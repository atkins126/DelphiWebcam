unit UWebcam;

interface

uses
  System.Classes, System.Generics.Collections,
  WinAPI.Activex, WinAPI.DirectShow9, WinAPI.Windows,
  WinAPI.Messages,
  ComObj;

type
  TWebcamState = (wsNull, wsPlaying, wsPaused, wsStopped);
  TWebcamEvent = (weDeviceLost, weDeviceReconnect, weDeviceStateChange);
  TFrameRate = (frUnrestrained, fr10, fr15, fr20, fr30, fr60);

  TStreamCaps = record
    MaxFrameRate: Int64;
    MinFrameRate: Int64;
    MinWidth: Int64;
    MinHeight: Int64;
    MaxWidth: Int64;
    MaxHeight: Int64;
    MinBitrate: Int64;
    MaxBitrate: Int64;
  end;

  TInfoFn = reference to procedure(const pInfo: string);
  TOnFrame = reference to procedure(pFrame: TMemoryStream);
  TOnEvent = reference to procedure(pEvent: TWebcamEvent; pParamOne, pParamTwo: NativeInt);
  TCapOptions = reference to function(pCaps: TList<TStreamCaps>): TStreamCaps;

  TSampleGrabberCB = class(TInterfacedObject, ISampleGrabberCB)
  private
    fInfoLogFn: TInfoFn;
    fFrameDistance: LongWord;
    fLFrameTime, fLastFrameTime: LongWord;
    fCurrentFrameCount, fLastFrameCount: LongWord;

    fWidth: Int32;
    fHeight: Int32;
    fOnFrame: TOnFrame;

    function FrameRateToFrameDistance(pFrameRate: TFrameRate): LongWord;
    function FrameToStream(pBi: BITMAPINFO; pData: PByte; size: LongInt): TMemoryStream;
  public
    constructor Create(pInfoLogFn: TInfoFn; pOnFrame: TOnFrame; pFrameRate: TFrameRate = frUnrestrained); reintroduce;

    function SampleCB(SampleTime: Double; pSample: IMediaSample): HResult; stdcall;
    function BufferCB(SampleTime: Double; pBuffer: PByte; BufferLen: longint): HResult; stdcall;

    procedure SetFrameRate(pFrameRate: TFrameRate);

    property Width: Int32 read fWidth write fWidth;
    property Height: Int32 read fHeight write fHeight;
    property CurrentFrameRate: LongWord read fLastFrameCount;
  end;

  TWebcam = class(TObject)
  strict private
    fCOMInitialize: Boolean;
    fInfoLogFn: TInfoFn;
    fOnFrame: TOnFrame;
    fOnEvent: TOnEvent;

    fEventHandle: Hwnd;

    fCurrentState: TWebcamState;

    fEnum: IEnumMoniker;
    fGraph: IGraphBuilder;
    fVideoGraphBuilder: ICaptureGraphBuilder2;
    fControl: IMediaControl;
    fAsyncEvents: IMediaEventEx;
    fVideoWindow: IVideoWindow;
    fBasicVideo: IBasicVideo;
    fStreamConfig: IAMStreamConfig;
    fSampleGrabber: ISampleGrabber;
    fCB: TSampleGrabberCB;

    function InitCaptureGraphBuilder: HRESULT;
    function EnumerateVideoInputDevices: HRESULT;
    function DisplayDeviceInformation(var pMoniker: IMoniker; const pDeviceName: string): HRESULT;
    function GetState: TWebcamState;
    function GetFrameRate: Integer;

    procedure SetFormat(pCaps: TStreamCaps); overload;
    procedure OnEvent(var pMsg: TMessage);
  public
    // General Utilities
    class function GetAllVideoDeviceNames: TArray<string>;
  public
    constructor Create(pLogFn: TInfoFn; pOnFrame: TOnFrame; pCOMInitialize: Boolean = True); reintroduce;
    destructor Destroy; override;

    // Main operations
    procedure Play(const pVideoDeviceName: string; pTargetFrameRate: TFrameRate = frUnrestrained;
      pChooseFormat: TCapOptions = nil);
    procedure Resume;
    procedure Pause;
    procedure Stop;

    // Utilities
    function GetCurrentStreamCaps: TList<TStreamCaps>;
    procedure SetTargetFrameRate(pFrameRate: TFrameRate);

    property FrameRate: Integer read GetFrameRate;
    property State: TWebcamState read GetState;
    property OnFrame: TOnFrame read fOnFrame write fOnFrame;
    property OnEventE: TOnEvent read fOnEvent write fOnEvent;
  end;

