unit ExprParser;
//ToDo Больше регионов. БОЛЬШЕ
//ToDo Больше шорткатов при res=nil
//ToDo Сохранять контекст, чтоб при вызове ошибки показывало начало и конец выражения

//ToDo ClampLists:  Реализовать
//ToDo функции:     что то для нарезания строк
//ToDo ToString:    переделать для выражений (обоих видов)
//ToDo Optimize:    1^n=1 и т.п. НОООООО: 1^NaN=NaN . function IOptExpr.CanBeNaN: boolean; ? https://stackoverflow.com/questions/25506281/what-are-all-the-possible-calculations-that-could-cause-a-nan-in-python
//ToDo Optimize:    Много лишних вызовов Openup и Optimize (3;4 для каждого параметра). Это нужно, чтоб сначала OPlus=>NNPlus, а потомм уже раскрывать. Проверить производительность

//ToDo OptNilLiteralExpr:
// - Проверить чтоб всюду были проверки. В программе полно месте где идёт расчёт на то, что OExprBase констант нету

//ToDo Optimize:    оптимизация 5*(i+0) => 5*(+i) => 5*i
// - Если константа 1 и она =0 - удалить
// - Если осталось 1 выражение в скобочка - можно и открыть

//ToDo Проверить, не исправили ли issue компилятора
// - #533

interface

