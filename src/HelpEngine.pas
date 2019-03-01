unit HelpEngine;

uses LocaleData;
uses SettingsData;

var
  h: string;
  d := new Dictionary<string, string>;

procedure Load;
begin
  var l := new List<string>;
  
  foreach var n in Locale do
    if n.Key[0]=CurrLocale then
      if n.Key[1].StartsWith('H|') then l += n.Key[1].Substring(2) else
      if n.Value='' then l += '';
  
  var hw := l.Max(s->s.Length)+5;
  var hb := new StringBuilder;
  
  var w1 := 1;
  foreach var s in l do
    if s = '' then
      hb.AppendLine else
    begin
      var lc := hb.Length;
      
      hb += s;
      hb.Append(' ', hw-s.Length);
      hb.AppendLine(Translate('H|'+s));
      
      w1 := Max(w1, hb.Length-lc-1);//AppendLine is +2, and we need +1
      d.Add(s.ToLower, Translate('T|'+s));
    end;
  hb.Length -= 1;
  h := hb.ToString;
  var h1 := l.Count;
  d['%EnterName'] := Translate('%EnterName');
  Locale := nil;
  
  var w2 := d.Values.Max(s->s.Split(#10).Max(l->l.Length));
  var h2 := d.Values.Max(s->s.Count(ch->ch=#10)+1);
  
  var ww := Max(w1, w2);
  var wh := Max(h1, h2) + d['%EnterName'].Count(ch->ch=#10) + 1;
  System.Console.WindowWidth := ww;
  System.Console.WindowHeight := wh;
  System.Console.BufferWidth := ww;
  System.Console.BufferHeight := wh;
  
  write(h);
end;

procedure WriteHelp :=
while true do
begin
  
  write(d['%EnterName']);
  var s := ReadlnString.ToLower;
  System.Console.Clear;
  if d.ContainsKey(s) then
    write(d[s]) else
    write(h);
  
end;

procedure InitHelp(htg: string);
begin
  LoadLocale(htg);
  LoadSettings;
  Load;
  WriteHelp;
end;

end.