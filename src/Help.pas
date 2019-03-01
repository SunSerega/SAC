{$mainresource 'Help.res'}

uses LocaleData;
uses SettingsData;

var
  scts := new List<string>;

procedure Load;
begin
  
  foreach var n in Locale do
    if n.Key.Item1=CurrLocale then
      if n.Key.Item2.All(ch->ch.IsDigit) then
        scts.Add(n.Value);
  
  System.Console.WindowWidth := scts.SelectMany(l->l.Split(#10)).Select(s->s.Length).Max+1;
  System.Console.WindowHeight := scts.Select(l->l.Split(#10).Length).Max+10;
  
  scts.Capacity := scts.Count;
  Locale := Locale.Where(kvp-> (kvp.Key.Item1=CurrLocale) and (kvp.Key.Item2.Length<>1) ).ToDictionary(kvp->kvp.Key,kvp->kvp.Value);
end;

begin
  {$resource Lang\#Help}
  LoadLocale('#Help');
  LoadSettings;
  Load;
  
//  foreach var s in d.Values do
//  begin
//    writeln(s);
//    readln;
//    System.Console.Clear;
//  end;
  
  var curr := 1;
  var last := 0;
  
  while true do
  begin
    
    if curr <> last then
    begin
      System.Console.Clear;
      writeln(scts[curr]);
      last := curr;
      writeln(Translate('%EnterID'));
    end;
    
    var key := System.Console.ReadKey(true);
    if (key.KeyChar >= '0') and (key.KeyChar <= (scts.Count-1).ToString[1]) then
      curr := key.KeyChar.ToString.ToInteger else
    case key.Key of
      System.ConsoleKey.DownArrow, System.ConsoleKey.RightArrow:  curr := (curr+1) mod scts.Count;
      System.ConsoleKey.UpArrow, System.ConsoleKey.LeftArrow:     curr := (curr+scts.Count-1) mod scts.Count;
      System.ConsoleKey.Enter:                                    curr := 0;
    end;
    
  end;
  
end.