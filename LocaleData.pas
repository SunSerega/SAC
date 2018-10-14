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

{$resource 'Lang\RU.lang'}
{$resource 'Lang\EN.lang'}
procedure LoadLocale(htg: string);
begin
  foreach var lang_id in LangList do
  begin
    var fname := lang_id+'.lang';
    var sr := new System.IO.StreamReader(GetResourceStream(fname));
    var f := false;
    
    while not sr.EndOfStream do
    begin
      var s := sr.ReadLine;
      if s = '' then continue;
      if s[1] = '#' then
        f := s = htg else
      if f then
      begin
        var ss := s.Split(new char[]('='),2);
        Locale.Add((lang_id, ss[0].TrimEnd(#9)),ss[1].Replace('\#10',#10));
      end;
    end;
    
    sr.Close;
  end;
end;

function Translate(text:string):string;
begin
  var key := (CurrLocale, text);
  if Locale.ContainsKey(key) then
    Result := Locale[key] else
    Result := '*Translation Error*';
end;

end.