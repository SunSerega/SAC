{$mainresource 'WK.res'}

function GetKeyState(Id:byte):byte;
external 'User32.dll';

begin
  try
    while true do
    begin
      
      for i:byte := 0 to $FF do
        if GetKeyState(i) shr 7 = $01 then
          writeln($'{i,3} ${i.ToString(''X'')} {char(i)}');
      
      sleep(30);
      System.Console.Clear;
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