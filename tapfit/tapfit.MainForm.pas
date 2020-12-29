unit tapfit.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls;

type
  CBM_FILE = THandle;
  PCBM_FILE = ^CBM_FILE;
const
  CBM_FILE_INVALID: CBM_FILE = THandle(-1);

type
  opencbm_usb_handle = record
    ctx: Pointer;  //libusb_context
    devh: Pointer; //libusb_device_handle
  end;
  popencbm_usb_handle = ^opencbm_usb_handle;

type
  TMainForm = class(TForm)
    HeadFitPanel: TPanel;
    HeadFitPaintBox: TPaintBox;
    Label1: TLabel;
    PaintDataTimer: TTimer;
    CloseTimer: TTimer;
    ButtonClearCapData: TButton;
    procedure FormCreate(Sender: TObject);
    procedure HeadFitPaintBoxPaint(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintDataTimerTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CloseTimerTimer(Sender: TObject);
    procedure ButtonClearCapDataClick(Sender: TObject);
  private
    { Private declarations }
    FMaxLines: UInt;
    FLineStart: UInt;
    FLineEnd: UInt;
    FLineIter: UInt;
    FHeadfitHeaderBitmap: TBitmap;
    FPulseBitmap: TBitmap;
    FirstHW: Boolean;
    FTapeBuffer: Pointer;
    FStreaming, FAborted: Boolean;
  public
    { Public declarations }
    procedure OnCaptureBuffer;
    procedure HeadFit;
    procedure ClearCapData;
  end;

var
  MainForm: TMainForm;

var
  g_DeviceHandle: CBM_FILE;
var
  g_cap_buffer_offset: Pointer;
  g_cap_buffer_len: NativeUInt;
  g_cap_buffer_left_previous: NativeUInt = 0;
  g_cap_ui64Abs: UInt64;

function ConnectTapeXUM: Boolean;

implementation

uses
  System.IOUtils;

{$R *.dfm}

// Tape status values (must match xum1541 firmware values in xum1541.h)
const
  Tape_Status_OK                              = 1;
  Tape_Status_OK_Tape_Device_Present          = (Tape_Status_OK + 1);
  Tape_Status_OK_Tape_Device_Not_Present      = (Tape_Status_OK + 2);
  Tape_Status_OK_Device_Configured_for_Read   = (Tape_Status_OK + 3);
  Tape_Status_OK_Device_Configured_for_Write  = (Tape_Status_OK + 4);
  Tape_Status_OK_Sense_On_Play                = (Tape_Status_OK + 5);
  Tape_Status_OK_Sense_On_Stop                = (Tape_Status_OK + 6);
  Tape_Status_OK_Motor_On                     = (Tape_Status_OK + 7);
  Tape_Status_OK_Motor_Off                    = (Tape_Status_OK + 8);
  Tape_Status_OK_Capture_Finished             = (Tape_Status_OK + 9);
  Tape_Status_OK_Write_Finished               = (Tape_Status_OK + 10);
  Tape_Status_OK_Config_Uploaded              = (Tape_Status_OK + 11);
  Tape_Status_OK_Config_Downloaded            = (Tape_Status_OK + 12);
  Tape_Status_OK_Saving_File                  = (Tape_Status_OK + 50);
  Tape_Status_ERROR                           = 255;
  Tape_Status_ERROR_Device_Disconnected       = (Tape_Status_ERROR - 1);
  Tape_Status_ERROR_Device_Not_Configured     = (Tape_Status_ERROR - 2);
  Tape_Status_ERROR_Sense_Not_On_Record       = (Tape_Status_ERROR - 3);
  Tape_Status_ERROR_Sense_Not_On_Play         = (Tape_Status_ERROR - 4);
  Tape_Status_ERROR_Write_Interrupted_By_Stop = (Tape_Status_ERROR - 5);
  Tape_Status_ERROR_usbSendByte               = (Tape_Status_ERROR - 6);
  Tape_Status_ERROR_usbRecvByte               = (Tape_Status_ERROR - 7);
  Tape_Status_ERROR_External_Break            = (Tape_Status_ERROR - 8);
  Tape_Status_ERROR_Wrong_Tape_Firmware       = (Tape_Status_ERROR - 9); // Not returned by firmware.

// Signal edge definitions.
const
  XUM1541_TAP_WRITE_STARTFALLEDGE = $20; // start writing with falling edge (1 = true)
  XUM1541_TAP_READ_STARTFALLEDGE  = $40; // start reading with falling edge (1 = true)
  XUM1541_TAP_STOP_ON_SENSE       = $01; // stop capture/write if STOP was pressed (1 = true)

type
  tapexum_config = record
    tsr: Byte;
    auto_stop: Byte;
    write_serial: Byte;
    device_serial: Byte;
  end;
  ptapexum_config = ^tapexum_config;

function cbm_driver_open_ex(f: PCBM_FILE; const adapter: PUTF8Char): Integer; cdecl; external 'opencbm.dll';
procedure cbm_driver_close(f: CBM_FILE); cdecl; external 'opencbm.dll';

type
  cbm_tap_capture_callback_t = procedure (Buffer: Pointer; Buffer_Length: Cardinal); cdecl;
  cbm_tap_write_callback_t = procedure (Buffer_Position: Cardinal; Buffer_Length: Cardinal); cdecl;

function cbm_tap_prepare_capture(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_prepare_write(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_get_sense(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_wait_for_stop_sense(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_wait_for_play_sense(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_start_capture(f: CBM_FILE; Buffer: PByte; Buffer_Length: Cardinal; var Status: Integer; out BytesRead: Integer; ReadCallback: cbm_tap_capture_callback_t): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_start_write(f: CBM_FILE; Buffer: PByte; Length: Cardinal; var Status: Integer; out BytesWritten: Integer; WriteCallback: cbm_tap_write_callback_t): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_motor_on(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_motor_off(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_get_ver(f: CBM_FILE; var Status: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_download_config(f: CBM_FILE; Buffer: PByte; Buffer_Length: Cardinal; var Status: Integer; out BytesRead: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_upload_config(f: CBM_FILE; Buffer: PByte; ConfigLength: Integer; var Status: Integer; out BytesWritten: Integer): Integer; cdecl; external 'opencbm.dll';
function cbm_tap_break(f: CBM_FILE): Integer; cdecl; external 'opencbm.dll';

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  i, j: Integer;
  iXDelta: Integer;
begin
  FTapeBuffer := nil;

  MainForm.DoubleBuffered := True;

  HeadFitPaintBox.Canvas.Brush.Color := clWhite;
  HeadFitPaintBox.Canvas.Brush.Style := bsSolid;
  HeadFitPaintBox.Canvas.Font.Color := clWhite;
  HeadFitPaintBox.Canvas.Pen.Color := clWhite;

  FHeadfitHeaderBitmap := TBitmap.Create;
  FHeadfitHeaderBitmap.PixelFormat := pfDevice;
  FHeadfitHeaderBitmap.SetSize(HeadFitPaintBox.ClientWidth, HeadFitPaintBox.ClientHeight);
  FHeadfitHeaderBitmap.Canvas.Brush.Color := clBlack;
  FHeadfitHeaderBitmap.Canvas.Brush.Style := bsSolid;
  FHeadfitHeaderBitmap.Canvas.FillRect(FHeadfitHeaderBitmap.Canvas.ClipRect);

  FPulseBitmap := TBitmap.Create;
  FPulseBitmap.PixelFormat := pfDevice;
  FPulseBitmap.SetSize(HeadFitPaintBox.ClientWidth, HeadFitPaintBox.ClientHeight*2);
  FPulseBitmap.Canvas.Brush.Color := clBlack;
  FPulseBitmap.Canvas.Brush.Style := bsSolid;
  FPulseBitmap.Canvas.Brush.Color := clBlack;
  FPulseBitmap.Canvas.Brush.Style := bsSolid;
  FPulseBitmap.Canvas.FillRect(FPulseBitmap.Canvas.ClipRect);
  SetBkMode(FPulseBitmap.Canvas.Handle, TRANSPARENT);

  SetTextColor(FHeadfitHeaderBitmap.Canvas.Handle, $00FFFFFF);
  SetBkMode(FHeadfitHeaderBitmap.Canvas.Handle, TRANSPARENT);
  iXDelta := (HeadFitPaintBox.Width-(HeadFitPaintBox.Width mod 100)) div 10 div 2;
  for i := 0 to 9 do
  begin
    for j := 0 to HeadFitPaintBox.Height-1 do
    begin
      if (j mod 3 = 0) then
        SetPixel(FHeadfitHeaderBitmap.Canvas.Handle, iXDelta+i*2*iXDelta, j, $0000009F);
      SetPixel(FHeadfitHeaderBitmap.Canvas.Handle, 2*iXDelta*(i+1), j, $000000FF);
    end;
  end;

  ClearCapData;

  TThread.CreateAnonymousThread(procedure
  begin
    HeadFit;
  end).Start;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FPulseBitmap.Free;
  FHeadfitHeaderBitmap.Free;
  if g_DeviceHandle <> 0 then
    cbm_driver_close(g_DeviceHandle);
  if Assigned(FTapeBuffer) then
    FreeMemory(FTapeBuffer);
end;

procedure TMainForm.CloseTimerTimer(Sender: TObject);
begin
  if not FStreaming then
    Close;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  FAborted := True;
  if FStreaming then
  begin
    cbm_tap_break(g_DeviceHandle);
    ButtonClearCapData.Enabled := False;
    CloseTimer.Enabled := True;
    CanClose := False;
  end;
end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (key = VK_ESCAPE) then
    Close;
end;

procedure TMainForm.ButtonClearCapDataClick(Sender: TObject);
begin
  ClearCapData;
end;

procedure TMainForm.ClearCapData;
begin
  FirstHW := True;
  g_cap_ui64Abs := 0;

  FMaxLines := HeadFitPaintBox.Height;
  FLineStart := 0;
  FLineEnd := FMaxLines;
  FLineIter := 0;

  FPulseBitmap.Canvas.FillRect(FPulseBitmap.Canvas.ClipRect);
  HeadFitPaintBox.Invalidate;
end;

procedure TMainForm.HeadFitPaintBoxPaint(Sender: TObject);
begin
  HeadFitPaintBox.Canvas.CopyMode := cmSrcCopy;
  HeadFitPaintBox.Canvas.CopyRect(HeadFitPaintBox.Canvas.ClipRect, FHeadfitHeaderBitmap.Canvas, FHeadfitHeaderBitmap.Canvas.ClipRect);
  HeadFitPaintBox.Canvas.CopyMode := cmSrcPaint;
  HeadFitPaintBox.Canvas.CopyRect(HeadFitPaintBox.Canvas.ClipRect, FPulseBitmap.Canvas, HeadFitPaintBox.Canvas.ClipRect);

  HeadFitPaintBox.Canvas.Font.Color := clWhite;
end;

procedure TMainForm.PaintDataTimerTimer(Sender: TObject);
begin
  HeadFitPaintBox.Invalidate;
end;

procedure capture_callback(Buffer: Pointer; Buffer_Length: Cardinal); cdecl;
begin
  g_cap_buffer_offset := Pointer(NativeUInt(Buffer) - g_cap_buffer_left_previous);
  g_cap_buffer_len := Buffer_Length + g_cap_buffer_left_previous;

  TThread.Synchronize(nil, MainForm.OnCaptureBuffer);
end;

function ConnectTapeXUM: Boolean;
var
  adapter: String;
begin
  Result := False;

  adapter := 'tapexum';
  if cbm_driver_open_ex(@g_DeviceHandle, PUTF8Char(UTF8Encode(adapter))) = 0 then
    Result := True
  else
    g_DeviceHandle := 0;
end;

procedure TMainForm.HeadFit;
var
  status: Integer;
  read_config, read_config2: tapexum_config;
  bytes_read, bytes_written: Integer;
  tapeBufferSize: Integer;
begin
  FStreaming := False;
  FAborted := False;

  read_config.TSR := XUM1541_TAP_READ_STARTFALLEDGE;
  read_config.auto_stop := 0;
  read_config.write_serial := 0;
  read_config.device_serial := 0;

  bytes_written := 0;
  tapeBufferSize := 1024*1024*100; // 100 MB
  FTapeBuffer := GetMemory(tapeBufferSize);
  ZeroMemory(FTapeBuffer, tapeBufferSize);

  cbm_tap_upload_config(g_DeviceHandle, @read_config, SizeOf(tapexum_config), status, bytes_written);
  if (status = Tape_Status_OK_Config_Uploaded) then
  begin
    cbm_tap_download_config(g_DeviceHandle, @read_config2, SizeOf(tapexum_config), status, bytes_read);
    if (Status = Tape_Status_OK_Config_Downloaded) and ((read_config.tsr and $60) = (read_config2.tsr and $60)) then
    begin
      cbm_tap_prepare_capture(g_DeviceHandle, status);
      if (Status = Tape_Status_OK_Device_Configured_for_Read) then
      begin
        FStreaming := True;
        try
          cbm_tap_wait_for_play_sense(g_DeviceHandle, status);
          TThread.Synchronize(nil, procedure
          begin
            ClearCapData;
          end);
          if not FAborted then
            cbm_tap_start_capture(g_DeviceHandle, FTapeBuffer, tapeBufferSize, status, bytes_read, @capture_callback);
        finally
          FStreaming := False;
        end;
      end;
    end;
  end;
end;

procedure TMainForm.OnCaptureBuffer;
const
  MSperLine = 25;
  Timer_Precision_MHz = 1;
var
  canBeSignal: Boolean;
  remainCurrent: Integer;
  ui32Line, ui32Len: UInt;
  ui64Rel, ui64Len, ui64Delta: UInt64;
  ui64Offset: UInt64;
  Source, Dest: TRect;
  drawIndex: Integer;
begin
  ui64Offset := 0;
  remainCurrent := g_cap_buffer_len;
  canBeSignal := remainCurrent >= 2;

  while canBeSignal do
  begin
    ui64Delta := PByte(NativeUInt(g_cap_buffer_offset)+ui64Offset)^;
    ui64Delta := (ui64Delta shl 8) + PByte(NativeUInt(g_cap_buffer_offset)+ui64Offset+1)^;
    if (ui64Delta < $8000) then
    begin
      ui64Delta := (ui64Delta + 8) shr 4; // downscale by 16
      Inc(ui64Offset, 2);
      Dec(remainCurrent, 2);
    end else if (remainCurrent >= 5) then
    begin
      ui64Delta := ui64Delta and $7fff;
      ui64Delta := (ui64Delta shl 8) + PByte(NativeUInt(g_cap_buffer_offset)+ui64Offset+2)^;
      ui64Delta := (ui64Delta shl 8) + PByte(NativeUInt(g_cap_buffer_offset)+ui64Offset+3)^;
      ui64Delta := (ui64Delta shl 8) + PByte(NativeUInt(g_cap_buffer_offset)+ui64Offset+4)^;
      ui64Delta := (ui64Delta + 8) shr 4; // downscale by 16
      Inc(ui64Offset, 5);
      Dec(remainCurrent, 5);
    end else
      Break;

    FirstHW := not FirstHW;
    g_cap_ui64Abs := g_cap_ui64Abs + ui64Delta;
    ui64Rel := ui64Delta div Timer_Precision_MHz;
    if (ui64Rel < 1000) then
    begin
      ui64Len := g_cap_ui64Abs div Timer_Precision_MHz;
      ui32Line := ui64Len div 1000 div MSperLine;
      ui32Len := ui64Rel;

      if FirstHW then
      begin
        if ui32Line > (FMaxLines*(FLineIter+1)) then
          Inc(FLineIter);
        if (FLineEnd < ui32Line) and (ui32Line > FMaxLines) then
        begin
          FLineEnd := ui32Line;
          Source := Rect(0, 0, MainForm.FPulseBitmap.Width, FPulseBitmap.Height);
          Dest := Source;
          Dest.Offset(0, -1);
          FPulseBitmap.Canvas.CopyRect(Dest, FPulseBitmap.Canvas, Source);
        end;
        drawIndex := ui32Line-(FMaxLines*FLineIter);

        if FLineIter > 0 then
          SetPixel(FPulseBitmap.Canvas.Handle, ui32Len, FMaxLines, $0000FF00)
        else
          SetPixel(FPulseBitmap.Canvas.Handle, ui32Len, drawIndex, $0000FF00);
      end;
    end;

    canBeSignal := remainCurrent >= 2;
  end;
  g_cap_buffer_left_previous := remainCurrent;
end;

end.
