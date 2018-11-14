uses StmParser;
//uses ExprParser;

//ToDo неправильно компилируется, надо исправить в StmParser пару моментов
//ToDo узнать как получается obj_var#? после оптимизации (должна создаваться копия при любых изменениях чтоб такого небыло)

begin
  //var s := new Script('Lib\examples\Basic operators\main.sac');
  //var s := new Script('Lib\Temp\SAC Script.sac');
  var s := new Script('Lib\Temp\main.sac');
  writeln(s);
  readln;
  s.otp += s->writeln(s);
  s.susp_called += procedure->writeln('%susp called');
  s.stoped += procedure->writeln('%stoped');
  s.Execute;
  readln;
end.

//