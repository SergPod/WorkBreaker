unit mainform_rs;

{$mode Delphi}{$H+}

{
  WorkBreaker - a minimal break reminder.

  Lives in the system tray. Shows a borderless, always-on-top window
  in the centre of the primary monitor:
    - which break it is (Mini / Long)
    - a progress bar counting the break down
    - the remaining time in mm:ss

  No sounds, no ideas, no decorations. Settings are kept in an INI file.
}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Menus,
  LCLType, IniFiles, Windows, breakform_rs, settingsform_rs;


type

  { TMainForm }

  TMainForm = class(TForm)
    MenuSettings: TMenuItem;
    MenuNewMini: TMenuItem;
    MenuNewLong: TMenuItem;
    MenuSep1: TMenuItem;
    MenuSkip: TMenuItem;
    MenuPostpone: TMenuItem;
    MenuReset: TMenuItem;
    MenuSep2: TMenuItem;
    MenuPause: TMenuItem;
    MenuPause30: TMenuItem;
    MenuPause1h: TMenuItem;
    MenuPause2h: TMenuItem;
    MenuPauseInf: TMenuItem;
    MenuQuit: TMenuItem;
    TrayIcon: TTrayIcon;
    TrayMenu: TPopupMenu;
    Timer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure TimerTick(Sender: TObject);
    procedure TrayIconClick(Sender: TObject);
    procedure MenuNewMiniClick(Sender: TObject);
    procedure MenuNewLongClick(Sender: TObject);
    procedure MenuSkipClick(Sender: TObject);
    procedure MenuPostponeClick(Sender: TObject);
    procedure MenuResetClick(Sender: TObject);
    procedure MenuPause30Click(Sender: TObject);
    procedure MenuPause1hClick(Sender: TObject);
    procedure MenuPause2hClick(Sender: TObject);
    procedure MenuPauseInfClick(Sender: TObject);
    procedure MenuResumeClick(Sender: TObject);
    procedure MenuSettingsClick(Sender: TObject);
    procedure MenuQuitClick(Sender: TObject);
  private
    FIniPath: string;
    FPaused: Boolean;
    FPauseUntil: Int64;        // GetTickCount64 when pause ends (0 = indefinite)
    FMiniEnabled: Boolean;
    FLongEnabled: Boolean;
    FMiniInterval: Integer;   // sec between mini breaks
    FMiniDuration: Integer;   // sec
    FLongInterval: Integer;   // mini breaks between long breaks
    FLongDuration: Integer;   // sec
    FPostponeMini: Integer;   // sec
    FPostponeLong: Integer;
    FIdleLimitSec: Integer;   // idle threshold, sec
    FCountMini: Integer;      // mini breaks since the last long break
    FCountdown: Integer;      // sec until the next break
    FPostponing: Boolean;     // True while a postponed-break countdown runs
    function CurrentKind: TBreakKind;
    function PostponeFor(AKind: TBreakKind): Integer;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure UpdateMenu;
    procedure UpdateHint;
    procedure ShowBreak(AKind: TBreakKind);

    procedure StartNextCountdown;
    procedure IdleReset;
  public
    procedure BreakFinished(Sender: TObject);
    //constructor CreateMain(AOwner: TComponent);
    procedure Reconfigure;
  end;

var
  TrayApp: TMainForm;

implementation

//uses breakform_rs, settingsform_rs;

{$R *.lfm}

const
  CIniName     = 'WorkBreaker.ini';
  CSection = 'Settings';
  CMiniEnabled   = 'MiniEnabled';
  CMiniInterval  = 'MiniInterval';
  CMiniDuration  = 'MiniDuration';
  CLongEnabled   = 'LongEnabled';
  CLongInterval  = 'LongInterval';
  CLongDuration  = 'LongDuration';
  CPostponeMini  = 'PostponeMini';
  CPostponeLong  = 'PostponeLong';
  CIdleLimit     = 'IdleLimit';
  CPaused        = 'Paused';