type
  {$region Exception's}
  
  {$region General}
  
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
  
  {$endregion General}
  
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
    inherited Create(sender, 'Resulting string had length {str_l}. Can''t save string with length > (2^31-1)=2147483647', KV('str_l', object(str_l)));
    
  end;
  CanNotMltNegStringException = class(ExprCompilingException)
    
    public constructor(sender: object; k: BigInteger) :=
    inherited Create(sender, 'Can''t muliply string and {k}, number can''t be negative', KV(''+'k', object(k)));
    
  end;
  ExpectedNumValueException = class(ExprCompilingException)
    
    public constructor(sender: object) :=
    inherited Create(sender, 'Expected Num Value');
    
  end;
  
  {$endregion Compiling}
  
  {$endregion Exception's}
  
  {$region General}
  
  IExpr = interface
    
    function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object;
    
  end;
  
  ExprContextArea = abstract class
    
    public debug_name: string;
    
    public function GetSubAreas: IList<ExprContextArea>; abstract;
    
  end;
  SimpleExprContextArea = class(ExprContextArea)
    
    public p1,p2: integer;
    
    public function GetSubAreas: IList<ExprContextArea>; override := new ExprContextArea[](self);
    
    public class function GetAllSimpleAreas(a: ExprContextArea): sequence of SimpleExprContextArea :=
    a.GetSubAreas.SelectMany(
      sa->
      (sa is SimpleExprContextArea)?
      Seq(sa as SimpleExprContextArea):
      GetAllSimpleAreas(sa)
    );
    
    public class function TryCombine(var a1: SimpleExprContextArea; a2: SimpleExprContextArea): boolean;
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
  ComplexExprContextArea = class(ExprContextArea)
    
    public sas: IList<ExprContextArea>;
    
    public function GetSubAreas: IList<ExprContextArea>; override := sas;
    
    public class function Combine(debug_name:string; params a: array of ExprContextArea): ExprContextArea;
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
    
    public class function Combine(params a: array of ExprContextArea): ExprContextArea :=
    Combine(
      a
      .Select(ca->ca.debug_name)
      .Where(s->s<>'')
      .JoinIntoString('+'),
      a
    );
    
  end;
  
  {$endregion General}
  
  {$region Load}
  
  Expr = abstract class(IExpr)
    
    public class function FromString(text:string): Expr :=
    FromString(text,1,text.Length);
    
    public class function FromString(text:string; i1,i2:integer): Expr;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object;
    begin
      Result := nil;
      var ToDo := 0;
      raise new CannotCalcLoadedExpr;
    end;
    
  end;
  
  NLiteralExpr = class(Expr)
    
    val: real;
    
    constructor(val: real) :=
    self.val := val;
    
    public function ToString: string; override :=
    $'{val}';
    
  end;
  SLiteralExpr = class(Expr)
    
    val: string;
    
    constructor(val: string) :=
    self.val := val;
    
    public function ToString: string; override :=
    $'"{val}"';
    
  end;
  
  ComplexExpr = abstract class(Expr)
    
    Positive := new List<Expr>;
    Negative := new List<Expr>;
    
  end;
  PlusExpr = class(ComplexExpr)
    
    public function ToString: string; override :=
    $'(+[{Positive.JoinIntoString(''+'')}]-[{Negative.JoinIntoString(''+'')}])';
    
  end;
  MltExpr = class(ComplexExpr)
    
    public function ToString: string; override :=
    $'(*[{Positive.JoinIntoString(''*'')}]/[{Negative.JoinIntoString(''*'')}])';
    
  end;
  PowExpr = class(ComplexExpr)
    
    public function ToString: string; override :=
    $'PowExpr({Positive.First}^[{Positive.Skip(1).JoinIntoString('','')}])';
    
  end;
  
  FuncExpr = class(Expr)
    
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
  VarExpr = class(Expr)
    
    name: string;
    
    constructor(name: string) :=
    self.name := name;
    
    public function ToString: string; override :=
    $'{name}';
    
  end;
  
  {$endregion Load}
  
  {$region Optimize}
  
  {$region Base}
  
  IOptExpr = interface
    
    function GetRes: Object;
    
    function GetResType: System.Type;
    
    function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr;
    
    function Openup: IOptExpr;
    
    function Optimize: IOptExpr;
    
    function GetCalc: Action0;
    
  end;
  OptExprBase = abstract class(IOptExpr)
    
    protected static nfi := new System.Globalization.NumberFormatInfo;
    
    protected static function AsStrExpr(o: OptExprBase): OptExprBase;//"a"+("b"+o1) => "a"+"b"+Str(o1)
    protected static function AsDefinitelyNumExpr(o: OptExprBase; ifnot: Action0 := nil): OptExprBase;//("a"*o1)*(5*3) => "a"*(DeflyNum(o1)*5*3)
    
    
    
    public function GetRes: object; abstract;
    
    public function GetResType: System.Type; abstract;
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; virtual := self;
    
    public function Openup: IOptExpr; virtual := self;
    
    public function Optimize: IOptExpr; virtual := self;
    
    public function GetCalc:Action0; virtual := nil;
    
    
    
    private property DebugType: System.Type read self.GetType;
    
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
  
  {$endregion Base}
  
  {$region Literal}
  
  IOptLiteralExpr = interface(IOptExpr)
    
  end;
  OptNLiteralExpr = class(OptNExprBase, IOptLiteralExpr)
    
    public constructor(val: real) :=
    self.res := val;
    
    public function ToString: string; override :=
    res.ToString(nfi);
    
  end;
  OptSLiteralExpr = class(OptSExprBase, IOptLiteralExpr)
    
    public constructor(val: string) :=
    self.res := val;
    
    public function ToString: string; override :=
    (res.Length < 100)?
    $'"{res}"':
    $'"{res.Substring(0,100)}..."[{res.Length}]';
    
  end;
  OptNullLiteralExpr = class(OptOExprBase, IOptLiteralExpr)
    
    public constructor :=
    self.res := nil;
    
    public function ToString: string; override :=
    'null';
    
  end;
  
  {$endregion Literal}
  
  {$region Plus}
  
  IOptPlusExpr = interface(IOptExpr)
    
    function GetPositive: sequence of OptExprBase;
    function GetNegative: sequence of OptExprBase;
    
  end;
  OptNNPlusExpr = class(OptNExprBase, IOptPlusExpr)
    
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
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive.Cast&<OptExprBase>;
    public function GetNegative: sequence of OptExprBase := Negative.Cast&<OptExprBase>;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Openup as OptNExprBase;
      
      if Positive.Concat(Negative).Any(oe->oe is IOptPlusExpr) then
      begin
        var res := new OptNNPlusExpr;
        
        foreach var oe in Positive do
          if oe is OptNNPlusExpr(var onnp) then
          begin
            res.Positive.AddRange(onnp.Positive);
            res.Negative.AddRange(onnp.Negative);
          end else
            res.Positive.Add(oe);
        
        foreach var oe in Negative do
          if oe is OptNNPlusExpr(var onnp) then
          begin
            res.Negative.AddRange(onnp.Positive);
            res.Positive.AddRange(onnp.Negative);
          end else
            res.Negative.Add(oe);
        
        Result := res;
      end else
        Result := self;
      
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize.Openup.Optimize as OptNExprBase;
      var pn := Positive.Concat(Negative);
      var lc :=  pn.Count(oe->oe is IOptLiteralExpr);
      
      if lc = Positive.Count+Negative.Count then
      begin
        var res := new OptNLiteralExpr;
        foreach var p in self.Positive do
          res.res += p.res;
        foreach var n in self.Negative do
          res.res -= n.res;
        Result := res;
      end else
      if lc < 2 then
        Result := self else
      begin
        var res := new OptNNPlusExpr;
        var n: real := 0;
        
        foreach var oe in Positive do
          if oe is IOptLiteralExpr then
            n += oe.res else
            res.Positive.Add(oe);
        
        foreach var oe in Negative do
          if oe is IOptLiteralExpr then
            n -= oe.res else
            res.Negative.Add(oe);
        
        if n <> 0 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( [{Positive.JoinIntoString(''+'')}]-[{Negative.JoinIntoString(''+'')}] )';
    
  end;
  OptSSPlusExpr = class(OptSExprBase, IOptPlusExpr)
    
    public Positive := new List<OptSExprBase>;
    
    private procedure Calc;
    begin
      res := '';
      
      for var i := 0 to Positive.Count-1 do
        res += Positive[i].res;
      
    end;
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive.Cast&<OptExprBase>;
    public function GetNegative: sequence of OptExprBase := new OptExprBase[0];
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptSExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptSExprBase;
      
      if Positive.Any(oe->oe is IOptPlusExpr) then
      begin
        var res := new OptSSPlusExpr;
        
        foreach var oe in Positive do
          if (oe is IOptPlusExpr(var ope)) and (ope.GetPositive.All(noe->noe is OptSExprBase)) then
            res.Positive.AddRange(ope.GetPositive.Select(oe->oe as OptSExprBase)) else
            res.Positive.Add(oe);
        
        Result := res;
      end else
        Result := self;
      
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptSExprBase;
      var lc := Positive.Count(oe->oe is IOptLiteralExpr);
      
      if lc = Positive.Count then
      begin
        var sb := new StringBuilder;
        foreach var oe in Positive do
          sb += oe.res;
        Result := new OptSLiteralExpr(sb.ToString);
      end else
      if lc < 2 then
        Result := self else
      begin
        var res := new OptSSPlusExpr;
        
        var sb := new StringBuilder;
        var ig := false;
        foreach var oe in Positive do
          if oe is IOptLiteralExpr then
          begin
            ig := true;
            sb += (oe as OptSLiteralExpr).res;
          end else
          if ig then
          begin
            ig := false;
            if sb.Length <> 0 then res.Positive.Add(new OptSLiteralExpr(sb.ToString));
            sb.Clear;
          end else
            res.Positive.Add(oe);
        
        if ig then
        begin
          //ig := false;
          if sb.Length <> 0 then res.Positive.Add(new OptSLiteralExpr(sb.ToString));
          sb.Clear;
        end;
        
        Result := res;
      end;
      
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( [{Positive.JoinIntoString(''+'')}]] )';
    
  end;
  OptSOPlusExpr = class(OptSExprBase, IOptPlusExpr)
    
    public Positive := new List<OptExprBase>;
    
    private procedure Calc;
    begin
      var sb := new StringBuilder;
      
      for var i := 0 to Positive.Count-1 do
      begin
        var r: object := Positive[i].GetRes;
        if r <> nil then
          if r is real(var n) then
            sb += n.ToString(nfi) else
            sb += r as string;
      end;
      
      res := sb.ToString;
    end;
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive;
    public function GetNegative: sequence of OptExprBase := new OptExprBase[0];
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptExprBase;
      
      if Positive.Any(oe->oe is IOptPlusExpr) then
      begin
        var res := new OptSOPlusExpr;
        
        foreach var oe in Positive do
          if oe is IOptPlusExpr(var ope) then
            res.Positive.AddRange(ope.GetPositive) else
            res.Positive.Add(oe);
        
        Result := res;
      end else
        Result := self;
      
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptExprBase;
      var lc :=  Positive.Count(oe->oe is IOptLiteralExpr);
      
      if lc = Positive.Count then
      begin
        var sb := new StringBuilder;
        
        foreach var oe in Positive do
          sb += oe.GetRes.ToString;
        
        Result := new OptSLiteralExpr(sb.ToString);
      end else
      if Positive.All(oe->(oe is OptSExprBase) or (oe is IOptLiteralExpr)) then
      begin
        var res := new OptSSPlusExpr;
        res.Positive := self.Positive.ConvertAll(oe->
        begin
          if oe is OptSExprBase then
            Result := oe as OptSExprBase else
          begin//oe is IOptLiteralExpr, but not OptSExprBase
            var o := oe.GetRes;
            if o is real then
              Result := new OptSLiteralExpr(real(o).ToString(nfi)) else
              Result := new OptSLiteralExpr('null');
          end;
        end);
        Result := res.Optimize;//Если можно сложить какие то константы
      end else
      if lc < 2 then
        Result := self else
      begin
        var res := new OptSOPlusExpr;
        
        var sb := new StringBuilder;
        var ig := false;
        foreach var oe in Positive do
          if oe is IOptLiteralExpr then
          begin
            ig := true;
            sb += oe.GetRes.ToString;
          end else
          if ig then
          begin
            ig := false;
            if sb.Length <> 0 then res.Positive.Add(new OptSLiteralExpr(sb.ToString));
            sb.Clear;
          end else
            res.Positive.Add(oe);
        
        if ig then
        begin
          //ig := false;
          if sb.Length <> 0 then res.Positive.Add(new OptSLiteralExpr(sb.ToString));
          sb.Clear;
        end;
        
        Result := res;
      end;
      
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'[ {Positive.JoinIntoString(''+'')} ]';
    
  end;
  OptOPlusExpr = class(OptOExprBase, IOptPlusExpr)
    
    public Positive := new List<OptExprBase>;
    public Negative := new List<OptExprBase>;
    
    private procedure Calc;
    begin
      if Positive.Concat(Negative).Any(oe->oe.GetRes is string) then
      begin
        if Negative.Any then raise new CannotSubStringExprException(self, Negative);
        var sb := new StringBuilder;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var r := Positive[i].GetRes;
          if r <> nil then
            if r is real(var n) then
              sb += n.ToString(nfi) else
              sb += r as string;
        end;
        
        res := sb.ToString;
      end else
      begin
        var nres: real := 0;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var r := Positive[i].GetRes;
          if r <> nil then
            nres += real(r);
        end;
        
        for var i := 0 to Negative.Count-1 do
        begin
          var r := Negative[i].GetRes;
          if r <> nil then
            nres -= real(r);
        end;
        
        res := nres;
      end;
    end;
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive;
    public function GetNegative: sequence of OptExprBase := Negative;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize.Openup.Optimize as OptExprBase;
      if Negative.Any(oe->oe is OptSExprBase) then raise new CannotSubStringExprException(self, Negative);
      
      if Positive.Any(oe->oe is OptSExprBase) then
      begin
        if Negative.Any then raise new CannotSubStringExprException(self, Negative);
        
        var res := new OptSOPlusExpr;
        res.Positive := self.Positive.ConvertAll(oe->
        begin
          if oe is IOptLiteralExpr then
          begin
            var res := oe.GetRes;
            if res is real then
              res := real(res).ToString(nfi) else
            if res = nil then
              res := '';
            Result := new OptSLiteralExpr(res as string) as OptExprBase;
          end else
            Result := oe;
        end);
        Result := res.Optimize;//Тут оптимизации не провели, только изменили тип
      end else
      begin
        var pn := Positive.Concat(Negative);
        
        if pn.All(oe->oe is OptNExprBase) then
        begin
          var res := new OptNNPlusExpr;
          res.Positive := self.Positive.ConvertAll(oe->oe as OptNExprBase);
          res.Negative := self.Negative.ConvertAll(oe->oe as OptNExprBase);
          Result := res.Optimize;//Тут оптимизации не провели, только изменили тип
        end else
          Result := self;//Даже если есть несколько констант подряд - их нельзя складывать, потому что числа и строки по разному складываются
      end;
      
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( [{Positive.JoinIntoString(''+'')}]-[{Negative.JoinIntoString(''+'')}] )';
    
  end;
  
  {$endregion Plus}
  
  {$region Mlt}
  
  IOptMltExpr = interface(IOptExpr)
    
    function AnyNegative: boolean;
    
    function GetPositive: sequence of OptExprBase;
    function GetNegative: sequence of OptExprBase;
    
  end;
  OptNNMltExpr = class(OptNExprBase, IOptMltExpr)
    
    public Positive := new List<OptNExprBase>;
    public Negative := new List<OptNExprBase>;
    
    private procedure Calc;
    begin
      res := 1;
      
      for var i := 0 to Positive.Count-1 do
        res *= Positive[i].res;
      
      for var i := 0 to Negative.Count-1 do
        res /= Negative[i].res;
      
    end;
    
    
    
    public function AnyNegative := Negative.Any;
    
    function GetPositive: sequence of OptExprBase := Positive.Select(oe->oe as OptExprBase);
    function GetNegative: sequence of OptExprBase := Negative.Select(oe->oe as OptExprBase);
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Openup as OptNExprBase;
      
      if Positive.Concat(Negative).Any(oe->oe is IOptMltExpr) then
      begin
        var res := new OptNNMltExpr;
        
        foreach var oe in Positive do
          if oe is OptNNPlusExpr(var onnp) then
          begin
            res.Positive.AddRange(onnp.Positive);
            res.Negative.AddRange(onnp.Negative);
          end else
            res.Positive.Add(oe);
        
        foreach var oe in Negative do
          if oe is OptNNPlusExpr(var onnp) then
          begin
            res.Negative.AddRange(onnp.Positive);
            res.Positive.AddRange(onnp.Negative);
          end else
            res.Negative.Add(oe);
        
        Result := res;
      end else
        Result := self;
      
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize.Openup.Optimize as OptNExprBase;
      
      var pn := Positive.Concat(Negative);
      var lc := pn.Count(oe->oe is IOptLiteralExpr);
      
      if lc = Positive.Count+Negative.Count then
      begin
        var res := new OptNLiteralExpr(1);
        
        foreach var oe in self.Positive do
          res.res *= oe.res;
        
        foreach var oe in self.Negative do
          res.res /= oe.res;
        
        Result := res;
      end else
      if lc < 2 then
        Result := self else
      begin
        var res := new OptNNMltExpr;
        var n: real := 1;
        
        foreach var oe in self.Positive do
          if oe is IOptLiteralExpr then
            n *= oe.res else
            res.Positive.Add(oe);
        
        foreach var oe in self.Negative do
          if oe is IOptLiteralExpr then
            n /= oe.res else
            res.Negative.Add(oe);
        
        if n <> 1 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( [{Positive.JoinIntoString(''*'')}]/[{Negative.JoinIntoString(''*'')}] )';
    
  end;
  OptSNMltExpr = class(OptSExprBase, IOptMltExpr)
    
    public Base: OptSExprBase;
    public Positive: OptNExprBase;
    
    private procedure Calc;
    begin
      var r := Base.res;
      var cr := Positive.res;
      var ci := BigInteger.Create(cr+0.5);
      if ci < 0 then raise new CanNotMltNegStringException(self, ci);
      var cap := ci * r.Length;
      if cap > integer.MaxValue then raise new TooBigStringException(self, cap);
      var sb := new StringBuilder(integer(cap));
      loop integer(ci) do sb += r;
      res := sb.ToString;
    end;
    
    
    
    public function AnyNegative := false;
    
    function GetPositive: sequence of OptExprBase := new OptExprBase[](Base, Positive);
    function GetNegative: sequence of OptExprBase := new OptExprBase[0];
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      Base := Base.FixVarExprs(sn,ss,so,nn,ns,no) as OptSExprBase;
      Positive := Positive.FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      Base := Base.Openup as OptSExprBase;
      Positive := Positive.Openup as OptNExprBase;
      
      var res := self;
      
      if res.Base is IOptMltExpr(var ome) then
      begin
        var nres := new OptSNMltExpr;
        var p := new OptNNMltExpr;
        
        foreach var oe in ome.GetPositive do
          if oe is OptSExprBase then
            if nres.Base = nil then
              nres.Base := oe as OptSExprBase else
              raise new CannotMltALotStringsException(self, new object[](nres.Base, oe)) else
          if oe is OptNExprBase then
            p.Positive.Add(oe as OptNExprBase) else
            p.Positive.Add(AsDefinitelyNumExpr(oe, procedure->raise new CannotMltALotStringsException(self,new object[](Base, oe))) as OptNExprBase);
        
        if res.Positive is OptNNMltExpr(var onme) then
          p.Positive.AddRange(onme.Positive) else
          p.Positive.Add(res.Positive);
        
        nres.Positive := p;
        res := nres;
      end;
      
      Result := res;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      Base := Base.Optimize.Openup.Optimize as OptSExprBase;
      Positive := Positive.Optimize.Openup.Optimize as OptNExprBase;
      
      if (Positive is IOptMltExpr(var ome)) and ome.AnyNegative then raise new CannotDivStringExprException(self, ome.GetPositive.Prepend(Base as OptExprBase), ome.GetNegative);
      
      if
        (Base is IOptLiteralExpr) and
        (Positive is IOptLiteralExpr)
      then
      begin
        var r := Base.res;
        var cr := Positive.res;
        var ci := BigInteger.Create(cr+0.5);
        if ci < 0 then raise new CanNotMltNegStringException(self, ci);
        var cap := ci * r.Length;
        if cap > integer.MaxValue then raise new TooBigStringException(self, cap);
        var sb := new StringBuilder(integer(cap));
        loop integer(ci) do sb += r;
        Result := new OptSLiteralExpr(sb.ToString);
      end else
        Result := self;
    end;
    
    public function GetCalc:Action0; override;
    begin
      Result += Base.GetCalc();
      Result += Positive.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( {Base}*{Positive} )';
    
  end;
  OptSOMltExpr = class(OptSExprBase, IOptMltExpr)
    
    public Base: OptSExprBase;
    public Positive: OptExprBase;
    
    private procedure Calc;
    begin
      var r := Base.res;
      var co := Positive.GetRes;
      if co = nil then
      begin
        res := '';
        exit;
      end;
      if not (co is real) then raise new CannotMltALotStringsException(self, new object[](Base, co));
      var ci := BigInteger.Create(real(co)+0.5);
      if ci < 0 then raise new CanNotMltNegStringException(self, ci);
      var cap := ci * r.Length;
      if cap > integer.MaxValue then raise new TooBigStringException(self, cap);
      var sb := new StringBuilder(integer(cap));
      loop integer(ci) do sb += r;
      res := sb.ToString;
    end;
    
    
    
    public function AnyNegative := false;
    
    function GetPositive: sequence of OptExprBase := new OptExprBase[](Base, Positive);
    function GetNegative: sequence of OptExprBase := new OptExprBase[0];
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      Base := Base.FixVarExprs(sn,ss,so,nn,ns,no) as OptSExprBase;
      Positive := Positive.FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      Base := Base.Openup as OptSExprBase;
      Positive := Positive.Openup as OptNExprBase;
      
      if Base is IOptMltExpr(var ome) then
      begin
        var res := new OptSNMltExpr;
        var res_copy := res;//ToDo убрать, #533. + даёт лишнее предупреждение изза #1315 XD
        var p := new OptNNMltExpr;
        
        foreach var oe in ome.GetPositive do
          if oe is OptSExprBase then
            if res.Base = nil then
              res.Base := oe as OptSExprBase else
              raise new CannotMltALotStringsException(self, new object[](res.Base, oe)) else
          if oe is OptNExprBase then
            p.Positive.Add(oe as OptNExprBase) else
            p.Positive.Add(AsDefinitelyNumExpr(oe, procedure->raise new CannotMltALotStringsException(self,new object[](res_copy.Base, oe))) as OptNExprBase);
        
        if res.Positive is OptNNMltExpr(var onme) then
          p.Positive.AddRange(onme.Positive) else
          p.Positive.Add(res.Positive);
        
        res.Positive := p;
        Result := res;
      end else
        Result := self;
      
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      Base := Base.Optimize.Openup.Optimize as OptSExprBase;
      Positive := Positive.Optimize.Openup.Optimize as OptExprBase;
      
      if Positive is OptSExprBase then raise new CannotMltALotStringsException(self, new object[](Base, Positive));
      if (Positive is IOptMltExpr(var ome)) and ome.AnyNegative then raise new CannotDivStringExprException(self, ome.GetPositive.Prepend(Base as OptExprBase), ome.GetNegative);
      
      if Positive is OptNExprBase then
      begin
        var res := new OptSNMltExpr;
        res.Base := self.Base;
        res.Positive := self.Positive as OptNExprBase;
        Result := res.Optimize;
      end else
        Result := self;
    end;
    
    public function GetCalc:Action0; override;
    begin
      Result += Base.GetCalc();
      Result += Positive.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( {Base}*{Positive} )';
    
  end;
  OptOMltExpr = class(OptOExprBase, IOptMltExpr)
    
    public Positive := new List<OptExprBase>;
    public Negative := new List<OptExprBase>;
    
    private procedure Calc;
    begin
      if Positive.Concat(Negative).Any(oe->oe.GetRes is string) then
      begin
        if Negative.Any then raise new CannotDivStringExprException(self, Positive, Negative);
        var n := 1.0;
        var nres: string := nil;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var ro := Positive[i].GetRes;
          if ro is string then
            if nres = nil then
              nres := ro as string else
              raise new CannotMltALotStringsException(self, Positive.Select(oe->oe.GetRes).Where(r->r is string)) else
            begin
              if ro = nil then
              begin
                res := '';
                exit;
              end;
              n *= real(ro);
            end;
        end;
        
        var ci := BigInteger.Create(n+0.5);
        if ci < 0 then raise new CanNotMltNegStringException(self,ci);
        var cap := ci * nres.Length;
        if cap > integer.MaxValue then raise new TooBigStringException(self,cap);
        var sb := new StringBuilder(integer(cap));
        loop integer(ci) do sb += nres;
        res := sb.ToString;
      end else
      begin
        var nres := 1.0;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var ro := Positive[i].GetRes;
          if ro = nil then
            nres := 0.0 else
            nres *= real(ro);
        end;
        
        for var i := 0 to Negative.Count-1 do
        begin
          var ro := Negative[i].GetRes;
          if ro = nil then
            nres /= 0.0 else
            nres /= real(ro);
        end;
        
        res := nres;
      end;
    end;
    
    
    
    public function AnyNegative := Negative.Any;
    
    function GetPositive: sequence of OptExprBase := Positive;
    function GetNegative: sequence of OptExprBase := Negative;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Openup as OptExprBase;
      
      if Positive.Concat(Negative).Any(oe->oe is IOptMltExpr) then
      begin
        var res := new OptOMltExpr;
        
        foreach var oe in Positive do
          if oe is IOptPlusExpr(var onnp) then
          begin
            res.Positive.AddRange(onnp.GetPositive);
            res.Negative.AddRange(onnp.GetNegative);
          end else
            res.Positive.Add(oe);
        
        foreach var oe in Negative do
          if oe is IOptPlusExpr(var onnp) then
          begin
            res.Negative.AddRange(onnp.GetPositive);
            res.Positive.AddRange(onnp.GetNegative);
          end else
            res.Negative.Add(oe);
        
        Result := res;
      end else
        Result := self;
      
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize.Openup.Optimize as OptExprBase;
      
      var pn := Positive.Concat(Negative);
      var sc := pn.Count(oe->oe is OptSExprBase);
      if sc > 1 then raise new CannotMltALotStringsException(self, pn.Where(oe->oe is OptSExprBase));
      
      if sc = 1 then
      begin
        if Negative.Any then
          raise new CannotDivStringExprException(self, Positive, Negative);
        var res := new OptSOMltExpr;
        var rp := new OptOMltExpr;
        
        foreach var oe in Positive do
          if oe is OptSExprBase(var ose) then
            res.Base := ose else
            rp.Positive.Add(oe);
        
        res.Positive := rp;
        Result := res.Optimize;
      end else
      if pn.All(oe->oe is OptNExprBase) then
      begin
        var res := new OptNNMltExpr;
        res.Positive := self.Positive.ConvertAll(oe->oe as OptNExprBase);
        res.Negative := self.Negative.ConvertAll(oe->oe as OptNExprBase);
        Result := res.Optimize;
      end else
      if pn.Count(oe->oe is IOptLiteralExpr) < 2 then
        Result := self else
      begin
        var res := new OptOMltExpr;
        var n: real := 1;
        
        foreach var oe in self.Positive do
          if oe is OptNExprBase(var ane) then
            n *= ane.res else
            res.Positive.Add(oe);
        
        foreach var oe in self.Negative do
          if oe is OptNExprBase(var ane) then
            n /= ane.res else
            res.Negative.Add(oe);
        
        if n <> 1 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
      
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive.Concat(Negative) do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'( [{Positive.JoinIntoString(''*'')}]/[{Negative.JoinIntoString(''*'')}] )';
    
  end;
  
  {$endregion Mlt}
  
  {$region Pow}
  
  IOptPowExpr = interface(IOptExpr)
    
    function GetPositive: sequence of OptExprBase;
    
  end;
  OptNPowExpr = class(OptNExprBase, IOptPowExpr)
    
    public Positive := new List<OptNExprBase>;
    
    private procedure Calc;
    begin
      res := 1;
      
      for var i := 1 to Positive.Count-1 do
        res *= Positive[i].res;
      
      res := Power(Positive[0].res, res);
    end;
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive.Select(oe->oe as OptExprBase);
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptNExprBase;
      
      if Positive[0] is IOptPowExpr(var ope) then
      begin
        var res := new OptNPowExpr;
        
        foreach var oe in ope.GetPositive do
          if oe is OptNExprBase then
            res.Positive.Add(oe as OptNExprBase) else
            res.Positive.Add(AsDefinitelyNumExpr(oe) as OptNExprBase);
        
        res.Positive.AddRange(self.Positive.Skip(1));
        Result := res;
      end else
        Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptNExprBase;
      
      var lc := Positive.Count(oe->oe is IOptLiteralExpr);
      
      if lc = Positive.Count then
      begin
        var res := new OptNLiteralExpr;
        
        res.res := Positive[0].res;
        foreach var oe in Positive.Skip(1) do
          res.res := Power(res.res, oe.res);
        
        Result := res;
      end else
      if lc < 2 then
        Result := self else
      if Positive[0] is IOptLiteralExpr then
      begin
        var res := new OptNPowExpr;
        
        res.Positive.Add(self.Positive[0]);
        foreach var oe in self.Positive.Skip(1) do
          if oe is IOptLiteralExpr then
            res.res := Power(res.res, oe.res) else
            res.Positive.Add(oe);
        
        Result := res;
      end else
      begin
        var res := new OptNPowExpr;
        var n: real := 1;
        
        res.Positive.Add(self.Positive[0]);
        foreach var oe in self.Positive.Skip(1) do
          if oe is IOptLiteralExpr then
            n *= oe.res else
            res.Positive.Add(oe);
        
        if n <> 1 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'PowExpr({Positive.First}^[{Positive.Skip(1).JoinIntoString('','')}])';
    
  end;
  OptOPowExpr = class(OptNExprBase, IOptPowExpr)
    
    public Positive := new List<OptExprBase>;
    
    private procedure Calc;
    begin
      var nres := 1.0;
      
      for var i := 1 to Positive.Count-1 do
      begin
        var ro := Positive[i].GetRes;
        if ro = nil then
          nres := 0 else
        if ro is string then
          raise new CannotPowStringException(self) else
          nres *= real(ro);
      end;
      
      var ro := Positive[0].GetRes;
      if ro = nil then ro := 0.0 else
      if ro is string then raise new CannotPowStringException(self);
      res := Power(real(ro), nres);
    end;
    
    
    
    public function GetPositive: sequence of OptExprBase := Positive;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Openup as OptNExprBase;
      
      if Positive[0] is IOptPowExpr(var ope) then
      begin
        var res := new OptOPowExpr;
        
        res.Positive.AddRange(ope.GetPositive);
        res.Positive.AddRange(self.Positive.Skip(1));
        
        Result := res;
      end else
        Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize.Openup.Optimize as OptExprBase;
      
      if Positive.Any(oe->oe is OptSExprBase) then raise new CannotPowStringException(self);
      
      if Positive.All(oe->oe is OptNExprBase) then
      begin
        var res := new OptNPowExpr;
        res.Positive := self.Positive.ConvertAll(oe->oe as OptNExprBase);
        Result := res.Optimize;
      end else
      if Positive.Count(oe->oe is IOptLiteralExpr) < 2 then
        Result := self else
      if Positive[0] is OptNLiteralExpr(var onl) then
      begin
        var res := new OptOPowExpr;
        var rb := new OptNLiteralExpr(onl.res);
        
        res.Positive.Add(nil);
        foreach var oe in Positive.Skip(1) do
          if oe is OptNLiteralExpr(var onl2) then
            rb.res := Power(rb.res, onl2.res) else
            res.Positive.Add(oe);
        
        res.Positive[0] := rb;
        Result := res;
      end else
      begin
        var res := new OptOPowExpr;
        var n: real := 1;
        
        res.Positive.Add(self.Positive[0]);
        foreach var oe in Positive.Skip(1) do
          if oe is OptNLiteralExpr(var onl) then
            n *= onl.res else
            res.Positive.Add(oe);
        
        if n <> 1 then res.Positive.Add(new OptNLiteralExpr(n));
        Result := res;
      end;
      
    end;
    
    public function GetCalc:Action0; override;
    begin
      foreach var oe in Positive do
        Result += oe.GetCalc();
      Result += self.Calc;
    end;
    
    public function ToString: string; override :=
    $'PowExpr({Positive.First}^[{Positive.Skip(1).JoinIntoString('','')}])';
    
  end;
  
  {$endregion Pow}
  
  {$region Func}
  
  IOptFuncExpr = interface(IOptExpr)
    
    procedure CheckParams;
    
  end;
  OptNFuncExpr = abstract class(OptNExprBase, IOptFuncExpr)
    
    public name: string;
    public par: array of OptExprBase;
    
    
    
    public function GetTps: array of System.Type; abstract;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    protected procedure CheckParamsBase;
    begin
      var tps := GetTps;
      if par.Length <> tps.Length then raise new InvalidFuncParamCountException(self, self.name, tps.Length, par.Length);
      
      for var i := 0 to tps.Length-1 do
        if (par[i].GetResType <> tps[i]) and (par[i].GetResType <> typeof(Object)) then
          raise new InvalidFuncParamTypesException(self, self.name, i, tps[i], par[i].GetResType);
    end;
    
    public procedure CheckParams; abstract;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].Optimize.Openup.Optimize as OptExprBase;
      CheckParams;
      if par.All(oe->oe is IOptLiteralExpr) then
      begin
        var res := new OptNLiteralExpr;
        GetCalc()();
        res.res := self.res;//-_-
        Result := res;
      end else
        Result := self;
    end;
    
    public function GetCalc: Action0; override;
    begin
      foreach var p in par do
        Result += p.GetCalc();
    end;
    
    public function ToString: string; override :=
    '{n}'+$'{name}({par.JoinIntoString('','')})';
    
  end;
  OptSFuncExpr = abstract class(OptSExprBase, IOptFuncExpr)
    
    public name: string;
    public par: array of OptExprBase;
    
    
    
    public function GetTps: array of System.Type; abstract;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    protected procedure CheckParamsBase;
    begin
      var tps := GetTps;
      if par.Length <> tps.Length then raise new InvalidFuncParamCountException(self, self.name, tps.Length, par.Length);
      
      for var i := 0 to tps.Length-1 do
        if par[i].GetResType <> tps[i] then
          raise new InvalidFuncParamTypesException(self, self.name, i, tps[i], par[i].GetResType);
    end;
    
    public procedure CheckParams; abstract;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].Optimize.Openup.Optimize as OptExprBase;
      CheckParams;
      if par.All(oe->oe is IOptLiteralExpr) then
      begin
        var res := new OptSLiteralExpr;
        GetCalc()();
        res.res := self.res;//-_-
        Result := res;
      end else
        Result := self;
    end;
    
    public function GetCalc: Action0; override;
    begin
      foreach var p in par do
        Result += p.GetCalc();
    end;
    
    public function ToString: string; override :=
    '{s}'+$'{name}({par.JoinIntoString('','')})';
    
  end;
  
  {$endregion Func}
  
  {$region Var}
  
  IOptVarExpr = interface(IOptExpr)
    
  end;
  OptNVarExpr = class(OptNExprBase, IOptVarExpr)
    
    public souce: array of real;
    public id: integer;
    
    public procedure Calc :=
    res := souce[id];
    
    public function GetCalc:Action0; override :=
    self.Calc;
    
    public function ToString: string; override :=
    $'num_var[{id}]';
    
  end;
  OptSVarExpr = class(OptSExprBase, IOptVarExpr)
    
    public souce: array of string;
    public id: integer;
    
    public procedure Calc :=
    res := souce[id];
    
    public function GetCalc:Action0; override :=
    self.Calc;
    
    public function ToString: string; override :=
    $'str_var[{id}]';
    
  end;
  OptOVarExpr = class(OptOExprBase, IOptVarExpr)
    
    public souce: array of object;
    public id: integer;
    
    public procedure Calc :=
    res := souce[id];
    
    public function GetCalc:Action0; override :=
    self.Calc;
    
    public function ToString: string; override :=
    $'obj_var[{id}]';
    
  end;
  UnOptNVarExpr = class(OptNExprBase, IOptVarExpr)
    
    public name: string;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      var id := nn.IndexOf(self.name);
      if id = -1 then
        Result := new OptNLiteralExpr(0) else
      begin
        var res := new OptNVarExpr;
        res.souce := sn;
        res.id := id;
        Result := res;
      end;
    end;
    
    public constructor(name: string) :=
    self.name := name;
    
    public function ToString: string; override :=
    $'int_var[?]';
    
  end;
  UnOptSVarExpr = class(OptSExprBase, IOptVarExpr)
    
    public name: string;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      var id := ns.IndexOf(self.name);
      if id = -1 then
        Result := new OptSLiteralExpr('') else
      begin
        var res := new OptSVarExpr;
        res.souce := ss;
        res.id := id;
        Result := res;
      end;
    end;
    
    public constructor(name: string) :=
    self.name := name;
    
    public function ToString: string; override :=
    $'str_var[?]';
    
  end;
  UnOptOVarExpr = class(OptOExprBase, IOptVarExpr)
    
    public name: string;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      var id := no.IndexOf(self.name);
      if id = -1 then
        Result := new OptNLiteralExpr(0) else
      begin
        var res := new OptOVarExpr;
        res.souce := so;
        res.id := id;
        Result := res;
      end;
    end;
    
    public constructor(name: string) :=
    self.name := name;
    
    public function ToString: string; override :=
    $'obj_var[?]';
    
  end;
  
  {$endregion Var}
  
  {$region Wrappers}
  
  OptExprWrapper = abstract class(IExpr)
    
    public n_vars: array of real;
    public s_vars: array of string;
    public o_vars: array of object;
    
    public n_vars_names := new List<string>;
    public s_vars_names := new List<string>;
    public o_vars_names := new List<string>;
    
    public MainCalcProc: procedure;
    
    protected procedure StartCalc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>);
    begin
      
      for var i := 0 to n_vars_names.Count-1 do
      begin
        var name := n_vars_names[i];
        if n_vars.ContainsKey(name) then
          self.n_vars[i] := n_vars[name] else
          self.n_vars[i] := 0;
      end;
      
      for var i := 0 to s_vars_names.Count-1 do
      begin
        var name := s_vars_names[i];
        if s_vars.ContainsKey(name) then
          self.s_vars[i] := s_vars[name] else
          self.s_vars[i] := '';
      end;
      
      for var i := 0 to o_vars_names.Count-1 do
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
    
    public class function FromExpr(e: Expr; n_vars_names, s_vars_names: List<string>): OptExprWrapper;
    
    public constructor;
    begin
      
    end;
    
  end;
  OptNExprWrapper = class(OptExprWrapper)
    
    public Main: OptNExprBase;
    
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
    
    public function ToString: string; override :=
    Main.ToString;
    
  end;
  OptSExprWrapper = class(OptExprWrapper)
    
    public Main: OptSExprBase;
    
    public function CalcN(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): string;
    begin
      
      inherited StartCalc(n_vars, s_vars);
      
      Result := Main.res;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>): object; override :=
    CalcN(n_vars, s_vars);
    
    public constructor(Main: OptSExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
    public function ToString: string; override :=
    Main.ToString;
    
  end;
  OptOExprWrapper = class(OptExprWrapper)
    
    public Main: OptOExprBase;
    
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
    
    public function ToString: string; override :=
    Main.ToString;
    
  end;
  
  {$endregion Wrappers}
  
  {$endregion Optimize}
  
implementation

{$region Load}

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
    
    if self[from] = '(' then
      from := self.FindNext(from+1,')') else
    if self[from] = '"' then
      from := self.FindNext(from+1,'"');
    
    from += 1;
    
  end;
end;

type
  ArithOp = (none, plus, minus, mlt, divide, pow);
  ExprCoord = record
    Op: ArithOp;
    i1,i2: integer;
  end;

function GetSimpleExpr(text:string; si1,si2: integer): Expr;
begin
  
  if si1 > si2 then raise new EmptyExprException(text, si1) else
  if text[si1] = '(' then Result := Expr.FromString(text, si1+1, si2-1) else
  if text[si1] = '"' then
  begin
    var i := text.FindNext(si1+1, '"');
    if i <> si2 then raise new ExtraCharsException(text, si1, si2, i);
    Result := new SLiteralExpr(text.Substring(si1,si2-si1-1));
  end else
  begin
    var str := text.Substring(si1-1,si2-si1+1);
    var r: real;
    
    if real.TryParse(str,System.Globalization.NumberStyles.AllowDecimalPoint,new System.Globalization.NumberFormatInfo, r) then
      Result := new NLiteralExpr(r) else
    if str.All(ch->ch.IsLetter or ch.IsDigit or (ch='_')) then
      Result := new VarExpr(str) else
    if str.Contains('(') and (str.FindNext(str.IndexOf('(')+2,')') = si2-si1+1) then
    begin
      var im := str.IndexOf('(')+1;
      Result := new FuncExpr(str.Substring(0, im-1), str.Substring(im,str.Length-im-1).Split(','));
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

class function Expr.FromString(text:string; i1, i2:integer): Expr;
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
      i1 := text.FindNext(i1+1, '"')+1;
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

{$endregion Load}

{$region Optimize}

type
  OptFunc_Length = class(OptNFuncExpr)
    
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
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(string), pr=nil?nil:pr.GetType);
    end;
    
    public function GetCalc: Action0; override;
    begin
      Result := 
        inherited GetCalc()+
        Calc;
    end;
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Length';
      CheckParams;
    end;
    
  end;
  OptFunc_Num = class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(string)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if not ( (pr is string) and (TryStrToFloat(pr as string, self.res)) ) then
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(string), pr=nil?nil:pr.GetType);
    end;
    
    public function GetCalc: Action0; override;
    begin
      Result := 
        inherited GetCalc()+
        Calc;
    end;
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Num';
      CheckParams;
    end;
    
  end;
  OptFunc_Ord = class(OptNFuncExpr)
    
    public procedure CheckParams; override :=
    CheckParamsBase;
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(string)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if not ( (pr is string(var s)) and (s.Length = 1) ) then
        self.res := word(s[1]) else
        raise new InvalidFuncParamTypesException(self, self.name, 0, typeof(string), pr=nil?nil:pr.GetType);
    end;
    
    public function GetCalc: Action0; override;
    begin
      Result := 
        inherited GetCalc()+
        Calc;
    end;
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Ord';
      CheckParams;
    end;
    
  end;
  OptFunc_DeflyNum = class(OptNFuncExpr)
    
    ifnot: Action0;
    
    public procedure CheckParams; override :=
    if par.Length <> 1 then
      raise new InvalidFuncParamCountException(self, self.name, 1, par.Length) else
    if par[0] is OptSExprBase then
      ifnot();
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(Object)
    );
    
    public procedure Calc;
    begin
      var o := par[0].GetRes;
      if o is real then
        self.res := real(o) else
      if o = nil then
        self.res := 0 else
        ifnot();
    end;
    
    private procedure DefaultIfNot :=
    raise new ExpectedNumValueException(self);
    
    
    
    public function Optimize: IOptExpr; override;
    begin
      CheckParams;
      par[0] := par[0].Optimize.Openup.Optimize as OptExprBase;
      CheckParams;
      
      if par[0] is OptNExprBase then
        Result := par[0] else
      if par[0] is IOptLiteralExpr then
      begin
        var o := par[0].GetRes;
        if o is real then
          Result := new OptNLiteralExpr(real(o)) else
          Result := new OptNLiteralExpr(0);
      end else
        Result := self;
      
    end;
    
    public function GetCalc: Action0; override;
    begin
      Result := 
        inherited GetCalc()+
        Calc;
    end;
    
    public constructor(par: array of OptExprBase; ifnot: procedure := nil);
    begin
      self.par := par;
      self.name := 'DeflyNum';
      self.ifnot := ifnot=nil?DefaultIfNot:ifnot;
      CheckParams;
    end;
    
  end;
  
  OptFunc_Str = class(OptSFuncExpr)
    
    public procedure CheckParams; override :=
    if par.Length <> 1 then
      raise new InvalidFuncParamCountException(self, self.name, 1, par.Length);
    
    public function GetTps: array of System.Type; override :=
    new System.Type[](
      typeof(Object)
    );
    
    public procedure Calc;
    begin
      var o := par[0].GetRes;
      if o is real(var n) then
        self.res := n.ToString(nfi) else
      if o = nil then
        self.res := '' else
        self.res := o as string;
    end;
    
    
    
    public function Optimize: IOptExpr; override;
    begin
      CheckParams;
      par[0] := par[0].Optimize.Openup.Optimize as OptExprBase;
      
      if par[0] is OptSExprBase then
        Result := par[0] else
      if par[0] is IOptLiteralExpr then
      begin
        var o := par[0].GetRes;
        if o is real(var n) then
          Result := new OptSLiteralExpr(n.ToString(nfi)) else
          Result := new OptSLiteralExpr('');
      end else
        Result := self;
      
    end;
    
    public function GetCalc: Action0; override;
    begin
      Result := 
        inherited GetCalc()+
        Calc;
    end;
    
    public constructor(par: array of OptExprBase);
    begin
      self.par := par;
      self.name := 'Str';
      CheckParams;
    end;
    
  end;
  