implementation

uses
  System.SysUtils;

const
  WM_GRAPH_NOTIFY: Cardinal = WM_APP + 1;

  function FilterStateToWebcamState(pState: _FilterState): TWebcamState;
begin
  case pState of
    State_Stopped: Exit(TWebcamState.wsStopped);
    State_Paused: Exit(TWebcamState.wsPaused);
    State_Running: Exit(TWebcamState.wsPlaying);
  else
    Exit(TWebcamState.wsNull);
  end;
end;

{ TWebcam }

constructor TWebcam.Create(pLogFn: TInfoFn; pOnFrame: TOnFrame; pCOMInitialize: Boolean = True);
begin
  fInfoLogFn := pLogFn;
  fOnFrame := pOnFrame;
  fCOMInitialize := pComInitialize;
  fEventHandle := AllocateHwnd(OnEvent);
  fCurrentState := TWebcamState.wsNull;

  if fComInitialize then
    CoInitializeEx(nil, COINIT_MULTITHREADED);
end;

destructor TWebcam.Destroy;
begin
  if GetState <> wsNull then
    Self.Stop;
  DeallocateHWnd(fEventHandle);
  if fCOMInitialize then
    CoUninitialize;
  inherited;
end;

function TWebcam.InitCaptureGraphBuilder: HRESULT;
begin
  fGraph := nil;
  fVideoGraphBuilder := nil;

  Result := CoCreateInstance(CLSID_CaptureGraphBuilder2, nil,
    CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, fVideoGraphBuilder);

  if Result >= 0 then
  begin
    Result := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER,
      IID_IGraphBuilder, fGraph);
    if Result >= 0 then
    begin
      fVideoGraphBuilder.SetFilterGraph(fGraph);
      Result := S_OK;
    end
    else
      Result := S_FALSE;
  end;
end;

procedure TWebcam.OnEvent(var pMsg: TMessage);
var
  vParamOne, vParamTwo: NativeInt;
  vEvCode: Integer;
begin
  if fAsyncEvents = nil then
    Exit;

  if pMsg.Msg = WM_GRAPH_NOTIFY then
    while fAsyncEvents.GetEvent(vEvCode, vParamOne, vParamTwo, 20) >= 0 do
    begin
      fAsyncEvents.FreeEventParams(vEvCode, vParamOne, vParamTwo);
      if Assigned(fOnEvent) then
        case vEvCode of
          EC_DEVICE_LOST: // 31
            if Assigned(fOnEvent) then
            begin
              if vParamTwo = 0 then
                fOnEvent(TWebcamEvent.weDeviceLost, 0, 0)
              else if vParamTwo = 1 then
                fOnEvent(TWebcamEvent.weDeviceReconnect, 0, 0)
            end;
          EC_STATE_CHANGE:
            begin
              if Assigned(fOnEvent) then
                fOnEvent(TWebcamEvent.weDeviceStateChange, NativeInt(fCurrentState),
                  NativeInt(FilterStateToWebcamState(_FilterState(vParamOne))));
              fCurrentState := FilterStateToWebcamState(_FilterState(vParamOne));
            end;
        end;
    end;
end;

function TWebcam.EnumerateVideoInputDevices: HRESULT;
var
  vDeviceEnumerator: ICreateDevEnum;
begin
  Result := CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC_SERVER,
    ICreateDevEnum, vDeviceEnumerator);

  if Result >= 0 then
  begin
    Result := vDeviceEnumerator.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, fEnum, 0);
    if (Result = S_FALSE) then
      Result := VFW_E_NOT_FOUND;
  end;
end;

function TWebcam.DisplayDeviceInformation(var pMoniker: IMoniker; const pDeviceName: string): HRESULT;
var
  vPropBag: IPropertyBag;
  vHr: HRESULT;
  vVar: OleVariant;
  vDeviceName: string;
