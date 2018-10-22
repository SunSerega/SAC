unit StmParser;
//ToDo Убрать лишние поля StmBlock (там список локальных переменных и т.п., что должно сущесвовать только в определённых процедурах)
//ToDo Добавить DeduseVarsTypes и Instatiate в ExprParser
//ToDo Удобный способ смотреть изначальный и оптимизированный вариант
//ToDo Контекст ошибок, то есть при оптимизации надо сохранять номер строки
//ToDo Оптимизация блоков, так чтоб они знали когда их результат - константа

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
    
    public class function GetAllSimpleAreas(a: FileContextArea): sequence of SimpleFileContextArea :=
    a.GetSubAreas.SelectMany(
      sa->
      (sa is SimpleFileContextArea)?
      Seq(sa as SimpleFileContextArea):
      GetAllSimpleAreas(sa)
    );
    
    public class function TryCombine(var a1: SimpleFileContextArea; a2: SimpleFileContextArea): boolean;
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
    
    public class function Combine(debug_name:string; params a: array of FileContextArea): FileContextArea;
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
    
    public class function Combine(params a: array of FileContextArea): FileContextArea :=
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
    
    public constructor(source: StmBlock; fname: string) :=
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
    inherited Create(source, $'Mouse key code must be 1..2 or 4..6, it can''t be {k}', KV('k'+'', object(k)));
    
  end;
  InvalidCompNameException = class(FileCompilingException)
    
    public constructor(source: Script; comp: string) :=
    inherited Create(source, $'"{comp}" is not compare operator', KV('comp', object(comp)));
    
  end;
  
  OutputStreamEmptyException = class(InnerException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Output stream was null');
    
  end;
  
  {$endregion Exception's}
  
  {$region Single stm}
  
  ExecutingContext = class
    
    public scr: Script;
    
    public curr: StmBlock;
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
    
    private class nfi := new System.Globalization.NumberFormatInfo;
    
    public bl: StmBlock;
    public scr: Script;
    
    public function GetCalc: Action<ExecutingContext>; abstract;
    
    public function Optimize(nvs: Dictionary<string, real>; svs: Dictionary<string, string>; ovs: List<string>): StmBase; virtual := self;
    
    public class function FromString(sb: StmBlock; s: string; par: array of string): StmBase;
    
    public class function ObjToStr(o: object): string;
    begin
      if o = nil then
        Result := '' else
      if o is string then
        Result := o as string else
        Result := real(o).ToString(nfi);
    end;
    
    public function NumToInt(n: real): integer;
    begin
      if real.IsNaN(n) or real.IsInfinity(n) then raise new CannotConvertToIntException(scr, n);
      var i := BigInteger.Create(n);
      if (i < integer.MinValue) or (i > integer.MaxValue) then raise new CannotConvertToIntException(scr, i);
      Result := integer(i);
    end;
    
  end;
  ExprStm = sealed class(StmBase)
    
    public v_name: string;
    public e: IExpr;
    
    public constructor(sb: StmBlock; text: string);
    
    public function GetCalc: Action<ExecutingContext>; override :=
    ec->
    ec.SetVar(v_name, e.Calc(
      ec.nvs,
      ec.svs
    ));
    
  end;
  DrctStmBase = abstract class(StmBase)
    
    public class function FromString(sb: StmBlock; text: string): DrctStmBase;
    
    public function GetCalc: Action<ExecutingContext>; override := nil;
    
  end;
  OperStmBase = abstract class(StmBase)
    
    public class function FromString(sb: StmBlock; par: array of string): OperStmBase;
    
  end;
  
  {$endregion Single stm}
  
  {$region Stm containers}
  
  StmBlock = class
    
    public stms := new List<StmBase>;
    public nvn := new List<string>;
    public svn := new List<string>;
    public next: StmBlock := nil;
    public Execute: Action<ExecutingContext>;
    
    public fname: string;
    public scr: Script;
    
    public prev: StmBlock;
    
    public function GetAllFRefs: sequence of OptExprBase;
    
    public procedure Seal;
    begin
      Execute := System.Delegate.Combine(stms.Select(stm->stm.GetCalc() as System.Delegate).ToArray) as Action<ExecutingContext>;
    end;
    
    constructor(scr: Script) :=
    self.scr := scr;
    
  end;
  Script = class
    
    private class nfi := new System.Globalization.NumberFormatInfo;
    
    public main_file_name: string;
    
    public otp: procedure(s: string);
    public susp_called: procedure;
    public stoped: procedure;
    
    public sbs := new Dictionary<string, StmBlock>;
    public nvn := new List<string>;
    public svn := new List<string>;
    public ovn := new List<string>;
    
    private class function CombinePaths(p1, p2: string): string;
    begin
      while p2.StartsWith('..\') do
      begin
        p1 := System.IO.Path.GetDirectoryName(p1);
        p2 := p2.Remove(0, 3);
      end;
      if p2.StartsWith('\') then
        Result := p1 + p2 else
        Result := p1 + '\' + p2;
    end;
    
    public constructor(fname: string);
    
    public procedure Optimize(load_done: boolean);
    
    public procedure Execute :=
    Execute(main_file_name);
    
    public procedure Execute(entry_point: string);
    begin
      var ec := new ExecutingContext(self, sbs[entry_point], 10000);
      while ec.ExecuteNext do;
      if stoped <> nil then
        stoped;
    end;
    
  end;
  
  {$endregion Stm containers}
  
  {$region InputValue}
  
  InputValue = abstract class
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    
    public function GetRes: object; abstract;
    
    public function Optimize(nvn, svn: List<string>): InputValue; virtual := self;
    
  end;
  
  InputSValue = abstract class(InputValue)
    
    public res: string;
    
    public function GetRes: object; override := res;
    
  end;
  SInputSValue = class(InputSValue)
    
    public constructor(res: string) :=
    self.res := res;
    
  end;
  DInputSValue = class(InputSValue)
    
    public oe: OptSExprWrapper;
    
    public procedure Calc(ec: ExecutingContext) :=
    self.res := oe.CalcS(ec.nvs, ec.svs);
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function Optimize(nvn, svn: List<string>): InputValue; override;
    begin
      oe.Optimize(nvn, svn);
      if oe.GetMain is IOptLiteralExpr(var me) then
        Result := new SInputSValue(string(me.GetRes)) else
        Result := self;
    end;
    
    public constructor(s: string; bl: StmBlock);
    begin
      oe := OptSExprWrapper(OptExprWrapper.FromExpr(Expr.FromString(s), bl.nvn, bl.svn, OptExprBase.AsStrExpr));
    end;
    
  end;
  
  InputNValue = abstract class(InputValue)
    
    public res: real;
    
    public function GetRes: object; override := res;
    
  end;
  SInputNValue = class(InputNValue)
    
    public constructor(res: real) :=
    self.res := res;
    
  end;
  DInputNValue = class(InputNValue)
    
    public oe: OptNExprWrapper;
    
    public procedure Calc(ec: ExecutingContext) :=
    res := oe.CalcN(ec.nvs, ec.svs);
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function Optimize(nvn, svn: List<string>): InputValue; override;
    begin
      oe.Optimize(nvn, svn);
      if oe.GetMain is IOptLiteralExpr(var me) then
        Result := new SInputNValue(real(me.GetRes)) else
        Result := self;
    end;
    
    public constructor(s: string; bl: StmBlock);
    begin
      oe := OptNExprWrapper(OptExprWrapper.FromExpr(Expr.FromString(s), bl.nvn, bl.svn, oe->OptExprBase.AsDefinitelyNumExpr(oe)));
    end;
    
  end;
  
  {$endregion InputValue}
  
  {$region StmBlockRef}
  
  StmBlockRef = abstract class
    
    function GetCalc: Action<ExecutingContext>; virtual := nil;
    
    function GetBlock(ec: ExecutingContext): StmBlock; abstract;
    
  end;
  StaticStmBlockRef = class(StmBlockRef)
    
    bl: StmBlock;
    
    function GetBlock(ec: ExecutingContext): StmBlock; override := bl;
    
  end;
  DynamicStmBlockRef = class(StmBlockRef)
    
    s: InputSValue;
    
    function GetCalc: Action<ExecutingContext>; override := s.GetCalc;
    
    function GetBlock(ec: ExecutingContext): StmBlock; override;
    begin
      var res := s.res;
      if res <> '' then
      begin
        if res.StartsWith('#') then
          res := ec.curr.fname+res else
          res := Script.CombinePaths(System.IO.Path.GetDirectoryName(ec.curr.fname), res);
        
        if not ec.scr.sbs.TryGetValue(res, Result) then
          raise new LabelNotFoundException(ec.scr, res);
      end;
    end;
    
    constructor(s: InputSValue) :=
    self.s := s;
    
  end;
  
  {$endregion StmBlockRef}
  
  {$region interface's}
  
  IFileRefStm = interface
    
    function GetRefs: sequence of OptExprBase;
    
  end;
  
  IJumpCallOper = interface
    
  end;
  ICallOper = interface(IJumpCallOper)
    
    property JumpBl: StmBlock read write;
    
  end;
  IJumpOper = interface(IJumpCallOper)
    
  end;
  
  {$endregion interface's}
  
  {$region operator's}
  
  {$region Key/Mouse}
  
  OperKey = class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    class procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      dp.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperKeyDown = class(OperStmBase)
    
    public kk: InputNValue;
    
    class procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperKeyUp = class(OperStmBase)
    
    public kk: InputNValue;
    
    class procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperKeyPress = class(OperStmBase)
    
    public kk: InputNValue;
    
    class procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperMouse = class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    class procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: cardinal);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      dp.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperMouseDown = class(OperStmBase)
    
    public kk: InputNValue;
    
    class procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperMouseUp = class(OperStmBase)
    
    public kk: InputNValue;
    
    class procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperMousePress = class(OperStmBase)
    
    public kk: InputNValue;
    
    class procedure mouse_event(dwFlags, dx, dy, dwData, dwExtraInfo: longword);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  
  {$endregion Key/Mouse}
  
  {$region Other simulators}
  
  OperMousePos = class(OperStmBase)
    
    public x,y: InputNValue;
    
    class procedure SetCursorPos(x, y: integer);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      x.GetCalc(),
      y.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperGetKey = class(OperStmBase)
    
    public kk: InputNValue
    public vname: string;
    
    class function GetKeyState(nVirtKey: byte): byte;
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperGetKeyTrigger = class(OperStmBase)
    
    public kk: InputNValue
    public vname: string;
    
    class function GetKeyState(nVirtKey: byte): byte;
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      kk.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperGetMousePos = class(OperStmBase)
    
    public x,y: string;
    
    class procedure GetCursorPos(p: ^Point);
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    self.Calc;
    
  end;
  
  {$endregion Other simulators}
  
  {$region Call/Jump}
  
  OperCall = class(OperStmBase, ICallOper)
    
    public CalledBlock: StmBlockRef;
    public next: StmBlock;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(self.next);
      ec.curr.next := self.CalledBlock.GetBlock(ec);
    end;
    
    
    
    public property JumpBl: StmBlock read next write next;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1], sb));
    end;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      CalledBlock.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperCallIf = class(OperStmBase, ICallOper)
    
    public e1,e2: OptExprWrapper;
    public compr: (equ, less, more);
    public CalledBlock1: StmBlockRef;
    public CalledBlock2: StmBlockRef;
    public next: StmBlock;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(self.next);
      var res1 := e1.Calc(ec.nvs, ec.svs);
      var res2 := e2.Calc(ec.nvs, ec.svs);
      ec.curr.next := comp_obj(res1,res2)?CalledBlock1.GetBlock(ec):CalledBlock2.GetBlock(ec);
    end;
    
    
    
    public property JumpBl: StmBlock read next write next;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientOperParamCount(self.scr, 6, par);
      
      if par[2].Length <> 1 then raise new InvalidCompNameException(sb.scr, par[2]);
      case par[2][1] of
        '=': compr := equ;
        '<': compr := less;
        '>': compr := more;
        else raise new InvalidCompNameException(sb.scr, par[2]);
      end;
      
      e1 := OptExprWrapper.FromExpr(Expr.FromString(par[1]), sb.nvn, sb.svn);
      e2 := OptExprWrapper.FromExpr(Expr.FromString(par[3]), sb.nvn, sb.svn);
      
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      CalledBlock1.GetCalc(),
      CalledBlock2.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  
  OperCJump = class(OperStmBase, IJumpOper)
    
    public CalledBlock: StmBlock;
    
    
    
    public function GetCalc: Action<ExecutingContext>; override :=
    procedure(ec)->ec.curr.next := self.CalledBlock;
    
  end;
  OperJump = class(OperStmBase, IJumpOper)
    
    public CalledBlock: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.curr.next := self.CalledBlock.GetBlock(ec);
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1], sb));
    end;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      CalledBlock.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperJumpIf = class(OperStmBase, IJumpOper)
    
    public e1,e2: OptExprWrapper;
    public compr: (equ, less, more);
    public CalledBlock1: StmBlockRef;
    public CalledBlock2: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var res1 := e1.Calc(ec.nvs, ec.svs);
      var res2 := e2.Calc(ec.nvs, ec.svs);
      ec.curr.next := comp_obj(res1,res2)?CalledBlock1.GetBlock(ec):CalledBlock2.GetBlock(ec);
    end;
    
    
    
    public function Optimize(nvs: Dictionary<string, real>; svs: Dictionary<string, string>; ovs: List<string>): StmBase; override;
    begin
      
    end;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientOperParamCount(self.scr, 6, par);
      
      if par[2].Length <> 1 then raise new InvalidCompNameException(sb.scr, par[2]);
      case par[2][1] of
        '=': compr := equ;
        '<': compr := less;
        '>': compr := more;
        else raise new InvalidCompNameException(sb.scr, par[2]);
      end;
      
      e1 := OptExprWrapper.FromExpr(Expr.FromString(par[1]), sb.nvn, sb.svn);
      e2 := OptExprWrapper.FromExpr(Expr.FromString(par[3]), sb.nvn, sb.svn);
      
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
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      CalledBlock1.GetCalc(),
      CalledBlock2.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action&<ExecutingContext>;
    
  end;
  
  {$endregion Call/Jump}
  
  {$region ExecutingContext chandgers}
  
  OperSusp = class(OperStmBase)
    
    public constructor := exit;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    ec->
    begin
      if ec.scr.susp_called <> nil then
        ec.scr.susp_called();
      System.Threading.Thread.CurrentThread.Suspend;
    end;
    
  end;
  OperReturn = class(OperStmBase, IJumpOper)
    
    public constructor := exit;
    
    public function GetCalc: Action<ExecutingContext>; override := nil;
    
  end;
  OperHalt = class(OperStmBase, IJumpOper)
    
    public constructor := exit;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    oe->Halt();
    
  end;
  
  {$endregion ExecutingContext chandgers}
  
  {$region Misc}
  
  OperSleep = class(OperStmBase, IJumpOper)
    
    public l: InputNValue;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var r := l.res;
      if real.IsNaN(r) or real.IsInfinity(r) then raise new CannotConvertToIntException(l, r);
      var i := BigInteger.Create(r);
      if (i < 0) or (i > integer.MaxValue) then raise new InvalidSleepLengthException(ec.scr, i);
      Sleep(integer(i));
    end;
    
    
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      l := new DInputNValue(par[1], sb);
    end;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      l.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  OperRandom = class(OperStmBase, IJumpOper)
    
    public vname: string;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      vname := par[1];
    end;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    ec->ec.SetVar(vname, Random());
    
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
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      otp := new DInputSValue(par[1],sb);
    end;
    
    public public function GetCalc: Action<ExecutingContext>; override :=
    System.Delegate.Combine(
      otp.GetCalc(),
      Action&<ExecutingContext>(self.Calc)
    ) as Action<ExecutingContext>;
    
  end;
  
  {$endregion Misc}
  
  {$endregion operator's}
  
  {$region directive's}
  
  DrctFRef = class(DrctStmBase, IFileRefStm)
    
    public fns: array of string;
    
    function GetRefs: sequence of OptExprBase :=
    fns.Select(fn->new OptSLiteralExpr(fn) as OptExprBase);
    
    public constructor(par: array of string);
    begin
      self.fns := par;
    end;
    
  end;
  
  {$endregion directive's}
  
implementation

{$region General}

function SmartSplit(self: string; ch: char := ' '; c: integer := -1): array of string; extensionmethod;
begin
  if (self = '') or (c = 0) then
  begin
    Result := new string[1]('');
    exit;
  end else
  if c = 1 then
  begin
    Result := new string[1](self);
    exit;
  end;
  
  c -= 1;
  var wsp := new List<integer>;
  
  var n := 1;
  while n < self.Length do
  begin
    
    if self[n] = '"' then
      n := self.FindNext(n+1,'"') else
    if self[n] = '(' then
      n := self.FindNext(n+1,')') else
    if self[n] = ch then
    begin
      wsp += n;
      if wsp.Count = c then break;
    end;
    
    n += 1;
  end;
  
  if wsp.Count=0 then
  begin
    Result := new string[](self);
    exit;
  end;
  
  Result := new string[wsp.Count+1];
  Result[0] := self.Substring(0, wsp[0]-1);
  
  for var i := 0 to wsp.Count-2 do
    Result[i+1] := self.Substring(wsp[i], wsp[i+1]-wsp[i]-1);
  
  Result[Result.Length-1] := self.Substring(wsp[wsp.Count-1]);
  
end;

{$endregion General}
  
{$region constructor's}

constructor ExprStm.Create(sb: StmBlock; text: string);
begin
  var ss := text.SmartSplit('=', 2);
  self.v_name := ss[0];
  self.e := ExprParser.OptExprWrapper.FromExpr(Expr.FromString(ss[1]),sb.nvn, sb.svn);
end;

class function DrctStmBase.FromString(sb: StmBlock; text: string): DrctStmBase;
begin
  var p := text.Split(new char[]('='),2);
  case p[0] of
    '!fref': Result := new DrctFRef(p[1].Split(','));
  else raise new UndefinedDirectiveNameException(sb, text);
  end;
end;

class function OperStmBase.FromString(sb: StmBlock; par: array of string): OperStmBase;
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

class function StmBase.FromString(sb: StmBlock; s: string; par: array of string): StmBase;
begin
  if s.StartsWith('!') then
    Result := DrctStmBase.FromString(sb, s);
  if par[0].Contains('=') then
    Result := ExprStm.Create(sb, s) else
    Result := OperStmBase.FromString(sb, par);
  
  Result.bl := sb;
  Result.scr := sb.scr;
end;

constructor Script.Create(fname: string);
begin
  var fQu := new List<StmBlock>;
  
  var LoadedFiles := new HashSet<string>;
  var LoadFile: procedure(sb: StmBlock; f: string) :=
  (sb, f)->
  begin
    if not LoadedFiles.Add(f) then exit;
    
    var fi := new System.IO.FileInfo(f);
    if not fi.Exists then raise new RefFileNotFound(sb, fi.FullName);
    var ffname := fi.FullName;
    
    var lns: array of string;
    begin
      var str := fi.OpenRead;
      lns := (new System.IO.StreamReader(str)).ReadToEnd.Remove(#13).Split(#10);
      str.Close;
    end;
    
    var last := new StmBlock(self);
    var lname := ffname;
    
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
          if skp_ar then
          begin
            last.Seal;
            last := new StmBlock(self);
            skp_ar := false;
          end else
          begin
            last.next := new StmBlock(self);
            last.Seal;
            last := last.next;
          end;
          lname := ffname+s;
          
        end else
          if (s <> '') and not skp_ar then
          begin
            var stm := StmBase.FromString(last, s, ss.SmartSplit);
            last.stms.Add(stm);
            if stm is ICallOper{(var ico)} then//ToDo #незнаю_ибо_нет_инета
            begin
              sbs.Add(lname, last);
              last.fname := ffname;
              last.Seal;
              last := new StmBlock(self);
              //ico.SetNext(last);//ToDo #незнаю_ибо_нет_инета
              ICallOper(stm).JumpBl := last;
              lname := ffname+'#%'+tmp_b_c;
              tmp_b_c += 1;
            end else
            if stm is IJumpOper then
              skp_ar := true;
          end;
      end;
    
    last.Seal;
    sbs.Add(lname, last);
  end;
  
  main_file_name := (new System.IO.FileInfo(fname)).FullName;
  LoadFile(nil, fname);
  var any_done := true;
  var all_frefs_static := true;
  while any_done do
  begin
    any_done := false;
    
    var Qu := fQu.ToArray;
    fQu.Clear;
    foreach var sb in Qu do
    begin
      var dir := System.IO.Path.GetDirectoryName(sb.fname)+'\';
      
      foreach var oe in sb.GetAllFRefs do
        if oe is IOptLiteralExpr then
        begin
          var res := oe.GetRes;
          if (res = nil) or (res as string = 'null') then continue;
          if res is real(var n) then
            res := n.ToString(nfi);
          
          var s := res as string;
          if s.Contains('#') then
            s := s.Split(new char[]('#'),2)[0];
          
          LoadFile(sb, CombinePaths(dir, s));
        end else
          all_frefs_static := false;
      
    end;
    
  end;
  
  self.Optimize(all_frefs_static);
end;

{$endregion constructor's}

function StmBlock.GetAllFRefs: sequence of OptExprBase;
begin
  foreach var op in stms do
    if op is IFileRefStm(var frs) then
      yield sequence frs.GetRefs;
end;

procedure Script.Optimize(load_done: boolean);
begin
  
  exit;
  var njbs: List<StmBlock>;
  njbs := self.sbs.Values.Where(bl->not (bl.stms.Last is IJumpCallOper)).ToList;//ошибка если в stms нету ни 1 оператора
  var prev_njbs := new HashSet<StmBlock>;
  while njbs.Count <> 0 do
  begin
    foreach var njb in njbs do
      foreach var bl: StmBlock in self.sbs.Values do
        if (bl.stms.Last is IJumpOper(var ijo)) and false then//ToDo if ijo.next=njb
        begin
          var Main_ToDo := 0;
          bl.stms.Remove(bl.stms.Last);
          bl.stms.AddRange(njb.stms);
        end else
        if (not (bl.stms.Last is IJumpCallOper)) and (bl.next = njb) then
          bl.stms.AddRange(njb.stms);
    
    prev_njbs += njbs;
    njbs := self.sbs.Values.Where(bl->not (prev_njbs.Contains(bl) or (bl.stms.Last is IJumpCallOper))).ToList;
  end;
  
end;

function ExecutingContext.ExecuteNext: boolean;
begin
  if curr <> nil then
  begin
    curr.Execute(self);
    curr := curr.next;
    Result := true;
  end else
    Result := Pop(curr);
end;

{$region temp_reg}

{$endregion temp_reg}

end.