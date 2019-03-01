unit KCDData;

interface

function GetKeyCode(s: string): byte;

function GetKeyName(k: byte): string;

type KeyDataNotFoundException = class(Exception) end;

implementation

var
  lang_spec_keys := new List<(char, byte)>;
  named_keys := new List<(string, byte)>;

function GetKeyCode(s: string): byte;
begin
  if s.Length=1 then
    case s[1] of
      'A'..'Z': Result := word(s[1]);
      '0'..'9': Result := word(s[1]);
      'a'..'z': Result := word(s[1])-32;
      else
        begin
          var ch := s[1].ToUpper;
          var res := lang_spec_keys.FirstOrDefault(t->t[0]=ch);
          if res=nil then raise new KeyDataNotFoundException;
          Result := res[1];
        end;
    end else
    begin
      s := s.ToLower;
      var res := named_keys.FirstOrDefault(t->t[0].ToLower=s);
      if res=nil then raise new KeyDataNotFoundException;
      Result := res[1];
    end;
end;

function GetKeyName(k: byte): string;
begin
  case k of
    65..90: Result := char(k);
    48..57: Result := char(k);
    else
      begin
        var res := named_keys.FirstOrDefault(kvp->kvp[1]=k);
        Result := res=nil?'?':res[0];
      end;
  end;
end;

{$resource 'Packs\kcd_pack'}
procedure Load;
begin
  var br := new System.IO.BinaryReader(GetResourceStream('kcd_pack'));
  loop br.ReadInt32 do lang_spec_keys += (br.ReadChar, br.ReadByte);
  loop br.ReadInt32 do named_keys += (br.ReadString, br.ReadByte);
end;

begin
  Load;
end.