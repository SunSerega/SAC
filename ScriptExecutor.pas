﻿unit ScriptExecutor;

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
uses LocaleData;
uses SettingsData;

//uses ВБФ;

type
  ExecParams = record
    
    debug := false;
    
  end;
  
  ScriptExecutionForm=class(Form)
    
    scr: Script;
    scr_thr: System.Threading.Thread;
    
    pause_thr: System.Threading.Thread;
    
    pause_keys := Lst&<byte>(192);
    form_thr: System.Threading.Thread;
    
    static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    constructor(entry_point: string; ep: ExecParams) :=
    try
      
      {$region Script}
      
      scr := new Script(entry_point.SmartSplit('#',2)[0]);
      scr_thr := new System.Threading.Thread(
        ()->
        try
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
      
      {$endregion script}
      
      {$region Form}
      
      form_thr := System.Threading.Thread.CurrentThread;
      
      var Output := new RichTextBox;
      self.Controls.Add(Output);
      Output.ReadOnly := true;
      Output.WordWrap := false;
      Output.Font := System.Drawing.Font.Create('Courier New', 8);
      Output.Multiline := true;
      Output.Bounds := new Rectangle(
        10,
        10,
        Ceil(self.CreateGraphics.MeasureString(' ', Output.Font).Width*80),
        Ceil(self.CreateGraphics.MeasureString(' ', Output.Font).Height*30)
      );
      
      var Running := new CheckBox;
      self.Controls.Add(Running);
      Running.AutoSize := true;
      Running.Text := Translate('Running');
      Running.Checked := false;
      Running.Top := 10;
      Running.Left := Output.Right+10;
      
      var SetKey := new Button;
      self.Controls.Add(SetKey);
      SetKey.AutoSize := true;
      SetKey.Text := Translate('SetKey');
      SetKey.Top := 10;
      SetKey.Left := Running.Right+10;
      Running.Top += (SetKey.Height-Running.Height) div 2;
      
      var PreCompile := new Button;
      self.Controls.Add(PreCompile);
      SetKey.AutoSize := true;
      PreCompile.Text := Translate('PreCompile');
      PreCompile.Top := SetKey.Bottom+10;
      PreCompile.Left := Running.Left;
      PreCompile.Width := SetKey.Right-PreCompile.Left;
      {$region PreCompile}
      PreCompile.Click += (o,e)->
      begin
        //SaveObj('temp.bin', scr);
        var sfd := new System.Windows.Forms.SaveFileDialog;
        sfd.Filter := Translate('PreCompFileFilter');
        if sfd.ShowDialog <> System.Windows.Forms.DialogResult.OK then exit;
        scr.Save(sfd.OpenFile);
      end;
      {$endregion PreCompile}
      
      var KeyList := new RichTextBox;
      self.Controls.Add(KeyList);
      KeyList.Top := PreCompile.Bottom+10;
      KeyList.Left := PreCompile.Left;
      KeyList.Width := PreCompile.Width;
      KeyList.ReadOnly := true;
      KeyList.WordWrap := false;
      KeyList.Multiline := true;
      {$region RunningClick}
      Running.Click += (o,e)->
      if Running.Enabled then
        if Running.Checked then
          scr_thr.Resume else
          scr_thr.Suspend;
      {$endregion RunningClick}
      {$region Update KeyList}
      var NGetKeyState := ScriptExecutionForm.GetKeyState;//ToDo #891
      var n_pause_keys := pause_keys;//ToDo #? 2.pas
      var UpdateKeyList: procedure := ()->
      begin
        var s := '';
        foreach var key in n_pause_keys do
        begin
          s += $'{key} : ';
          case key of
            65..90,48..57: s += ChrAnsi(key);
            96..105: s += $'NUMPAD{key-96}';
            
            9: s += 'Tab';
            20: s += 'CapsLock';
            27: s += 'Esc';
            91: s += 'Win';
            144: s += 'NumLock';
            192: s += '~';
            
            16: s += 'Shift';
            160: s += 'LShift';
            161: s += 'RShift';
            
            17: s += 'Ctrl';
            162: s += 'LCtrl';
            163: s += 'RCtrl';
            
            18: s += 'Alt';
            164: s += 'LAlt';
            165: s += 'RAlt';
            
            else s += '?';
          end;
          s += #10;
        end;
        KeyList.Height := Min(s.Split(#10).Length*13+5, Output.Height-KeyList.Top+Output.Top);
        KeyList.Text := s;
      end;
      UpdateKeyList;
      {$endregion Update KeyList}
      {$region SetKey}
      SetKey.Click += procedure(o,e)->
      System.Threading.Thread.Create(()->
      if SetKey.Enabled then
      lock n_pause_keys do
      begin
        SetKey.Enabled := false;
        Running.Enabled := false;
        Running.AutoCheck := false;
        KeyList.Focus;
        pause_thr.Suspend;
        
        var s := SeqGen(256,i->byte(i)).Where(i->NGetKeyState(i) and $80 = $80);
        while s.Any do Sleep(1);
        while not s.Any do Sleep(1);
        var l := s.ToList;
        var hs := new HashSet<byte>;
        while l.Any do
        begin
          hs += l;
          n_pause_keys.Clear;
          n_pause_keys.AddRange(hs.Sorted);
          UpdateKeyList;
          
          Sleep(10);
          l := s.ToList;
        end;
        
        pause_thr.Resume;
        Running.AutoCheck := true;
        SetKey.Enabled := true;
        Running.Enabled := true;
      end).Start;
      {$endregion SetKey}
      
      self.Width := SetKey.Right+25;
      self.Height := Output.Bottom+48;
      self.Text := System.IO.Path.GetFullPath(entry_point.Split(new char[]('#'),2)[0]);
      if self.Text.ToLower.Contains('\lib\') then
        self.Text := 'SAC: '+self.Text.Split('\').SkipWhile(s->s.ToLower <> 'lib').JoinIntoString('\') else
        self.Text := 'SAC: '+self.Text.Split('\').Last;
      
      {$endregion Form}
      
      {$region Pause/Resume}
      
      pause_thr := new System.Threading.Thread(()->
      while true do
      try
        
        var cpk := new List<byte>;
        var s := SeqGen(256,i->byte(i)).Where(i->NGetKeyState(i) and $80 = $80);
        while
          pause_keys.Any(k->not cpk.Contains(k)) and
          not Running.Checked
        do
        begin
          Sleep(1);
          cpk := s.ToList;
        end;
        //writeln('off-pressed');
        while
          pause_keys.Any(k->cpk.Contains(k)) and
          not Running.Checked
        do
        begin
          Sleep(1);
          cpk := s.ToList;
        end;
        //writeln('on-unpressed');
        
        if not Running.Checked then
        begin
          scr_thr.Resume;
          Running.Invoke(procedure->Running.Checked := true);
        end;
        
        while
          pause_keys.Any(k->not cpk.Contains(k)) and
          Running.Checked
        do
        begin
          Sleep(1);
          cpk := s.ToList;
        end;
        //writeln('on-pressed');
        while
          pause_keys.Any(k->cpk.Contains(k)) and
          Running.Checked
        do
        begin
          Sleep(1);
          cpk := s.ToList;
        end;
        //writeln('off-unpressed');
        
        if Running.Checked then
        begin
          scr_thr.Suspend;
          Running.Invoke(procedure->Running.Checked := false);
        end;
        
      except
        on e: Exception do
        begin
          Writeln(e);
          Readln;
          Halt;
        end;
      end);
      
      {$endregion Pause/Resume}
      
      scr.otp += procedure(s)->Output.Invoke(procedure->Output.Text += s+#10);
      scr.susp_called += procedure->Running.Checked := false;
      scr.stoped += Halt;
      
      scr_thr.Start;
      pause_thr.Start;
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
    Create(entry_point, new ExecParams);
    
  end;

implementation

begin
  System.IO.File.Delete('Errors.txt');
  System.IO.File.Delete('Log.txt');
  System.IO.File.Delete('Log2.txt');
  System.IO.File.Delete('Log3.txt');
end.