type
  // Win32 LASTINPUTINFO (not declared by the FPC Windows unit).
  TLastInputInfo = packed record
    cbSize: DWORD;
    ulLastInput: DWORD;
  end;

  // Real Win32 prototype: BOOL GetLastInputInfo(LPLASTINPUTINFO) -
  // the record is passed BY POINTER. A "var" parameter in an
  // "external 'user32'" declaration is passed BY VALUE by FPC, which
  // makes Win32 treat the record contents as an address -> AV.
  TGetLastInputInfo = function (plii: Pointer): BOOL; cdecl;

var
  FnGetLastInputInfo: TGetLastInputInfo;

function IdleInfoAvailable: Boolean;
var
  Lib: HMODULE;
begin
  if not Assigned(FnGetLastInputInfo) then
  begin
    Lib := LoadLibrary('user32'{$IFDEF UNICODE}W{$ENDIF});
    if Lib <> 0 then
    begin
      FnGetLastInputInfo := TGetLastInputInfo(GetProcAddress(Lib, PChar('GetLastInputInfo')));
      // user32 stays loaded for the whole lifetime of the process,
      // so the handle is intentionally not freed.
    end;
  end;
  Result := Assigned(FnGetLastInputInfo);
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
   ShowInTaskBar := stNever;
   BorderIcons := [];
   Position := poDesigned;
{
   MenuNewMini := TMenuItem.Create(Self);
   MenuNewMini.Caption := 'New mini break';
   MenuNewMini.OnClick := MenuNewMiniClick;
   TrayMenu.Items.Add(MenuNewMini);

   MenuNewLong := TMenuItem.Create(Self);
   MenuNewLong.Caption := 'New long break';
   MenuNewLong.OnClick := MenuNewLongClick;
   TrayMenu.Items.Add(MenuNewLong);

   MenuSep1 := TMenuItem.Create(Self);
   MenuSep1.Caption := '-';
   TrayMenu.Items.Add(MenuSep1);

   MenuSkip := TMenuItem.Create(Self);
   MenuSkip.Caption := 'Skip current break';
   MenuSkip.OnClick := MenuSkipClick;
   TrayMenu.Items.Add(MenuSkip);

   MenuPostpone := TMenuItem.Create(Self);
   MenuPostpone.Caption := 'Postpone current break';
   MenuPostpone.OnClick := MenuPostponeClick;
   TrayMenu.Items.Add(MenuPostpone);

   MenuReset := TMenuItem.Create(Self);
   MenuReset.Caption := 'Reset break counter';
   MenuReset.OnClick := MenuResetClick;
   TrayMenu.Items.Add(MenuReset);

   MenuSep2 := TMenuItem.Create(Self);
   MenuSep2.Caption := '-';
   TrayMenu.Items.Add(MenuSep2);

   MenuPause := TMenuItem.Create(Self);
   MenuPause.Caption := 'Pause breaks';
   TrayMenu.Items.Add(MenuPause);

   MenuSettings := TMenuItem.Create(Self);
   MenuSettings.Caption := 'Settings';
   MenuSettings.OnClick := MenuSettingsClick;
   TrayMenu.Items.Add(MenuSettings);

   MenuQuit := TMenuItem.Create(Self);
   MenuQuit.Caption := 'Quit';
   MenuQuit.OnClick := MenuQuitClick;
   TrayMenu.Items.Add(MenuQuit);      }

   MenuPause30 := TMenuItem.Create(Self);
   MenuPause30.Caption := 'For 30 minutes';
   MenuPause30.OnClick := MenuPause30Click;
   MenuPause.Add(MenuPause30);

   MenuPause1h := TMenuItem.Create(Self);
   MenuPause1h.Caption := 'For 1 hour';
   MenuPause1h.OnClick := MenuPause1hClick;
   MenuPause.Add(MenuPause1h);

   MenuPause2h := TMenuItem.Create(Self);
   MenuPause2h.Caption := 'For 2 hours';
   MenuPause2h.OnClick := MenuPause2hClick;
   MenuPause.Add(MenuPause2h);

   MenuPauseInf := TMenuItem.Create(Self);
   MenuPauseInf.Caption := 'Until resumed';
   MenuPauseInf.OnClick := MenuPauseInfClick;
   MenuPause.Add(MenuPauseInf);


   Timer := TTimer.Create(Self);
   Timer.Interval := 1000;
   Timer.OnTimer := TimerTick;

   FIniPath := GetAppConfigDir(False) + CIniName;
   FCountMini := 0;

   TrayIcon.PopUpMenu := TrayMenu;
   TrayIcon.OnClick := TrayIconClick;

   LoadSettings;
   UpdateMenu;

   TrayIcon.Visible := True;
   Timer.Enabled := True;

   if FMiniEnabled or FLongEnabled then
     StartNextCountdown
   else
     FCountdown := 0;

   //Hide;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // The tray menu "Quit" calls Application.Terminate, which does not go
  // through CloseQuery - so blocking it here is safe.
  CanClose := False;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Timer.Enabled := False;
 { if FBreakForm <> nil then
  begin
    FBreakForm.OnFinish := nil;
    FBreakForm.Free;
    FBreakForm := nil;
  end;
  if FTrayIco <> 0 then
  begin
    DestroyIcon(FTrayIco);
    FTrayIco := 0;
  end;
  TrayIcon.Visible := False;}
  SaveSettings;
