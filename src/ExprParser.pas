﻿unit ExprParser;

//ToDo а что если убрать IOptExpr? Оно вроде давно утратило своё предназначение

//ToDo в DeduseVarsTypes OPlus можно превращать в NPlus, но не SPlus (результат будет не тот)
// - так же с остальными
// - это позволит перемещать DeflyNum внуть выражений, в итоге получая ошибку или удаляя DeflyNum до завершения оптимизации

//ToDo в DeduseVarsTypes надо передавать метод вызывающий ошибку
// - иначе получается внутренняя "не совместимые типы"

//ToDo Контекст ошибок

//ToDo срочно - DeflyNum должно показывать имя файла, всё выражение и часть вызывающую ошибку! В тест сьюте тест неправильный из за этого
// - наверное всё же контекст ошибок придётся сделать для этого

//ToDo Проверить issue:
// - #533
// - #1418

interface

type
  {$region Exception's}
  
  {$region Inner}
  
  ExprContextArea = class;
  
  InnerException = abstract class(Exception)
    
    public Sender: object;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Inner exception in {sender}: ' + text);
      self.Sender := Sender;
      foreach var kvp in d do
        ExtraInfo.Add(kvp.Key, kvp.Value);
    end;
    
  end;
  CannotCalcLoadedExpr = class(InnerException)
    
    public constructor :=
    inherited Create(nil, 'Unprecompiled expr calculation not implemented');
    
  end;
  ReadingOutOfRangeException = class(InnerException)
    
    public constructor(text: string; i: integer) :=
    inherited Create(text, $'Was trying to read after text end, at #{i}', KV('i'+'', object(i)));
    
  end;
  UnexpectedNegativePow = class(InnerException)
    
    public constructor(source: object) :=
    inherited Create($'[> {source} <]', $'Pow Loaded Expr had negative params');
    
  end;
  UnexpectedExprTypeException = class(InnerException)
    
    public constructor(source: object; t: System.Type) :=
    inherited Create($'[> {source} <]', $'Undefined expr type: {t}', KV('t'+'', object(t)));
    
  end;
  UnexpectedOExprBaseException = class(InnerException)
    
    public constructor(source: object) :=
    inherited Create($'[> {source} <]', $'Unexpected OExprBase');
    
  end;
  SaveNotImplementedException = class(InnerException)
    
    public constructor(sender: object) :=
    inherited Create(sender, 'Binarry save proc not implemented for type {sender.GetType}');
    
  end;
  ConflictingExprTypesException = class(InnerException)
    
    public constructor(t1,t2: System.Type) :=
    inherited Create(nil, $'Can''t convert expr type from {t1} to {t2}', KV('t1',object(t1)), KV('t2',object(t2)));
    
  end;
  
  {$endregion Inner}
  
  {$region ContextCreation}
  
  ContextCreationException = abstract class(Exception)
    
    public Sender: object;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Error {sender}: ' + text);
      self.Sender := Sender;
      foreach var kvp in d do
        ExtraInfo.Add(kvp.Key, kvp.Value);
    end;
    
  end;
  UnexpectedExprContextDataException = class(ContextCreationException)
    
    public constructor(data: ExprContextArea) :=
    inherited Create(data, $'Unexpected expression context data');
    
  end;
  
  {$endregion General}
  
  {$region Parsing}
  
  ExprParsingException = abstract class(Exception)
    
    public Sender: object;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Error parsing [> {sender} <]: ' + text);
      self.Sender := Sender;
      foreach var kvp in d do
        ExtraInfo.Add(kvp.Key, kvp.Value);
    end;
    
  end;
  CorrespondingCharNotFoundException = class(ExprParsingException)
    
    public constructor(str: string; ch: char; from: integer) :=
    inherited Create(str, $'Corresponding [> {ch} <] not found, starting from symbol #{from}', KV('ch', object(ch)), KV('from', object(from)));
    
  end;
  InvalidCharException = class(ExprParsingException)
    
    public constructor(str: string; pos: integer) :=
    inherited Create(str, $'Invalid char [> {str[pos]} <] at #{pos}', KV('pos', object(pos)));
    
  end;
  ExtraCharsException = class(ExprParsingException)
    
    public constructor(str: string; i1,im,i2: integer) :=
    inherited Create(str, $'Unconvertible chars [> {str.Substring(im-1, i2-im+1)} <] in expression [> {str.Substring(i1-1, i2-i1+1)} <]', KV('i1', object(i1)), KV('im', object(im)), KV('i2', object(i2)));
    
  end;
  EmptyExprException = class(ExprParsingException)
    
    public constructor(str: string; pos: integer) :=
    inherited Create(str, $'Empty expression at #{pos}', KV('pos', object(pos)));
    
  end;
  CanNotParseException = class(ExprParsingException)
    public constructor(str:string) :=
    inherited Create(str, $'Expression can''t be parsed');
  end;
  InvalidUseOfStrCut = class(ExprParsingException)
    public constructor(str:string) :=
    inherited Create(str, $'Invalid use of string cuting');
  end;
  InvalidVarException = class(ExprParsingException)
    public constructor(vname, why:string) :=
    inherited Create(vname, $'Variable can''t be parsed, because: {why}');
  end;
  
  {$endregion Parsing}
  
  {$region Compiling}
  
  ExprCompilingException = abstract class(Exception)
    
    public Sender: object;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Compiling exception in [> {sender} <]: ' + text);
      self.Sender := Sender;
      foreach var kvp in d do
        ExtraInfo.Add(kvp.Key, kvp.Value);
    end;
    
  end;
  
  ValueCannotBeNum = class(ExprCompilingException)
    
    public constructor(sender: object) :=
    inherited Create(sender, $'value can''t be Num');
    
  end;
  ValueCannotBeStr = class(ExprCompilingException)
    
    public constructor(sender: object) :=
    inherited Create(sender, $'value can''t be Str');
    
  end;
  UnknownFunctionNameException = class(ExprCompilingException)
    
    public constructor(sender: object; func_name: string) :=
    inherited Create(sender, $'Function "{func_name}" not defined', KV('func_name', object(func_name)));
    
  end;
  InvalidFuncParamCountException = class(ExprCompilingException)
    
    public constructor(sender: object; func_name: string; exp_c, fnd_c: integer) :=
    inherited Create(sender, $'Function "{func_name}" had {fnd_c} parameters, when expected {exp_c}', KV('func_name', object(func_name)), KV('exp_c', object(exp_c)), KV('fnd_c', object(fnd_c)));
    
  end;
  InvalidFuncParamTypesException = class(ExprCompilingException)
    
    public constructor(sender: object; func_name: string; param_n: integer; exp_t, fnd_t: System.Type) :=
    inherited Create(sender, $'Function "{func_name}" parameter #{param_n} had type {fnd_t}, when expected {exp_t}', KV('func_name', object(func_name)), KV('param_n', object(param_n)), KV('exp_t', object(exp_t)), KV('fnd_t', object(fnd_t)));
    
  end;
  CannotSubStringExprException = class(ExprCompilingException)
    
    public constructor(sender: object; sub: object) :=
    inherited Create(sender, $'Can''t substruct expressions from strings. Was substructing [> {sub} <]', KV('sub', sub));
    
  end;
  CannotDivStringExprException = class(ExprCompilingException)
    
    public constructor(sender: object; numr, denomr: object) :=
    inherited Create(sender, $'Can''t divide expressions with strings. Was dividing [> {numr} <] by [> {denomr} <]', KV('numr', numr), KV('denomr', denomr));
    
  end;
  CannotMltALotStringsException = class(ExprCompilingException)
    
    public constructor(sender: object; strs: object) :=
    inherited Create(sender, $'Can''t multiply string by strings. Expressions with strings: [> strs <]', KV('strs', strs));
    
  end;
  CannotPowStringException = class(ExprCompilingException)
    
    public constructor(sender: object) :=
    inherited Create(sender, $'Can''t use operator^ on string');
    
  end;
  TooBigStringException = class(ExprCompilingException)
    
    public constructor(sender: object; str_l: BigInteger) :=
    inherited Create(sender, $'Resulting string had length {str_l}. Can''t save string with length > (2^31-1)=2147483647', KV('str_l', object(str_l)));
    
  end;
  CanNotMltNegStringException = class(ExprCompilingException)
    
    public constructor(sender: object; k: BigInteger) :=
    inherited Create(sender, $'Can''t muliply string and {k}, number can''t be negative', KV(''+'k', object(k)));
    
  end;
  ExpectedNumValueException = class(ExprCompilingException)
    
    public constructor(sender: object) :=
    inherited Create(sender, $'Expected Num Value');
    
  end;
  CannotConvertToIntException = class(ExprCompilingException)
    
    public constructor(sender, val: object) :=
    inherited Create(sender, $'Can''t convert [{val}] to integer', KV('val',object(val)));
    
  end;
  CutOutOfRangeException = class(ExprCompilingException)
    
    public constructor(sender: object; s: string; i1,i2: BigInteger) :=
    inherited Create(sender, $'Cut [{i1}..{i2}] can''t be applied to "{s}" (len={s.Length})', KV('s'+'',object(s)), KV('i1',object(i1)), KV('i2',object(i2)));
    
  end;
  UndefinedKeyNameException = class(ExprCompilingException)
    
    public constructor(sender: object; s: string) :=
    inherited Create(sender, $'Key name [> {s} <] not defined');//ToDo test for s too long
    
  end;
  
  {$endregion Compiling}
  
  {$region Load}
  
  LoadException = abstract class(InnerException)
    
    public constructor(text: string; params d: array of KeyValuePair<string, object>) :=
    inherited Create(nil, $'LoadException: {text}', d);
    
  end;
  InvalidExprTException = class(LoadException)
    
    public constructor(t1,t2: byte) :=
    inherited Create($'Invalid Expr type: {(t1,t2)}', KV('t1', object(t1)), KV('t2', object(t2)));
    
  end;
  InvalidFuncTException = class(LoadException)
    
    public constructor(t: byte) :=
    inherited Create($'SFunc type can be 1..4, not {t}', KV('t'+'', object(t)));
    
  end;
  
  {$endregion Load}
  
  {$endregion Exception's}
  
  {$region ExprContextArea}
  
  ExprContextArea = abstract class
    
    public debug_name: string;
    
    public function GetSubAreas: IList<ExprContextArea>; abstract;
    
  end;
  SimpleExprContextArea = sealed class(ExprContextArea)
    
    public p1,p2: integer;
    
    public function GetSubAreas: IList<ExprContextArea>; override := new ExprContextArea[](self);
    
    public static function GetAllSimpleAreas(a: ExprContextArea): sequence of SimpleExprContextArea :=
    a.GetSubAreas.SelectMany(
      sa->
      (sa is SimpleExprContextArea)?
      (new ExprContextArea[](sa)).Cast&<SimpleExprContextArea>:
      GetAllSimpleAreas(sa)
    );
    
    public static function TryCombine(var a1: SimpleExprContextArea; a2: SimpleExprContextArea): boolean;
    begin
      Result :=
        ( (a1.p1 >= a2.p1-1) and (a1.p1 <= a2.p2+1) ) or
        ( (a1.p2 >= a2.p1-1) and (a1.p2 <= a2.p2+1) );
      
      if Result then
        a1 := new SimpleExprContextArea(
          Min(a1.p1,a2.p1),
          Max(a1.p2,a2.p2),
          (new string[](a1.debug_name,a2.debug_name))
          .Where(s->s<>'')
          .JoinIntoString('+')
        );
    end;
    
    public constructor(p1,p2: integer; debug_name: string := '');
    begin
      self.p1 := p1;
      self.p2 := p2;
      self.debug_name := debug_name;
      if p2 < p1 then raise new UnexpectedExprContextDataException(self);
    end;
    
  end;
  ComplexExprContextArea = sealed class(ExprContextArea)
    
    public sas: IList<ExprContextArea>;
    
    public function GetSubAreas: IList<ExprContextArea>; override := sas;
    
    public static function Combine(debug_name:string; params a: array of ExprContextArea): ExprContextArea;
    begin
      var scas := a.SelectMany(SimpleExprContextArea.GetAllSimpleAreas).ToList;
      scas.ForEach(procedure(ca)->ca.debug_name := '');
      
      var try_smpl: List<SimpleExprContextArea> -> boolean :=
      l->
      begin
        Result := false;
        for var i1 := l.Count-2 downto 0 do
          for var i2 := l.Count-1 downto i1+1 do
          begin
            var a1 := l[i1];
            if SimpleExprContextArea.TryCombine(a1, l[i2]) then
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
        var res := new ComplexExprContextArea;
        res.sas := scas.ConvertAll(ca->ca as ExprContextArea);
        res.debug_name := debug_name;
        Result := res;
      end;
    end;
    
    public static function Combine(params a: array of ExprContextArea): ExprContextArea :=
    Combine(
      a
      .Select(ca->ca.debug_name)
      .Where(s->s<>'')
      .JoinIntoString('+'),
      a
    );
    
  end;
  
  {$endregion ExprContextArea}
  
  {$region PreOpt}
  
  Expr = abstract class
    
    public static nfi := new System.Globalization.NumberFormatInfo;
    
    public static function FromString(text:string): Expr :=
    FromString(text,1,text.Length);
    
    public static function FromString(text:string; i1,i2:integer): Expr;
    
  end;
  
  NLiteralExpr = sealed class(Expr)
    
    val: real;
    
    constructor(val: real) :=
    self.val := val;
    
    public function ToString: string; override :=
    val.ToString(nfi);
    
  end;
  SLiteralExpr = sealed class(Expr)
    
    val: string;
    
    constructor(val: string) :=
    self.val := val;
    
    public function ToString: string; override;
    
  end;
  
  ComplexExpr = abstract class(Expr)
    
    Positive := new List<Expr>;
    Negative := new List<Expr>;
    
  end;
  PlusExpr = sealed class(ComplexExpr)
    
    public function ToString: string; override :=
    $'({Positive.JoinIntoString(''+'')}-{Negative.JoinIntoString(''-'')})';
    
  end;
  MltExpr = sealed class(ComplexExpr)
    
    public function ToString: string; override :=
    $'({Positive.JoinIntoString(''*'')}/{Negative.JoinIntoString(''/'')})';
    
  end;
  PowExpr = sealed class(ComplexExpr)
    
    public function ToString: string; override :=
    $'({Positive.First}^{Positive.Skip(1).JoinIntoString(''^'')})';
    
  end;
  
  FuncExpr = sealed class(Expr)
    
    name: string;
    par: array of Expr;
    
    constructor(name: string; par: array of string);
    begin
      self.name := name;
      self.par := par.ConvertAll(p->Expr.FromString(p));
    end;
    
    public function ToString: string; override :=
    $'{name}({par.JoinIntoString('','')})';
    
  end;
  VarExpr = sealed class(Expr)
    
    name: string;
    
    constructor(name: string) :=
    self.name := name;
    
    public function ToString: string; override :=
    name;
    
  end;
  
  {$endregion PreOpt}
  
  {$region Optimized}
  
  {$region Base}
  
  OptExprBase=class;
  OptNExprBase=class;
  OptSExprBase=class;
  OptExprWrapper=class;
  
  IOptExpr = interface
    
    function GetRes: Object;
    function GetResType: System.Type;
    
    function FixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr;
    function UnFixVarExprs(nn, ns, no: array of string): IOptExpr;
    function FinalFixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr;
    function ReplaceVar(vn: string; oe: OptExprBase): IOptExpr;
    procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks, StrChecks: Dictionary<string, ExprContextArea>);
    function IsSame(oe: IOptExpr): boolean;
    function NVarUseCount(id: integer): integer;
    function SVarUseCount(id: integer): integer;
    function OVarUseCount(id: integer): integer;
    
    function Optimize(nvn, svn, ovn: array of string): IOptExpr;
    procedure SetWrapper(wrapper: OptExprWrapper);
    procedure ClampLists;
    
    function GetCalc: sequence of Action0;
    function ToString(nvn, svn, ovn: array of string): string;
    
  end;
  OptExprBase = abstract class(IOptExpr)
    
    protected static nfi := new System.Globalization.NumberFormatInfo;
    public wrapper: OptExprWrapper;
    
    public static function AsDefinitelyNumExpr(o: OptExprBase; ifnot: Action0 := nil): OptNExprBase;//("a"*o1)*(5*3) => "a"*(DeflyNum(o1)*5*3)
    public static function AsStrExpr(o: OptExprBase): OptSExprBase;//"a"+("b"+o1) => "a"+"b"+Str(o1)
    
    public static function ObjToStr(o: object): string;
    begin
      if o = nil then
        Result := '' else
      if o is string then
        Result := o as string else
        Result := real(o).ToString(nfi);
    end;
    
    public static function ObjToNum(o: object): real;
    begin
      if o <> nil then
        if o is string then
          raise new ExpectedNumValueException(o) else
          Result := real(o);
    end;
    
    public static function ObjToNumUnsafe(o: object): real;
    begin
      if o <> nil then
        Result := real(o);
    end;
    
    
    
    public function Copy: OptExprBase; abstract;
    
    public function GetRes: object; abstract;
    public function GetResType: System.Type; abstract;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; virtual := self;
    protected procedure ExecuteOnEverySubExpr(p: IOptExpr->());
    begin
      TransformAllSubExprs(
        oe->
        begin
          p(oe);
          Result := oe;
        end
      );
    end;
    protected function SelectAllSubExprs<T>(f: IOptExpr->T): List<T>;
    begin
      var res := new List<T>;
      TransformAllSubExprs(
        oe->
        begin
          res += f(oe);
          Result := oe;
        end
      );
      Result := res;
    end;
    
    
    
    public function FixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr; virtual :=
    TransformAllSubExprs(oe->oe.FixVarExprs(sn,ss,so, nn,ns,no));
    
    public function UnFixVarExprs(nn, ns, no: array of string): IOptExpr; virtual :=
    TransformAllSubExprs(oe->oe.UnFixVarExprs(nn,ns,no));
    
    public function FinalFixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr; virtual :=
    TransformAllSubExprs(oe->oe.FinalFixVarExprs(sn,ss,so, nn,ns,no));
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; virtual :=
    TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn));
    
    public function Optimize(wrapper: OptExprWrapper): IOptExpr;
    
    public procedure SetWrapper(wrapper: OptExprWrapper);
    begin
      self.wrapper := wrapper;
      ExecuteOnEverySubExpr(oe->oe.SetWrapper(wrapper));
    end;
    
    public procedure ClampLists; virtual :=
    ExecuteOnEverySubExpr(oe->oe.ClampLists());
    
    public function ReplaceVar(vn: string; oe: OptExprBase): IOptExpr; virtual :=
    TransformAllSubExprs(se->se.ReplaceVar(vn,oe));
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N,CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); virtual;
    begin
      
      if (self as object is OptNExprBase) and not CB_N then raise new ConflictingExprTypesException(nil,nil);
      if (self as object is OptSExprBase) and not CB_S then raise new ConflictingExprTypesException(nil,nil);
      
      ExecuteOnEverySubExpr(oe->oe.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, true,true, NumChecks,StrChecks));
    end;
    
    public function IsSame(oe: IOptExpr): boolean; abstract;
    
    public function NVarUseCount(id: integer): integer; virtual :=
    SelectAllSubExprs(oe->oe.NVarUseCount(id)).Sum;
    
    public function SVarUseCount(id: integer): integer; virtual :=
    SelectAllSubExprs(oe->oe.SVarUseCount(id)).Sum;
    
    public function OVarUseCount(id: integer): integer; virtual :=
    SelectAllSubExprs(oe->oe.OVarUseCount(id)).Sum;
    
    public procedure Save(bw: System.IO.BinaryWriter); virtual :=
    raise new SaveNotImplementedException(self);
    
    public static function Load(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object): OptExprBase;
    
    
    
    public function GetCalc: sequence of Action0; virtual := new Action0[0];
    
    public function ToString: string; override;
    
    public function ToString(nvn, svn, ovn: array of string): string; virtual :=
    $'{self.GetType}(.ToString(*vn) not found)';
    
  end;
  OptNExprBase = abstract class(OptExprBase)
    
    public res: real;
    
    public function GetRes: object; override := res;
    
    public function GetResType: System.Type; override := typeof(real);
    
  end;
  OptSExprBase = abstract class(OptExprBase)
    
    public res: string;
    
    public function GetRes: object; override := res;
    
    public function GetResType: System.Type; override := typeof(string);
    
  end;
  OptOExprBase = abstract class(OptExprBase)
    
    public res: object;
    
    public function GetRes: object; override := res;
    
    public function GetResType: System.Type; override := typeof(object);
    
  end;
  
  IOptSimpleExpr=interface(IOptExpr) end;
  
  {$endregion Base}
  
  {$region Literal}
  
  IOptLiteralExpr = interface(IOptSimpleExpr)
    
  end;
  OptNLiteralExpr = sealed class(OptNExprBase, IOptLiteralExpr)
    
    public constructor(val: real) :=
    self.res := val;
    
    public function Copy: OptExprBase; override :=
    new OptNLiteralExpr(self.res);
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is OptNLiteralExpr(var noe)) and (noe.res=self.res);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override :=
    res.ToString(nfi);
    
  end;
  OptSLiteralExpr = sealed class(OptSExprBase, IOptLiteralExpr)
    
    public constructor(val: string) :=
    self.res := val;
    
    public function Copy: OptExprBase; override :=
    new OptSLiteralExpr(self.res);
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is OptSLiteralExpr(var noe)) and (noe.res=self.res);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(byte(2));
      bw.Write(res);
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    
  end;
  OptNullLiteralExpr = sealed class(OptOExprBase, IOptLiteralExpr)
    
    public constructor :=
    self.res := nil;
    
    public function Copy: OptExprBase; override :=
    new OptNullLiteralExpr;
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is OptNullLiteralExpr);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(byte(3));
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override :=
    'null';
    
  end;
  
  {$endregion Literal}
  
  {$region Plus}
  
  IOptPlusExpr = interface(IOptExpr)
    
    function GetPositive: sequence of OptExprBase;
    function GetNegative: sequence of OptExprBase;
    
  end;
  OptNNPlusExpr = sealed class(OptNExprBase, IOptPlusExpr)
    
    public Positive := new List<OptNExprBase>;
    public Negative := new List<OptNExprBase>;
    
    public procedure Calc;
    begin
      res := 0;
      
      for var i := 0 to Positive.Count-1 do
        res += Positive[i].res;
      
      for var i := 0 to Negative.Count-1 do
        res -= Negative[i].res;
      
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var nPositive := Positive.ConvertAll(oe->
      begin
        Result := f(oe) as OptNExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      var nNegative := Negative.ConvertAll(oe->
      begin
        Result := f(oe) as OptNExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      if need_copy then
      begin
        var res := new OptNNPlusExpr;
        res.Positive := nPositive;
        res.Negative := nNegative;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public constructor(Positive: List<OptNExprBase>; Negative: List<OptNExprBase>);
    begin
      self.Positive := Positive;
      self.Negative := Negative;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptNNPlusExpr(self.Positive.ConvertAll(oe->OptNExprBase(oe.Copy)), self.Negative.ConvertAll(oe->OptNExprBase(oe.Copy)));
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive.Cast&<OptExprBase>;
    public function GetNegative: sequence of OptExprBase := Negative.Cast&<OptExprBase>;
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptNNPlusExpr;
      
      var res1: OptNNPlusExpr;
      if res0.Positive.Concat(res0.Negative).Any(oe->oe is IOptPlusExpr) then
      begin
        res1 := new OptNNPlusExpr;
        
        foreach var oe in res0.Positive do
          if oe is OptNNPlusExpr(var onnp) then
          begin
            res1.Positive.AddRange(onnp.Positive);
            res1.Negative.AddRange(onnp.Negative);
          end else
            res1.Positive.Add(oe);
        
        foreach var oe in res0.Negative do
          if oe is OptNNPlusExpr(var onnp) then
          begin
            res1.Negative.AddRange(onnp.Positive);
            res1.Positive.AddRange(onnp.Negative);
          end else
            res1.Negative.Add(oe);
        
      end else
        res1 := res0;
      
      res1.Positive.RemoveAll(oe->(oe is IOptLiteralExpr) and (oe.res = 0.0));
      res1.Negative.RemoveAll(oe->(oe is IOptLiteralExpr) and (oe.res = 0.0));
      
      if (res1.Positive.Count=1) and (res1.Negative.Count=0) then
      begin
        Result := res1.Positive[0];
        exit;
      end;
      
      var plc :=  res1.Positive.Count(oe->oe is IOptLiteralExpr);
      var nlc :=  res1.Negative.Count(oe->oe is IOptLiteralExpr);
      
      if (plc = res1.Positive.Count) and (nlc = res1.Negative.Count) then
      begin
        var res := new OptNLiteralExpr;
        foreach var p in res1.Positive do
          res.res += p.res;
        foreach var n in res1.Negative do
          res.res -= n.res;
        Result := res;
      end else
      if (plc<2) and (nlc=0) then
        Result := res1 else
      begin
        var res := new OptNNPlusExpr;
        var n: real := 0.0;
        
        foreach var oe in res1.Positive do
          if oe is IOptLiteralExpr then
            n += oe.res else
            res.Positive.Add(oe);
        
        foreach var oe in res1.Negative do
          if oe is IOptLiteralExpr then
            n -= oe.res else
            res.Negative.Add(oe);
        
        if n <> 0 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
    end;
    
    public procedure ClampLists; override;
    begin
      
      Positive.Capacity := Positive.Count;
      Negative.Capacity := Negative.Count;
      
      foreach var oe in Positive do oe.ClampLists;
      foreach var oe in Negative do oe.ClampLists;
    end;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_N then raise new ConflictingExprTypesException(nil,nil);
      ExecuteOnEverySubExpr(oe->oe.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, true,false, NumChecks,StrChecks));
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptNNPlusExpr;
      if noe=nil then exit;
      
      if noe.Positive.Count<>self.Positive.Count then exit;
      if noe.Negative.Count<>self.Negative.Count then exit;
      
      Result :=
        noe.Positive.ZipTuple(self.Positive).All(t->t[0].IsSame(t[1])) and
        noe.Negative.ZipTuple(self.Negative).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        yield sequence oe.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      bw.Write(byte(1));
      
      bw.Write(Positive.Count);
      foreach var oe in Positive do
        oe.Save(bw);
      
      bw.Write(Negative.Count);
      foreach var oe in Negative do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      loop br.ReadInt32 do
        Positive.Add(OptNExprBase(OptExprBase.Load(br, nv, sv, ov)));
      
      loop br.ReadInt32 do
        Negative.Add(OptNExprBase(OptExprBase.Load(br, nv, sv, ov)));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      sb += '(';
      
      if Positive.Count<>0 then
      begin
        sb += Positive[0].ToString(nvn, svn, ovn);
        for var i := 1 to Positive.Count-1 do
        begin
          sb += '+';
          sb += Positive[i].ToString(nvn, svn, ovn);
        end;
      end;
      
      for var i := 0 to Negative.Count-1 do
      begin
        sb += '-';
        sb += Negative[i].ToString(nvn, svn, ovn);
      end;
      
      sb += ')';
      Result := sb.ToString;
    end;
    
  end;
  OptSSPlusExpr = sealed class(OptSExprBase, IOptPlusExpr)
    
    public Positive := new List<OptSExprBase>;
    
    private procedure Calc;
    begin
      res := '';
      
      for var i := 0 to Positive.Count-1 do
        res += Positive[i].res;
      
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var nPositive := Positive.ConvertAll(oe->
      begin
        Result := f(oe) as OptSExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      if need_copy then
      begin
        var res := new OptSSPlusExpr;
        res.Positive := nPositive;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public constructor(Positive: List<OptSExprBase>);
    begin
      self.Positive := Positive;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptSSPlusExpr(self.Positive.ConvertAll(oe->OptSExprBase(oe.Copy)));
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive.Cast&<OptExprBase>;
    public function GetNegative: sequence of OptExprBase := new OptExprBase[0];
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptSSPlusExpr;
      
      var res1: OptSSPlusExpr;
      if res0.Positive.Any(oe->oe is IOptPlusExpr) then
      begin
        res1 := new OptSSPlusExpr;
        
        foreach var oe in res0.Positive do
          if (oe is OptSExprBase) and (oe is IOptPlusExpr(var ope)) then
            res1.Positive.AddRange(ope.GetPositive.Select(oe->AsStrExpr(oe))) else
            res1.Positive.Add(oe);
        
      end else
        res1 := res0;
      
      res1.Positive.RemoveAll(oe->(oe is IOptLiteralExpr) and (oe.res = ''));
      
      if res1.Positive.Count=1 then
      begin
        Result := res1.Positive[0];
        exit;
      end;
      
      var lc := res1.Positive.Count(oe->oe is IOptLiteralExpr);
      
      if lc = res1.Positive.Count then
      begin
        var sb := new StringBuilder;
        foreach var oe in res1.Positive do
          sb += oe.res;
        Result := new OptSLiteralExpr(sb.ToString);
      end else
      if lc < 2 then
        Result := res1 else
      begin
        var res := new OptSSPlusExpr;
        
        var sb := new StringBuilder;
        var ig := false;
        foreach var oe in res1.Positive do
          if oe is IOptLiteralExpr then
          begin
            ig := true;
            sb += (oe as OptSLiteralExpr).res;
          end else
          begin
            if ig then
            begin
              ig := false;
              if sb.Length <> 0 then res.Positive.Add(new OptSLiteralExpr(sb.ToString));
              sb.Clear;
            end;
            
            res.Positive.Add(oe);
          end;
        
        if ig then
        begin
          //ig := false;
          if sb.Length <> 0 then res.Positive.Add(new OptSLiteralExpr(sb.ToString));
          sb.Clear;
        end;
        
        Result := res;
      end;
      
    end;
    
    public procedure ClampLists; override;
    begin
      
      Positive.Capacity := Positive.Count;
      
      foreach var oe in Positive do oe.ClampLists;
    end;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_S then raise new ConflictingExprTypesException(nil,nil);
      ExecuteOnEverySubExpr(oe->oe.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, false,true, NumChecks,StrChecks));
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptSSPlusExpr;
      if noe=nil then exit;
      
      if noe.Positive.Count<>self.Positive.Count then exit;
      
      Result :=
        noe.Positive.ZipTuple(self.Positive).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      foreach var oe in Positive do
        yield sequence oe.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      bw.Write(byte(2));
      
      bw.Write(Positive.Count);
      foreach var oe in Positive do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      loop br.ReadInt32 do
        Positive.Add(OptSExprBase(OptExprBase.Load(br, nv, sv, ov)));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      sb += '(';
      
      if Positive.Count<>0 then
      begin
        sb += Positive[0].ToString(nvn, svn, ovn);
        for var i := 1 to Positive.Count-1 do
        begin
          sb += '+';
          sb += Positive[i].ToString(nvn, svn, ovn);
        end;
      end;
      
      sb += ')';
      Result := sb.ToString;
    end;
    
  end;
  OptOPlusExpr = sealed class(OptOExprBase, IOptPlusExpr)
    
    public Positive := new List<OptExprBase>;
    public Negative := new List<OptExprBase>;
    
    private procedure Calc;
    begin
      if Positive.Concat(Negative).Any(oe->oe.GetRes is string) then
      begin
        if Negative.Any then raise new CannotSubStringExprException(self, Negative);
        var sb := new StringBuilder;
        
        for var i := 0 to Positive.Count-1 do
          sb += ObjToStr(Positive[i].GetRes);
        
        res := sb.ToString;
      end else
      begin
        var nres: real := 0;
        
        foreach var oe in Positive do
          nres += ObjToNumUnsafe(oe.GetRes);
        
        foreach var oe in Negative do
          nres -= ObjToNumUnsafe(oe.GetRes);
        
        res := nres;
      end;
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var nPositive := Positive.ConvertAll(oe->
      begin
        Result := f(oe) as OptExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      var nNegative := Negative.ConvertAll(oe->
      begin
        Result := f(oe) as OptExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      if need_copy then
      begin
        var res := new OptOPlusExpr;
        res.Positive := nPositive;
        res.Negative := nNegative;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public constructor(Positive: List<OptExprBase>; Negative: List<OptExprBase>);
    begin
      self.Positive := Positive;
      self.Negative := Negative;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptOPlusExpr(self.Positive.ConvertAll(oe->oe.Copy), self.Negative.ConvertAll(oe->oe.Copy));
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive;
    public function GetNegative: sequence of OptExprBase := Negative;
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res1 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptOPlusExpr;
      if res1.Negative.Any(oe->oe is OptSExprBase) then raise new CannotSubStringExprException(nil, nil);
      
      res1.Positive.RemoveAll(oe->oe is OptNullLiteralExpr);
      
      if (res1.Positive.Count=1) and (res1.Negative.Count=0) then
      begin
        Result := res1.Positive[0];
        exit;
      end;
      
      if res1.Positive.Any(oe->oe is OptSExprBase) then
      begin
        if res1.Negative.Any then raise new CannotSubStringExprException(nil, nil);
        
        var res := new OptSSPlusExpr;
        res.Positive := res1.Positive.ConvertAll(AsStrExpr);
        Result := res.Optimize(nvn, svn, ovn);
      end else
      if res1.Positive.Concat(res1.Negative).All(oe->(oe is OptNExprBase) or (oe is OptNullLiteralExpr)) then
      begin
        var res := new OptNNPlusExpr;
        res.Positive := res1.Positive.ConvertAll(oe->AsDefinitelyNumExpr(oe));
        res.Negative := res1.Negative.ConvertAll(oe->AsDefinitelyNumExpr(oe));
        Result := res.Optimize(nvn, svn, ovn);
      end else
        Result := res1;//Даже если есть несколько констант подряд - их нельзя складывать, потому что числа и строки по разному складываются
      
    end;
    
    public procedure ClampLists; override;
    begin
      
      Positive.Capacity := Positive.Count;
      Negative.Capacity := Negative.Count;
      
      foreach var oe in Positive do oe.ClampLists;
      foreach var oe in Negative do oe.ClampLists;
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptOPlusExpr;
      if noe=nil then exit;
      
      if noe.Positive.Count<>self.Positive.Count then exit;
      if noe.Negative.Count<>self.Negative.Count then exit;
      
      Result :=
        noe.Positive.ZipTuple(self.Positive).All(t->t[0].IsSame(t[1])) and
        noe.Negative.ZipTuple(self.Negative).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        yield sequence oe.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      bw.Write(byte(4));
      
      bw.Write(Positive.Count);
      foreach var oe in Positive do
        oe.Save(bw);
      
      bw.Write(Negative.Count);
      foreach var oe in Negative do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      loop br.ReadInt32 do
        Positive.Add(OptExprBase.Load(br, nv, sv, ov));
      
      loop br.ReadInt32 do
        Negative.Add(OptExprBase.Load(br, nv, sv, ov));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      sb += '(';
      
      if Positive.Count<>0 then
      begin
        sb += Positive[0].ToString(nvn, svn, ovn);
        for var i := 1 to Positive.Count-1 do
        begin
          sb += '+';
          sb += Positive[i].ToString(nvn, svn, ovn);
        end;
      end;
      
      for var i := 0 to Negative.Count-1 do
      begin
        sb += '-';
        sb += Negative[i].ToString(nvn, svn, ovn);
      end;
      
      sb += ')';
      Result := sb.ToString;
    end;
    
  end;
  
  {$endregion Plus}
  
  {$region Mlt}
  
  IOptMltExpr = interface(IOptExpr)
    
    function AnyNegative: boolean;
    
    function GetPositive: sequence of OptExprBase;
    function GetNegative: sequence of OptExprBase;
    
  end;
  OptNNMltExpr = sealed class(OptNExprBase, IOptMltExpr)
    
    public Positive := new List<OptNExprBase>;
    public Negative := new List<OptNExprBase>;
    
    private procedure Calc;
    begin
      res := 1.0;
      
      for var i := 0 to Positive.Count-1 do
        res *= Positive[i].res;
      
      for var i := 0 to Negative.Count-1 do
        res /= Negative[i].res;
      
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var nPositive := Positive.ConvertAll(oe->
      begin
        Result := f(oe) as OptNExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      var nNegative := Negative.ConvertAll(oe->
      begin
        Result := f(oe) as OptNExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      if need_copy then
      begin
        var res := new OptNNMltExpr;
        res.Positive := nPositive;
        res.Negative := nNegative;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public constructor(Positive: List<OptNExprBase>; Negative: List<OptNExprBase>);
    begin
      self.Positive := Positive;
      self.Negative := Negative;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptNNMltExpr(self.Positive.ConvertAll(oe->OptNExprBase(oe.Copy)), self.Negative.ConvertAll(oe->OptNExprBase(oe.Copy)));
    
    
    
    public function AnyNegative := Negative.Any;
    
    function GetPositive: sequence of OptExprBase := Positive.Select(oe->oe as OptExprBase);
    function GetNegative: sequence of OptExprBase := Negative.Select(oe->oe as OptExprBase);
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptNNMltExpr;
      
      var res1 := new OptNNMltExpr;
      if res0.Positive.Concat(res0.Negative).Any(oe->oe is IOptMltExpr) then
      begin
        res1 := new OptNNMltExpr;
        
        foreach var oe in res0.Positive do
          if oe is IOptMltExpr(var ome) then
          begin
            res1.Positive.AddRange(ome.GetPositive.Select(oe->OptExprBase.AsDefinitelyNumExpr(oe).Optimize(nvn, svn, ovn) as OptNExprBase));
            res1.Negative.AddRange(ome.GetNegative.Select(oe->OptExprBase.AsDefinitelyNumExpr(oe).Optimize(nvn, svn, ovn) as OptNExprBase));
          end else
            res1.Positive.Add(oe);
        
        foreach var oe in res0.Negative do
          if oe is IOptMltExpr(var ome) then
          begin
            res1.Negative.AddRange(ome.GetPositive.Select(oe->OptExprBase.AsDefinitelyNumExpr(oe).Optimize(nvn, svn, ovn) as OptNExprBase));
            res1.Positive.AddRange(ome.GetNegative.Select(oe->OptExprBase.AsDefinitelyNumExpr(oe).Optimize(nvn, svn, ovn) as OptNExprBase));
          end else
            res1.Negative.Add(oe);
        
      end else
        res1 := res0;
      
      res1.Positive.RemoveAll(oe->(oe is IOptLiteralExpr) and (oe.res = 1.0));
      res1.Negative.RemoveAll(oe->(oe is IOptLiteralExpr) and (oe.res = 1.0));
      
      if (res1.Positive.Count=1) and (res1.Negative.Count=0) then
      begin
        Result := res1.Positive[0];
        exit;
      end;
      
      var plc := res1.Positive.Count(oe->oe is IOptLiteralExpr);
      var nlc := res1.Negative.Count(oe->oe is IOptLiteralExpr);
      
      if (plc = Positive.Count) and (nlc = Negative.Count) then
      begin
        var res := new OptNLiteralExpr(1.0);
        
        foreach var oe in res1.Positive do
          res.res *= oe.res;
        
        foreach var oe in res1.Negative do
          res.res /= oe.res;
        
        Result := res;
      end else
      if (plc < 2) and (nlc = 0) then
        Result := res1 else
      begin
        var res := new OptNNMltExpr;
        var n := 1.0;
        
        foreach var oe in res1.Positive do
          if oe is IOptLiteralExpr then
            n *= oe.res else
            res.Positive.Add(oe);
        
        foreach var oe in res1.Negative do
          if oe is IOptLiteralExpr then
            n /= oe.res else
            res.Negative.Add(oe);
        
        if n <> 1.0 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
    end;
    
    public procedure ClampLists; override;
    begin
      
      Positive.Capacity := Positive.Count;
      Negative.Capacity := Negative.Count;
      
      foreach var oe in Positive do oe.ClampLists;
      foreach var oe in Negative do oe.ClampLists;
    end;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_N then raise new ConflictingExprTypesException(nil,nil);
      ExecuteOnEverySubExpr(oe->oe.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, true,false, NumChecks,StrChecks));
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptNNMltExpr;
      if noe=nil then exit;
      
      if noe.Positive.Count<>self.Positive.Count then exit;
      if noe.Negative.Count<>self.Negative.Count then exit;
      
      Result :=
        noe.Positive.ZipTuple(self.Positive).All(t->t[0].IsSame(t[1])) and
        noe.Negative.ZipTuple(self.Negative).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        yield sequence oe.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(3));
      bw.Write(byte(1));
      
      bw.Write(Positive.Count);
      foreach var oe in Positive do
        oe.Save(bw);
      
      bw.Write(Negative.Count);
      foreach var oe in Negative do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      loop br.ReadInt32 do
        Positive.Add(OptNExprBase(OptExprBase.Load(br, nv, sv, ov)));
      
      loop br.ReadInt32 do
        Negative.Add(OptNExprBase(OptExprBase.Load(br, nv, sv, ov)));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      sb += '(';
      
      if Positive.Count<>0 then
      begin
        sb += Positive[0].ToString(nvn, svn, ovn);
        for var i := 1 to Positive.Count-1 do
        begin
          sb += '*';
          sb += Positive[i].ToString(nvn, svn, ovn);
        end;
      end else
        sb += '1';
      
      for var i := 0 to Negative.Count-1 do
      begin
        sb += '/';
        sb += Negative[i].ToString(nvn, svn, ovn);
      end;
      
      sb += ')';
      Result := sb.ToString;
    end;
    
  end;
  OptSNMltExpr = sealed class(OptSExprBase, IOptMltExpr)
    
    public Base: OptSExprBase;
    public Positive: OptNExprBase;
    
    private procedure Calc;
    begin
      var r := Base.res;
      var cr := Positive.res;
      if real.IsNaN(cr) or real.IsInfinity(cr) then raise new CannotConvertToIntException(self, cr);
      var ci := BigInteger.Create(cr+0.5);
      if ci < 0 then raise new CanNotMltNegStringException(self, ci);
      var cap := ci * r.Length;
      if cap > integer.MaxValue then raise new TooBigStringException(self, cap);
      var sb := new StringBuilder(integer(cap));
      loop integer(ci) do sb += r;
      res := sb.ToString;
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      
      var nBase := f(Base) as OptSExprBase;
      var nPositive := f(Positive) as OptNExprBase;
      
      if (Base=nBase) and (Positive=nPositive) then
        Result := self else
      begin
        var res := new OptSNMltExpr;
        res.Base := nBase;
        res.Positive := nPositive;
        Result := res;
      end;
      
    end;
    
    public constructor(Base: OptSExprBase; Positive: OptNExprBase);
    begin
      self.Base := Base;
      self.Positive := Positive;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptSNMltExpr(OptSExprBase(self.Base.Copy), OptNExprBase(self.Positive.Copy));
    
    
    
    public function AnyNegative := false;
    
    function GetPositive: sequence of OptExprBase := new OptExprBase[](Base, Positive);
    function GetNegative: sequence of OptExprBase := new OptExprBase[0];
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptSNMltExpr;
      
      var res1: OptSNMltExpr;
      if res0.Base is IOptMltExpr(var ome) then
      begin
        res1 := new OptSNMltExpr;
        var p := new OptNNMltExpr;
        
        foreach var oe in ome.GetPositive do
          if oe is OptSExprBase then
          begin
            if res1.Base = nil then
              res1.Base := oe as OptSExprBase else
              
              //-------- //ToDo #1418
              //raise new CannotMltALotStringsException(self, new object[](nres.Base, oe)) else
              raise new CannotMltALotStringsException(nil, new object[](nil, nil));
              //--------
              
          end else
            
            //-------- //ToDo #1418
            //p.Positive.Add(AsDefinitelyNumExpr(oe, procedure->raise new CannotMltALotStringsException(self,new object[](Base, oe))));
            p.Positive.Add(AsDefinitelyNumExpr(oe, procedure->raise new CannotMltALotStringsException(nil,new object[](nil, nil))));
            //--------
        
        if res0.Positive is OptNNMltExpr(var onme) then
        begin
          p.Positive.AddRange(onme.Positive);
          p.Negative.AddRange(onme.Negative);
        end else
          p.Positive.Add(res0.Positive);
        
        res1.Positive := p;
      end else
        res1 := res0;
      
      if
        (res1.Base is IOptLiteralExpr) and
        (res1.Positive is IOptLiteralExpr)
      then
      begin
        var r := res1.Base.res;
        var cr := res1.Positive.res;
        if real.IsNaN(cr) or real.IsInfinity(cr) then raise new CannotConvertToIntException(self, cr);
        var ci := BigInteger.Create(cr+0.5);
        if ci < 0 then raise new CanNotMltNegStringException(self, ci);
        var cap := ci * r.Length;
        if cap > integer.MaxValue then raise new TooBigStringException(self, cap);
        var sb := new StringBuilder(integer(cap));
        loop integer(ci) do sb += r;
        Result := new OptSLiteralExpr(sb.ToString);
      end else
      if (res1.Positive is IOptLiteralExpr) and (res1.Positive.res = 1.0) then
        Result := res1.Base else
        Result := res1;
    end;
    
    public procedure ClampLists; override;
    begin
      Base.ClampLists;
      Positive.ClampLists;
    end;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_S then raise new ConflictingExprTypesException(nil,nil);
      Base    .DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, false,true, NumChecks,StrChecks);
      Positive.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, true,false, NumChecks,StrChecks);
      ExecuteOnEverySubExpr(oe->oe.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, true,false, NumChecks,StrChecks));
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptSNMltExpr;
      if noe=nil then exit;
      
      Result :=
        noe.Base.IsSame(self.Base) and
        noe.Positive.IsSame(self.Positive);
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence Base.GetCalc();
      yield sequence Positive.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(3));
      bw.Write(byte(2));
      
      Base.Save(bw);
      Positive.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      Base := OptSExprBase(OptExprBase.Load(br, nv, sv, ov));
      Positive := OptNExprBase(OptExprBase.Load(br, nv, sv, ov));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      
      sb += '(';
      sb += Base.ToString(nvn, svn, ovn);
      sb += '*';
      sb += Positive.ToString(nvn, svn, ovn);
      sb += ')';
      
      Result := sb.ToString;
    end;
    
  end;
  OptOMltExpr = sealed class(OptOExprBase, IOptMltExpr)
    
    public Positive := new List<OptExprBase>;
    public Negative := new List<OptExprBase>;
    
    private procedure Calc;
    begin
      if Positive.Concat(Negative).Any(oe->oe.GetRes is string) then
      begin
        var n := 1.0;
        var nres: string := nil;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var ro := Positive[i].GetRes;
          if ro is string then
            if nres = nil then
              nres := ro as string else
              raise new CannotMltALotStringsException(self, Positive.Select(oe->oe.GetRes).Where(r->r is string)) else
            if ro = nil then
            begin
              self.res := '';
              exit;
            end else
              n *= real(ro);
        end;
        
        for var i := 0 to Negative.Count-1 do
        begin
          var ro := Negative[i].GetRes;
          if ro is string then
            raise new CannotDivStringExprException(self, nil, nil) else
            n /= ObjToNumUnsafe(ro);
        end;
        
        if real.IsNaN(n) or real.IsInfinity(n) then raise new CannotConvertToIntException(self, n);
        var ci := BigInteger.Create(n+0.5);
        if ci < 0 then raise new CanNotMltNegStringException(self,ci);
        var cap := ci * nres.Length;
        if cap > integer.MaxValue then raise new TooBigStringException(self,cap);
        var sb := new StringBuilder(integer(cap));
        loop integer(ci) do sb += nres;
        self.res := sb.ToString;
      end else
      begin
        var nres := 1.0;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var ro := Positive[i].GetRes;
          if ro = nil then
          begin
            nres *= 0.0;
            //break;
          end else
            nres *= real(ro);
        end;
        
        for var i := 0 to Negative.Count-1 do
        begin
          var ro := Negative[i].GetRes;
          if ro = nil then
          begin
            nres /= 0.0;
            //break;
          end else
            nres /= real(ro);
        end;
        
        res := nres;
      end;
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var nPositive := Positive.ConvertAll(oe->
      begin
        Result := f(oe) as OptExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      var nNegative := Negative.ConvertAll(oe->
      begin
        Result := f(oe) as OptExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      if need_copy then
      begin
        var res := new OptOMltExpr;
        res.Positive := nPositive;
        res.Negative := nNegative;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public constructor(Positive: List<OptExprBase>; Negative: List<OptExprBase>);
    begin
      self.Positive := Positive;
      self.Negative := Negative;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptOMltExpr(self.Positive.ConvertAll(oe->oe.Copy), self.Negative.ConvertAll(oe->oe.Copy));
    
    
    
    public function AnyNegative := Negative.Any;
    
    function GetPositive: sequence of OptExprBase := Positive;
    function GetNegative: sequence of OptExprBase := Negative;
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptOMltExpr;
      
      var res1: OptOMltExpr;
      if res0.Positive.Concat(res0.Negative).Any(oe->oe is IOptMltExpr) then
      begin
        res1 := new OptOMltExpr;
        
        foreach var oe in res0.Positive do
          if oe is IOptMltExpr(var ome) then
          begin
            res1.Positive.AddRange(ome.GetPositive);
            res1.Negative.AddRange(ome.GetNegative);
          end else
            res1.Positive.Add(oe);
        
        foreach var oe in res0.Negative do
          if oe is IOptMltExpr(var ome) then
          begin
            res1.Negative.AddRange(ome.GetPositive);
            res1.Positive.AddRange(ome.GetNegative);
          end else
            res1.Negative.Add(oe);
        
      end else
        res1 := res0;
      
      res1.Positive.RemoveAll(oe->(oe is OptNLiteralExpr) and (real(oe.GetRes) = 1.0));
      res1.Negative.RemoveAll(oe->(oe is OptNLiteralExpr) and (real(oe.GetRes) = 1.0));
      
      if (res1.Positive.Count=1) and (res1.Negative.Count=0) then
      begin
        Result := res1.Positive[0];
        exit;
      end;
      
      var pn := res1.Positive.Concat(res1.Negative);
      var sc := pn.Count(oe->oe is OptSExprBase);
      if sc > 1 then raise new CannotMltALotStringsException(self, pn.Where(oe->oe is OptSExprBase));
      
      if sc = 1 then
      begin
        var res := new OptSNMltExpr;
        var rp := new OptNNMltExpr;
        
        foreach var oe in res1.Positive do
          if oe is OptSExprBase(var ose) then
            res.Base := ose else
            rp.Positive.Add(AsDefinitelyNumExpr(oe));
        
        rp.Negative.AddRange(res1.Negative.Select(oe->AsDefinitelyNumExpr(oe)));
        res.Positive := rp;
        Result := res.Optimize(nvn, svn, ovn);
      end else
      if pn.All(oe->(oe is OptNExprBase) or (oe is OptNullLiteralExpr)) then
      begin
        var res := new OptNNMltExpr;
        res.Positive := res1.Positive.ConvertAll(oe->AsDefinitelyNumExpr(oe));
        res.Negative := res1.Negative.ConvertAll(oe->AsDefinitelyNumExpr(oe));
        Result := res.Optimize(nvn, svn, ovn);
      end else
      if pn.Count(oe->oe is IOptLiteralExpr) < 2 then
        Result := res1 else
      begin
        var res := new OptOMltExpr;
        var n := 1.0;
        
        foreach var oe in res1.Positive do
          if oe is OptNLiteralExpr(var nle) then
            n *= nle.res else
          if oe is OptNullLiteralExpr then
            n *= 0.0 else
            res.Positive.Add(oe);
        
        foreach var oe in res1.Negative do
          if oe is OptNLiteralExpr(var anle) then
            n /= anle.res else
          if oe is OptNullLiteralExpr then
            n /= 0.0 else
            res.Negative.Add(oe);
        
        if n <> 1.0 then
          res.Positive.Add(new OptNLiteralExpr(n));
        
        Result := res;
      end;
      
    end;
    
    public procedure ClampLists; override;
    begin
      
      Positive.Capacity := Positive.Count;
      Negative.Capacity := Negative.Count;
      
      foreach var oe in Positive do oe.ClampLists;
      foreach var oe in Negative do oe.ClampLists;
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptOMltExpr;
      if noe=nil then exit;
      
      if noe.Positive.Count<>self.Positive.Count then exit;
      if noe.Negative.Count<>self.Negative.Count then exit;
      
      Result :=
        noe.Positive.ZipTuple(self.Positive).All(t->t[0].IsSame(t[1])) and
        noe.Negative.ZipTuple(self.Negative).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        yield sequence oe.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(3));
      bw.Write(byte(4));
      
      bw.Write(Positive.Count);
      foreach var oe in Positive do
        oe.Save(bw);
      
      bw.Write(Negative.Count);
      foreach var oe in Negative do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      loop br.ReadInt32 do
        Positive.Add(OptExprBase.Load(br, nv, sv, ov));
      
      loop br.ReadInt32 do
        Negative.Add(OptExprBase.Load(br, nv, sv, ov));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      sb += '(';
      
      if Positive.Count<>0 then
      begin
        sb += Positive[0].ToString(nvn, svn, ovn);
        for var i := 1 to Positive.Count-1 do
        begin
          sb += '*';
          sb += Positive[i].ToString(nvn, svn, ovn);
        end;
      end else
        sb += '1';
      
      for var i := 0 to Negative.Count-1 do
      begin
        sb += '/';
        sb += Negative[i].ToString(nvn, svn, ovn);
      end;
      
      sb += ')';
      Result := sb.ToString;
    end;
    
  end;
  
  {$endregion Mlt}
  
  {$region Pow}
  
  IOptPowExpr = interface(IOptExpr)
    
    function GetPositive: sequence of OptExprBase;
    
  end;
  OptNPowExpr = sealed class(OptNExprBase, IOptPowExpr)
    
    public Positive := new List<OptNExprBase>;
    
    private procedure Calc;
    begin
      res := Positive[0].res;
      
      for var i := 1 to Positive.Count-1 do
        res := res ** Positive[i].res;
      
    end;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var nPositive := Positive.ConvertAll(oe->
      begin
        Result := f(oe) as OptNExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      if need_copy then
      begin
        var res := new OptNPowExpr;
        res.Positive := nPositive;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public constructor(Positive: List<OptNExprBase>);
    begin
      self.Positive := Positive;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptNPowExpr(self.Positive.ConvertAll(oe->OptNExprBase(oe.Copy)));
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive.Select(oe->oe as OptExprBase);
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptNPowExpr;
      
      var res1: OptNPowExpr;
      if res0.Positive[0] is IOptPowExpr(var ope) then
      begin
        res1 := new OptNPowExpr;
        
        foreach var oe in ope.GetPositive do
          res1.Positive.Add(AsDefinitelyNumExpr(oe).Optimize(nvn, svn, ovn) as OptNExprBase);
        
        res1.Positive.AddRange(res0.Positive.Skip(1));
      end else
        res1 := res0;
      
      res1.Positive.RemoveAll(oe->(oe <> Positive[0]) and (oe is OptNLiteralExpr) and (oe.res = 1.0));
      
      if res1.Positive.Count=1 then
      begin
        Result := res1.Positive[0];
        exit;
      end;
      
      var lc := res1.Positive.Count(oe->oe is IOptLiteralExpr);
      
      if lc = res1.Positive.Count then
      begin
        var res := res1.Positive[0].res;
        
        foreach var oe in res1.Positive.Skip(1) do
          res := res ** oe.res;
        
        Result := new OptNLiteralExpr(res);
      end else
      if lc < 2 then
        Result := res1 else
      if res1.Positive[0] is OptNLiteralExpr(var rb) then
      begin
        var res := new OptNPowExpr;
        res.Positive.Add(rb);
        
        foreach var oe in res1.Positive.Skip(1) do
          if oe is IOptLiteralExpr then
            rb.res := rb.res ** oe.res else
            res.Positive.Add(oe);
        
        Result := res;
      end else
      begin
        var res := new OptNPowExpr;
        var n := 1.0;
        
        res.Positive.Add(res1.Positive[0]);
        foreach var oe in res1.Positive.Skip(1) do
          if (oe is IOptLiteralExpr) and not real.IsInfinity(oe.res) then
            n *= oe.res else
            res.Positive.Add(oe);
        
        if n <> 1.0 then res.Positive.Add(new OptNLiteralExpr(n));
        if res.Positive.Count=1 then
          Result := res.Positive[0] else
          Result := res;
      end;
    end;
    
    public procedure ClampLists; override;
    begin
      
      Positive.Capacity := Positive.Count;
      
      foreach var oe in Positive do oe.ClampLists;
    end;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_N then raise new ConflictingExprTypesException(nil,nil);
      ExecuteOnEverySubExpr(oe->oe.DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, true,false, NumChecks,StrChecks));
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptNPowExpr;
      if noe=nil then exit;
      
      if noe.Positive.Count<>self.Positive.Count then exit;
      
      Result :=
        noe.Positive.ZipTuple(self.Positive).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override;
    begin
      foreach var oe in Positive do
        yield sequence oe.GetCalc();
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(4));
      bw.Write(byte(1));
      
      bw.Write(Positive.Count);
      foreach var oe in Positive do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      loop br.ReadInt32 do
        Positive.Add(OptNExprBase(OptExprBase.Load(br, nv, sv, ov)));
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      sb += '(';
      
      sb += Positive[0].ToString(nvn, svn, ovn);
      for var i := 1 to Positive.Count-1 do
      begin
        sb += '^';
        sb += Positive[i].ToString(nvn, svn, ovn);
      end;
      
      sb += ')';
      Result := sb.ToString;
    end;
    
  end;
  
  {$endregion Pow}
  
  {$region Func}
  
  IOptFuncExpr = interface(IOptExpr)
    
    procedure CheckParams;
    
  end;
  OptNFuncExpr = abstract class(OptNExprBase, IOptFuncExpr)
    
    public name: string;
    public par: array of OptExprBase;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var npar := par.ConvertAll(oe->
      begin
        Result := f(oe) as OptExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      Result := need_copy?self.GetNewInst(npar):self;
      
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; abstract;
    
    public function Copy: OptExprBase; override :=
    OptExprBase(GetNewInst(self.par.ConvertAll(oe->oe.Copy)));
    
    
    
    public function GetTps: array of System.Type; abstract;
    
    protected procedure CheckParamsBase;
    begin
      var tps := GetTps;
      if par.Length <> tps.Length then raise new InvalidFuncParamCountException(self, self.name, tps.Length, par.Length);
      
      for var i := 0 to tps.Length-1 do
        if (par[i].GetResType <> tps[i]) and (par[i].GetResType <> typeof(Object)) then
          raise new InvalidFuncParamTypesException(self, self.name, i, tps[i], par[i].GetResType);
    end;
    
    public procedure CheckParams; abstract;
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptNFuncExpr;
      CheckParams;
      if res0.par.All(oe->oe is IOptLiteralExpr) then
      begin
        
        foreach var p in res0.GetCalc() do
          p();
        
        Result := new OptNLiteralExpr(res0.res);
      end else
        Result := res0;
    end;
    
    public procedure ClampLists; override :=
    foreach var oe in par do oe.ClampLists;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_N then raise new ConflictingExprTypesException(nil,nil);
      var tps := self.GetTps;
      for var i := 0 to tps.Length-1 do
        par[i].DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, tps[i]<>typeof(string),tps[i]<>typeof(real), NumChecks,StrChecks);
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptNFuncExpr;
      if noe=nil then exit;
      
      if noe.par.Length<>self.par.Length then exit;
      
      Result :=
        noe.par.ZipTuple(self.par).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override :=
    par.SelectMany(p->p.GetCalc());
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      
      bw.Write(par.Count);
      foreach var oe in par do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; name: string; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      self.name := name;
      
      par := new OptExprBase[br.ReadInt32];
      for var i := 0 to par.Length-1 do
        par[i] := OptExprBase.Load(br, nv, sv, ov);
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      
      sb += name;
      sb += '(';
      sb += par[0].ToString(nvn, svn, ovn);
      for var i := 1 to par.Length-1 do
      begin
        sb += ',';
        sb += par[i].ToString(nvn, svn, ovn);
      end;
      sb += ')';
      
      Result := sb.ToString;
    end;
    
  end;
  OptSFuncExpr = abstract class(OptSExprBase, IOptFuncExpr)
    
    public name: string;
    public par: array of OptExprBase;
    
    protected function TransformAllSubExprs(f: IOptExpr->IOptExpr): IOptExpr; override;
    begin
      var need_copy := false;
      
      var npar := par.ConvertAll(oe->
      begin
        Result := f(oe) as OptExprBase;
        if oe<>Result then
          need_copy := true;
      end);
      
      Result := need_copy?self.GetNewInst(npar):self;
      
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; abstract;
    
    public function Copy: OptExprBase; override :=
    GetNewInst(self.par.ConvertAll(oe->oe.Copy)) as OptExprBase;
    
    
    
    public function GetTps: array of System.Type; abstract;
    
    protected procedure CheckParamsBase;
    begin
      var tps := GetTps;
      if par.Length <> tps.Length then raise new InvalidFuncParamCountException(self, self.name, tps.Length, par.Length);
      
      for var i := 0 to tps.Length-1 do
        if (par[i].GetResType <> tps[i]) and (par[i].GetResType <> typeof(Object)) then
          raise new InvalidFuncParamTypesException(self, self.name, i, tps[i], par[i].GetResType);
    end;
    
    public procedure CheckParams; abstract;
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      var res0 := TransformAllSubExprs(oe->oe.Optimize(nvn, svn, ovn)) as OptSFuncExpr;
      CheckParams;
      if res0.par.All(oe->oe is IOptLiteralExpr) then
      begin
        foreach var p in res0.GetCalc() do
          p();
        
        Result := new OptSLiteralExpr(res0.res);
      end else
        Result := res0;
    end;
    
    public procedure ClampLists; override :=
    foreach var oe in par do oe.ClampLists;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks,StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      if not CB_S then raise new ConflictingExprTypesException(nil,nil);
      var tps := self.GetTps;
      for var i := 0 to tps.Length-1 do
        par[i].DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn, tps[i]<>typeof(string),tps[i]<>typeof(real), NumChecks,StrChecks);
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override;
    begin
      var noe := oe as OptSFuncExpr;
      if noe=nil then exit;
      
      if noe.par.Length<>self.par.Length then exit;
      
      Result :=
        noe.par.ZipTuple(self.par).All(t->t[0].IsSame(t[1]));
      
    end;
    
    public function GetCalc: sequence of Action0; override :=
    par.SelectMany(p->p.GetCalc());
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      
      bw.Write(par.Count);
      foreach var oe in par do
        oe.Save(bw);
      
    end;
    
    public constructor(br: System.IO.BinaryReader; name: string; nv: array of real; sv: array of string; ov: array of object);
    begin
      
      self.name := name;
      
      par := new OptExprBase[br.ReadInt32];
      for var i := 0 to par.Length-1 do
        par[i] := OptExprBase.Load(br, nv, sv, ov);
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override;
    begin
      var sb := new StringBuilder;
      
      sb += name;
      sb += '(';
      sb += par[0].ToString(nvn, svn, ovn);
      for var i := 1 to par.Length-1 do
      begin
        sb += ',';
        sb += par[i].ToString(nvn, svn, ovn);
      end;
      sb += ')';
      
      Result := sb.ToString;
    end;
    
  end;
  
  {$endregion Func}
  
  {$region Var}
  
  IOptVarExpr = interface(IOptSimpleExpr)
    
  end;
  UnOptVarExpr = sealed class(OptOExprBase, IOptVarExpr)
    
    public name: string;
    
    public constructor(name: string) :=
    self.name := name;
    
    public function Copy: OptExprBase; override :=
    new UnOptVarExpr(name);
    
    
    
    public function FixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr; override;
    
    public function FinalFixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr; override;
    
    public function ReplaceVar(vn: string; oe: OptExprBase): IOptExpr; override :=
    vn=name?oe:self;
    
    public procedure DeduseVarsTypes(anvn,asvn,aovn, gnvn,gsvn,govn, lnvn,lsvn,lovn: HashSet<string>; CB_N, CB_S: boolean; NumChecks, StrChecks: Dictionary<string, ExprContextArea>); override;
    begin
      //a_ = all,    все которые надо разрешать (FinnalOptimize так удаляет неиспользуемое), изменяется так же как g_
      //g_ = global, ориентир исключений, новые элементы не добавляются, могут только перейти в [n,s]vn если было в ovn
      //l_ = local,  подсчёт локальных переменных которые сейчас ищутся, работает как возвращаемое значение
      
      if anvn.Contains(name) or (aovn.Contains(name) and not CB_S) then
      begin
        if not CB_N then raise new ConflictingExprTypesException(nil, nil);
        if asvn.Contains(name) or gsvn.Contains(name) or lsvn.Contains(name) then raise new ConflictingExprTypesException(nil, nil);
        if aovn.Contains(name) and not NumChecks.ContainsKey(name) then NumChecks[name] := nil; //ToDo
        
        lovn.Remove(name); lnvn.Add(name);
        if aovn.Remove(name) then anvn.Add(name);
        if (govn=nil) or govn.Remove(name) then gnvn.Add(name);
        
      end else
      if asvn.Contains(name) or (aovn.Contains(name) and not CB_N) then
      begin
        if not CB_S then raise new ConflictingExprTypesException(nil, nil);
        if anvn.Contains(name) or gnvn.Contains(name) or lnvn.Contains(name) then raise new ConflictingExprTypesException(nil, nil);
        if aovn.Contains(name) and not StrChecks.ContainsKey(name) then StrChecks[name] := nil; //ToDo
        
        lovn.Remove(name); lsvn.Add(name);
        if aovn.Remove(name) then asvn.Add(name);
        if (govn=nil) or govn.Remove(name) then gsvn.Add(name);
        
      end else
      if aovn.Contains(name) then
      begin
        
        if not(
          lnvn.Contains(name) or
          lsvn.Contains(name)
        ) then lovn.Add(name);
        
      end;
      
    end;
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is UnOptVarExpr(var noe)) and (noe.name=self.name);
    
    public function ToString(nvn, svn, ovn: array of string): string; override :=
    $'(%UnFixed+{name})';
    
  end;
  OptNVarExpr = sealed class(OptNExprBase, IOptVarExpr)
    
    public source: array of real;
    public id: integer;
    
    public procedure Calc :=
    res := source[id];
    
    public constructor(source: array of real; id: integer);
    begin
      self.source := source;
      self.id := id;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptNVarExpr(source, id);
    
    
    
    public function UnFixVarExprs(nn, ns, no: array of string): IOptExpr; override :=
    AsDefinitelyNumExpr(new UnOptVarExpr(nn[id]));
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is OptNVarExpr(var noe)) and (noe.id=self.id);
    
    public function NVarUseCount(id: integer): integer; override :=
    integer(self.id = id);
    
    public function GetCalc: sequence of Action0; override :=
    new Action0[](self.Calc);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(6));
      bw.Write(byte(1));
      bw.Write(id);
    end;
    
    public constructor(br: System.IO.BinaryReader; nv: array of real);
    begin
      
      self.source := nv;
      self.id := br.ReadInt32;
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override :=
    nvn[id];
    
  end;
  OptSVarExpr = sealed class(OptSExprBase, IOptVarExpr)
    
    public source: array of string;
    public id: integer;
    
    public procedure Calc :=
    res := source[id];
    
    public constructor(source: array of string; id: integer);
    begin
      self.source := source;
      self.id := id;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptSVarExpr(source, id);
    
    
    
    public function UnFixVarExprs(nn, ns, no: array of string): IOptExpr; override :=
    AsStrExpr(new UnOptVarExpr(ns[id]));
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is OptSVarExpr(var noe)) and (noe.id=self.id);
    
    public function SVarUseCount(id: integer): integer; override :=
    integer(self.id = id);
    
    public function GetCalc: sequence of Action0; override :=
    new Action0[](self.Calc);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(6));
      bw.Write(byte(2));
      bw.Write(id);
    end;
    
    public constructor(br: System.IO.BinaryReader; sv: array of string);
    begin
      
      self.source := sv;
      self.id := br.ReadInt32;
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override :=
    svn[id];
    
  end;
  OptOVarExpr = sealed class(OptOExprBase, IOptVarExpr)
    
    public source: array of object;
    public id: integer;
    
    public procedure Calc :=
    res := source[id];
    
    public constructor(source: array of object; id: integer);
    begin
      self.source := source;
      self.id := id;
    end;
    
    public function Copy: OptExprBase; override :=
    new OptOVarExpr(source, id);
    
    
    
    public function UnFixVarExprs(nn, ns, no: array of string): IOptExpr; override :=
    new UnOptVarExpr(no[id]);
    
    public function IsSame(oe: IOptExpr): boolean; override :=
    (oe is OptOVarExpr(var noe)) and (noe.id=self.id);
    
    public function OVarUseCount(id: integer): integer; override :=
    integer(self.id = id);
    
    public function GetCalc: sequence of Action0; override :=
    new Action0[](self.Calc);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(6));
      bw.Write(byte(3));
      bw.Write(id);
    end;
    
    public constructor(br: System.IO.BinaryReader; ov: array of object);
    begin
      
      self.source := ov;
      self.id := br.ReadInt32;
      
    end;
    
    public function ToString(nvn, svn, ovn: array of string): string; override :=
    ovn[id];
    
  end;
  
  {$endregion Var}
  
  {$region Wrappers}
  
  OptExprWrapper = abstract class
    
    public n_vars: array of real;
    public s_vars: array of string;
    public o_vars: array of object;
    
    public n_vars_names: array of string;
    public s_vars_names: array of string;
    public o_vars_names: array of string;
    
    public NumChecks := new Dictionary<string, ExprContextArea>;
    public StrChecks := new Dictionary<string, ExprContextArea>;
    
    
    public MainCalcProc: procedure;
    
    
    
    public function GetMain: OptExprBase; abstract;
    public procedure SetMain(Main: OptExprBase); abstract;
    
    protected function GetNewInst: OptExprWrapper; abstract;
    
    public function Copy: OptExprWrapper;
    begin
      Result := GetNewInst;
      
      Result.n_vars := self.n_vars;
      Result.s_vars := self.s_vars;
      Result.o_vars := self.o_vars;
      
      Result.n_vars_names := self.n_vars_names;
      Result.s_vars_names := self.s_vars_names;
      Result.o_vars_names := self.o_vars_names;
      
      Result.NumChecks := self.NumChecks.ToDictionary(kvp->kvp.Key, kvp->kvp.Value);
      Result.StrChecks := self.StrChecks.ToDictionary(kvp->kvp.Key, kvp->kvp.Value);
      
    end;
    
    public function IsSame(wrapper: OptExprWrapper): boolean :=
      
      self.n_vars_names.SequenceEqual(wrapper.n_vars_names) and
      self.s_vars_names.SequenceEqual(wrapper.s_vars_names) and
      self.o_vars_names.SequenceEqual(wrapper.o_vars_names) and
      
      self.NumChecks.SequenceEqual(wrapper.NumChecks) and // ExprContextArea shouldn't copy itself, so it's ok to check this way
      self.StrChecks.SequenceEqual(wrapper.StrChecks) and
      
      self.GetMain.IsSame(wrapper.GetMain);
    
    protected function GetOptInst(Main: IOptExpr; NumChecks, StrChecks: Dictionary<string, ExprContextArea>): OptExprWrapper;
    
    public function Optimize(gnvn, gsvn: HashSet<string>): OptExprWrapper;
    
    public function FinalOptimize(gnvn, gsvn, govn: HashSet<string>): OptExprWrapper;
    
    public function ReplaceVar(vn: string; oe: OptExprBase; envn, esvn, eovn: array of string): OptExprWrapper;
    
    public function ReplaceVar(vn: string; oe: OptExprWrapper) :=
    ReplaceVar(vn, oe.GetMain, oe.n_vars_names, oe.s_vars_names, oe.o_vars_names);
    
    public function VarUseCount(vn: string): integer;
    begin
      var ind: integer;
      
      ind := n_vars_names.IndexOf(vn);
      if ind<>-1 then
      begin
        Result := GetMain.NVarUseCount(ind);
        exit;
      end;
      
      ind := s_vars_names.IndexOf(vn);
      if ind<>-1 then
      begin
        Result := GetMain.SVarUseCount(ind);
        exit;
      end;
      
      ind := o_vars_names.IndexOf(vn);
      if ind<>-1 then
      begin
        Result := GetMain.OVarUseCount(ind);
        exit;
      end;
      
    end;
    
    public procedure ResetCalc;
    begin
      
      MainCalcProc := System.Delegate.Combine(GetMain.GetCalc.Cast&<System.Delegate>.ToArray) as Action0;
      
    end;
    
    protected procedure StartCalc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>);
    begin
      foreach var vname in NumChecks.Keys do if s_vars.ContainsKey(vname) then raise new ValueCannotBeStr;
      foreach var vname in StrChecks.Keys do if n_vars.ContainsKey(vname) then raise new ValueCannotBeNum;
      
      for var i := 0 to n_vars_names.Length-1 do
      begin
        var name := n_vars_names[i];
        if n_vars.ContainsKey(name) then
          self.n_vars[i] := n_vars[name] else
          self.n_vars[i] := 0;
      end;
      
      for var i := 0 to s_vars_names.Length-1 do
      begin
        var name := s_vars_names[i];
        if s_vars.ContainsKey(name) then
          self.s_vars[i] := s_vars[name] else
          self.s_vars[i] := '';
      end;
      
      for var i := 0 to o_vars_names.Length-1 do
      begin
        var name := o_vars_names[i];
        if n_vars.ContainsKey(name) then
          self.o_vars[i] := n_vars[name] else
        if s_vars.ContainsKey(name) then
          self.o_vars[i] := s_vars[name] else
          self.o_vars[i] := nil;
      end;
      
      if MainCalcProc <> nil then MainCalcProc;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object; abstract;
    
    public static function FromExpr(e: Expr; conv: OptExprBase->OptExprBase := nil): OptExprWrapper;
    
    public procedure Save(bw: System.IO.BinaryWriter);
    begin
      
      bw.Write(NumChecks.Count);
      foreach var vname in NumChecks.Keys do
      begin
        bw.Write(vname);
        //NumChecks[vname].Save(bw);//ToDo
      end;
      
      bw.Write(StrChecks.Count);
      foreach var vname in StrChecks.Keys do
      begin
        bw.Write(vname);
        //StrChecks[vname].Save(bw);//ToDo
      end;
      
      bw.Write(n_vars_names.Length);
      foreach var nvn in n_vars_names do
        bw.Write(nvn);
      
      bw.Write(s_vars_names.Length);
      foreach var svn in s_vars_names do
        bw.Write(svn);
      
      bw.Write(o_vars_names.Length);
      foreach var ovn in o_vars_names do
        bw.Write(ovn);
      
      GetMain.Save(bw);
      
    end;
    
    public static function Load(br: System.IO.BinaryReader): OptExprWrapper;
    
    public function ToString: string; override :=
    GetMain.ToString(n_vars_names, s_vars_names, o_vars_names);
    
    public property DebugStr: string read ToString;
    
  end;
  OptNExprWrapper = sealed class(OptExprWrapper)
    
    public Main: OptNExprBase;
    
    
    
    public function GetMain: OptExprBase; override := Main;
    public procedure SetMain(Main: OptExprBase); override := self.Main := OptNExprBase(Main);
    
    protected function GetNewInst: OptExprWrapper; override;
    begin
      var res := new OptNExprWrapper;
      res.Main := OptNExprBase(self.Main.Copy);
      res.Main.SetWrapper(res);
      Result := res;
    end;
    
    public function CalcN(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): real;
    begin
      
      inherited StartCalc(n_vars, s_vars);
      
      Result := Main.res;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object; override :=
    CalcN(n_vars, s_vars);
    
    public constructor(Main: OptNExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
  end;
  OptSExprWrapper = sealed class(OptExprWrapper)
    
    public Main: OptSExprBase;
    
    
    
    public function GetMain: OptExprBase; override := Main;
    public procedure SetMain(Main: OptExprBase); override := self.Main := OptSExprBase(Main);
    
    protected function GetNewInst: OptExprWrapper; override;
    begin
      var res := new OptSExprWrapper;
      res.Main := OptSExprBase(self.Main.Copy);
      res.Main.SetWrapper(res);
      Result := res;
    end;
    
    public function CalcS(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): string;
    begin
      
      inherited StartCalc(n_vars, s_vars);
      
      Result := Main.res;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object; override :=
    CalcS(n_vars, s_vars);
    
    public constructor(Main: OptSExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
  end;
  OptOExprWrapper = sealed class(OptExprWrapper)
    
    public Main: OptExprBase;
    
    
    
    public function GetMain: OptExprBase; override := Main;
    public procedure SetMain(Main: OptExprBase); override := self.Main := Main;
    
    protected function GetNewInst: OptExprWrapper; override;
    begin
      var res := new OptOExprWrapper;
      res.Main := self.Main.Copy;
      res.Main.SetWrapper(res);
      Result := res;
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object; override;
    begin
      
      inherited StartCalc(n_vars, s_vars);
      
      Result := Main.GetRes;
      
    end;
    
    public constructor(Main: OptOExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
  end;
  
  {$endregion Wrappers}
  
  {$endregion Optimized}
  
implementation

uses KCDData;

{$region StrFuncs}

function EscapeStrSyms(self: string): string; extensionmethod :=
self.Replace('\','\\').Replace('"','\"');

function FindStrEnd(self: string; from: integer): integer; extensionmethod;
begin
  var nfrom := from;
  while true do
  begin
    
    if from > self.Length then
      raise new CorrespondingCharNotFoundException(self, '"', nfrom);
    
    if self[from] = '"' then
    begin
      Result := from;
      exit;
    end;
    
    from += self[from]='\'?2:1;
  end;
end;

function FindNext(self: string; from: integer; ch: char): integer; extensionmethod;
begin
  var nfrom := from;
  while true do
  begin
    
    if from > self.Length then
      raise new CorrespondingCharNotFoundException(self, ch, nfrom);
    
    if self[from] = ch then
    begin
      Result := from;
      exit;
    end;
    
    if self[from] = '(' then from := self.FindNext(from+1,')') else
    if self[from] = '"' then from := self.FindStrEnd(from+1) else
    if self[from] = '[' then from := self.FindNext(from+1,']');
    
    from += 1;
  end;
end;

function SmartSplit(self: string; str: string := ' '; c: integer := -1): array of string; extensionmethod;
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
  while n+str.Length-1 < self.Length do
  begin
    
    if Range(1,str.Length).All(i->self[n+i-1] = str[i]) then
    begin
      wsp += n;
      if wsp.Count = c then break;
    end else
    if self[n] = '(' then n := self.FindNext(n+1,')') else
    if self[n] = '"' then n := self.FindStrEnd(n+1) else
    if self[n] = '[' then n := self.FindNext(n+1,']');
    
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
    Result[i+1] := self.Substring(wsp[i]+str.Length-1, wsp[i+1]-wsp[i]-1);
  
  Result[Result.Length-1] := self.Substring(wsp[wsp.Count-1]+str.Length-1);
  
end;

function SmartCheckAll(self: string; f: char->boolean; params allowed_chars: array of char): boolean; extensionmethod;
begin
  var i := 1;
  Result := true;
  while i < self.Length do
  begin
    
    if not ( f(self[i]) or allowed_chars.Contains(self[i]) ) then
    begin
      Result := false;
      exit;
    end;
    
    if self[i] = '(' then i := self.FindNext(i+1,')') else
    if self[i] = '"' then i := self.FindNext(i+1,'"') else
    if self[i] = '[' then i := self.FindNext(i+1,']');
    
    i += 1;
  end;
end;

{$endregion StrFuncs}

{$region PreOpt}

function SLiteralExpr.ToString: string :=
$'"{val.EscapeStrSyms}"';

type
  ArithOp = (none, plus, minus, mlt, divide, pow);
  ExprCoord = record
    Op: ArithOp;
    i1,i2: integer;
  end;

function GetSimpleExpr(text:string; si1,si2: integer): Expr;
begin
  
  if si1 > si2 then raise new EmptyExprException(text, si1) else
  if text[si1] = '(' then
    if text[si2] = ']' then
    begin
      var i := text.FindNext(si1+1, ')');
      var str := text.Substring(si1-1,i-si1+1);
      var cps := text.Substring(i+1,si2-i-2).SmartSplit('..');
      if cps.Length <> 2 then raise new InvalidUseOfStrCut(text);
      Result := new FuncExpr('cutstr', new string[](str, cps[0], cps[1]));
    end else
      Result := Expr.FromString(text, si1+1, si2-1) else
  if text[si1] = '"' then
  begin
    var i := text.FindStrEnd(si1+1);
    if (i <> si2) and (text[i+1] = '[') then
    begin
      if text.FindNext(i+2,']') <> si2 then raise new ExtraCharsException(text, si1, si2, text.FindNext(i+2,']'));
      var str := text.Substring(si1-1,i-si1+1);
      var cps := text.Substring(i+1,si2-i-2).SmartSplit('..');
      if cps.Length <> 2 then raise new InvalidUseOfStrCut(text);
      Result := new FuncExpr('cutstr', new string[](str, cps[0], cps[1]));
    end else
    begin
      if i <> si2 then raise new ExtraCharsException(text, si1, i+1, si2);
      Result := new SLiteralExpr(text.Substring(si1,si2-si1-1).Replace('\"','"').Replace('\\','\'));
    end;
  end else
  begin
    var str := text.Substring(si1-1,si2-si1+1);
    var r: real;
    
    if real.TryParse(str,System.Globalization.NumberStyles.AllowDecimalPoint,new System.Globalization.NumberFormatInfo, r) then
      Result := new NLiteralExpr(r) else
    if str.SmartCheckAll(ch->ch.IsLetter or ch.IsDigit, '_', '[', '.') then
      Result := new VarExpr(str) else
    if (not str.SmartCheckAll(ch->ch <> '(')) and (str.FindNext(str.FindNext(1, '(')+1,')') = si2-si1+1) then
    begin
      var im := str.FindNext(1, '(');
      Result := new FuncExpr(str.Substring(0, im-1), str.Substring(im,str.Length-im-1).SmartSplit(','));
    end else
    begin
      //writeln(data);
      //readln;
      raise new CanNotParseException(str);
    end;
  end;
  
end;

function GetSimpleExpr(text:string; ec: ExprCoord):=
GetSimpleExpr(text,ec.i1,ec.i2);

function ParseOrderedOps(text:string; cl: List<ExprCoord>): ComplexExpr;
begin
  var res := new LinkedList<(ArithOp,Expr)>(
    cl.Select(ec->(ec.Op,GetSimpleExpr(text,ec)))
  );
  
  var in_group := false;
  var group := new List<(ArithOp,Expr)>;
  var n: LinkedListNode<(ArithOp,Expr)>;
  
  n := res.First.Next;
  while n <> nil do
  begin
    
    if in_group then
    begin
      if n.Value.Item1 = pow then
      begin
        group.Add(n.Value);
      end else
      begin
        in_group := false;
        
        var ce := new PowExpr;
        ce.Positive.AddRange(group.Select(t->t.Item2));
        res.AddBefore(n,(group[0].Item1, Expr(ce)));
        
        foreach var el in group do res.Remove(el);
        group.Clear;
      end;
    end else
    begin
      if n.Value.Item1 = pow then
      begin
        in_group := true;
        group.Add(n.Previous.Value);
        group.Add(n.Value);
      end;
    end;
    
    n := n.Next;
  end;
  if in_group then
  begin
    in_group := false;
    
    var ce := new PowExpr;
    ce.Positive.AddRange(group.Select(t->t.Item2));
    res.AddLast((group[0].Item1, Expr(ce)));
    
    foreach var el in group do res.Remove(el);
    group.Clear;
  end;
  
  n := res.First.Next;
  while n <> nil do
  begin
    
    if in_group then
    begin
      if (n.Value.Item1 = mlt) or (n.Value.Item1 = divide) then
      begin
        group.Add(n.Value);
      end else
      begin
        in_group := false;
        
        var ce := new MltExpr;
        ce.Positive.Add(group.First.Item2);
        ce.Positive.AddRange(group.Skip(1).Where(t->t.Item1=mlt).Select(t->t.Item2));
        ce.Negative.AddRange(group.Skip(1).Where(t->t.Item1=divide).Select(t->t.Item2));
        res.AddBefore(n,(group[0].Item1, Expr(ce)));
        
        foreach var el in group do res.Remove(el);
        group.Clear;
      end;
    end else
    begin
      if (n.Value.Item1 = mlt) or (n.Value.Item1 = divide) then
      begin
        in_group := true;
        group.Add(n.Previous.Value);
        group.Add(n.Value);
      end;
    end;
    
    n := n.Next;
  end;
  if in_group then
  begin
    var ce := new MltExpr;
    ce.Positive.Add(group.First.Item2);
    ce.Positive.AddRange(group.Skip(1).Where(t->t.Item1=mlt).Select(t->t.Item2));
    ce.Negative.AddRange(group.Skip(1).Where(t->t.Item1=divide).Select(t->t.Item2));
    res.AddLast((group[0].Item1, Expr(ce)));
    
    foreach var el in group do res.Remove(el);
    group.Clear;
  end;
  
  if res.Count = 1 then
    Result := res.First.Value.Item2 as ComplexExpr else
  if res.All(t->t.Item1>minus) then
  begin
    Result := new MltExpr;
    
    n := res.First;
    while n <> nil do
    begin
      if n.Value.Item1 = divide then
        Result.Negative.Add(n.Value.Item2) else
        Result.Positive.Add(n.Value.Item2);
      
      n := n.Next;
    end;
  end else
  begin
    Result := new PlusExpr;
    
    n := res.First;
    while n <> nil do
    begin
      if n.Value.Item1 = minus then
        Result.Negative.Add(n.Value.Item2) else
        Result.Positive.Add(n.Value.Item2);
      
      n := n.Next;
    end;
    
  end;
  
end;

static function Expr.FromString(text:string; i1, i2:integer): Expr;
begin
  var cl := new List<ExprCoord>;
  var curr: ExprCoord;
  
  if i1 > i2 then raise new EmptyExprException(text, i1);
  case text[i1] of
    '+':
    begin
      curr.Op := none;
      i1 += 1;
      curr.i1 := i1;
    end;
    '-':
    begin
      curr.Op := minus;
      i1 += 1;
      curr.i1 := i1;
    end;
    '"':
    begin
      curr.Op := none;
      curr.i1 := i1;
      i1 := text.FindStrEnd(i1+1)+1;
    end;
    else
    if text[i1].IsDigit or text[i1].IsLetter or (text[i1] = '_') or (text[i1] = '(') or (text[i1] = ')') then
    begin
      curr.Op := none;
      curr.i1 := i1;
    end else
      raise new InvalidCharException(text, i1);
  end;
  
  var FinishCurr: procedure(Op: ArithOp) := Op->
  begin
    curr.i2 := i1-1;
    cl.Add(curr);
    i1 += 1;
    curr.i1 := i1;
    curr.Op := Op;
  end;
  
  
  
  while true do
  begin
    
    if i1 = i2+1 then break;
    if i1 > i2+1 then raise new ReadingOutOfRangeException(text, i1);
    
    case text[i1] of
      '(': i1 := text.FindNext(i1+1,')') + 1;
      '"': i1 := text.FindNext(i1+1,'"') + 1;
      '[': i1 := text.FindNext(i1+1,']') + 1;
      '+': FinishCurr(plus);
      '-': FinishCurr(minus);
      '*': FinishCurr(mlt);
      '/': FinishCurr(divide);
      '^': FinishCurr(pow);
      else i1 += 1;
    end;
  end;
  
  curr.i2 := i2;
  cl.Add(curr);
  
  if cl.Count > 1 then
    Result := ParseOrderedOps(text, cl) else
  if cl[0].Op = minus then
  begin
    var res := new PlusExpr;
    res.Negative.Add(GetSimpleExpr(text, cl[0]));
    Result := res;
  end else
    Result := GetSimpleExpr(text, cl[0]);
  
end;

{$endregion PreOpt}

{$region Optimized}

{$region Funcs}
type
  
  OptFunc_Length = sealed class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(string)
    );
  
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is string then
        self.res := (pr as string).Length else
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(string), pr?.GetType);
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(1));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'Length', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Length';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_Length(par);
    
  end;
  OptFunc_Num = sealed class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    if par.Length <> 1 then
      raise new InvalidFuncParamCountException(self, self.name, 1, par.Length);
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(Object)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is real then
        res := real(pr) else
      if pr = nil then
        res := 0.0 else
      if not TryStrToFloat(pr as string, self.res) then
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(real), pr?.GetType);
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      
      var oe := par[0].Optimize(nvn, svn, ovn) as OptExprBase;
      var res1: OptFunc_Num;
      if oe<>par[0] then
        res1 := new OptFunc_Num(new OptExprBase[](oe)) else
        res1 := self;
      
      if res1.par[0] is OptNExprBase then
        Result := res1.par[0] else
      if res1.par[0] is IOptLiteralExpr then
      begin
        res1.Calc;
        Result := new OptNLiteralExpr(res1.res)
      end else
        Result := res1;
      
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(2));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'Num', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Num';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_Num(par);
    
  end;
  OptFunc_KeyCode = sealed class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(string)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is string(var s) then
        self.res := GetKeyCode(s) else
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(string), pr?.GetType);
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(3));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'KeyCode', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'KeyCode';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_KeyCode(par);
    
  end;
  OptFunc_DeflyNum = sealed class(OptNFuncExpr)
    
    ifnot: Action0;
    
    public procedure CheckParams; override :=
    if par.Length <> 1 then
      raise new InvalidFuncParamCountException(self, self.name, 1, par.Length) else
    if par[0] is OptSExprBase then
      ifnot();
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(real)
    );
    
    public procedure Calc;
    begin
      var o := par[0].GetRes;
      if o is string then
        ifnot else
      self.res := ObjToNumUnsafe(o);
    end;
    
    private procedure DefaultIfNot :=
    raise new ExpectedNumValueException(self);
    
    
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      
      var oe := par[0].Optimize(nvn, svn, ovn) as OptExprBase;
      var res1: OptFunc_DeflyNum;
      if oe<>par[0] then
        res1 := new OptFunc_DeflyNum(new OptExprBase[](oe), ifnot) else
        res1 := self;
      CheckParams;
      
      if res1.par[0] is OptNExprBase then
        Result := res1.par[0] else
      if res1.par[0] is OptNullLiteralExpr then
        Result := new OptNLiteralExpr(0.0) else
        Result := res1;
      
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(4));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'DeflyNum', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase; ifnot: procedure := nil);
    begin
      self.par := par;
      self.name := 'DeflyNum';
      self.ifnot := ifnot=nil?DefaultIfNot:ifnot;
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_DeflyNum(par, ifnot);
    
  end;
  OptFunc_Floor = sealed class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(real)
    );
  
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is real then
        self.res := System.Math.Floor(real(pr)) else
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(real), pr?.GetType);
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(7));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'Floor', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Floor';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_Floor(par);
    
  end;
  OptFunc_Round = sealed class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(real)
    );
  
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is real then
        self.res := System.Math.Round(real(pr)) else
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(real), pr?.GetType);
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(8));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'Round', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Round';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_Round(par);
    
  end;
  OptFunc_Ceil = sealed class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(real)
    );
  
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is real then
        self.res := System.Math.Ceiling(real(pr)) else
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(real), pr?.GetType);
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(9));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'Ceil', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Ceil';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_Ceil(par);
    
  end;
  
  OptFunc_Str = sealed class(OptSFuncExpr)
    
    public procedure CheckParams; override :=
    if par.Length <> 1 then
      raise new InvalidFuncParamCountException(self, self.name, 1, par.Length);
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(Object)
    );
    
    public procedure Calc;
    begin
      self.res := ObjToStr(par[0].GetRes);
    end;
    
    
    
    public function Optimize(nvn, svn, ovn: array of string): IOptExpr; override;
    begin
      
      var oe := par[0].Optimize(nvn, svn, ovn) as OptExprBase;
      var res1: OptFunc_Str;
      if oe<>par[0] then
        res1 := new OptFunc_Str(new OptExprBase[](oe)) else
        res1 := self;
      
      if res1.par[0] is OptSExprBase then
        Result := res1.par[0] else
      if res1.par[0] is IOptLiteralExpr then
        Result := new OptSLiteralExpr(ObjToStr(res1.par[0].GetRes)) else
        Result := res1;
      
    end;
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(5));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'Str', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Str';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_Str(par);
    
  end;
  OptFunc_CutStr = sealed class(OptSFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(string),
      typeof(real),
      typeof(real)
    );
    
    public procedure Calc;
    begin
      var r1 := ObjToNum(par[1].GetRes);
      var r2 := ObjToNum(par[2].GetRes);
      if real.IsNaN(r1) or real.IsInfinity(r1) then raise new CannotConvertToIntException(self, r1);
      if real.IsNaN(r2) or real.IsInfinity(r1) then raise new CannotConvertToIntException(self, r2);
      var bi1 := BigInteger.Create(r1+0.5);
      var bi2 := BigInteger.Create(r2+0.5);
      if bi2 < bi1 then Swap(bi1, bi2);
      self.res := ObjToStr(par[0].GetRes);
      if (bi1 < 0) or (bi2 < 0) then raise new CutOutOfRangeException(self, self.res, bi1, bi2);
      if (bi1 > self.res.Length) or (bi2 > self.res.Length) then raise new CutOutOfRangeException(self, self.res, bi1, bi2);
      var i1 := integer(bi1);
      var i2 := integer(bi2);
      self.res := self.res.Substring(i1, i2-i1+1);
    end;
    
    
    
    function inhgc := inherited GetCalc;
    public function GetCalc: sequence of Action0; override;
    begin
      yield sequence inhgc;
      yield Action0(self.Calc);
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(5));
      bw.Write(byte(6));
      inherited Save(bw);
    end;
    
    public constructor(br: System.IO.BinaryReader; nvn: array of real; svn: array of string; ovn: array of object) :=
    inherited Create(br, 'CutStr', nvn, svn, ovn);
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'CutStr';
      CheckParams;
    end;
    
    public function GetNewInst(par: array of OptExprBase): IOptFuncExpr; override :=
    new OptFunc_CutStr(par);
    
  end;
  
