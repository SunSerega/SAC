unit MiscData;
{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

{$region Loging}

var
  StartTime := System.DateTime.Now;
  
procedure WTF(name: string; params obj: array of object) := lock name do System.IO.File.AppendAllText(name, string.Join('', obj.ConvertAll(a -> _ObjectToString(a))) + char(13) + char(10));

procedure SaveError(params obj: array of object);
begin
  (new System.Threading.Thread(()->
  lock 'Errors.txt' do
  begin
    
    (new System.Threading.Thread(()->System.Console.Beep(1000, 1000))).Start;
    if not System.IO.File.Exists('Errors.txt') then
      WTF('Errors.txt', 'Started|', StartTime);
    var b := true;
    while b do
      try
        WTF('Errors.txt', new object[2](System.DateTime.Now, '|') + obj);
        b := false;
      except
      end;
    
  end)).Start;
end;

procedure Log(params data: array of object) := WTF('Log.txt', data);

procedure Log2(params data: array of object) := WTF('Log2.txt', data);

procedure Log3(params data: array of object) := WTF('Log3.txt', data);

{$endregion}

type
  Point=record
    X,Y: integer;
    constructor(X,Y: integer);
    begin
      self.X := X;
      self.Y := Y;
    end;
  end;
  ExecParams = record
    
    public help_conf := false;
    
    public debug := false;
    public SupprIO := false;
    public lib_mode := false;
    
  end;
  
end.