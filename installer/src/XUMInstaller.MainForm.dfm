object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'XUM1541/TapeXUM Installer for Windows 7/10 64-bit'
  ClientHeight = 374
  ClientWidth = 474
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  DesignSize = (
    474
    374)
  PixelsPerInch = 96
  TextHeight = 13
  object btnInstall: TButton
    Tag = 1
    Left = 145
    Top = 108
    Width = 187
    Height = 29
    Caption = 'Install'
    ElevationRequired = True
    TabOrder = 0
    OnClick = btnInstallClick
  end
  object memLog: TMemo
    AlignWithMargins = True
    Left = 8
    Top = 152
    Width = 458
    Height = 214
    Margins.Left = 8
    Margins.Right = 8
    Margins.Bottom = 8
    TabStop = False
    Align = alBottom
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = EASTEUROPE_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
    ExplicitWidth = 541
  end
  object cbInstallComponents: TCheckListBox
    Left = 8
    Top = 8
    Width = 458
    Height = 81
    Anchors = [akLeft, akTop, akRight]
    ItemHeight = 17
    Items.Strings = (
      'Device driver'
      'OpenCBM and NibTools'
      'CBMXfer (file transfer software for disk drives)')
    Style = lbOwnerDrawVariable
    TabOrder = 2
    ExplicitWidth = 541
  end
end