{$endregion Funcs}

{$region some impl}

function OptExprBase.Optimize(wrapper: OptExprWrapper): IOptExpr :=
Optimize(wrapper.n_vars_names,wrapper.s_vars_names,wrapper.o_vars_names);

static function OptExprBase.AsDefinitelyNumExpr(o: OptExprBase; ifnot: Action0): OptNExprBase :=
new OptFunc_DeflyNum(new OptExprBase[](o), ifnot);

static function OptExprBase.AsStrExpr(o: OptExprBase): OptSExprBase :=
new OptFunc_Str(new OptExprBase[](o));

function OptExprBase.ToString: string :=
self.ToString(wrapper.n_vars_names,wrapper.s_vars_names,wrapper.o_vars_names);

function OptSLiteralExpr.ToString(nvn, svn, ovn: array of string): string;
begin
  var formated_res := res.EscapeStrSyms;
  Result :=
    (formated_res.Length <= 100)?
    $'"{formated_res}"':
    $'"{formated_res.Substring(0,100)}..."[{formated_res.Length}]';
end;

function UnOptVarExpr.FixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr;
begin
  if nn.Contains(name) then
  begin
    var res := new OptNVarExpr;
    res.source := sn;
    res.id := nn.IndexOf(name);
    Result := res;
  end else
  if ns.Contains(name) then
  begin
    var res := new OptSVarExpr;
    res.source := ss;
    res.id := ns.IndexOf(name);
    Result := res;
  end else
  begin
    var res := new OptOVarExpr;
    res.source := so;
    res.id := no.IndexOf(name);
    Result := res;
  end;
