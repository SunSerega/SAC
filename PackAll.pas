﻿begin
  
  var c := 0;
  var key := new object;
  
  System.Console.ForegroundColor := System.ConsoleColor.Gray;
  
  System.Threading.Thread.Create(
  ()->
  begin
    var comp := new System.Diagnostics.ProcessStartInfo;
    comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
    comp.Arguments := $'"{System.Environment.CurrentDirectory}\Editor.pas"';
    comp.UseShellExecute := false;
    comp.RedirectStandardOutput := true;
    
    var p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
    
    lock key do c += 1;
  end).Start;
  
  System.Threading.Thread.Create(
  ()->
  begin
    var comp := new System.Diagnostics.ProcessStartInfo;
    comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
    comp.Arguments := $'"{System.Environment.CurrentDirectory}\Help.pas"';
    comp.UseShellExecute := false;
    comp.RedirectStandardOutput := true;
    
    var p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
    
    lock key do c += 1;
  end).Start;
  
  System.Threading.Thread.Create(
  ()->
  begin
    var comp := new System.Diagnostics.ProcessStartInfo;
    comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
    comp.Arguments := $'"{System.Environment.CurrentDirectory}\WK.pas"';
    comp.UseShellExecute := false;
    comp.RedirectStandardOutput := true;
    
    var p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
    
    lock key do c += 1;
  end).Start;
  
  System.Threading.Thread.Create(
  ()->
  begin
    var comp := new System.Diagnostics.ProcessStartInfo;
    comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
    comp.Arguments := $'"{System.Environment.CurrentDirectory}\LibPacker.pas"';
    comp.UseShellExecute := false;
    comp.RedirectStandardOutput := true;
    
    var p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
    
    comp.FileName := 'LibPacker.exe';
    comp.Arguments := '';
    p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
    
    
    lock key do c += 1;
  end).Start;
  
  System.Threading.Thread.Create(
  ()->
  begin
    var comp := new System.Diagnostics.ProcessStartInfo;
    comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
    comp.Arguments := $'"{System.Environment.CurrentDirectory}\SAC.pas"';
    comp.UseShellExecute := false;
    comp.RedirectStandardOutput := true;
    
    var p := System.Diagnostics.Process.Start(comp);
    p.WaitForExit;
    write(p.StandardOutput.ReadToEnd+#10);
    
    lock key do c += 1;
  end).Start;
  
  System.IO.File.Copy('Icon(backup).ico','Icon.ico',true);
  
  var comp := new System.Diagnostics.ProcessStartInfo;
  comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
  comp.Arguments := $'"{System.Environment.CurrentDirectory}\Config.pas"';
  comp.UseShellExecute := false;
  comp.RedirectStandardOutput := true;
  //comp.RedirectStandardInput := true;
  
  while c < 5 do Sleep(10);
  
  System.Console.ForegroundColor := System.ConsoleColor.Green;
  
  writeln('main'#10);
  
  var p := System.Diagnostics.Process.Start(comp);
  //p.StandardInput.WriteLine;
  p.WaitForExit;
  writeln(p.StandardOutput.ReadToEnd);
  
  ReadlnString('Ready');
  
end.