var
  curr_dir := System.Environment.CurrentDirectory;
  thrs := new List<System.Threading.Thread>;

procedure Compile(fname: string; execute: boolean := false) :=
try
  
  var comp := new System.Diagnostics.ProcessStartInfo;
  comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetcclear.exe"';
  //comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
  comp.Arguments := $'"{curr_dir}\{fname}.pas"';
  comp.UseShellExecute := false;
  comp.RedirectStandardOutput := true;
  
  var p := System.Diagnostics.Process.Start(comp);
  p.WaitForExit;
  write($'{fname} - {p.StandardOutput.ReadToEnd}{#10}');
  
  if execute then
  begin
    comp.FileName := $'{fname}.exe';
    comp.Arguments := '';
    p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
  end;
  
except
  on e: Exception do
    write($'{fname} - {_ObjectToString(e)}{#10#10}');
end;

procedure CompileAsync(fname: string; execute: boolean := false);
begin
  var thr := new System.Threading.Thread(
    procedure->Compile(fname, execute)
  );
  thr.Start;
  thrs.Add(thr);
end;

begin
  try
    
    System.Console.ForegroundColor := System.ConsoleColor.Gray;
    
    CompileAsync('LangPacker', true);
    CompileAsync('LibPacker', true);
    CompileAsync('WK');
    
    while thrs[0].IsAlive do Sleep(10);
    
    CompileAsync('SAC');
    CompileAsync('Editor');
    CompileAsync('Help');
    
    System.IO.File.Copy('Icon(backup).ico','Icon.ico',true);
    
    while thrs.Any do
    begin
      thrs.RemoveAll(thr->not thr.IsAlive);
      Sleep(10);
    end;
    
    System.Console.ForegroundColor := System.ConsoleColor.Green;
    
    Compile('Config');
    
    System.Console.ForegroundColor := System.ConsoleColor.Gray;
    ReadlnString('Ready');
    
  except
    on e: Exception do
      ReadlnString($'General Error - {_ObjectToString(e)}');
  end;
end.