end;

function UnOptVarExpr.FinalFixVarExprs(sn: array of real; ss: array of string; so: array of object; nn, ns, no: array of string): IOptExpr;
begin
  if nn.Contains(name) then
  begin
    var res := new OptNVarExpr;
    res.source := sn;
    res.id := nn.IndexOf(name);
    Result := res;
  end else
  if ns.Contains(name) then
  begin
    var res := new OptSVarExpr;
    res.source := ss;
    res.id := ns.IndexOf(name);
    Result := res;
  end else
  if no.Contains(name) then
  begin
    var res := new OptOVarExpr;
    res.source := so;
    res.id := no.IndexOf(name);
    Result := res;
  end else
    Result := new OptNullLiteralExpr;
end;

{$endregion some impl}

{$region Wrapper converters}

function OptExprWrapper.GetOptInst(Main: IOptExpr; NumChecks, StrChecks: Dictionary<string, ExprContextArea>): OptExprWrapper;
begin
  
  if self.NumChecks.SequenceEqual(NumChecks) and self.StrChecks.SequenceEqual(StrChecks) and Main.IsSame(self.GetMain) then
    Result := self else
  if Main is OptNExprBase then
    Result := new OptNExprWrapper(Main as OptNExprBase) else
  if Main is OptSExprBase then
    Result := new OptSExprWrapper(Main as OptSExprBase) else
    Result := new OptOExprWrapper(Main as OptOExprBase);
  
  Main.SetWrapper(Result);
