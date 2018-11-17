unit LocaleData;

var
  Locale := new Dictionary<(string,string),string>;
  CurrLocale := '';

const
  LangList: array of string =
  (
    'EN',
    'RU'
  );

procedure LoadLocale(htg: string);
begin
  var sr := new System.IO.StreamReader(GetResourceStream(htg));
  var lang_id := LangList[0];
  var sb := new StringBuilder;
  
  while not sr.EndOfStream do
  begin
    var s := sr.ReadLine;
    if s = '' then continue;
    if s[1] = '~' then
      lang_id := s.Remove(0,1) else
    begin
      var ss := s.Split(new char[]('='),2);
      sb += ss[1];
      if ss[1].LastOrDefault='\' then
      repeat
        sb.Remove(sb.Length-1,1);
        s := sr.ReadLine;
        sb += #10;
        sb += s;
      until (s.Last<>'\') or sr.EndOfStream;
      Locale.Add((lang_id, ss[0]),sb.ToString);
      sb.Clear;
    end;
  end;
  
  sr.Close;
end;

function Translate(text:string):string;
begin
  var key := (CurrLocale, text);
  if Locale.ContainsKey(key) then
    Result := Locale[key] else
    Result := '*Translation Error*';
end;

end.