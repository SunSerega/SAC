function GetKeyState(Id:byte):byte;
external 'User32.dll';

begin
  while true do
  begin
    
    for i:byte := 0 to $FF do
      if GetKeyState(i) shr 7 = $01 then
        writeln($'{i,3} ${i.ToString(''X'')} {char(i)}');
    
    sleep(30);
    System.Console.Clear;
  end;
end.