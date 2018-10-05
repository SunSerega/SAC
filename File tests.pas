uses StmParser;
uses ExprParser;

begin
  var s := new Script('Lib\Temp\Main.sac');
  s.otp += s->writeln(s);
  s.Execute;
end.