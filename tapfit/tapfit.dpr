program tapfit;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  System.UITypes,
  tapfit.MainForm in 'tapfit.MainForm.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;

  g_DeviceHandle := 0;
  if not ConnectTapeXUM then
  begin
    MessageDlg('No TapeXUM device found', mtError, [mbOk], 0);
    Exit;
  end;

  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
