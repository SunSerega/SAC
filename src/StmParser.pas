unit StmParser;
//ToDo документация новых параметров
//ToDo функционал новых параметров
//ToDo в тестере сделать чтоб заменялся весь .sactd файл (вместо добавления в конце)

//ToDo перестановка переменных в следующий блок всё ещё неправильна. В перёд переставлять можно только если ничего тот блок не вызывает (кроме того, откуда эту переменную переместили)
// - это в 2 местах одновременно надо исправлять

//ToDo типы Ununwrapable[Jump/Call]If
// - надо ибо сейчас в случае невозможности развернуть - остаётся огрызок, который в Calc делает кучу лишнего

//ToDo параметр для разрешения разворачивания: [> JumpIf ... "Loop" ... <]
// - написать где то что возможно бесконечное разворачивание в определённых условиях

//ToDo параметр для ограничения размера блока (обязательно с дефолтным значением)
//ToDo добавить в SAC защиту от багов. Если компилируется долго или ошибка - его всё должно обрабатывать
//ToDo задокументировать возможность добавлять табы в начале каждой строчки
//ToDo засовывать WW и WH в основные константы... наверное - не лучшая идея. Лучше хранить их в отдельном словаре
//ToDo оператор Assert
//ToDo операторы ReadText и Alert, работающие через месседж боксы

//ToDo защита GetBlockChain от бесконечного Call
// - иначе может быть внутренняя StackOverflow оптимизатора
// - нужно добавить параметр-глубину в GetBlockChain, если он ушёл за предел рекурсии - ошибка

//ToDo в каждом ExprStm надо хранить имя начального файла
// - иначе оптимизация меняет блок а с ним и файл, и ReadOnly переменные могут перестать работать
// - это нельзя засовывать в контекст ошибок, раз он есть только в режиме дебага. Или, может, сохранять минимум контекста на время компиляции, а потом удалять?
// - когда будет готово - добавить ReadOnly проверку и в ExecutingContext.SetVar . Это важно, но не смертельно, так что можно и подождать контекста ошибок



//ToDo Контекст ошибок
// - его добавлять только в дебаг режиме

//ToDo тесты для всех скриптов из справки

//ToDo а как будет работать получение относительного пути, если при подключении файла указать название диска?
// - и в библиотеках проверить, если указать полный путь - наверное не надо считать относительный в библиотеке...

//ToDo Directives: !NoOpt/!Opt

//ToDo даже если несколько блоков вызывают какой то один - можно всё равно узнать какие переменные могут иметь какой тип. FinalOptimize не проведёшь, но Optimize вполне
// - не забыть что блок может быть стартом программы
// - FinalOptimize всё же может случится, если нет такого что из 1 блока переменная Str, а из другого она же Num

//ToDo как насчёт директивы !DefFunc ?
// - объявляется в начале блока
// - можно указать список передаваемых переменных (или не так... хз пока)
// - это помогло бы создавать не_игрушечные библиотеки
// - с другой стороны, по хорошему надо написать .Net библиотеку для кликеров, ибо это всё всё равно баловство ради опыта и скриптов на 10-20 строк

