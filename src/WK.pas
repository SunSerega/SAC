uses LocaleData;
uses SettingsData;
{$mainresource 'WK.res'}//this is only for icon

function GetKeyState(Id:byte):byte;
external 'User32.dll';

begin
  try
    {$resource Lang\#WK}
    LoadLocale('#WK');
    LoadSettings;
    writeln(Translate('ColExpl'));
    System.Console.CursorVisible := false;
    System.Console.CancelKeyPress += procedure(o,e)->e.Cancel := true;
    
    var last_h := 0;
    
    while true do
    begin
      if System.Console.CursorVisible then System.Console.CursorVisible := false;//Draging window can turn it on ¯\_(ツ)_/¯
      
      var curr_h := 0;
      var sb := new StringBuilder;
      
      for var i := 0 to $FF do
        if GetKeyState(i) shr 7 = 1 then
        begin
          sb.AppendLine($'{i,3} |               ${i:X2} |         {ChrAnsi(i)}');
          curr_h += 1;
        end;
      
      loop last_h-curr_h do
      begin
        sb.Append(' ', 35);
        sb.AppendLine;
      end;
      
      write(sb.ToString);
      System.Console.SetCursorPosition(0,1);
      last_h := curr_h;
      
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