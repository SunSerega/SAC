uses StmParser;
//uses ExprParser;

//uses ВБФ;

begin
  //var s := new Script('Lib\examples\Basic operators\main.sac');
  //var s := new Script('Lib\examples\Hello world\main.sac');
  //var s := new Script('Lib\Temp\SAC Script.sac');
  var s := new Script('Lib\Temp\main.sac', new ExecParams);
  
  //SaveObj('test.bin',s);
  
  writeln(s);
  loop 10 do s.Optimize;
  writeln(s);
  readln;
  
  s.otp += s->writeln(s);
  s.susp_called += procedure->writeln('%susp called');
  s.stoped += procedure->writeln('%stoped');
  s.Execute;
  readln;
end.

//