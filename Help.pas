uses CRT;

begin
  var s := '';
  while true do
  begin
    if s = 'key' then
    begin
      writeln('  key            нажимает или отжимает клавишу на клавиатуре');
      writeln('  Key 65 1 нажмёт клавишу №65(латинское A) на клавиатуре, если второе число будет не 1 а 2 - отожмёт её. код(№) клавиши можно узнать запустив WK.exe и нажав эту клавишу');
    end else if s = 'sleep' then
    begin
      writeln('sleep          делает паузу выполнения');
      writeln('Sleep 1000 заставит программу подождать 1000 миллисекунд, то есть 1 секунду');
    end else if s = 'next' then
    begin
      writeln('next           закрывает выполняющийся скрипт и запускает указаный');
      writeln('Next N.txt найдёт фаил N.txt и начнёт выполнять его');
    end else if s = 'susp' then
    begin
      writeln('susp           приостонавливает работу программы до следующего нажатия del');
      writeln('Susp приостоновит выполнение, чтоб возобновить нужно нажать del');
    end else if s = 'movemouse' then
    begin
      writeln('movemouse      переставляет курсор');
      writeln('MoveMouse 100 200 переместит мышку на координаты (100;200)');
    end else if s = 'if' then
    begin
      writeln('if             сравнивает 2 числа и выполняет 1 из 2 действий');
      writeln('If 3 < 5 A.txt B.txt выполнит фаил A.txt, потому что 3 < 5. ВНИМАНИЕ между всеми параметрами надо ставить пробел и только 1! если написать 3<5 - программа выдаст ошибку');
    end else if s = 'gkey' then
    begin
      writeln('gkey           узнаёт нажата ли клавиша');
      writeln('GKey 65 APresed запишет 0 или 1 в зависимости от того нажата ли клавиша №65(латинское A) в переменную с именем "APresed"');
    end else if s = 'gcolor' then
    begin
      writeln('gcolor         узнаёт цвет выбраного пикселя на выбраном рисунке');
      writeln('GColor Pict1 10 15 R G B возьмёт у рисунка Pict1 цвет пикселя на координатах (10;15) и запишет его красную, зелёную и синюю составляющие в переменные с названиями R, G и B соответственно');
    end else if s = 'gimage' then
    begin
      writeln('gimage         делает снимок экрана');
      writeln('GImage PrintOfScreen сделает снимок экрана и запишет получившийся рисунок в переменную с именем PrintOfScreen');
    end else if s = 'scolor' then
    begin
      writeln('scolor         устанавливает цвет выбраного пикселя на выбраном рисунке');
      writeln('SColor Pict1 10 15 R G B перекрасит пиксель с координатами (10;15) и запишет в него красную, зелёную и синюю составляющие взятые из переменных с названиями R, G и B соответственно');
    end else if s = 'saveimage' then
    begin
      writeln('saveimage      сохраняет рисунок в фаил');
      writeln('SaveImage Pict1 Pict1.png сохранит рисунок с названием Pict1 в фаил Pict1.png');
    end else if s = 'random' then
    begin
      writeln('random         выдаёт псевдослучайное число');
      writeln('Random r 5 запишет в переменную с именем r случайное целое число от 0 включительно до 5 не включительно');
    end else if s = 'saveimage' then
    begin
      writeln('loadimage      загружает рисунок из фаила');
      writeln('LoadImage Pict1 Pict1.png загрузит в переменную Pict рисунок хранящийся в фаиле Pict1.png');
    end else if s = 'do' then
    begin
      writeln('do             запускает указаный скрипт, но в отличии от Next не закрывает выполняющийся');
      writeln('Do N.txt запустит скрипт в фаиле N.txt но не закрое тот что выполняется сейчас. зачем же тогда Next? Do нельзя зацикливать, если сказать в Main.txt открывать его же - в конце концов программа вылетит. если есть цепочка из A.txt, B.txt и C.txt, A открывает B, B открывает C и C открывает A то хотя бы 1 из них должно работать на Next, остальные можно на Do.');
    end else if s = 'console.write' then
    begin
      writeln('console.write       добавляет переменную в список выписываемых на консоль');
      writeln('Console.Write a добавит в список выписываемых на консоль переменных переменную с именем "a"');
    end else if s = 'console.read' then
    begin
      writeln('console.read        считывает с клавиатуры переменную');
      writeln('Console.Read a считает с клавиатуры число и запишет его в переменную с именем "a"');
    end else if s = 'console.clear' then
    begin
      writeln('console.clear       отчищает список выписываемых на консоль переменных');
      writeln('Console.Clear отчистит список выписываемых на консоль переменных');
    end else if s = 'console.update' then
    begin
      writeln('console.update      выписывает список переменных на консоль');
      writeln('Console.Update сотрёт всё что написано на консоли и выпишет заново с новым списком переменных');
    end else
    begin
      writeln('key                 нажимает или отжимает клавишу на клавиатуре');
      writeln('sleep               делает паузу выполнения');
      writeln('next                закрывает выполняющийся скрипт и запускает указаный');
      writeln('susp                приостонавливает работу программы до следующего нажатия del');
      writeln('movemouse           переставляет курсор');
      writeln('if                  сравнивает 2 числа и выполняет 1 из 2 действий');
      writeln('gkey                узнаёт нажата ли клавиша');
      writeln('gcolor              узнаёт цвет выбраного пикселя на выбраном рисунке');
      writeln('gimage              делает снимок экрана');
      writeln('scolor              устанавливает цвет выбраного пикселя на выбраном рисунке');
      writeln('saveimage           сохраняет рисунок в фаил');
      writeln('random              выдаёт псевдослучайное число');
      writeln('loadimage           загружает рисунок из фаила');
      writeln('do                  запускает указаный скрипт, но не закрывает выполняющийся');
      writeln('console.write       добавляет переменную в список выписываемых на консоль');
      writeln('console.read        считывает с клавиатуры переменную');
      writeln('console.clear       отчищает список выписываемых на консоль переменных');
      writeln('console.update      выписывает список переменных на консоль');
    end;
    writeln;
    writeln('введите команду');
    s := ReadlnString.ToLower;
    CRT.ClrScr;
  end;
end.