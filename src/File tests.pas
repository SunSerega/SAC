uses StmParser;
uses MiscData;
//uses ExprParser;

//uses ВБФ;

//ToDo тесты для Jump[If] посередине блока
// - в блоке вызываемом Call и без

begin
  var ep: ExecParams;
  ep.SupprIO := true;
  
  //var s := new Script('D:\Мои программы\Проекты\SAC\src\TestSuite\TestComp\VarMove3\Main.sac',ep);
  //var s := new Script('D:\Мои программы\Проекты\SAC\src\TestSuite\TestExec\JumpIf1\Main.sac',ep);
  var s := new Script('D:\Мои программы\Проекты\SAC Client\Lib\Полезности\Ctrl+V, ArrowUp\Main.sac',ep); // ToDo перед первой оптимизацией - показывает что последний параметр CallIf это "", хотя он null. Разобраться
  //var s := new Script('0\2.sac', ep);
  
  //SaveObj('test.bin',s);
  
  writeln(s);
//  loop 10 do s.Optimize;
//  writeln('-'*50);
//  writeln(s);
//  exit;
  
  s.otp += s->writeln(s);
  s.susp_called += procedure->writeln('%susp called');
  s.stoped += procedure->writeln('%stoped');
  s.Execute;
//  readln;
end.

//