unit XUMInstaller.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, System.SyncObjs,
  Vcl.CheckLst, System.ImageList, Vcl.ImgList, Vcl.ExtCtrls, System.UITypes,
  XUMInstaller.InstallerThread;

type
  TMainForm = class(TForm)
    btnInstall: TButton;
    memLog: TMemo;
    cbInstallComponents: TCheckListBox;
    procedure btnInstallClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FXUMInstaller: TXUMInstaller;
    function GetInstallComponents: TXUMInstallComponents;
  public
    { Public declarations }
    procedure Log(ASender: TObject; AMessage: String; AContinueMessage: Boolean = False);

    procedure OnInstallBegin(ASender: TObject);
    procedure OnInstallFinished(ASender: TObject; ASuccess: Boolean);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  cbInstallComponents.CheckAll(cbChecked);
end;

procedure TMainForm.btnInstallClick(Sender: TObject);
begin
  FXUMInstaller := TXUMInstaller.Create(Self.Handle, GetInstallComponents);
  FXUMInstaller.OnInstallBegin := OnInstallBegin;
  FXUMInstaller.OnInstallFinished := OnInstallFinished;
  FXUMInstaller.OnInstallLog := Log;

  FXUMInstaller.Start;
end;

procedure TMainForm.OnInstallBegin(ASender: TObject);
begin
  btnInstall.Enabled := False;
  cbInstallComponents.Enabled := False;
  memLog.Clear;
end;

procedure TMainForm.OnInstallFinished(ASender: TObject; ASuccess: Boolean);
begin
  if ASuccess then
  begin
    if MessageDlg('Installation completed successfully, Do you want to read the log?',
      mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    begin
      MainForm.Close;
    end;
  end;
  btnInstall.Enabled := True;
  cbInstallComponents.Enabled := True;
end;

function TMainForm.GetInstallComponents: TXUMInstallComponents;
var
  i: Integer;
begin
  Result := [];
  for i := 0 to cbInstallComponents.Items.Count-1 do
    if cbInstallComponents.Checked[i] then
      Include(Result, TXUMInstallComponent(i));
end;

procedure TMainForm.Log(ASender: TObject; AMessage: String; AContinueMessage: Boolean);
begin
  if not AContinueMessage then
    memLog.Lines.Add(AMessage)
  else
    memLog.Lines[memLog.Lines.Count-1] := memLog.Lines[memLog.Lines.Count-1] + ' ' + AMessage;
end;

end.
