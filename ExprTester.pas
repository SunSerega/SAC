uses ExprParser;

type
  OkException = class(Exception) end;
  
  TestExpr = abstract class
    
    static AllowedNameChars: List<char>;
    
    
    
    nvs: Dictionary<string, real>;
    svs: Dictionary<string, string>;
    ovs: Dictionary<string, object>;
    
    function GetExpRes: object; abstract;
    function ContainsString: boolean; abstract;
    procedure FindAllVars; virtual;
    begin
      nvs := new Dictionary<string,real>;
      svs := new Dictionary<string,string>;
      ovs := new Dictionary<string,object>;
    end;
    
    
    
    static constructor;
    begin
      
      AllowedNameChars := new List<char>(integer('a').To(word('z')).Select(id->char(id)));
      AllowedNameChars.Add('_');
      
    end;
    
    static function GetRandName(c: integer) :=
    new string(
      ArrGen(
        c, i->AllowedNameChars[Random(AllowedNameChars.Count)]
      )
    );
    
    static function GetConstExprs(AllowString: boolean): sequence of TestExpr;
    static function GetPlusExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
    static function GetMltExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
    static function GetPowExprs(recl: integer): sequence of TestExpr;
    static function GetFuncExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
    static function GetVarExprs(AllowString: boolean): sequence of TestExpr;
    
    static function GetAnyExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
    begin
      Result := new TestExpr[0];
      if recl = 0 then exit;
      
      var ce := GetConstExprs(AllowString);
      var ve := GetVarExprs(AllowString);
      var pe := GetPlusExprs(AllowString, recl);
      var me := GetMltExprs(AllowString, recl);
      var pwe := GetPowExprs(recl);
      var fe := GetFuncExprs(AllowString, recl);
      
      Result := ce;
      Result := Result + ve;
      Result := Result + pe;
      Result := Result + me;
      Result := Result + pwe;
      Result := Result + fe;
    end;
    static function GetMultipleExprs(c: integer; AllowString: boolean; recl: integer): sequence of array of TestExpr;
    const
      trl = 2;
    begin
      var res := new TestExpr[c];
      var enms := ArrGen(c, i->TestExpr.GetAnyExprs(AllowString, recl).GetEnumerator);
      
//      var n := BigInteger.Pow(TestExpr.GetAnyExprs(AllowString, recl).Count, c);
      
      var i := 0;
      while true do
        if enms[i].MoveNext then
        begin
          i += 1;
          if i = c then
          begin
            yield enms.ConvertAll(enm -> enm.Current as TestExpr);
            i -= 1;
            
//            if recl = trl then
//            begin
//              n -= 1;
//              if n mod (100*1000) = 0 then writeln(n);
//            end;
          end;
        end else
        begin
          enms[i] := GetAnyExprs(AllowString, recl).GetEnumerator;
          i -= 1;
          if i = -1 then break;
        end;
    end;
    
  end;
  ExprRes = class
    
    res: object;
    
    property ResNil: boolean read res=nil;
    property ResType: System.Type read res=nil?nil:res.GetType;
    
    static function operator explicit(o: object): ExprRes;
    begin
      Result := new ExprRes;
      Result.res := o;
    end;
    
    static function StrEql(s1,s2:string): real;
    const
      max_search_l=1000;
    begin
      
      var ok := 0;
      var i1 := 1;
      var i2 := 1;
      while (i1 <= s1.Length) and (i2 <= s2.Length) do
        if s1[i1] = s2[i2] then
        begin
          ok += 1;
          i1 += 1;
          i2 += 1;
        end else
        begin
          
          var nok1 := -1;
          var nok2 := -1;
          
          var l1 := Min(s1.Length-i1, max_search_l);
          for var ni1 := i1+1 to i1+l1 do
          begin
            var l2 := Min(s2.Length-i2-ni1+i1, max_search_l);
            for var ni2 := i2+1 to i2+l2 do
              if (s1[ni1] = s2[ni2]) then
                if (nok1=-1) or (ni1+ni2 < nok1+nok2) or ((ni1+ni2 = nok1+nok2) and (abs(ni1-ni2) < abs(nok1-nok2))) then
                begin
                  nok1 := ni1;
                  nok2 := ni2;
                end;
          end;
          
          if nok1=-1 then break;
          i1 := nok1;
          i2 := nok2;
          
        end;
      
      Result := ok/(s1.Length+s2.Length)*2;
    end;
    
    static function CalcEqu(r1,r2: ExprRes): real;
    begin
      //var t1 := r1.res?.GetType;
      //var t2 := r2.res?.GetType;
      
      if r1.res = nil then
        Result := (r2.res = nil)?1:0 else
        Result := StrEql(r1.ToString, r2.ToString);