end;

procedure TMainForm.LoadSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FIniPath);
  try
    FMiniEnabled   := Ini.ReadBool(CSection, CMiniEnabled, True);
    FMiniInterval  := Ini.ReadInteger(CSection, CMiniInterval, 600);
    FMiniDuration  := Ini.ReadInteger(CSection, CMiniDuration, 20);
    FLongEnabled   := Ini.ReadBool(CSection, CLongEnabled, True);
    FLongInterval  := Ini.ReadInteger(CSection, CLongInterval, 2);
    FLongDuration  := Ini.ReadInteger(CSection, CLongDuration, 300);
    FPostponeMini  := Ini.ReadInteger(CSection, CPostponeMini, 120);
    FPostponeLong  := Ini.ReadInteger(CSection, CPostponeLong, 300);
    // INI stores minutes; convert to seconds internally
    FIdleLimitSec  := Ini.ReadInteger(CSection, CIdleLimit, 5) * 60;
    if FIdleLimitSec < 60 then FIdleLimitSec := 60;  // min 1 min
    // Always start unpaused - pause state is not persisted across restarts.
    FPaused := False;
    FPauseUntil := 0;
  finally
    Ini.Free;
  end;
end;

procedure TMainForm.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FIniPath);
  try
    Ini.WriteBool(CSection, CMiniEnabled, FMiniEnabled);
    Ini.WriteInteger(CSection, CMiniInterval, FMiniInterval);
    Ini.WriteInteger(CSection, CMiniDuration, FMiniDuration);
    Ini.WriteBool(CSection, CLongEnabled, FLongEnabled);
    Ini.WriteInteger(CSection, CLongInterval, FLongInterval);
    Ini.WriteInteger(CSection, CLongDuration, FLongDuration);
    Ini.WriteInteger(CSection, CPostponeMini, FPostponeMini);
    Ini.WriteInteger(CSection, CPostponeLong, FPostponeLong);
    Ini.WriteInteger(CSection, CIdleLimit, FIdleLimitSec div 60);
  finally
    Ini.Free;
  end;
end;

function SecToStr(ASec: Integer): string;
begin
  Result := Format('%.2d:%.2d', [ASec div 60, ASec mod 60]);
end;

function TMainForm.CurrentKind: TBreakKind;
begin
  Result := bkNone;
  if BreakForm = nil then Exit;
  Result := BreakForm.Kind;
end;

function TMainForm.PostponeFor(AKind: TBreakKind): Integer;
begin
  if AKind = bkLong then Result := FPostponeLong else Result := FPostponeMini;
end;

procedure TMainForm.UpdateHint;
begin
  if CurrentKind <> bkNone then
    TrayIcon.Hint := 'WorkBreaker - break ' + SecToStr(BreakForm.LeftSec)
  else
  if FPaused then
    TrayIcon.Hint := 'WorkBreaker - paused'
  else
    TrayIcon.Hint := 'WorkBreaker - next break in ' + SecToStr(FCountdown);
