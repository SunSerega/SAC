uses CRT;

begin
  var s := '';
  while true do
  begin
    if s = 'key' then
    begin
      writeln('  key            �������� ��� �������� ������� �� ����������');
      writeln('  Key 65 1 ����� ������� �65(��������� A) �� ����������, ���� ������ ����� ����� �� 1 � 2 - ������ �. ���(�) ������� ����� ������ �������� WK.exe � ����� ��� �������');
    end else if s = 'sleep' then
    begin
      writeln('sleep          ������ ����� ����������');
      writeln('Sleep 1000 �������� ��������� ��������� 1000 �����������, �� ���� 1 �������');
    end else if s = 'next' then
    begin
      writeln('next           ��������� ������������� ������ � ��������� ��������');
      writeln('Next N.txt ����� ���� N.txt � ����� ��������� ���');
    end else if s = 'susp' then
    begin
      writeln('susp           ���������������� ������ ��������� �� ���������� ������� del');
      writeln('Susp ������������ ����������, ���� ����������� ����� ������ del');
    end else if s = 'movemouse' then
    begin
      writeln('movemouse      ������������ ������');
      writeln('MoveMouse 100 200 ���������� ����� �� ���������� (100;200)');
    end else if s = 'if' then
    begin
      writeln('if             ���������� 2 ����� � ��������� 1 �� 2 ��������');
      writeln('If 3 < 5 A.txt B.txt �������� ���� A.txt, ������ ��� 3 < 5. �������� ����� ����� ����������� ���� ������� ������ � ������ 1! ���� �������� 3<5 - ��������� ������ ������');
    end else if s = 'gkey' then
    begin
      writeln('gkey           ����� ������ �� �������');
      writeln('GKey 65 APresed ������� 0 ��� 1 � ����������� �� ���� ������ �� ������� �65(��������� A) � ���������� � ������ "APresed"');
    end else if s = 'gcolor' then
    begin
      writeln('gcolor         ����� ���� ��������� ������� �� �������� �������');
      writeln('GColor Pict1 10 15 R G B ������ � ������� Pict1 ���� ������� �� ����������� (10;15) � ������� ��� �������, ������ � ����� ������������ � ���������� � ���������� R, G � B ��������������');
    end else if s = 'gimage' then
    begin
      writeln('gimage         ������ ������ ������');
      writeln('GImage PrintOfScreen ������� ������ ������ � ������� ������������ ������� � ���������� � ������ PrintOfScreen');
    end else if s = 'scolor' then
    begin
      writeln('scolor         ������������� ���� ��������� ������� �� �������� �������');
      writeln('SColor Pict1 10 15 R G B ���������� ������� � ������������ (10;15) � ������� � ���� �������, ������ � ����� ������������ ������ �� ���������� � ���������� R, G � B ��������������');
    end else if s = 'saveimage' then
    begin
      writeln('saveimage      ��������� ������� � ����');
      writeln('SaveImage Pict1 Pict1.png �������� ������� � ��������� Pict1 � ���� Pict1.png');
    end else if s = 'random' then
    begin
      writeln('random         ����� ��������������� �����');
      writeln('Random r 5 ������� � ���������� � ������ r ��������� ����� ����� �� 0 ������������ �� 5 �� ������������');
    end else if s = 'saveimage' then
    begin
      writeln('loadimage      ��������� ������� �� �����');
      writeln('LoadImage Pict1 Pict1.png �������� � ���������� Pict ������� ���������� � ����� Pict1.png');
    end else if s = 'do' then
    begin
      writeln('do             ��������� �������� ������, �� � ������� �� Next �� ��������� �������������');
      writeln('Do N.txt �������� ������ � ����� N.txt �� �� ������ ��� ��� ����������� ������. ����� �� ����� Next? Do ������ �����������, ���� ������� � Main.txt ��������� ��� �� - � ����� ������ ��������� �������. ���� ���� ������� �� A.txt, B.txt � C.txt, A ��������� B, B ��������� C � C ��������� A �� ���� �� 1 �� ��� ������ �������� �� Next, ��������� ����� �� Do.');
    end else if s = 'console.write' then
    begin
      writeln('console.write       ��������� ���������� � ������ ������������ �� �������');
      writeln('Console.Write a ������� � ������ ������������ �� ������� ���������� ���������� � ������ "a"');
    end else if s = 'console.read' then
    begin
      writeln('console.read        ��������� � ���������� ����������');
      writeln('Console.Read a ������� � ���������� ����� � ������� ��� � ���������� � ������ "a"');
    end else if s = 'console.clear' then
    begin
      writeln('console.clear       �������� ������ ������������ �� ������� ����������');
      writeln('Console.Clear �������� ������ ������������ �� ������� ����������');
    end else if s = 'console.update' then
    begin
      writeln('console.update      ���������� ������ ���������� �� �������');
      writeln('Console.Update ����� �� ��� �������� �� ������� � ������� ������ � ����� ������� ����������');
    end else
    begin
      writeln('key                 �������� ��� �������� ������� �� ����������');
      writeln('sleep               ������ ����� ����������');
      writeln('next                ��������� ������������� ������ � ��������� ��������');
      writeln('susp                ���������������� ������ ��������� �� ���������� ������� del');
      writeln('movemouse           ������������ ������');
      writeln('if                  ���������� 2 ����� � ��������� 1 �� 2 ��������');
      writeln('gkey                ����� ������ �� �������');
      writeln('gcolor              ����� ���� ��������� ������� �� �������� �������');
      writeln('gimage              ������ ������ ������');
      writeln('scolor              ������������� ���� ��������� ������� �� �������� �������');
      writeln('saveimage           ��������� ������� � ����');
      writeln('random              ����� ��������������� �����');
      writeln('loadimage           ��������� ������� �� �����');
      writeln('do                  ��������� �������� ������, �� �� ��������� �������������');
      writeln('console.write       ��������� ���������� � ������ ������������ �� �������');
      writeln('console.read        ��������� � ���������� ����������');
      writeln('console.clear       �������� ������ ������������ �� ������� ����������');
      writeln('console.update      ���������� ������ ���������� �� �������');
    end;
    writeln;
    writeln('������� �������');
    s := ReadlnString.ToLower;
    CRT.ClrScr;
  end;
end.