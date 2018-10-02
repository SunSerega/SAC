var
  si: System.Diagnostics.ProcessStartInfo;

procedure GenRes(fname: string);
begin
  si.Arguments := $'"{System.IO.Path.GetDirectoryName(System.Environment.CurrentDirectory)}\{fname}.rc"';
  System.Diagnostics.Process.Start(si).StandardOutput.ReadToEnd.Print;
end;

begin
  si := new System.Diagnostics.ProcessStartInfo;
  si.FileName := 'rc.exe';
  si.UseShellExecute := false;
  si.RedirectStandardOutput := true;
  
  GenRes('SAC_res');
end.