begin
  // Property	Description	VARIANT Type
  // "FriendlyName"	The name of the device.	VT_BSTR
  // "Description"	A description of the device.	VT_BSTR
  // "DevicePath"	A unique string that identifies the device. (Video capture devices only.)	VT_BSTR
  // "WaveInID"	The identifier for an audio capture device. (Audio capture devices only.)	VT_I4

  while (fEnum.Next(1, pMoniker, nil) = S_OK) do
  begin
    vHr := pMoniker.BindToStorage(nil, nil, IPropertyBag, vPropBag);
    if vHr < 0 then
      Continue;

    VariantInit(vVar);

    vHr := vPropBag.Read(PChar('Description'), vVar, nil);
    if vHr <= 0 then
      vHr := vPropBag.Read(PChar('FriendlyName'), vVar, nil);
    if vHr >= 0 then
    begin
      vDeviceName := VariantToStringWithDefault(vVar, PChar(EmptyStr));
      VariantClear(vVar);
      if vDeviceName = pDeviceName then
      begin
        if Assigned(fInfoLogFn) then
          fInfoLogFn(Format('Setting up device: %s', [vDeviceName]));
        Exit(0);
      end;
    end;
  end;
  Exit(0);
end;

function TWebcam.GetCurrentStreamCaps: TList<TStreamCaps>;
var
  vPICount, vPISize, vFormat: Integer;
  vSCC: VIDEO_STREAM_CONFIG_CAPS;
  vPMTConfig: PAMMediaType;
  vHr: Integer;
  vList: TList<TStreamCaps>;
  vCaps: TStreamCaps;
begin
  Result := nil;
  if fStreamConfig = nil then
    Exit
  else
  begin
    fStreamConfig.GetNumberOfCapabilities(vPICount, vPISize);

    if (vPISize = Sizeof(VIDEO_STREAM_CONFIG_CAPS)) then
    begin
      vList := TList<TStreamCaps>.Create;
      for vFormat := 0 to vPICount - 1 do
      begin
        vHr := fStreamConfig.GetStreamCaps(vFormat, vPMTConfig, vSCC);
        if vHr >= 0 then
        begin
          vCaps.MaxFrameRate := vSCC.MaxFrameInterval;
          vCaps.MinFrameRate := vSCC.MinFrameInterval;
          vCaps.MinWidth := vSCC.MinOutputSize.Width;
          vCaps.MinHeight := vSCC.MinOutputSize.Height;
          vCaps.MaxWidth := vSCC.MaxOutputSize.Width;
          vCaps.MaxHeight := vSCC.MaxOutputSize.Height;
          vCaps.MinBitrate := vSCC.MinBitsPerSecond;
          vCaps.MaxBitrate := vSCC.MaxBitsPerSecond;
          vList.Add(vCaps);
        end;
      end;
      Result := vList;
    end;
  end;
end;

function TWebcam.GetFrameRate: Integer;
begin
  if fCB <> nil then
    Exit(fCB.CurrentFrameRate)
  else
    Exit(0);
end;

function TWebcam.GetState: TWebcamState;
var
  vState: _FilterState;
begin
  if fControl = nil then
    Exit(wsNull);

  fControl.GetState(10, vState);

  case vState of
    State_Stopped: Exit(wsStopped);
    State_Paused: Exit(wsPaused);
    State_Running: Exit(wsPlaying);
  else
    Exit(wsNull);
  end;
end;

procedure TWebcam.Play(const pVideoDeviceName: string; pTargetFrameRate: TFrameRate = frUnrestrained;
  pChooseFormat: TCapOptions = nil);
var
  vHr: HRESULT;
  vMoniker: IMoniker;
  vVideoCaptureFilter, vGrabberF: IBaseFilter;
  vMediaType: AM_MEDIA_TYPE;
  vVideoInfoHeader: PVideoInfoHeader;
  vList: TList<TStreamCaps>;
