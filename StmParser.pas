unit StmParser;
//ToDo файлы могут быть подключены и динамичным связыванием. Это надо предусмотреть
//ToDo Добавить DeduseVarsTypes и Instatiate в ExprParser
//ToDo удобный способ смотреть изначальный и оптимизированный вариант
//ToDo контекст ошибок, то есть при оптимизации надо сохранять номер строки

//ToDo Directives:  !NoOpt/!Opt
//ToDo Directives:  !SngDef:i1=num:readonly

//ToDo bug track:   "ExprStm.Create" broken in code analyzer
//ToDo bug track:   formating adds newline for "class function"

interface

uses ExprParser;

type
  {$region Exception's}
  
  ScriptFile = class;
  
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
    
    public procedure Optimize;
    begin
      
    end;
    
  end;
  ScriptFile = class
    
    public name, full_name: string;
    public bls := new Dictionary<string, StmBlock>;
    public refs := new Dictionary<(ScriptFile, string), integer>;
    
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
    
    fls := new List<ScriptFile>;
    
    constructor(fname: string);
    
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
  fls.Add(new ScriptFile(fname));
  
  var nloaded := true;
  while nloaded do
  begin
    nloaded := false;
    
    foreach var f in fls do
      foreach var bl: StmBlock in f.bls.Values do
      begin
        var Main_ToDo := 0;
      end;
    
  end;
end;

{$endregion constructor's}

{$region temp_reg}

{$endregion }

end.