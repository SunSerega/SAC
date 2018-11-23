uses StmParser;
//uses ExprParser;

//uses ВБФ;

begin
  var ep: ExecParams;
  ep.SupprIO := true;
  
  //var s := new Script('Lib\examples\Basic operators\main.sac');
  var s := new Script('TestSuite\TestComp\DynJump1\Main.sac', ep);
  
  //SaveObj('test.bin',s);
  
  writeln(s);
  loop 10 do s.Optimize;
  writeln('-'*50);
  writeln(s);
  exit;
  
  s.otp += s->writeln(s);
  s.susp_called += procedure->writeln('%susp called');
  s.stoped += procedure->writeln('%stoped');
  s.Execute;
  readln;
end.

//