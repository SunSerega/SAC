unit StmParser;

//ToDo Контекст ошибок
//ToDo Операторы ОБЯЗАНЫ при оптимизации добавлять имена своих переменных, чтоб FinalOptimize не удаляла эти переменные (да и чтоб просто Optimize работала эффективнее)
//ToDo подставлять переменные можно только в данном блоке. потому что следующий может быть вызван из нескольких мест

//ToDo При загрузке абстрактный и физический файл могут наложится. надо их совмещать, но если будет дубль лэйбла - давать ошибку
// - так же по особому обрабатывать лэйблы начинающиеся с %. Запретить вызов и про совмещении переименовывать

//ToDo Directives:  !NoOpt/!Opt
//ToDo Directives:  !SngDef:i1=num:readonly/const

//ToDo даже если несколько блоков вызывают какой то один - можно всё равно узнать какие переменные могут иметь какой тип. FinalOptimize не проведёшь, но Optimize вполне

//ToDo Проверить, не исправили ли issue компилятора
// - #1488

interface

uses ExprParser;

uses MiscData;
uses LocaleData;
uses SettingsData;

type
  {$region pre desc}
  
  StmBase = class;
  
  StmBlockRef = class;
  
  StmBlock = class;
  Script = class;
  
  {$endregion pre desc}
  
  {$region Context}
  
  FileContextArea = abstract class
    
    public debug_name: string;
    
    public function GetSubAreas: IList<FileContextArea>; abstract;
    
  end;
  SimpleFileContextArea = sealed class(FileContextArea)
    
    public fname: string;
    public l1,l2: integer;
    public bl: StmBlock;
    
    public left: integer;
    public ExprContext: ExprContextArea;
    
    public function GetSubAreas: IList<FileContextArea>; override := new FileContextArea[](self);
    
    public static function GetAllSimpleAreas(a: FileContextArea): sequence of SimpleFileContextArea :=
    a.GetSubAreas.SelectMany(
      sa->
      (sa is SimpleFileContextArea)?
      Seq(sa as SimpleFileContextArea):
      GetAllSimpleAreas(sa)
    );
    
    public static function TryCombine(var a1: SimpleFileContextArea; a2: SimpleFileContextArea): boolean;
    begin
      Result :=
        (a1.fname = a2.fname) and
        (a1.bl = a2.bl) and
        (a1.left = 0) and
        (a2.left = 0) and
        (a1.ExprContext = nil) and
        (a2.ExprContext = nil) and
        (
          ( (a1.l1 >= a2.l1-1) and (a1.l1 <= a2.l2+1) ) or
          ( (a1.l2 >= a2.l1-1) and (a1.l2 <= a2.l2+1) )
        );
      
      if Result then
        a1 := new SimpleFileContextArea(
          a1.fname,
          Min(a1.l1,a2.l1),
          Max(a1.l2,a2.l2),
          a1.bl,
          0,
          nil,
          (new string[](a1.debug_name,a2.debug_name))
          .Where(s->s<>'')
          .JoinIntoString('+')
        );
    end;
    
    public constructor(fname: string; l1,l2: integer; bl: StmBlock; left: integer := 0; ExprContext: ExprContextArea := nil; debug_name: string := '');
    begin
      self.fname := fname;
      self.l1 := l1;
      self.l2 := l2;
      self.bl := bl;
      
      self.left := left;
      self.ExprContext := ExprContext;
      self.debug_name := debug_name;
    end;
    
  end;
  ComplexFileContextArea = sealed class(FileContextArea)
    
    public sas: IList<FileContextArea>;
    
    public function GetSubAreas: IList<FileContextArea>; override := sas;
    
    public static function Combine(debug_name:string; params a: array of FileContextArea): FileContextArea;
    begin
      var scas := a.SelectMany(SimpleFileContextArea.GetAllSimpleAreas).ToList;
      scas.ForEach(procedure(ca)->ca.debug_name := '');
      
      var try_smpl: List<SimpleFileContextArea> -> boolean :=
      l->
      begin
        Result := false;
        for var i1 := l.Count-2 downto 0 do
          for var i2 := l.Count-1 downto i1+1 do
          begin
            var a1 := l[i1];
            if SimpleFileContextArea.TryCombine(a1, l[i2]) then
            begin
              l[i1] := a1;
              l.RemoveAt(i2);
              Result := true;
              exit;
            end;
          end;
      end;
      
      while try_smpl(scas) do;
      
      if scas.Count=1 then
      begin
        Result := scas[0];
        Result.debug_name := debug_name;
      end else
      begin
        var res := new ComplexFileContextArea;
        res.sas := scas.ConvertAll(ca->ca as FileContextArea);
        res.debug_name := debug_name;
        Result := res;
      end;
    end;
    
    public static function Combine(params a: array of FileContextArea): FileContextArea :=
    Combine(
      a
      .Select(ca->ca.debug_name)
      .Where(s->s<>'')
      .JoinIntoString('+'),
      a
    );
    
  end;
  
  ContextedExpr = sealed class
    
    expr: OptExprBase;
    context: SimpleFileContextArea;
    
  end;
  
  {$endregion Context}
  
  {$region Exception's}
  
  {$region FileCompiling}
  
  FileCompilingException = abstract class(Exception)
    
    public Sender: StmBlock;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Precompiling error in block {Sender}: ' + text);
      self.source := source;
    end;
    
  end;
  UndefinedDirectiveNameException = class(FileCompilingException)
    
    public constructor(source: StmBlock; dname: string) :=
    inherited Create(source, $'Directive name "{dname}" not defined');
    
  end;
  UndefinedOperNameException = class(FileCompilingException)
    
    public constructor(source: StmBlock; oname: string) :=
    inherited Create(source, $'Operator name "{oname}" not defined');
    
  end;
  RefFileNotFound = class(FileCompilingException)
    
    public constructor(source: object; fname: string) :=
    inherited Create(source, $'File "{fname}" not found');
    
  end;
  InvalidLabelCharactersException = class(FileCompilingException)
    
    public constructor(source: StmBlock; l: string; ch: char) :=
    inherited Create(source, $'Label can''t contain "{ch}". Label was "l"');
    
  end;
  RecursionTooBig = class(FileCompilingException)
    
    public constructor(source: Script; max: integer) :=
    inherited Create(source, $'Recursion level was > maximum, {max}');
    
  end;
  InsufficientOperParamCount = class(FileCompilingException)
    
    public constructor(source: Script; exp: integer; par: array of string) :=
    inherited Create(source, $'Insufficient operator params count, expeted {exp}, but found {par.Length}', KV('par', object(par)));
    
  end;
  InvalidSleepLengthException = class(FileCompilingException)
    
    public constructor(source: Script; l: BigInteger) :=
    inherited Create(source, $'Value {l} is invalid for Sleep operator', KV('l'+'', object(l)));
    
  end;
  InvalidKeyCodeException = class(FileCompilingException)
    
    public constructor(source: Script; k: integer) :=
    inherited Create(source, $'Key code must be 1..254, it can''t be {k}', KV('k'+'', object(k)));
    
  end;
  InvalidMouseKeyCodeException = class(FileCompilingException)
    
    public constructor(source: Script; k: integer) :=
    inherited Create(source, $'Mouse key code must be 1,2 or 4..6, it can''t be {k}', KV('k'+'', object(k)));
    
  end;
  InvalidCompNameException = class(FileCompilingException)
    
    public constructor(source: Script; comp: string) :=
    inherited Create(source, $'"{comp}" is not compare operator', KV('comp', object(comp)));
    
  end;
  InvalidUseStartPosException = class(FileCompilingException)
    
    public constructor(source: Script) :=
    inherited Create(source, $'!StartPos can only be placed after label or on begining of the file');
    
  end;
  DrctFRefNotConstException = class(FileCompilingException)
    
    public constructor(par: string; opt: OptExprBase) :=
    inherited Create(source, $'!FRef must Not contain runtime calculated expressions{#10}Input [> {par} <] was optimized to [> {opt} <], but it can''t be converted to constant');
    
  end;
  DuplicateLabelNameException = class(FileCompilingException)
    
    public constructor(o: object; lbl: string) :=
    inherited Create(source, $'Duplicate label for {lbl} found');
    
  end;
  
  {$endregion FileCompiling}
  
  {$region Inner}
  
  OutputStreamEmptyException = class(InnerException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Output stream was null');
    
  end;
  
  {$endregion Inner}
  
  {$region Load}
  
  InvalidStmBlIdException = class(LoadException)
    
    public constructor(id, c: integer) :=
    inherited Create($'Index of StmBlock[{id}] is out of range [0..{c-1}]', KV('id', object(id)), KV('c'+'', object(c)));
    
  end;
  InvalidComprTException = class(LoadException)
    
    public constructor(t: byte) :=
    inherited Create($'Can''t convert {t} to comparer char', KV('t'+'', object(t)));
    
  end;
  InvalidInpTException = class(LoadException)
    
    public constructor(t: byte) :=
    inherited Create($'Input type can be 1..2, not {t}', KV('t'+'', object(t)));
    
  end;
  InvalidBlRefTException = class(LoadException)
    
    public constructor(t: byte) :=
    inherited Create($'BlockRef type can be 1..2, not {t}', KV('t'+'', object(t)));
    
  end;
  InvalidStmTException = class(LoadException)
    
    public constructor(t: byte) :=
    inherited Create($'Stm type can be 0..2, not {t}', KV('t'+'', object(t)));
    
  end;
  InvalidOperTException = class(LoadException)
    
    public constructor(t1,t2: byte) :=
    inherited Create($'Invalid Oper type: {(t1,t2)}', KV('t1', object(t1)), KV('t2', object(t2)));
    
  end;
  InvalidDrctTException = class(LoadException)
    
    public constructor(t1,t2: byte) :=
    inherited Create($'Invalid Drct type: {(t1,t2)}', KV('t1', object(t1)), KV('t2', object(t2)));
    
  end;
  
  {$endregion Load}
  
  {$endregion Exception's}
  
  {$region Single stm}
  
  ExecutingContext = sealed class
    
    public scr: Script;
    
    public curr: StmBlock;
    public next: StmBlock;
    public nvs := new Dictionary<string, real>;
    public svs := new Dictionary<string, string>;
    public CallStack := new Stack<StmBlock>;
    public max_recursion: integer;
    
    public procedure SetVar(vname:string; val: object);
    begin
      if val is real then
      begin
        svs.Remove(vname);
        nvs[vname] := real(val);
      end else
      if val is string then
      begin
        nvs.Remove(vname);
        svs[vname] := string(val);
      end else
      begin
        nvs.Remove(vname);
        svs.Remove(vname);
      end;
    end;
    
    public procedure Push(bl: StmBlock);
    begin
      CallStack.Push(bl);
      if CallStack.Count > max_recursion then
        raise new RecursionTooBig(scr, max_recursion);
    end;
    
    public function Pop(var bl: StmBlock): boolean;
    begin
      Result := CallStack.Count > 0;
      if Result then
        bl := CallStack.Pop else
        bl := nil;
    end;
    
    public function ExecuteNext: boolean;
    
    public constructor(scr: Script; entry_point: StmBlock; max_recursion: integer);
    begin
      self.scr := scr;
      self.curr := entry_point;
      self.max_recursion := max_recursion;
    end;
    
  end;
  
  StmBase = abstract class
    
    private static nfi := new System.Globalization.NumberFormatInfo;
    private static tps_lst := new List<System.Type>;
    
    public bl: StmBlock;
    public scr: Script;
    
    
    
    public function GetCalc: sequence of Action<ExecutingContext>; abstract;
    
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; virtual := self;
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; virtual :=
    Optimize(nvn, svn);
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; virtual :=
    new OptExprWrapper[0];
    
    
    
    public static function FromString(sb: StmBlock; s: string; par: array of string): StmBase;
    
    public static function ObjToStr(o: object) :=
    OptExprBase.ObjToStr(o);
    
    public static function ObjToNum(o: object) :=
    OptExprBase.ObjToNum(o);
    
    public static function NumToInt(context: object; n: real): integer;
    begin
      if real.IsNaN(n) or real.IsInfinity(n) then raise new CannotConvertToIntException(context, n);
      var i := BigInteger.Create(n);
      if (i < integer.MinValue) or (i > integer.MaxValue) then raise new CannotConvertToIntException(context, i);
      Result := integer(i);
    end;
    
    
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): StmBase;
    
  end;
  ExprStm = sealed class(StmBase)
    
    public vname: string;
    public e: OptExprWrapper;
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, e.Calc(
      ec.nvs,
      ec.svs
    ));
    
    
    
    public constructor(sb: StmBlock; text: string);
    
    public constructor(vname: string; e: OptExprWrapper; bl: StmBlock; scr: Script);
    begin
      self.vname := vname;
      self.e := e;
      self.bl := bl;
      self.scr := scr;
    end;
    
    public function Simplify(ne: OptExprWrapper): StmBase;
    begin
      
      if e=ne then
        Result := self else
        Result := new ExprStm(vname, ne, bl, scr);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override;
    begin
      Result := Simplify(e.Optimize(nvn, svn));
      var main := ExprStm(Result).e.GetMain;
      
      if main is OptNExprBase then
      begin
        nvn.Add(vname);
        svn.Remove(vname);
      end else
      if main is OptSExprBase then
      begin
        nvn.Remove(vname);
        svn.Add(vname);
      end else;
      
    end;
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override;
    begin
      Result := Simplify(e.FinalOptimize(nvn, svn, ovn));
      var main := ExprStm(Result).e.GetMain;
      
      if main is OptNExprBase then
      begin
        nvn.Add(vname);
        svn.Remove(vname);
        ovn.Remove(vname);
      end else
      if main is OptSExprBase then
      begin
        nvn.Remove(vname);
        svn.Add(vname);
        ovn.Remove(vname);
      end else
      begin
        nvn.Remove(vname);
        svn.Remove(vname);
        ovn.Add(vname);
      end;
      
    end;
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    e.DoesUseVar(vn)?
    new OptExprWrapper[](e):
    new OptExprWrapper[0];
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(0));
      bw.Write(vname);
      e.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): ExprStm;
    begin
      Result := new ExprStm;
      Result.vname := br.ReadString;
      Result.e := OptExprWrapper.Load(br);
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    (e.GetMain is IOptLiteralExpr)?$'{vname}={e} //Const':$'{vname}={e}';
    
  end;
  OperStmBase = abstract class(StmBase)
    
    public static function FromString(sb: StmBlock; par: array of string): OperStmBase;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
    
  end;
  DrctStmBase = abstract class(StmBase)
    
    public static function FromString(sb: StmBlock; text: string): DrctStmBase;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[0];
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): DrctStmBase;
    
  end;
  
  {$endregion Single stm}
  
  {$region Stm containers}
  
  StmBlock = sealed class
    
    public StartPos := false;
    public stms := new List<StmBase>;
    public next: StmBlock := nil;
    public Execute: Action<ExecutingContext>;
    
    public fname: string;
    public lbl: string;
    public scr: Script;
    
    public function GetAllFRefs: sequence of StmBlockRef;
    
    public function EnumrNextStms: sequence of StmBase;
    
    public procedure Seal;
    begin
      Execute :=
        System.Delegate.Combine(
          stms
          .SelectMany(stm->stm.GetCalc())
          .Cast&<System.Delegate>
          .ToArray
        ) as Action<ExecutingContext>;
    end;
    
    public constructor(scr: Script) :=
    self.scr := scr;
    
    public procedure Save(bw: System.IO.BinaryWriter);
    begin
      bw.Write(StartPos);
      
      bw.Write(stms.Count);
      foreach var stm in stms do
        stm.Save(bw);
      
      if next=nil then
        bw.Write(-1) else
        next.SaveId(bw)
      
    end;
    
    public procedure SaveId(bw: System.IO.BinaryWriter);
    
    public procedure Load(br: System.IO.BinaryReader; sbs: array of StmBlock);
    begin
      StartPos := br.ReadBoolean;
      
      var c := br.ReadInt32;
      self.stms := new List<StmBase>(c);
      for var i := 0 to c-1 do
      begin
        var stm := StmBase.Load(br, sbs);
        stm.bl := self;
        stm.scr := self.scr;
        self.stms.Add(stm);
      end;
      
      var n := br.ReadInt32;
      if n <> -1 then
        if cardinal(n) < sbs.Length then
          self.next := sbs[n] else
          raise new InvalidStmBlIdException(n, c);
      
    end;
    
    public function GetBodyString: string :=
    (StartPos?'!StartPos //Const'#10:'') +
    stms.JoinIntoString(#10);
    
    public function ToString: string; override :=
    GetBodyString +
    (next=nil?#10'Return //Const':$'{#10}Jump {next.fname+next.lbl} //Const');
    
  end;
  
  Script = sealed class
    
    private static nfi := new System.Globalization.NumberFormatInfo;
    
    public read_start_lbl_name: string;
    public start_pos_def := false;
    
    public otp: procedure(s: string);
    public susp_called: procedure;
    public stoped: procedure;
    
    public LoadedFiles := new HashSet<string>;
    public sbs := new Dictionary<string, StmBlock>;
    
    private function ReadFile(context: object; lbl: string): boolean;
    
    private static function CombinePaths(p1, p2: string): string;
    begin
      
      while p2.StartsWith('..\') do
      begin
        p1 := System.IO.Path.GetDirectoryName(p1);
        p2 := p2.Remove(0, 3);
      end;
      
      Result := System.IO.Path.Combine(p1,p2);
      
    end;
    
    private static function GetRelativePath(p1, p2: string): string;
    begin
      
      var sb := new StringBuilder;
      var pp1 := p1.Split('\');
      var pp2 := p2.Split('\');
      
      var sc := pp1.Numerate(0).Count(t->t[1]=pp2[t[0]]);
      loop pp1.Length-sc do sb += '..\';
      
      foreach var pp in pp2.Skip(sc) do
      begin
        sb += pp;
        sb += '\';
      end;
      sb.Length -= 1;
      
      Result := sb.ToString;
    end;
    
    public constructor(fname: string);
    
    public procedure Optimize;
    
    public procedure Execute :=
    Execute(read_start_lbl_name);
    
    public procedure Execute(entry_point: string);
    begin
      if not entry_point.Contains('#') then entry_point += '#';
      var ec := new ExecutingContext(self, sbs[entry_point], 10000);
      while ec.ExecuteNext do;
      if stoped <> nil then
        stoped;
    end;
    
    public procedure Save(str: System.IO.Stream);
    
    public procedure Load(main_path: string; br: System.IO.BinaryReader);
    begin
      
      var prev_main_fname := br.ReadString;
      var new_main_fname := main_path.Split('\').Last;
      main_path := System.IO.Path.GetDirectoryName(main_path);
      
      loop br.ReadInt32 do
      begin
        var fname := br.ReadString;
        if fname = prev_main_fname then
          fname := new_main_fname;
        fname := CombinePaths(main_path, fname);
        
        var lsbs := new StmBlock[br.ReadInt32];
        for var i := 0 to lsbs.Length-1 do
          lsbs[i] := new StmBlock(self);
        
        for var i := 0 to lsbs.Length-1 do
        begin
          lsbs[i].fname := fname;
          lsbs[i].lbl := '#'+br.ReadString;
          self.sbs.Add(fname + lsbs[i].lbl, lsbs[i]);
          lsbs[i].Load(br, lsbs);
          lsbs[i].Seal;
        end;
        
      end;
      
      self.Optimize;
      
    end;
    
    public function ToString: string; override;
    begin
      var sb := new StringBuilder;
      
      foreach var kvp: System.Linq.IGrouping<string, StmBlock> in sbs.Values.GroupBy(bl->bl.fname) do
      begin
        sb += $' (file {kvp.Key})';
        sb += #10;
        
        foreach var bl in kvp do
        begin
          sb += bl.lbl;
          sb += #10;
          sb += bl.ToString;
          sb += #10;
          sb += #10;
        end;
        
      end;
      
      Result := sb.ToString;
    end;
    
  end;

  {$endregion Stm containers}
  
  {$region InputValue}
  
  InputSValue = abstract class
    
    public res: string;
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public function Optimize(nvn, svn: HashSet<string>): InputSValue; virtual := self;
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): InputSValue; virtual := self;
    
    public function FindVarUsages(vn: string): OptExprWrapper; virtual := nil;
    
    public static function Load(br: System.IO.BinaryReader): InputSValue;
    
  end;
  SInputSValue = sealed class(InputSValue)
    
    public constructor(res: string) :=
    self.res := res;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
    public function ToString: string; override :=
    $'"{res}"';
    
  end;
  DInputSValue = sealed class(InputSValue)
    
    public oe: OptSExprWrapper;
    
    public procedure Calc(ec: ExecutingContext) :=
    self.res := oe.CalcS(ec.nvs, ec.svs);
    
    
    
    public constructor(s: string) :=
    oe := OptExprWrapper.FromExpr(Expr.FromString(s), OptExprBase.AsStrExpr) as OptSExprWrapper;
    
    public constructor(oe: OptSExprWrapper);
    begin
      self.oe := oe;
    end;
    
    public function Simplify(noe: OptSExprWrapper): InputSValue;
    begin
      if noe.Main is OptSLiteralExpr(var sle) then
        Result := new SInputSValue(sle.res) else
      if oe=noe then
        Result := self else
        Result := new DInputSValue(noe);
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): InputSValue; override :=
    Simplify(OptSExprWrapper(oe.Optimize(nvn, svn)));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): InputSValue; override :=
    Simplify(OptSExprWrapper(oe.FinalOptimize(nvn, svn, ovn)));
    
    public function FindVarUsages(vn: string): OptExprWrapper; override :=
    oe.DoesUseVar(vn)?oe:nil;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      oe.Save(bw);
    end;
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function ToString: string; override :=
    oe.ToString;
    
  end;
  
  InputNValue = abstract class
    
    public res: real;
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public function Optimize(nvn, svn: HashSet<string>): InputNValue; virtual := self;
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): InputNValue; virtual := self;
    
    public function FindVarUsages(vn: string): OptExprWrapper; virtual := nil;
    
    public static function Load(br: System.IO.BinaryReader): InputNValue;
    
  end;
  SInputNValue = sealed class(InputNValue)
    
    public constructor(res: real) :=
    self.res := res;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
    public function ToString: string; override :=
    res.ToString(StmBase.nfi);
    
  end;
  DInputNValue = sealed class(InputNValue)
    
    public oe: OptNExprWrapper;
    
    public procedure Calc(ec: ExecutingContext) :=
    res := oe.CalcN(ec.nvs, ec.svs);
    
    
    
    public constructor(s: string) :=
    oe := OptExprWrapper.FromExpr(Expr.FromString(s), oe->OptExprBase.AsDefinitelyNumExpr(oe)) as OptNExprWrapper;
    
    public constructor(oe: OptNExprWrapper);
    begin
      self.oe := oe;
    end;
    
    public function Simplify(noe: OptNExprWrapper): InputNValue;
    begin
      if noe.Main is OptNLiteralExpr(var nle) then
        Result := new SInputNValue(nle.res) else
      if oe=noe then
        Result := self else
        Result := new DInputNValue(noe);
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): InputNValue; override :=
    Simplify(OptNExprWrapper(oe.Optimize(nvn, svn)));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): InputNValue; override :=
    Simplify(OptNExprWrapper(oe.FinalOptimize(nvn, svn, ovn)));
    
    public function FindVarUsages(vn: string): OptExprWrapper; override :=
    oe.DoesUseVar(vn)?oe:nil;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      oe.Save(bw);
    end;
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function ToString: string; override :=
    oe.ToString;
    
  end;
  
  {$endregion InputValue}
  
  {$region StmBlockRef}
  
  StmBlockRef = abstract class
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    
    public function GetBlock(curr: StmBlock): StmBlock; abstract;
    
    public function Optimize(bl: StmBlock; nvn, svn: HashSet<string>): StmBlockRef; virtual := self;
    public function FinalOptimize(bl: StmBlock; nvn, svn, ovn: HashSet<string>): StmBlockRef; virtual := self;
    
    public function FindVarUsages(vn: string): OptExprWrapper; virtual := nil;
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): StmBlockRef;
    
  end;
  StaticStmBlockRef = sealed class(StmBlockRef)
    
    public bl: StmBlock;
    
    public function GetBlock(curr: StmBlock): StmBlock; override := bl;
    
    public constructor(bl: StmBlock) :=
    self.bl := bl;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      if bl = nil then
        bw.Write(-1) else
        bl.SaveId(bw);
    end;
    
    public function ToString: string; override :=
    $'"{bl.fname+bl.lbl}"';
    
  end;
  DynamicStmBlockRef = sealed class(StmBlockRef)
    
    public s: InputSValue;
    
    public function GetCalc: Action<ExecutingContext>; override := s.GetCalc();
    
    public function GetBlock(curr: StmBlock): StmBlock; override;
    begin
      var res := s.res;
      if res <> '' then
      begin
        if res.StartsWith('#') then
          res := curr.fname+res else
          res := Script.CombinePaths(System.IO.Path.GetDirectoryName(curr.fname), res);
        
        if not res.Contains('#') then res += '#';
        
        if not curr.scr.sbs.ContainsKey(res) then
          curr.scr.ReadFile(nil, res);
        
        Result := curr.scr.sbs[res];
      end;
    end;
    
    public constructor(s: InputSValue) :=
    self.s := s;
    
    public function Simplify(bl: StmBlock; ns: InputSValue): StmBlockRef;
    begin
      if ns is SInputSValue then
      begin
        self.s := ns;
        Result := new StaticStmBlockRef(self.GetBlock(bl));
      end else
      if s=ns then
        Result := self else
        Result := new DynamicStmBlockRef(ns);
    end;
    
    public function Optimize(bl: StmBlock; nvn, svn: HashSet<string>): StmBlockRef; override :=
    Simplify(bl, s.Optimize(nvn, svn));
    
    public function FinalOptimize(bl: StmBlock; nvn, svn, ovn: HashSet<string>): StmBlockRef; override :=
    Simplify(bl, s.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): OptExprWrapper; override :=
    s.FindVarUsages(vn);
    
    public function Optimize(bl: StmBlock) :=
    Optimize(bl, new HashSet<string>, new HashSet<string>);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      s.Save(bw);
    end;
    
    public function ToString: string; override :=
    s.ToString;
    
  end;
  
  {$endregion StmBlockRef}
  
  {$region interface's}
  
  IFileRefStm = interface
    
    function GetRefs: sequence of StmBlockRef;
    
  end;
  
  ///всё что перемещает точку выполнения (Jump, Call, Return, Halt, ...)
  IContextJumpOper = interface
    
  end;
  ///только Jump и Call операторы
  IJumpCallOper = interface(IContextJumpOper)
    
  end;
  ///только Call операторы
  ICallOper = interface(IJumpCallOper)
    
  end;
  
  {$endregion interface's}
  
  {$region operator's}
  
  {$region Key}
  
  OperConstKeyDown = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext) :=
    keybd_event(kk, 0, 0, 0);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte($80 or 2));
      bw.Write(kk);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstKeyDown;
      res.kk := br.ReadByte;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    $'KeyDown {kk} //Const';
    
  end;
  OperConstKeyUp = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext) :=
    keybd_event(kk, 0, 2, 0);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte($80 or 3));
      bw.Write(kk);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstKeyUp;
      res.kk := br.ReadByte;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    $'KeyUp {kk} //Const';
    
  end;
  OperConstKeyPress = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      keybd_event(kk, 0, 0, 0);
      keybd_event(kk, 0, 2, 0);
    end;
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte($80 or 4));
      bw.Write(kk);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstKeyPress;
      res.kk := br.ReadByte;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    $'KeyPress {kk} //Const';
    
  end;
  
  OperKeyDown = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 0, 0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var ikk := NumToInt(nil, nkk.res);
        if (ikk < 1) or (ikk > 254) then raise new InvalidKeyCodeException(scr, ikk);
        Result := new OperConstKeyDown(ikk, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperKeyDown(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte(2));
      kk.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperKeyDown;
      res.kk := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'KeyDown {kk}';
    
  end;
  OperKeyUp = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 2, 0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var ikk := NumToInt(nil, nkk.res);
        if (ikk < 1) or (ikk > 254) then raise new InvalidKeyCodeException(scr, ikk);
        Result := new OperConstKeyUp(ikk, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperKeyUp(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte(3));
      kk.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperKeyUp;
      res.kk := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'KeyUp {kk}';
    
  end;
  OperKeyPress = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 0, 0);
      keybd_event(n, 0, 2, 0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var ikk := NumToInt(nil, nkk.res);
        if (ikk < 1) or (ikk > 254) then raise new InvalidKeyCodeException(scr, ikk);
        Result := new OperConstKeyPress(ikk, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperKeyPress(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte(3));
      kk.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperKeyPress;
      res.kk := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'KeyPress {kk}';
    
  end;
  OperKey = sealed class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var p := NumToInt(nil, dp.res);
      if p and $1 = $1 then keybd_event(n,0,0,0);
      if p and $2 = $2 then keybd_event(n,0,2,0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1]);
      dp := new DInputNValue(par[2]);
    end;
    
    public constructor(kk, dp: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.dp := dp;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk, ndp: InputNValue; optf: StmBase->StmBase): StmBase;
    begin
      
      if ndp is SInputNValue then
      case NumToInt(nil, ndp.res) and $3 of
        0: Result := nil;
        1: Result := optf(new OperKeyDown(nkk, bl));
        2: Result := optf(new OperKeyUp(nkk, bl));
        3: Result := optf(new OperKeyPress(nkk, bl));
      end else
      if (kk=nkk) and (dp=ndp) then
        Result := self else
        Result := new OperKey(nkk, ndp, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn), dp.Optimize(nvn, svn), stm->stm.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn), dp.FinalOptimize(nvn, svn, ovn), stm->stm.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn), dp.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte(1));
      kk.Save(bw);
      dp.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperKey;
      res.kk := InputNValue.Load(br);
      res.dp := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      dp.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'Key {kk} {dp}';
    
  end;
  
  {$endregion Key}
  
  {$region Mouse}
  
  OperConstMouseDown = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc1(ec: ExecutingContext) :=
    mouse_event($002, 0,0,0,0);
    
    private procedure Calc2(ec: ExecutingContext) :=
    mouse_event($008, 0,0,0,0);
    
    private procedure Calc4(ec: ExecutingContext) :=
    mouse_event($020, 0,0,0,0);
    
    private procedure Calc5(ec: ExecutingContext) :=
    mouse_event($080, 0,0,0,0);
    
    private procedure Calc6(ec: ExecutingContext) :=
    mouse_event($200, 0,0,0,0);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte($80 or 2));
      bw.Write(kk);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstMouseDown;
      res.kk := br.ReadByte;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override;
    begin
      
      case kk of
        1: Result := new Action<ExecutingContext>[](Calc1);
        2: Result := new Action<ExecutingContext>[](Calc2);
        4: Result := new Action<ExecutingContext>[](Calc4);
        5: Result := new Action<ExecutingContext>[](Calc5);
        6: Result := new Action<ExecutingContext>[](Calc6);
        else raise new InvalidMouseKeyCodeException(scr, kk);
      end;
      
    end;
    
    public function ToString: string; override :=
    $'MouseDown {kk} //Const';
    
  end;
  OperConstMouseUp = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc1(ec: ExecutingContext) :=
    mouse_event($004, 0,0,0,0);
    
    private procedure Calc2(ec: ExecutingContext) :=
    mouse_event($010, 0,0,0,0);
    
    private procedure Calc4(ec: ExecutingContext) :=
    mouse_event($040, 0,0,0,0);
    
    private procedure Calc5(ec: ExecutingContext) :=
    mouse_event($100, 0,0,0,0);
    
    private procedure Calc6(ec: ExecutingContext) :=
    mouse_event($400, 0,0,0,0);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte($80 or 3));
      bw.Write(kk);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstMouseUp;
      res.kk := br.ReadByte;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override;
    begin
      
      case kk of
        1: Result := new Action<ExecutingContext>[](Calc1);
        2: Result := new Action<ExecutingContext>[](Calc2);
        4: Result := new Action<ExecutingContext>[](Calc4);
        5: Result := new Action<ExecutingContext>[](Calc5);
        6: Result := new Action<ExecutingContext>[](Calc6);
        else raise new InvalidMouseKeyCodeException(scr, kk);
      end;
      
    end;
    
    public function ToString: string; override :=
    $'MouseUp {kk} //Const';
    
  end;
  OperConstMousePress = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc1(ec: ExecutingContext) :=
    mouse_event($006, 0,0,0,0);
    
    private procedure Calc2(ec: ExecutingContext) :=
    mouse_event($018, 0,0,0,0);
    
    private procedure Calc4(ec: ExecutingContext) :=
    mouse_event($060, 0,0,0,0);
    
    private procedure Calc5(ec: ExecutingContext) :=
    mouse_event($180, 0,0,0,0);
    
    private procedure Calc6(ec: ExecutingContext) :=
    mouse_event($600, 0,0,0,0);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte($80 or 4));
      bw.Write(kk);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstMousePress;
      res.kk := br.ReadByte;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override;
    begin
      
      case kk of
        1: Result := new Action<ExecutingContext>[](Calc1);
        2: Result := new Action<ExecutingContext>[](Calc2);
        4: Result := new Action<ExecutingContext>[](Calc4);
        5: Result := new Action<ExecutingContext>[](Calc5);
        6: Result := new Action<ExecutingContext>[](Calc6);
        else raise new InvalidMouseKeyCodeException(scr, kk);
      end;
      
    end;
    
    public function ToString: string; override :=
    $'MousePress {kk} //Const';
    
  end;
  
  OperMouseDown = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      case NumToInt(nil, kk.res) of
        1: mouse_event($002, 0,0,0,0);
        2: mouse_event($008, 0,0,0,0);
        4: mouse_event($020, 0,0,0,0);
        5: mouse_event($080, 0,0,0,0);
        6: mouse_event($200, 0,0,0,0);
        else raise new InvalidMouseKeyCodeException(scr, NumToInt(nil, kk.res));
      end;
      
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var ikk := NumToInt(nil, nkk.res);
        case ikk of
          1,2,4..6: Result := new OperConstMouseDown(ikk, bl);
          else raise new InvalidMouseKeyCodeException(scr, ikk);
        end;
      end else
      if kk=nkk then
        Result := self else
        Result := new OperMouseDown(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte(2));
      kk.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperMouseDown;
      res.kk := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'MouseDown {kk}';
    
  end;
  OperMouseUp = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      case NumToInt(nil, kk.res) of
        1: mouse_event($004, 0,0,0,0);
        2: mouse_event($010, 0,0,0,0);
        4: mouse_event($040, 0,0,0,0);
        5: mouse_event($100, 0,0,0,0);
        6: mouse_event($400, 0,0,0,0);
        else raise new InvalidMouseKeyCodeException(scr, NumToInt(nil, kk.res));
      end;
      
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var ikk := NumToInt(nil, nkk.res);
        case ikk of
          1,2,4..6: Result := new OperConstMouseUp(ikk, bl);
          else raise new InvalidMouseKeyCodeException(scr, ikk);
        end;
      end else
      if kk=nkk then
        Result := self else
        Result := new OperMouseUp(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte(3));
      kk.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperMouseUp;
      res.kk := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'MouseUp {kk}';
    
  end;
  OperMousePress = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      case NumToInt(nil, kk.res) of
        1: mouse_event($006, 0,0,0,0);
        2: mouse_event($018, 0,0,0,0);
        4: mouse_event($060, 0,0,0,0);
        5: mouse_event($180, 0,0,0,0);
        6: mouse_event($600, 0,0,0,0);
        else raise new InvalidMouseKeyCodeException(ec.scr, NumToInt(nil, kk.res));
      end;
      
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var ikk := NumToInt(nil, nkk.res);
        case ikk of
          1,2,4..6: Result := new OperConstMousePress(ikk, bl);
          else raise new InvalidMouseKeyCodeException(scr, ikk);
        end;
      end else
      if kk=nkk then
        Result := self else
        Result := new OperMousePress(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte(4));
      kk.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperMousePress;
      res.kk := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'MousePress {kk}';
    
  end;
  OperMouse = sealed class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: cardinal);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      var p: cardinal;
      case NumToInt(nil, kk.res) of
        1: p := $002;
        2: p := $008;
        4: p := $020;
        5: p := $080;
        6: p := $200;
        else raise new InvalidMouseKeyCodeException(scr, NumToInt(nil, kk.res));
      end;
      
      mouse_event(
        (NumToInt(nil, dp.res) and $3) * p,
        0,0,0,0
      );
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1]);
      dp := new DInputNValue(par[2]);
    end;
    
    public constructor(kk, dp: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.dp := dp;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk, ndp: InputNValue; optf: StmBase->StmBase): StmBase;
    begin
      
      if ndp is SInputNValue then
      case NumToInt(nil, ndp.res) and $3 of
        0: Result := nil;
        1: Result := optf(new OperMouseDown(nkk, bl));
        2: Result := optf(new OperMouseUp(nkk, bl));
        3: Result := optf(new OperMousePress(nkk, bl));
      end else
      if (kk=nkk) and (dp=ndp) then
        Result := self else
        Result := new OperMouse(nkk, ndp, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn), dp.Optimize(nvn, svn), stm->stm.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn), dp.FinalOptimize(nvn, svn, ovn), stm->stm.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn), dp.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(2));
      bw.Write(byte(1));
      kk.Save(bw);
      dp.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperMouse;
      res.kk := InputNValue.Load(br);
      res.dp := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      dp.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'Mouse {kk} {dp}';
    
  end;
  
  {$endregion Key/Mouse}
  
  {$region Other simulators}
  
  OperConstMousePos = sealed class(OperStmBase)
    
    public x,y: integer;
    
    static procedure SetCursorPos(x, y: integer);
    external 'User32.dll' name 'SetCursorPos';
    
    private procedure Calc(ec: ExecutingContext) :=
    SetCursorPos(x,y);
    
    
    
    public constructor(x,y: integer; bl: StmBlock);
    begin
      self.x := x;
      self.y := y;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte($80 or 1));
      bw.Write(x);
      bw.Write(y);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstMousePos;
      res.x := br.ReadInt32;
      res.y := br.ReadInt32;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'MousePos {x} {y} //Const';
    
  end;
  OperConstGetKey = sealed class(OperStmBase)
    
    public kk: byte;
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, (GetKeyState(kk) and $80 <> 0)?1.0:0.0);
    
    
    
    public constructor(kk: byte; vname: string; bl: StmBlock);
    begin
      self.kk := kk;
      self.vname := vname;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte($80 or 2));
      bw.Write(kk);
      bw.Write(vname);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstGetKey;
      res.kk := br.ReadByte;
      res.vname := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'GetKey {kk} {vname} //Const';
    
  end;
  OperConstGetKeyTrigger = sealed class(OperStmBase)
    
    public kk: byte;
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, (GetKeyState(kk) and $01 <> 0)?1.0:0.0);
    
    
    
    public constructor(kk: byte; vname: string; bl: StmBlock);
    begin
      self.kk := kk;
      self.vname := vname;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte($80 or 3));
      bw.Write(kk);
      bw.Write(vname);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstGetKeyTrigger;
      res.kk := br.ReadByte;
      res.vname := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'GetKeyTrigger {kk} {vname} //Const';
    
  end;
  
  OperMousePos = sealed class(OperStmBase)
    
    public x,y: InputNValue;
    
    static procedure SetCursorPos(x, y: integer);
    external 'User32.dll' name 'SetCursorPos';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      SetCursorPos(
        NumToInt(nil, x.res),
        NumToInt(nil, y.res)
      );
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      x := new DInputNValue(par[1]);
      y := new DInputNValue(par[2]);
    end;
    
    public constructor(x,y: InputNValue; bl: StmBlock);
    begin
      self.x := x;
      self.y := y;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nx,ny: InputNValue): StmBase;
    begin
      if (nx is SInputNValue) and (ny is SInputNValue) then
        Result := new OperConstMousePos(NumToInt(nil, x.res), NumToInt(nil, y.res), bl) else
      if (x=nx) and (y=ny) then
        Result := self else
        Result := new OperMousePos(nx,ny, bl);
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(x.Optimize(nvn,svn), y.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(x.FinalOptimize(nvn, svn, ovn), y.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](x.FindVarUsages(vn), y.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte(1));
      x.Save(bw);
      y.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperMousePos;
      res.x := InputNValue.Load(br);
      res.y := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      x.GetCalc(),
      y.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'MousePos {x} {y}';
    
  end;
  OperGetKey = sealed class(OperStmBase)
    
    public kk: InputNValue
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var k := GetKeyState(n) and $80 = $80;
      ec.SetVar(vname, k?1.0:0.0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1]);
      vname := par[2];
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var n := NumToInt(nil, nkk.res);
        if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
        Result := new OperConstGetKey(n, vname, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperGetKey(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte(2));
      kk.Save(bw);
      bw.Write(vname);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperGetKey;
      res.kk := InputNValue.Load(br);
      res.vname := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'GetKey {kk} {vname}';
    
  end;
  OperGetKeyTrigger = sealed class(OperStmBase)
    
    public kk: InputNValue
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var k := GetKeyState(n) and $01 = $01;
      ec.SetVar(vname, k?1.0:0.0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1]);
      vname := par[2];
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nkk: InputNValue): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var n := NumToInt(nil, nkk.res);
        if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
        Result := new OperConstGetKeyTrigger(n, vname, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperGetKeyTrigger(nkk, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](kk.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte(3));
      kk.Save(bw);
      bw.Write(vname);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperGetKeyTrigger;
      res.kk := InputNValue.Load(br);
      res.vname := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      kk.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'GetKeyTrigger {kk} {vname}';
    
  end;
  OperGetMousePos = sealed class(OperStmBase)
    
    public x,y: string;
    
    static procedure GetCursorPos(p: ^Point);
    external 'User32.dll' name 'GetCursorPos';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var p: Point;
      GetCursorPos(@p);
      ec.SetVar(x, real(p.X));
      ec.SetVar(y, real(p.Y));
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      x := par[1];
      y := par[2];
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(3));
      bw.Write(byte(4));
      bw.Write(x);
      bw.Write(y);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperGetMousePos;
      res.x := br.ReadString;
      res.y := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'GetMousePos {x} {y} //Const';
    
  end;
  
  {$endregion Other simulators}
  
  {$region Jump/Call}
  comprT=(equ=byte(1), less=byte(2), more=byte(3));
  
  OperJump = sealed class(OperStmBase, IJumpCallOper, IFileRefStm)
    
    public CalledBlock: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.next := CalledBlock.GetBlock(ec.curr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock);
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(sb.scr, 2, par);
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1]));
    end;
    
    public constructor(CalledBlock: StmBlockRef; bl: StmBlock);
    begin
      self.CalledBlock := CalledBlock;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nCalledBlock: StmBlockRef): StmBase;
    begin
      
      if nCalledBlock is StaticStmBlockRef(var sbf) then
        bl.next := sbf.bl else
      if CalledBlock=nCalledBlock then
        Result := self else
        Result := new OperJump(nCalledBlock, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.Optimize(bl, nvn,svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.FinalOptimize(bl, nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](CalledBlock.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte(1));
      CalledBlock.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
    begin
      var res := new OperJump;
      res.CalledBlock := StmBlockRef.Load(br, sbs);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'Jump {CalledBlock.ToString}';
    
  end;
  OperJumpIf = sealed class(OperStmBase, IJumpCallOper, IFileRefStm)
    
    public e1,e2: OptExprWrapper;
    public compr: comprT;
    public CalledBlock1: StmBlockRef;
    public CalledBlock2: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var res1 := e1.Calc(ec.nvs, ec.svs);
      var res2 := e2.Calc(ec.nvs, ec.svs);
      ec.next :=
        comp_obj(res1,res2)?
        CalledBlock1.GetBlock(ec.curr):
        CalledBlock2.GetBlock(ec.curr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock1, CalledBlock2);
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientOperParamCount(sb.scr, 6, par);
      
      if par[2].Length <> 1 then raise new InvalidCompNameException(sb.scr, par[2]);
      case par[2][1] of
        '=': compr := equ;
        '<': compr := less;
        '>': compr := more;
        else raise new InvalidCompNameException(sb.scr, par[2]);
      end;
      
      e1 := OptExprWrapper.FromExpr(Expr.FromString(par[1]));
      e2 := OptExprWrapper.FromExpr(Expr.FromString(par[3]));
      
      CalledBlock1 := new DynamicStmBlockRef(new DInputSValue(par[4]));
      CalledBlock2 := new DynamicStmBlockRef(new DInputSValue(par[5]));
    end;
    
    private function comp_obj(o1,o2: object): boolean;
    begin
      if (o1 is real) and (o2 is real) then
        case compr of
          equ: Result := (real(o1) = real(o2)) or (real.IsNaN(real(o1)) and real.IsNaN(real(o2)));
          less: Result := real(o1) < real(o2);
          more: Result := real(o1) > real(o2);
        end else
        case compr of
          equ: Result := ObjToStr(o1) = ObjToStr(o2);
          less: Result := ObjToStr(o1) < ObjToStr(o2);
          more: Result := ObjToStr(o1) > ObjToStr(o2);
        end;
    end;
    
    public constructor(e1,e2: OptExprWrapper; compr: comprT; CalledBlock1: StmBlockRef; CalledBlock2: StmBlockRef; bl: StmBlock);
    begin
      self.e1 := e1;
      self.e2 := e2;
      self.compr := compr;
      self.CalledBlock1 := CalledBlock1;
      self.CalledBlock2 := CalledBlock2;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(ne1,ne2: OptExprWrapper; nCalledBlock1,nCalledBlock2: StmBlockRef; optf: StmBase->StmBase): StmBase;
    begin
      
      if
        (ne1.GetMain() is IOptLiteralExpr) and
        (ne2.GetMain() is IOptLiteralExpr)
      then
        Result := optf(new OperJump(
          comp_obj(ne1.GetMain.GetRes(), ne2.GetMain.GetRes())?
            nCalledBlock1:nCalledBlock2,
          bl
        )) else
      if
        (e1=ne1) and (e2=ne2) and
        (CalledBlock1=nCalledBlock1) and (CalledBlock2=nCalledBlock2)
      then
        Result := self else
        Result := new OperJumpIf(ne1,ne2, compr, nCalledBlock1,nCalledBlock2, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(
      e1.Optimize(nvn, svn),e2.Optimize(nvn, svn),
      CalledBlock1.Optimize(bl, nvn, svn),CalledBlock2.Optimize(bl, nvn, svn),
      stm->stm.Optimize(nvn, svn)
    );
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(
      e1.FinalOptimize(nvn, svn, ovn),e2.FinalOptimize(nvn, svn, ovn),
      CalledBlock1.FinalOptimize(bl, nvn, svn, ovn),CalledBlock2.FinalOptimize(bl, nvn, svn, ovn),
      stm->stm.FinalOptimize(nvn, svn, ovn)
    );
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](CalledBlock1.FindVarUsages(vn), CalledBlock2.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte(2));
      e1.Save(bw);
      bw.Write(byte(compr));
      e2.Save(bw);
      CalledBlock1.Save(bw);
      CalledBlock2.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
    begin
      var res := new OperJumpIf;
      
      res.e1 := OptExprWrapper.Load(br);
      
      var ct := br.ReadByte;
      case ct of
        
        1: res.compr := equ;
        2: res.compr := less;
        3: res.compr := more;
        
        else raise new InvalidComprTException(ct);
      end;
      
      res.e2 := OptExprWrapper.Load(br);
      
      res.CalledBlock1 := StmBlockRef.Load(br, sbs);
      res.CalledBlock2 := StmBlockRef.Load(br, sbs);
      
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock1.GetCalc(),
      CalledBlock2.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'JumpIf {e1} {System.Enum.GetName(compr.GetType, compr)} {e2} {CalledBlock1} {CalledBlock2}';
    
  end;
  
  OperConstCall = sealed class(OperStmBase, ICallOper, IFileRefStm)
    
    public CalledBlock: StmBlock;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(bl.next);
      ec.next := self.CalledBlock;
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](new StaticStmBlockRef(CalledBlock));
    
    public constructor(CalledBlock, bl: StmBlock);
    begin
      self.CalledBlock := CalledBlock;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte($80 or 3));
      CalledBlock.SaveId(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
    begin
      var res := new OperConstCall;
      var n := br.ReadInt32;
      if n <> -1 then
        if cardinal(n) < sbs.Length then
          res.bl := sbs[n] else
          raise new InvalidStmBlIdException(n, sbs.Length);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'Call {StaticStmBlockRef.Create(CalledBlock).ToString} //Const';
    
  end;
  
  OperCall = sealed class(OperStmBase, ICallOper, IFileRefStm)
    
    public CalledBlock: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(bl.next);
      ec.next := self.CalledBlock.GetBlock(ec.curr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock);
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(sb.scr, 2, par);
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1]));
    end;
    
    public constructor(CalledBlock: StmBlockRef; bl: StmBlock);
    begin
      self.CalledBlock := CalledBlock;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nCalledBlock: StmBlockRef): StmBase;
    begin
      
      if nCalledBlock is StaticStmBlockRef(var sbf) then
        Result := new OperConstCall(sbf.bl, bl) else
      if CalledBlock=nCalledBlock then
        Result := self else
        Result := new OperCall(nCalledBlock, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.Optimize(bl, nvn,svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.FinalOptimize(bl, nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](CalledBlock.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte(3));
      CalledBlock.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
    begin
      var res := new OperCall;
      res.CalledBlock := StmBlockRef.Load(br, sbs);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'Call {CalledBlock}';
    
  end;
  OperCallIf = sealed class(OperStmBase, ICallOper, IFileRefStm)
    
    public e1,e2: OptExprWrapper;
    public compr: comprT;
    public CalledBlock1: StmBlockRef;
    public CalledBlock2: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(bl.next);
      var res1 := e1.Calc(ec.nvs, ec.svs);
      var res2 := e2.Calc(ec.nvs, ec.svs);
      ec.next :=
        comp_obj(res1,res2)?
        CalledBlock1.GetBlock(ec.curr):
        CalledBlock2.GetBlock(ec.curr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock1, CalledBlock2);
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientOperParamCount(sb.scr, 6, par);
      
      if par[2].Length <> 1 then raise new InvalidCompNameException(sb.scr, par[2]);
      case par[2][1] of
        '=': compr := equ;
        '<': compr := less;
        '>': compr := more;
        else raise new InvalidCompNameException(sb.scr, par[2]);
      end;
      
      e1 := OptExprWrapper.FromExpr(Expr.FromString(par[1]));
      e2 := OptExprWrapper.FromExpr(Expr.FromString(par[3]));
      
      CalledBlock1 := new DynamicStmBlockRef(new DInputSValue(par[4]));
      CalledBlock2 := new DynamicStmBlockRef(new DInputSValue(par[5]));
    end;
    
    private function comp_obj(o1,o2: object): boolean;
    begin
      if (o1 is real) and (o2 is real) then
        case compr of
          equ: Result := real(o1) = real(o2);
          less: Result := real(o1) < real(o2);
          more: Result := real(o1) > real(o2);
        end else
        case compr of
          equ: Result := ObjToStr(o1) = ObjToStr(o2);
          less: Result := ObjToStr(o1) < ObjToStr(o2);
          more: Result := ObjToStr(o1) > ObjToStr(o2);
        end;
    end;
    
    public constructor(e1,e2: OptExprWrapper; compr: comprT; CalledBlock1: StmBlockRef; CalledBlock2: StmBlockRef; bl: StmBlock);
    begin
      self.e1 := e1;
      self.e2 := e2;
      self.compr := compr;
      self.CalledBlock1 := CalledBlock1;
      self.CalledBlock2 := CalledBlock2;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(ne1,ne2: OptExprWrapper; nCalledBlock1,nCalledBlock2: StmBlockRef; optf: StmBase->StmBase): StmBase;
    begin
      
      if
        (ne1.GetMain() is IOptLiteralExpr) and
        (ne2.GetMain() is IOptLiteralExpr)
      then
        Result := optf(new OperCall(
          comp_obj(ne1.GetMain.GetRes(), ne2.GetMain.GetRes())?
            nCalledBlock1:nCalledBlock2,
          bl
        )) else
      if
        (e1=ne1) and (e2=ne2) and
        (CalledBlock1=nCalledBlock1) and (CalledBlock2=nCalledBlock2)
      then
        Result := self else
        Result := new OperCallIf(ne1,ne2, compr, nCalledBlock1,nCalledBlock2, bl);
      
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(
      e1.Optimize(nvn, svn),e2.Optimize(nvn, svn),
      CalledBlock1.Optimize(bl, nvn, svn),CalledBlock2.Optimize(bl, nvn, svn),
      stm->stm.Optimize(nvn, svn)
    );
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(
      e1.FinalOptimize(nvn, svn, ovn),e2.FinalOptimize(nvn, svn, ovn),
      CalledBlock1.FinalOptimize(bl, nvn, svn, ovn),CalledBlock2.FinalOptimize(bl, nvn, svn, ovn),
      stm->stm.FinalOptimize(nvn, svn, ovn)
    );
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](CalledBlock1.FindVarUsages(vn), CalledBlock2.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte(4));
      e1.Save(bw);
      bw.Write(byte(compr));
      e2.Save(bw);
      CalledBlock1.Save(bw);
      CalledBlock2.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
    begin
      var res := new OperCallIf;
      
      res.e1 := OptExprWrapper.Load(br);
      
      var ct := br.ReadByte;
      case ct of
        
        1: res.compr := equ;
        2: res.compr := less;
        3: res.compr := more;
        
        else raise new InvalidComprTException(ct);
      end;
      
      res.e2 := OptExprWrapper.Load(br);
      
      res.CalledBlock1 := StmBlockRef.Load(br, sbs);
      res.CalledBlock2 := StmBlockRef.Load(br, sbs);
      
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock1.GetCalc(),
      CalledBlock2.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'CallIf {e1} {System.Enum.GetName(compr.GetType, compr)} {e2} {CalledBlock1} {CalledBlock2}';
    
  end;
  
  {$endregion Jump/Call}
  
  {$region ExecutingContext chandgers}
  
  OperSusp = sealed class(OperStmBase)
    
    private static procedure Calc(ec: ExecutingContext) :=
    if ec.scr.susp_called = nil then
      System.Threading.Thread.CurrentThread.Suspend else
      ec.scr.susp_called();
    
    
    
    public constructor := exit;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(1));
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    $'Susp //Const';
    
  end;
  OperReturn = sealed class(OperStmBase, IContextJumpOper)
    
    public constructor := exit;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(2));
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override;
    begin
      bl.next := nil;
      Result := nil;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[0];
    
    public function ToString: string; override :=
    $'Return //Const';
    
  end;
  OperHalt = sealed class(OperStmBase, IContextJumpOper)
    
    private static procedure Calc(ec: ExecutingContext) :=
    Halt;
    
    
    
    public constructor := exit;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(3));
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    $'Halt //Const';
    
  end;
  
  {$endregion ExecutingContext chandgers}
  
  {$region Misc}
  
  OperConstSleep = sealed class(OperStmBase)
    
    public l: integer;
    
    private procedure Calc(ec: ExecutingContext) :=
    Sleep(l);
    
    
    
    public constructor(l: integer; bl: StmBlock);
    begin
      self.l := l;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(6));
      bw.Write(byte($80 or 1));
      bw.Write(l);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstSleep;
      res.l := br.ReadInt32;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'Sleep {l} //Const';
    
  end;
  OperConstOutput = sealed class(OperStmBase)
    
    public otp: string;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var p := ec.scr.otp;
      if p <> nil then
        p(otp);
    end;
    
    
    
    public constructor(otp: string; bl: StmBlock);
    begin
      self.otp := otp;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(6));
      bw.Write(byte($80 or 3));
      bw.Write(otp);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperConstOutput;
      res.otp := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'Output "{otp}" //Const';
    
  end;
  
  OperSleep = sealed class(OperStmBase)
    
    public l: InputNValue;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var i := NumToInt(nil, l.res);
      if i < 0 then raise new InvalidSleepLengthException(ec.scr, i);
      Sleep(i);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(sb.scr, 2, par);
      
      l := new DInputNValue(par[1]);
    end;
    
    public constructor(l: InputNValue; bl: StmBlock);
    begin
      self.l := l;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(nl: InputNValue): StmBase;
    begin
      if nl is SInputNValue then
      begin
        var il := NumToInt(nil, nl.res);
        if il < 0 then raise new InvalidSleepLengthException(nil, il);
        Result := new OperConstSleep(il, bl);
      end else
      if nl=l then
        Result := self else
        Result := new OperSleep(nl, bl);
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(l.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(l.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](l.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(6));
      bw.Write(byte(1));
      l.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperSleep;
      res.l := InputNValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      l.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'Sleep {l}';
    
  end;
  OperRandom = sealed class(OperStmBase)
    
    public vname: string;
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, Random());
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(sb.scr, 2, par);
      
      vname := par[1];
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(6));
      bw.Write(byte(2));
      bw.Write(vname);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperRandom;
      res.vname := br.ReadString;
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'Random {vname} //Const';
    
  end;
  OperOutput = sealed class(OperStmBase)
    
    public otp: InputSValue;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var p := ec.scr.otp;
      if p <> nil then
        p(otp.res);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(sb.scr, 2, par);
      otp := new DInputSValue(par[1]);
    end;
    
    public constructor(otp: InputSValue; bl: StmBlock);
    begin
      self.otp := otp;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Simplify(notp: InputSValue): StmBase;
    begin
      if notp is SInputSValue then
        Result := new OperConstOutput(notp.res, bl) else
      if otp=notp then
        Result := self else
        Result := new OperOutput(notp, bl);
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override :=
    Simplify(otp.Optimize(nvn, svn));
    
    public function FinalOptimize(nvn, svn, ovn: HashSet<string>): StmBase; override :=
    Simplify(otp.FinalOptimize(nvn, svn, ovn));
    
    public function FindVarUsages(vn: string): array of OptExprWrapper; override :=
    new OptExprWrapper[](otp.FindVarUsages(vn));
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(6));
      bw.Write(byte(3));
      otp.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): OperStmBase;
    begin
      var res := new OperOutput;
      res.otp := InputSValue.Load(br);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      otp.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override :=
    $'Output {otp}';
    
  end;
  
  {$endregion Misc}
  
  {$endregion operator's}
  
  {$region directive's}
  
  DrctFRef = sealed class(DrctStmBase, IFileRefStm)
    
    public fns: array of string;
    
    private procedure Calc(ec: ExecutingContext := nil) :=
    foreach var fn in fns do
      scr.ReadFile(nil, fn);
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    fns.Select(fn->DynamicStmBlockRef.Create(new SInputSValue(fn)).Optimize(self.bl));
    
    public constructor(par: array of string);
    begin
      self.fns := par.ConvertAll(
        s->
        begin
          var res := OptExprWrapper.FromExpr(Expr.FromString(s)).GetMain;
          res := res.Optimize as OptExprBase;
          if not (res is IOptLiteralExpr) then raise new DrctFRefNotConstException(s, res);
          Result := ObjToStr(res.GetRes());
        end
      );
    end;
    
    public function Optimize(nvn, svn: HashSet<string>): StmBase; override;
    begin
      Calc;
      Result := nil;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte(1));
      bw.Write(fns.Length);
      foreach var fn in fns do
        bw.Write(fn);
    end;
    
    public static function Load(br: System.IO.BinaryReader): DrctStmBase;
    begin
      var res := new DrctFRef;
      res.fns := new string[br.ReadInt32];
      for var i := 0 to res.fns.Length-1 do
        res.fns[i] := br.ReadString;
      Result := res;
    end;
    
    public function ToString: string; override :=
    '!FRef'+fns.Select(s->' '+s).JoinIntoString;
    
  end;
  
  {$endregion directive's}
  
implementation

{$region Reading}

{$region Single stm}

constructor ExprStm.Create(sb: StmBlock; text: string);
begin
  var ss := text.SmartSplit('=', 2);
  self.vname := ss[0];
  self.e := ExprParser.OptExprWrapper.FromExpr(Expr.FromString(ss[1]));
end;

static function DrctStmBase.FromString(sb: StmBlock; text: string): DrctStmBase;
begin
  var p := text.Split(new char[]('='),2);
  case p[0].ToLower of
    
    '!fref': Result := new DrctFRef(p[1].Split(','));
    
    '!startpos':
    if (sb.stms.Count = 0) and (not sb.lbl.StartsWith('#%')) and not sb.StartPos then
    begin
      sb.scr.start_pos_def := true;
      sb.StartPos := true
    end else
      raise new InvalidUseStartPosException(sb.scr);
    
    else raise new UndefinedDirectiveNameException(sb, text);
  end;
end;

static function OperStmBase.FromString(sb: StmBlock; par: array of string): OperStmBase;
begin
  case par[0].ToLower of
    
    'key': Result := new OperKey(sb, par);
    'keyd': Result := new OperKeyDown(sb, par);
    'keyu': Result := new OperKeyUp(sb, par);
    'keyp': Result := new OperKeyPress(sb, par);
    'mouse': Result := new OperMouse(sb, par);
    'moused': Result := new OperMouseDown(sb, par);
    'mouseu': Result := new OperMouseUp(sb, par);
    'mousep': Result := new OperMousePress(sb, par);
    
    'mousepos': Result := new OperMousePos(sb, par);
    'getkey': Result := new OperGetKey(sb, par);
    'getkeytrigger': Result := new OperGetKeyTrigger(sb, par);
    'getmousepos': Result := new OperGetMousePos(sb, par);
    
    'call': Result := new OperCall(sb, par);
    'callif': Result := new OperCallIf(sb, par);
    'jump': Result := new OperJump(sb, par);
    'jumpif': Result := new OperJumpIf(sb, par);
    
    'susp': Result := new OperSusp;
    'return': Result := new OperReturn;
    'halt': Result := new OperHalt;
    
    'sleep': Result := new OperSleep(sb, par);
    'random': Result := new OperRandom(sb, par);
    'output': Result := new OperOutput(sb, par);
    
    else raise new UndefinedOperNameException(sb, par[0]);
  end;
end;

static function StmBase.FromString(sb: StmBlock; s: string; par: array of string): StmBase;
begin
  if s.StartsWith('!') then
    Result := DrctStmBase.FromString(sb, s) else
  if par[0].Contains('=') then
    Result := ExprStm.Create(sb, s) else
    Result := OperStmBase.FromString(sb, par);
  
  if Result=nil then exit;
  Result.bl := sb;
  Result.scr := sb.scr;
end;

{$endregion Single stm}

{$region Script}

function Script.ReadFile(context: object; lbl: string): boolean;
begin
  
  lbl := lbl.Split('#')[0];
  if not LoadedFiles.Add(lbl) then
    exit else
    Result := true;
  
  var fi := new System.IO.FileInfo(lbl);
  if not fi.Exists then raise new RefFileNotFound(context, fi.FullName);
  var ffname := fi.FullName;
  
  var lns: array of string;
  begin
    var str := fi.OpenRead;
    
    var sr := new System.IO.StreamReader(str);
    
    var pc_str := '!PreComp=';
    var buff := new char[pc_str.Length];
    sr.ReadBlock(buff,0,buff.Length);
    if new string(buff) = pc_str then
    begin
      str.Position := buff.Length;
      var br := new System.IO.BinaryReader(str);
      self.Load(ffname, br);
      exit;
    end;
    
    str.Position := 0;
    sr := new System.IO.StreamReader(str);
    lns := sr.ReadToEnd.Remove(#13).Split(#10);
    sr.Close;
    
  end;
  
  var last := new StmBlock(self);
  var lname := ffname+'#';
  
  var tmp_b_c := 0;
  var skp_ar := false;
  
  foreach var ss in lns do
    if ss <> '' then
    begin
      var s := ss.SmartSplit(' ',2)[0];
      
      if s.StartsWith('#') then
      begin
        
        if s.Contains('%') then raise new InvalidLabelCharactersException(last, s, '%');
        sbs.Add(lname, last);
        last.fname := ffname;
        last.lbl := lname.Remove(0,lname.IndexOf('#'));
        if skp_ar then
        begin
          last.Seal;
          last := new StmBlock(self);
          skp_ar := false;
        end else
        begin
          last.Seal;
          last.next := new StmBlock(self);
          last := last.next;
        end;
        lname := ffname+s;
        if sbs.ContainsKey(lname) then raise new DuplicateLabelNameException(context, s);
        
      end else
        if (s <> '') and not skp_ar then
        begin
          var stm := StmBase.FromString(last, s, ss.SmartSplit);
          if stm=nil then continue;
          last.stms.Add(stm);
          
          if stm is ICallOper then
          begin
            sbs.Add(lname, last);
            last.fname := ffname;
            last.lbl := lname.Remove(0,lname.IndexOf('#'));
            last.Seal;
            last.next := new StmBlock(self);
            last := last.next;
            lname := $'{ffname}#%{tmp_b_c}';
            tmp_b_c += 1;
          end else
          if stm is IContextJumpOper then
            skp_ar := true;
        end;
    end;
  
  last.fname := ffname;
  last.lbl := lname.Remove(0,lname.IndexOf('#'));
  last.Seal;
  sbs.Add(lname, last);
end;

constructor Script.Create(fname: string);
begin
  
  read_start_lbl_name := System.IO.Path.GetFullPath(fname);
  ReadFile(nil, read_start_lbl_name);
  
  self.Optimize;
end;

{$endregion Script}

{$endregion Reading}

{$region Misc Impl}

procedure StmBlock.SaveId(bw: System.IO.BinaryWriter) :=
bw.Write(scr.sbs.Values.Numerate(0).First(t->t[1]=self)[0]);

function StmBlock.GetAllFRefs: sequence of StmBlockRef;
begin
  foreach var op in stms do
    if op is IFileRefStm(var frs) then
      yield sequence frs.GetRefs;
end;

function StmBlock.EnumrNextStms: sequence of StmBase;
begin
  yield sequence stms;
  if stms[stms.Count-1] is IJumpCallOper then
    yield nil else
  if next <> nil then
    yield sequence next.EnumrNextStms;
end;

function ExecutingContext.ExecuteNext: boolean;
begin
  if curr = nil then
    Result := Pop(curr) else
  begin
    next := curr.next;
    curr.Execute(self);
    curr := next;
    Result := true;
  end;
end;

{$endregion Misc Impl}

{$region Script optimization}

function GetBlockChain(bl: StmBlock; bl_lst: List<StmBlock>; stm_lst: List<StmBase>; ind_lst: List<integer>; allow_final_opt: boolean): boolean;
begin
  Result := true;
  
  var curr := bl;
  
  var nvn := new HashSet<string>;
  var svn := new HashSet<string>;
  var ovn := new HashSet<string>;
  
  while curr <> nil do
  begin
    
    var pi := bl_lst.IndexOf(curr);
    if pi <> -1 then
    begin
      
      if pi <> 0 then
      begin
        bl.next := bl_lst[pi];
        var stm_ind := ind_lst[pi-1];
        stm_lst.RemoveRange(stm_ind, stm_lst.Count-stm_ind);
        bl_lst.RemoveRange(pi, bl_lst.Count-pi);
        //ind_lst.RemoveRange//нигде дальше всё равно не используется
      end;
      
      Result := false;
      break;
    end;
    
    
    
    bl_lst.Add(curr);
    
    foreach var stm in curr.stms do
    begin
      var opt := allow_final_opt?stm.FinalOptimize(nvn, svn, ovn):stm.Optimize(nvn, svn);
      if opt <> nil then
        stm_lst.Add(opt) else
        if stm is IContextJumpOper then
        begin
          bl.next := stm.bl.next;
          //Result := true;
          break;
        end;
    end;
    
    
    
    if stm_lst.Count <> 0 then
    begin
      
      if stm_lst[stm_lst.Count-1] is OperConstCall(var occ) then
      begin
        stm_lst.RemoveLast;
        ind_lst.Add(stm_lst.Count);
        
        if not GetBlockChain(occ.CalledBlock, bl_lst, stm_lst, ind_lst, allow_final_opt) then
        begin
          Result := false;//bl.next уже изменило в рекурсивном вызове GetBlockChain
          break;
        end;
        
      end else
        ind_lst.Add(stm_lst.Count);
      
      if stm_lst[stm_lst.Count-1] is IJumpCallOper then
      begin
        bl.next := nil;
        Result := false;
        break;
      end;
      
    end;
    
    curr := curr.next;
  end;
  
end;

procedure Script.Optimize;
begin
  
  var try_final_opt := true;
  var dyn_refs := new List<StmBlockRef>;
  while try_final_opt do
  begin
    
    {$region Init}
    
    var done := new HashSet<StmBlock>;
    var waiting := new HashSet<StmBlock>(start_pos_def?sbs.Values.Where(bl->bl.StartPos):sbs.Values);
    var add_to_waiting := start_pos_def;
    
    var new_dyn_refs := waiting.SelectMany(bl->bl.GetAllFRefs).Where(ref->ref is DynamicStmBlockRef).ToList;
    try_final_opt := (new_dyn_refs.Count <> 0) and not dyn_refs.SequenceEqual(new_dyn_refs);
    dyn_refs := new_dyn_refs;
    
    var allow_final_opt := new List<StmBlock>;
    if dyn_refs.Count=0 then
    begin
      allow_final_opt.AddRange(waiting);
      
      foreach var bl in waiting do
      begin
        foreach var ref in bl.GetAllFRefs do
          allow_final_opt.Remove(StaticStmBlockRef(ref).bl);
        allow_final_opt.Remove(bl.next);
      end;
      
    end;
    
    {$endregion Init}
    
    {$region Block chaining}
    
    while waiting.Count <> 0 do
    begin
      var curr := waiting.Last;
      waiting.Remove(curr);
      if curr=nil then continue;
      if not done.Add(curr) then continue;
      
      var stms := new List<StmBase>;
      
      GetBlockChain(curr, new List<StmBlock>, stms, new List<integer>, allow_final_opt.Contains(curr));
      
      curr.stms := stms;
      
      if add_to_waiting then
      begin
        var refs := curr.GetAllFRefs.ToArray;
        add_to_waiting := refs.All(ref->ref is StaticStmBlockRef);
        if not add_to_waiting then continue;
        waiting += curr;
        foreach var ref in refs.Select(ref->(ref as StaticStmBlockRef).bl) do
          waiting += ref;
        waiting += curr.next;
      end;
    end;
    
    foreach var kvp in sbs.ToList do
      if not done.Contains(kvp.Value) then
        sbs.Remove(kvp.Key);
    
    {$endregion Block chaining}
    
    {$region Variable optimizations}
    
    foreach var bl: StmBlock in sbs.Values do
    begin//ToDo #1488
      foreach var e: ExprStm in bl.stms.Select(stm->stm as ExprStm).Where(stm-> stm<>nil).ToList do
      begin
        
        var usages := new List<(StmBase, OptExprWrapper)>;
        var auf := true;
        
        foreach var stm in
          bl.stms
          .SkipWhile(stm-> stm<>e).Skip(1)
        do
        begin
          
          usages.AddRange(
            stm
            .FindVarUsages(e.vname)
            .Where(e-> e<>nil )
            .Select(e->(stm, e))
          );
          
          if (stm is ExprStm(var e2)) and (e2.vname=e.vname) then break;
        end;
        
        var nue := false;
        if bl.next <> nil then
        begin
          var prev := new HashSet<StmBase>;
          
          foreach var stm in
            bl.next
            .EnumrNextStms
          do
          begin
            
            if (stm=nil) or stm.FindVarUsages(e.vname).Where(e-> e<>nil ).Any then
            begin
              nue := true;
              break;
            end;
            
            if not prev.Add(stm) then break;
            if (stm is ExprStm(var e2)) and (e2.vname=e.vname) then break;
          end;
          
        end;
        
        var main := e.e.GetMain;
        if (main is IOptSimpleExpr) or (usages.Count < 2) then
        begin
          
          foreach var use in usages do
            use[1].ReplaceVar(e.vname, main);
          
          if auf and not nue then bl.stms.Remove(e);
          
          if (usages.Count<>0) or not nue then try_final_opt := true;
        end else
        begin
          var use := usages[0];
          var stms := use[0].bl.stms;
          
          var ind := stms.IndexOf(use[0]);
          if stms.IndexOf(e)+1 <> ind then
          begin
            
            stms.Remove(e);
            stms.Insert(ind-1,e);
            
            try_final_opt := true;
          end;
          
        end;
        
        
      end;
    end;
    
    {$endregion Variable optimizations}
    
  end;
  
  if sbs.Values.SelectMany(bl->bl.GetAllFRefs).All(ref->ref is StaticStmBlockRef) then
    LoadedFiles := nil;
  
  foreach var bl: StmBlock in sbs.Values do
    bl.Seal;
  
end;

{$endregion Script optimizing}

{$region Save/Load}

static function InputSValue.Load(br: System.IO.BinaryReader): InputSValue;
begin
  var t := br.ReadByte;
  case t of
    
    1: Result := new SInputSValue(br.ReadString);
    2: Result := new DInputSValue(OptExprWrapper.Load(br) as OptSExprWrapper);
    
    else raise new InvalidInpTException(t);
  end;
end;

static function InputNValue.Load(br: System.IO.BinaryReader): InputNValue;
begin
  var t := br.ReadByte;
  case t of
    
    1: Result := new SInputNValue(br.ReadDouble);
    2: Result := new DInputNValue(OptExprWrapper.Load(br) as OptNExprWrapper);
    
    else raise new InvalidInpTException(t);
  end;
end;

static function StmBlockRef.Load(br: System.IO.BinaryReader; sbs: array of StmBlock): StmBlockRef;
begin
  var t := br.ReadByte;
  case t of
    
    1:
    begin
      var res := new StaticStmBlockRef;
      
      var n := br.ReadInt32;
      if n <> -1 then
        if cardinal(n) < sbs.Length then
          res.bl := sbs[n] else
          raise new InvalidStmBlIdException(n, sbs.Length);
      
      Result := res;
    end;
    
    2: Result := new DynamicStmBlockRef(InputSValue.Load(br));
    
    else raise new InvalidBlRefTException(t);
  end;
end;

static function OperStmBase.Load(br: System.IO.BinaryReader; sbs: array of StmBlock): OperStmBase;
begin
  var t1 := br.ReadByte;
  var t2 := br.ReadByte;
  
  case t1 of
    
    1:
    case t2 of
      
      1: Result := OperKey.Load(br);
      2: Result := OperKeyDown.Load(br);
      3: Result := OperKeyUp.Load(br);
      4: Result := OperKeyPress.Load(br);
      
      $80 or 2: Result := OperConstKeyDown.Load(br);
      $80 or 3: Result := OperConstKeyUp.Load(br);
      $80 or 4: Result := OperConstKeyPress.Load(br);
      
      else raise new InvalidOperTException(t1,t2);
    end;
    
    2:
    case t2 of
      
      1: Result := OperMouse.Load(br);
      2: Result := OperMouseDown.Load(br);
      3: Result := OperMouseUp.Load(br);
      4: Result := OperMousePress.Load(br);
      
      $80 or 2: Result := OperConstMouseDown.Load(br);
      $80 or 3: Result := OperConstMouseUp.Load(br);
      $80 or 4: Result := OperConstMousePress.Load(br);
      
      else raise new InvalidOperTException(t1,t2);
    end;
    
    3:
    case t2 of
      
      1: Result := OperMousePos.Load(br);
      2: Result := OperGetKey.Load(br);
      3: Result := OperGetKeyTrigger.Load(br);
      4: Result := OperGetMousePos.Load(br);
      
      $80 or 1: Result := OperConstMousePos.Load(br);
      $80 or 2: Result := OperConstGetKey.Load(br);
      $80 or 3: Result := OperConstGetKeyTrigger.Load(br);
      
      else raise new InvalidOperTException(t1,t2);
    end;
    
    4:
    case t2 of
      
      1: Result := OperJump.Load(br, sbs);
      2: Result := OperJumpIf.Load(br, sbs);
      3: Result := OperCall.Load(br, sbs);
      4: Result := OperCallIf.Load(br, sbs);
      
      $80 or 3: Result := OperConstCall.Load(br, sbs);
      
      else raise new InvalidOperTException(t1,t2);
    end;
    
    5:
    case t2 of
      
      1: Result := OperSusp.Create;
      2: Result := OperReturn.Create;
      3: Result := OperHalt.Create;
      
      else raise new InvalidOperTException(t1,t2);
    end;
    
    6:
    case t2 of
      
      1: Result := OperSleep.Load(br);
      2: Result := OperRandom.Load(br);
      3: Result := OperOutput.Load(br);
      
      $80 or 1: Result := OperConstSleep.Load(br);
      $80 or 3: Result := OperConstOutput.Load(br);
      
      else raise new InvalidOperTException(t1,t2);
    end;
    
    else raise new InvalidOperTException(t1,t2);
  end;
  
end;

static function DrctStmBase.Load(br: System.IO.BinaryReader; sbs: array of StmBlock): DrctStmBase;
begin
  var t1 := br.ReadByte;
  var t2 := br.ReadByte;
  
  case t1 of
    
    1:
    case t2 of
      
      1: Result := DrctFRef.Load(br);
      
      else raise new InvalidDrctTException(t1,t2);
    end;
    
    else raise new InvalidDrctTException(t1,t2);
  end;
  
end;

static function StmBase.Load(br: System.IO.BinaryReader; sbs: array of StmBlock): StmBase;
begin
  
  var t := br.ReadByte;
  case t of
    0: Result := ExprStm.Load(br, sbs);
    1: Result := OperStmBase.Load(br, sbs);
    2: Result := DrctStmBase.Load(br, sbs);
    else raise new InvalidStmTException(t);
  end;
  
end;

procedure Script.Save(str: System.IO.Stream);
begin
  
  if LoadedFiles <> nil then
  begin
    
    var nopt: boolean;
    repeat
      nopt := true;
      
      var refs := sbs.Values.SelectMany(bl->bl.GetAllFRefs).Cast&<DynamicStmBlockRef>.Where(ref->ref <> nil).Select(ref->ref.s).ToList;
      foreach var ref: InputSValue in refs do
      begin
        var inp := ref.Optimize(new HashSet<string>,new HashSet<string>);
        if inp is SInputSValue then
          if ReadFile(nil, inp.res) then
            nopt := false;
      end;
      
    until nopt;
    
  end;
  
  var sw := new System.IO.StreamWriter(str);
  sw.Write('!PreComp=');
  sw.Flush;
  
  var bw := new System.IO.BinaryWriter(str);
  
  var main_fname := read_start_lbl_name.Split('#')[0];
  var main_path := main_fname.Split('\').SkipLast.JoinIntoString('\');
  bw.Write(main_fname.Split('\').Last);
  
  var sbbs :=
  sbs
  .Select(kvp->(kvp.Key.Split(new char[]('#'),2),kvp.Value))
  .GroupBy(
    t->t[0][0],
    t->(t[0][1],t[1])
  ).ToList;
  bw.Write(sbbs.Count);
  foreach var kvp: System.Linq.IGrouping<string, (string, StmBlock)> in sbbs do
  begin
    bw.Write(GetRelativePath(main_path, kvp.Key));
    var l := kvp.ToList;
    bw.Write(l.Count);
    foreach var t in l do
    begin
      bw.Write(t[0]);
      t[1].Save(bw);
    end;
  end;
  
  //str.Flush;
  str.Close;
end;

{$endregion Save/Load}

begin
  try
    
    {$resource Lang\#Parsing}
    LoadLocale('#Parsing');
    
  except
    on e: Exception do
    begin
      writeln(e);
      readln;
    end;
  end;
end.