//      if r1.res is real(var n1) then
//        Result := ((r2.res is real(var n2)) and ( (n1=n2) or ((real.IsNaN(n1)) and (real.IsNaN(n2))) or (abs(n1-n2) < 0.1)))?1:0 else
//      if r1.res is string(var s1) then
//        Result := (r2.res is string(var s2))?StrEql(s1,s2):0 else
//        Result := 0;
    end;
    
    public function ToString: string; override;
    begin
      if res = nil then Result := 'null' else
      if res is real then Result := real(res).ToString(new System.Globalization.NumberFormatInfo) else
      if res is string(var s) then Result :=
        (s.Length < 100)?
        $'"{s}"':
        $'"{s.Substring(0,100)}..."[{s.Length}]'
      else
      Result := $'*Неправильный тип результата: {res.GetType}*';
    end;
    
  end;
  
  TestConstExpr = class(TestExpr)
    
    res: object;
    
    function GetExpRes: object; override := res;
    function ContainsString: boolean; override := res is string;
    
    constructor(o: object) :=
    res := o;
    
    public function ToString: string; override :=
    ExprRes(res).ToString;
    
  end;
  TestVarExpr = class(TestExpr)
    
    name: string;
    val: object;
    as_obj: boolean;
    
    static Prohibited_names := Arr('null', 'inf', 'nan');
    
    function GetExpRes: object; override := val;
    function ContainsString: boolean; override := val is string;
    
    procedure FindAllVars; override;
    begin
      if Prohibited_names.Contains(name) then raise new OkException;
      
      inherited FindAllVars;
      if as_obj then
        ovs.Add(name, val) else
      if val is real(var n) then
        nvs.Add(name, n) else
        svs.Add(name, val as string);
    end;
    
    constructor(name: string; val: object; as_obj: boolean);
    begin
      self.name := name;
      self.val := val;
      self.as_obj := as_obj;
    end;
    
    public function ToString: string; override :=
    name;
    
  end;
  TestCmplExpr = abstract class(TestExpr)
  
    se: array of TestExpr;
    pn_tbl: array of boolean;
    
    function ContainsString: boolean; override := se.Any(e->e.ContainsString);
    
    procedure FindAllVars; override;
    begin
      inherited FindAllVars;
      foreach var e in se do
      begin
        e.FindAllVars;
        var check_name: string->string := s->
        begin
          if self.nvs.ContainsKey(s) then raise new OkException;
          if self.svs.ContainsKey(s) then raise new OkException;
          if self.ovs.ContainsKey(s) then raise new OkException;
          Result := s;
        end;
        foreach var kvp in e.nvs do self.nvs.Add(check_name(kvp.Key), kvp.Value);
        foreach var kvp in e.svs do self.svs.Add(check_name(kvp.Key), kvp.Value);
        foreach var kvp in e.ovs do self.ovs.Add(check_name(kvp.Key), kvp.Value);
        e.nvs := nil;
        e.svs := nil;
        e.ovs := nil;
      end;
    end;
    
  end;
  TestPlusExpr = class(TestCmplExpr)
    
    function GetExpRes: object; override;
    begin
      var ress := se.ConvertAll(e->e.GetExpRes);
      if ress.Any(o->o is string) then
        Result := ress.Where(o->o<>nil).Select(
          o->
          begin
            Result := '';
            if o is string then
              Result := o as string else
            if o is real then
              Result := real(o).ToString(new System.Globalization.NumberFormatInfo);
          end
        ).JoinIntoString('') else
        Result := ress.ConvertAll(function(o,i)->
//        try
//          Result :=
          o=nil?0.0:(pn_tbl[i]?real(o):-real(o))
//        except
//          on e: System.InvalidCastException do
//          begin
//            writeln(o);
//            writeln(o.GetType);
//            var ToDo_Remove := 0;
//            raise e;
//          end;
//        end
        ).Sum;
    end;
    
    constructor(se: array of TestExpr; pn_tbl: array of boolean);
    begin
      self.se := se;
      self.pn_tbl := pn_tbl;
    end;
    
    public function ToString: string; override :=
    self.ContainsString?
    $'({se.JoinIntoString(''+'')})':
    $'({se.Select((e,i)->(pn_tbl[i]?''+'':''-'')+e.ToString).JoinIntoString('''')})';
    
  end;
  TestMltExpr = class(TestCmplExpr)
    
    function GetExpRes: object; override;
    begin
      var ress := se.ConvertAll(e->e.GetExpRes) as IEnumerable&<Object>;
      if ress.Any(o->o is string) then
      begin
        var res := ress.First(o->o is string) as string;
        ress := ress.Where(o->not (o is string));
        if ress.Any(o->o=nil) then
        begin
          Result := '';
          exit;
        end;
        var c := real(ress.First);
        ress.Skip(1).ForEach((o,i)->
          if self.pn_tbl[i] then
            c *= real(o) else
            c /= real(o)
        );
        
        if c < -0.5 then raise new OkException;
        if real.IsNaN(c) or real.IsInfinity(c) then raise new OkException;
        var ic := BigInteger.Create(c+0.5);
        if ic > 10000 then raise new OkException;
        var cap := ic * res.Length;
        if cap > integer.MaxValue then raise new OkException;
        var sb := new StringBuilder(integer(cap));
        loop integer(ic) do sb += res;
        Result := sb.ToString;
      end else
      begin
        var co := ress.First;
        var c := co=nil?0.0:real(co);
        ress.Skip(1).ForEach((o,i)->
          if self.pn_tbl[i] then
            c *= o=nil?0.0:real(o) else
            c /= o=nil?0.0:real(o)
        );
        Result := c;
      end;
    end;
    
    constructor(se: array of TestExpr; pn_tbl: array of boolean);
    begin
      self.se := se;
      self.pn_tbl := pn_tbl;
    end;
    
    public function ToString: string; override :=
    $'({se[0]}{se.Skip(1).Select((e,i)->(pn_tbl[i]?''*'':''/'')+e.ToString).JoinIntoString('''')})';
    
  end;
  TestPowExpr = class(TestCmplExpr)
    
    function GetExpRes: object; override;
    begin
      var ress := se.ConvertAll(e->e.GetExpRes);
      var p := 1.0;
      foreach var o in ress.Skip(1) do
        p *= o=nil?0.0:real(o);
      Result := Power(ress[0]=nil?0.0:real(ress[0]), p);
    end;
    
    constructor(se: array of TestExpr) :=
    self.se := se;
    
    public function ToString: string; override :=
    $'({se[0]}^({se.Skip(1).JoinIntoString(''*'')}))';
    
  end;
  TestFuncExpr = class(TestCmplExpr)
    
    name: string;
    
    function GetExpRes: object; override;
    begin
      var ress := se.ConvertAll(e->e.GetExpRes);
    end;
    
    constructor(name: string; se: array of TestExpr) :=
    self.se := se;
    
    public function ToString: string; override :=
    $'name({se.JoinIntoString('','')})';
    
  end;
  
  

