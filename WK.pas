procedure GetKeyboardState(KeyArr:^byte);
external 'User32.dll' name 'GetKeyboardState';

function GetKeyState(Id:byte):byte;
external 'User32.dll' name 'GetKeyState';

begin
  var k := new byte[256];
  while true do
  begin
    System.Console.Clear;
    {
    GetKeyboardState(@k[0]);//не работает, так и не нашёл почему
    {}
    for i:byte := 0 to $FF do
      k[i] := GetKeyState(i); 
    {}
    for i:byte := 0 to $FF do
      if k[i] shr 7 = $01 then
        writeln($'{i,3} ${i.ToString(''X'')} {char(i)}');
    
    sleep(30);
  end;
end.