unit SettingsData;

uses LocaleData;

var
  Settings := new Dictionary<string, object>;

function TryGetSettingsValue<T>(key: string; var val: T): boolean;
begin
  if not Settings.ContainsKey(key) then exit;
  var o := Settings[key];
  if o is T then
  begin
    val := T(o);
    Result := true;
  end;
end;

function GetSettingsValue<T>(key: string; def: T): T;
begin
  if not TryGetSettingsValue(key, Result) then Result := def;
end;

procedure LoadSettings(fname: string := System.Environment.GetEnvironmentVariable('ProgramFiles')+'\ScriptAutoClicker\Settings.ini');
begin
  var sr := new System.IO.StreamReader(System.IO.File.OpenRead(fname));
  
  while not sr.EndOfStream do
  begin
    var s := sr.ReadLine.Split(new char[]('='),2);
    
    case s[0] of
      'CurrLang': Settings.Add(s[0], s[1]);
    end;
  end;
  
  sr.Close;
  
  LocaleData.CurrLocale := GetSettingsValue('CurrLang', LangList[0]);
end;

end.