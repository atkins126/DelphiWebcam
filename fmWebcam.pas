unit fmWebcam;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  UWebcam;

type
  TfrmWebcam = class(TForm)
  published
    cbResize: TCheckBox;
    imWebcam: TImage;
    memLogger: TMemo;
    memEvents: TMemo;
    btnPlay: TButton;
    btnStop: TButton;
    btnPause: TButton;
    btnResume: TButton;
    btnUpdateDeviceList: TButton;
    btnStreamCaps: TButton;
    lblLogger: TLabel;
    lblWebcamState: TLabel;
    lblWebcamStateValue: TLabel;
    cmbxDevices: TComboBox;
    lblFrameRate: TLabel;
    lblFrameRateValue: TLabel;
    lblVideoDeviceList: TLabel;
    lblFrameRateOptions: TLabel;
    cmbxFrameRate: TComboBox;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure btnPlayClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnPauseClick(Sender: TObject);
    procedure btnResumeClick(Sender: TObject);
    procedure btnUpdateDeviceListClick(Sender: TObject);
    procedure btnStreamCapsClick(Sender: TObject);

    procedure cmbxFrameRateSelect(Sender: TObject);

    procedure ValidateMaxLines(Sender: TObject);
    procedure UpdateAllDeviceNamesToComboBox;
    procedure UpdateWebcamState(pState: TWebcamState);
  strict private
    fWebcam: TWebcam;
    fWebcamStatsTimer: TTimer;
    fCount: Integer;

    procedure HandleWebcamUpdateStats(Sender: TObject);
  end;

var
  frmWebcam: TfrmWebcam;

implementation

uses
  System.Generics.Collections,
  TypInfo,
  USmoothResize,
  fmSelectFormat;

const
  WEBCAMSTATENAME: array[UWebcam.TWebcamState] of string = ('Null', 'Playing', 'Paused', 'Stopped');
  WEBCAMSTATECOLOR: array[UWebcam.TWebcamState] of TColor = (clGrayText, clGreen, clOlive, clRed);
  FRAMERATESTRINGS: array[UWebcam.TFrameRate] of string = ('Unrestrained', '10', '15', '20', '30', '60');

{$R *.dfm}

procedure TfrmWebcam.FormCreate(Sender: TObject);

var
  vFrameRate: TFrameRate;
begin
  memLogger.OnChange := ValidateMaxLines;

  fWebcamStatsTimer := TTimer.Create(Self);
  fWebcamStatsTimer.Enabled := True;
  fWebcamStatsTimer.Interval := 1000;
  fWebcamStatsTimer.OnTimer := HandleWebcamUpdateStats;

  fWebcam := TWebcam.Create
  (
    procedure(const pInfo: string)
    begin
      memLogger.Lines.Add(Format('[%d] %s', [fCount, pInfo]));
      Inc(fCount);
    end,

    procedure(pStream: TMemoryStream)
    var
      vOriginal, vResized: TBitmap;
    begin
      if pStream = nil then
        Exit;

      vOriginal := TBitmap.Create;
      vOriginal.LoadFromStream(pStream);
      if cbResize.Checked then
      begin
        vResized := TBitmap.Create;
        vResized.Width := imWebcam.Width;
        vResized.Height := imWebcam.Height;
        SmoothResize(vOriginal, vResized);
        imWebcam.Picture.Bitmap.Assign(vResized);
        vResized.Free;
      end
      else
        imWebcam.Picture.Bitmap.Assign(vOriginal);
      vOriginal.Free;
    end
  );

  fWebcam.OnEventE := procedure(pEvent: TWebcamEvent; pParamOne, pParamTwo: NativeInt)
  begin
    memEvents.Lines.Add(Format('vEvent: %s', [TypInfo.GetEnumName(TypeInfo(TWebcamEvent), Integer(pEvent))]));
    case pEvent of
      weDeviceLost: fWebcam.Stop;
      weDeviceStateChange:
      begin
        memEvents.Lines.Add(Format('PrevState: %s | NewState: %s', [
          TypInfo.GetEnumName(TypeInfo(TWebcamState), Integer(pParamOne)),
          TypInfo.GetEnumName(TypeInfo(TWebcamState), Integer(pParamTwo))
          ]));
        UpdateWebcamState(TWebcamState(pParamTwo));
      end;
    end;
  end;

  for vFrameRate := Low(UWebcam.TFrameRate) to High(UWebcam.TFrameRate) do
    cmbxFrameRate.Items.Add(FRAMERATESTRINGS[vFrameRate]);
  cmbxFrameRate.ItemIndex := Integer(frUnrestrained);

  UpdateAllDeviceNamesToComboBox;