end;

function OptExprWrapper.Optimize(gnvn, gsvn: HashSet<string>): OptExprWrapper;
begin
  var Main := GetMain.UnFixVarExprs(n_vars_names, s_vars_names, o_vars_names);
  
  foreach var vname in gnvn do if StrChecks.ContainsKey(vname) then raise new ConflictingExprTypesException(nil,nil);
  foreach var vname in gsvn do if NumChecks.ContainsKey(vname) then raise new ConflictingExprTypesException(nil,nil);
  
  var nNumChecks := NumChecks.ToDictionary(kvp->kvp.Key, kvp->ExprContextArea(nil));
  var nStrChecks := StrChecks.ToDictionary(kvp->kvp.Key, kvp->ExprContextArea(nil));
  
  foreach var vname in gnvn do nNumChecks.Remove(vname);
  foreach var vname in gsvn do nStrChecks.Remove(vname);
  
  var anvn := n_vars_names.ToHashSet;
  var asvn := s_vars_names.ToHashSet;
  var aovn := o_vars_names.ToHashSet;
  
  foreach var vname in gnvn do
  begin
    aovn.Remove(vname);
    anvn.Add(vname);
  end;
  
  foreach var vname in gsvn do
  begin
    aovn.Remove(vname);
    asvn.Add(vname);
  end;
  
  var lnvn := new HashSet<string>;
  var lsvn := new HashSet<string>;
  var lovn := new HashSet<string>;
  
  Main.DeduseVarsTypes(
    anvn,asvn,aovn,
    gnvn,gsvn,nil,
    lnvn,lsvn,lovn,
    true, true,
    nNumChecks, nStrChecks
  );
  
  var n_vars := ArrFill(lnvn.Count, 0.0);
  var s_vars := ArrFill(lsvn.Count, '');
  var o_vars := ArrFill(lovn.Count, object(nil));
  
  var n_vars_names := lnvn.ToArray;
  var s_vars_names := lsvn.ToArray;
  var o_vars_names := lovn.ToArray;
  
  Main := Main.FixVarExprs(n_vars, s_vars, o_vars, n_vars_names, s_vars_names, o_vars_names);
  Main := Main.Optimize(n_vars_names,s_vars_names,o_vars_names);
  
  Result := GetOptInst(Main, nNumChecks,nStrChecks);
  if Result=self then exit;
  
  
  
  Result.NumChecks := nNumChecks;
  Result.StrChecks := nStrChecks;
  
  Result.n_vars_names := n_vars_names;
  Result.s_vars_names := s_vars_names;
  Result.o_vars_names := o_vars_names;
  
  Result.n_vars := n_vars;
  Result.s_vars := s_vars;
  Result.o_vars := o_vars;
  
  Main.ClampLists;
  
