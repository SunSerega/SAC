uses LocaleData;

begin
  try
    
    var fls :=
      System.IO.Directory.EnumerateFiles('Lang')
      .Where(fname->fname.StartsWith($'Lang\{LangList[0]}'))
      .ToList;
    
    foreach var fname in fls do
    begin
      
      var htg := System.IO.Path.GetFileNameWithoutExtension(fname).Split('+')[1];
      var str := System.IO.File.Create($'Lang\{htg}');
      var sw := new System.IO.StreamWriter(str);
      
      foreach var lang in LangList do
      begin
        
        if lang <> LangList[0] then
          sw.WriteLine($'~{lang}');
        
        var sr := new System.IO.StreamReader(System.IO.File.OpenRead(fname.Replace(LangList[0],lang)));
        while not sr.EndOfStream do
        begin
          var s := sr.ReadLine;
          if s = '' then continue;
          var s_sp := s.Split(new char[]('='), 2);
          
          if (s_sp.Length=2) and (s_sp[0].Last='\') then
            s_sp := new string[](s_sp[0].Remove(s_sp[0].Length-1)+'='+s_sp[1]);
          
          if (s_sp.Length=2) and (s_sp[1]='\') then
            sw.WriteLine(s_sp[0].TrimEnd(#9)+'='+sr.ReadLine.TrimStart(#9).Replace('\=','=')) else
            sw.WriteLine(
              s_sp
              .Reverse
              .Select(
                (ss,i)->
                begin
                  
                  Result := i=0?
                  ss.TrimStart(#9):
                  ss.TrimEnd(#9)
                  
                end
                
              )
              .Reverse
              .JoinIntoString('=')
              .Replace(#13,'')
            );
          
        end;
        sr.Close;
        
      end;
      
      sw.Close;
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