end;

procedure TfrmWebcam.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fWebcamStatsTimer);
  if fWebcam <> nil then
    FreeAndNil(fWebcam);
end;

procedure TfrmWebcam.HandleWebcamUpdateStats(Sender: TObject);
begin
  if fWebcam <> nil then
    lblFrameRateValue.Caption := fWebcam.FrameRate.ToString;
end;

procedure TfrmWebcam.UpdateAllDeviceNamesToComboBox;
var
  vDeviceNames: TArray<string>;
  vCount: Integer;
begin
  if fWebcam = nil then
    Exit;
  vDeviceNames := TWebcam.GetAllVideoDeviceNames;
  if vDeviceNames <> nil then
  begin
    cmbxDevices.Clear;
    for vCount := 0 to High(vDeviceNames) do
      cmbxDevices.Items.Add(vDeviceNames[vCount]);
    cmbxDevices.ItemIndex := 0;
  end;
end;

procedure TfrmWebcam.UpdateWebcamState(pState: TWebcamState);
begin
  if fWebcam = nil then
    Exit;

  lblWebcamStateValue.Caption := WEBCAMSTATENAME[pState];
  lblWebcamStateValue.Font.Color := WEBCAMSTATECOLOR[pState];
end;

procedure TfrmWebcam.ValidateMaxLines(Sender: TObject);
var
  vMemo: TMemo absolute Sender;
begin
  if vMemo.Lines.Count >= 100 then
    vMemo.Clear;
end;

procedure TfrmWebcam.btnPlayClick(Sender: TObject);
begin
  if cmbxDevices.ItemIndex = -1 then
    Exit;

  if cmbxFrameRate.ItemIndex = -1 then
    Exit;

  fWebcam.Play(cmbxDevices.Items[cmbxDevices.ItemIndex], TFrameRate(cmbxFrameRate.ItemIndex),
    function(pCaps: TList<TStreamCaps>): TStreamCaps
    var
      vForm: TfrmSelectFormat;
    begin
      vForm := fmSelectFormat.CreateSelectFormatForm(pCaps, Self);
      vForm.ShowModal;
      Result := vForm.Caps;
      FreeAndNil(vForm);
    end
  );
end;

procedure TfrmWebcam.btnPauseClick(Sender: TObject);
begin
  if fWebcam <> nil then
    fWebcam.Pause;
end;

procedure TfrmWebcam.btnResumeClick(Sender: TObject);
begin
  if fWebcam <> nil then
    fWebcam.Resume;
end;

procedure TfrmWebcam.btnStopClick(Sender: TObject);
begin
  if fWebcam <> nil then
    fWebcam.Stop;
  lblFrameRateValue.Caption := IntToStr(0);
  imWebcam.Picture.Bitmap.Assign(nil);
end;

procedure TfrmWebcam.btnStreamCapsClick(Sender: TObject);
var
  vStreamCaps: TList<TStreamCaps>;
  vCount: Integer;
begin
  vStreamCaps := fWebcam.GetCurrentStreamCaps;
  if vStreamCaps <> nil then
    for vCount := 0 to vStreamCaps.Count - 1 do
      memEvents.Lines.Add(Format('MaxWidth = %d | MinWidth = %d | MaxHeight = %d | MinHeight = %d | MaxFrameRate = %d | MinFrameRate = %d | MinBitRate = %d | MaxBitRate = %d',
      [
        vStreamCaps[vCount].MaxWidth, vStreamCaps[vCount].MinWidth,
        vStreamCaps[vCount].MaxHeight, vStreamCaps[vCount].MinHeight,
        vStreamCaps[vCount].MaxFrameRate, vStreamCaps[vCount].MinFrameRate,
        vStreamCaps[vCount].MinBitrate, vStreamCaps[vCount].MaxBitrate
      ]));
  FreeAndNil(vStreamCaps);
end;

procedure TfrmWebcam.btnUpdateDeviceListClick(Sender: TObject);
begin
  UpdateAllDeviceNamesToComboBox;
end;

procedure TfrmWebcam.cmbxFrameRateSelect(Sender: TObject);
begin
  if (fWebcam <> nil) and (fWebcam.State = wsPlaying) then
    fWebcam.SetTargetFrameRate(TFrameRate(cmbxFrameRate.ItemIndex));
end;

end.
