program Webcam;

uses
  Vcl.Forms,
  fmWebcam in 'fmWebcam.pas' {frmWebcam};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmWebcam, frmWebcam);
  Application.Run;
end.
