uses ScriptExecutor;

var
  WW, WH: integer;

type
  ScriptFile = class
    
    path: string;
    name: string;
    
    procedure Start;
    begin
      var s := new Script(path);
      s.Start;
    end;
    
    constructor(fname: string);
    begin
      self.path := fname;
      self.name := System.IO.Path.GetFileName(fname);
    end;
    
  end;
  Lib = class
    
    path: string;
    name: string;
    root: Lib;
    SubLibs := new List<Lib>;
    Scripts := new List<ScriptFile>;
    
    function AskUser: object;
    begin
      System.Console.Clear;
      Writeln($'Lib "{name}"');
      if root <> nil then
        Writeln($'Root: "{root.name}"');
      write('='*WW);
      var y := root=nil?2:3;
      var fst := true;
      
      if SubLibs.Count > 0 then
      begin
        writeln('SubLibs:');
        for var i := 0 to SubLibs.Count-1 do
          writeln($'{i} : {SubLibs[i].name}');
        y += 1+SubLibs.Count;
        fst := false;
      end;
      
      if Scripts.Count > 0 then
      begin
        if not fst then write('-'*WW);
        writeln('Scripts:');
        for var i := 0 to Scripts.Count-1 do
          writeln($'{i+SubLibs.Count} : {Scripts[i].name}');
        y += Scripts.Count + (fst?1:2);
        fst := false;
      end;
      
      if root <> nil then
      begin
        if not fst then write('-'*WW);
        writeln('-1/back : Go to root');
        y += fst?2:3;
        fst := false;
      end;
      
      if not fst then
      begin
        write('='*WW);
        y += 1;
      end;
      
      var Erase: procedure := ()->
      begin
        System.Console.SetCursorPosition(0,y);
        write(' '*((WH-y)*WW-1));
        System.Console.SetCursorPosition(0,y);
      end;
      
      while true do
      begin
        var ans := ReadlnString('Enter name or id : ').ToLower;
        var id: integer;
        if TryStrToInt(ans, id) then
        begin
          
          if (id < -1) or (id >= SubLibs.Count + Scripts.Count) then
          begin
            Erase;
            writeln('id #{id} is out of posible range');
          end else
          begin
            if id = -1 then Result := root else
            if id >= SubLibs.Count then
              Result := Scripts[id-SubLibs.Count] else
              Result := SubLibs[id];
            exit;
          end;
          
        end else
        begin
          
          if ans = 'back' then Result := root;
          if Result = nil then Result := SubLibs.Where(l->l.name.ToLower=ans).FirstOrDefault;
          if Result = nil then Result := Scripts.Where(s->s.name.ToLower=ans).FirstOrDefault;
          if Result = nil then
          begin
            Erase;
            writeln($'"{ans}" is not defined');
          end else
            exit;
          
        end;
      end;
      
    end;
    
    constructor(dir: string := 'lib'; root: Lib := nil);
    begin
      self.path := dir;
      self.name := System.IO.Path.GetFileName(dir);
      self.root := root;
      
      foreach var d in System.IO.Directory.EnumerateDirectories(dir) do
        if System.IO.File.Exists(d+'\Main.sac') then
          Scripts.Add(new ScriptFile(d)) else
          SubLibs.Add(new Lib(d, self));
      
      SubLibs.Capacity := SubLibs.Count;
      Scripts.Capacity := Scripts.Count;
      
    end;
    
  end;

procedure OpenLib;
begin
  
  System.Console.SetWindowSize(60,50);
  System.Console.SetBufferSize(60,50);
  WW := System.Console.BufferWidth;
  WH := System.Console.BufferHeight;
  
  var root := new Lib;
  while true do
  begin
    var ans := root.AskUser;
    if ans is ScriptFile(var sf) then
      sf.Start else
      root := ans as Lib;
  end;
  
end;

procedure WriteHelp;
begin
  
  Writeln('No lib folder found');
  Writeln('You can still start script from random folder');
  Writeln('Start this .exe with Command line arguments, like this:');
  Writeln('"folder_of_this_exe\SAC.exe" "YourScriptName.sac"');
  Writeln('You can also specify arguments, after .sac file name');
  Writeln('Here is list of them:');
  Writeln('"!conf" - will start program to help add arguments');
  Writeln('"!line=5" - will start script from line 5');
  Writeln('"!debug" - will start script with debug (slower, but more info)');
  Writeln('Thats all for now, press Enter to exit');
  Readln;
  Halt;
  
end;

procedure HelpWithArgs;
begin
  var ToDo := 0;
  writeln('Nothing in "!conf" start yet');
  writeln('Press Enter to continue without config');
  readln;
end;

procedure StartScript;
begin
  
  WW := Max(60,CommandLineArgs[0].Length+5+1);
  WH := System.Console.LargestWindowHeight-1;
  System.Console.SetWindowSize(WW,WH);
  System.Console.SetBufferSize(WW,WH);
  writeln($'File {CommandLineArgs[0]}');
  
  var debug := false;
  var conf := false;
  var line := 0;
  
  foreach var arg:string in CommandLineArgs.Skip(1) do
    if arg = '!conf' then conf := true else
    if arg = '!debug' then debug := true else
    if arg.StartsWith('!line=') then//ToDo заменить, прыгать можно только на лейблы
    begin//ToDo StartsWith это криво. Надо заменить на .Split('=',2) в начале цикла
      if not TryStrToInt(arg.Split('=',2)[1], line) then
        Writeln($'Error parsing {arg.Split(''='',2)[1]} to integer in "!line" arg');
    end else
      writeln($'unknown arg: {arg}');
  
  if conf then HelpWithArgs;
  
  var s := new Script(CommandLineArgs[0], debug, line);
  s.Start;
  
end;

begin
  try
    
    if CommandLineArgs.Any then
      StartScript else
    if System.IO.Directory.Exists('lib') then
      OpenLib else
      WriteHelp;
    
  except
    on e: Exception do
    begin
      writeln(e);
      readln;
    end;
  end;
end.