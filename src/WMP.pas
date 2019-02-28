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
begin
  WaitKeyCombo($10, $53);
  
  {$reference System.Windows.Forms.dll}
  System.Windows.Forms.Clipboard.SetText(GetOperString);
  
  System.Console.Beep;
end;

begin
  var thr := new System.Threading.Thread(CopyPos);
  thr.ApartmentState := System.Threading.ApartmentState.STA;
  thr.Start;
  
  System.Console.CursorVisible := false;
  write('Нажмите Shift+S чтоб скопировать следующее в буфер обмена:');
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
end.