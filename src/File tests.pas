uses StmParser;
uses MiscData;
//uses ExprParser;

//uses ВБФ;

//ToDo тесты для Jump[If] посередине блока
// - в блоке вызываемом Call и без

//ToDo TestExec\MultFile2 - странно, вроде правильно, но развернулось по-другому

begin
  var ep: ExecParams;
  ep.SupprIO := true;
  
  var s := new Script('D:\Мои программы\SAC\src\TestSuite\TestComp\Loop1\Main.sac',ep);
  //var s := new Script('D:\Мои программы\SAC\src\TestSuite\TestExec\Loop1\Main.sac',ep);
  //var s := new Script('D:\Мои программы\SAC Client\Lib\Полезности\RW установка мебели\Main.sac',ep);
  //var s := new Script('0\2.sac', ep);
  
  //SaveObj('test.bin',s);
  
  writeln(s);
//  loop 10 do s.Optimize;
//  writeln('-'*50);
//  writeln(s);
//  exit;
  
//  s.otp += s->writeln(s);
//  s.susp_called += procedure->writeln('%susp called');
//  s.stoped += procedure->writeln('%stoped');
//  s.Execute;
//  readln;
end.

//