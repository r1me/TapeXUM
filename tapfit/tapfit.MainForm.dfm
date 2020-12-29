object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'tapfit'
  ClientHeight = 454
  ClientWidth = 453
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyUp = FormKeyUp
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 123
    Height = 13
    Caption = 'Press ESC to quit tapfit...'
  end
  object HeadFitPanel: TPanel
    Left = 0
    Top = 39
    Width = 453
    Height = 415
    Align = alBottom
    Caption = 'HeadFitPanel'
    Color = clBlack
    ParentBackground = False
    ShowCaption = False
    TabOrder = 0
    object HeadFitPaintBox: TPaintBox
      Left = 1
      Top = 1
      Width = 451
      Height = 413
      Align = alClient
      Color = clBlack
      ParentColor = False
      OnPaint = HeadFitPaintBoxPaint
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 498
      ExplicitHeight = 85
    end
  end
  object ButtonClearCapData: TButton
    Left = 370
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Clear'
    TabOrder = 1
    TabStop = False
    OnClick = ButtonClearCapDataClick
  end
  object PaintDataTimer: TTimer
    Interval = 40
    OnTimer = PaintDataTimerTimer
    Left = 337
    Top = 24
  end
  object CloseTimer: TTimer
    Enabled = False
    Interval = 150
    OnTimer = CloseTimerTimer
    Left = 328
    Top = 91
  end
end
