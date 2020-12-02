program XUMInstaller;

uses
  Vcl.Forms,
  XUMInstaller.MainForm in 'XUMInstaller.MainForm.pas' {MainForm},
  libwdi in 'libwdi.pas',
  XUMInstaller.InstallerThread in 'XUMInstaller.InstallerThread.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