end;

function OptExprWrapper.FinalOptimize(gnvn, gsvn, govn: HashSet<string>): OptExprWrapper;
begin
  var Main := GetMain.UnFixVarExprs(n_vars_names, s_vars_names, o_vars_names);
  
  foreach var vname in gnvn do if StrChecks.ContainsKey(vname) then raise new ConflictingExprTypesException(nil,nil);
  foreach var vname in gsvn do if NumChecks.ContainsKey(vname) then raise new ConflictingExprTypesException(nil,nil);
  
  var nNumChecks := NumChecks.ToDictionary(kvp->kvp.Key, kvp->ExprContextArea(nil));
  var nStrChecks := StrChecks.ToDictionary(kvp->kvp.Key, kvp->ExprContextArea(nil));
  
  foreach var vname in gnvn do nNumChecks.Remove(vname);
  foreach var vname in gsvn do nStrChecks.Remove(vname);
  
  var lnvn := new HashSet<string>;
  var lsvn := new HashSet<string>;
  var lovn := new HashSet<string>;
  
  Main.DeduseVarsTypes(
    gnvn,gsvn,govn,
    gnvn,gsvn,govn,
    lnvn,lsvn,lovn,
    true, true,
    nNumChecks, nStrChecks
  );
  
  var n_vars := ArrFill(lnvn.Count, 0.0);
  var s_vars := ArrFill(lsvn.Count, '');
  var o_vars := ArrFill(lovn.Count, object(nil));
  
  var n_vars_names := lnvn.ToArray;
  var s_vars_names := lsvn.ToArray;
  var o_vars_names := lovn.ToArray;
  
  Main := Main.FinalFixVarExprs(n_vars, s_vars, o_vars, n_vars_names, s_vars_names, o_vars_names);
  Main := Main.Optimize(n_vars_names,s_vars_names,o_vars_names);
  
  Result := GetOptInst(Main, nNumChecks,nStrChecks);
  if Result=self then exit;
  
  
  
  Result.NumChecks := nNumChecks;
  Result.StrChecks := nStrChecks;
  
  Result.n_vars_names := n_vars_names;
  Result.s_vars_names := s_vars_names;
  Result.o_vars_names := o_vars_names;
  
  Result.n_vars := n_vars;
  Result.s_vars := s_vars;
  Result.o_vars := o_vars;
  
  Main.ClampLists;
  