const
  TestConstC = 2;

function EnmrBoolArr(c: integer): List<array of boolean>;
begin
  Result := new List<array of boolean>(1 shl c);
  
  var curr := new boolean[c];
  var i := c-1;
  while true do
  begin
    Result += curr.ToArray;
    
    while true do
    begin
      curr[i] := not curr[i];
      if curr[i] then break;
      i -= 1;
      if i < 0 then exit;
    end;
    i := c-1;
  end;
end;


static function TestExpr.GetConstExprs(AllowString: boolean): sequence of TestExpr;
begin
  loop TestConstC do yield new TestConstExpr(Random*(1024*1024));
  if AllowString then
    loop TestConstC do yield new TestConstExpr(GetRandName(Random(5)));
end;

static function TestExpr.GetVarExprs(AllowString: boolean): sequence of TestExpr;
begin
  var name := GetRandName(Random(1, 5));
  yield new TestVarExpr(name, nil, true);
  loop TestConstC do
  begin
    name := GetRandName(Random(1, 5));
    var val: object := Random*(1024*1024);
    yield new TestVarExpr(name, val, false);
    yield new TestVarExpr(name, val, true);
  end;
  if AllowString then
    loop TestConstC do
      begin
        name := GetRandName(Random(1, 5));
        var val := GetRandName(Random(5));
        yield new TestVarExpr(name, val, false);
        yield new TestVarExpr(name, val, true);
      end;
