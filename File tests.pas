uses StmParser;
uses ExprParser;

begin
  var s := new Script('Lib\Temp\test.sac');
  s.otp += s->writeln(s);
  s.Execute;
end.