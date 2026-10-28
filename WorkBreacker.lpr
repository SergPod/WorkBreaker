program WorkBreacker;

{$mode Delphi}{$H+}

{
  TBreak_rs - entry point.

  Two things are non-obvious here and both were the cause of real bugs:

  1. Application.MainFormOnTaskbar must be False. The main form is hidden
     and the app lives only as a tray icon. With True the win32 widgetset
     treats the hidden main form as the taskbar window: the window shows
     up anyway and closing it (Alt+F4) terminates the whole application.

  2. Single instance is enforced with a named kernel event, created before
     Application.Initialize. A named object is owned by the process, so it
     is released automatically on exit - a crashed instance does not block
     the next start.
}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Dialogs, Windows, mainform_rs, breakform_rs, settingsform_rs
  { you can add units after this };

{$R *.res}
const
  CAppMutex = 'Local\TBreak_SingleInstance';

var
  Hdl: THandle;

begin
  Hdl := 0;
  {$IFDEF WINDOWS}
  Hdl := CreateEvent(nil, True, False, PChar(CAppMutex));
  if (Hdl <> 0) and (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    CloseHandle(Hdl);
    Application.Initialize;
    MessageDlg('WorkBreaker is already running in the system tray.',
      mtInformation, [mbOK], 0);
    Halt(0);
  end;
  {$ENDIF}
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=False;
  {$POP}
  Application.Initialize;
  // Создаем невидимый диспетчер
  Application.CreateForm(TMainForm, TrayApp);
  // ЖЕСТКО ЗАПРЕЩАЕМ показывать Form1 на экране вообще когда-либо
  Application.ShowMainForm := False;
  Application.CreateForm(TBreakFormRs, BreakForm);
  Application.CreateForm(TSettingsFormRs, SettingsForm);
  Application.Run;
end.

