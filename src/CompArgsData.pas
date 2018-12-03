unit CompArgsData;

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
   
{$endregion Exception's}

{$region Main}

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
    
    cb: CheckBox;
    qb: TextBox;
    
    static f: ArgsHelpForm;
    static All := new List<(string, ArgBox)>;
    static function GetBox(name: string) := All.Find(t->t[0]=name)[1];
    
    procedure UpdatePos(var y, max_x: integer); virtual;
    begin
      
      cb.Left := 10;
      cb.Top := y;
      
      qb.Left := cb.Right+5;
      qb.Top := cb.Top+3;
      
      y += cb.Height;
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
    
    constructor(name, descr: string; active: boolean);
    begin
      
      cb := new CheckBox;
      cb.Text := name;
      cb.AutoSize := true;
      cb.Checked := active;
      cb.CheckedChanged += procedure(o,e)->UpdateValue;
      f.Controls.Add(cb);
      
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
  
  SimpleArgBox = class(ArgBox)
    
    constructor(name, descr: string; active: boolean) :=
    inherited Create(name, descr, active);
    
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
    if ResBoxChanging then exit;
    ResBoxChanging := true;
    
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
      
      ArgBox.GetBox('!conf' ).cb.Checked := ep.help_conf;
      ArgBox.GetBox('!debug').cb.Checked := ep.debug;
      ArgBox.GetBox('!lib_m').cb.Checked := ep.lib_mode;
      ArgBox.GetBox('!supr' ).cb.Checked := ep.SupprIO;
      
      if ResBox.SelectionStart=0 then
      begin
        var ind := ResBox.Text.LastIndexOf(sb.ToString);
        if ind = -1 then
          ResBox.SelectionStart := ResBox.Text.Length else
          ResBox.SelectionStart := ind+sb.Length;
      end;
      
    except
      on _CompArgException do;
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
  
  new SimpleArgBox('!conf',  Translate('!conf descr'),  ep.help_conf);
  new SimpleArgBox('!debug', Translate('!debug descr'), ep.debug);
  new SimpleArgBox('!lib_m', Translate('!lib_m descr'), ep.lib_mode);
  new SimpleArgBox('!supr',  Translate('!supr descr'),  ep.SupprIO);
  
  Application.Run(self);
end;

procedure ArgsHelpForm.ResetPos(w,h: integer);
begin
  
  ResBox.Left := 10;
  ResBox.Top := h;
  
  RunButton.Left := ResBox.Right+10;
  RunButton.Top := ResBox.Top;
  
  self.Width := Max(
    w,
    RunButton.Right + 10 + (self.Width-self.ClientSize.Width)
  );
  self.Height :=
    h +
    ResBox.Height+10 +
    (self.Height-self.ClientSize.Height);
end;

procedure ArgsHelpForm.ResetRes;
begin
  ep.help_conf  := ArgBox.GetBox('!conf' ).cb.Checked;
  ep.debug      := ArgBox.GetBox('!debug').cb.Checked;
  ep.lib_mode   := ArgBox.GetBox('!lib_m').cb.Checked;
  ep.SupprIO    := ArgBox.GetBox('!supr' ).cb.Checked;
  
  RunButton.Enabled := not ep.help_conf;
  
  var res := new StringBuilder;
  
  res += '"';
  res += fname;
  res += '"';
  
  if ep.help_conf then res += ' !conf';
  if ep.debug     then res += ' !debug';
  if ep.lib_mode  then res += ' !lib_m';
  if ep.SupprIO   then res += ' !supr';
  
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

function ParseArgs(args: sequence of string): ExecParams;
begin
  
  foreach var arg:string in args do
  begin
    var par := arg.SmartSplit('=',2);
    
    case par[0] of
      
      '!conf':  Result.help_conf := (par.Length=1) or TryParseBoolInArg(par[1]);
      '!debug': Result.debug :=     (par.Length=1) or TryParseBoolInArg(par[1]);
      '!lib_m': Result.lib_mode :=  (par.Length=1) or TryParseBoolInArg(par[1]);
      '!supr':  Result.SupprIO :=   (par.Length=1) or TryParseBoolInArg(par[1]);
      
      else raise new UndefinedCompArgNameException(par[0]);
    end;
    
  end;
  
end;

{$endregion ParseArgs}

begin
  try
    
    {$resource Lang\#CompArgs}
    LoadLocale('#CompArgs');
    
  except
    on e: Exception do
    begin
      writeln(e);
      readln;
    end;
  end;
end.