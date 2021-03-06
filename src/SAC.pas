﻿{$mainresource 'SAC.res'}
{$apptype windows}

uses ScriptExecutor;
uses CompArgsData;

uses LocaleData;
uses SettingsData;

uses MiscData;

var
  WW, WH: integer;

{$region Lib}

type
  ScriptFile = class
    
    path: string;
    name: string;
    
    static procedure FreeConsole;
    external 'kernel32.dll' name 'FreeConsole';
    
    procedure Start;
    begin
      FreeConsole;
      new ScriptExecutionForm(path+'\main.sac');
      Halt;
    end;
    
    constructor(fname: string);
    begin
      var fi := new System.IO.FileInfo(fname);
      self.path := fi.FullName;
      self.name := fi.Name;
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
      WritelnFormat(Translate('LibView|CurrLib'), name);
      if root <> nil then
        WritelnFormat(Translate('LibView|RootLib'), root.name);
      write('='*WW);
      var y := root=nil?2:3;
      var fst := true;
      
      if SubLibs.Count > 0 then
      begin
        Writeln(Translate('LibView|SubLibs'));
        for var i := 0 to SubLibs.Count-1 do
          WritelnFormat(Translate('LibView|LibElement'),i,SubLibs[i].name);
        y += 1+SubLibs.Count;
        fst := false;
      end;
      
      if Scripts.Count > 0 then
      begin
        if not fst then write('-'*WW);
        Writeln(Translate('LibView|Scripts'));
        for var i := 0 to Scripts.Count-1 do
          WritelnFormat(Translate('LibView|LibElement'),i+SubLibs.Count,Scripts[i].name);
        y += Scripts.Count + (fst?1:2);
        fst := false;
      end;
      
      if root <> nil then
      begin
        if not fst then write('-'*WW);
        Writeln(Translate('LibView|LibBack'));
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
        var ans := ReadlnString(Translate('LibView|Read')).ToLower;
        
        if ans = 'back' then Result := root;
        if Result = nil then Result := SubLibs.Where(l->l.name.ToLower=ans).FirstOrDefault;
        if Result = nil then Result := Scripts.Where(s->s.name.ToLower=ans).FirstOrDefault;
        if Result <> nil then exit;
        
        var id: integer;
        if TryStrToInt(ans, id) then
        begin
          
          if (id < (root=nil?0:-1) ) or (id >= SubLibs.Count + Scripts.Count) then
          begin
            Erase;
            WritelnFormat(Translate('LibView|InvalidId'),id);
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
          Erase;
          WritelnFormat(Translate('LibView|AnsNotDef'),ans);
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

{$endregion Lib}

procedure OpenLib;
begin
  
  writeln;
  System.Console.Clear;
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
  
  Writeln(Translate('NoLibHelp'));
  Readln;
  Halt;
  
end;

procedure StartScript;
begin
  var ep: ExecParams;
  try
    ep := ParseArgs(CommandLineArgs.Skip(1));
  except
    on e: _CompArgException do
    begin
      Writeln(e);
      Writeln;
      Writeln(Translate('PressToExit'));
      Readln;
      Halt;
    end;
  end;
  
  if ep.help_conf then ep := ArgsHelpForm.Create(ep, CommandLineArgs[0], CommandLineArgs.Select(arg->$'"{arg}"').JoinIntoString).ep;
  new ScriptExecutionForm(CommandLineArgs[0], ep);
end;

begin
  try
    
    {$resource Lang\#SAC}
    LoadLocale('#SAC');
    LoadSettings;
    
    //CommandLineArgs := new string[]('0\0.sac');
    //CommandLineArgs := new string[]('Lib\examples\Basic operators\main.sac');
    //CommandLineArgs := new string[]('Lib\examples\Basic operators\main.sac', '!conf');
    
    if CommandLineArgs.Any then
      StartScript else
    if System.IO.Directory.Exists('Lib') then
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