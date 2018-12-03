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
  var str := GetResourceStream(htg);
  var br := new System.IO.BinaryReader(str);
  
  while str.Position < str.Length do
  begin
    var lang_id := br.ReadString;
    
    loop br.ReadInt32 do
    begin
      var key := br.ReadString;
      var val := br.ReadString;
      Locale.Add((lang_id, key), val);
    end;
    
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