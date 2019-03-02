unit KCDData;

interface

function GetKeyCode(key: string): byte;

function GetKeyName(key: byte): string;

type 
  KeyDataNotFoundException = class(Exception)
    
    constructor(key: string) :=
    inherited Create($'Undefined key: "{key}"');
    
  end;

implementation

var
  lang_spec_keys := new List<(char, byte)>;
  named_keys := new List<(string, byte)>;

function GetKeyCode(key: string): byte;
begin
  var s := key.ToLower;
  var res := named_keys.FirstOrDefault(t->t[0].ToLower=s);
  
  if res<>nil then
    Result := res[1] else
    case key[1] of
      'A'..'Z': Result := word(key[1]);
      '0'..'9': Result := word(key[1]);
      'a'..'z': Result := word(key[1])-32;
      else
        begin
          var ch := key[1].ToUpper;
          var res2 := lang_spec_keys.FirstOrDefault(t->t[0]=ch);
          if res2=nil then raise new KeyDataNotFoundException(key);
          Result := res2[1];
        end;
    end;
  
end;

function GetKeyName(key: byte): string;
begin
  case key of
    65..90:   Result := char(key);
    48..57:   Result := char(key);
    else
      begin
        var res := named_keys.FirstOrDefault(kvp->kvp[1]=key);
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