//ToDo Проверить issue:
// - #1502
// - #1797

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
    
    public Sender: object;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Precompiling error in block {Sender}: ' + text);
      self.Sender := Sender;
      ExtraInfo := Dict(d);
    end;
    
  end;
  CannotOverrideConstException = class(FileCompilingException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Cannot override const');
    
  end;
  CannotOverrideReadonlyException = class(FileCompilingException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Cannot override readonly var''s from file, where they are not defined');
    
  end;
  InvalidUseOfConstDefException = class(FileCompilingException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Invalid use of const defining');
    
  end;
  ConflictingVarTypesException = class(FileCompilingException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Conflicting var types');
    
  end;
  VarDefOtherTException = class(FileCompilingException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Invalid var type, var defined as other type');
    
  end;
  InvalidVarTypeException = class(FileCompilingException)
    
    public constructor(source: object; vname: string) :=
    inherited Create(source, $'"{vname}" isn''t a defined variable type. Must be "Str" or "Num"');
    
  end;
  InvalidVarAccessTypeException = class(FileCompilingException)
    
    public constructor(source: object; at: string) :=
    inherited Create(source, $'"{at}" isn''t a defined variable access type. Must be "readonly" or "const"');
    
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
  InsufficientStmParamCount = class(FileCompilingException)
    
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
  ConstExprExpectedException = class(FileCompilingException)
    
    public constructor(par: string; opt: OptExprBase) :=
    inherited Create(source, $'Expected const expr{#10}Input [> {par} <] was optimized to [> {opt} <], but it can''t be converted to constant');
    
  end;
  DuplicateLabelNameException = class(FileCompilingException)
    
    public constructor(o: object; lbl: string) :=
    inherited Create(o, $'Duplicate label for {lbl} found');
    
  end;
  EntryPointNotFoundException = class(FileCompilingException)
    
    public constructor(o: object) :=
    inherited Create(o, $'Entry point "{o}" not found');
    
  end;
  CanOnlyStartFromStartPosException = class(FileCompilingException)
    
    public constructor(o: object) :=
    inherited Create(o, $'Start pos is defined, can''t start from other labels');
    
  end;
  LabelNotFoundException = class(FileCompilingException)
    
    public constructor(o: object; lbl: string) :=
    inherited Create(o, $'Label not found: {lbl}');
    
  end;
  
  {$endregion FileCompiling}
  
  {$region Inner}
  
  OutputStreamEmptyException = class(InnerException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Output stream was null');
    
  end;
  WrongConstTypeException = class(InnerException)
    
    public constructor(source: object) :=
    inherited Create(source, $'const had wrong type, not double nor string');
    
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
  InvalidSngDefValTException = class(LoadException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Invalid const val T');
    
  end;
  InvalidSngDefAccessTException = class(LoadException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Invalid var access T');
    
  end;
  CannotLoadAddSerializedScript = class(LoadException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Cannot add deserialized script, because it wasn''t serialized in lib mode');
    
  end;
  
  {$endregion Load}
  
  {$region Settings}
  
  WrongSettingsException = abstract class(Exception)
    
    public Sender: StmBlock;
    public ExtraInfo := new Dictionary<string, object>;
    
    public constructor(Sender: object; text: string; params d: array of KeyValuePair<string, object>);
    begin
      inherited Create($'Precompiling error in block {Sender}: ' + text);
      self.source := source;
    end;
    
  end;
  CannotSerializeInExecModeException = class(WrongSettingsException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Cannot serialize in non-lib compiller mode');
    
  end;
  CannotExecInLibModeException = class(WrongSettingsException)
    
    public constructor(source: object) :=
    inherited Create(source, $'Cannot execute in lib compiller mode');
    
  end;
  
  {$endregion Settings}
  
  {$endregion Exception's}
  
  {$region Misc}
  
  SuppressedIOData = sealed class
    
    public mX,mY: integer;
    public ks := new byte[256];
    
  end;
  
  VarAccessT = (none=byte(0), read_only=byte(1), init_only=byte(2));
  
  comprT = (equ=byte(1), less=byte(2), more=byte(3));
  
  ExecutingContext = sealed class
    
    public scr: Script;
    
    public curr: StmBlock;
    public next: StmBlock;
    public nvs := new Dictionary<string, real>;
    public svs := new Dictionary<string, string>;
    public CallStack := new Stack<StmBlock>;
    public max_recursion: integer;
    
    public procedure Push(bl: StmBlock);
    begin
      if CallStack.Count >= max_recursion then raise new RecursionTooBig(scr, max_recursion);
      
      CallStack.Push(bl);
      
    end;
    
    public function Pop(var bl: StmBlock): boolean;
    begin
      Result := CallStack.Count > 0;
      if Result then
        bl := CallStack.Pop else
        bl := nil;
    end;
    
    public procedure SetVar(vname:string; val: object);
    
    public function ExecuteNext: boolean;
    
    public constructor(scr: Script; entry_point: StmBlock; max_recursion: integer);
    begin
      self.scr := scr;
      self.curr := entry_point;
      self.max_recursion := max_recursion;
    end;
    
  end;
  
  {$endregion Misc}
  
  {$region Single stm}
  
  StmBase = abstract class
    
    private static nfi := new System.Globalization.NumberFormatInfo;
    private static tps_lst := new List<System.Type>;
    
    public bl: StmBlock;
    public scr: Script;
    
    
    
    public function GetCalc: sequence of Action<ExecutingContext>; abstract;
    
    public function GetAllExprs: sequence of OptExprWrapper; virtual :=
    new OptExprWrapper[0];
    
    
    
    ///Only creates new instance for stms that can change container when optimized (like when Jump becomes [Const])
    public function Copy(container: StmBlock): StmBase; virtual := self;
    
    public function IsSame(stm: StmBase): boolean; abstract;
    
    public procedure CheckSngDef; virtual := exit;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; virtual := self;
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; virtual :=
    Optimize(prev_bls, nvn,svn);
    
    public function FindVarUsages(vn: string): sequence of OptExprWrapper :=
    GetAllExprs.Where(oe->oe.DoesUseVar(vn));
    
    public procedure ResetExprDelegats :=
    foreach var oe in GetAllExprs do oe.ResetCalc;
    
    public function DoesRewriteVar(vn: string): boolean; virtual := false;
    
    
    
    
    public static function FromString(bl: StmBlock; s: string; par: array of string): StmBase;
    
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
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): StmBase;
    
    
    
    public static procedure AddVarTypesComments(res: StringBuilder; oes: sequence of OptExprWrapper);
    begin
      
      var NumChecks := oes.SelectMany(oe->oe.NumChecks.Keys).ToList;
      var StrChecks := oes.SelectMany(oe->oe.StrChecks.Keys).ToList;
      
      var n_vars_names := oes.SelectMany(oe->oe.n_vars_names).ToList;
      var s_vars_names := oes.SelectMany(oe->oe.s_vars_names).ToList;
      var o_vars_names := oes.SelectMany(oe->oe.o_vars_names).ToList;
      
      
      
      if NumChecks.Count<>0 then
      begin
        res += ' NumChecks={';
        
        res += NumChecks[0];
        foreach var vname in NumChecks.Skip(1) do
        begin
          res += ', ';
          res += vname;
        end;
        
        res += '}';
      end;
      
      if StrChecks.Count<>0 then
      begin
        res += ' StrChecks={';
        
        res += StrChecks[0];
        foreach var vname in StrChecks.Skip(1) do
        begin
          res += ', ';
          res += vname;
        end;
        
        res += '}';
      end;
      
      
      
      if n_vars_names.Count<>0 then
      begin
        res += ' Nums={';
        
        res += n_vars_names[0];
        foreach var vname in n_vars_names.Skip(1) do
        begin
          res += ', ';
          res += vname;
        end;
        
        res += '}';
      end;
      
      if s_vars_names.Count<>0 then
      begin
        res += ' Strs={';
        
        res += s_vars_names[0];
        foreach var vname in s_vars_names.Skip(1) do
        begin
          res += ', ';
          res += vname;
        end;
        
        res += '}';
      end;
      
      if o_vars_names.Count<>0 then
      begin
        res += ' Objs={';
        
        res += o_vars_names[0];
        foreach var vname in o_vars_names.Skip(1) do
        begin
          res += ', ';
          res += vname;
        end;
        
        res += '}';
      end;
      
    end;
    
    public static procedure AddVarTypesComments(res: StringBuilder; params oes: array of OptExprWrapper) :=
    AddVarTypesComments(res, oes.AsEnumerable);
    
  end;
  ExprStm = sealed class(StmBase)
    
    public vname: string;
    public e: OptExprWrapper;
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, e.Calc(
      ec.nvs,
      ec.svs
    ));
    
    
    
    public constructor(bl: StmBlock; text: string);
    
    public constructor(vname: string; e: OptExprWrapper; bl: StmBlock; scr: Script);
    begin
      self.vname := vname;
      self.e := e;
      self.bl := bl;
      self.scr := scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as ExprStm;
      if nstm=nil then exit;
      
      Result :=
        (self.vname = nstm.vname) and
        e.IsSame(nstm.e);
      
    end;
    
    public function Simplify(ne: OptExprWrapper): StmBase;
    begin
      
      if e=ne then
        Result := self else
        Result := new ExprStm(vname, ne, bl, scr);
      
    end;
    
    public procedure CheckSngDef; override;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override;
    begin
      Result := Simplify(e.Optimize(nvn,svn));
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
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override;
    begin
      Result := Simplify(e.FinalOptimize(nvn,svn,ovn));
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
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    new OptExprWrapper[](e);
    
    public function DoesRewriteVar(vn: string): boolean; override := self.vname=vn;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(0));
      bw.Write(vname);
      e.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): ExprStm;
    begin
      Result := new ExprStm;
      Result.vname := br.ReadString;
      Result.e := OptExprWrapper.Load(br);
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += vname;
      res += '=';
      res += e.ToString;
      
      AddVarTypesComments(res, e);
      
      Result := res.ToString;
    end;
    
  end;
  OperStmBase = abstract class(StmBase)
    
    public static function FromString(bl: StmBlock; par: array of string): OperStmBase;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
    
  end;
  DrctStmBase = abstract class(StmBase)
    
    public static function FromString(bl: StmBlock; s: string; par: array of string): DrctStmBase;
    
    private constructor := raise new System.NotSupportedException;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      Result := false;
      raise new System.NotSupportedException;
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override := nil;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[0];
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): DrctStmBase;
    
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
    
    private static procedure _EmptyBlockExecute(ec: ExecutingContext) := exit;
    
    public procedure Seal;
    begin
      
      foreach var stm in stms do
        stm.ResetExprDelegats;
      
      Execute :=
        System.Delegate.Combine(
          stms
          .SelectMany(stm->stm.GetCalc())
          .Cast&<System.Delegate>
          .ToArray
        ) as Action<ExecutingContext>;
      
      if Execute=nil then Execute := _EmptyBlockExecute;
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
      if next.lbl = '' then
      begin
        bw.Write(-2);
        next.Save(bw);
      end else
        next.SaveId(bw)
      
    end;
    
    public procedure SaveId(bw: System.IO.BinaryWriter);
    
    public procedure Load(br: System.IO.BinaryReader; bls: array of StmBlock);
    begin
      StartPos := br.ReadBoolean;
      
      var c := br.ReadInt32;
      self.stms := new List<StmBase>(c);
      for var i := 0 to c-1 do
      begin
        var stm := StmBase.Load(br, bls);
        stm.bl := self;
        stm.scr := self.scr;
        self.stms.Add(stm);
      end;
      
      var n := br.ReadInt32;
      if n <> -1 then
        if n = -2 then
        begin
          self.next := new StmBlock(self.scr);
          self.next.Load(br, bls);
          self.next.fname := self.fname;
        end else
        if cardinal(n) < bls.Length then
          self.next := bls[n] else
          raise new InvalidStmBlIdException(n, bls.Length);
      
      self.Seal;
    end;
    
    public function GetBodyString: string :=
    (StartPos?'!StartPos [Const]'#10:'') +
    stms.JoinIntoString(#10);
    
    public function ToString: string; override;
    
  end;
  
  Script = sealed class
    
    private static nfi := new System.Globalization.NumberFormatInfo;
    
    public read_start_lbl_name: string;
    private main_path: string;
    public start_pos_def := false;
    
    public settings: ExecParams;
    public SupprIO: SuppressedIOData := nil;
    
    public otp: procedure(s: string);
    public susp_called: procedure;
    public stoped: procedure;
    
    public LoadedFiles := new HashSet<string>;
    public bls := new Dictionary<string, StmBlock>;
    
    public SngDefConsts := new Dictionary<string, object>;
    public SngDefNums := new Dictionary<string, (boolean, string)>;//is readonly, fname for readonly
    public SngDefStrs := new Dictionary<string, (boolean, string)>;
    
    {$region Utility}
    
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
      
      var bl := new StringBuilder;
      var pp1 := p1.Split('\');
      var pp2 := p2.Split('\');
      
      var sc := pp1.ZipTuple(pp2).TakeWhile(t->t[0]=t[1]).Count;
      loop pp1.Length-sc do bl += '..\';
      
      foreach var pp in pp2.Skip(sc) do
      begin
        bl += pp;
        bl += '\';
      end;
      bl.Length -= 1;
      
      Result := bl.ToString;
    end;
    
    {$endregion Utility}
    
    {$region Script from text file}
    
    private function ReadFile(context: object; lbl: string): boolean;
    
    public constructor(fname: string; ep: ExecParams);
    
    //ToDo #1502
//    public constructor(fname: string) :=
//    Create(fname, new ExecParams);
    
    {$endregion Script from text file}
    
    {$region Optimizing}
    
    public procedure AddSngDef(vname: string; IsNum: boolean; val: object; Access: VarAccessT; fname: string);
    
    public procedure AllCheckSngDef :=
    foreach var bl in bls.Values do
      foreach var stm in bl.stms do
        stm.CheckSngDef;
    
    public procedure CheckCanOverride(vname, fname: string);
    begin
      if SngDefConsts.ContainsKey(vname) then raise new CannotOverrideConstException(nil);
      var def: (boolean, string);
      
      if SngDefNums.ContainsKey(vname) then def := SngDefNums[vname] else
      if SngDefStrs.ContainsKey(vname) then def := SngDefStrs[vname] else
        exit;
      
      if def[0] and (def[1] <> fname) then
        raise new CannotOverrideReadonlyException(nil);
      
    end;
    
    public procedure ReplaceAllConstsFor(oe: OptExprWrapper);
    
    public procedure Optimize;
    
    {$endregion Optimizing}
    
    {$region Executing}
    
    public procedure Execute :=
    Execute(read_start_lbl_name);
    
    public procedure Execute(entry_point: string);
    begin
      if settings.lib_mode then raise new CannotExecInLibModeException(nil);
      
      if not entry_point.Contains('#') then entry_point += '#';
      if not bls.ContainsKey(entry_point) then raise new EntryPointNotFoundException(nil);
      var ec := new ExecutingContext(self, bls[entry_point], 10000);
      if start_pos_def and not ec.curr.StartPos then raise new CanOnlyStartFromStartPosException(nil);
      while ec.ExecuteNext do;
      if stoped <> nil then
        stoped;
    end;
    
    {$endregion Executing}
    
    {$region Binary serialization}
    
    public procedure SaveContent(bw: System.IO.BinaryWriter);
    
    public procedure SaveLib(fname: string);
    begin
      if not settings.lib_mode then raise new CannotSerializeInExecModeException(nil);
      
      var str := System.IO.File.Create(fname);
      
      var sw := new System.IO.StreamWriter(str);
      sw.Write('!PreComp=');
      sw.Flush;
      
      var bw := new System.IO.BinaryWriter(str);
      bw.Write(true);
      
      SaveContent(bw);
      
      str.Close;
    end;
    
    public procedure Serialize(str: System.IO.Stream);
    begin
      var bw := new System.IO.BinaryWriter(str);
      bw.Write(false);
      SaveContent(bw);
    end;
    
    private procedure LoadContent(virtual_path: string; br: System.IO.BinaryReader);
    begin
      var prev_main_fname := br.ReadString;
      var new_main_fname := virtual_path.Split('\').Last;
      var load_path := System.IO.Path.GetDirectoryName(virtual_path);
      
      self.start_pos_def := br.ReadBoolean or self.start_pos_def;
      
      loop br.ReadInt32 do
      begin
        var vname := br.ReadString;
        var val: object;
        case br.ReadByte of
          1: val := nil;
          2: val := br.ReadString;
          3: val := br.ReadDouble;
        end;
        AddSngDef(vname, val is real, val, VarAccessT.init_only, nil);
      end;
      
      loop br.ReadInt32 do
      begin
        var vname := br.ReadString;
        var is_readonly := br.ReadBoolean;
        var fname := CombinePaths(load_path, br.ReadString);
        AddSngDef(vname,false,nil,is_readonly?VarAccessT.read_only:VarAccessT.none,fname);
      end;
      
      loop br.ReadInt32 do
      begin
        var vname := br.ReadString;
        var is_readonly := br.ReadBoolean;
        var fname := CombinePaths(load_path, br.ReadString);
        AddSngDef(vname,true,nil,is_readonly?VarAccessT.read_only:VarAccessT.none,fname);
      end;
      
      var lbls := new StmBlock[br.ReadInt32];
      for var i := 0 to lbls.Length-1 do
        lbls[i] := new StmBlock(self);
      
      loop br.ReadInt32 do
      begin
        var fname := br.ReadString;
        if fname = prev_main_fname then
          fname := new_main_fname;
        fname := CombinePaths(load_path, fname);
        
        loop br.ReadInt32 do
        begin
          var i := br.ReadInt32;
          lbls[i].fname := fname;
          lbls[i].lbl := '#'+br.ReadString;
          lbls[i].Load(br, lbls);
        end;
        
      end;
      
      for var i := 0 to lbls.Length-1 do
      begin
        
        var key := lbls[i].fname + lbls[i].lbl;
        if not self.bls.ContainsKey(key) then
          self.bls.Add(key, lbls[i]) else
          raise new DuplicateLabelNameException(nil, key);
        
      end;
      
      self.Optimize;
    end;
    
    public procedure LoadAdd(virtual_path: string; br: System.IO.BinaryReader);
    begin
      if not br.ReadBoolean then raise new CannotLoadAddSerializedScript(nil);
      LoadContent(virtual_path, br);
    end;
    
    public static function LoadNew(virtual_path: string; str: System.IO.Stream; ep: ExecParams): Script;
    begin
      Result := new Script;
      Result.settings := ep;
      if ep.SupprIO then
        Result.SupprIO := new SuppressedIOData;
      
      Result.read_start_lbl_name := virtual_path;
      if Result.read_start_lbl_name.Contains('#') then
        Result.main_path := Result.read_start_lbl_name.Remove(Result.read_start_lbl_name.IndexOf('#')) else
        Result.main_path := Result.read_start_lbl_name;
      Result.main_path := System.IO.Path.GetDirectoryName(Result.main_path);
      
      var br := new System.IO.BinaryReader(str);
      br.ReadBoolean; // both libs and non-libs can be loaded this way
      
      Result.LoadContent(virtual_path, br);
    end;
    
    {$endregion Binary serialization}
    
    {$region Decompiling}
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      foreach var kvp: System.Linq.IGrouping<string, StmBlock> in bls.Values.GroupBy(bl->bl.fname) do
      begin
        res += $' (file {GetRelativePath(main_path,kvp.Key)})';
        res += #10;
        
        foreach var bl: StmBlock in kvp do
        begin
          res += bl.lbl;
          res += #10;
          res += bl.ToString;
          res += #10;
        end;
        
      end;
      
      Result := res.ToString;
    end;
    
    {$endregion Decompiling}
    
  end;

  {$endregion Stm containers}
  
  {$region InputValue}
  
  InputNValue = abstract class
    
    public res: real;
    
    public function IsSame(val: InputNValue): boolean; abstract;
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public function Optimize(nvn,svn: HashSet<string>): InputNValue; virtual := self;
    public function FinalOptimize(nvn,svn,ovn: HashSet<string>): InputNValue; virtual := self;
    
    public function GetAllExprs: sequence of OptExprWrapper; virtual :=
    new OptExprWrapper[0];
    
    public static function Load(br: System.IO.BinaryReader): InputNValue;
    
  end;
  SInputNValue = sealed class(InputNValue)
    
    public constructor(res: real) :=
    self.res := res;
    
    public function IsSame(val: InputNValue): boolean; override :=
    (val is SInputNValue(var nval)) and
    (self.res = nval.res);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
    public static function Load(br: System.IO.BinaryReader): SInputNValue;
    begin
      Result := new SInputNValue;
      Result.res := br.ReadDouble;
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
    
    public function IsSame(val: InputNValue): boolean; override :=
    (val is DInputNValue(var nval)) and
    self.oe.IsSame(nval.oe);
    
    public function Simplify(noe: OptNExprWrapper): InputNValue;
    begin
      if noe.Main is OptNLiteralExpr(var nle) then
        Result := new SInputNValue(nle.res) else
      if oe=noe then
        Result := self else
        Result := new DInputNValue(noe);
    end;
    
    public function Optimize(nvn,svn: HashSet<string>): InputNValue; override :=
    Simplify(OptNExprWrapper(oe.Optimize(nvn,svn)));
    
    public function FinalOptimize(nvn,svn,ovn: HashSet<string>): InputNValue; override :=
    Simplify(OptNExprWrapper(oe.FinalOptimize(nvn,svn,ovn)));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    new OptExprWrapper[](oe);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      oe.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): DInputNValue;
    begin
      Result := new DInputNValue;
      Result.oe := OptNExprWrapper(OptExprWrapper.Load(br));
    end;
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function ToString: string; override :=
    oe.ToString;
    
  end;
  
  InputSValue = abstract class
    
    public res: string;
    
    public function IsSame(val: InputSValue): boolean; abstract;
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public function Optimize(nvn,svn: HashSet<string>): InputSValue; virtual := self;
    public function FinalOptimize(nvn,svn,ovn: HashSet<string>): InputSValue; virtual := self;
    
    public function GetAllExprs: sequence of OptExprWrapper; virtual :=
    new OptExprWrapper[0];
    
    public static function Load(br: System.IO.BinaryReader): InputSValue;
    
  end;
  SInputSValue = sealed class(InputSValue)
    
    public constructor(res: string) :=
    self.res := res;
    
    public function IsSame(val: InputSValue): boolean; override :=
    (val is SInputSValue(var nval)) and
    (self.res = nval.res);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      bw.Write(res);
    end;
    
    public static function Load(br: System.IO.BinaryReader): SInputSValue;
    begin
      Result := new SInputSValue;
      Result.res := br.ReadString;
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
    
    public function IsSame(val: InputSValue): boolean; override :=
    (val is DInputSValue(var nval)) and
    self.oe.IsSame(nval.oe);
    
    public function Simplify(noe: OptSExprWrapper): InputSValue;
    begin
      if noe.Main is OptSLiteralExpr(var sle) then
        Result := new SInputSValue(sle.res) else
      if oe=noe then
        Result := self else
        Result := new DInputSValue(noe);
    end;
    
    public function Optimize(nvn,svn: HashSet<string>): InputSValue; override :=
    Simplify(OptSExprWrapper(oe.Optimize(nvn,svn)));
    
    public function FinalOptimize(nvn,svn,ovn: HashSet<string>): InputSValue; override :=
    Simplify(OptSExprWrapper(oe.FinalOptimize(nvn,svn,ovn)));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    new OptExprWrapper[](oe);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      oe.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader): DInputSValue;
    begin
      Result := new DInputSValue;
      Result.oe := OptSExprWrapper(OptExprWrapper.Load(br));
    end;
    
    public function GetCalc: Action<ExecutingContext>; override := self.Calc;
    
    public function ToString: string; override :=
    oe.ToString;
    
  end;
  
  {$endregion InputValue}
  
  {$region StmBlockRef}
  
  StmBlockRef = abstract class
    
    public function GetCalc: Action<ExecutingContext>; virtual := nil;
    
    public function GetBlock(scr: Script): StmBlock; abstract;
    
    public function IsSame(ref: StmBlockRef): boolean; abstract;
    
    public function Optimize(scr: Script; nvn,svn: HashSet<string>): StmBlockRef; virtual := self;
    public function FinalOptimize(scr: Script; nvn,svn,ovn: HashSet<string>): StmBlockRef; virtual := self;
    
    public function GetAllExprs: sequence of OptExprWrapper; virtual :=
    new OptExprWrapper[0];
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): StmBlockRef;
    
  end;
  StaticStmBlockRef = sealed class(StmBlockRef)
    
    public bl: StmBlock;
    
    public function GetBlock(scr: Script): StmBlock; override := bl;
    
    public constructor(bl: StmBlock) :=
    self.bl := bl;
    
    public function IsSame(ref: StmBlockRef): boolean; override :=
    (ref is StaticStmBlockRef(var nref)) and
    (self.bl = nref.bl);
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(1));
      if bl = nil then
        bw.Write(-1) else
        bl.SaveId(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): StaticStmBlockRef;
    begin
      Result := new StaticStmBlockRef;
      
      var n := br.ReadInt32;
      if n <> -1 then
        if cardinal(n) < bls.Length then
          Result.bl := bls[n] else
          raise new InvalidStmBlIdException(n, bls.Length);
      
    end;
    
    public function ToString: string; override :=
    bl=nil?'null':
    $'"{Script.GetRelativePath(bl.scr.main_path, bl.fname+bl.lbl)}"';
    
  end;
  DynamicStmBlockRef = sealed class(StmBlockRef)
    
    public s: InputSValue;
    public org_fname: string;
    
    public function IsSame(ref: StmBlockRef): boolean; override :=
    (ref is DynamicStmBlockRef(var nref)) and
    self.s.IsSame(nref.s) and
    (self.org_fname = nref.org_fname);
    
    public function GetCalc: Action<ExecutingContext>; override := s.GetCalc();
    
    public function GetBlock(scr: Script): StmBlock; override;
    begin
      var res := s.res;
      if res <> '' then
      begin
        if res.StartsWith('#') then
          res := org_fname+res else
          res := Script.CombinePaths(System.IO.Path.GetDirectoryName(org_fname), res);
        
        if not res.Contains('#') then res += '#';
        
        if not scr.bls.ContainsKey(res) then
        begin
          scr.ReadFile(nil, res);
          scr.AllCheckSngDef;
          
          if not scr.bls.ContainsKey(res) then
            raise new LabelNotFoundException(nil, res);
          
        end;
        
        Result := scr.bls[res];
      end;
    end;
    
    public constructor(s: InputSValue; org_fname: string);
    begin
      self.s := s;
      self.org_fname := org_fname;
    end;
    
    public function Simplify(scr: Script; ns: InputSValue): StmBlockRef;
    begin
      if ns is SInputSValue then
      begin
        self.s := ns;
        Result := new StaticStmBlockRef(self.GetBlock(scr));
      end else
      if s=ns then
        Result := self else
        Result := new DynamicStmBlockRef(ns, org_fname);
    end;
    
    public function Optimize(scr: Script; nvn,svn: HashSet<string>): StmBlockRef; override :=
    Simplify(scr, s.Optimize(nvn,svn));
    
    public function Optimize(scr: Script) :=
    Optimize(scr, new HashSet<string>, new HashSet<string>);
    
    public function FinalOptimize(scr: Script; nvn,svn,ovn: HashSet<string>): StmBlockRef; override :=
    Simplify(scr, s.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    s.GetAllExprs;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(byte(2));
      s.Save(bw);
      bw.Write(org_fname);
    end;
    
    public static function Load(br: System.IO.BinaryReader): DynamicStmBlockRef;
    begin
      Result := new DynamicStmBlockRef;
      Result.s := InputSValue.Load(br);
      Result.org_fname := br.ReadString;
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
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext) :=
    keybd_event(kk, 0, 0, 0);
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.scr.SupprIO.ks[kk] := $80 or ($01 and not ec.scr.SupprIO.ks[kk]);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstKeyDown;
      if nstm=nil then exit;
      
      Result := self.kk = nstm.kk;
      
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'KeyD {kk} [Const]';
    
  end;
  OperConstKeyUp = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext) :=
    keybd_event(kk, 0, 2, 0);
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.scr.SupprIO.ks[kk] := not ($80 or not ec.scr.SupprIO.ks[kk]);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstKeyUp;
      if nstm=nil then exit;
      
      Result := self.kk = nstm.kk;
      
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'KeyU {kk} [Const]';
    
  end;
  OperConstKeyPress = sealed class(OperStmBase)
    
    public kk: byte;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      keybd_event(kk, 0, 0, 0);
      keybd_event(kk, 0, 2, 0);
    end;
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.scr.SupprIO.ks[kk] := $01 and not ec.scr.SupprIO.ks[kk];
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstKeyPress;
      if nstm=nil then exit;
      
      Result := self.kk = nstm.kk;
      
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'KeyP {kk} [Const]';
    
  end;
  
  OperKeyDown = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 0, 0);
    end;
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      ec.scr.SupprIO.ks[n] := $80 or ($01 and not ec.scr.SupprIO.ks[n]);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperKeyDown;
      if nstm=nil then exit;
      
      Result := self.kk.IsSame(nstm.kk);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'KeyD ';
      res += kk.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  OperKeyUp = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 2, 0);
    end;
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      ec.scr.SupprIO.ks[n] := not ($80 or not ec.scr.SupprIO.ks[n]);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperKeyUp;
      if nstm=nil then exit;
      
      Result := self.kk.IsSame(nstm.kk);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'KeyU ';
      res += kk.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  OperKeyPress = sealed class(OperStmBase)
    
    public kk: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      keybd_event(n, 0, 0, 0);
      keybd_event(n, 0, 2, 0);
    end;
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      ec.scr.SupprIO.ks[n] := $01 and not ec.scr.SupprIO.ks[n];
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperKeyPress;
      if nstm=nil then exit;
      
      Result := self.kk.IsSame(nstm.kk);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(1));
      bw.Write(byte(4));
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'KeyP ';
      res += kk.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  OperKey = sealed class(OperStmBase)
    
    public kk, dp: InputNValue;
    
    static procedure keybd_event(bVk, bScan: byte; dwFlags, dwExtraInfo: cardinal);
    external 'User32.dll' name 'keybd_event';
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var p := NumToInt(nil, dp.res);
      if p and $1 = $1 then keybd_event(n,0,0,0);
      if p and $2 = $2 then keybd_event(n,0,2,0);
    end;
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var p := NumToInt(nil, dp.res);
      if p and $1 = $1 then ec.scr.SupprIO.ks[n] := $80 or ($01 and not ec.scr.SupprIO.ks[n]);
      if p and $2 = $2 then ec.scr.SupprIO.ks[n] := not ($80 or not ec.scr.SupprIO.ks[n]);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientStmParamCount(self.scr, 3, par);
      
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
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperKey;
      if nstm=nil then exit;
      
      Result :=
        self.kk.IsSame(nstm.kk) and
        self.dp.IsSame(nstm.dp);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn), dp.Optimize(nvn,svn), stm->stm.Optimize(prev_bls, nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn), dp.FinalOptimize(nvn,svn,ovn), stm->stm.FinalOptimize(prev_bls, nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs() + dp.GetAllExprs;//ToDo #1797
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'Key ';
      res += kk.ToString;
      res += ' ';
      res += dp.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs()+dp.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.scr.SupprIO.ks[kk] := $80 or ($01 and not ec.scr.SupprIO.ks[kk]);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstMouseDown;
      if nstm=nil then exit;
      
      Result := self.kk = nstm.kk;
      
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
      
      if scr.SupprIO=nil then
        case kk of
          1: Result := new Action<ExecutingContext>[](Calc1);
          2: Result := new Action<ExecutingContext>[](Calc2);
          4: Result := new Action<ExecutingContext>[](Calc4);
          5: Result := new Action<ExecutingContext>[](Calc5);
          6: Result := new Action<ExecutingContext>[](Calc6);
          else raise new InvalidMouseKeyCodeException(scr, kk);
        end else
          Result := new Action<ExecutingContext>[](CalcSuppr);
      
    end;
    
    public function ToString: string; override :=
    $'MouseD {kk} [Const]';
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.scr.SupprIO.ks[kk] := not ($80 or not ec.scr.SupprIO.ks[kk]);
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstMouseUp;
      if nstm=nil then exit;
      
      Result := self.kk = nstm.kk;
      
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
      
      if scr.SupprIO=nil then
        case kk of
          1: Result := new Action<ExecutingContext>[](Calc1);
          2: Result := new Action<ExecutingContext>[](Calc2);
          4: Result := new Action<ExecutingContext>[](Calc4);
          5: Result := new Action<ExecutingContext>[](Calc5);
          6: Result := new Action<ExecutingContext>[](Calc6);
          else raise new InvalidMouseKeyCodeException(scr, kk);
        end else
          Result := new Action<ExecutingContext>[](CalcSuppr);
      
    end;
    
    public function ToString: string; override :=
    $'MouseU {kk} [Const]';
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.scr.SupprIO.ks[kk] := $01 and not ec.scr.SupprIO.ks[kk];
    
    
    
    public constructor(kk: byte; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstMousePress;
      if nstm=nil then exit;
      
      Result := self.kk = nstm.kk;
      
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
      
      if scr.SupprIO=nil then
        case kk of
          1: Result := new Action<ExecutingContext>[](Calc1);
          2: Result := new Action<ExecutingContext>[](Calc2);
          4: Result := new Action<ExecutingContext>[](Calc4);
          5: Result := new Action<ExecutingContext>[](Calc5);
          6: Result := new Action<ExecutingContext>[](Calc6);
          else raise new InvalidMouseKeyCodeException(scr, kk);
        end else
          Result := new Action<ExecutingContext>[](CalcSuppr);
      
    end;
    
    public function ToString: string; override :=
    $'MouseP {kk} [Const]';
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      case n of
        1,2,4..6: ;
        else raise new InvalidMouseKeyCodeException(scr, n);
      end;
      ec.scr.SupprIO.ks[n] := $80 or ($01 and not ec.scr.SupprIO.ks[n]);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperMouseDown;
      if nstm=nil then exit;
      
      Result := self.kk.IsSame(nstm.kk);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'MouseD ';
      res += kk.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      case n of
        1,2,4..6: ;
        else raise new InvalidMouseKeyCodeException(scr, n);
      end;
      ec.scr.SupprIO.ks[n] := not ($80 or not ec.scr.SupprIO.ks[n]);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperMouseUp;
      if nstm=nil then exit;
      
      Result := self.kk.IsSame(nstm.kk);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'MouseU ';
      res += kk.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      case n of
        1,2,4..6: ;
        else raise new InvalidMouseKeyCodeException(scr, n);
      end;
      ec.scr.SupprIO.ks[n] := $01 and not ec.scr.SupprIO.ks[n];
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(self.scr, 2, par);
      
      kk := new DInputNValue(par[1]);
    end;
    
    public constructor(kk: InputNValue; bl: StmBlock);
    begin
      self.kk := kk;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperMousePress;
      if nstm=nil then exit;
      
      Result := self.kk.IsSame(nstm.kk);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'MouseP ';
      res += kk.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil,kk.res);
      case n of
        1,2,4..6: ;
        else raise new InvalidMouseKeyCodeException(scr, n);
      end;
      var p := NumToInt(nil, dp.res);
      if p and $1 = $1 then ec.scr.SupprIO.ks[n] := $80 or ($01 and not ec.scr.SupprIO.ks[n]);
      if p and $2 = $2 then ec.scr.SupprIO.ks[n] := not ($80 or not ec.scr.SupprIO.ks[n]);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientStmParamCount(self.scr, 3, par);
      
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
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperMouse;
      if nstm=nil then exit;
      
      Result :=
        self.kk.IsSame(nstm.kk) and
        self.dp.IsSame(nstm.dp);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn), dp.Optimize(nvn,svn), stm->stm.Optimize(prev_bls, nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn), dp.FinalOptimize(nvn,svn,ovn), stm->stm.FinalOptimize(prev_bls, nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs() + dp.GetAllExprs;//ToDo #1797
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'Mouse ';
      res += kk.ToString;
      res += ' ';
      res += dp.ToString;
      
      AddVarTypesComments(res, kk.GetAllExprs()+dp.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  
  {$endregion Key/Mouse}
  
  {$region Other simulators}
  
  OperConstMousePos = sealed class(OperStmBase)
    
    public x,y: integer;
    
    static procedure SetCursorPos(x, y: integer);
    external 'User32.dll' name 'SetCursorPos';
    
    private procedure Calc(ec: ExecutingContext) :=
    SetCursorPos(x,y);
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      ec.scr.SupprIO.mX := x;
      ec.scr.SupprIO.mX := y;
    end;
    
    
    
    public constructor(x,y: integer; bl: StmBlock);
    begin
      self.x := x;
      self.y := y;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstMousePos;
      if nstm=nil then exit;
      
      Result :=
        (self.x = nstm.x) and
        (self.y = nstm.y);
      
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'MousePos {x} {y} [Const]';
    
  end;
  OperConstGetKey = sealed class(OperStmBase)
    
    public kk: byte;
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, (GetKeyState(kk) and $80 <> 0)?1.0:0.0);
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.SetVar(vname, (ec.scr.SupprIO.ks[kk] and $80 <> 0)?1.0:0.0);
    
    
    
    public constructor(kk: byte; vname: string; bl: StmBlock);
    begin
      self.kk := kk;
      self.vname := vname;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstGetKey;
      if nstm=nil then exit;
      
      Result :=
        (self.kk = nstm.kk) and
        (self.vname = nstm.vname);
      
    end;
    
    public procedure CheckSngDef; override :=
    scr.CheckCanOverride(vname, bl.fname);
    
    public function Simplify(nvn,svn,ovn: HashSet<string>): StmBase;
    begin
      Result := self;
      
      nvn.Add(vname);
      svn.Remove(vname);
      if ovn<>nil then ovn.Remove(vname);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn, nil);
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn,ovn);
    
    public function DoesRewriteVar(vn: string): boolean; override := self.vname=vn;
    
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'GetKey {kk} {vname} [Const]';
    
  end;
  OperConstGetKeyTrigger = sealed class(OperStmBase)
    
    public kk: byte;
    public vname: string;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, (GetKeyState(kk) and $01 <> 0)?1.0:0.0);
    
    private procedure CalcSuppr(ec: ExecutingContext) :=
    ec.SetVar(vname, (ec.scr.SupprIO.ks[kk] and $01 <> 0)?1.0:0.0);
    
    
    
    public constructor(kk: byte; vname: string; bl: StmBlock);
    begin
      self.kk := kk;
      self.vname := vname;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstGetKeyTrigger;
      if nstm=nil then exit;
      
      Result :=
        (self.kk = nstm.kk) and
        (self.vname = nstm.vname);
      
    end;
    
    public procedure CheckSngDef; override :=
    scr.CheckCanOverride(vname, bl.fname);
    
    public function Simplify(nvn,svn,ovn: HashSet<string>): StmBase;
    begin
      Result := self;
      
      nvn.Add(vname);
      svn.Remove(vname);
      if ovn<>nil then ovn.Remove(vname);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn, nil);
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn,ovn);
    
    public function DoesRewriteVar(vn: string): boolean; override := self.vname=vn;
    
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'GetKeyTrigger {kk} {vname} [Const]';
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      ec.scr.SupprIO.mX := NumToInt(nil, x.res);
      ec.scr.SupprIO.mX := NumToInt(nil, y.res);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientStmParamCount(self.scr, 3, par);
      
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
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperMousePos;
      if nstm=nil then exit;
      
      Result :=
        self.x.IsSame(nstm.x) and
        self.y.IsSame(nstm.y);
      
    end;
    
    public function Simplify(nx,ny: InputNValue): StmBase;
    begin
      if (nx is SInputNValue) and (ny is SInputNValue) then
        Result := new OperConstMousePos(NumToInt(nil, nx.res), NumToInt(nil, ny.res), bl) else
      if (x=nx) and (y=ny) then
        Result := self else
        Result := new OperMousePos(nx,ny, bl);
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(x.Optimize(nvn,svn), y.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(x.FinalOptimize(nvn,svn,ovn), y.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    x.GetAllExprs() + y.GetAllExprs;//ToDo #1797
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'MousePos ';
      res += x.ToString;
      res += ' ';
      res += y.ToString;
      
      AddVarTypesComments(res, x.GetAllExprs()+y.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var k := ec.scr.SupprIO.ks[n] and $80 = $80;
      ec.SetVar(vname, k?1.0:0.0);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientStmParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1]);
      vname := par[2];
    end;
    
    public constructor(kk: InputNValue; vname: string; bl: StmBlock);
    begin
      self.kk := kk;
      self.vname := vname;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperGetKey;
      if nstm=nil then exit;
      
      Result :=
        self.kk.IsSame(nstm.kk) and
        (self.vname = nstm.vname);
      
    end;
    
    public procedure CheckSngDef; override :=
    scr.CheckCanOverride(vname, bl.fname);
    
    public function Simplify(nkk: InputNValue; nvn,svn,ovn: HashSet<string>): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var n := NumToInt(nil, nkk.res);
        if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
        Result := new OperConstGetKey(n, vname, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperGetKey(nkk, vname, bl);
      
      nvn.Add(vname);
      svn.Remove(vname);
      if ovn<>nil then ovn.Remove(vname);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn), nvn,svn, nil);
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn), nvn,svn,ovn);
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
    public function DoesRewriteVar(vn: string): boolean; override := self.vname=vn;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'GetKey ';
      res += kk.ToString;
      res += ' ';
      res += vname;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      var n := NumToInt(nil, kk.res);
      if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
      var k := ec.scr.SupprIO.ks[n] and $01 = $01;
      ec.SetVar(vname, k?1.0:0.0);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientStmParamCount(self.scr, 3, par);
      
      kk := new DInputNValue(par[1]);
      vname := par[2];
    end;
    
    public constructor(kk: InputNValue; vname: string; bl: StmBlock);
    begin
      self.kk := kk;
      self.vname := vname;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperGetKeyTrigger;
      if nstm=nil then exit;
      
      Result :=
        self.kk.IsSame(nstm.kk) and
        (self.vname = nstm.vname);
      
    end;
    
    public procedure CheckSngDef; override :=
    scr.CheckCanOverride(vname, bl.fname);
    
    public function Simplify(nkk: InputNValue; nvn,svn,ovn: HashSet<string>): StmBase;
    begin
      
      if nkk is SInputNValue then
      begin
        var n := NumToInt(nil, nkk.res);
        if (n < 1) or (n > 254) then raise new InvalidKeyCodeException(scr, n);
        Result := new OperConstGetKeyTrigger(n, vname, bl);
      end else
      if kk=nkk then
        Result := self else
        Result := new OperGetKeyTrigger(nkk, vname, bl);
      
      nvn.Add(vname);
      svn.Remove(vname);
      if ovn<>nil then ovn.Remove(vname);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(kk.Optimize(nvn,svn), nvn,svn, nil);
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(kk.FinalOptimize(nvn,svn,ovn), nvn,svn,ovn);
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    kk.GetAllExprs;
    
    public function DoesRewriteVar(vn: string): boolean; override := self.vname=vn;
    
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
      scr.SupprIO=nil?Calc:CalcSuppr
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'GetKeyTrigger ';
      res += kk.ToString;
      res += ' ';
      res += vname;
      
      AddVarTypesComments(res, kk.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    private procedure CalcSuppr(ec: ExecutingContext);
    begin
      ec.SetVar(x, ec.scr.SupprIO.mX);
      ec.SetVar(y, ec.scr.SupprIO.mY);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 3 then raise new InsufficientStmParamCount(self.scr, 3, par);
      
      x := par[1];
      y := par[2];
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperGetMousePos;
      if nstm=nil then exit;
      
      Result :=
        (self.x = nstm.x) and
        (self.y = nstm.y);
      
    end;
    
    public procedure CheckSngDef; override;
    begin
      scr.CheckCanOverride(x, bl.fname);
      scr.CheckCanOverride(y, bl.fname);
    end;
    
    public function Simplify(nvn,svn,ovn: HashSet<string>): StmBase;
    begin
      Result := self;
      
      nvn.Add(x);
      svn.Remove(x);
      if ovn<>nil then ovn.Remove(x);
      
      nvn.Add(y);
      svn.Remove(y);
      if ovn<>nil then ovn.Remove(y);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn, nil);
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn,ovn);
    
    public function DoesRewriteVar(vn: string): boolean; override :=
    (self.x=vn) or (self.y=vn);
    
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
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'GetMousePos {x} {y} [Const]';
    
  end;
  
  {$endregion Other simulators}
  
  {$region Jump/Call}
  
  OperJump = sealed class(OperStmBase, IJumpCallOper, IFileRefStm)
    
    public CalledBlock: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.next := CalledBlock.GetBlock(ec.scr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock);
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(bl.scr, 2, par);
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1]), bl.fname);
    end;
    
    public constructor(CalledBlock: StmBlockRef; bl: StmBlock);
    begin
      self.CalledBlock := CalledBlock;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function Copy(container: StmBlock): StmBase; override :=
    new OperJump(CalledBlock, container);
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperJump;
      if nstm=nil then exit;
      
      Result := self.CalledBlock.IsSame(nstm.CalledBlock);
      
    end;
    
    public function Simplify(nCalledBlock: StmBlockRef): StmBase;
    begin
      
      if nCalledBlock is StaticStmBlockRef(var sbr) then
        bl.next := sbr.bl else
      if CalledBlock=nCalledBlock then
        Result := self else
        Result := new OperJump(nCalledBlock, bl);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.Optimize(scr, nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.FinalOptimize(scr, nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    CalledBlock.GetAllExprs;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte(1));
      CalledBlock.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
    begin
      var res := new OperJump;
      res.CalledBlock := StmBlockRef.Load(br, bls);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'Jump ';
      res += CalledBlock.ToString;
      
      AddVarTypesComments(res, CalledBlock.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
        CalledBlock1.GetBlock(ec.scr):
        CalledBlock2.GetBlock(ec.scr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock1, CalledBlock2);
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientStmParamCount(bl.scr, 6, par);
      
      if par[2].Length <> 1 then raise new InvalidCompNameException(bl.scr, par[2]);
      case par[2][1] of
        '=': compr := equ;
        '<': compr := less;
        '>': compr := more;
        else raise new InvalidCompNameException(bl.scr, par[2]);
      end;
      
      e1 := OptExprWrapper.FromExpr(Expr.FromString(par[1]));
      e2 := OptExprWrapper.FromExpr(Expr.FromString(par[3]));
      
      CalledBlock1 := new DynamicStmBlockRef(new DInputSValue(par[4]), bl.fname);
      CalledBlock2 := new DynamicStmBlockRef(new DInputSValue(par[5]), bl.fname);
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
    
    public function Copy(container: StmBlock): StmBase; override :=
    new OperJumpIf(e1.Copy,e2.Copy, compr, CalledBlock1,CalledBlock2, container);
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperJumpIf;
      if nstm=nil then exit;
      
      Result :=
        self.e1.IsSame(nstm.e1) and
        self.e2.IsSame(nstm.e2) and
        (self.compr = nstm.compr) and
        self.CalledBlock1.IsSame(nstm.CalledBlock1) and
        self.CalledBlock2.IsSame(nstm.CalledBlock2);
      
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
    
    public function CheckCanUnwrapJumpCall_If(prev_bls: List<StmBlock>; ref: StmBlockRef): boolean;
    
    public function Simplify(prev_bls: List<StmBlock>; ne1,ne2: OptExprWrapper; nCalledBlock1,nCalledBlock2: StmBlockRef; optf: StmBase->StmBase): StmBase;
    begin
      var AllLiteral :=
        (ne1.GetMain() is IOptLiteralExpr) and
        (ne2.GetMain() is IOptLiteralExpr);
      
      var OnlyCaledBlock :=
        AllLiteral?nil:
          comp_obj(ne1.GetMain.GetRes(), ne2.GetMain.GetRes())?
              nCalledBlock1:
              nCalledBlock2;
      
      if
        AllLiteral and
        CheckCanUnwrapJumpCall_If(prev_bls, OnlyCaledBlock)
      then
        Result := optf(new OperJump(OnlyCaledBlock, bl)) else
      if
        (e1=ne1) and (e2=ne2) and
        (CalledBlock1=nCalledBlock1) and (CalledBlock2=nCalledBlock2)
      then
        Result := self else
        Result := new OperJumpIf(ne1,ne2, compr, nCalledBlock1,nCalledBlock2, bl);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(
      prev_bls,
      e1.Optimize(nvn,svn),e2.Optimize(nvn,svn),
      CalledBlock1.Optimize(scr, nvn,svn),CalledBlock2.Optimize(scr, nvn,svn),
      stm->stm.Optimize(prev_bls, nvn,svn)
    );
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(
      prev_bls,
      e1.FinalOptimize(nvn,svn,ovn),e2.FinalOptimize(nvn,svn,ovn),
      CalledBlock1.FinalOptimize(scr, nvn,svn,ovn),CalledBlock2.FinalOptimize(scr, nvn,svn,ovn),
      stm->stm.FinalOptimize(prev_bls, nvn,svn,ovn)
    );
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    CalledBlock1.GetAllExprs() + CalledBlock2.GetAllExprs + e1 + e2;//ToDo #1797
    
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
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
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
      
      res.CalledBlock1 := StmBlockRef.Load(br, bls);
      res.CalledBlock2 := StmBlockRef.Load(br, bls);
      
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock1.GetCalc(),
      CalledBlock2.GetCalc(),
      self.Calc
    );
    
    public function GetComprStr: string;
    begin
      case compr of
        comprT.less: Result := '<';
        comprT.equ:  Result := '=';
        comprT.more: Result := '>';
      end;
    end;
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'JumpIf ';
      res += e1.ToString;
      res += ' ';
      res += GetComprStr;
      res += ' ';
      res += e2.ToString;
      res += ' ';
      res += CalledBlock1.ToString;
      res += ' ';
      res += CalledBlock2.ToString;
      
      AddVarTypesComments(res, Seq(e1,e2) + CalledBlock1.GetAllExprs + CalledBlock2.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstCall;
      if nstm=nil then exit;
      
      Result := self.CalledBlock = nstm.CalledBlock;
      
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte($80 or 3));
      CalledBlock.SaveId(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
    begin
      var res := new OperConstCall;
      var n := br.ReadInt32;
      if n <> -1 then
        if cardinal(n) < bls.Length then
          res.CalledBlock := bls[n] else
          raise new InvalidStmBlIdException(n, bls.Length);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](self.Calc);
    
    public function ToString: string; override :=
    $'Call {StaticStmBlockRef.Create(CalledBlock).ToString} [Const]';
    
  end;
  
  OperCall = sealed class(OperStmBase, ICallOper, IFileRefStm)
    
    public CalledBlock: StmBlockRef;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      ec.Push(bl.next);
      ec.next := self.CalledBlock.GetBlock(ec.scr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock);
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(bl.scr, 2, par);
      
      CalledBlock := new DynamicStmBlockRef(new DInputSValue(par[1]), bl.fname);
    end;
    
    public constructor(CalledBlock: StmBlockRef; bl: StmBlock);
    begin
      self.CalledBlock := CalledBlock;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperCall;
      if nstm=nil then exit;
      
      Result := self.CalledBlock.IsSame(nstm.CalledBlock);
      
    end;
    
    public function Simplify(nCalledBlock: StmBlockRef): StmBase;
    begin
      
      if nCalledBlock is StaticStmBlockRef(var sbr) then
        Result := new OperConstCall(sbr.bl, bl) else
      if CalledBlock=nCalledBlock then
        Result := self else
        Result := new OperCall(nCalledBlock, bl);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.Optimize(scr, nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(CalledBlock.FinalOptimize(scr, nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    CalledBlock.GetAllExprs;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(4));
      bw.Write(byte(3));
      CalledBlock.Save(bw);
    end;
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
    begin
      var res := new OperCall;
      res.CalledBlock := StmBlockRef.Load(br, bls);
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock.GetCalc(),
      self.Calc
    );
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'Call ';
      res += CalledBlock.ToString;
      
      AddVarTypesComments(res, CalledBlock.GetAllExprs);
      
      Result := res.ToString;
    end;
    
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
        CalledBlock1.GetBlock(ec.scr):
        CalledBlock2.GetBlock(ec.scr);
    end;
    
    
    
    public function GetRefs: sequence of StmBlockRef :=
    new StmBlockRef[](CalledBlock1, CalledBlock2);
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 6 then raise new InsufficientStmParamCount(bl.scr, 6, par);
      
      if par[2].Length <> 1 then raise new InvalidCompNameException(bl.scr, par[2]);
      case par[2][1] of
        '=': compr := equ;
        '<': compr := less;
        '>': compr := more;
        else raise new InvalidCompNameException(bl.scr, par[2]);
      end;
      
      e1 := OptExprWrapper.FromExpr(Expr.FromString(par[1]));
      e2 := OptExprWrapper.FromExpr(Expr.FromString(par[3]));
      
      CalledBlock1 := new DynamicStmBlockRef(new DInputSValue(par[4]), bl.fname);
      CalledBlock2 := new DynamicStmBlockRef(new DInputSValue(par[5]), bl.fname);
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperCallIf;
      if nstm=nil then exit;
      
      Result :=
        self.e1.IsSame(nstm.e1) and
        self.e2.IsSame(nstm.e2) and
        (self.compr = nstm.compr) and
        self.CalledBlock1.IsSame(nstm.CalledBlock1) and
        self.CalledBlock2.IsSame(nstm.CalledBlock2);
      
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
    
    public function CheckCanUnwrapJumpCall_If(prev_bls: List<StmBlock>; ref: StmBlockRef): boolean;
    
    public function Simplify(prev_bls: List<StmBlock>; ne1,ne2: OptExprWrapper; nCalledBlock1,nCalledBlock2: StmBlockRef; optf: StmBase->StmBase): StmBase;
    begin
      var AllLiteral :=
        (ne1.GetMain() is IOptLiteralExpr) and
        (ne2.GetMain() is IOptLiteralExpr);
      
      var OnlyCaledBlock :=
        AllLiteral?nil:
          comp_obj(ne1.GetMain.GetRes(), ne2.GetMain.GetRes())?
              nCalledBlock1:
              nCalledBlock2;
      
      if
        AllLiteral and
        CheckCanUnwrapJumpCall_If(prev_bls, OnlyCaledBlock)
      then
        Result := optf(new OperCall(OnlyCaledBlock, bl)) else
      if
        (e1=ne1) and (e2=ne2) and
        (CalledBlock1=nCalledBlock1) and (CalledBlock2=nCalledBlock2)
      then
        Result := self else
        Result := new OperCallIf(ne1,ne2, compr, nCalledBlock1,nCalledBlock2, bl);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(
      prev_bls,
      e1.Optimize(nvn,svn),e2.Optimize(nvn,svn),
      CalledBlock1.Optimize(scr, nvn,svn),CalledBlock2.Optimize(scr, nvn,svn),
      stm->stm.Optimize(prev_bls, nvn,svn)
    );
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(
      prev_bls,
      e1.FinalOptimize(nvn,svn,ovn),e2.FinalOptimize(nvn,svn,ovn),
      CalledBlock1.FinalOptimize(scr, nvn,svn,ovn),CalledBlock2.FinalOptimize(scr, nvn,svn,ovn),
      stm->stm.FinalOptimize(prev_bls, nvn,svn,ovn)
    );
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    CalledBlock1.GetAllExprs() + CalledBlock2.GetAllExprs + e1 + e2;//ToDo #1797
    
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
    
    public static function Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
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
      
      res.CalledBlock1 := StmBlockRef.Load(br, bls);
      res.CalledBlock2 := StmBlockRef.Load(br, bls);
      
      Result := res;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](
      CalledBlock1.GetCalc(),
      CalledBlock2.GetCalc(),
      self.Calc
    );
    
    public function GetComprStr: string;
    begin
      case compr of
        comprT.less: Result := '<';
        comprT.equ:  Result := '=';
        comprT.more: Result := '>';
      end;
    end;
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'CallIf ';
      res += e1.ToString;
      res += ' ';
      res += GetComprStr;
      res += ' ';
      res += e2.ToString;
      res += ' ';
      res += CalledBlock1.ToString;
      res += ' ';
      res += CalledBlock2.ToString;
      
      AddVarTypesComments(res, Seq(e1,e2) + CalledBlock1.GetAllExprs + CalledBlock2.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  
  {$endregion Jump/Call}
  
  {$region ExecutingContext chandgers}
  
  OperSusp = sealed class(OperStmBase)
    
    private static procedure Calc(ec: ExecutingContext) :=
    if ec.scr.susp_called = nil then
      System.Threading.Thread.CurrentThread.Suspend else
      ec.scr.susp_called();
    
    
    
    public constructor := exit;
    
    public function IsSame(stm: StmBase): boolean; override :=
    stm is OperSusp;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(1));
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](Calc);
    
    public function ToString: string; override :=
    $'Susp [Const]';
    
  end;
  OperReturn = sealed class(OperStmBase, IContextJumpOper)
    
    public constructor := exit;
    
    public function IsSame(stm: StmBase): boolean; override :=
    stm is OperReturn;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(2));
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override;
    begin
      bl.next := nil;
      Result := nil;
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[0];
    
    public function ToString: string; override :=
    $'Return [Const]';
    
  end;
  OperHalt = sealed class(OperStmBase, IContextJumpOper)
    
    private static procedure Calc(ec: ExecutingContext) :=
    Halt;
    
    private static procedure CalcSuppr(ec: ExecutingContext) :=
    if ec.scr.otp<>nil then ec.scr.otp('%halted');
    
    
    
    public constructor := exit;
    
    public function IsSame(stm: StmBase): boolean; override :=
    stm is OperHalt;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      inherited Save(bw);
      bw.Write(byte(5));
      bw.Write(byte(3));
    end;
    
    public function GetCalc: sequence of Action<ExecutingContext>; override :=
    new Action<ExecutingContext>[](scr.SupprIO=nil?Calc:CalcSuppr);
    
    public function ToString: string; override :=
    $'Halt [Const]';
    
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
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstSleep;
      if nstm=nil then exit;
      
      Result := self.l = nstm.l;
      
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
    $'Sleep {l} [Const]';
    
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
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperConstOutput;
      if nstm=nil then exit;
      
      Result := self.otp = nstm.otp;
      
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
    $'Output "{otp.EscapeStrSyms}" [Const]';
    
  end;
  
  OperSleep = sealed class(OperStmBase)
    
    public l: InputNValue;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var i := NumToInt(nil, l.res);
      if i < 0 then raise new InvalidSleepLengthException(ec.scr, i);
      Sleep(i);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(bl.scr, 2, par);
      
      l := new DInputNValue(par[1]);
    end;
    
    public constructor(l: InputNValue; bl: StmBlock);
    begin
      self.l := l;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperSleep;
      if nstm=nil then exit;
      
      Result := self.l.IsSame(nstm.l);
      
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
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(l.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(l.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    l.GetAllExprs;
    
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
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'Sleep ';
      res += l.ToString;
      
      AddVarTypesComments(res, l.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  OperRandom = sealed class(OperStmBase)
    
    public vname: string;
    
    private procedure Calc(ec: ExecutingContext) :=
    ec.SetVar(vname, Random());
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(bl.scr, 2, par);
      
      vname := par[1];
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperRandom;
      if nstm=nil then exit;
      
      Result := self.vname = nstm.vname;
      
    end;
    
    public procedure CheckSngDef; override :=
    scr.CheckCanOverride(vname, bl.fname);
    
    public function Simplify(nvn,svn,ovn: HashSet<string>): StmBase;
    begin
      Result := self;
      
      nvn.Add(vname);
      svn.Remove(vname);
      if ovn<>nil then ovn.Remove(vname);
      
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn, nil);
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(nvn,svn,ovn);
    
    public function DoesRewriteVar(vn: string): boolean; override := self.vname=vn;
    
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
    $'Random {vname} [Const]';
    
  end;
  OperOutput = sealed class(OperStmBase)
    
    public otp: InputSValue;
    
    private procedure Calc(ec: ExecutingContext);
    begin
      var p := ec.scr.otp;
      if p <> nil then
        p(otp.res);
    end;
    
    
    
    public constructor(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(bl.scr, 2, par);
      otp := new DInputSValue(par[1]);
    end;
    
    public constructor(otp: InputSValue; bl: StmBlock);
    begin
      self.otp := otp;
      self.bl := bl;
      self.scr := bl.scr;
    end;
    
    public function IsSame(stm: StmBase): boolean; override;
    begin
      var nstm := stm as OperOutput;
      if nstm=nil then exit;
      
      Result := self.otp.IsSame(nstm.otp);
      
    end;
    
    public function Simplify(notp: InputSValue): StmBase;
    begin
      if notp is SInputSValue then
        Result := new OperConstOutput(notp.res, bl) else
      if otp=notp then
        Result := self else
        Result := new OperOutput(notp, bl);
    end;
    
    public function Optimize(prev_bls: List<StmBlock>; nvn,svn: HashSet<string>): StmBase; override :=
    Simplify(otp.Optimize(nvn,svn));
    
    public function FinalOptimize(prev_bls: List<StmBlock>; nvn,svn,ovn: HashSet<string>): StmBase; override :=
    Simplify(otp.FinalOptimize(nvn,svn,ovn));
    
    public function GetAllExprs: sequence of OptExprWrapper; override :=
    otp.GetAllExprs;
    
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
    
    public function ToString: string; override;
    begin
      var res := new StringBuilder;
      
      res += 'Output ';
      res += otp.ToString;
      
      AddVarTypesComments(res, otp.GetAllExprs);
      
      Result := res.ToString;
    end;
    
  end;
  
  {$endregion Misc}
  
  {$endregion operator's}
  
  {$region directive's}
  
  DrctFRef = sealed class(DrctStmBase)
    
    public static procedure Create(bl: StmBlock; par: array of string) :=
    foreach var s in par.Skip(1) do
    begin
      var res := OptExprWrapper.FromExpr(Expr.FromString(s)).GetMain;
      res := res.Optimize(res.wrapper) as OptExprBase;
      if not (res is IOptLiteralExpr) then raise new ConstExprExpectedException(s, res);
      bl.scr.ReadFile(nil, ObjToStr(res.GetRes()));
    end;
    
  end;
  DrctSngDef = sealed class(DrctStmBase)
    
    public static procedure Create(bl: StmBlock; par: array of string);
    begin
      if par.Length < 2 then raise new InsufficientStmParamCount(bl.scr, 2, par);
      
      var ss := par[1].SmartSplit(':',2);
      
      var vd := ss[0].SmartSplit('=',2);
      var vname := vd[0].ToLower;
      var IsNum: boolean;
      case vd[1].ToLower of
        'num': IsNum := true;
        'str': IsNum := false;
        else raise new InvalidVarTypeException(nil, vd[1]);
      end;
      
      var val: object;
      var Access: VarAccessT;
      if ss.Length=1 then
        Access := VarAccessT.none else
      if ss[1].ToLower = 'readonly' then
        Access := VarAccessT.read_only else
      if ss[1].ToLower.StartsWith('const') then
      begin
        Access := VarAccessT.init_only;
        
        ss := ss[1].SmartSplit('=',2);
        if ss[0].ToLower <> 'const' then raise new InvalidUseOfConstDefException(nil);
        if ss.Length <> 2 then raise new InvalidUseOfConstDefException(nil);
        
        var e := Expr.FromString(ss[1]);
        var oe :=
          IsNum?
          OptExprWrapper.FromExpr(e, oe->OptExprBase.AsDefinitelyNumExpr(oe, ()->raise new VarDefOtherTException(nil))):
          OptExprWrapper.FromExpr(e, oe->OptExprBase.AsStrExpr(oe))
        ;
        
        bl.scr.ReplaceAllConstsFor(oe);
        var main := oe.Optimize(new HashSet<string>, new HashSet<string>).GetMain;
        if not (main is IOptLiteralExpr) then raise new ConstExprExpectedException(ss[1], main);
        
        val := main.GetRes;
      end else
        raise new InvalidVarAccessTypeException(nil, ss[1]);
      
      bl.scr.AddSngDef(vname, IsNum, val, Access, bl.fname);
    end;
    
  end;
  
  {$endregion directive's}
  
implementation

{$region Reading}

{$region Single stm}

constructor ExprStm.Create(bl: StmBlock; text: string);
begin
  var ss := text.SmartSplit('=', 2);
  self.vname := ss[0];
  self.e := ExprParser.OptExprWrapper.FromExpr(Expr.FromString(ss[1]));
end;

static function DrctStmBase.FromString(bl: StmBlock; s: string; par: array of string): DrctStmBase;
begin
  case s.ToLower of
    
    '!fref': DrctFRef.Create(bl, par);
    '!sngdef': DrctSngDef.Create(bl, par);
    
    '!startpos':
    if (bl.stms.Count = 0) and (bl.lbl <> '') and not bl.StartPos then
    begin
      bl.scr.start_pos_def := true;
      bl.StartPos := true
    end else
      raise new InvalidUseStartPosException(bl.scr);
    
    else raise new UndefinedDirectiveNameException(bl, s);
  end;
  
  Result := nil;
end;

static function OperStmBase.FromString(bl: StmBlock; par: array of string): OperStmBase;
begin
  case par[0].ToLower of
    
    'key': Result := new OperKey(bl, par);
    'keyd': Result := new OperKeyDown(bl, par);
    'keyu': Result := new OperKeyUp(bl, par);
    'keyp': Result := new OperKeyPress(bl, par);
    'mouse': Result := new OperMouse(bl, par);
    'moused': Result := new OperMouseDown(bl, par);
    'mouseu': Result := new OperMouseUp(bl, par);
    'mousep': Result := new OperMousePress(bl, par);
    
    'mousepos': Result := new OperMousePos(bl, par);
    'getkey': Result := new OperGetKey(bl, par);
    'getkeytrigger': Result := new OperGetKeyTrigger(bl, par);
    'getmousepos': Result := new OperGetMousePos(bl, par);
    
    'call': Result := new OperCall(bl, par);
    'callif': Result := new OperCallIf(bl, par);
    'jump': Result := new OperJump(bl, par);
    'jumpif': Result := new OperJumpIf(bl, par);
    
    'susp': Result := new OperSusp;
    'return': Result := new OperReturn;
    'halt': Result := new OperHalt;
    
    'sleep': Result := new OperSleep(bl, par);
    'random': Result := new OperRandom(bl, par);
    'output': Result := new OperOutput(bl, par);
    
    else raise new UndefinedOperNameException(bl, par[0]);
  end;
end;

static function StmBase.FromString(bl: StmBlock; s: string; par: array of string): StmBase;
begin
  
  if s.StartsWith('!') then
    Result := DrctStmBase.FromString(bl, s, par) else
  if par[0].Contains('=') then
    Result := ExprStm.Create(bl, s) else
    Result := OperStmBase.FromString(bl, par);
  
  if Result=nil then exit;
  Result.bl := bl;
  Result.scr := bl.scr;
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
      self.LoadAdd(ffname, br);
      exit;
    end;
    
    str.Position := 0;
    sr := new System.IO.StreamReader(str);
    lns := sr.ReadToEnd.Remove(#13).Split(#10).ConvertAll(l->l.TrimStart(#9));
    sr.Close;
    
  end;
  
  var last := new StmBlock(self);
  last.lbl := '#';
  last.fname := ffname;
  
  var skp_ar := false;
  
  foreach var ss in lns do
    if ss <> '' then
    begin
      var s := ss.SmartSplit(' ',2)[0];
      
      if s.StartsWith('#') then
      begin
        
        if last.lbl <> '' then bls.Add(last.fname+last.lbl, last);
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
        last.lbl := s;
        last.fname := ffname;
        if bls.ContainsKey(last.fname+last.lbl) then raise new DuplicateLabelNameException(context, s);
        
      end else
        if (s <> '') and not skp_ar then
        begin
          var stm := StmBase.FromString(last, s, ss.SmartSplit);
          if stm=nil then continue;
          last.stms.Add(stm);
          
          if stm is ICallOper then
          begin
            if last.lbl <> '' then bls.Add(last.fname+last.lbl, last);
            last.Seal;
            last.next := new StmBlock(self);
            last := last.next;
            last.lbl := '';
            last.fname := ffname;
          end else
          if stm is IContextJumpOper then
            skp_ar := true;
        end;
    end;
  
  last.Seal;
  if last.lbl <> '' then bls.Add(last.fname+last.lbl, last);
end;

constructor Script.Create(fname: string; ep: ExecParams);
begin
  self.settings := ep;
  if ep.SupprIO then
    self.SupprIO := new SuppressedIOData;
  
  var sc_sz := System.Windows.Forms.Screen.PrimaryScreen.WorkingArea.Size;
  
  if not settings.lib_mode then
  begin
    AddSngDef('WW', true, real(sc_sz.Width),  VarAccessT.init_only, nil);
    AddSngDef('WH', true, real(sc_sz.Height), VarAccessT.init_only, nil);
  end;
  
  read_start_lbl_name := System.IO.Path.GetFullPath(fname);
  
  if read_start_lbl_name.Contains('#') then
    main_path := read_start_lbl_name.Remove(read_start_lbl_name.IndexOf('#')) else
    main_path := read_start_lbl_name;
  
  main_path := System.IO.Path.GetDirectoryName(main_path);
  ReadFile(nil, read_start_lbl_name);
  AllCheckSngDef;
  
  self.Optimize;
end;

{$endregion Script}

{$endregion Reading}

{$region Misc Impl}

{$region ExecutingContext}

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

procedure ExecutingContext.SetVar(vname:string; val: object);
begin
  if scr.SngDefConsts.ContainsKey(vname) then raise new CannotOverrideConstException(nil);
  
  if val is real then
  begin
    
    if scr.SngDefStrs.ContainsKey(vname) then
    begin
      nvs.Remove(vname);
      svs[vname] := StmBase.ObjToStr(val)
    end else
    begin
      svs.Remove(vname);
      nvs[vname] := real(val);
    end;
    
  end else
  if val is string then
  begin
    if scr.SngDefNums.ContainsKey(vname) then raise new VarDefOtherTException(nil);
    
    nvs.Remove(vname);
    svs[vname] := string(val);
    
  end else
  begin
    nvs.Remove(vname);
    svs.Remove(vname);
  end;
end;

{$endregion ExecutingContext}

{$region StmExpr}

procedure ExprStm.CheckSngDef;
begin
  scr.CheckCanOverride(vname, bl.fname);
  var main := e.GetMain;
  
  if scr.SngDefNums.ContainsKey(vname) then
  begin
    
    if main is OptSExprBase then raise new VarDefOtherTException(nil) else
    if main is OptOExprBase then e.SetMain(ExprParser.OptExprBase.AsDefinitelyNumExpr(e.GetMain, ()->raise new VarDefOtherTException(nil)));
    
  end else
  if scr.SngDefStrs.ContainsKey(vname) then
  begin
    
    if not (main is OptSExprBase) then e.SetMain(ExprParser.OptExprBase.AsStrExpr(e.GetMain));
    
  end;
  
end;

{$endregion StmExpr}

{$region [Jump/Call]If unwraping}

function GCheckCanUnwrapJumpCall_If(prev_bls: List<StmBlock>; ref: StmBlockRef): boolean;
begin
  if (ref is StaticStmBlockRef(var ssbr)) then
  begin
    if prev_bls.Contains(ssbr.bl) then exit;
    Result := true;
    if ssbr.bl=nil then exit;
    
    if ssbr.bl.stms.LastOrDefault is IFileRefStm(var ifrs) then
    begin
      prev_bls := prev_bls.ToList;
      prev_bls += ssbr.bl;
      
      foreach var nref in ifrs.GetRefs do
        Result := Result and GCheckCanUnwrapJumpCall_If(prev_bls, nref);
      
    end;
  end;
end;

function OperJumpIf.CheckCanUnwrapJumpCall_If(prev_bls: List<StmBlock>; ref: StmBlockRef): boolean :=
GCheckCanUnwrapJumpCall_If(prev_bls.ToList, ref);

function OperCallIf.CheckCanUnwrapJumpCall_If(prev_bls: List<StmBlock>; ref: StmBlockRef): boolean :=
GCheckCanUnwrapJumpCall_If(prev_bls.ToList, ref);

{$endregion [Jump/Call]If unwraping}

{$region StmBlock}

procedure StmBlock.SaveId(bw: System.IO.BinaryWriter) :=
bw.Write(scr.bls.Values.Numerate(0).First(t->t[1]=self)[0]);

function StmBlock.GetAllFRefs: sequence of StmBlockRef;
begin
  foreach var op in stms do
    if op is IFileRefStm(var frs) then
      yield sequence frs.GetRefs;
end;

function StmBlock.EnumrNextStms: sequence of StmBase;
begin
  if stms.Count = 0 then
  begin
    if next=nil then exit;
    if next=self then exit;
    yield sequence next.EnumrNextStms;
    exit;
  end;
  
  yield sequence stms;
  if stms[stms.Count-1] is IJumpCallOper then
    yield nil else
  if next <> nil then
    yield sequence next.EnumrNextStms;
  
end;

function StmBlock.ToString: string;
begin
  var bl := new StringBuilder;
  
  var last_stm: StmBase;
  var curr := self;
  repeat
    
    bl += curr.GetBodyString;
    if curr.stms.Count <> 0 then
    begin
      bl += #10;
      last_stm := curr.stms[curr.stms.Count-1];
    end;
    
    curr := curr.next;
    if curr=nil then break;
  until curr.lbl <> '';
  
  if (last_stm is ICallOper) or not (last_stm is IContextJumpOper) then
  begin
    
    if next=nil then
      bl += 'Return [Const]' else
      bl += $'Jump "{Script.GetRelativePath(scr.main_path, next.fname+next.lbl)}" [Const]';
    
    bl += #10;
  end;
  
  Result := bl.ToString;
end;

{$endregion StmBlock}

{$region Script}

procedure Script.AddSngDef(vname: string; IsNum: boolean; val: object; Access: VarAccessT; fname: string);
begin
  
  if Access=VarAccessT.init_only then
  begin
    if
      SngDefNums.ContainsKey(vname) or
      SngDefStrs.ContainsKey(vname) or
      (SngDefConsts.ContainsKey(vname) and not SngDefConsts[vname].Equals(val))
    then raise new CannotOverrideConstException(nil);//ToDo надо отдельное исключение, потому что это не совсем отражает проблему
    
    SngDefConsts[vname] := val;
    
  end else
  begin
    if SngDefConsts.ContainsKey(vname) then raise new CannotOverrideConstException(nil);
    if (IsNum?SngDefStrs:SngDefNums).ContainsKey(vname) then raise new ConflictingVarTypesException(nil);
    
    (IsNum?SngDefNums:SngDefStrs)
    [vname] := (Access=VarAccessT.read_only, fname);
    
  end;
  
end;

procedure Script.ReplaceAllConstsFor(oe: OptExprWrapper) :=
foreach var c: KeyValuePair<string, object> in SngDefConsts do
begin
  
  var le: OptExprBase;
  if c.Value is real    then le := new OptNLiteralExpr(real(c.Value)) else
  if c.Value is string  then le := new OptSLiteralExpr(string(c.Value)) else
  if c.Value = nil      then le := new OptNullLiteralExpr else
  raise new WrongConstTypeException(nil);
  
  oe.ReplaceVar(c.Key, le, new string[0], new string[0], new string[0]);
  
end;

{$endregion Script}

{$endregion Misc Impl}

{$region Script optimization}

type
  GBCResT = (
    GBCR_done = $0,
    GBCR_all_loop = $1,
    GBCR_found_loop = $2,
    GBCR_context_halt = $3,
    GBCR_nonconst_context_jump = $4
  );

function GetBlockChain(org_bl, bl: StmBlock; bl_lst: List<StmBlock>; stm_lst: List<StmBase>; ind_lst: List<integer>; allow_final_opt: boolean): GBCResT;
begin
  var curr := bl;
  
  var nvn := new HashSet<string>;
  var svn := new HashSet<string>;
  var ovn := new HashSet<string>;
  
  while curr <> nil do
  begin
    var dummy_container := new StmBlock;
    dummy_container.fname := curr.fname;
    dummy_container.lbl := curr.lbl;
    dummy_container.scr := curr.scr;
    dummy_container.next := curr.next;
    
    var pi := bl_lst.IndexOf(curr);
    if pi <> -1 then
    begin
      var stm_ind := pi=0 ? 0 : ind_lst[pi-1];
      
      if stm_ind <> 0 then
      begin
        bl.next := bl_lst[pi];
        stm_lst.RemoveRange(stm_ind, stm_lst.Count-stm_ind);
        ind_lst.RemoveRange(pi, ind_lst.Count-pi);
        Result := GBCR_found_loop;
        exit;
      end else
      begin
        Result := GBCR_all_loop;
        exit;
      end;
      
    end;
    
    
    
    bl_lst.Add(curr);
    
    foreach var stm in curr.stms do
      if stm is OperReturn then
      begin
        Result := GBCR_done;
        exit;
      end else
      if stm is OperHalt then
      begin
        Result := GBCR_context_halt;
        stm_lst += stm;
        exit;
      end else
      begin
        //ToDo Debug
//        if stm is OperJumpIf(var oji) then
//           if oji.CalledBlock1 is StaticStmBlockRef(var ssbr) then
//            if (ssbr.bl<>nil) and (ssbr.bl.lbl = '#ForXBreak') then
//              if oji.e1.Calc(new Dictionary<string,real>,new Dictionary<string,string>) is real(var res) then
//                if res=38 then
//                begin
//                  bl_lst := bl_lst;
//                end;
        
        var opt :=
          allow_final_opt?
          stm.Copy(dummy_container).FinalOptimize(bl_lst, nvn,svn,ovn):
          stm.Copy(dummy_container).Optimize(bl_lst, nvn,svn);
        
        if (opt is OperConstCall(var cc)) and (cc.CalledBlock=nil) then opt := nil;
        
        if opt <> nil then
        begin
          stm_lst += opt;
          opt.bl := org_bl;
        end;
      end;
    
    
    
    if stm_lst.Count <> 0 then
    begin
      
      if stm_lst[stm_lst.Count-1] is OperConstCall(var occ) then
      begin
        var stm := stm_lst[stm_lst.Count-1];
        stm_lst.RemoveLast;
        ind_lst.Add(stm_lst.Count);
        pi := ind_lst.Count;
        
        case GetBlockChain(org_bl, occ.CalledBlock, bl_lst.ToList, stm_lst, ind_lst, allow_final_opt) of
          
          GBCR_done: ;
          
          GBCR_context_halt:
          begin
            Result := GBCR_context_halt;
            exit;
          end;
          
          GBCR_found_loop,
          GBCR_nonconst_context_jump:
          if ind_lst.Count < pi then
          begin
            Result := GBCR_found_loop;
            exit;
          end else
          begin
            
            ind_lst.RemoveRange(pi, ind_lst.Count-pi);
            var stm_ind := ind_lst[pi-1];
            stm_lst.RemoveRange(stm_ind, stm_lst.Count-stm_ind);
            
            stm_lst += stm;
            ind_lst[pi-1] += 1;
            
          end;
          
        end;
        
      end else
      begin
        ind_lst.Add(stm_lst.Count);
        
        if stm_lst[stm_lst.Count-1] is IJumpCallOper then
        begin
          Result := GBCR_nonconst_context_jump;
          exit;
        end;
        
      end;
      
    end else
      ind_lst.Add(stm_lst.Count);
    
    curr := dummy_container.next;
  end;
  
  Result := GBCR_done;
end;

procedure Script.Optimize;
begin
//  writeln(self);
//  writeln('-'*50);
  
  foreach var bl: StmBlock in bls.Values do
    foreach var stm in bl.stms do
      foreach var oe in stm.GetAllExprs do
        self.ReplaceAllConstsFor(oe);
  
  if not settings.lib_mode then
    foreach var key in SngDefConsts.Keys.ToArray do
      SngDefConsts[key] := nil;//Они больше никогда не понадобятся. Но для ExecutingContext.SetVar надо всё же оставить ключи
  
  var try_opt_again := true;
  var mini_opt := true;
  var dyn_refs := new List<StmBlockRef>;
  while try_opt_again or mini_opt do
  begin
    mini_opt := try_opt_again;
    
//    writeln('opt');
//    writeln(self);
//    writeln('-'*50);
//    readln;
//    Sleep(1000);
    
    {$region Init}
    
    var done := new HashSet<StmBlock>;
    var not_all_waiting :=
      start_pos_def and
      (
        mini_opt or
        bls.Values
        .Where(bl->bl.StartPos)
        .SelectMany(bl->bl.GetAllFRefs)
        .All(ref->ref is StaticStmBlockRef)
      );
    
    var waiting := new HashSet<StmBlock>(
      not_all_waiting?
      bls.Values.Where(bl->bl.StartPos):
      bls.Values
    );
    
    var new_dyn_refs := bls.Values.SelectMany(bl->bl.GetAllFRefs).Where(ref->ref is DynamicStmBlockRef).ToList;
    try_opt_again := (new_dyn_refs.Count <> 0) and not dyn_refs.SequenceEqual(new_dyn_refs);
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
      var curr := waiting.First;
      waiting.Remove(curr);
      if curr=nil then continue;
      if not done.Add(curr) then continue;
      
      var stms := new List<StmBase>;
      
      case GetBlockChain(curr,curr, new List<StmBlock>, stms, new List<integer>, allow_final_opt.Contains(curr)) of
        
        GBCR_done,
        GBCR_context_halt,
        GBCR_nonconst_context_jump:
          curr.next := nil;
        
        GBCR_all_loop:
          curr.next := curr;
        
        GBCR_found_loop: ;
        
      end;
      
      try_opt_again :=
        try_opt_again or
        (curr.stms.Count<>stms.Count) or
        not curr.stms.Zip(stms, (stm1,stm2)->stm1.IsSame(stm2)).All(b->b);
      
      curr.stms := stms;
      
      if not_all_waiting then
      begin
        
        foreach var ref in
          curr.GetAllFRefs
          .Select(ref->ref as StaticStmBlockRef)
          .Where(ref-> ref<>nil )
          .Select(ref->ref.bl)
        do
          waiting += ref;
        
        waiting += curr.next;
      end;
    end;
    
    if not settings.lib_mode then
      if not done.Any(bl->bl.GetAllFRefs.Any(ref->ref is DynamicStmBlockRef)) then
        foreach var kvp in bls.ToList do
          if not done.Contains(kvp.Value) then
            bls.Remove(kvp.Key);
    
    {$endregion Block chaining}
    
    {$region Variable optimizations}
    
    foreach var bl: StmBlock in bls.Values do
      foreach var e: ExprStm in bl.stms.OfType&<ExprStm>.ToList do
      begin
        var params_names := new HashSet<string>;
        params_names += e.e.n_vars_names;
        params_names += e.e.s_vars_names;
        params_names += e.e.o_vars_names;
        
        {$region usages}
        
        var usages := new List<(StmBase, OptExprWrapper)>;
        var pri := -1; // param rewriter index // this is index in bl.stms array
        var pio := false; // param is overridden (is this block)
        
        foreach var stm in
          bl.stms
          .SkipWhile(stm-> stm<>e).Skip(1)
        do
        begin
          
          var cu := stm
            .FindVarUsages(e.vname)
            .Where(e2-> e2<>nil )
            .Select(e2->(stm, e2));
          
          usages.AddRange(cu);
          
          if stm.DoesRewriteVar(e.vname) then
          begin
            pio := true;
            break;
          end;
          
          if params_names.Any(vname->stm.DoesRewriteVar(vname)) then
          begin
            pri := bl.stms.IndexOf(stm);
            break;
          end;
          
        end;
        
        {$endregion usages}
        
        {$region nue}
        
        //next usage (could) exist (in next blocks)
        var nue := false;
        
        if bl.next = nil then
          nue := (bl.stms.LastOrDefault is IJumpCallOper) and not pio else
        begin
          var prev := new HashSet<StmBase>(bl.stms);
          
          foreach var stm in
            bl.next
            .EnumrNextStms
          do
          begin
            if not prev.Add(stm) then break;
            
            if (stm=nil) or stm.FindVarUsages(e.vname).Any(e-> e<>nil ) then
            begin
              nue := true;
              break;
            end;
            
            if stm.DoesRewriteVar(e.vname) then break;
            
          end;
          
        end;
        
        {$endregion nue}
        
        //Start checking
        
        {$region No usages}
        if usages.Count = 0 then
        begin
          
          if pri <> -1 then
          begin
            var ci := bl.stms.IndexOf(e);
            if ci<>pri-1 then
            begin
              bl.stms.Insert(pri, e);
              bl.stms.RemoveAt(ci);
              //try_opt_again := true; // This can't open new opt posability
            end;
          end else
          if not nue then
          begin
            
            bl.stms.Remove(e);
            try_opt_again := true;
            
          end else
          if (bl.next<>nil) and (self.start_pos_def and not bl.next.StartPos) and (bl.next.next <> bl.next) then
          begin
            bl.stms.Remove(e);
            bl.next.stms.Insert(0, e);
            try_opt_again := true;
          end;
          
        end else
        {$endregion No usages}
        
        {$region IOptSimpleExpr}
        if e.e.GetMain is IOptSimpleExpr then
        begin
          
          if usages.Any then try_opt_again := true;
          foreach var use in usages do
            use[1].ReplaceVar(e.vname, e.e);
          
          if pri<>-1 then
          begin
            var ci := bl.stms.IndexOf(e);
            if ci<>pri-1 then
            begin
              bl.stms.Insert(pri, e);
              bl.stms.RemoveAt(ci);
              //try_opt_again := true; // This can't open new opt posability
            end;
          end else
          if nue then
          begin
            if (bl.next<>nil) and (self.start_pos_def and not bl.next.StartPos) and (bl.next.next <> bl.next) then
            begin
              bl.stms.Remove(e);
              bl.next.stms.Insert(0, e);
              try_opt_again := true;
            end;
          end else
          //if allow_final_opt.Contains(bl) then // why was it here? // added in "a bit of refactoring" commit: d081a0184203fa92b8cf42ace1638a4c6a87bc2f
          begin
            bl.stms.Remove(e);
            try_opt_again := true;
          end;
          
        end else
        {$endregion IOptSimpleExpr}
        
        {$region Only 1 use}
        if (usages.Count = 1) and (pri = -1) and allow_final_opt.Contains(bl) and not nue then
        begin
          bl.stms.Remove(e);
          
          usages[0][1].ReplaceVar(e.vname, e.e);
          
          try_opt_again := true;
        end else
        {$endregion Only 1 use}
        
        {$region Move closer to first use}
        begin
          var use := usages[0];
          var stms := use[0].bl.stms;
          
          var ind := stms.IndexOf(use[0]);
          var ci := stms.IndexOf(e);
          if ci <> ind-1 then
          begin
            
            stms.Insert(ind,e);
            stms.RemoveAt(ci);
            
            //try_opt_again := true; // This can't open new opt posability + would create inf loop in optimizer, if 2 var's are used in same expr
          end;
          
        end;
        {$endregion Move closer to first use}
        
      end;
    
    {$endregion Variable optimizations}
    
  end;
  
  if bls.Values.SelectMany(bl->bl.GetAllFRefs).All(ref->ref is StaticStmBlockRef) then
    LoadedFiles := nil;
  
  foreach var bl: StmBlock in bls.Values do
    bl.Seal;
  
end;

{$endregion Script optimizing}

{$region Save/Load}

static function InputSValue.Load(br: System.IO.BinaryReader): InputSValue;
begin
  var t := br.ReadByte;
  case t of
    
    1: Result := SInputSValue.Load(br);
    2: Result := DInputSValue.Load(br);
    
    else raise new InvalidInpTException(t);
  end;
end;

static function InputNValue.Load(br: System.IO.BinaryReader): InputNValue;
begin
  var t := br.ReadByte;
  case t of
    
    1: Result := SInputNValue.Load(br);
    2: Result := DInputNValue.Load(br);
    
    else raise new InvalidInpTException(t);
  end;
end;

static function StmBlockRef.Load(br: System.IO.BinaryReader; bls: array of StmBlock): StmBlockRef;
begin
  var t := br.ReadByte;
  case t of
    
    1: Result := StaticStmBlockRef.Load(br, bls);
    2: Result := DynamicStmBlockRef.Load(br);
    
    else raise new InvalidBlRefTException(t);
  end;
end;

static function OperStmBase.Load(br: System.IO.BinaryReader; bls: array of StmBlock): OperStmBase;
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
      
      1: Result := OperJump.Load(br, bls);
      2: Result := OperJumpIf.Load(br, bls);
      3: Result := OperCall.Load(br, bls);
      4: Result := OperCallIf.Load(br, bls);
      
      $80 or 3: Result := OperConstCall.Load(br, bls);
      
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

static function DrctStmBase.Load(br: System.IO.BinaryReader; bls: array of StmBlock): DrctStmBase;
begin
  Result := nil;
  
  var t1 := br.ReadByte;
  var t2 := br.ReadByte;
  
  case t1 of
    
    1:
    case t2 of
      
      //1: ;
      
      else raise new InvalidDrctTException(t1,t2);
    end;
    
    else raise new InvalidDrctTException(t1,t2);
  end;
  
end;

static function StmBase.Load(br: System.IO.BinaryReader; bls: array of StmBlock): StmBase;
begin
  
  var t := br.ReadByte;
  case t of
    0: Result := ExprStm.Load(br, bls);
    1: Result := OperStmBase.Load(br, bls);
    2: Result := DrctStmBase.Load(br, bls);
    else raise new InvalidStmTException(t);
  end;
  
end;

procedure Script.SaveContent(bw: System.IO.BinaryWriter);
begin
  
  if LoadedFiles <> nil then
  begin
    
    var nopt: boolean;
    repeat
      nopt := true;
      
      var refs := bls.Values.SelectMany(bl->bl.GetAllFRefs).OfType&<DynamicStmBlockRef>.Select(ref->ref.s).ToList;
      foreach var ref: InputSValue in refs do
      begin
        var inp := ref.Optimize(new HashSet<string>,new HashSet<string>);
        if inp is SInputSValue then
          if ReadFile(nil, inp.res) then
          begin
            nopt := false;
            AllCheckSngDef;
          end;
      end;
      
    until nopt;
    
  end;
  
  var main_fname := read_start_lbl_name.Substring(read_start_lbl_name.LastIndexOf('\')+1);
  bw.Write(
    main_fname.Contains('#')?
    main_fname.Remove(main_fname.IndexOf('#')):
    main_fname
  );
  
  bw.Write(self.start_pos_def);
  
  bw.Write(self.SngDefConsts.Count);
  foreach var kvp in self.SngDefConsts do
  begin
    bw.Write(kvp.Key);
    
    if kvp.Value is string(var s) then
    begin
      bw.Write(2);
      bw.Write(s);
    end else
    if kvp.Value is real(var r) then
    begin
      bw.Write(3);
      bw.Write(r);
    end else
      bw.Write(byte(1));
    
  end;
  
  bw.Write(self.SngDefStrs.Count);
  foreach var kvp in self.SngDefStrs do
  begin
    bw.Write(kvp.Key);
    bw.Write(kvp.Value[0]);
    bw.Write(GetRelativePath(main_path, kvp.Value[1]));
  end;
  
  bw.Write(self.SngDefNums.Count);
  foreach var kvp in self.SngDefNums do
  begin
    bw.Write(kvp.Key);
    bw.Write(kvp.Value[0]);
    bw.Write(GetRelativePath(main_path, kvp.Value[1]));
  end;
  
  bw.Write(bls.Count);
  
  var blgs :=
  bls
  .Select(kvp->(kvp.Key.Split(new char[]('#'),2),kvp.Value))
  .GroupBy(
    t->t[0][0],
    t->(t[0][1],t[1])
  ).ToList;
  bw.Write(blgs.Count);
  
  foreach var kvp: System.Linq.IGrouping<string, (string, StmBlock)> in blgs do
  begin
    bw.Write(GetRelativePath(main_path, kvp.Key));
    var l := kvp.ToList;
    bw.Write(l.Count);
    foreach var t in l do
    begin
      t[1].SaveId(bw);
      bw.Write(t[0]);
      t[1].Save(bw);
    end;
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