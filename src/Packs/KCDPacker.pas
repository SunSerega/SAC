begin
  try
    var bw := new System.IO.BinaryWriter(System.IO.File.Create('Packs\kcd_pack'));
    //System.Environment.CurrentDirectory := System.IO.Path.GetDirectoryName(System.Environment.CurrentDirectory);
    
    var lang_spec_keys := new Dictionary<char, byte>;
    var named_keys := new Dictionary<string, byte>;
    
    foreach var f in System.IO.Directory.EnumerateFiles('Key Name-Code Data', '*.kcd') do
    begin
      var sr := System.IO.File.OpenText(f);
      var lang := f.Contains('#');
      
      while not sr.EndOfStream do
      begin
        var l := sr.ReadLine;
        if l = '' then continue;
        var s := l.Split('=');
        if lang then
          lang_spec_keys.Add(s[0].Single, byte.Parse(s[1]));
          named_keys.Add(s[0], byte.Parse(s[1]));
      end;
      sr.Close;
      
      if lang then
        writeln($'Saved lang spec keys from "{f}"') else
        writeln($'Saved named keys from     "{f}"');
    end;
    
    bw.Write(lang_spec_keys.Count);
    foreach var kvp in lang_spec_keys do
    begin
      bw.Write(kvp.Key.ToUpper);
      bw.Write(kvp.Value);
    end;
    
    bw.Write(named_keys.Count);
    foreach var kvp in named_keys do
    begin
      bw.Write(kvp.Key);
      bw.Write(kvp.Value);
    end;
    
    bw.Close;
  except
    on e: Exception do
    begin
      writeln('Error:');
      writeln(e);
      readln;
    end;
  end;
end.