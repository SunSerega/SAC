uses LocaleData;

function GetAllLangData(fname: string): Dictionary<string, string>;
begin
  Result := new Dictionary<string, string>;
  var sr := System.IO.File.OpenText(fname);
  var sb := new StringBuilder;
  var header: string := nil;
  
  while not sr.EndOfStream do
  begin
    var s := sr.ReadLine.Trim(' ').Remove(#0, #13);
    
    if header<>nil then
    begin
      s := s.TrimStart(#9);
      
      if s.EndsWith('\') then
      begin
        sb += s;
        sb.Length -= 1;
        sb += #10;
      end else
      begin
        sb += s;
        Result.Add(header, sb.ToString);
        header := nil;
        sb.Clear;
      end;
      
    end else
    begin
      if s.Length=0 then continue;
      
      var ss := s.Split(new char[]('='),2);
      if ss.Length<>2 then raise new Exception('Expected next def');
      
      header := ss[0].TrimEnd(#9);
      if ss[1].EndsWith('\') then
      begin
        sb += ss[1];
        sb.Length -= 1;
      end else
      begin
        Result.Add(header, ss[1]);
        header := nil;
      end;
      
    end;
    
  end;
  
  sr.Close;
end;

begin
  try
    
    foreach var htg in
      System.IO.Directory.EnumerateFiles($'Lang\{LangList[0]}')
      .Where(fname->System.IO.Path.GetExtension(fname)='.lang')
      .Select(System.IO.Path.GetFileNameWithoutExtension)
    do
    begin
      
      var str := System.IO.File.Create($'Lang\{htg}');
      var bw := new System.IO.BinaryWriter(str);
      
      foreach var lang in LangList do
      begin
        
        bw.Write(lang);
        
        var d := GetAllLangData($'Lang\{lang}\{htg}.lang');
        bw.Write(d.Count);
        foreach var kvp in d do
        begin
          bw.Write(kvp.Key);
          bw.Write(kvp.Value);
        end;
        
      end;
      
      str.Close;
      writeln($'Packed all langs for {htg}');
    end;
    
  except
    on e: Exception do
    begin
      writeln('Error:');
      writeln(e);
      readln;
    end;
  end;
end.