end;

function OptExprWrapper.ReplaceVar(vn: string; oe: OptExprBase; envn, esvn, eovn: array of string): OptExprWrapper;
begin
  var Main := GetMain.UnFixVarExprs(n_vars_names, s_vars_names, o_vars_names);
  Main := Main.ReplaceVar(vn, oe.UnFixVarExprs(envn,esvn,eovn) as OptExprBase);
  
  foreach var vname in envn do if StrChecks.ContainsKey(vname) then raise new ConflictingExprTypesException(nil,nil);
  foreach var vname in esvn do if NumChecks.ContainsKey(vname) then raise new ConflictingExprTypesException(nil,nil);
  
  var nNumChecks := NumChecks.ToDictionary(kvp->kvp.Key, kvp->ExprContextArea(nil));
  var nStrChecks := StrChecks.ToDictionary(kvp->kvp.Key, kvp->ExprContextArea(nil));
  
  foreach var vname in envn do nNumChecks.Remove(vname);
  foreach var vname in esvn do nStrChecks.Remove(vname);
  
  var anvn := n_vars_names.ToHashSet;
  var asvn := s_vars_names.ToHashSet;
  var aovn := o_vars_names.ToHashSet;
  
  foreach var vname in envn do
  begin
    aovn.Remove(vname);
    anvn.Add(vname);
  end;
  
  foreach var vname in esvn do
  begin
    aovn.Remove(vname);
    asvn.Add(vname);
  end;
  
  foreach var vname in eovn do
    if not(
      anvn.Contains(vname) or
      asvn.Contains(vname)
    ) then aovn += vname;
  
  var lnvn := new HashSet<string>;
  var lsvn := new HashSet<string>;
  var lovn := new HashSet<string>;
  
  Main.DeduseVarsTypes(
    anvn,asvn,aovn,
    envn.ToHashSet,esvn.ToHashSet,eovn.ToHashSet,
    lnvn,lsvn,lovn,
    true, true,
    nNumChecks, nStrChecks
  );
  
  var n_vars := ArrFill(lnvn.Count, 0.0);
  var s_vars := ArrFill(lsvn.Count, '');
  var o_vars := ArrFill(lovn.Count, object(nil));
  
  var n_vars_names := lnvn.ToArray;
  var s_vars_names := lsvn.ToArray;
  var o_vars_names := lovn.ToArray;
  
  Main := Main.FixVarExprs(n_vars, s_vars, o_vars, n_vars_names, s_vars_names, o_vars_names);
  Main := Main.Optimize(n_vars_names,s_vars_names,o_vars_names);
  
  Result := GetOptInst(Main, nNumChecks,nStrChecks);
  if Result=self then exit;
  
  
  
  Result.NumChecks := nNumChecks;
  Result.StrChecks := nStrChecks;
  
  Result.n_vars_names := n_vars_names;
  Result.s_vars_names := s_vars_names;
  Result.o_vars_names := o_vars_names;
  
  Result.n_vars := n_vars;
  Result.s_vars := s_vars;
  Result.o_vars := o_vars;
  
  Main.ClampLists;
  
