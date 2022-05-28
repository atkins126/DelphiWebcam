unit fmWebcam;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  UWebcam, Vcl.ExtCtrls;

type
  TfrmWebcam = class(TForm)
  published
    imWebcam: TImage;
    mem: TMemo;
    btnPlay: TButton;
    btnStop: TButton;
    btnPause: TButton;
    btnResume: TButton;
    btnUpdateDeviceList: TButton;
    lblLogger: TLabel;
    lblWebcamState: TLabel;
    lblWebcamStateValue: TLabel;
    cmbxDevices: TComboBox;
    lblFrameRate: TLabel;
    lblFrameRateValue: TLabel;
    lblDeviceList: TLabel;
    lblFrameRateOptions: TLabel;
    cmbxFrameRate: TComboBox;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnPauseClick(Sender: TObject);
    procedure btnResumeClick(Sender: TObject);
    procedure btnUpdateDeviceListClick(Sender: TObject);

    procedure cmbxFrameRateSelect(Sender: TObject);

    procedure ValidateMaxLines(Sender: TObject);
    procedure UpdateAllDeviceNamesToComboBox;
    procedure UpdateWebcamState;
  strict private
    fWebcam: TWebcam;
    fWebcamStateTimer: TTimer;
    fCount: Integer;

    procedure HandleWebcamUpdateStats(Sender: TObject);
  end;

var
  frmWebcam: TfrmWebcam;

implementation

uses
  USmoothResize;

const
  WEBCAMSTATENAME: array[UWebcam.TWebcamState] of string = ('Null', 'Playing', 'Paused', 'Stopped');
  WEBCAMSTATECOLOR: array[UWebcam.TWebcamState] of TColor = (clGrayText, clGreen, clOlive, clRed);
  FRAMERATESTRINGS: array[UWebcam.TFrameRate] of string = ('10', '15', '20', '30', '60');

{$R *.dfm}

procedure TfrmWebcam.FormCreate(Sender: TObject);
var
  vFrameRate: TFrameRate;
begin
  mem.OnChange := ValidateMaxLines;

  fWebcamStateTimer := TTimer.Create(Self);
  fWebcamStateTimer.Enabled := True;
  fWebcamStateTimer.Interval := 1000;
  fWebcamStateTimer.OnTimer := HandleWebcamUpdateStats;

  fWebcam := TWebcam.Create
  (
    procedure(const pInfo: string)
    begin
      mem.Lines.Add(Format('[%d] %s', [fCount, pInfo]));
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
      vResized := TBitmap.Create;
      vResized.Width := imWebcam.Width;
      vResized.Height := imWebcam.Height;

      SmoothResize(vOriginal, vResized);

      imWebcam.Picture.Bitmap.Assign(vResized);

      vOriginal.Free;
      vResized.Free;
    end
  );

  for vFrameRate := Low(UWebcam.TFrameRate) to High(UWebcam.TFrameRate) do
    cmbxFrameRate.Items.Add(FRAMERATESTRINGS[vFrameRate]);
  cmbxFrameRate.ItemIndex := Integer(fr30);

  UpdateAllDeviceNamesToComboBox;
end;

procedure TfrmWebcam.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fWebcamStateTimer);
  if fWebcam <> nil then
    FreeAndNil(fWebcam);
end;

procedure TfrmWebcam.HandleWebcamUpdateStats(Sender: TObject);
begin
  UpdateWebcamState;
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
  vDeviceNames := fWebcam.GetAllVideoDeviceNames;
  if vDeviceNames <> nil then
  begin
    cmbxDevices.Clear;
    for vCount := 0 to High(vDeviceNames) do
      cmbxDevices.Items.Add(vDeviceNames[vCount]);
    cmbxDevices.ItemIndex := 0;
  end;
end;

procedure TfrmWebcam.UpdateWebcamState;
begin
  if fWebcam = nil then
    Exit;

  lblWebcamStateValue.Caption := WEBCAMSTATENAME[fWebcam.State];
  lblWebcamStateValue.Font.Color := WEBCAMSTATECOLOR[fWebcam.State];
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

  fWebcam.Play(cmbxDevices.Items[cmbxDevices.ItemIndex], TFrameRate(cmbxFrameRate.ItemIndex));
  UpdateWebcamState;
end;

procedure TfrmWebcam.btnPauseClick(Sender: TObject);
begin
  if fWebcam <> nil then
    fWebcam.Pause;
  UpdateWebcamState;
end;

procedure TfrmWebcam.btnResumeClick(Sender: TObject);
begin
  if fWebcam <> nil then
    fWebcam.Resume;
  UpdateWebcamState;
end;

procedure TfrmWebcam.btnStopClick(Sender: TObject);
begin
  if fWebcam <> nil then
    fWebcam.Stop;
  UpdateWebcamState;
  lblFrameRateValue.Caption := IntToStr(0);
  imWebcam.Picture.Bitmap.Assign(nil);
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
