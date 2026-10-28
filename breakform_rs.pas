unit breakform_rs;

{$mode Delphi}{$H+}

{
  The break window (designer-based, see breakform_rs.lfm).

  Created ONCE at start-up (hidden) and then only shown/hidden for each
  break. The layout is entirely the .lfm one - no runtime resizing.

  Esc            - finish the break now
  "Skip break"   label - finish the break now
  "Postpone break" label - postpone once (then it gets disabled)
}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, LCLType, Windows;

type

  TBreakKind = (bkMini, bkLong, bkNone);

  { TBreakFormRs }

  TBreakFormRs = class(TForm)
    LblPostpone: TLabel;
    LblSkip: TLabel;
    LblTime: TLabel;
    LblTitle: TLabel;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormDeactivate(Sender: TObject);
    procedure LblPostponeClick(Sender: TObject);
    procedure LblSkipClick(Sender: TObject);
  private
    FKind: TBreakKind;
    FLeftSec: Integer;
    FPostponed: Boolean;
    FPostponeSec: Integer;
    FOnFinish: TNotifyEvent;
    procedure SetKind(const AValue: TBreakKind);
    procedure UpdateView;
    procedure KeepOnTop;
  public
    procedure Start(ASec: Integer; AKind: TBreakKind);
    procedure Tick;
    procedure Postpone;
    property Kind: TBreakKind read FKind write SetKind;
    property PostponeSec: Integer read FPostponeSec write FPostponeSec;
    property LeftSec: Integer read FLeftSec;
    property Postponed: Boolean read FPostponed;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
  end;

var
  BreakForm: TBreakFormRs;

implementation

{$R *.lfm}

uses mainform_rs;

function SecToStr(ASec: Integer): string;
begin
  Result := Format('%.2d:%.2d', [ASec div 60, ASec mod 60]);
end;

{ TBreakFormRs }

procedure TBreakFormRs.FormCreate(Sender: TObject);
begin
  // Load the .lfm layout. The form stays hidden until the first break;
  // Show/Hide are used for every break afterwards.
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Position := poDesigned;
  ShowInTaskBar := stNever;
  KeyPreview := True;
  // Re-assert topmost the moment the break window loses focus (the user
  // clicked another window) so it never drops behind the rest.
  OnDeactivate := FormDeactivate;

  FKind := bkNone;
  FLeftSec := 0;
  FPostponed := False;
  // The break window is created once (hidden) and reused for every break.
  //FBreakForm := TBreakFormRs.CreateBreak(Self);
  PostponeSec := 0; // set per break in ShowBreak
  OnFinish := TrayApp.BreakFinished;
end;

procedure TBreakFormRs.SetKind(const AValue: TBreakKind);
begin
  FKind := AValue;
  if FKind = bkMini then
      begin
        LblTitle.Caption := 'MINI  BREAK';
      end
  else
      begin
        LblTitle.Caption := 'LONG  BREAK';
      end;
end;

procedure TBreakFormRs.Start(ASec: Integer; AKind: TBreakKind);
begin
  FLeftSec := ASec;
  FPostponed := False;
  Kind := AKind;
  UpdateView;
  if not Visible then Show;
  SetFocus;
end;

procedure TBreakFormRs.Tick;
begin
  KeepOnTop; // re-assert topmost every second while the break is running
  if FLeftSec > 0 then Dec(FLeftSec);
  UpdateView;
  if FLeftSec <= 0 then
  begin
    if Assigned(FOnFinish) then FOnFinish(Self);
    Exit;
  end;
end;

{ Postpone: end the current break (hide the window) and hand control back
  to the main form, which starts a new countdown of FPostponeSec seconds.
  The "Postpone" label is disabled for the rest of the session. }

procedure TBreakFormRs.Postpone;
begin
  if FPostponed then Exit;
  FPostponed := True;
  UpdateView;
  Hide; // the form is reused, never freed
  if Assigned(FOnFinish) then FOnFinish(Self);
end;

procedure TBreakFormRs.UpdateView;
begin
  LblTime.Caption := SecToStr(FLeftSec);
  LblPostpone.Enabled := not FPostponed;
end;

{ Keep the borderless break window above every other window. fsStayOnTop
  sets WS_EX_TOPMOST, which only keeps it above NON-topmost windows; a
  newly activated topmost window (menus, dialogs, other apps) can still
  cover it. Re-applying HWND_TOPMOST restores the top position. SWP_NOACTIVATE
  raises the z-order WITHOUT stealing the keyboard focus from the window the
  user is working in. }
procedure TBreakFormRs.KeepOnTop;
begin
  if (Handle <> 0) and Visible then
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;

{ The user clicked another window: the break window was deactivated.
  Immediately push it back to the top of the z-order. }
procedure TBreakFormRs.FormDeactivate(Sender: TObject);
begin
  KeepOnTop;
end;

{ Alt+F4 / system close of the break window: treat it like Skip, i.e. end
  the break (OnFinish). The form is only hidden, never freed. }
procedure TBreakFormRs.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if Assigned(FOnFinish) then
    FOnFinish(Self)
  else
    CanClose := True;
end;

{ Alt+F4 / system close of the break window: treat it like Skip, i.e. end
  the break (OnFinish). The form is only hidden, never freed. }
procedure TBreakFormRs.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    if Assigned(FOnFinish) then FOnFinish(Self);
end;


procedure TBreakFormRs.LblPostponeClick(Sender: TObject);
begin
  Postpone;
end;

procedure TBreakFormRs.LblSkipClick(Sender: TObject);
begin
  if Assigned(FOnFinish) then FOnFinish(Self);
end;

end.