begin
  if (fControl <> nil) and (GetState = wsPlaying) then
    Exit;

  vHr := InitCaptureGraphBuilder;

  if vHr < 0 then
    raise Exception.Create('Error initializing capture graph builder');

  vHr := fGraph.QueryInterface(IID_IMediaControl, fControl);

  if vHr < 0 then
    raise Exception.Create('Error creating media control interface');

  vHr := fGraph.QueryInterface(IID_IMediaEventEx, fAsyncEvents);

  fAsyncEvents.SetNotifyFlags(0);
  fAsyncEvents.SetNotifyWindow(fEventHandle, WM_GRAPH_NOTIFY, NativeInt(nil));
  fAsyncEvents.CancelDefaultHandling(EC_STATE_CHANGE);

  if vHr < 0 then
    raise Exception.Create('Error creating media event interface');

  vHr := fGraph.QueryInterface(IID_IVideoWindow, fVideoWindow);

  if vHr < 0 then
    raise Exception.Create('Unable to acquire video window interface');

  vHr := fGraph.QueryInterface(IID_IBasicVideo, fBasicVideo);

  if vHr < 0 then
    raise Exception.Create('Unable to acquire BasicVideo interface');

  vHr := EnumerateVideoInputDevices;

  if vHr < 0 then
    raise Exception.Create('Error enumerating video input devices');

  vHr := DisplayDeviceInformation(vMoniker, pVideoDeviceName);

  if vHr < 0 then
    raise Exception.Create('Unable to display devices');

  vHr := CoCreateInstance(CLSID_SampleGrabber, nil, CLSCTX_INPROC_SERVER,
    IID_IBaseFilter, vGrabberF);

  if vHr < 0 then
    raise Exception.Create('Error creating sample grabber interface');

  vHr := vGrabberF.QueryInterface(IID_ISampleGrabber, fSampleGrabber);

  if vHr < 0 then
    raise Exception.Create('Error querying sample grabber interface');

  vHr := vMoniker.BindToObject(nil, nil, IID_IBaseFilter, vVideoCaptureFilter);

  if vHr < 0 then
    raise Exception.Create('Unable to bind base filter');

  vHr := fGraph.AddFilter(vVideoCaptureFilter, PChar('Video capture'));

  if vHr < 0 then
    raise Exception.Create('Unable to add graph filter');

  FillChar(vMediaType, Sizeof(AM_MEDIA_TYPE), 0);
  vMediaType.majortype := MEDIATYPE_Video;
  vMediaType.subtype := MEDIASUBTYPE_RGB24;

  vHr := fSampleGrabber.SetMediaType(vMediaType);

  if vHr < 0 then
    raise Exception.Create('Error setting media type');

  vHr := fSampleGrabber.SetBufferSamples(True);
  if vHr < 0 then
    raise Exception.Create('Error setting buffer samples');

  vHr := fSampleGrabber.SetOneShot(False);
  if vHr < 0 then
    raise Exception.Create('Error setting one shot');

  vHr := fGraph.AddFilter(vGrabberF, PChar('Camera'));

  if vHr < 0 then
    raise Exception.Create('Error adding sample grabber');

  vHr := fVideoGraphBuilder.FindInterface(nil,
    nil, vVideoCaptureFilter, IID_IAMSTREAMCONFIG, fStreamConfig);

  if vHr < 0 then
    raise Exception.Create('Unable to acquire StreamConfig interface');

  if Assigned(pChooseFormat) then
    try
      vList := GetCurrentStreamCaps;
      SetFormat(pChooseFormat(vList));
    finally
      FreeAndNil(vList);
    end;

  vHr := fVideoGraphBuilder.RenderStream(@PIN_CATEGORY_PREVIEW,
    @MEDIATYPE_Video, vVideoCaptureFilter, vGrabberF, nil);

  if vHr < 0 then
    raise Exception.Create('Unable to render stream');

  vHr := fSampleGrabber.GetConnectedMediaType(vMediaType);

  if vHr < 0 then
    raise Exception.Create('Unable to determine what we connected');

  vVideoInfoHeader := PVIDEOINFOHEADER(vMediaType.pbFormat);

  fCB := TSampleGrabberCB.Create(fInfoLogFn, fOnFrame, pTargetFrameRate);
  fCB.Width := vVideoInfoHeader.bmiHeader.biWidth;
  fCB.Height := vVideoInfoHeader.bmiHeader.biHeight;

  vHr := fSampleGrabber.SetCallback(fCB, 1);

  if vHr < 0 then
    raise Exception.Create('Unable to set samplegrabber callback');

  fVideoWindow.put_AutoShow(False);

  vHr := fControl.Run;

  if vHr < 0 then
    raise Exception.Create('Unable to run');
end;

procedure TWebcam.Resume;
begin
  if (fControl <> nil) and (GetState = wsPaused) then
    fControl.Run;