class function OptExprBase.AsStrExpr(o: OptExprBase): OptExprBase :=
new OptFunc_Str(new OptExprBase[](o));

class function OptExprBase.AsDefinitelyNumExpr(o: OptExprBase; ifnot: Action0): OptExprBase :=
new OptFunc_DeflyNum(new OptExprBase[](o), ifnot);

type
  OptConverter = static class//ToDo #1279
    
    class g_n_vars_names: List<string>;
    class g_s_vars_names: List<string>;
    
    class l_n_vars_names: List<string>;
    class l_s_vars_names: List<string>;
    class l_o_vars_names: List<string>;
    
    
    
    class FuncTypes := new Dictionary<string, Func<array of OptExprBase,IOptFuncExpr>>;
    
    class constructor;
    begin
      
      FuncTypes.Add('length', par->new OptFunc_Length(par));
      FuncTypes.Add('Num', par->new OptFunc_Num(par));
      FuncTypes.Add('Ord', par->new OptFunc_Ord(par));
      FuncTypes.Add('DeflyNum', par->new OptFunc_DeflyNum(par));
      
      FuncTypes.Add('Str', par->new OptFunc_Str(par));
      
    end;
    
    class function GetOptLiteralExpr(e: NLiteralExpr) :=
    new OptNLiteralExpr(e.val);
    
    class function GetOptLiteralExpr(e: SLiteralExpr) :=
    new OptSLiteralExpr(e.val);
    
    class function GetOptPlusExpr(e: PlusExpr): IOptPlusExpr;
    begin
      var res := new OptOPlusExpr;
      res.Positive := e.Positive.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      res.Negative := e.Negative.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      Result := res;
    end;
    
    class function GetOptMltExpr(e: MltExpr): IOptMltExpr;
    begin
      var res := new OptOMltExpr;
      res.Positive := e.Positive.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      res.Negative := e.Negative.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      Result := res;
    end;
    
    class function GetOptPowExpr(e: PowExpr): IOptPowExpr;
    begin
      if e.Negative.Any then raise new UnexpectedNegativePow(e);
      
      var res := new OptOPowExpr;
      res.Positive := e.Positive.ConvertAll(se->GetOptExpr(se) as OptExprBase);
      Result := res;
    end;
    
    class function GetOptFuncExpr(e: FuncExpr): IOptFuncExpr;
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
    
    class function GetOptVarExpr(e: VarExpr): IOptExpr;
    begin
      
      case e.name of
      'null': Result := new OptNullLiteralExpr;
      else
        if g_n_vars_names.Contains(e.name) then
        begin
          Result := new UnOptNVarExpr(e.name);
          l_n_vars_names.Add(e.name);
        end else
        if g_s_vars_names.Contains(e.name) then
        begin
          Result := new UnOptSVarExpr(e.name);
          l_s_vars_names.Add(e.name);
        end else
        begin
          Result := new UnOptOVarExpr(e.name);
          l_o_vars_names.Add(e.name);
        end;
      end;
      
    end;
    
    class function GetOptExpr(e: Expr): IOptExpr;
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
    
    class function GetOptExprWrapper(e: Expr; g_n_vars_names, g_s_vars_names: List<string>): OptExprWrapper;
    begin
      
      OptConverter.g_n_vars_names := g_n_vars_names;
      OptConverter.g_s_vars_names := g_s_vars_names;
      
      l_n_vars_names := new List<string>;
      l_s_vars_names := new List<string>;
      l_o_vars_names := new List<string>;
      
      var Main := GetOptExpr(e);
      
      var n_vars := ArrFill(l_n_vars_names.Count, 0.0);
      var s_vars := ArrFill(l_s_vars_names.Count, '');
      var o_vars := ArrFill(l_o_vars_names.Count, object(nil));
      
      Main := Main.FixVarExprs(n_vars, s_vars, o_vars, l_n_vars_names, l_s_vars_names, l_o_vars_names);
      Main := Main.Optimize.Openup.Optimize;
      
      if Main is OptNExprBase then
        Result := new OptNExprWrapper(Main as OptNExprBase) else
      if Main is OptSExprBase then
        Result := new OptSExprWrapper(Main as OptSExprBase) else
        Result := new OptOExprWrapper(Main as OptOExprBase);
      
      Result.n_vars_names := l_n_vars_names;
      Result.s_vars_names := l_s_vars_names;
      Result.o_vars_names := l_o_vars_names;
      
      Result.n_vars := n_vars;
      Result.s_vars := s_vars;
      Result.o_vars := o_vars;
      
      
      
      Result.MainCalcProc := Main.GetCalc;
      
    end;
    
  end;

class function OptExprWrapper.FromExpr(e: Expr; n_vars_names, s_vars_names: List<string>) :=
OptConverter.GetOptExprWrapper(e, n_vars_names, s_vars_names);

{$endregion Optimize}

end.