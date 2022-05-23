unit UWebcam;

interface

uses
  System.Classes,
  WinAPI.Activex, WinAPI.DirectShow9, WinAPI.Windows,
  ComObj;

type
  TInfoFn = reference to procedure(const pInfo: string);
  TOnFrame = reference to procedure(pFrame: TMemoryStream);

  TWebcamState = (wsNull, wsPlaying, wsPaused, wsStopped);

  TFrameRate = (fr10, fr15, fr20, fr30, fr60);

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
    constructor Create(pInfoLogFn: TInfoFn; pOnFrame: TOnFrame; pFrameRate: TFrameRate = fr30); reintroduce;

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

    fEnum: IEnumMoniker;
    fGraph: IGraphBuilder;
    fBuild: ICaptureGraphBuilder2;
    fControl: IMediaControl;
    fVideoWindow: IVideoWindow;
    fSampleGrabber: ISampleGrabber;
    fCB: TSampleGrabberCB;

    function InitCaptureGraphBuilder: HRESULT;
    function EnumerateVideoInputDevices: HRESULT;
    function DisplayDeviceInformation(var pMoniker: IMoniker; const pDeviceName: string): HRESULT;
    function GetState: TWebcamState;
    function GetFrameRate: Integer;
  public
    constructor Create(pLogFn: TInfoFn; pOnFrame: TOnFrame; pCOMInitialize: Boolean = True); reintroduce;
    destructor Destroy; override;

    // Main operations
    procedure Play(const pDeviceName: string; pTargetFrameRate: TFrameRate = fr30);
    procedure Resume;
    procedure Pause;
    procedure Stop;

    // Utilities
    function GetAllVideoDeviceNames: TArray<string>;
    procedure SetTargetFrameRate(pFrameRate: TFrameRate);

    property FrameRate: Integer read GetFrameRate;
    property State: TWebcamState read GetState;
    property OnFrame: TOnFrame read fOnFrame write fOnFrame;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections;

{ TWebcam }

constructor TWebcam.Create(pLogFn: TInfoFn; pOnFrame: TOnFrame; pCOMInitialize: Boolean = True);
begin
  fInfoLogFn := pLogFn;
  fOnFrame := pOnFrame;
  fCOMInitialize := pComInitialize;

  if fComInitialize then
    CoInitializeEx(nil, COINIT_MULTITHREADED);
end;

destructor TWebcam.Destroy;
begin
  if fCOMInitialize then
    CoUninitialize;
  inherited;
end;

function TWebcam.InitCaptureGraphBuilder: HRESULT;
begin
  fGraph := nil;
  fBuild := nil;

  Result := CoCreateInstance(CLSID_CaptureGraphBuilder2, nil,
    CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, fBuild);

  if Result >= 0 then
  begin
    Result := CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER,
      IID_IGraphBuilder, fGraph);
    if Result >= 0 then
    begin
      fBuild.SetFilterGraph(fGraph);
      Result := S_OK;
    end
    else
      Result := S_FALSE;
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

function TWebcam.GetAllVideoDeviceNames: TArray<string>;
var
  vPropBag: IPropertyBag;
  vHr: HRESULT;
  vVar: OleVariant;
  vMoniker: IMoniker;
  vDeviceName: string;
  vList: TList<string>;
begin
  Result := nil;
  vHr := EnumerateVideoInputDevices;
  if vHr < 0 then
    Exit;

  vList := TList<string>.Create;
  while (fEnum.Next(1, vMoniker, nil) = S_OK) do
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

procedure TWebcam.Play(const pDeviceName: string; pTargetFrameRate: TFrameRate = fr30);
var
  vHr: HRESULT;
  vMoniker: IMoniker;
  vVideoCaptureFilter, vGrabberF: IBaseFilter;
  vMediaType: AM_MEDIA_TYPE;
  vVideoInfoHeader: PVideoInfoHeader;
begin
  if (fControl <> nil) and (GetState = wsPlaying) then
    Exit;

  vHr := InitCaptureGraphBuilder;

  if vHr < 0 then
    raise Exception.Create('Error initializing capture graph builder');

  vHr := fGraph.QueryInterface(IID_IMediaControl, fControl);

  if vHr < 0 then
    raise Exception.Create('Error creating media control interface');

  vHr := fGraph.QueryInterface(IID_IVideoWindow, fVideoWindow);

  if vHr < 0 then
    raise Exception.Create('Unable to acquire video window interface');

  vHr := EnumerateVideoInputDevices;

  if vHr < 0 then
    raise Exception.Create('Error enumerating video input devices');

  vHr := DisplayDeviceInformation(vMoniker, pDeviceName);

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

  vHr := fGraph.AddFilter(vGrabberF, PChar('UVC Camera'));

  if vHr < 0 then
    raise Exception.Create('Error adding sample grabber');

  vHr := fBuild.RenderStream(@PIN_CATEGORY_PREVIEW,
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

{ TSampleGrabberCB }

constructor TSampleGrabberCB.Create(pInfoLogFn: TInfoFn; pOnFrame: TOnFrame; pFrameRate: TFrameRate = fr30);
begin
  fInfoLogFn := pInfoLogFn;
  fOnFrame := pOnFrame;
  fFrameDistance := FrameRateToFrameDistance(pFrameRate);
end;

function TSampleGrabberCB.FrameRateToFrameDistance(pFrameRate: TFrameRate): LongWord;
begin
  case pFrameRate of
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

  if vNewFrameTime - fLFrameTime > 1000 then
  begin
    fLFrameTime := vNewFrameTime;
    fLastFrameCount := fCurrentFrameCount;
    fCurrentFrameCount := 0;
  end;

  if (vNewFrameTime - fLastFrameTime) > (fFrameDistance) then
  begin
    Inc(fCurrentFrameCount);
    TThread.Queue(nil,
    procedure
    begin
      fInfoLogFn(Format('NewFrame! FrameSize [%d]', [BufferLen]));
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