end;

procedure TWebcam.Pause;
begin
  if (fControl <> nil) and (GetState = wsPlaying) then
    fControl.Pause;
end;

procedure TWebcam.SetFormat(pCaps: TStreamCaps);
var
  vCurrentConfig, vPMTConfig: PAMMediaType;
  vIndex: Integer;
  vSCC: VIDEO_STREAM_CONFIG_CAPS;
  vPICount, vPISize: Integer;
  vHr: HRESULT;
begin
  if fStreamConfig <> nil then
  begin
    fStreamConfig.GetNumberOfCapabilities(vPICount, vPISize);

    if (vPISize = Sizeof(VIDEO_STREAM_CONFIG_CAPS)) then
     for vIndex := 0 to vPICount - 1 do
      begin
        vHr := fStreamConfig.GetStreamCaps(vIndex, vPMTConfig, vSCC);
        if vHr < 0 then
          Continue;
        if vPMTConfig.pbFormat = nil then
          Continue;
        if (vSCC.MaxFrameInterval = pCaps.MaxFrameRate) and
          (vSCC.MinFrameInterval = pCaps.MinFrameRate) and
          (vSCC.MinOutputSize.Width = pCaps.MinWidth) and
          (vSCC.MinOutputSize.Height = pCaps.MinHeight) and
          (vSCC.MaxOutputSize.Width = pCaps.MaxWidth) and
          (vSCC.MaxOutputSize.Height = pCaps.MaxHeight) and
          (vSCC.MinBitsPerSecond = pCaps.MinBitrate) and
          (vSCC.MaxBitsPerSecond = pCaps.MaxBitrate) then
        begin
          fStreamConfig.GetFormat(vCurrentConfig);
          vHr := fStreamConfig.SetFormat(vPMTConfig);
          if vHr < 0 then
            raise Exception.Create('Unable to set format')
          else
            Break;
        end;
      end;
  end;
end;

procedure TWebcam.SetTargetFrameRate(pFrameRate: TFrameRate);
begin
  if fCB <> nil then
    fCB.SetFrameRate(pFrameRate);
end;

procedure TWebcam.Stop;
begin
  if (fControl <> nil) and (GetState in [wsPlaying, wsPaused]) then
    fControl.Stop;
end;

class function TWebcam.GetAllVideoDeviceNames: TArray<string>;
var
  vPropBag: IPropertyBag;
  vHr: HRESULT;
  vVar: OleVariant;
  vMoniker: IMoniker;
  vDeviceName: string;
  vList: TList<string>;
  vDeviceEnumerator: ICreateDevEnum;
  vEnum: IEnumMoniker;
begin
  Result := nil;
  vHr := CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC_SERVER,
    ICreateDevEnum, vDeviceEnumerator);

  if vHr >= 0 then
  begin
    vHr := vDeviceEnumerator.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, vEnum, 0);
    if (vHr = S_FALSE) then
      vHr := VFW_E_NOT_FOUND;
  end;

  if vHr < 0 then
    Exit;

  vList := TList<string>.Create;
  while (vEnum.Next(1, vMoniker, nil) = S_OK) do
  begin
    vHr := vMoniker.BindToStorage(nil, nil, IPropertyBag, vPropBag);
    if vHr < 0 then
      Continue;
    VariantInit(vVar);
    vHr := vPropBag.Read(PChar('Description'), vVar, nil);
    if vHr <= 0 then
      vHr := vPropBag.Read(PChar('FriendlyName'), vVar, nil);
    if vHr >= 0 then
    begin
      vDeviceName := VariantToStringWithDefault(vVar, PChar(EmptyStr));
      VariantClear(vVar);
      vList.Add(vDeviceName);
    end;
  end;
  Result := vList.ToArray;
  vList.Free;
end;

{ TSampleGrabberCB }

constructor TSampleGrabberCB.Create(pInfoLogFn: TInfoFn; pOnFrame: TOnFrame; pFrameRate: TFrameRate = frUnrestrained);
begin
  fInfoLogFn := pInfoLogFn;
  fOnFrame := pOnFrame;
  fFrameDistance := FrameRateToFrameDistance(pFrameRate);
end;