end;

procedure TMainForm.UpdateMenu;
var
  InBreak: Boolean;
begin
  InBreak := CurrentKind <> bkNone;
  if FPaused then
  begin
    MenuPause.Caption := 'Resume breaks';
    MenuPause.OnClick := MenuResumeClick;
    // Hide submenu items when paused
    MenuPause30.Visible := False;
    MenuPause1h.Visible := False;
    MenuPause2h.Visible := False;
    MenuPauseInf.Visible := False;
  end
  else
  begin
    MenuPause.Caption := 'Pause breaks';
    MenuPause.OnClick := nil;
    // Show submenu items
    MenuPause30.Visible := True;
    MenuPause1h.Visible := True;
    MenuPause2h.Visible := True;
    MenuPauseInf.Visible := True;
  end;
  MenuPause.Enabled := not InBreak;
  MenuSkip.Enabled := InBreak;
  MenuPostpone.Enabled := InBreak and (not BreakForm.Postponed);
  MenuNewMini.Enabled := not (InBreak or FPostponing);
  MenuNewLong.Enabled := not (InBreak or FPostponing);
end;

procedure TMainForm.ShowBreak(AKind: TBreakKind);
begin
  BreakForm.PostponeSec := PostponeFor(AKind);
  if AKind = bkLong then
    BreakForm.Start(FLongDuration, AKind)
  else
    BreakForm.Start(FMiniDuration, AKind);
  UpdateMenu;
end;

procedure TMainForm.StartNextCountdown;
begin
  FPostponing := False;
  FCountdown := FMiniInterval;
end;

{ The break window is gone. If it was postponed, the countdown is set to the
  postpone interval and FPostponing flags that state; otherwise a normal
  countdown starts. }
procedure TMainForm.BreakFinished(Sender: TObject);
var
  Postponed: Boolean;
begin
  // Capture BEFORE Hide - afterwards we cannot tell why the window closed.
  Postponed := BreakForm.Postponed and (not BreakForm.Visible);
  BreakForm.Hide; // the form is reused, not freed
  // The break session is over: clear the kind so CurrentKind = bkNone.
  // Without this InBreak stays True forever - the tray menu gets stuck
  // (New mini/long disabled, Skip/Postpone enabled) and TimerTick keeps
  // calling BreakForm.Tick -> OnFinish -> BreakFinished every second,
  // resetting FCountdown to FMiniInterval so the next break never fires.
  BreakForm.Kind := bkNone;
  FPostponing := Postponed;
  if Postponed then
    FCountdown := BreakForm.PostponeSec
  else
  if FMiniEnabled or FLongEnabled then
    StartNextCountdown
  else
    FCountdown := 0;
  UpdateMenu;
end;

procedure TMainForm.IdleReset;
var
  Info: TLastInputInfo;
  Idle: Cardinal;
begin
  if not IdleInfoAvailable then Exit;
  Info.cbSize := SizeOf(Info);
  Info.ulLastInput := 0;
  if FnGetLastInputInfo(@Info) then
  begin
    Idle := GetTickCount - Info.ulLastInput; // wraps safely, unsigned math
    if Idle > Cardinal(FIdleLimitSec) * 1000 then
      FCountdown := FMiniInterval;
  end;
end;

procedure TMainForm.TimerTick(Sender: TObject);
begin
  if CurrentKind <> bkNone then
  begin
    BreakForm.Tick;
    UpdateHint;
    Exit;
  end;

  if FPaused then
  begin
    // Check if timed pause has expired
    if FPauseUntil > 0 then
    begin
      if GetTickCount64 - FPauseUntil >= 0 then
      begin
        FPaused := False;
        FPauseUntil := 0;
        StartNextCountdown;
        UpdateMenu;
        SaveSettings;
      end;
    end;
    UpdateHint;
    Exit;
  end;

  IdleReset;

  if FCountdown > 0 then
  begin
    Dec(FCountdown);
    if FPostponing and (FCountdown = 0) then
      FPostponing := False; // postponed interval elapsed - menu unlocks
    UpdateHint;
    Exit;
  end;

  // time for a break
  if FLongEnabled and (FCountMini >= FLongInterval) then
  begin
    // Reset BEFORE showing: without this FCountMini keeps growing and
    // every subsequent break becomes long forever.
    FCountMini := 0;
    ShowBreak(bkLong)
  end
  else
  if FMiniEnabled then
  begin
    Inc(FCountMini);
    ShowBreak(bkMini);
  end
  else
    StartNextCountdown;
