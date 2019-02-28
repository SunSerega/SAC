function GetAllFiles(d: string): sequence of string;
begin
  yield sequence System.IO.Directory.EnumerateDirectories(d).SelectMany(GetAllFiles);
  yield sequence System.IO.Directory.EnumerateFiles(d);
end;

begin
  try
    
    var bw := new System.IO.BinaryWriter(System.IO.File.Create('lib_pack'));
    
    var saving :=
      'Lib\examples'.Split(#10);
    
    foreach var f in
      saving
      .SelectMany(GetAllFiles)
      .ToHashSet
    do
    begin
      bw.Write(System.IO.Path.GetDirectoryName(f));
      bw.Write(System.IO.Path.GetFileName(f));
      var str := System.IO.File.OpenRead(f);
      bw.Write(str.Length);
      bw.Flush;
      str.CopyTo(bw.BaseStream);
      str.Close;
      bw.BaseStream.Flush;
      
      writeln($'Saved lib file "{f}"');
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