unit XUMInstaller.InstallerThread;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs;

type
  TXUMInstallComponent = (xiDriver, xiOpencbmLibraries, xiCbmxfer);
  TXUMInstallComponents = set of TXUMInstallComponent;

type
  TXUMInstallFinished = procedure(ASender: TObject; ASuccess: Boolean) of object;
  TXUMInstallLog = procedure(ASender: TObject; AMessage: String; AContinueMessage: Boolean) of object;

type
  TXUMInstaller = class(TThread)
  protected
    procedure Execute; override;
  private
    FDelayEvent: TSimpleEvent;
    FFormHandle: THandle;
    FWorkingDirectory: String;
    FOnInstallBegin: TNotifyEvent;
    FOnInstallFinished: TXUMInstallFinished;
    FOnInstallLog: TXUMInstallLog;
    FInstallComponents: TXUMInstallComponents;
    procedure Log(AMessage: String; AContinueMessage: Boolean = False);
    procedure LogFormat(AMessage: String; const AFormatArgs: array of const);

    procedure BeginInstallation;

    function InstallDriver: Boolean;
    function InstallOpenCBM: Boolean;
    function InstallCBMXfer: Boolean;
  public
    property OnInstallBegin: TNotifyEvent read FOnInstallBegin write FOnInstallBegin;
    property OnInstallFinished: TXUMInstallFinished read FOnInstallFinished write FOnInstallFinished;
    property OnInstallLog: TXUMInstallLog read FOnInstallLog write FOnInstallLog;

    constructor Create(const AFormHandle: THandle; const AInstallComponents: TXUMInstallComponents);
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.ShlObj,
  System.IOUtils,
  System.Types,
  System.Masks,
  System.StrUtils,
  Winapi.ShellAPI,
  System.IniFiles,
  Winapi.Messages,
  System.Win.Registry,
  libwdi;

const
  XUM1541_VID = $16D0;
  XUM1541_PID = $0504;

const
  INF_NAME = 'libusb_device.inf';

{ TXUMInstaller }

procedure TXUMInstaller.BeginInstallation;
begin
  TThread.Synchronize(nil, procedure
  begin
    OnInstallBegin(Self);
  end);
end;

constructor TXUMInstaller.Create(const AFormHandle: THandle; const AInstallComponents: TXUMInstallComponents);
begin
  inherited Create(True);
  FFormHandle := AFormHandle;
  FreeOnTerminate := True;
  FDelayEvent := TSimpleEvent.Create();
  FInstallComponents := AInstallComponents;
  FWorkingDirectory := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

destructor TXUMInstaller.Destroy;
begin
  FDelayEvent.Free;
  inherited;
end;

procedure TXUMInstaller.Execute;
var
  task_succeeded: Boolean;
begin
  BeginInstallation;

  task_succeeded := True;
  try
    if xiDriver in FInstallComponents then
      task_succeeded := InstallDriver;
    if not task_succeeded then Exit;

    if xiOpencbmLibraries in FInstallComponents then
      task_succeeded := InstallOpencbm;
    if not task_succeeded then Exit;

    if xiCbmxfer in FInstallComponents then
      task_succeeded := InstallCbmxfer;
    if not task_succeeded then Exit;

  finally
    TThread.Synchronize(nil, procedure
    begin
      OnInstallFinished(Self, task_succeeded);
    end);
  end;
end;