end;

{$endregion Wrapper converters}

{$region OptConverter}

type
  OptConverter = sealed class
    
    static FuncTypes := new Dictionary<string, Func<array of OptExprBase,IOptFuncExpr>>;
    
    var_names := new HashSet<string>;
    
    static constructor;
    begin
      
      FuncTypes.Add('length', par->new OptFunc_Length(par));
      FuncTypes.Add('num', par->new OptFunc_Num(par));
      FuncTypes.Add('keycode', par->new OptFunc_KeyCode(par));
      FuncTypes.Add('deflynum', par->new OptFunc_DeflyNum(par));
      FuncTypes.Add('floor', par->new OptFunc_Floor(par));
      FuncTypes.Add('round', par->new OptFunc_Round(par));
      FuncTypes.Add('ceil', par->new OptFunc_Ceil(par));
      
      FuncTypes.Add('str', par->new OptFunc_Str(par));
      FuncTypes.Add('cutstr', par->new OptFunc_CutStr(par));
      
    end;
    
    function GetOptLiteralExpr(e: NLiteralExpr) :=
    new OptNLiteralExpr(e.val);
    
    function GetOptLiteralExpr(e: SLiteralExpr) :=
    new OptSLiteralExpr(e.val);
    
    function GetOptPlusExpr(e: PlusExpr): IOptPlusExpr;
    begin
      var res := new OptOPlusExpr;
      res.Positive := e.Positive.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      res.Negative := e.Negative.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      Result := res;
    end;
    
    function GetOptMltExpr(e: MltExpr): IOptMltExpr;
    begin
      var res := new OptOMltExpr;
      res.Positive := e.Positive.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      res.Negative := e.Negative.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      
      Result := res;
    end;
    
    function GetOptPowExpr(e: PowExpr): IOptPowExpr;
    begin
      if e.Negative.Any then raise new UnexpectedNegativePow(e);
      
      var res := new OptNPowExpr;
      res.Positive := e.Positive.ConvertAll(se->OptExprBase.AsDefinitelyNumExpr(GetOptExpr(se) as OptExprBase, ()->raise new CannotPowStringException(nil)));
      Result := res;
    end;
    
    function GetOptFuncExpr(e: FuncExpr): IOptFuncExpr;
    begin
      var ln := e.name.ToLower;
      if FuncTypes.ContainsKey(ln) then
      begin
        var func := FuncTypes[ln];
        var pars := e.par.ConvertAll(p->GetOptExpr(p) as OptExprBase);
        Result := func(pars);
      end else
        raise new UnknownFunctionNameException(e, e.name);
    end;
    
    function GetOptVarExpr(e: VarExpr): IOptExpr;
    begin
      
      case e.name.ToLower of
        'null': Result := new OptNullLiteralExpr;
        'nan': Result := new OptNLiteralExpr(real.NaN);
        'inf': Result := new OptNLiteralExpr(real.PositiveInfinity);
        else
        begin
          var res := new UnOptVarExpr(e.name);
          Result := res;
          if e.name.Contains('[') then
          begin
            var i1 := e.name.FindNext(1,'[');
            var i2 := e.name.FindNext(i1+1,']');
            if i2 <> e.name.Length then raise new InvalidVarException(e.name, 'Invalid use of indexing');
            var cut_str := e.name.Substring(i1,i2-i1-1);
            if cut_str.Contains('..') then
            begin
              var csp := cut_str.SmartSplit('..');
              if csp.Length <> 2 then raise new InvalidVarException(e.name, 'Invalid use of string cuting');
              res.name := res.name.Remove(i1-1);
              Result := new OptFunc_CutStr(new OptExprBase[](
                res,
                GetOptExpr(Expr.FromString(csp[0])) as OptExprBase,
                GetOptExpr(Expr.FromString(csp[1])) as OptExprBase
              ));
            end;
          end;
          
          if res.name.Length=0 then
            raise new InvalidVarException(e.name, 'Var name can''t be empty');
          
          var_names += res.name;
          
        end;
      end;
      
    end;
    
    function GetOptExpr(e: Expr): IOptExpr;
    begin
      match e with
        NLiteralExpr(var nl): Result := GetOptLiteralExpr(nl);
        SLiteralExpr(var sl): Result := GetOptLiteralExpr(sl);
        PlusExpr(var p): Result := GetOptPlusExpr(p);
        MltExpr(var m): Result := GetOptMltExpr(m);
        PowExpr(var p): Result := GetOptPowExpr(p);
        FuncExpr(var f): Result := GetOptFuncExpr(f);
        VarExpr(var v): Result := GetOptVarExpr(v);
        else raise new UnexpectedExprTypeException(e, e=nil?nil:e.GetType);
      end;
    end;
    
    function GetOptExprWrapper(e: Expr; conv: OptExprBase->OptExprBase): OptExprWrapper;
    begin
      
      var Main := GetOptExpr(e);
      if conv <> nil then Main := conv(Main as OptExprBase);
      
      var n_vars_names := new string[0];
      var s_vars_names := new string[0];
      var o_vars_names := var_names.ToArray;
      
      var n_vars := new real[0];
      var s_vars := new string[0];
      var o_vars := ArrFill(var_names.Count, object(nil));
      
      Main := Main.FixVarExprs(
        n_vars,
        s_vars,
        o_vars,
        
        n_vars_names,
        s_vars_names,
        o_vars_names
      );
      
      if Main is OptNExprBase then
        Result := new OptNExprWrapper(Main as OptNExprBase) else
      if Main is OptSExprBase then
        Result := new OptSExprWrapper(Main as OptSExprBase) else
        Result := new OptOExprWrapper(Main as OptOExprBase);
      Main.SetWrapper(Result);
      
      Result.n_vars := n_vars;
      Result.s_vars := s_vars;
      Result.o_vars := o_vars;
      
      Result.n_vars_names := n_vars_names;
      Result.s_vars_names := s_vars_names;
      Result.o_vars_names := o_vars_names;
      
    end;
    
  end;

