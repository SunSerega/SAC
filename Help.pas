uses LocaleData;
uses SettingsData;

var
  h: string;
  d := new Dictionary<string, string>;

procedure Load;
begin
  var l := new List<string>;
  
  var nlcl := new Dictionary<(string, string), string>;
  
  foreach var n in Locale do
    if n.Key.Item1=CurrLocale then
      if n.Key.Item2.StartsWith('H|') then
        l.Add(n.Key.Item2.Remove(0,2)) else
      if n.Value <> '' then
        nlcl.Add(n.Key, n.Value) else
        l.Add('');
        
  
  var ll := l.Select(s->s.Length).Max+5;
  
  foreach var s in l do
    if s = '' then
      h += #10 else
    begin
      h += s + ' '*(ll-s.Length) + Translate('H|'+s)+#10;
      d.Add(s.ToLower, Translate('T|'+s));
    end;
  
  var lns := h.Split(#10);
  System.Console.WindowWidth := lns.Select(s->s.Length).Max+1;
  System.Console.WindowHeight := lns.Length+10;
  
  Locale := nlcl;
end;

begin
  LoadSettings;
  LoadLocale('#Help');
  Load;
  
//  foreach var s in d.Values do
//  begin
//    writeln(s);
//    readln;
//    System.Console.Clear;
//  end;
  
  write(h);
  
  while true do
  begin
    
    loop 3 do writeln;
    writeln(Translate('%EnterName'));
    var s := ReadlnString.ToLower;
    System.Console.Clear;
    if d.ContainsKey(s) then
      writeln(d[s]) else
      write(h);
    
  end;
  
end.