uses StmParser;

//ToDo Проверить, не исправили ли issue компилятора
// - #1520

{ $define SingleThread}
{ $define WriteDone}

function TimedExecute(p: procedure; t: integer): boolean;
begin
  var res := false;
  
  var exec_thr := new System.Threading.Thread(p);
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
  
  Result := res;
end;

type
  Tester=abstract class
    
    curr_dir: string;
    sfn: string;
    stg: Dictionary<string, string>;
    exp_opt_code: string;
    main_fname: string;
    
    
    
    function Copy: Tester; abstract;
    
    procedure Test(dir: string); abstract;
    
    function StartTesting: boolean;
    begin
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
    
    procedure LoadSettings;
    begin
      
      stg := new Dictionary<string, string>;
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
          stg.Add(key, sb.ToString.TrimEnd(#10));
      end;
      
      if not stg.TryGetValue('#ExpOptCode', exp_opt_code) then exp_opt_code := nil;
      if not stg.TryGetValue('#MainFName', main_fname) then main_fname := nil;
      
    end;
    
  end;
  
  ExecTester = class(Tester)
    
    exp_otp: string;
    
    
    
    function Copy: Tester; override := new ExecTester;
    
    procedure Test(dir: string := 'TestSuite\TestExec'); override :=
    try
      curr_dir := dir;
      sfn := dir+'\0.sactd';
      if StartTesting then exit;
      
      LoadSettings;
      if not stg.TryGetValue('#ExpOtp', exp_otp) then exp_otp := nil;
      
      var s: Script;
      if TimedExecute(
        ()->
        begin
          var ep := new ExecParams;
          ep.SupprIO := true;
          s := new Script(dir + '\' + (main_fname=nil?'Main.sac':main_fname), ep);
        end,
        1000
      ) then
      begin
        write($'{dir}: Error, compiling took too long!{#10}');
        exit;
      end;
      
      var opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
      if exp_opt_code=nil then
      begin
        System.IO.File.AppendAllText(sfn, #10' #ExpOptCode'#10 + opt_code + #10);
        exp_opt_code := opt_code;
      end else
      if opt_code <> exp_opt_code then
      begin
        write($'{dir}: Error, wrong code!{#10}');
        exit;
      end;
      
      if TimedExecute(
        procedure->begin loop 10 do s.Optimize end,//ToDo #1520
        1000
      ) then
      begin
        write($'{dir}: Error, optimizing took too long!{#10}');
        exit;
      end;
      
      opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
      if opt_code <> exp_opt_code then
      begin
        write($'{dir}: Error, wrong code after optimize!{#10}');
        exit;
      end;
      
      
      
      var otp := new StringBuilder;
      s.otp := str->
      begin
        otp += str;
        otp += #10;
      end;
      s.susp_called := procedure->otp += '%susp_called'#10;
      s.stoped := procedure->otp += '%stoped'#10;
      
      if TimedExecute(procedure->s.Execute, 5000) then
        otp += '%aborted'#10;
      
      var otp_str := otp.ToString.TrimEnd(#10);
      if exp_otp=nil then
        System.IO.File.AppendAllText(sfn, #10' #ExpOtp'#10 + otp_str + #10) else
      if otp_str <> exp_otp then
      begin
        write($'{dir}: Error, wrong output!{#10}');
        exit;
      end;
      
      {$ifdef WriteDone}
      write($'DONE: {dir}{#10}');
      {$endif WriteDone}
      
    except
      on e: Exception do
        writeln($'Exception in {dir}: {_ObjectToString(e)}');
    end;
    
  end;
  CompTester = class(Tester)
    
    function Copy: Tester; override := new CompTester;
    
    procedure Test(dir: string := 'TestSuite\TestComp'); override :=
    try
      curr_dir := dir;
      sfn := dir+'\0.sactd';
      if StartTesting then exit;
      
      LoadSettings;
      
      var s: Script;
      if TimedExecute(
        ()->
        begin
          var ep := new ExecParams;
          ep.SupprIO := true;
          s := new Script(dir + '\' + (main_fname=nil?'Main.sac':main_fname), ep);
        end,
        1000
      ) then
      begin
        writeln($'{dir}: Error, compiling took too long!');
        exit;
      end;
      
      var opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
      if exp_opt_code=nil then
      begin
        System.IO.File.AppendAllText(sfn, #10' #ExpOptCode'#10 + opt_code + #10);
        exp_opt_code := opt_code;
      end else
      if opt_code <> exp_opt_code then
        writeln($'{dir}: Error, wrong code!');
      
      if TimedExecute(
        procedure->begin loop 10 do s.Optimize end,//ToDo #1520
        1000
      ) then
      begin
        writeln($'{dir}: Error, optimizing took too long!');
        exit;
      end;
      
      {$ifdef WriteDone}
      write($'DONE: {dir}{#10}');
      {$endif WriteDone}
      
    except
      on e: Exception do
        writeln($'Exception in {dir}: {_ObjectToString(e)}');
    end;
    
  end;

procedure TestErr(dir: string := 'TestErr');
begin
  if not System.IO.File.Exists(dir+'\0.sactd') then
  begin
    System.IO.Directory.EnumerateDirectories(dir).ForEach(TestErr);
    exit;
  end;
  
  
  
end;

procedure SpecTests(dir: string := 'SpecialTests');
begin
  if not System.IO.File.Exists(dir+'\0.sactd') then
  begin
    System.IO.Directory.EnumerateDirectories(dir).ForEach(SpecTests);
    exit;
  end;
  
  
  
end;

begin
  try
    
    var c := 2;
    var done := 0;
    var done_lock := new object;
    
    System.Threading.Thread.Create(()->begin ExecTester.Create.Test; lock done_lock do done += 1 end).Start;
    System.Threading.Thread.Create(()->begin CompTester.Create.Test; lock done_lock do done += 1 end).Start;
    
//    TestErr;
//    SpecTests;
    
    
    
    while done<c do Sleep(10);
    Writeln('Done testing');
    
  except
    on e: Exception do
      writeln($'General Error: {_ObjectToString(e)}');
  end;
end.