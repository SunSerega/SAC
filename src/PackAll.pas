type
  [System.FlagsAttribute]
  CompFlags = (
    none=0,
    exec=1,
    mnft=2,
    gres=4
  );

type
  Entry=class
    
    static defined := new Dictionary<string, Entry>;
    static comp_arg_tmpl := '"{0}.pas" ' + $'"{GetCurrentDir}" "Debug=0"';
    static can_finalize := false;
    
    fname: string;
    flags: CompFlags;
    
    waiting := new List<Entry>;
    next := new List<Entry>;
    
    constructor(fname: string; flags: CompFlags; params wait: array of string);
    begin
      self.fname := fname;
      self.flags := flags;
      
      foreach var ws in wait do
      begin
        var w := defined[ws];
        w.next += self;
        waiting += w;
      end;
      
      lock defined do defined.Add(fname, self);
      
      System.Threading.Thread.Create(Compile).Start;
      
    end;
    
    procedure Compile :=
    try
      
      var comp := new System.Diagnostics.ProcessStartInfo;
      comp.UseShellExecute := false;
      comp.RedirectStandardOutput := true;
      var p: System.Diagnostics.Process;
      
      if integer(flags and gres) <> 0 then
      begin
        
        loop 10 do
        begin
          comp.FileName := 'ResGen\RC.exe';
          comp.Arguments := $'"{System.IO.Path.GetFullPath(fname)}.rc"';
          p := System.Diagnostics.Process.Start(comp);
          p.WaitForExit;
          
          var otp := p.StandardOutput.ReadToEnd;
          if otp.Count(ch->ch=#10) > 3 then
          begin
            write($'{fname}: {otp}{#10}');
            Sleep(1000);
          end else
            break;
          
        end;
        
        write($'{fname}: Created res{#10}{#10}');
      end;
      
      while waiting.Count<>0 do Sleep(10);
      
      loop 10 do
      begin
          
        comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetcclear.exe"';
        //comp.FileName := '"C:\Program Files (x86)\PascalABC.NET\pabcnetc.exe"';
        comp.Arguments := string.Format(comp_arg_tmpl, fname);
        
        p := System.Diagnostics.Process.Start(comp);
        p.WaitForExit;
        var otp := p.StandardOutput.ReadToEnd;
        write($'{fname} - {otp}{#10}');
        if not otp.ToLower.Contains('error') then break;
        
      end;
      
      if integer(flags and mnft) <> 0 then
      begin
        
        loop 10 do
        begin
          
          comp.FileName := 'ManifestGen\mt.exe';
          comp.Arguments := $'-nologo -manifest "{System.IO.Path.GetFullPath(fname)}.exe.manifest" -outputresource:"{System.IO.Path.GetFullPath(fname)}.exe;#1"';
          p := System.Diagnostics.Process.Start(comp);
          p.WaitForExit;
          
          var otp := p.StandardOutput.ReadToEnd;
          if otp <> '' then
          begin
            write($'{fname}: {otp}{#10}');
            Sleep(1000);
          end else
            break;
        end;
        
        write($'{fname}: Added manifest{#10}{#10}');
      end;
      
      if integer(flags and exec) <> 0 then
      begin
        comp.FileName := $'{fname}.exe';
        comp.Arguments := '';
        p := System.Diagnostics.Process.Start(comp);
        p.WaitForExit;
        var otp := p.StandardOutput.ReadToEnd;
        if otp <> '' then write(Concat($'Executing {fname}:',#10,otp,#10));
      end;
      
      if can_finalize then lock defined do defined.Remove(self.fname);
      
      foreach var n in next do
        lock n.waiting do
          n.waiting.Remove(self);
      
      if defined.ContainsKey(self.fname) then
      begin
        while not can_finalize do Sleep(10);
        lock defined do defined.Remove(self.fname);
      end;
      
    except
      on e: Exception do
        write($'{fname} - {_ObjectToString(e)}{#10#10}');
    end;
    
  end;

procedure Init;
begin
  
  System.IO.File.Copy('Icon(backup).ico','Icon.ico',true);
  
  var s := ReadAllText('version.dat');
  var chs := s.Skip(1).TakeWhile(ch->ch.IsDigit).ToArray;
  var maj := string.Create(chs).ToInteger;
  var min := s.Skip(1+chs.Length+12).TakeWhile(ch->ch.IsDigit).JoinIntoString.ToInteger;
  
  min += 1;
  if min > word.MaxValue then
  begin
    maj += 1;
    min := 0;
  end;
  
  WriteAllText('version.dat', $'({maj} shl 16) + ({min})');
  
end;

procedure UpdateIcons;
begin
  var si := new System.Diagnostics.ProcessStartInfo('cmd');
  si.UseShellExecute := false;
  si.RedirectStandardInput := true;
  si.RedirectStandardOutput := true;
  var p := System.Diagnostics.Process.Start(si);
  var sw := p.StandardInput;
  sw.WriteLine('ie4uinit.exe -ClearIconCache');
  sw.WriteLine('ie4uinit.exe -show');//Win10
  sw.WriteLine('exit');
  p.WaitForExit;
end;

begin
  try
    
    Init;
    
    
    
    new Entry('Test',       exec);
    
    new Entry('LangPacker', exec);
    new Entry('LibPacker',  exec);
    
    new Entry('SAC',        gres or mnft, 'LangPacker');
    new Entry('Editor',     none,         'LangPacker');
    new Entry('FuncHelp',   gres,         'LangPacker');
    new Entry('OperHelp',   gres,         'LangPacker');
    new Entry('DrctHelp',   gres,         'LangPacker');
    new Entry('Help',       gres,         'LangPacker');
    new Entry('WK',         gres,         'LangPacker');
    new Entry('WMP',        gres,         'LangPacker');
    
    new Entry('Config',     gres or mnft, 'LibPacker', 'WK', 'WMP', 'SAC', 'Editor', 'FuncHelp', 'OperHelp', 'DrctHelp', 'Help');
    
    Entry.can_finalize := true;
    
    
    
    while Entry.defined.Count<>0 do Sleep(10);
    
    System.IO.File.Copy('Config.exe',$'{System.IO.Path.GetDirectoryName(GetCurrentDir)}\Config.exe',true);
    
    UpdateIcons;
    
    System.Console.ForegroundColor := System.ConsoleColor.Green;
    ReadlnString('Ready');
    Halt;
    
  except
    on e: Exception do
      ReadlnString($'General Error - {_ObjectToString(e)}');
  end;
end.