function TSampleGrabberCB.FrameRateToFrameDistance(pFrameRate: TFrameRate): LongWord;
begin
  case pFrameRate of
    frUnrestrained: Exit(0);
    fr10: Exit(85);
    fr15: Exit(60);
    fr20: Exit(31);
    fr30: Exit(30);
    fr60: Exit(15);
  else
    Exit(30);
  end;
end;

function TSampleGrabberCB.FrameToStream(pBi: BITMAPINFO; pData: PByte;
  size: LongInt): TMemoryStream;
var
  vBufSize: LongInt;
  vBfh: BITMAPFILEHEADER;
  vBih: BITMAPINFOHEADER;
begin
  vBufSize := size;
  FillChar(vBfh, 0, sizeof(BITMAPFILEHEADER));
  vBfh.bfType := 66 + (77 shl 8);
  vBfh.bfOffBits := Sizeof(BITMAPFILEHEADER) + Sizeof(BITMAPINFOHEADER);
  vBfh.bfSize := Sizeof(BITMAPFILEHEADER) + Sizeof(BITMAPINFOHEADER) + vBufSize;

  FillChar(vBih, 0, Sizeof(BITMAPINFOHEADER));
  vBih.biSize := Sizeof(vBih);
  vBih.biWidth := pBi.bmiHeader.biWidth;
  vBih.biHeight := pBi.bmiHeader.biHeight;
  vBih.biPlanes := 1;
  vBih.biBitCount := 24;
  vBih.biCompression := BI_RGB;
  vBih.biSizeImage := Self.Width + Self.Height * 3;
  vBih.biClrUsed := 0;

  Result := TMemoryStream.Create;
  Result.Write(vBfh, Sizeof(BITMAPFILEHEADER));
  Result.Write(vBih, Sizeof(BITMAPINFOHEADER));
  Result.Write(pData[0], vBufSize);
  Result.Seek(0, TSeekOrigin.soBeginning);
end;

function TSampleGrabberCB.BufferCB(SampleTime: Double; pBuffer: PByte;
  BufferLen: longint): HResult;
var
  vBfh: BITMAPFILEHEADER;
  vBih: BITMAPINFOHEADER;
  vBi: BITMAPINFO;
  vNewFrameTime: LongWord;
begin
  FillChar(vBfh, Sizeof(BITMAPFILEHEADER), 0);
  vBfh.bfType := 66 + (77 shl 8);
  vBfh.bfSize := Sizeof(BITMAPFILEHEADER) + Sizeof(BITMAPINFOHEADER) + BufferLen;
  vBfh.bfOffBits := Sizeof(BITMAPFILEHEADER) + Sizeof(BITMAPINFOHEADER);

  FillChar(vBih, Sizeof(BITMAPINFOHEADER), 0);
  vBih.biSize := Sizeof(BITMAPINFOHEADER);
  vBih.biWidth := Self.Width;
  vBih.biHeight := Self.Height;
  vBih.biPlanes := 1;
  vBih.biBitCount := 24;

  vBi.bmiHeader := vBih;

  vNewFrameTime := GetTickCount;

  // Counting how many frames per second
  if vNewFrameTime - fLFrameTime > 1000 then
  begin
    fLFrameTime := vNewFrameTime;
    fLastFrameCount := fCurrentFrameCount;
    fCurrentFrameCount := 0;
  end;

  if (fFrameDistance = 0) or ((vNewFrameTime - fLastFrameTime) > (fFrameDistance)) then
  begin
    Inc(fCurrentFrameCount);
    if Assigned(fInfoLogFn) then
      TThread.Queue(nil,
      procedure
      begin
        fInfoLogFn(Format('NewFrame. FrameSize [%d]', [BufferLen]));
      end);

    fLastFrameTime := vNewFrameTime;

    TThread.Queue(nil,
    procedure
    var
      vStream: TMemoryStream;
    begin
      vStream := FrameToStream(vBI, pBuffer, BufferLen);
      if Assigned(fOnFrame) then
        fOnFrame(vStream);
      vStream.Free;
    end);
  end;

  Exit(0);
end;

function TSampleGrabberCB.SampleCB(SampleTime: Double;
  pSample: IMediaSample): HResult;
begin
  Result := 0;
end;

procedure TSampleGrabberCB.SetFrameRate(pFrameRate: TFrameRate);
begin
  fFrameDistance := FrameRateToFrameDistance(pFrameRate);
end;

end.
