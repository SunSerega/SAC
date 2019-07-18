unit CompArgsData;

//ToDo проверить issue
// - #2046 (http://forum.mmcs.sfedu.ru/t/versiya-pascalabc-net-3-4/2303/178?u=sun_serega)

interface

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

uses System.Windows.Forms;
uses System.Drawing;

uses ExprParser;

uses MiscData;
uses LocaleData;
uses SettingsData;

{$region Exception's}

type
  _CompArgException = abstract class(Exception)
    
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Error parsing compiller arg: ' + text);
    end;
    
  end;
  UndefinedCompArgNameException = class(_CompArgException)
    
    public constructor(aname: string) :=
    inherited Create($'Arg name "{aname}" isn''t defined', KV('aname', aname as object));
    
  end;
  CannotParseBoolArgException = class(_CompArgException)
    
    public constructor(val: string) :=
    inherited Create($'Can''t parse "{val}" to bool', KV('val', val as object));
    
  end;
  CannotParseIntArgException = class(_CompArgException)
    
    public constructor(val: string) :=
    inherited Create($'Can''t parse "{val}" to integer', KV('val', val as object));
    
  end;
   
{$endregion Exception's}

{$region Main}

procedure ParseArg(var ec: ExecParams; name, val: string);
procedure ParseArg(var ec: ExecParams; arg: string);
procedure ParseArgs(var ec: ExecParams; args: sequence of string);
function ParseArgs(args: sequence of string): ExecParams;

type
  ArgsHelpForm = class(Form)
    
    public ep: ExecParams;
    private fname: string;
    private done := false;
    
    private ResBox: RichTextBox;
    private ResetResButton: Button;
    
    private RunButton: Button;
    
    
    
    public constructor(ep: ExecParams; fname, curr_command: string);
    
    private procedure ResetPos(w,h: integer);
    
    private procedure ResetRes;
    
  end;

{$endregion Main}

implementation

{$region ArgBox's}

type
  ArgBox = abstract class
    
    container: Control;
    qb: TextBox;
    
    static f: ArgsHelpForm;
    static All := new List<(string, ArgBox)>;
    static function GetBox(name: string) := All.Find(t->t[0]=name)[1];
    
    
    
    function GetValueObj: object; abstract;
    procedure SetValue(o: object); abstract;
    
    function GetValue<T> :=
    T(GetValueObj);
    
    procedure UpdatePos(var y, max_x: integer); virtual;
    begin
      
      container.Left := 10;
      container.Top := y;
      
      qb.Left := container.Right+5;
      qb.Top := y;
      
      if qb.Height>container.Height then
        container.Top += (qb.Height-container.Height) div 2 else
        qb.Top        += (container.Height-qb.Height) div 2;
      
      y += Max(container.Height, qb.Height);
      max_x := Max(max_x, qb.Right);
    end;
    
    static procedure UpdatePosAll;
    begin
      var y := 10;
      var max_x := 300;
      
      foreach var ab in All do
      begin
        ab[1].UpdatePos(y, max_x);
        y += 10;
      end;
      
      f.ResetPos(
        max_x+10 + (f.Width-f.ClientSize.Width),
        y
      );
    end;
    
    procedure UpdateValue; virtual :=
    f.ResetRes;
    
    procedure Init(name, descr: string);
    begin
      
      qb := new TextBox;
      qb.Text := '?';
      qb.Cursor := f.Cursor;
      qb.BorderStyle := BorderStyle.None;
      qb.ReadOnly := true;
      qb.AutoSize := true;
      f.Controls.Add(qb);
      
      var tt := new ToolTip;
      tt.AutomaticDelay := 0;
      tt.AutoPopDelay := 32767;
      tt.SetToolTip(qb, descr);
      
      All += (name, self);
    end;
    
  end;
  
  BoolArgBox = class(ArgBox)
    
    cb := new CheckBox;
    
    function GetValueObj: object; override := cb.Checked;
    procedure SetValue(o: object); override := cb.Checked := boolean(o);
    
    constructor(name, descr: string; val: boolean);
    begin
      
      cb.Text := name;
      cb.AutoSize := true;
      cb.Checked := val;
      cb.CheckedChanged += procedure(o,e)->UpdateValue;
      f.Controls.Add(cb);
      container := cb;
      
      inherited Init(name, descr);
    end;
    
  end;
  
  IntArgBox = class(ArgBox)
    
    tb := new RichTextBox;
    last_cursor_pos := 0;
    
    function GetValueObj: object; override;
    begin
      try
        Result := tb.Text.ToInteger;
      except
        Result := 0;
      end;
    end;
    
    procedure SetValue(o: object); override := if (tb.Text<>'') or (integer(o)<>0) then tb.Text := integer(o).ToString;
    
    constructor(name, descr: string; val: integer);
    begin
      
      tb.Text := val.ToString;
      tb.AutoSize := true;
      tb.Multiline := false;
      tb.KeyDown += (o,e)->if (e.KeyCode=Keys.Back) and (last_cursor_pos>0) then last_cursor_pos -= 1;
      tb.KeyPress += procedure(o,e)->e.Handled := (tb.SelectionLength=0) and not (e.KeyChar.IsDigit and (BigInteger.Parse(tb.Text+e.KeyChar)<=integer.MaxValue));
      tb.SelectionChanged += (o,e)->
      begin
        var n_pos := tb.SelectionStart;
        if n_pos<>0 then last_cursor_pos := n_pos;
      end;
      tb.TextChanged += (o,e)->
      try
        
        if tb.Text.Any(ch->not ch.IsDigit) then
          tb.Text := tb.Text.Where(ch->ch.IsDigit).JoinIntoString;
        
        var val := tb.Text.Length<>0 ? BigInteger.Parse(tb.Text) : 0;
        if val>integer.MaxValue then
        begin
          
          repeat
            val := val div 10;
          until val<=integer.MaxValue;
          
          tb.Text := val.ToString;
        end;
        
        UpdateValue;
        tb.SelectionStart := last_cursor_pos;
      except
        on e2: Exception do
        begin
          MessageBox.Show(e2.ToString, 'Internal Error:');
          Halt;
        end;
      end;
      f.Controls.Add(tb);
      container := tb;
      
      inherited Init(name, descr);
    end;
    
  end;
  
{$endregion ArgBox's}

{$region ArgsHelpForm}

constructor ArgsHelpForm.Create(ep: ExecParams; fname, curr_command: string);
begin
  ep.help_conf := false;
  self.ep := ep;
  self.fname := fname;
  ArgBox.f := self;
  
  self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.Fixed3D;
  self.Text := Translate('ArgsHelpFormTitle');
  self.Load += (o,e)->
  begin
    ResBox.Text := curr_command.Remove(' "!conf"');
    ResBox.SelectionStart := ResBox.Text.Length;
    //ArgBox.UpdatePosAll;
  end;
  self.Closing += (o,e)->if not done then Halt;
  
  ResBox := new RichTextBox;
  self.Controls.Add(ResBox);
  ResBox.AutoSize := true;
  ResBox.Multiline := false;
  ResBox.Font := System.Drawing.Font.Create('Courier New', ResBox.Font.Size);
  var ResBoxChanging := false;
  ResBox.TextChanged += (o,e)->
  loop 2 do
  begin
    lock ResBox do
    begin
      if ResBoxChanging then exit;
      ResBoxChanging := true;
    end;
    
    ResBox.Size := ResBox.CreateGraphics.MeasureString('W'*(ResBox.Text.Length+1), ResBox.Font).ToSize;
    ResBox.Width += ResBox.Width div 30;
    
    try
      var sb := new StringBuilder;
      var i := ResBox.SelectionStart+1;
      while i > 1 do
      begin
        i -= 1;
        sb.Insert(0,ResBox.Text[i]);
        if sb.Chars[0]='!' then break;
      end;
      
      self.ep := ParseArgs(ResBox.Text.SmartSplit(' ').Skip(1));
      
      ArgBox.GetBox('!conf'             ).SetValue( ep.help_conf );
      
      ArgBox.GetBox('!lib_m'            ).SetValue( ep.lib_mode );
      ArgBox.GetBox('!supr'             ).SetValue( ep.SupprIO );
      ArgBox.GetBox('!debug'            ).SetValue( ep.debug );
      
      ArgBox.GetBox('!max_block_size'   ).SetValue( ep.max_block_size );
      ArgBox.GetBox('!max_compile_time' ).SetValue( ep.max_compile_time );
      ArgBox.GetBox('!jciauw'           ).SetValue( ep.jci_aggressive_unwrap );
      
      if ResBox.SelectionStart=0 then
      begin
        var ind := ResBox.Text.LastIndexOf(sb.ToString);
        if ind = -1 then
          ResBox.SelectionStart := ResBox.Text.Length else
          ResBox.SelectionStart := ind+sb.Length;
      end;
      
    except
      on ee: _CompArgException do; //ToDo #2046
    end;
    
    ArgBox.UpdatePosAll;
    ResBoxChanging := false;
  end;
  
  RunButton := new Button;
  self.Controls.Add(RunButton);
  RunButton.Text := Translate('RunWithNewArgs');
  RunButton.AutoSize := true;
  RunButton.Click += (o,e)->
  begin
    ArgBox.f := nil;
    ArgBox.All := nil;
    done := true;
    self.Close;
  end;
  
  new BoolArgBox('!conf',             Translate('!conf descr'),             ep.help_conf);
  
  new BoolArgBox('!lib_m',            Translate('!lib_m descr'),            ep.lib_mode);
  new BoolArgBox('!supr',             Translate('!supr descr'),             ep.SupprIO);
  new BoolArgBox('!debug',            Translate('!debug descr'),            ep.debug);
  
  new IntArgBox ('!max_block_size',   Translate('!max_block_size descr'),   ep.max_block_size);
  new IntArgBox ('!max_compile_time', Translate('!max_compile_time descr'), ep.max_compile_time);
  new BoolArgBox('!jciauw',           Translate('!jciauw descr'),           ep.jci_aggressive_unwrap);
  
  Application.Run(self);
end;

procedure ArgsHelpForm.ResetPos(w,h: integer);
begin
  
  ResBox.Left := 10;
  ResBox.Top := h;
  
  RunButton.Left := ResBox.Right+10;
  RunButton.Top := ResBox.Top;
  
  self.SetClientSizeCore(
    
    Max(
      w,
      RunButton.Right + 10
    )
    
  ,
    
    h +
    ResBox.Height+10
    
  );
end;

procedure ArgsHelpForm.ResetRes;
begin
  ep.help_conf              := ArgBox.GetBox('!conf' )            .GetValue&<boolean>;
  
  ep.lib_mode               := ArgBox.GetBox('!lib_m')            .GetValue&<boolean>;
  ep.SupprIO                := ArgBox.GetBox('!supr' )            .GetValue&<boolean>;
  ep.debug                  := ArgBox.GetBox('!debug')            .GetValue&<boolean>;
  
  ep.max_block_size         := ArgBox.GetBox('!max_block_size')   .GetValue&<integer>;
  ep.max_compile_time       := ArgBox.GetBox('!max_compile_time') .GetValue&<integer>;
  ep.jci_aggressive_unwrap  := ArgBox.GetBox('!jciauw')           .GetValue&<boolean>;
  
  RunButton.Enabled := not ep.help_conf;
  
  var res := new StringBuilder;
  
  res += '"';
  res += fname;
  res += '"';
  
  if ep.help_conf                           then res += $' !conf';
  
  if ep.lib_mode                            then res += $' !lib_m';
  if ep.SupprIO                             then res += $' !supr';
  if ep.debug                               then res += $' !debug';
  
  if ep.max_block_size<>ExecParams.StdMBS   then res += $' !max_block_size={ep.max_block_size}';
  if ep.max_compile_time<>ExecParams.StdMCT then res += $' !max_compile_time={ep.max_compile_time}';
  if ep.jci_aggressive_unwrap               then res += $' !jciauw';
  
  ResBox.Text := res.ToString;
end;

{$endregion ArgsHelpForm}

{$region ParseArgs}

function TryParseBoolInArg(s: string): boolean;
begin
  Result := false;
  
  if not boolean.TryParse(s, Result) then
  begin
    var bi: BigInteger;
    if BigInteger.TryParse(s, bi) then
      Result := bi <> 0 else
      raise new CannotParseBoolArgException(s);
  end;
  
end;

function TryParseIntInArg(s: string): integer;
begin
  if not integer.TryParse(s, Result) then
    raise new CannotParseIntArgException(s);
end;

procedure ParseArg(var ec: ExecParams; name, val: string);
begin
  
  case name of
    '!conf':  ec.help_conf :=                             (val=nil) or TryParseBoolInArg(val);
    
    '!lib_m': ec.lib_mode :=                              (val=nil) or TryParseBoolInArg(val);
    '!supr':  ec.SupprIO :=                               (val=nil) or TryParseBoolInArg(val);
    '!debug': ec.debug :=                                 (val=nil) or TryParseBoolInArg(val);
    
    '!max_block_size': ec.max_block_size :=                             TryParseIntInArg(val);
    '!max_compile_time': ec.max_compile_time :=                         TryParseIntInArg(val);
    '!jciauw': ec.jci_aggressive_unwrap :=                (val=nil) or TryParseBoolInArg(val);
    
    else raise new UndefinedCompArgNameException(name);
  end;
  
end;

procedure ParseArg(var ec: ExecParams; arg: string);
begin
  var par := arg.SmartSplit('=',2);
  
  if par.Length=1 then
    ParseArg(ec, par[0], nil) else
    ParseArg(ec, par[0], par[1]);
  
end;

procedure ParseArgs(var ec: ExecParams; args: sequence of string) :=
foreach var arg in args do
  ParseArg(ec, arg);

function ParseArgs(args: sequence of string): ExecParams;
begin
  ParseArgs(Result, args);
end;

{$endregion ParseArgs}

begin
  try
    
    {$resource Lang\#CompArgs}
    LoadLocale('#CompArgs');
    
  except
    on e: Exception do
    begin
      MessageBox.Show(e.ToString, 'Internal Error:');
      Halt;
    end;
  end;
end.