static function OptExprWrapper.FromExpr(e: Expr; conv: OptExprBase->OptExprBase) :=
OptConverter.Create.GetOptExprWrapper(e, conv);

{$endregion OptConverter}

{$region Load}

function LoadFunc(br: System.IO.BinaryReader; t: byte; nv: array of real; sv: array of string; ov: array of object): IOptFuncExpr;
begin
  case t of
    
    1: Result := new OptFunc_Length(br, nv, sv, ov);
    2: Result := new OptFunc_Num(br, nv, sv, ov);
    3: Result := new OptFunc_KeyCode(br, nv, sv, ov);
    4: Result := new OptFunc_DeflyNum(br, nv, sv, ov);
    7: Result := new OptFunc_Floor(br, nv, sv, ov);
    8: Result := new OptFunc_Round(br, nv, sv, ov);
    9: Result := new OptFunc_Ceil(br, nv, sv, ov);
    
    5: Result := new OptFunc_Str(br, nv, sv, ov);
    6: Result := new OptFunc_CutStr(br, nv, sv, ov);
    
    else raise new InvalidFuncTException(t);
  end;
end;

static function OptExprBase.Load(br: System.IO.BinaryReader; nv: array of real; sv: array of string; ov: array of object): OptExprBase;
begin
  var t1 := br.ReadByte;
  var t2 := br.ReadByte;
  
  case t1 of
    
    1:
    case t2 of
      
      1: Result := new OptNLiteralExpr(br.ReadDouble);
      2: Result := new OptSLiteralExpr(br.ReadString);
      3: Result := new OptNullLiteralExpr;
      
      else raise new InvalidExprTException(t1,t2);
    end;
    
    2:
    case t2 of
      
      1: Result := new OptNNPlusExpr(br, nv, sv, ov);
      2: Result := new OptSSPlusExpr(br, nv, sv, ov);
      4: Result := new OptOPlusExpr(br, nv, sv, ov);
      
      else raise new InvalidExprTException(t1,t2);
    end;
    
    3:
    case t2 of
      
      1: Result := new OptNNMltExpr(br, nv, sv, ov);
      2: Result := new OptSNMltExpr(br, nv, sv, ov);
      4: Result := new OptOMltExpr(br, nv, sv, ov);
      
      else raise new InvalidExprTException(t1,t2);
    end;
    
    4:
    case t2 of
      
      1: Result := new OptNPowExpr(br, nv, sv, ov);
      
      else raise new InvalidExprTException(t1,t2);
    end;
    
    5: Result := LoadFunc(br, t2, nv, sv, ov) as OptExprBase;
    
    6:
    case t2 of
      
      1: Result := new OptNVarExpr(br, nv);
      2: Result := new OptSVarExpr(br, sv);
      3: Result := new OptOVarExpr(br, ov);
      
      else raise new InvalidExprTException(t1,t2);
    end;
    
    else raise new InvalidExprTException(t1,t2);
  end;
  
end;

static function OptExprWrapper.Load(br: System.IO.BinaryReader): OptExprWrapper;
begin
  
  var NumChecks := new Dictionary<string, ExprContextArea>;
  loop br.ReadInt32 do
    NumChecks[br.ReadString] := nil;//ToDo
  
  var StrChecks := new Dictionary<string, ExprContextArea>;
  loop br.ReadInt32 do
    StrChecks[br.ReadString] := nil;//ToDo
  
  var nvn := new string[br.ReadInt32];
  for var i := 0 to nvn.Length-1 do
    nvn[i] := br.ReadString;
  
  var svn := new string[br.ReadInt32];
  for var i := 0 to svn.Length-1 do
    svn[i] := br.ReadString;
  
  var ovn := new string[br.ReadInt32];
  for var i := 0 to ovn.Length-1 do
    ovn[i] := br.ReadString;
  
  var nv := ArrFill(nvn.Length, 0.0);
  var sv := ArrFill(svn.Length, '');
  var ov := ArrFill(ovn.Length, object(nil));
  
  var Main := OptExprBase.Load(br, nv, sv, ov);
  
  if Main is OptNExprBase then
    Result := new OptNExprWrapper(Main as OptNExprBase) else
  if Main is OptSExprBase then
    Result := new OptSExprWrapper(Main as OptSExprBase) else
    Result := new OptOExprWrapper(Main as OptOExprBase);
  
  
  
  Result.NumChecks := NumChecks;
  Result.StrChecks := StrChecks;
  
  Result.n_vars_names := nvn;
  Result.s_vars_names := svn;
  Result.o_vars_names := ovn;
  
  Result.n_vars := nv;
  Result.s_vars := sv;
  Result.o_vars := ov;
  
end;

{$endregion Load}

{$endregion Optimized}

end.