end;

procedure TMainForm.TrayIconClick(Sender: TObject);
begin
  // NOTE: Cannot use TrayMenu.Popup() here because it is NOT modal in LCL.
  // Popup() blocks execution until menu closes, but the modal loop is broken
  // when Escape is pressed or click outside, causing the menu to remain visible.
  // The correct way is to let TTrayIcon handle the popup automatically via PopUpMenu property.
end;

procedure TMainForm.MenuNewMiniClick(Sender: TObject);
begin
  if FPostponing then Exit; // a postponed break is already scheduled
  ShowBreak(bkMini);
end;

procedure TMainForm.MenuNewLongClick(Sender: TObject);
begin
  if FPostponing then Exit; // a postponed break is already scheduled
  ShowBreak(bkLong);
end;

procedure TMainForm.MenuSkipClick(Sender: TObject);
begin
  if CurrentKind <> bkNone then BreakFinished(nil);
end;

procedure TMainForm.MenuPostponeClick(Sender: TObject);
begin
  if CurrentKind <> bkNone then
    BreakForm.Postpone; // hides the window and calls BreakFinished
end;

procedure TMainForm.MenuResetClick(Sender: TObject);
begin
  FCountMini := 0;
  StartNextCountdown;
end;

procedure TMainForm.MenuPause30Click(Sender: TObject);
begin
  FPaused := True;
  FPauseUntil := GetTickCount64 + 30 * 60 * 1000;
  UpdateMenu;
  SaveSettings;
end;

procedure TMainForm.MenuPause1hClick(Sender: TObject);
begin
  FPaused := True;
  FPauseUntil := GetTickCount64 + 60 * 60 * 1000;
  UpdateMenu;
  SaveSettings;
end;

procedure TMainForm.MenuPause2hClick(Sender: TObject);
begin
  FPaused := True;
  FPauseUntil := GetTickCount64 + 2 * 60 * 60 * 1000;
  UpdateMenu;
  SaveSettings;
end;

procedure TMainForm.MenuPauseInfClick(Sender: TObject);
begin
  FPaused := True;
  FPauseUntil := 0; // indefinite
  UpdateMenu;
  SaveSettings;
end;

procedure TMainForm.MenuResumeClick(Sender: TObject);
begin
  FPaused := False;
  FPauseUntil := 0;
  StartNextCountdown;
  UpdateMenu;
  SaveSettings;
end;

procedure TMainForm.MenuSettingsClick(Sender: TObject);
begin
  with SettingsForm do
  begin
    // Load current values (convert sec -> min for interval/duration)
     MiniDurationSec := FMiniDuration;
     MiniIntervalMin := FMiniInterval div 60;
    if  MiniIntervalMin < 1 then  MiniIntervalMin := 1;
     LongDurationMin := FLongDuration div 60;
    if  LongDurationMin < 1 then  LongDurationMin := 1;
     LongAfterCount := FLongInterval;
     IdleLimitMin := FIdleLimitSec div 60;
    if  IdleLimitMin < 1 then  IdleLimitMin := 1;

    if  ShowModal = mrOK then
    begin
      FMiniDuration :=  MiniDurationSec;
      FMiniInterval :=  MiniIntervalMin * 60;
      FLongDuration :=  LongDurationMin * 60;
      FLongInterval :=  LongAfterCount;
      FIdleLimitSec := IdleLimitMin * 60;
      SaveSettings;
      if not FPaused then StartNextCountdown;
    end;
  end;
end;

procedure TMainForm.MenuQuitClick(Sender: TObject);
begin
  Application.Terminate;  //??
end;

procedure TMainForm.Reconfigure;
begin
  SaveSettings;
  if not FPaused then StartNextCountdown;
end;

end.
