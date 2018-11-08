unit StmParser;
//ToDo Добавить DeduseVarsTypes в ExprParser
//ToDo Контекст ошибок
//ToDo использовать FinalFixVarExprs (превращает все не найденные переменные в null)

//ToDo подставлять значения переменных в выражения если (переменной присваивается литерал ИЛИ (переменная используется 1 раз И bl.next=nil))
// - так же если следующий блок не может быть стартовой пизицией - можно перенести переменную-литерал в него

//ToDo Directives:  !NoOpt/!Opt
//ToDo Directives:  !SngDef:i1=num:readonly/const

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
  SimpleFileContextArea = class(FileContextArea)
    
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
  ComplexFileContextArea = class(FileContextArea)
    
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
  
  ContextedExpr = class
    
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
  LabelNotFoundException = class(FileCompilingException)
    
    public constructor(source: Script; lbl_name: string) :=
    inherited Create(source, $'Label "{lbl_name}" not found');
    
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
  
  ExecutingContext = class
    
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
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; virtual := self;
    
    public static function FromString(sb: StmBlock; s: string; par: array of string): StmBase;
    
    public static function ObjToStr(o: object) :=
    OptExprBase.ObjToStr(o);
    
    public static function ObjToNum(o: object) :=
    OptExprBase.ObjToNum(o);
    
    public function NumToInt(n: real): integer;
    begin
      if real.IsNaN(n) or real.IsInfinity(n) then raise new CannotConvertToIntException(scr, n);
      var i := BigInteger.Create(n);
      if (i < integer.MinValue) or (i > integer.MaxValue) then raise new CannotConvertToIntException(scr, i);
      Result := integer(i);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): StmBase;
    
  end;
  ExprStm = sealed class(StmBase)
    
    public v_name: string;
    public e: OptExprWrapper;
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(v_name, e.Calc(
      ec.nvs,
      ec.svs
    ));
    
    
    
    public constructor(sb: StmBlock; text: string);
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(0));
      bw.Write(v_name);
      e.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): ExprStm;
    begin
      Result := new ExprStm;
      Result.v_name := br.ReadString;
      Result.e := OptExprWrapper.Load(br);
    end;
    
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
  
  StmBlock = class
    
    public StartPos := false;
    public stms := new List<StmBase>;
    public next: StmBlock := nil;
    public Execute: Action<ExecutingContext>;
    
    public fname: string;
    public lbl: string;
    public scr: Script;
    
    public function GetAllFRefs: sequence of StmBlockRef;
    
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
    
  end;
  
  Script = class
    
    private static nfi := new System.Globalization.NumberFormatInfo;
    
    public read_start_lbl_name: string;
    public start_pos_def := false;
    
    public otp: procedure(s: string);
    public susp_called: procedure;
    public stoped: procedure;
    
    public LoadedFiles := new HashSet<string>;
    public sbs := new Dictionary<string, StmBlock>;
    
    private procedure ReadFile(context: object; lbl: string; fQu: List<StmBlock>);
    private procedure ReadFileBatch(context: object; lbl: string);
    
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
    begin
      
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
      
    end;
    
  end;

  {$endregion Stm containers}
  
  {$region InputValue}
  
  InputValue = abstract class
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    
    public function GetRes: object; abstract;
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
  end;
  
  InputSValue = abstract class(InputValue)
    
    public res: string;
    
    public function GetRes: object; override := res;
    
    public function Optimize(nvn, svn: List<string>): InputSValue; virtual := self;
    
    public static function Load(br: System.IO.BinaryReader): InputSValue;
    
  end;
  SInputSValue = class(InputSValue)
    
    public constructor(res: string) :=
    self.res := res;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
  end;
  DInputSValue = class(InputSValue)
    
    public oe: OptSExprWrapper;
    
    public procedure Calc(ec: ExecutingContext) :=
    self.res := oe.CalcS(ec.nvs, ec.svs);
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function Optimize(nvn, svn: List<string>): InputSValue; override;
    begin
      oe.Optimize(nvn, svn);
      if oe.Main is IOptLiteralExpr(var me) then
        Result := new SInputSValue(StmBase.ObjToStr(me.GetRes)) else
        Result := self;
    end;
    
    public constructor(oe: OptSExprWrapper);
    begin
      self.oe := oe;
    end;
    
    public constructor(s: string; bl: StmBlock) :=
    oe := OptExprWrapper.FromExpr(Expr.FromString(s), OptExprBase.AsStrExpr) as OptSExprWrapper;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      oe.Save(bw);
    end;
    
  end;
  
  InputNValue = abstract class(InputValue)
    
    public res: real;
    
    public function GetRes: object; override := res;
    
    public function Optimize(nvn, svn: List<string>): InputNValue; virtual := self;
    
    public static function Load(br: System.IO.BinaryReader): InputNValue;
    
  end;
  SInputNValue = class(InputNValue)
    
    public constructor(res: real) :=
    self.res := res;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
  end;
  DInputNValue = class(InputNValue)
    
    public oe: OptNExprWrapper;
    
    public procedure Calc(ec: ExecutingContext) :=
    res := oe.CalcN(ec.nvs, ec.svs);
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function Optimize(nvn, svn: List<string>): InputNValue; override;
    begin
      oe.Optimize(nvn, svn);
      if oe.Main is IOptLiteralExpr(var me) then
        Result := new SInputNValue(StmBase.ObjToNum(me.GetRes)) else
        Result := self;
    end;
    
    public constructor(oe: OptNExprWrapper);
    begin
      self.oe := oe;
    end;
    
    public constructor(s: string; bl: StmBlock) :=
    oe := OptExprWrapper.FromExpr(Expr.FromString(s), oe->OptExprBase.AsDefinitelyNumExpr(oe)) as OptNExprWrapper;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      oe.Save(bw);
    end;
    
  end;
  
  {$endregion InputValue}
  
  {$region StmBlockRef}
  
  StmBlockRef = abstract class
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    
    public function GetBlock(curr: StmBlock): StmBlock; abstract;
    
    public function Optimize(bl: StmBlock; nvn: List<string>; svn: List<string>): StmBlockRef; virtual := self;
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public static function Load(br: System.IO.BinaryReader; sbs: array of StmBlock): StmBlockRef;
    
  end;
  StaticStmBlockRef = class(StmBlockRef)
    
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
    
  end;
  DynamicStmBlockRef = class(StmBlockRef)
    
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
        
        if not curr.scr.sbs.TryGetValue(res, Result) then
        begin
          curr.scr.ReadFileBatch(nil, res);
          if not curr.scr.sbs.TryGetValue(res, Result) then
            raise new LabelNotFoundException(curr.scr, res);
        end;
      end;
    end;
    
    public constructor(s: InputSValue) :=
    self.s := s;
    
    public function Optimize(bl: StmBlock; nvn: List<string>; svn: List<string>): StmBlockRef; override;
    begin
      s := s.Optimize(nvn, svn);
      if s is SInputSValue then
        Result := new StaticStmBlockRef(self.GetBlock(bl)) else
        Result := self;
    end;
    
    public function Optimize(bl: StmBlock) :=
    Optimize(bl, new List<string>, new List<string>);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      s.Save(bw);
    end;
    
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
  
  OperConstKeyDown = class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext) :=
    keybd_event(kk, 0, 0, 0);
    
    
    
    public constructor(kk: byte) :=
    self.kk := kk;
    
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
    
  end;
  OperConstKeyUp = class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext) :=
    keybd_event(kk, 0, 2, 0);
    
    
    
    public constructor(kk: byte) :=
    self.kk := kk;
    
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
    
  end;
  OperConstKeyPress = class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      keybd_event(kk, 0, 0, 0);
      keybd_event(kk, 0, 2, 0);
    end;
    
    
    
    public constructor(kk: byte) :=
    self.kk := kk;
    
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
    
  end;
  
  OperKeyDown = class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 0, 0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1], sb);
    end;
    
    public constructor(kk: InputNValue) :=
    self.kk := kk;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var ikk := NumToInt(kk.res);
        if (ikk < 1) or (ikk > 254) then raise new InvalidKeyCodeException(scr, ikk);
        Result := new OperConstKeyDown(ikk);
      end else
        Result := self;
    end;
    
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
    
  end;
  OperKeyUp = class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 2, 0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1], sb);
    end;
    
    public constructor(kk: InputNValue) :=
    self.kk := kk;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var ikk := NumToInt(kk.res);
        if (ikk < 1) or (ikk > 254) then raise new InvalidKeyCodeException(scr, ikk);
        Result := new OperConstKeyUp(ikk);
      end else
        Result := self;
    end;
    
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
    
  end;
  OperKeyPress = class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 0, 0);
      keybd_event(n, 0, 2, 0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1], sb);
    end;
    
    public constructor(kk: InputNValue) :=
    self.kk := kk;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var ikk := NumToInt(kk.res);
        if (ikk < 1) or (ikk > 254) then raise new InvalidKeyCodeException(scr, ikk);
        Result := new OperConstKeyPress(ikk);
      end else
        Result := self;
    end;
    
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
    
  end;
  OperKey = class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var p := NumToInt(dp.res);
      if p and $1 = $1 then keybd_event(n,0,0,0);
      if p and $2 = $2 then keybd_event(n,0,2,0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1], sb);
      dp := new DInputNValue(par[2], sb);
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      dp := dp.Optimize(nvn, svn);
      if dp is SInputNValue then
      case NumToInt(dp.res) and $3 of
        0: Result := nil;
        1: Result := OperKeyDown.Create(kk).Optimize(nvn, svn);
        2: Result := OperKeyUp.Create(kk).Optimize(nvn, svn);
        3: Result := OperKeyPress.Create(kk).Optimize(nvn, svn);
      end else
      begin
        kk := kk.Optimize(nvn, svn);
        Result := self;
      end;
    end;
    
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
    
  end;
  
  {$endregion Key}
  
  {$region Mouse}
  
  OperConstMouseDown = class(OperStmBase)
    
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
    
    
    
    public constructor(kk: byte) :=
    self.kk := kk;
    
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
    
  end;
  OperConstMouseUp = class(OperStmBase)
    
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
    
    
    
    public constructor(kk: byte) :=
    self.kk := kk;
    
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
    
  end;
  OperConstMousePress = class(OperStmBase)
    
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
    
    
    
    public constructor(kk: byte) :=
    self.kk := kk;
    
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
    
  end;
  
  OperMouseDown = class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      case NumToInt(kk.res) of
        1: mouse_event($002, 0,0,0,0);
        2: mouse_event($008, 0,0,0,0);
        4: mouse_event($020, 0,0,0,0);
        5: mouse_event($080, 0,0,0,0);
        6: mouse_event($200, 0,0,0,0);
        else raise new InvalidMouseKeyCodeException(scr, NumToInt(kk.res));
      end;
      
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1], sb);
    end;
    
    public constructor(kk: InputNValue) :=
    self.kk := kk;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var ikk := NumToInt(kk.res);
        
        case ikk of
          1,2,4..6: Result := new OperConstMouseDown(ikk);
          else raise new InvalidMouseKeyCodeException(scr, ikk);
        end;
        
      end else
        Result := self;
    end;
    
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
    
  end;
  OperMouseUp = class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      case NumToInt(kk.res) of
        1: mouse_event($004, 0,0,0,0);
        2: mouse_event($010, 0,0,0,0);
        4: mouse_event($040, 0,0,0,0);
        5: mouse_event($100, 0,0,0,0);
        6: mouse_event($400, 0,0,0,0);
        else raise new InvalidMouseKeyCodeException(scr, NumToInt(kk.res));
      end;
      
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1], sb);
    end;
    
    public constructor(kk: InputNValue) :=
    self.kk := kk;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var ikk := NumToInt(kk.res);
        
        case ikk of
          1,2,4..6: Result := new OperConstMouseUp(ikk);
          else raise new InvalidMouseKeyCodeException(scr, ikk);
        end;
        
      end else
        Result := self;
    end;
    
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
    
  end;
  OperMousePress = class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      case NumToInt(kk.res) of
        1: mouse_event($006, 0,0,0,0);
        2: mouse_event($018, 0,0,0,0);
        4: mouse_event($060, 0,0,0,0);
        5: mouse_event($180, 0,0,0,0);
        6: mouse_event($600, 0,0,0,0);
        else raise new InvalidMouseKeyCodeException(ec.scr, NumToInt(kk.res));
      end;
      
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1], sb);
    end;
    
    public constructor(kk: InputNValue) :=
    self.kk := kk;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var ikk := NumToInt(kk.res);
        
        case ikk of
          1,2,4..6: Result := new OperConstMousePress(ikk);
          else raise new InvalidMouseKeyCodeException(scr, ikk);
        end;
        
      end else
        Result := self;
    end;
    
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
    
  end;
  OperMouse = class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    static procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: cardinal);
    external 'User32.dll' name 'mouse_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      
      var p: cardinal;
      case NumToInt(kk.res) of
        1: p := $002;
        2: p := $008;
        4: p := $020;
        5: p := $080;
        6: p := $200;
        else raise new InvalidMouseKeyCodeException(scr, NumToInt(kk.res));
      end;
      
      mouse_event(
        (NumToInt(dp.res) and $3) * p,
        0,0,0,0
      );
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1], sb);
      dp := new DInputNValue(par[2], sb);
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      dp := dp.Optimize(nvn, svn);
      if dp is SInputNValue then
      case NumToInt(dp.res) and $3 of
        0: Result := nil;
        1: Result := OperMouseDown.Create(kk).Optimize(nvn, svn);
        2: Result := OperMouseUp.Create(kk).Optimize(nvn, svn);
        3: Result := OperMousePress.Create(kk).Optimize(nvn, svn);
      end else
      begin
        kk := kk.Optimize(nvn, svn);
        Result := self;
      end;
    end;
    
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
    
  end;
  
  {$endregion Key/Mouse}
  
  {$region Other simulators}
  
  OperConstMousePos = class(OperStmBase)
    
    public x,y: integer;
    
    static procedure SetCursorPos(x, y: integer);
    external 'User32.dll' name 'SetCursorPos';
    
    private procedure Calc(ec: ExecutingContext) :=
    SetCursorPos(x,y);
    
    
    
    public constructor(x,y: integer);
    begin
      self.x := x;
      self.y := y;
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
    
  end;
  OperConstGetKey = class(OperStmBase)
    
    public kk: byte;
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, (GetKeyState(kk) and $80 <> 0)?1.0:0.0);
    
    
    
    public constructor(kk: byte; vname: string);
    begin
      self.kk := kk;
      self.vname := vname;
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
    
  end;
  OperConstGetKeyTrigger = class(OperStmBase)
    
    public kk: byte;
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, (GetKeyState(kk) and $01 <> 0)?1.0:0.0);
    
    
    
    public constructor(kk: byte; vname: string);
    begin
      self.kk := kk;
      self.vname := vname;
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
    
  end;
  
  OperMousePos = class(OperStmBase)
    
    public x,y: InputNValue;
    
    static procedure SetCursorPos(x, y: integer);
    external 'User32.dll' name 'SetCursorPos';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      SetCursorPos(
        NumToInt(x.res),
        NumToInt(y.res)
      );
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      x := new DInputNValue(par[1], sb);
      y := new DInputNValue(par[2], sb);
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      x := x.Optimize(nvn, svn);
      y := y.Optimize(nvn, svn);
      if (x is SInputNValue) and (y is SInputNValue) then
        Result := new OperConstMousePos(NumToInt(x.res), NumToInt(y.res)) else
        Result := self;
    end;
    
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
    
  end;
  OperGetKey = class(OperStmBase)
    
    public kk: InputNValue
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var k := GetKeyState(n) and $80 = $80;
      ec.SetVar(vname, k?1.0:0.0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1], sb);
      vname := par[2];
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var n := NumToInt(kk.res);
        if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
        Result := new OperConstGetKey(n, vname);
      end else
        Result := self;
    end;
    
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
    
  end;
  OperGetKeyTrigger = class(OperStmBase)
    
    public kk: InputNValue
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var k := GetKeyState(n) and $01 = $01;
      ec.SetVar(vname, k?1.0:0.0);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientOperParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1], sb);
      vname := par[2];
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      kk := kk.Optimize(nvn, svn);
      if kk is SInputNValue then
      begin
        var n := NumToInt(kk.res);
        if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
        Result := new OperConstGetKeyTrigger(n, vname);
      end else
        Result := self;
    end;
    
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
    
  end;
  OperGetMousePos = class(OperStmBase)
    
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
    
  end;
  
  {$endregion Other simulators}
  
  {$region Jump/Call}
  
  OperJump = class(OperStmBase, IJumpCallOper, IFileRefStm)
    
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
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1], sb));
    end;
    
    public constructor(CalledBlock: StmBlockRef) :=
    self.CalledBlock := CalledBlock;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      CalledBlock := CalledBlock.Optimize(self.bl, nvn, svn);
      if CalledBlock is StaticStmBlockRef(var sbf) then
        bl.next := sbf.bl else
        Result := self;
    end;
    
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
    
  end;
  OperJumpIf = class(OperStmBase, IJumpCallOper, IFileRefStm)
    
    public e1,e2: OptExprWrapper;
    public compr: (equ=byte(1), less=byte(2), more=byte(3));
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
      
      CalledBlock1 := new DynamicStmBlockRef(new DInputSValue(par[4], sb));
      CalledBlock2 := new DynamicStmBlockRef(new DInputSValue(par[5], sb));
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
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      e1.Optimize(nvn, svn);
      e2.Optimize(nvn, svn);
      if
        (e1.GetMain() is IOptLiteralExpr) and
        (e2.GetMain() is IOptLiteralExpr)
      then
        Result := OperJump.Create(comp_obj(e1.GetMain.GetRes(), e2.GetMain.GetRes())?CalledBlock1:CalledBlock2).Optimize(nvn, svn) else
      begin
        CalledBlock1 := CalledBlock1.Optimize(bl, nvn, svn);
        CalledBlock2 := CalledBlock2.Optimize(bl, nvn, svn);
        Result := self;
      end;
    end;
    
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
    
  end;
  
  OperConstCall = class(OperStmBase, ICallOper, IFileRefStm)
    
    public CalledBlock: StmBlock;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(bl.next);
      ec.next := self.CalledBlock;
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](new StaticStmBlockRef(CalledBlock));
    
    public constructor(CalledBlock: StmBlock) :=
    self.CalledBlock := CalledBlock;
    
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
    
  end;
  
  OperCall = class(OperStmBase, ICallOper, IFileRefStm)
    
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
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1], sb));
    end;
    
    public constructor(CalledBlock: StmBlockRef) :=
    self.CalledBlock := CalledBlock;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      CalledBlock := CalledBlock.Optimize(self.bl, nvn, svn);
      if CalledBlock is StaticStmBlockRef(var sbf) then
        Result := new OperConstCall(sbf.bl) else
        Result := self;
    end;
    
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
    
  end;
  OperCallIf = class(OperStmBase, ICallOper, IFileRefStm)
    
    public e1,e2: OptExprWrapper;
    public compr: (equ=byte(1), less=byte(2), more=byte(3));
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
      
      CalledBlock1 := new DynamicStmBlockRef(new DInputSValue(par[4], sb));
      CalledBlock2 := new DynamicStmBlockRef(new DInputSValue(par[5], sb));
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
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      e1.Optimize(nvn, svn);
      e2.Optimize(nvn, svn);
      if
        (e1.GetMain() is IOptLiteralExpr) and
        (e2.GetMain() is IOptLiteralExpr)
      then
        Result := OperCall.Create(comp_obj(e1.GetMain.GetRes(), e2.GetMain.GetRes())?CalledBlock1:CalledBlock2).Optimize(nvn, svn) else
      begin
        CalledBlock1 := CalledBlock1.Optimize(bl, nvn, svn);
        CalledBlock2 := CalledBlock2.Optimize(bl, nvn, svn);
        Result := self;
      end;
    end;
    
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
    
  end;
  
  {$endregion Jump/Call}
  
  {$region ExecutingContext chandgers}
  
  OperSusp = class(OperStmBase)
    
    private static procedure Calc(ec: ExecutingContext) :=
    if ec.scr.susp_called = nil then
      System.Threading.Thread.CurrentThread.Suspend else
      ec.scr.susp_called();
    
    
    
    public constructor(bl: StmBlock);
    begin
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(1));
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
  end;
  OperReturn = class(OperStmBase, IContextJumpOper)
    
    public constructor(bl: StmBlock);
    begin
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(2));
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override := nil;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[0];
    
  end;
  OperHalt = class(OperStmBase, IContextJumpOper)
    
    private static procedure Calc(ec: ExecutingContext) :=
    Halt;
    
    
    
    public constructor(bl: StmBlock);
    begin
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(3));
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
  end;
  
  {$endregion ExecutingContext chandgers}
  
  {$region Misc}
  
  OperConstSleep = class(OperStmBase)
    
    public l: integer;
    
    private procedure Calc(ec: ExecutingContext) :=
    Sleep(l);
    
    
    
    public constructor(l: integer) :=
    self.l := l;
    
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
    
  end;
  OperConstOutput = class(OperStmBase)
    
    public otp: string;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var p := ec.scr.otp;
      if p <> nil then
        p(otp);
    end;
    
    
    
    public constructor(otp: string) :=
    self.otp := otp;
    
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
    
  end;
  
  OperSleep = class(OperStmBase)
    
    public l: InputNValue;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var i := NumToInt(l.res);
      if i < 0 then raise new InvalidSleepLengthException(ec.scr, i);
      Sleep(i);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(sb.scr, 2, par);
      
      l := new DInputNValue(par[1], sb);
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      l := l.Optimize(nvn, svn);
      if l is SInputNValue then
      begin
        var il := NumToInt(l.res);
        if il < 0 then raise new InvalidSleepLengthException(nil, il);
        Result := new OperConstSleep(il);
      end else
        Result := self;
    end;
    
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
    
  end;
  OperRandom = class(OperStmBase)
    
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
    
  end;
  OperOutput = class(OperStmBase)
    
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
      otp := new DInputSValue(par[1],sb);
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      otp := otp.Optimize(nvn, svn);
      if otp is SInputSValue then
        Result := new OperConstOutput(otp.res) else
        Result := self;
    end;
    
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
    
  end;
  
  {$endregion Misc}
  
  {$endregion operator's}
  
  {$region directive's}
  
  DrctFRef = class(DrctStmBase, IFileRefStm)
    
    public fns: array of string;
    
    function GetRefs: sequence of StmBlockRef :=
    fns.Select(fn->DynamicStmBlockRef.Create(new SInputSValue(fn)).Optimize(self.bl));
    
    public constructor(par: array of string);
    begin
      self.fns := par;
    end;
    
    public function Optimize(nvn: List<string>; svn: List<string>): StmBase; override;
    begin
      
      foreach var fn in fns do
        scr.ReadFileBatch(nil, fn);
      
      Result := nil;
    end;
    
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
    
  end;
  
  {$endregion directive's}
  
implementation

{$region constructor's}

{$region Single stm}

constructor ExprStm.Create(sb: StmBlock; text: string);
begin
  var ss := text.SmartSplit('=', 2);
  self.v_name := ss[0];
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
    
    'susp': Result := new OperSusp(sb);
    'return': Result := new OperReturn(sb);
    'halt': Result := new OperHalt(sb);
    
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

procedure Script.ReadFile(context: object; lbl: string; fQu: List<StmBlock>);
begin
  if not LoadedFiles.Add(lbl) then exit;
  
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

procedure Script.ReadFileBatch(context: object; lbl: string);
begin
  //if LoadedFiles=nil then exit;//Если загрузка уже была завершена. Но поидее этого вызова не может произойти
  var fQu := new List<StmBlock>;
  
  ReadFile(context, lbl, fQu);
  var any_done := true;
  
  while any_done do
  begin
    any_done := false;
    
    var Qu := fQu.ToArray;
    fQu.Clear;
    foreach var sb in Qu do
    begin
      var dir := System.IO.Path.GetDirectoryName(sb.fname)+'\';
      
      foreach var ref in sb.GetAllFRefs do
        if ref is StaticStmBlockRef then
        begin
          var s := StmBase.ObjToStr(ref.GetBlock(nil));
          if s = '' then continue;
          s := s.Split(new char[]('#'),2)[0];
          
          ReadFile(nil, CombinePaths(dir, s), fQu);
        end;
      
    end;
    
  end;
  
end;

constructor Script.Create(fname: string);
begin
  
  read_start_lbl_name := System.IO.Path.GetFullPath(fname);
  ReadFileBatch(nil, read_start_lbl_name);
  
  self.Optimize;
end;

{$endregion Script}

{$endregion constructor's}

{$region Misc Impl}

procedure StmBlock.SaveId(bw: System.IO.BinaryWriter) :=
bw.Write(scr.sbs.Values.Numerate(0).First(t->t[1]=self)[0]);

function StmBlock.GetAllFRefs: sequence of StmBlockRef;
begin
  foreach var op in stms do
    if op is IFileRefStm(var frs) then
      yield sequence frs.GetRefs;
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

function GetBlockChain(bl: StmBlock; bl_lst: List<StmBlock>; stm_lst: List<StmBase>; ind_lst: List<integer>): boolean;
begin
  Result := true;
  
  var curr := bl;
  
  var nvn := new List<string>;
  var svn := new List<string>;
  
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
      var opt := stm.Optimize(nvn, svn);
      if opt <> nil then
        stm_lst.Add(opt);
    end;
    
    var last := stm_lst[stm_lst.Count-1];
    if last is OperConstCall(var occ) then
    begin
      stm_lst.RemoveLast;
      ind_lst.Add(stm_lst.Count);
      
      if not GetBlockChain(occ.CalledBlock, bl_lst, stm_lst, ind_lst) then
      begin
        Result := false;//bl.next не надо присваивать, его уже изменило в рекурсивном вызове GetBlockChain
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
    
    curr := curr.next;
  end;
  
end;

procedure Script.Optimize;
begin
  
  var nopt: boolean;
  repeat
    nopt := true;
    
    foreach var bl: StmBlock in sbs.Values do
    begin
      var stms := new List<StmBase>;
      
      if GetBlockChain(bl, new List<StmBlock>, stms, new List<integer>) then
        bl.next := nil;
      
      nopt := nopt and bl.stms.SequenceEqual(stms);
      
      bl.stms := stms;
      
    end;
    
  until nopt;
  
  
  
  if sbs.Values.SelectMany(bl->bl.GetAllFRefs).All(ref->ref is StaticStmBlockRef) then
  begin
    LoadedFiles := nil;
    
    var ref_bl := new HashSet<StmBlock>;
    foreach var bl: StmBlock in sbs.Values do
      if bl.StartPos or not start_pos_def then
      begin
        ref_bl += bl;
        ref_bl += bl.GetAllFRefs.Select(ref->(ref as StaticStmBlockRef).bl);
        ref_bl += bl.next;
      end;
    
    var lc: integer;
    
    repeat
      lc := ref_bl.Count;
      ref_bl.Remove(nil);
      
      foreach var bl in ref_bl.ToList do
        if bl.StartPos or not start_pos_def then
        begin
          ref_bl += bl;
          ref_bl += bl.GetAllFRefs.Select(ref->(ref as StaticStmBlockRef).bl);
          ref_bl += bl.next;
        end;
      
    until lc=ref_bl.Count;
    
    foreach var kvp: KeyValuePair<string, StmBlock> in sbs.ToList do
      if not ref_bl.Contains(kvp.Value) then
        sbs.Remove(kvp.Key);
    
  end;
    
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