unit StmParser;
//ToDo файлы могут быть подключены и динамичным связыванием. Это надо предусмотреть
//ToDo Добавить DeduseVarsTypes и Instatiate в ExprParser
//ToDo удобный способ смотреть изначальный и оптимизированный вариант
//ToDo контекст ошибок, то есть при оптимизации надо сохранять номер строки
//ToDo убрать понятие файла, файл это лишь набор вблоков + в конце полседнего блока - оператор Retr

//ToDo Directives:  !NoOpt/!Opt
//ToDo Directives:  !SngDef:i1=num:readonly/const

//ToDo bug track:   "ExprStm.Create" broken in code analyzer
//ToDo bug track:   formating adds newline for "class function"

interface

uses ExprParser;

type
  {$region pre desc}
  
  StmBase = class;
  
  StmBlock = class;
  ScriptFile = class;
  Script = class;
  
  {$endregion pre desc}
  
  {$region Exception's}
  
  PrecompilingException = abstract class(Exception)
    
    public source: ScriptFile;
    
    constructor(source: ScriptFile; text: string);
    begin
      inherited Create(text);
      self.source := source;
    end;
    
  end;
  RefFilesNotFound = class(PrecompilingException)
    
    public constructor(source: ScriptFile; fns: sequence of string) :=
    inherited Create(source, 'Can''t find files:'#10+fns.JoinIntoString(#10));
    
  end;
  
  {$endregion Exception's}
  
  {$region Single stm}
  
  StmBase = abstract class
    
    public bl: StmBlock;
    public fl: ScriptFile;
    public scr: Script;
    
  end;
  ExprStm = sealed class(StmBase)
    
    public v_name: string;
    public e: IExpr;
    
    public constructor(text: string);
  
  end;
  DrctStmBase = abstract class(StmBase)
    
    public procedure Apply(fl: ScriptFile); abstract;
    
    public class function FromString(fl: ScriptFile; text: string): DrctStmBase;
  
  end;
  OperStmBase = abstract class(StmBase)
    
    public class function FromString(text: string): DrctStmBase;
  
  end;
  
  {$endregion Single stm}
  
  {$region Stm containers}
  
  StmBlock = class
    
    public stms := new List<StmBase>;
    public nvn := new List<string>;
    public svn := new List<string>;
    
    public fl: ScriptFile;
    public scr: Script;
    
    public prev: StmBlock;
    public refs := new List<StmBlock>;//блоки которые ссылаются на этот. не считая prev
    
    public procedure Optimize;
    
  end;
  ScriptFile = class
    
    public name, full_name: string;
    public bls := new Dictionary<string, StmBlock>;
    
    public scr: Script;
    
    private class RefNotLoadedFiles := new List<IOptExpr>;
    
    
    
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
    
  end;
  Script = class
    
    public fls := new List<ScriptFile>;
    public fQu := new Queue<OptExprBase>;
    public nvn := new List<string>;
    public svn := new List<string>;
    public ovn := new List<string>;
    
    public constructor(fname: string);
    
  end;
  
  {$endregion Stm containers}
  
  {$region interface's}
  
  IFileRefStm = interface
    
    function GetRefs: sequence of string;
    
    function AnyUnknownRefs: boolean;
    
  end;
  
  {$endregion interface's}
  
  {$region operator's}
  
  {$endregion operator's}
  
  {$region directive's}
  
  FRef = class(DrctStmBase)
    
    public fns: array of string;
    
    public procedure Apply(fl: ScriptFile); override;
    begin
      var dir := System.IO.Path.GetDirectoryName(fl.full_name);
      
      for var i := 0 to fns.Length-1 do
        fns[i] := ScriptFile.CombinePaths(dir, fns[i]);
      
      var ufns := fns.Where(fn->not System.IO.File.Exists(fn)).ToList;
      if ufns.Count > 0 then raise new RefFilesNotFound(fl, ufns);
      
      ScriptFile.RefNotLoadedFiles.AddRange(fns.Select(fn->new ExprParser.OptSLiteralExpr(fn) as IOptExpr));
      
    end;
    
    public constructor(par: array of string);
    begin
      self.fns := par;
    end;
    
  end;
  
  {$endregion directive's}
  
implementation

{$region constructor's}

constructor ExprStm.Create(text: string);
begin
  var ss := text.Split(new char[]('='), 2);
  self.v_name := ss[0];
  self.e := Expr.FromString(ss[1]);
end;

class function DrctStmBase.FromString(fl: ScriptFile; text: string): DrctStmBase;
begin
  
end;

class function OperStmBase.FromString(text: string): DrctStmBase;
begin
  
end;

constructor ScriptFile.Create(fname: string);
begin
  var fi := new System.IO.FileInfo(fname);
  self.name := fi.Name;
  self.full_name := fi.FullName;
  
  var lns: array of string;
  begin
    var str := fi.OpenRead;
    lns := (new System.IO.StreamReader(str)).ReadToEnd.ToLower.Remove(#13).Split(#10);
    str.Close;
  end;
  
  var last := new StmBlock;
  var lname := '';
  foreach var ll in lns do
  begin
    var l := ll.Split(new char[](' '),2)[0];
    if l = '' then continue;
    
    if l.StartsWith('#') then
    begin
      bls.Add(lname, last);
      last := new StmBlock;
      lname := l.Remove(0, 1);
    end else
    if l.StartsWith('!') then
      last.stms.Add(DrctStmBase.FromString(self, l)) else
    if l.Contains('=') then
      last.stms.Add(ExprStm.Create(l)) else
      last.stms.Add(OperStmBase.FromString(ll));
  end;
  
  bls.Add(lname, last);
end;

constructor Script.Create(fname: string);
begin
  
  var fQu: Queue<OptExprBase>;
  
  fQu.Enqueue(new OptSLiteralExpr(fname));
  var failed := 0;
  while failed < fQu.Count do
  begin
    var ce := fQu.Dequeue;
    ce.Optimize;//ToDo это должна быть процедура
    if false{failed get literal value} then
    begin
      fQu.Enqueue(ce);
      failed += 1;
      continue;
    end else
      failed := false;
    
    var Main_ToDo := 0;//ToDo fQu должно быть <ContextExpr>, которое хранит выражение и его контекст (блок, положение и т.п., чтоб можно было оптимизировать)
    //ToDo читать файл
    
  end;
end;

{$endregion constructor's}

procedure StmBlock.Optimize;
begin
  
end;

{$region temp_reg}

{$endregion }

end.