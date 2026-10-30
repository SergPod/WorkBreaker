unit settingsform_rs;

{$mode Delphi}{$H+}

{
  Settings dialog for WorkBreaker.
  Created via designer (.lfm file).
}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, Spin;

type

  { TSettingsFormRs }

  TSettingsFormRs = class(TForm)
    SpinMiniDuration: TSpinEdit;
    SpinMiniInterval: TSpinEdit;
    SpinLongDuration: TSpinEdit;
    SpinLongAfter: TSpinEdit;
    BtnOk: TButton;
    BtnCancel: TButton;
    Lbl1: TLabel;
    Lbl2: TLabel;
    Lbl3: TLabel;
    Lbl4: TLabel;
    procedure FormCreate(Sender: TObject);
  private
    function get_MiniDurationSec: Integer;
    procedure set_MiniDurationSec(AValue: Integer);
    function get_MiniIntervalMin: Integer;
    procedure set_MiniIntervalMin(AValue: Integer);
    function get_LongDurationMin: Integer;
    procedure set_LongDurationMin(AValue: Integer);
    function get_LongAfterCount: Integer;
    procedure set_LongAfterCount(AValue: Integer);
  public
   // constructor CreateSettings(AOwner: TComponent);
    property MiniDurationSec: Integer read get_MiniDurationSec write set_MiniDurationSec;
    property MiniIntervalMin: Integer read get_MiniIntervalMin write set_MiniIntervalMin;
    property LongDurationMin: Integer read get_LongDurationMin write set_LongDurationMin;
    property LongAfterCount: Integer read get_LongAfterCount write set_LongAfterCount;
  end;

var
  SettingsForm: TSettingsFormRs;

implementation

{$R *.lfm}

{ TSettingsFormRs }
{
constructor TSettingsFormRs.CreateSettings(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 0);
end;}

procedure TSettingsFormRs.FormCreate(Sender: TObject);
begin
  // Form is created via CreateNew, no designer setup needed
end;

function TSettingsFormRs.get_MiniDurationSec: Integer;
begin
  Result := SpinMiniDuration.Value;
end;

procedure TSettingsFormRs.set_MiniDurationSec(AValue: Integer);
begin
  SpinMiniDuration.Value := AValue;
end;

function TSettingsFormRs.get_MiniIntervalMin: Integer;
begin
  Result := SpinMiniInterval.Value;
end;

procedure TSettingsFormRs.set_MiniIntervalMin(AValue: Integer);
begin
  SpinMiniInterval.Value := AValue;
end;

function TSettingsFormRs.get_LongDurationMin: Integer;
begin
  Result := SpinLongDuration.Value;
end;

procedure TSettingsFormRs.set_LongDurationMin(AValue: Integer);
begin
  SpinLongDuration.Value := AValue;
end;

function TSettingsFormRs.get_LongAfterCount: Integer;
begin
  Result := SpinLongAfter.Value;
end;

procedure TSettingsFormRs.set_LongAfterCount(AValue: Integer);
begin
  SpinLongAfter.Value := AValue;
end;

end.
