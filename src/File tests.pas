﻿uses StmParser;
uses MiscData;
//uses ExprParser;

//uses ВБФ;



//ToDo Неправильно компилирует выбранный сейчас файл
// - Следующее случилось после добавления копирования Jump[If] при каждой оптимизации:
// - Там блок растёт до бесконечности
// - Оптимизация не сдыхает потому что в каждой добавленной копии блока появляется новый оператор "x=0"
// - Его можно удалить потому что после него добавляет ещё 1 оператор перезаписывающий "x"

//ToDo НОООО ИСПРАВИТЬ В ПЕРВУЮ ОЧЕРЕДЬ: почему "x=..." не удаляет из блока - откуда его берёт бесконечно растущий блок????
// - Возможно там 2 блока с JumpIf на конце...
// - Ну, бесконечно разворачивать их не должно всё равно!
// - Если переменную будет удалять сразу - это всё должно быть не бесконечно

//ToDo Но, конечно, там так же есть логическая ошибка, ибо в данной программе цикл конечный
// - Если уже и разворачивает - кода выйдет много, но не бесконечность
// - Но лучше добавить проверку: [> JumpIf ... "Loop" ... <] - тоже считать за цикл, раз одна из ветвей возвращается к #Loop
// - А чтоб если уже разворачивает то разворачивало до конца:

//ToDo Так же, наверное придётся добавить IsSame в StmBase, чтоб после GetBlockChain проверять изменилось ли что то
// - Обычным = теперь, конечно, сравнивать нельзя, раз Jump[If] копирует
// - И может есть другие причины, но с IsSame проблем не должно быть

//ToDo И ешё, раз теперь Jump[If] копирует - надо проверить что будет если его скопирует в другой файл, в другой папке
// - Если DynamicStmBlockRef будет ломаться - его тоже надо копировать, по особому как то
// - В DynamicStmBlockRef вообще надо хранить имя начального файла, ибо проблемы и в других случаях могут быть



// -------------------------------------
//Итого, список что надо сделать, в правильном порядке:

// разобраться почему "x=..." не удаляет
// найти логическую ошибку
// разобраться почему лишний раз разворачивает цикл (его продублировало) и почему в конце оказался Return вместо бесконечного цикла
// [> JumpIf ... "Loop" ... <] не разворачивать
// хранить имя файла в DynamicStmBlockRef
//ToDo добавить IsSame в StmBase



begin
  var ep: ExecParams;
  ep.SupprIO := true;
  
  //var s := new Script('D:\Мои программы\SAC\src\TestSuite\TestExec\AllFuncs\Main.sac',ep);
  var s := new Script('D:\Мои программы\SAC Client\Lib\Полезности\RW установка мебели\Main.sac',ep);
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