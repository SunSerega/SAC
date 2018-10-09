unit ScriptExecutor;

//ToDo Проверить, не исправили ли issue компилятора
// - #891

interface

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

uses System.Windows.Forms;
uses System.Drawing;

uses StmParser;
uses ExprParser;

uses MiscData;

type
  ScriptExecutionForm=class(Form)
    
    scr: Script;
    scr_thr: System.Threading.Thread;
    
    pause_thr: System.Threading.Thread;
    
    pause_btm: byte := 192;
    form_thr: System.Threading.Thread;
    
    class function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    constructor(entry_point: string; debug: boolean) :=
    try
      
      {$region Script}
      
      scr := new Script(entry_point.SmartSplit('#',2)[0]);
      scr_thr := new System.Threading.Thread(
        ()->
        try
          scr.otp += s->Log(s);
          scr.stoped += Halt;
          scr_thr.Suspend;
          scr.Execute(entry_point);
        except
          on e: Exception do
          begin
            Writeln(e);
            Readln;
            Halt;
          end;
        end
      );
      scr_thr.Start;
      
      {$endregion script}
      
      {$region Form}
      
      form_thr := System.Threading.Thread.CurrentThread;
      
      var tb1 := new RichTextBox;
      self.Controls.Add(tb1);
      tb1.Text := 'Susp';
      
      scr.susp_called += procedure->tb1.Text := 'Susp';
      
      {$endregion Form}
      
      {$region Pause/Resume}
      
      var NGetKeyState := ScriptExecutionForm.GetKeyState;//ToDo #891
      
      pause_thr := new System.Threading.Thread(
        ()->
        while true do
        try
          
          while
            (NGetKeyState(pause_btm) and $80 = 0) and
            (scr_thr.ThreadState and System.Threading.ThreadState.Suspended = System.Threading.ThreadState.Suspended)
          do Sleep(1);
          while
            (NGetKeyState(pause_btm) and $80 = $80) and
            (scr_thr.ThreadState and System.Threading.ThreadState.Suspended = System.Threading.ThreadState.Suspended)
          do Sleep(1);
          if scr_thr.ThreadState and System.Threading.ThreadState.Suspended = System.Threading.ThreadState.Suspended then
            scr_thr.Resume;
          
          tb1.Text := 'Resm';
          
          while
            (NGetKeyState(pause_btm) and $80 = 0) and
            (scr_thr.ThreadState and System.Threading.ThreadState.Suspended <> System.Threading.ThreadState.Suspended)
          do Sleep(1);
          while
            (NGetKeyState(pause_btm) and $80 = $80) and
            (scr_thr.ThreadState and System.Threading.ThreadState.Suspended <> System.Threading.ThreadState.Suspended)
          do Sleep(1);
          if scr_thr.ThreadState and System.Threading.ThreadState.Suspended <> System.Threading.ThreadState.Suspended then
            scr_thr.Suspend;
          
          tb1.Text := 'Susp';
          
        except
          on e: Exception do
          begin
            Writeln(e);
            Readln;
            Halt;
          end;
        end
      );
      pause_thr.Start;
      
      {$endregion Pause/Resume}
      
      Application.Run(self);
      
    except
      on e: Exception do
      begin
        Writeln(e);
        Readln;
        Halt;
      end;
    end;
    
    constructor(entry_point: string) :=
    Create(entry_point, true);
    
  end;

implementation

begin
  System.IO.File.Delete('Errors.txt');
  System.IO.File.Delete('Log.txt');
  System.IO.File.Delete('Log2.txt');
  System.IO.File.Delete('Log3.txt');
end.