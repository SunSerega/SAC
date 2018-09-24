unit ExprParser;
//ToDo программа - тестировщик

//ToDo Исключения:  Переделать все исключение (надо общий source и т.п.)
//ToDo Исключения:  Рантайм исключения как отдельный набор
//ToDo Calc:        Обрабатывать значения nil - как строку "" и число 0 сразу
//ToDo Openup:      Реализовать. "a"+(5+3) нельзя открывать
//ToDo Optimize:    ClampLists
//ToDo Optimize:    вызов функции для литералов

//ToDo Optimize:    оптимизация 5*(i+0) => 5*(+i) => 5*i
// -Если константа 1 и она =0 - удалить
// -Если осталось 1 выражение в скобочка - можно и открыть

interface

type
  {$region Exception's}
  
  Expr=class;
  IOptExpr=interface;
  
  CannotCalcLoadedExpr = class(Exception)
    
    public constructor(sender: Expr) :=
    inherited Create($'Can''t calculate unprecompiled expr: {sender}');
    
  end;
  
  ExprParsingException = abstract class(Exception) end;
  CorrespondingCharNotFoundException = class(ExprParsingException)
    
    public constructor(ch: char; str: string) :=
    inherited Create($'Corresponding [> {ch} <] not found in string [> {str} <]');
    
  end;
  InvalidCharException = class(ExprParsingException)
    
    public constructor(str: string; pos: integer) :=
    inherited Create($'Invalid char [> {str[pos]} <] in [> {str} <] at #{pos}');
    
  end;
  ExtraCharsException = class(ExprParsingException)
    
    public constructor(str: string; i1,im,i2: integer) :=
    inherited Create($'Unconvertible chars [> {str.Substring(im-1, i2-im+1)} <] in [> {str.Substring(i1-1, i2-i1+1)} <]');
    
  end;
  EmptyExprException = class(ExprParsingException)
    
    public constructor(str: string; pos: integer) :=
    inherited Create($'Empty expression in [> {str} <] at #{pos}');
    
  end;
  CanNotParseException = class(ExprParsingException)
    public constructor(str:string) :=
    inherited Create($'Can''t parse "{str}"');
  end;
  
  ExprCompilingException = abstract class(Exception) end;
  UnknownFunctionNameException = class(ExprCompilingException)
    
    public constructor(func_name: string) :=
    inherited Create($'Function "{func_name}" not found');
    
  end;
  UnknownVarNameException = class(ExprCompilingException)
    
    public constructor(name: string) :=
    inherited Create($'Variable "{name}" not defined');
    
  end;
  InvalidFuncParamCountException = class(ExprCompilingException)
    
    public constructor(func_name: string; exp_c, fnd_c: integer) :=
    inherited Create($'Function "{func_name}" got {fnd_c} parameters, when expected {exp_c}');
    
  end;
  InvalidFuncParamTypesException = class(ExprCompilingException)
    
    public constructor(func_name: string; param_n: integer; exp_t, fnd_t: System.Type) :=
    inherited Create($'Function "{func_name}" parameter #{param_n} had type {fnd_t}, when expected {exp_t}');
    
  end;
  CannotSubStringExprException = class(ExprCompilingException)
    
    public constructor(exprs: List<IOptExpr>) :=
    inherited Create($'Can''t substract expressions from strings ({exprs.SkipLast.JoinIntoString('','')} and {exprs.Last})');
    
  end;
  CannotDivStringExprException = class(ExprCompilingException)
    
    //ToDo 1/"abc" and "abc"/1 - same error
    public constructor(exprs: List<IOptExpr>) :=
    inherited Create($'Can''t divide string expressions (was divided by {exprs.SkipLast.JoinIntoString('','')} and {exprs.Last})');
    
  end;
  CannotMltALotStringsException = class(ExprCompilingException)
    
    public constructor(e: Expr; str_c: integer) :=
    inherited Create($'Can multiply string only by numbers. In Expression {e} there is {str_c} strings');
    
  end;
  CannotPowStringException = class(ExprCompilingException)
    
    public constructor(e: Expr) :=
    inherited Create($'Can''t use operator^ on string ({e})');
    
  end;
  CanNotConvertRTIException = class(ExprCompilingException)
    
    public constructor(e: IOptExpr; r: real) :=
    inherited Create($'*error text under construction*');
    
  end;
  
  {$endregion Exception's}

  IExpr = interface
    
    function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): object;
    
  end;
  
  {$region Load}
  
  Expr = abstract class(IExpr)
    
    public class function FromString(text:string): Expr :=
    FromString(text,1,text.Length);
    
    public class function FromString(text:string; i1,i2:integer): Expr;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): object;
    begin
      Result := nil;
      raise new CannotCalcLoadedExpr(self);
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
  
  IOptExpr = interface
    
    function GetRes: Object;
    
    function GetResType: System.Type;
    
    function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr;
    
    function Openup: IOptExpr;
    
    function Optimize: IOptExpr;
    
    function GetCalc: Action0;
    
  end;
  OptExprBase = abstract class(IOptExpr)
    
    public function GetRes: object; abstract;
    
    public function GetResType: System.Type; abstract;
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; virtual := self;
    
    public function Openup: IOptExpr; virtual := self;
    
    public function Optimize: IOptExpr; virtual := self;
    
    public function GetCalc:Action0; virtual := nil;
    
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
  
  IOptLiteralExpr = interface(IOptExpr)
    
  end;
  OptNLiteralExpr = class(OptNExprBase, IOptLiteralExpr)
    
    public constructor(val: real) :=
    self.res := val;
    
    public function ToString: string; override :=
    res.ToString(new System.Globalization.NumberFormatInfo);
    
  end;
  OptSLiteralExpr = class(OptSExprBase, IOptLiteralExpr)
    
    public constructor(val: string) :=
    self.res := val;
    
    public function ToString: string; override :=
    $'"{res}"';
    
  end;
  
  IOptPlusExpr = interface(IOptExpr)
    
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
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Openup: IOptExpr; override;
    begin
      Result := self;
      var ToDo := 0;//ToDo Проблема в [> "a" + (5 + 3) <] - его нельзя раскрыть, ибо будет "a53" вместо "a8"
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize as OptNExprBase;
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
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptSExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptSExprBase;
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
      res := '';
      
      for var i := 0 to Positive.Count-1 do
        res += Positive[i].GetRes.ToString;
      
    end;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptExprBase;
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
          (oe is OptSExprBase)?
          (oe as OptSExprBase):
          (new OptSLiteralExpr(oe.GetRes.ToString))
        );
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
        if Negative.Any then raise new CannotSubStringExprException(nil);
        var nres := '';
        
        for var i := 0 to Positive.Count-1 do
          nres += Positive[i].GetRes.ToString;
        
        res := nres;
      end else
      begin
        var nres: real := 0;
        
        for var i := 0 to Positive.Count-1 do
          nres += real(Positive[i].GetRes);
        
        for var i := 0 to Negative.Count-1 do
          nres -= real(Negative[i].GetRes);
        
        res := nres;
      end;
    end;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize as OptExprBase;
      if Negative.Any(oe->oe is OptSExprBase) then raise new CannotSubStringExprException(Lst&<IOptExpr>(self));
      
      if Positive.Any(oe->oe is OptSExprBase) then
      begin
        if Negative.Any then raise new CannotSubStringExprException(Lst&<IOptExpr>(self));
        
        var res := new OptSOPlusExpr;
        res.Positive := self.Positive.ConvertAll(oe->
          (oe is IOptLiteralExpr)?
          (new OptSLiteralExpr(oe.GetRes.ToString) as OptExprBase):
          oe
        );
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
  
  IOptMltExpr = interface(IOptExpr)
    
    function AnyNegative: boolean;
    
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
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptNExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize as OptNExprBase;
      
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
  OptSOMltExpr = class(OptSExprBase, IOptMltExpr)
    
    public Base: OptSExprBase;
    public Positive: OptExprBase;
    
    private procedure Calc;
    begin
      
      var ro := Positive.GetRes;
      if ro.GetType = typeof(string) then raise new CannotMltALotStringsException(nil,0);
      var rn: integer;
      try
        rn := System.Convert.ToInt32(ro);
        if rn < 0 then raise new CanNotConvertRTIException(nil,0);
      except
        on System.ArgumentException do raise new CanNotConvertRTIException(nil,0);
      end;
      
      res := Base.res * rn;
    end;
    
    
    
    public function AnyNegative := false;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      Base := Base.FixVarExprs(sn,ss,so,nn,ns,no) as OptSExprBase;
      Positive := Positive.FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      Base := Base.Optimize as OptSExprBase;
      Positive := Positive.Optimize as OptExprBase;
      
      if Positive is OptSExprBase then raise new CannotMltALotStringsException(nil,0);
      if (Positive is IOptMltExpr(var ome)) and ome.AnyNegative then raise new CannotDivStringExprException(nil);
      
      if
        (Base is IOptLiteralExpr) and
        (Positive is IOptLiteralExpr)
      then
      begin
        var cr := (Positive as OptNExprBase).res;
        var ci: integer;
        try
          ci := System.Convert.ToInt32(cr);
          if ci < 0 then raise new CanNotConvertRTIException(nil,0);
        except
          on System.ArgumentException do raise new CanNotConvertRTIException(self, cr);
        end;
        Result := new OptSLiteralExpr(Base.res * ci);
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
      if Positive.Concat(Negative).Any(oe->oe is OptSExprBase) then
      begin
        if Negative.Any then raise new CannotDivStringExprException(nil);
        var n := 1;
        var nres: string := nil;
        
        for var i := 0 to Positive.Count-1 do
        begin
          var ro := Positive[i].GetRes;
          if ro is string then
            if nres = nil then
              nres := ro as string else
              raise new CannotMltALotStringsException(nil,0) else
            try
              n *= System.Convert.ToInt32(ro);
              if n < 0 then raise new CanNotConvertRTIException(nil,0);
            except
              on System.ArgumentException do raise new CanNotConvertRTIException(nil,0);
            end;
        end;
        
        res := nres * n;
      end else
      begin
        var nres: real := 1;
        
        for var i := 0 to Positive.Count-1 do
          nres *= (Positive[i].GetRes as OptNExprBase).res;
        
        for var i := 0 to Negative.Count-1 do
          nres /= (Negative[i].GetRes as OptNExprBase).res;
        
        res := nres;
      end;
    end;
    
    
    
    public function AnyNegative := Negative.Any;
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptExprBase;
      for var i := 0 to Negative.Count-1 do Negative[i] := Negative[i].Optimize as OptExprBase;
      
      var pn := Positive.Concat(Negative);
      var sc := pn.Count(oe->oe is OptSExprBase);
      if sc > 1 then raise new CannotMltALotStringsException(nil, sc);
      
      if sc = 1 then
      begin
        if Negative.Any then raise new CannotDivStringExprException(nil);
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
  
  IOptPowExpr = interface(IOptExpr)
    
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
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptNExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptNExprBase;
      
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
      if Positive.Any(oe->oe is OptSExprBase) then raise new CannotPowStringException(nil);
      var nres: real := 1;
      
      for var i := 1 to Positive.Count-1 do
        nres *= (Positive[i] as OptNExprBase).res;
      
      res := Power((Positive[0] as OptNExprBase).res, nres);
    end;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to Positive.Count-1 do Positive[i] := Positive[i].Optimize as OptExprBase;
      
      if Positive.Any(oe->oe is OptSExprBase) then raise new CannotPowStringException(nil);
      
      if Positive.All(oe->oe is OptNExprBase) then
      begin
        var res := new OptNPowExpr;
        res.Positive := self.Positive.ConvertAll(oe->oe as OptNExprBase);
        Result := res;
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
  
  IOptFuncExpr = interface(IOptExpr)
    
    procedure CheckParams;
    
  end;
  OptNFuncExpr = abstract class(OptNExprBase, IOptFuncExpr)
    
    public name: string;
    public par: array of OptExprBase;
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    procedure CheckParamsBase(params tps: array of System.Type);
    begin
      if par.Length <> tps.Length then raise new InvalidFuncParamCountException(self.name, tps.Length, par.Length);
      
      for var i := 0 to tps.Length-1 do
        if (par[i].GetResType <> tps[i]) and (par[i].GetResType <> typeof(Object)) then
          raise new InvalidFuncParamTypesException(self.name, i, tps[i], par[i].GetRes.GetType);
    end;
    
    public procedure CheckParams; abstract;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].Optimize as OptExprBase;
      CheckParams;
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
    
    
    
    public function FixVarExprs(sn:array of real; ss: array of string; so: array of object; nn,ns,no: List<string>): IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].FixVarExprs(sn,ss,so,nn,ns,no) as OptExprBase;
      Result := self;
    end;
    
    procedure CheckParamsBase(params tps: array of System.Type);
    begin
      if par.Length <> tps.Length then raise new InvalidFuncParamCountException(self.name, tps.Length, par.Length);
      
      for var i := 0 to tps.Length-1 do
        if par[i].GetRes.GetType <> tps[i] then
          raise new InvalidFuncParamTypesException(self.name, i, tps[i], par[i].GetRes.GetType);
    end;
    
    public procedure CheckParams; abstract;
    
    public function Optimize: IOptExpr; override;
    begin
      for var i := 0 to par.Length-1 do par[i] := par[i].Optimize as OptExprBase;
      CheckParams;
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
    
    public souce: array of real;
    public id: integer;
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
    $'int_var[{id}]';
    
  end;
  UnOptSVarExpr = class(OptSExprBase, IOptVarExpr)
    
    public souce: array of string;
    public id: integer;
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
    $'str_var[{id}]';
    
  end;
  UnOptOVarExpr = class(OptOExprBase, IOptVarExpr)
    
    public souce: array of object;
    public id: integer;
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
    $'obj_var[{id}]';
    
  end;
  
  OptExprWrapper = abstract class(IExpr)
    
    public n_vars: array of real;
    public s_vars: array of string;
    public o_vars: array of object;
    
    public n_vars_names := new List<string>;
    public s_vars_names := new List<string>;
    public o_vars_names := new List<string>;
    
    public MainCalcProc: procedure;
    
    protected procedure StartCalc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>);
    begin
      
      for var i := 0 to n_vars_names.Count-1 do
      begin
        var name := n_vars_names[i];
        if n_vars.ContainsKey(name) then
          self.n_vars[i] := n_vars[name];
      end;
      
      for var i := 0 to s_vars_names.Count-1 do
      begin
        var name := s_vars_names[i];
        if s_vars.ContainsKey(name) then
          self.s_vars[i] := s_vars[name];
      end;
      
      for var i := 0 to o_vars_names.Count-1 do
      begin
        var name := o_vars_names[i];
        if n_vars.ContainsKey(name) then
          self.o_vars[i] := n_vars[name] else
        if s_vars.ContainsKey(name) then
          self.o_vars[i] := s_vars[name];
      end;
      
      if MainCalcProc <> nil then MainCalcProc;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): object; abstract;
    
    public class function FromExpr(e: Expr; n_vars_names, s_vars_names, o_vars_names: List<string>): OptExprWrapper;
    
    public constructor;
    begin
      
    end;
    
  end;
  OptNExprWrapper = class(OptExprWrapper)
    
    public Main: OptNExprBase;
    
    public function CalcN(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): real;
    begin
      
      inherited StartCalc(n_vars, s_vars, o_vars);
      
      Result := Main.res;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): object; override :=
    CalcN(n_vars, s_vars, o_vars);
    
    public constructor(Main: OptNExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
  end;
  OptSExprWrapper = class(OptExprWrapper)
    
    public Main: OptSExprBase;
    
    public function CalcN(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): string;
    begin
      
      inherited StartCalc(n_vars, s_vars, o_vars);
      
      Result := Main.res;
      
    end;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): object; override :=
    CalcN(n_vars, s_vars, o_vars);
    
    public constructor(Main: OptSExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
  end;
  OptOExprWrapper = class(OptExprWrapper)
    
    public Main: OptOExprBase;
    
    public function Calc(n_vars: Dictionary<string, real>; s_vars: Dictionary<string, string>; o_vars: Dictionary<string, object>): object; override;
    begin
      
      inherited StartCalc(n_vars, s_vars, o_vars);
      
      Result := Main.GetRes;
      
    end;
    
    public constructor(Main: OptOExprBase);
    begin
      inherited Create;
      self.Main := Main;
    end;
    
  end;
  
  {$endregion Optimize}
  
implementation

{$region Load}

function FindNext(self: string; from: integer; ch: char): integer; extensionmethod;
begin
  while true do
  begin
    
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
    if from > self.Length then
      raise new CorrespondingCharNotFoundException(ch, self);
    
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
  
  if i1 > i2 then raise new EmptyExprException('*EmptyString*', 0);
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
    
    if i1 = i2 then break;
    if i1 = i2+1 then break;
    if i1 > i2+1 then raise new Exception('This is unexpected...');
    
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
    CheckParamsBase(
      typeof(string)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if pr is string then
        self.res := (pr as string).Length else
        raise new InvalidFuncParamTypesException(self.name, -1, typeof(string), pr.GetType);
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
    CheckParamsBase(
      typeof(string)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if not ( (pr is string) and (TryStrToFloat(pr as string,self.res)) ) then
        raise new InvalidFuncParamTypesException(self.name, -1, typeof(string), pr.GetType);
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
    CheckParamsBase(
      typeof(string)
    );
    
    public procedure Calc;
    begin
      var pr := par[0].GetRes;
      if not ( (pr is string) and ((pr as string).Length = 1) ) then
        self.res := word((pr as string)[1]) else
        raise new InvalidFuncParamTypesException(self.name, -1, typeof(string), pr.GetType);
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
  
  OptFunc_Str = class(OptSFuncExpr)
    
    public procedure CheckParams; override :=
    if par.Length <> 1 then
      raise new InvalidFuncParamCountException(self.name, 1, par.Length);
    
    public procedure Calc;
    begin
      self.res := par[0].GetRes.ToString;
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
  
  //ToDo функции: *что то для нарезания строк*
  OptConverter = {static} class
    
    class g_n_vars_names: List<string>;
    class g_s_vars_names: List<string>;
    class g_o_vars_names: List<string>;
    
    class l_n_vars_names := new List<string>;
    class l_s_vars_names := new List<string>;
    class l_o_vars_names := new List<string>;
    
    
    
    //ToDo sequence заменить на array, #1210
    class FuncTypes := new Dictionary<string, Func<sequence of OptExprBase,IOptFuncExpr>>;
    
    class constructor;
    begin
      
      //ToDo убрать .ToArray, #1210
      FuncTypes.Add('length', par->new OptFunc_Length(par.ToArray));
      FuncTypes.Add('Num', par->new OptFunc_Num(par.ToArray));
      FuncTypes.Add('Ord', par->new OptFunc_Ord(par.ToArray));
      
      FuncTypes.Add('Str', par->new OptFunc_Str(par.ToArray));
      
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
      if e.Negative.Any then raise new Exception('этого не должно было произойти');
      
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
        raise new UnknownFunctionNameException(e.name);
    end;
    
    class function GetOptVarExpr(e: VarExpr): IOptVarExpr;
    begin
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
      if g_o_vars_names.Contains(e.name) then
      begin
        Result := new UnOptOVarExpr(e.name);
        l_o_vars_names.Add(e.name);
      end else
        raise new UnknownVarNameException(e.name);
      
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
        else raise new Exception;
      end;
    end;
    
    class function GetOptStatement(e: Expr; g_n_vars_names, g_s_vars_names, g_o_vars_names: List<string>): OptExprWrapper;
    begin
      
      OptConverter.g_n_vars_names := g_n_vars_names;
      OptConverter.g_s_vars_names := g_s_vars_names;
      OptConverter.g_o_vars_names := g_o_vars_names;
      
      var Main := GetOptExpr(e);
      
      var n_vars := ArrFill(l_n_vars_names.Count, 0.0);
      var s_vars := ArrFill(l_s_vars_names.Count, '');
      var o_vars := ArrFill(l_o_vars_names.Count, object(nil));
      
      Main := Main.FixVarExprs(n_vars, s_vars, o_vars, l_n_vars_names, l_s_vars_names, l_o_vars_names);
      Main := Main.Openup;
      Main := Main.Optimize;
      
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

class function OptExprWrapper.FromExpr(e: Expr; n_vars_names, s_vars_names, o_vars_names: List<string>) :=
OptConverter.GetOptStatement(e, n_vars_names, s_vars_names, o_vars_names);

{$endregion Optimize}

end.