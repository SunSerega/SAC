﻿uses StmParser;
uses ExprParser;

begin
  var s := new Script('Lib\examples\Basic operators\main.sac');
  //var s := new Script('Lib\Temp\SAC Script.sac');
  s.otp += s->writeln(s);
  s.susp_called += procedure->writeln('%susp called');
  s.stoped += procedure->writeln('%stoped');
  s.Execute;
  readln;
end.

//