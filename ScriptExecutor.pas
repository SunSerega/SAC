unit ScriptExecutor;

interface

type
  Script = class
    
    class Loaded := new Dictionary<string, Script>;
    
    procedure Start;
    begin
      var ToDo := 0;
      writeln('Типо запускаюсь');
      readln;
    end;
    
    constructor(fname: string; debug: boolean := false; start_line:integer := 0);
    begin
      var ToDo := 0;
    end;
    
  end;

implementation

end.