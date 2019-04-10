uses StmParser;

{ $define SingleThread}
{ $define WriteDone}

uses System.Windows.Forms;
uses System.Drawing;

uses MiscData;
uses LocaleData;

//ToDo issue:
// - #1814
// - #1900



///Result=True когда времени не хватило
function TimedExecute(p: procedure; t: integer): boolean;
begin
  {$ifndef SingleThread}
  var res := false;
  var err: Exception;
  
  var exec_thr := new System.Threading.Thread(()->
    try
      p;
    except
      on e: System.Threading.ThreadAbortException do ;
      on e2: Exception do err := e2; // ToDo #1900
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
  {$else}
  p;
  {$endif}
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
    
    
    
    function TemplatedCompile: array of Script;
    const TimeToComp=2000;
    begin
      var handle_exc: Exception->() := e->//ToDo #1814
      begin
        var ie := e;
        while ie.InnerException<>nil do ie := ie.InnerException;
        var err_text := ie.Message;
        
        if exp_comp_err=nil then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'code:'#10 + exp_opt_code + #10#10#10'error:'#10 + e.ToString + #10#10#10'Add this to expected errors?', $'Unexpected Exception', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              System.IO.File.AppendAllText(sfn, #10' #ExpCompErr'#10 + err_text + #10);
              writeln($'%Warning! .sactd updated for {curr_dir}{#10}');
            end;
            
            DialogResult.Cancel: Halt;
            
          end else
        if exp_comp_err='' then
        begin
          System.IO.File.AppendAllText(sfn, #10' #ExpCompErr'#10 + err_text + #10);
          writeln($'Warning! .sactd updated for {curr_dir}{#10}');
        end else
        if exp_comp_err<>err_text then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'code:'#10 + exp_opt_code + #10#10#10'exp:'#10 + exp_comp_err + #10#10#10'got:'#10 + err_text + #10#10#10'error:'#10 + e.ToString + #10#10#10'Add this to expected errors?', $'Wrong error text', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              System.IO.File.AppendAllText(sfn, #10' #ExpCompErr'#10 + err_text + #10);
              writeln($'%Warning! .sactd updated for {curr_dir}{#10}');
            end;
            
            DialogResult.Cancel: Halt;
            
          end;
      end;
      
      try
        
        {$region compile}
        
        var ep := new ExecParams;
        ep.SupprIO := true;
        var s: Script;
        if TimedExecute(
          ()->
          begin
            s := new Script(curr_dir + '\' + main_fname, ep);
          end,
          TimeToComp
        ) then
          raise new TesterException($'{curr_dir}: Error, compiling took too long!{#10}');
        
        {$endregion compile}
        
        {$region Test code}
        
        var opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
        if exp_opt_code=nil then
        begin
          System.IO.File.AppendAllText(sfn, #10' #ExpOptCode'#10 + opt_code + #10);
          writeln($'Warning! .sactd updated for {curr_dir}');
          exp_opt_code := opt_code;
        end else
        if opt_code <> exp_opt_code then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'exp:'#10 + exp_opt_code + #10#10#10'got:'#10 + opt_code + #10#10#10'Update expected code?', $'Wrong code', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              System.IO.File.AppendAllText(sfn, #10' #ExpOptCode'#10 + opt_code + #10);
              writeln($'%Warning! .sactd updated for {curr_dir}');
              exp_opt_code := opt_code;
            end;
            
            DialogResult.Cancel: Halt;
            
          end;
        
        {$endregion Test code}
        
        {$region Test multiple s.Optimize}
        
        if TimedExecute(
          s.Optimize * 10,
          TimeToComp
        ) then
          raise new TesterException($'{curr_dir}: Error, optimizing took too long!{#10}');
        
        opt_code := s.ToString.Replace('#', '\#').TrimEnd(#10);
        if opt_code <> exp_opt_code then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'exp:'#10 + exp_opt_code + #10#10#10'got:'#10 + opt_code + #10, $'Wrong code after optimizing', MessageBoxButtons.OKCancel) of
            
            DialogResult.Cancel: Halt;
            
          end;
        
        {$endregion Test multiple s.Optimize}
        
        {$region Test serialization}
        
        var temp_str := new System.IO.MemoryStream;
        s.Serialize(temp_str);
        temp_str.Position := 0;
        var s2 := Script.LoadNew(System.IO.Path.GetFullPath(curr_dir + '\' + main_fname), temp_str, ep);
        
        opt_code := s2.ToString.Replace('#', '\#').TrimEnd(#10);
        if opt_code <> exp_opt_code then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'exp:'#10 + exp_opt_code + #10#10#10'got:'#10 + opt_code + #10, $'Wrong code after serializing', MessageBoxButtons.OKCancel) of
            
            DialogResult.Cancel: Halt;
            
          end;
        
        {$endregion Test serialization}
        
        if exp_comp_err<>nil then
          raise new TesterException($'{curr_dir}: Error, expected error not found{#10}');
        
        Result := Arr(s,s2);
      except
        on e: TesterException do raise new TesterException(e.Message);
        on e2: Exception do // ToDo #1900
        begin
          handle_exc(e2); //ToDo #1814
        end;
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
      on e: Exception do writeln($'Exception in {dir}: {e}');
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
      var handle_exc: Exception->() := e->//ToDo #1814
      begin
        var ie := e;
        while ie.InnerException<>nil do ie := ie.InnerException;
        var err_text := ie.Message;
        
        if exp_exec_err=nil then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'code:'#10 + exp_opt_code + #10#10#10'error:'#10 + e.ToString + #10#10#10'Add this to expected errors?', $'Unexpected Exception when executing', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              System.IO.File.AppendAllText(sfn, #10' #ExpExecErr'#10 + err_text + #10);
              writeln($'%Warning! .sactd updated for {curr_dir}{#10}');
            end;
            
            DialogResult.Cancel: Halt;
            
          end else
        if exp_exec_err='' then
        begin
          System.IO.File.AppendAllText(sfn, #10' #ExpExecErr'#10 + err_text + #10);
          writeln($'Warning! .sactd updated for {curr_dir}');
        end else
        if exp_exec_err<>err_text then
        case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'code:'#10 + exp_opt_code + #10#10#10'exp:'#10 + exp_exec_err + #10#10#10'got:'#10 + err_text + #10#10#10'error:'#10 + e.ToString + #10#10#10'Add this to expected errors?', $'Wrong error text', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              System.IO.File.AppendAllText(sfn, #10' #ExpExecErr'#10 + err_text + #10);
              writeln($'%Warning! .sactd updated for {curr_dir}{#10}');
            end;
            
            DialogResult.Cancel: Halt;
            
          end;
        
      end;
      
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
        begin
          System.IO.File.AppendAllText(sfn, #10' #ExpOtp'#10 + otp_str + #10);
          writeln($'Warning! .sactd updated for {curr_dir}');
        end else
        if otp_str <> exp_otp then
          case MessageBox.Show(curr_dir + ':'#10#10'src:'#10 + ReadAllText(curr_dir + '\' + main_fname).Trim(#10) + #10#10#10'code:'#10 + exp_opt_code + #10#10#10'exp:'#10 + exp_otp + #10#10#10'got:'#10 + otp_str + #10#10#10'Update expected output?', $'Wrong output', MessageBoxButtons.YesNoCancel) of
            
            DialogResult.Yes:
            begin
              System.IO.File.AppendAllText(sfn, #10' #ExpOtp'#10 + otp_str + #10);
              writeln($'%Warning! .sactd updated for {curr_dir}');
            end;
            
            DialogResult.Cancel: Halt;
            
          end;
        
        if exp_exec_err<>nil then
          raise new TesterException($'{curr_dir}: Error, expected error not found{#10}');
        
      except
        on e: TesterException do raise new TesterException(e.Message);
        on e2: Exception do // ToDo #1900
        begin
          handle_exc(e2); //ToDo #1814
        end;
      end;
    end;
    
    
    
    procedure Test := Test('TestSuite\TestExec');
    
    procedure Test(dir: string); override :=
    try
      if StartTesting(dir) then exit;
      
      LoadSettings;
      
      {$ifdef SingleThread}
      foreach var s in TemplatedCompile do
        TemplatedExecute(s);
      {$else SingleThread}
      System.Threading.Tasks.Parallel.Invoke(
        TemplatedCompile.ConvertAll(s->
        begin
          var res: Action0 := ()->
          try
            self.TemplatedExecute(s);
          except
            on e: TesterException do writeln(e.Message);
            on e: Exception do writeln($'Exception in {dir}: {_ObjectToString(e)}');
          end;
          Result := res;
        end)
      );
      {$endif SingleThread}
      
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
    
//    CompTester.Create.Test('TestSuite\TestExec\MultFile2');
//    Halt;
    
    {$ifdef SingleThread}
    CompTester.Create.Test;
    ExecTester.Create.Test;
    {$else SingleThread}
    System.Threading.Tasks.Parallel.Invoke(
      CompTester.Create.Test,
      ExecTester.Create.Test
    );
    {$endif SingleThread}
    
    Writeln('Done testing');
    if not System.Console.IsOutputRedirected then ReadlnString('Press Enter to exit');
    
  except
    on e: Exception do
      writeln($'General Error: {_ObjectToString(e)}');
  end;
end.