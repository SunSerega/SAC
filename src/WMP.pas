uses LocaleData;
uses SettingsData;
{$mainresource 'WMP.res'}//this is only for icon

type
  Point = record
    X, Y: integer;
  end;

procedure GetCursorPos(p: ^Point);
external 'User32.dll' name 'GetCursorPos';

function GetKeyState(nVirtKey: byte): byte;
external 'User32.dll' name 'GetKeyState';

procedure WaitKeyCombo(params keys: array of byte);
begin
  while keys.Any(key -> GetKeyState(key) shr 7 = 0) do Sleep(10);
  while keys.All(key -> GetKeyState(key) shr 7 = 1) do Sleep(10);
end;

var
  p: Point;

function GetOperString: string :=
$'{#10}MousePos {p.X} {p.Y}';

procedure CopyPos :=
while true do
try
  WaitKeyCombo($10, $53);
  
  {$reference System.Windows.Forms.dll}
  System.Windows.Forms.Clipboard.SetText(GetOperString);
  
  System.Console.Beep;
except
  on e: Exception do
  begin
    writeln('Error:');
    writeln(e);
    readln;
  end;
end;

begin
  try
    var thr := new System.Threading.Thread(CopyPos);
    thr.ApartmentState := System.Threading.ApartmentState.STA;
    thr.Start;
    
    {$resource Lang\#WMP}
    LoadLocale('#WMP');
    LoadSettings;
    
    System.Console.CursorVisible := false;
    write(Translate('PressThisToCopy'));
    var last_l := 0;
    
    while true do
    begin
      GetCursorPos(@p);
      
      var s := GetOperString;
      if s.Length<last_l then s += ' '*(last_l-s.Length);
      write(s);
      last_l := s.Length;
      System.Console.SetCursorPosition(0,0);
      
      Sleep(10);
    end;
  except
    on e: Exception do
    begin
      writeln('Error:');
      writeln(e);
      readln;
    end;
  end;
end.