function TXUMInstaller.InstallOpenCBM: Boolean;

  function GetSpecialFolder(AFolderID: LongInt): String;
  var
    folderPath: PChar;
    idList: PItemIDList;
  begin
    Result := '';
    GetMem(folderPath, MAX_PATH);
    try
      if (SHGetSpecialFolderLocation(0, AFolderID, idList) = S_OK) then
      begin
        if SHGetPathFromIDList(idList, folderPath) then
          Result := IncludeTrailingPathDelimiter(String(folderPath));
      end;
    finally
      FreeMem(folderPath);
    end;
  end;

  function GetFiles(const APath, AMasks: String): TStringDynArray;
  var
    maskArray: TStringDynArray;
    predicate: TDirectory.TFilterPredicate;
  begin
    maskArray := SplitString(AMasks, ';');
    predicate :=
      function(const Path: string; const SearchRec: TSearchRec): Boolean
      var
        mask: String;
      begin
        for mask in MaskArray do
          if MatchesMask(SearchRec.Name, mask) then
            Exit(True);
        Exit(False);
      end;
    Result := TDirectory.GetFiles(APath, predicate);
  end;

  function GetOpenCbmDirectory(out APath: String): Boolean;
  var
    pf: String;
  begin
    Result := False;
    pf := GetSpecialFolder(CSIDL_PROGRAM_FILES);
    if pf.IsEmpty then Exit;

    Result := True;
    APath := TPath.Combine(pf, 'opencbm\');
  end;

  function GetSystemDirectory(out APath: String): Boolean;
  begin
    APath := GetSpecialFolder(CSIDL_SYSTEM);
    Result := not APath.IsEmpty;
  end;

const
  opencbm_conf_name = 'opencbm.conf';
  opencbm_xu1541_lib_name = 'opencbm-xu1541.dll';
  opencbm_xum1541_lib_name = 'opencbm-xum1541.dll';
  opencbm_tapexum_lib_name = 'opencbm-tapexum.dll';
var
  opencbm_pf_dir: String;
  files_list: TArray<String>;
  opencbm_files_dir: String;
  opencbm_file_path, opencbm_file_name: String;
  dest_file, dest_file_system: String;
  system_dir: String;
  ini_file: TMemIniFile;
  reg: TRegistry;
  path_env_var: String;
  dwReturnValue: DWORD;
begin
  Result := False;

  if not GetOpenCbmDirectory(opencbm_pf_dir) then Exit;
  if not GetSystemDirectory(system_dir) then Exit;

  if TDirectory.Exists(opencbm_pf_dir) then
    Log('OpenCBM directory already exists, files will be overwritten')
  else
  begin
    try
      TDirectory.CreateDirectory(opencbm_pf_dir);
    except
      on e: Exception do
      begin
        LogFormat('Error while creating OpenCBM directory: %s', [e.Message]);
        Exit;
      end;
    end;
  end;

  LogFormat('Copying OpenCBM files to %s', [opencbm_pf_dir]);
  opencbm_files_dir := TPath.Combine(FWorkingDirectory, 'opencbm\');
  files_list := GetFiles(opencbm_files_dir, '*.exe;*.dll');
  for opencbm_file_path in files_list do
  begin
    opencbm_file_name := TPath.GetFileName(opencbm_file_path);
    dest_file_system := '';
    dest_file := TPath.Combine(opencbm_pf_dir, opencbm_file_name);
    if TPath.GetExtension(opencbm_file_name).EndsWith('dll') then
      dest_file_system := TPath.Combine(system_dir, opencbm_file_name);
    try
      TFile.Copy(opencbm_file_path, dest_file, True);
      if not dest_file_system.IsEmpty then
        TFile.Copy(opencbm_file_path, dest_file_system, True);
    except
      on e: Exception do
      begin
        LogFormat('Error while copying OpenCBM file (%s): %s ', [opencbm_file_name, e.Message]);
        Exit;
      end;
    end;
  end;
  Log('OK!', True);

  dest_file_system := TPath.Combine(system_dir, opencbm_conf_name);
  LogFormat('Saving OpenCBM configuration to %s', [dest_file_system]);
  try
    ini_file := TMemIniFile.Create(dest_file_system);
    try
      ini_file.Clear;

      ini_file.WriteString('plugins', 'default', 'xum1541');
      ini_file.WriteString('xu1541', 'location', TPath.Combine(system_dir, opencbm_xu1541_lib_name));
      ini_file.WriteString('xum1541', 'location', TPath.Combine(system_dir, opencbm_xum1541_lib_name));
      ini_file.WriteString('tapexum', 'location', TPath.Combine(system_dir, opencbm_tapexum_lib_name));

      ini_file.UpdateFile;
    finally
      ini_file.Free;
    end;
  except
    on e: Exception do
    begin
      LogFormat('Error while saving OpenCBM configuration file: %s', [e.Message]);
      Exit;
    end;
  end;
  Log('OK!', True);

  Log('Adding OpenCBM directory to system PATH variable');
  try
    reg := TRegistry.Create(KEY_WRITE or KEY_READ);
    try
      reg.RootKey := HKEY_LOCAL_MACHINE;
      if reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', False) then
      begin
        path_env_var := '';
        if reg.ValueExists('PATH') then
          path_env_var := reg.ReadString('PATH');

        if not path_env_var.ToLower.Contains(opencbm_pf_dir.ToLower) then
        begin
          path_env_var := opencbm_pf_dir + ';' + path_env_var;
          reg.WriteString('PATH', path_env_var);

          dwReturnValue := 0;
          SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0,
            LPARAM(PChar('Environment')), SMTO_ABORTIFHUNG, 5000, @dwReturnValue);
        end;
      end;
    finally
      reg.Free;
    end;
  except
    on e: Exception do
      Log(e.Message);
  end;
  Log('OK!', True);

  Result := True;
end;

function TXUMInstaller.InstallCBMXfer: Boolean;
var
  setupPath: String;
  startupInfo: TStartupInfo;
  processInfo: TProcessInformation;
  returnCode: DWORD;
begin
  returnCode := WAIT_FAILED;

  Log('Installing CBMXfer: ');
  setupPath := TPath.Combine(FWorkingDirectory, 'cbmxfer.exe');

  FillChar(startupInfo, SizeOf(startupInfo), #0);
  startupInfo.cb := SizeOf(startupInfo);
  startupInfo.dwFlags := STARTF_USESHOWWINDOW;
  startupInfo.wShowWindow := SW_SHOWNORMAL;
  if CreateProcess(PChar(setupPath), PChar(setupPath + ' /SILENT'), nil, nil,
    False, NORMAL_PRIORITY_CLASS, nil, nil, startupInfo, processInfo) then
  begin
    WaitForSingleObject(processInfo.hProcess, INFINITE);
    GetExitCodeProcess(processInfo.hProcess, returnCode);
    if processInfo.hProcess <> 0 then
      CloseHandle(processInfo.hProcess);
    if processInfo.hThread <> 0 then
      CloseHandle(processInfo.hThread);
  end else
    Log('Failed to create installer process');

  case returnCode of
    0: Log('Setup completed', True);
    2, 5: Log('Setup was canceled by the user', True);
    else
      Log('Setup failed', True);
  end;
  Result := (returnCode = 0);
end;

function TXUMInstaller.InstallDriver: Boolean;
var
  r: Integer;
  list: pwdi_device_info;
  device: pwdi_device_info;
  cl_options: wdi_options_create_list;
  foundDevice: Boolean;
  sErrorMsg: String;
  pd_options: wdi_options_prepare_driver;
  install_options: wdi_options_install_driver;
  liberror: Boolean;
  driver_path: String;
  dev_count, dev_iter: Integer;
begin
  Result := False;

  Log('Please connect XUM1541/TapeXUM device...');

  foundDevice := False;
  cl_options.trim_whitespaces := True;
  cl_options.list_all := True;
  list := nil;
  liberror := False;

  while (not foundDevice) and (not Terminated) and (not liberror) do
  begin
    sErrorMsg := '';

    r := wdi_create_list(@list, @cl_options);
    case wdi_error(r) of
      WDI_SUCCESS:
        begin
          driver_path := TPath.Combine(TPath.GetTempPath, 'xum_driver_temp\');
          liberror := False;
          device := list;
          dev_count := 0;
          while (device <> nil) do
          begin
            if (device.vid = XUM1541_VID) and (device.pid = XUM1541_PID) then
              Inc(dev_count);
            device := device.next;
          end;
          if (dev_count = 0) then
            Continue;
          LogFormat('Found %d compatible devices', [dev_count]);

          device := list;
          dev_iter := 1;
          while (device <> nil) do
          begin
            if (device.vid = XUM1541_VID) and (device.pid = XUM1541_PID) then
            begin
              foundDevice := True;
              LogFormat('Installing %s at %s (%d/%d)', [String(device.driver), String(device.hardware_id), dev_iter, dev_count]);
              FillMemory(@pd_options, SizeOf(pd_options), 0);
              pd_options.driver_type := Ord(WDI_USER);
              if (wdi_prepare_driver(device, PUTF8Char(UTF8Encode(driver_path)), PUTF8Char(INF_NAME), @pd_options) = Ord(WDI_SUCCESS)) then
              begin
                FillMemory(@install_options, SizeOf(install_options), 0);
                install_options.aWnd := FFormHandle;
                install_options.pending_install_timeout := 120000;
                r := wdi_install_driver(device, PUTF8Char(UTF8Encode(driver_path)), PUTF8Char(INF_NAME), @install_options);
                if (r <> Ord(WDI_SUCCESS)) then
                begin
                  Log('FAILED!', True);
                  LogFormat('libwdi error: %s (%d)', [String(wdi_strerror(r)), Ord(r)]);
                  liberror := True;
                end else
                begin
                  Log('OK!', True);
                  Result := True;
                end;
              end;
              Inc(dev_iter);
            end;
            device := device.next;
          end;
          wdi_destroy_list(list);
        end;
      else
        sErrorMsg := String(wdi_strerror(r));
    end;

    if (not sErrorMsg.IsEmpty) then
    begin
      Log('Critical libwdi error: ' + sErrorMsg);
      Break;
    end;

    if not foundDevice then
      FDelayEvent.WaitFor(1000);
  end;
end;

procedure TXUMInstaller.Log(AMessage: String; AContinueMessage: Boolean = False);
begin
  TThread.Synchronize(nil, procedure
  begin
    FOnInstallLog(Self, AMessage, AContinueMessage);
  end);
end;

procedure TXUMInstaller.LogFormat(AMessage: String;
  const AFormatArgs: array of const);
var
  sMsg: String;
begin
  sMsg := Format(AMessage, AFormatArgs);
  TThread.Synchronize(nil, procedure
  begin
    FOnInstallLog(Self, sMsg, False);
  end);
end;

end.
