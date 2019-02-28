﻿uses StmParser;

uses MiscData;
uses LocaleData;

{ $define SingleThread}
{ $define WriteDone}



function TimedExecute(p: procedure; t: integer): boolean;
begin
  var res := false;
  var err: Exception;
  
  var exec_thr := new System.Threading.Thread(()->
    try
      p;
    except
      on e: System.Threading.ThreadAbortException do ;
      on e: Exception do err := e;
    end);
  var stop_thr := new System.Threading.Thread(()->
    begin
      Sleep(t);
      exec_thr.Abort;
      res := true;
    end);
  
  exec_thr.Start;
  stop_thr.Start;
  exec_thr.Join;
  stop_thr.Abort;
  
  if err<>nil then raise new Exception('',err);
  Result := res;
end;

type
  TesterException = class(Exception)
    constructor(text: string) :=
    inherited Create(text);
  end;
  
  Tester=abstract class
    
    curr_dir: string;
    sfn: string;
    
    main_fname: string;
    exp_opt_code: string;
    exp_comp_err: string;
    
    
    
    function Copy: Tester; abstract;
    
    function StartTesting(test_dir: string): boolean;
    begin
      curr_dir := test_dir;
      sfn := test_dir+'\0.sactd';
      
      Result := not System.IO.File.Exists(sfn);
      
      if Result then
      {$ifdef SingleThread}
        foreach var dir in System.IO.Directory.EnumerateDirectories(curr_dir) do
          self.Copy.Test(dir);
      {$else}
      begin
        var c := 0;
        var done := 0;
        var done_lock := new object;
        
        foreach var dir in System.IO.Directory.EnumerateDirectories(curr_dir) do
        begin
          var temp := self.Copy;
          c += 1;
          System.Threading.Thread.Create(()->
          begin
            temp.Test(dir);
            lock done_lock do done += 1;
          end).Start;
        end;
        
        while done<c do Sleep(10);
      end;
      {$endif}
      
    end;
    
    procedure Test(dir: string); abstract;
    
    
    
    function GetSettingsDict: Dictionary<string, string>;
    begin
      
      Result := new Dictionary<string, string>;
      var lns := ReadAllLines(sfn);
      
      var i := -1;
      while true do
      begin
        i += 1;
        if i >= lns.Length then break;
        var s := lns[i];
        if not s.StartsWith('#') then continue;
        
        var sb := new StringBuilder;
        var key := s;
        while true do
        begin
          i += 1;
          if i = lns.Length then break;
          s := lns[i];
          
          if s.StartsWith('#') or s.StartsWith(' #') then
          begin
            i -= 1;
            break;
          end;
          
          sb += s;
          sb += #10;
          
        end;
        
        if not key.StartsWith(' ') then
          Result.Add(key, sb.ToString.TrimEnd(#10));
      end;
      
    end;
    
    function LoadSettings: Dictionary<string, string>; virtual;
    begin
      Result := GetSettingsDict;
      
      if not Result.TryGetValue('#MainFName', main_fname) then main_fname := 'Main.sac';
      if not Result.TryGetValue('#ExpOptCode', exp_opt_code) then exp_opt_code := nil;
      if not Result.TryGetValue('#ExpCompErr', exp_comp_err) then exp_comp_err := nil;
      
    end;
    
    
    
    function TemplatedCompile: Script;
    const TimeToComp=2000;
    begin
      try
        
        var s: Script;
        if TimedExecute(
          ()->
          begin
            var ep := new ExecParams;
            ep.SupprIO := true;
            s := new Script(curr_dir + '\' + main_fname, ep);
          end,
          TimeToComp
        ) then
          raise new TesterException($'{curr_dir}: Error, compiling took too long!{#10}');
        
        var opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
        if exp_opt_code=nil then
        begin
          System.IO.File.AppendAllText(sfn, #10' #ExpOptCode'#10 + opt_code + #10);
          exp_opt_code := opt_code;
        end else
        if opt_code <> exp_opt_code then
          raise new TesterException($'{curr_dir}: Error, wrong code!{#10}');
        
        if TimedExecute(
          procedure->loop 10 do s.Optimize,
          TimeToComp
        ) then
          raise new TesterException($'{curr_dir}: Error, optimizing took too long!{#10}');
        
        opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
        if opt_code <> exp_opt_code then
          raise new TesterException($'{curr_dir}: Error, wrong code after optimize!{#10}');
        
        Result := s;
        
      except
        on e: Exception do
          if exp_comp_err=nil then
            raise e else
          if exp_comp_err='' then
            System.IO.File.AppendAllText(sfn, #10' #ExpCompErr'#10 + e.Message + #10) else
          if exp_comp_err<>e.Message then
            raise new TesterException($'{curr_dir}: Error, wrong error text!{#10}Exp: {exp_comp_err}{#10}Got: {e.Message}');
      end;
    end;
    
  end;
  
  CompTester = class(Tester)
    
    function Copy: Tester; override := new CompTester;
    
    procedure Test := Test('TestSuite\TestComp');
    
    procedure Test(dir: string); override :=
    try
      if StartTesting(dir) then exit;
      
      LoadSettings;
      
      TemplatedCompile;
      
      {$ifdef WriteDone}
      write($'DONE: {dir}{#10}');
      {$endif WriteDone}
      
    except
      on e: TesterException do writeln(e.Message);
      on e: Exception do writeln($'Exception in {dir}: {_ObjectToString(e)}');
    end;
    
  end;
  ExecTester = class(Tester)
    
    exp_otp: string;
    exp_exec_err: string;
    
    
    
    function Copy: Tester; override := new ExecTester;
    
    function LoadSettings: Dictionary<string, string>; override;
    begin
      Result := inherited LoadSettings;
      
      if not Result.TryGetValue('#ExpOtp', exp_otp) then exp_otp := nil;
      if not Result.TryGetValue('#ExpExecErr', exp_exec_err) then exp_exec_err := nil;
      
    end;
    
    
    
    procedure TemplatedExecute(s: Script);
    const TimeToExec=5000;
    begin
      try
        
        var otp := new StringBuilder;
        s.otp := str->
        begin
          otp += str;
          otp += #10;
        end;
        s.susp_called := procedure->otp += '%susp_called'#10;
        s.stoped := procedure->otp += '%stoped'#10;
        
        if TimedExecute(procedure->s.Execute, TimeToExec) then
          otp += '%aborted'#10;
        
        var otp_str := otp.ToString.TrimEnd(#10);
        if exp_otp=nil then
          System.IO.File.AppendAllText(sfn, #10' #ExpOtp'#10 + otp_str + #10) else
        if otp_str <> exp_otp then
          raise new TesterException($'{curr_dir}: Error, wrong output!{#10}');
        
      except
        on e: Exception do
          if exp_exec_err=nil then
            raise new Exception('',e) else
          if exp_exec_err='' then
            System.IO.File.AppendAllText(sfn, #10' #ExpExecErr'#10 + e.Message + #10) else
          if exp_exec_err<>e.Message then
            raise new TesterException($'{curr_dir}: Error, wrong error text!{#10}Exp: {exp_exec_err}{#10}Got: {e.Message}');
      end;
    end;
    
    
    
    procedure Test := Test('TestSuite\TestExec');
    
    procedure Test(dir: string); override :=
    try
      if StartTesting(dir) then exit;
      
      LoadSettings;
      
      var s := TemplatedCompile;
      TemplatedExecute(s);
      
      {$ifdef WriteDone}
      write($'DONE: {dir}{#10}');
      {$endif WriteDone}
      
    except
      on e: TesterException do writeln(e.Message);
      on e: Exception do writeln($'Exception in {dir}: {_ObjectToString(e)}');
    end;
    
  end;

begin
  try
    CurrLocale := LangList[0];
    
    {$ifdef SingleThread}
    CompTester.Create.Test;
    ExecTester.Create.Test;
    {$else}
    System.Threading.Tasks.Parallel.Invoke(
      CompTester.Create.Test,
      ExecTester.Create.Test
    );
    {$endif}
    
    Writeln('Done testing');
    if not System.Console.IsOutputRedirected then readln;
    
  except
    on e: Exception do
      writeln($'General Error: {_ObjectToString(e)}');
  end;
end.