end;

static function TestExpr.GetPlusExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
begin
  for var n := 2 to 2 do
    foreach var se in GetMultipleExprs(n, AllowString, recl-1) do
      foreach var pn_tbl in EnmrBoolArr(n) do
        yield new TestPlusExpr(se, pn_tbl);
end;

static function TestExpr.GetMltExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
begin
  for var n := 2 to 2 do
    foreach var se in GetMultipleExprs(n, AllowString, recl-1) do
      if (not AllowString) or (se.Count(e->e.ContainsString) <= 1) then
        if se.Any(e->e.ContainsString) then
          yield new TestMltExpr(se, ArrFill(n-1,true)) else
          foreach var pn_tbl in EnmrBoolArr(n-1) do
            yield new TestMltExpr(se, pn_tbl);
end;

static function TestExpr.GetPowExprs(recl: integer): sequence of TestExpr;
begin
  for var n := 2 to 2 do
    foreach var se in GetMultipleExprs(n, false, recl-1) do
      yield new TestPowExpr(se);
end;

static function TestExpr.GetFuncExprs(AllowString: boolean; recl: integer): sequence of TestExpr;
begin
  var ToDo := 0;
  exit;
  for var n := 2 to 2 do
    foreach var se in GetMultipleExprs(n, AllowString, recl-1) do
      yield new TestFuncExpr('', se);
end;



begin
  
  Randomize(0);
  
  //TestExpr.GetAnyExprs(true, 3).Count.Print;
  //exit;
  
  var skiping: integer;
  skiping := 1500000;
  var n := 0;
  
  foreach var te in TestExpr.GetAnyExprs(true, 3) do
  try
    n += 1;
    if n < skiping then continue;
    if n = skiping then writeln('done skiping');
    if n mod 1000 = 0 then writeln($'#{n}');
    
    
    var s := te.ToString;
    te.FindAllVars;
    var nvs := te.nvs;
    var svs := te.svs;
    var ovs := te.ovs;
    foreach var kvp in ovs do//ToDo ну да, костыль, но уже как то... какая разница
      if kvp.Value <> nil then
        if kvp.Value is real then
          nvs.Add(kvp.Key, real(kvp.Value)) else
          svs.Add(kvp.Key, string(kvp.Value));
    
    var res1 := ExprRes(te.GetExpRes);
    
    var e := Expr.FromString(s);
    var oe := OptExprWrapper.FromExpr(e, nvs.Keys.ToList, svs.Keys.ToList);
    var res2 := ExprRes(oe.Calc(nvs, svs));
    
    if ExprRes.CalcEqu(res1,res2) < 0.2 then
    begin
      writeln($'#{n}');
      writeln($'Ошибка, неправильный результат');
      writeln($'Оригинал:       {te}');
      writeln($'Прочитано:      {e}');
      writeln($'Оптимизировано: {oe}');
      writeln;
      writeln($'Числа:          ',nvs);
      writeln($'Строки:         ',svs);
      writeln($'Объекты:        ',ovs);
      writeln;
      writeln($'Ожидалось:      {res1}');
      writeln($'Получили:       {res2}');
      write('-'*50);
      oe := OptExprWrapper.FromExpr(e, nvs.Keys.ToList, svs.Keys.ToList);
      res1 := ExprRes(te.GetExpRes);
      res2 := ExprRes(oe.Calc(nvs, svs));
      var b := ExprRes.CalcEqu(res1,res2);
      readln;
    end;
  except
    on e: Exception do
    begin
      if e is OkException then continue;
      writeln('#',n);
      writeln(te);
      writeln(e);
      readln;
    end;
  end;
  
  writeln('done');
  readln;
end.