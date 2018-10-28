type
  [System.FlagsAttribute]
  CompFlags = (
    none=0,
    exec=1,
    mnft=2,
    gres=4
  );

var
  curr_dir := System.Environment.CurrentDirectory;
  thrs := new List<System.Threading.Thread>;

procedure Compile(fname: string; flags: CompFlags := none) :=
try
  
  var comp := new System.Diagnostics.ProcessStartInfo;
  comp.UseShellExecute := false;
  comp.RedirectStandardOutput := true;
  var p: System.Diagnostics.Process;
  
  if integer(flags and gres) <> 0 then
  begin
    comp.FileName := 'ResGen\RC.exe';
    comp.Arguments := $'"{System.IO.Path.GetFullPath(fname)}.rc"';
    p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    //write(p.StandardOutput.ReadToEnd+#10);
  end;
  
  comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetcclear.exe"';
  //comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
  comp.Arguments := $'"{curr_dir}\{fname}.pas"';
  
  p := System.Diagnostics.Process.Start(comp);
  p.WaitForExit;
  write($'{fname} - {p.StandardOutput.ReadToEnd}{#10}');
  
  if integer(flags and exec) <> 0 then
  begin
    comp.FileName := $'{fname}.exe';
    comp.Arguments := '';
    p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
  end;
  
  if integer(flags and mnft) <> 0 then
  begin
    comp.FileName := 'ManifestGen\mt.exe';
    comp.Arguments := $'-nologo -manifest "{System.IO.Path.GetFullPath(fname)}.exe.manifest" -outputresource:"{System.IO.Path.GetFullPath(fname)}.exe;#1"';
    p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    var otp := p.StandardOutput.ReadToEnd;
    if otp <> '' then write(otp+#10);
  end;
  
except
  on e: Exception do
    write($'{fname} - {_ObjectToString(e)}{#10#10}');
end;

procedure CompileAsync(fname: string; flags: CompFlags := none);
begin
  var thr := new System.Threading.Thread(
    procedure->Compile(fname, flags)
  );
  thr.Start;
  thrs.Add(thr);
end;

begin
  try
    
    System.Console.ForegroundColor := System.ConsoleColor.Gray;
    
    CompileAsync('LangPacker', exec);
    CompileAsync('LibPacker', exec);
    CompileAsync('WK', gres);
    
    while thrs[0].IsAlive do Sleep(10);
    
    CompileAsync('SAC', gres or mnft);
    CompileAsync('Editor');
    CompileAsync('Help', gres);
    
    System.IO.File.Copy('Icon(backup).ico','Icon.ico',true);
    
    while thrs.Any do
    begin
      thrs.RemoveAll(thr->not thr.IsAlive);
      Sleep(10);
    end;
    
    System.Console.ForegroundColor := System.ConsoleColor.Green;
    
    Compile('Config', gres or mnft);
    
//    foreach var fname in System.IO.Directory.EnumerateFiles(GetCurrentDir) do
//      if fname.EndsWith('.pcu') or fname.EndsWith('.pdb') then
//      try
//        System.IO.File.Delete(fname);
//      except end;
    
    System.Console.ForegroundColor := System.ConsoleColor.Gray;
    ReadlnString('Ready');
    
  except
    on e: Exception do
      ReadlnString($'General Error - {_ObjectToString(e)}');
  end;
end.