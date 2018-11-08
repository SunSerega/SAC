uses StmParser;
uses ExprParser;

begin
  var s := new Script('Lib\examples\Basic operators\main.sac');
  //var s := new Script('Lib\Temp\SAC Script.sac');
  s.otp += s->writeln(s);
  s.Execute;
end.

//