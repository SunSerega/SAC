unit StmParser;
//ToDo файлы могут быть подключены и динамичным связыванием. Это надо предусмотреть
//ToDo Добавить DeduseVarsTypes и Instatiate в ExprParser
//ToDo удобный способ смотреть изначальный и оптимизированный вариант
//ToDo контекст ошибок, то есть при оптимизации надо сохранять номер строки

//ToDo Directives:  !NoOpt/!Opt
//ToDo Directives:  !SngDef:i1=num:readonly/const

//ToDo bug track:
// -formating adds newline for "class function"

//ToDo Проверить, не исправили ли issue компилятора
// - #1322 (в следующем билде)
// - #1326

interface

uses ExprParser;

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
  
  PrecompilingException = abstract class(Exception)
    
    public Sender: StmBlock;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Precompiling error in block {Sender}: ' + text);
      self.source := source;
    end;
    
  end;
  UndefinedDirectiveNameException = class(PrecompilingException)
    
    public constructor(source: StmBlock; dname: string) :=
    inherited Create(source, $'Directive name "{dname}" not defined');
    
  end;
  UndefinedOperNameException = class(PrecompilingException)
    
    public constructor(source: StmBlock; oname: string) :=
    inherited Create(source, $'Operator name "{oname}" not defined');
    
  end;
  RefFileNotFound = class(PrecompilingException)
    
    public constructor(source: StmBlock; fname: string) :=
    inherited Create(source, $'File "{fname}" not found');
    
  end;
  InvalidLabelCharactersException = class(PrecompilingException)
    
    public constructor(source: StmBlock; l: string; ch: char) :=
    inherited Create(source, $'Label can''t contain "{ch}". Label was "l"');
    
  end;
  RecursionTooBig = class(PrecompilingException)
    
    public constructor(source: Script; max: integer) :=
    inherited Create(source, $'Recursion level was > maximum, {max}');
    
  end;
  InsufficientOperParamCount = class(PrecompilingException)
    
    public constructor(source: Script; exp: integer; par: array of string) :=
    inherited Create(source, $'Insufficient operator params count, expeted {exp}, but found {par.Length}', KV('par', object(par)));
    
  end;
  LabelNotFoundException = class(PrecompilingException)
    
    public constructor(source: Script; lbl_name: string) :=
    inherited Create(source, $'Label "{lbl_name}" not found');
    
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
    public jcc := false;
    
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
    
    public class function FromString(sb: StmBlock; s: string; par: array of string): StmBase;
    
    public class function ObjToStr(o: object): string;
    begin
      if o = nil then
        Result := '' else
      if o is string then
        Result := o as string else
        Result := real(o).ToString(nfi);
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
    public refs := new List<StmBlock>;//блоки которые ссылаются на этот. не считая prev
    
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
    end;
    
  end;
  
  {$endregion Stm containers}
  
  {$region StmBlockRef}
  
  StmBlockRef = abstract class
    
    function GetBlock(ec: ExecutingContext): StmBlock; abstract;
    
  end;
  StaticStmBlockRef = class(StmBlockRef)
    
    bl: StmBlock;
    
    function GetBlock(ec: ExecutingContext): StmBlock; override := bl;
    
  end;
  DynamicStmBlockRef = class(StmBlockRef)
    
    e: OptExprWrapper;
    
    function GetBlock(ec: ExecutingContext): StmBlock; override;
    begin
      var res := StmBase.ObjToStr(e.Calc(ec.nvs, ec.svs));
      if res <> '' then
      begin
        if res.StartsWith('#') then
          res := ec.curr.fname+res else
          res := Script.CombinePaths(System.IO.Path.GetDirectoryName(ec.curr.fname), res);
        
        if not ec.scr.sbs.TryGetValue(res, Result) then
          raise new LabelNotFoundException(ec.scr, res);
      end;
    end;
    
  end;
  
  {$endregion StmBlockRef}
  
  {$region interface's}
  
  IFileRefStm = interface
    
    function GetRefs: sequence of OptExprBase;
    
  end;
  ICallOper = interface
    
  end;
  
  {$endregion interface's}
  
  {$region operator's}
  
  OperCall = class(OperStmBase, ICallOper)
    
    public CallingBlock: StmBlockRef;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      
      var res := new DynamicStmBlockRef;
      res.e := OptExprWrapper.FromExpr(Expr.FromString(par[1]), sb.nvn, sb.svn);
      CallingBlock := res;
    end;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    ec->
    begin
      ec.Push(bl.next);
      ec.curr := self.CallingBlock.GetBlock(ec);
      ec.jcc := true;
    end;
    
  end;
  OperCallIf = class(OperStmBase, ICallOper)
    
    public e1,e2: OptExprWrapper;
    public compr: (equ, less, more, less_equ, more_equ);
    public CallingBlock1: StmBlockRef;
    public CallingBlock2: StmBlockRef;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientOperParamCount(self.scr, 6, par);
      
      var res := new DynamicStmBlockRef;
      res.e := OptExprWrapper.FromExpr(Expr.FromString(par[4]), sb.nvn, sb.svn);
      CallingBlock1 := res;
      
      res := new DynamicStmBlockRef;
      res.e := OptExprWrapper.FromExpr(Expr.FromString(par[5]), sb.nvn, sb.svn);
      CallingBlock2 := res;
    end;
    
    private function comp_obj(o1,o2: object): boolean;
    begin
      if (o1 is real) and (o2 is real) then
        case compr of
          equ: Result := real(o1) = real(o2);
          less: Result := real(o1) < real(o2);
          more: Result := real(o1) > real(o2);
          less_equ: Result := real(o1) <= real(o2);
          more_equ: Result := real(o1) >= real(o2);
        end else
        case compr of
          equ: Result := ObjToStr(o1) = ObjToStr(o2);
          less: Result := ObjToStr(o1) < ObjToStr(o2);
          more: Result := ObjToStr(o1) > ObjToStr(o2);
          less_equ: Result := ObjToStr(o1) <= ObjToStr(o2);
          more_equ: Result := ObjToStr(o1) >= ObjToStr(o2);
        end;
    end;
    
    public function GetCalc: Action<ExecutingContext>; override :=
    ec->
    begin
      ec.Push(bl.next);
      var res1 := e1.Calc(ec.nvs, ec.svs);
      var res2 := e2.Calc(ec.nvs, ec.svs);
      ec.curr := comp_obj(res1,res2)?CallingBlock1.GetBlock(ec):CallingBlock2.GetBlock(ec);
      ec.jcc := true;
    end;
    
  end;
  OperReturn = class(OperStmBase)
    
    public constructor := exit;
    
    public function GetCalc: Action<ExecutingContext>; override := nil;
    
  end;
  OperOutput = class(OperStmBase)
    
    public otp: OptExprWrapper;
    
    public constructor(sb: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientOperParamCount(self.scr, 2, par);
      var e := Expr.FromString(par[1]);
      otp := OptExprWrapper.FromExpr(e, sb.nvn, sb.svn);
    end;
    
    public public function GetCalc: Action<ExecutingContext>; override :=
    ec->
    if scr.otp <> nil then
      scr.otp(ObjToStr(otp.Calc(
        ec.nvs,
        ec.svs
      )))
    ;
    
  end;
  
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
  case par[0] of
    
    'call': Result := new OperCall(sb, par);
    'callif': Result := new OperCallIf(sb, par);
    'return': Result := new OperReturn;
    
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
      lns := (new System.IO.StreamReader(str)).ReadToEnd.ToLower.Remove(#13).Split(#10);
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
          end else
          begin
            last.next := new StmBlock(self);
            last.Seal;
            last := last.next;
          end;
          lname := ffname+s;
          skp_ar := false;
          
        end else
          if (s <> '') and not skp_ar then
          begin
            var stm := StmBase.FromString(last, s, ss.SmartSplit);
            last.stms.Add(stm);
            if stm is ICallOper then
            begin
              sbs.Add(lname, last);
              last.next := new StmBlock(self);
              last.fname := ffname;
              last.Seal;
              last := last.next;
              lname := ffname+'#%'+tmp_b_c;
              tmp_b_c += 1;
            end else
            if stm is OperReturn then
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
  var res := new List<OptExprBase>;//ToDo #1322
  foreach var op in stms do
    if op is IFileRefStm(var frs) then
      //yield sequence frs.GetRefs;
      res.AddRange(frs.GetRefs);
  
  Result := res;
end;

procedure Script.Optimize(load_done: boolean);
begin
  var ToDo := 0;
end;

function ExecutingContext.ExecuteNext: boolean;
begin
  if curr <> nil then
  begin
    curr.Execute(self);
    if not jcc then
      curr := curr.next;
    jcc := false;
    Result := true;
  end else
    Result := Pop(curr);
end;

{$region temp_reg}

{$endregion temp_reg}

end.