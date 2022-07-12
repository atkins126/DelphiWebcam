program Webcam;

uses
  Vcl.Forms,
  fmWebcam in 'fmWebcam.pas' {frmWebcam},
  fmSelectFormat in 'fmSelectFormat.pas' {frmSelectFormat};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmWebcam, frmWebcam);
  Application.CreateForm(TfrmSelectFormat, frmSelectFormat);
  Application.Run;
end.
