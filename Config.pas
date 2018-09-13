{$apptype windows}
{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

uses System.Windows.Forms;
uses System.Drawing;
uses Microsoft.Win32;

var
  f: Form;
  
  Locale := new Dictionary<(string,string),string>;
  curr_locale := '';

function Translate(text:string):string;
begin
  var key := (curr_locale, text);
  if Locale.ContainsKey(key) then
    Result := Locale[key] else
    Result := '*Translation Error*';
end;

function OpenOrCreate(self: RegistryKey; name: string): RegistryKey; extensionmethod;
begin
  Result := self.OpenSubKey(name,true);
  if Result = nil then
    Result := self.CreateSubKey(name);
end;

function ExistsSubKey(self: RegistryKey; name: string): boolean; extensionmethod;
begin
  var key := self.OpenSubKey(name);
  if key <> nil then
  begin
    Result := true;
    key.Close;
  end;
end;

type
  ParameterState = (StOn, StOff, StPart);
  Parameter = abstract class
    
    class RootParams := new List<Parameter>;
    class All := new Dictionary<string,Parameter>;
    
    Parent: Parameter;
    Name, Text: string;
    SubPar := new List<Parameter>;
    
    SubParStateChanged: procedure;
    
    
    
    function AddParams(params a: array of Parameter): Parameter;
    begin
      SubPar.AddRange(a);
      RootParams.RemoveAll(p->a.Contains(p));
      
      
      foreach var p in a do
        p.Parent := self;
      
      Result := self;
    end;
    
    procedure SetVis(val: boolean); virtual;
    begin
      foreach var p in SubPar do
        p.SetVis(val);
    end;
    
    procedure ValidatePos(x:integer; var y, maxw:integer); abstract;
    
    procedure ValidateName; virtual :=
    Text := Translate(Name);
    
    class procedure ValidatePosAll;
    begin
      var y := 10;
      var maxw := 0;
      
      foreach var p in RootParams do
        p.ValidatePos(10,y, maxw);
      
      f.Width := maxw + 10;
      f.Height := y + 10 + 30;
    end;
    
    class procedure ValidateNameAll;
    begin
      foreach var p in All.Values do
        p.ValidateName;
      
      ValidatePosAll;
    end;
    
    constructor(Name: string);
    begin
      self.Name := Name;
      All[Name] := self;
      RootParams.Add(self);
    end;
    
  end;
  
  LParameter = class(Parameter)
    
    L: System.Windows.Forms.ComboBox;
    
    procedure ValidatePos(x:integer; var y, maxw:integer); override;
    begin
      L.Location := new Point(x, y);
      y += L.Height + 5;
      maxw := Max(maxw, L.Left + L.Width);
    end;
    
    procedure ValidateName; override := exit;
    
    constructor(Name:string; update: procedure(sender: LParameter); params States: array of string);
    begin
      inherited Create(Name);
      
      L := new ComboBox;
      f.Controls.Add(L);
      L.DropDownStyle := ComboBoxStyle.DropDownList;
      
      L.Items.AddRange(States.ConvertAll(s->s as object));
      L.SelectedIndexChanged += procedure(o,e)->update(self);
      L.SelectedItem := L.Items.Cast&<object>.First;
      
    end;
    
  end;
  CBParameter = class(Parameter)
    
    CB: CheckBox;
    
    procedure SetVis(val: boolean); override;
    begin
      inherited SetVis(val);
      CB.Visible := val;
    end;
    
    procedure SetChecked;
    begin
      CB.CheckState := CheckState.Checked;
      foreach var p in SubPar do
        if p is CBParameter(var cb_p) then
          cb_p.SetChecked;
    end;
    
    procedure ValidatePos(x:integer; var y, maxw:integer); override;
    begin
      CB.Location := new Point(x, y);
      y += CB.Height + 5;
      maxw := Max(maxw, CB.Left + CB.Width);
      
      if CB.CheckState = CheckState.Unchecked then
        foreach var p in SubPar do
          p.SetVis(false) else
        foreach var p in SubPar do
        begin
          p.SetVis(true);
          p.ValidatePos(x + 30, y, maxw);
        end;
    end;
    
    procedure ValidateName; override;
    begin
      inherited ValidateName;
      CB.Text := Text;
    end;
    
    constructor(Name: string; State: CheckState := CheckState.Unchecked);
    begin
      inherited Create(Name);
      
      CB := new CheckBox;
      f.Controls.Add(CB);
      CB.AutoCheck := false;
      CB.AutoSize := true;
      CB.CheckState := State;
      CB.Click += (o,e)->
      begin
        if CB.CheckState = CheckState.Checked then
          CB.CheckState := CheckState.Unchecked else
          SetChecked;
        
        if Parent <> nil then
          self.Parent.SubParStateChanged();
        
        ValidatePosAll;
      end;
      
      SubParStateChanged +=
      procedure->
      if SubPar.All(p->(not (p is CBParameter)) or ((p as CBParameter).CB.CheckState = CheckState.Checked)) then
        self.CB.CheckState := CheckState.Checked else
        self.CB.CheckState := CheckState.Indeterminate;
    end;
  
  end;
  
  BPar = class(Parameter)
    
    B: Button;
    
    procedure ValidatePos(x:integer; var y, maxw:integer); override := exit;
    
    procedure ValidateName; override;
    begin
      inherited ValidateName;
      B.Text := self.Text;
    end;
    
    constructor(Name:string; Click: procedure);
    begin
      inherited Create(Name);
      
      B := new Button;
      f.Controls.Add(B);
      if Click <> nil then
        B.Click += procedure(o,e)->Click;
      B.AutoSize := true;
    end;
    
  end;
  BsParameter = class(Parameter)
    
    Bs: array of BPar;
    
    procedure ValidatePos(x:integer; var y, maxw:integer); override;
    begin
      y += Bs.Select(b->b.B.Height).Max;
      maxw := Max(
        maxw,
        Bs.Select(b->b.B.Width).Sum + (Bs.Length-1)*5 + 10*2
      );
    end;
    
    procedure ValidateName; override :=
    foreach var b in Bs do
      b.ValidateName;
    
    constructor(params BC: array of (string, Action0));
    begin
      inherited Create('');
      
      Bs := new BPar[BC.Length];
      for var i := 0 to BC.Length-1 do
        Bs[i] := new BPar(BC[i][0], BC[i][1]);
      
      f.Resize += (o,e)->
      begin
        var x := f.Width - 20 - Bs.Last.B.Width;
        var y := f.Height - 40;
        for var i := Bs.Length-1 downto 0 do
        begin
          Bs[i].B.Left := x;
          Bs[i].B.Top := y - Bs[i].B.Height;
          x -= Bs[i].B.Width+5;
        end;
      end;
    end;
    
  end;
  
  MForm = class(Form)
    
    const RegName = 'ScriptAutoClicker';
    const ProgFilesName = System.Environment.GetEnvironmentVariable('ProgramFiles')+'\'+RegName;
    
    const version = 1;
    
    
    
    class procedure InitLocale;
    begin
      Locale.Add(('EN','AssociateDotSAC'),'Associate .SAC files');
      Locale.Add(('EN','AddIcon'),'Add icon to .SAC files');
      Locale.Add(('EN','AddCreateNew'),'Add "Create>>new .SAC file" button');
      Locale.Add(('EN','AddConfLaunch'),'Add "Configured Launch" button for .SAC files');
      Locale.Add(('EN','AddEdit'),'Add "Edit" botton for .SAC files');
      Locale.Add(('EN','Ok'),'OK');
      Locale.Add(('EN','Apply'),'Apply');
      
      Locale.Add(('EN','Exec'),'Execute');
      Locale.Add(('EN','ConfLaunch'),'Configured Launch');
      Locale.Add(('EN','Edit'),'Edit');
      
      Locale.Add(('EN','Text|reg used'),'Registry key ".sac" used by "{0}"'#10'Replace it?');
      Locale.Add(('EN','Cap|reg used'),'Registry key ".sac" is used');
      
      Locale.Add(('EN','Text|reg ver'),'current version is {0}, but Config.exe version is {1}'#10'Do you wand to downgrade current version?');
      Locale.Add(('EN','Cap|reg ver'),'version error');
      
      
      
      Locale.Add(('RU','AssociateDotSAC'),'Ассоциировать .SAC файлы');
      Locale.Add(('RU','AddIcon'),'Add icon to .SAC files');
      Locale.Add(('RU','AddCreateNew'),'Add "Create>>new .SAC file" button');
      Locale.Add(('RU','AddConfLaunch'),'Добавить кнопку "Запуск с параметрами" для .SAC файлов');
      Locale.Add(('RU','AddEdit'),'Добавить кнопку "Редактировать" для .SAC файлов');
      Locale.Add(('RU','Ok'),'ОК');
      Locale.Add(('RU','Apply'),'Применить');
      
      Locale.Add(('RU','Exec'),'Выполнить');
      Locale.Add(('RU','ConfLaunch'),'Configured Launch');
      Locale.Add(('RU','Edit'),'Edit');
      
      Locale.Add(('RU','Text|reg used'),'');
      Locale.Add(('RU','Cap|reg used'),'');
      
      Locale.Add(('RU','Text|reg ver'),'');
      Locale.Add(('RU','Cap|reg ver'),'');
    end;
    
    class constructor :=
    InitLocale;
    
    class procedure DeleteFolder(dir: string);
    begin
      if not System.IO.Directory.Exists(dir) then exit;
      System.IO.Directory.EnumerateDirectories(dir).ForEach(DeleteFolder);
      System.IO.Directory.EnumerateFiles(dir).ForEach(System.IO.File.Delete);
      System.IO.Directory.Delete(dir);
    end;
    
    procedure Save;
    begin
      if (Parameter.All['AssociateDotSAC'] as CBParameter).CB.CheckState <> CheckState.Unchecked then
      begin
        var key := Registry.ClassesRoot.OpenSubKey('.sac');
        if key <> nil then
        begin
          
          while (key <> nil) and (key.GetValue('') as string <> RegName) do
          begin
            var res := MessageBox.Show(string.Format(Translate('Text|reg used'), key.GetValue('')),Translate('Cap|reg used'),MessageBoxButtons.AbortRetryIgnore);
            if res = System.Windows.Forms.DialogResult.Abort then exit else
            if res = System.Windows.Forms.DialogResult.Ignore then break else
            begin
              key.Close;
              key := Registry.ClassesRoot.OpenSubKey('.sac');
            end;
          end;
          
          if key <> nil then key.Close;
          if Registry.ClassesRoot.ExistsSubKey('.sac') then
            Registry.ClassesRoot.DeleteSubKeyTree('.sac');
          
        end;
        key := Registry.ClassesRoot.CreateSubKey('.sac');
        key.SetValue('', RegName);
        
        if (Parameter.All['AddCreateNew'] as CBParameter).CB.Checked then
        begin
          var ShellNew := key.OpenOrCreate('ShellNew');
          ShellNew.SetValue('NullFile','');
          ShellNew.Close;
        end else
        begin
          if key.ExistsSubKey('ShellNew') then
            key.DeleteSubKeyTree('ShellNew');
        end;
        
        key.Close;
        
        System.IO.Directory.CreateDirectory(ProgFilesName);
        
        key := Registry.ClassesRoot.OpenSubKey(RegName,true);
        if key <> nil then
        begin
          if key.GetValue('version') is integer(var val) then
            if val > version then
              if
                MessageBox.Show(string.Format(Translate('Text|reg ver'), val, version),Translate('Cap|reg ver'),MessageBoxButtons.OKCancel) =
                System.Windows.Forms.DialogResult.Cancel
              then exit;
        end else
          key := Registry.ClassesRoot.CreateSubKey(RegName);
        
        key.SetValue('version', version);
        
        var shell := key.OpenOrCreate('shell');
        shell.SetValue('','exec');
        
        System.IO.File.Copy('SAC.exe',ProgFilesName+'\Executor.exe', true);
        var exec := shell.OpenOrCreate('exec');
        exec.SetValue('',Translate('Exec'));
        var exec_com := exec.OpenOrCreate('command');
        exec_com.SetValue('',$'"{ProgFilesName}\Executor.exe" "%1"');
        exec_com.Close;
        exec.Close;
        
        if (Parameter.All['AddIcon'] as CBParameter).CB.Checked then
        begin
          System.IO.File.Copy('Icon.ico',ProgFilesName+'\Icon.ico', true);
          
          var icon := key.OpenOrCreate('DefaultIcon');
          icon.SetValue('', $'"{ProgFilesName}\Icon.ico"');
          icon.Close;
        end else
        begin
          System.IO.File.Delete(ProgFilesName+'\Icon.ico');
          
          if shell.ExistsSubKey('DefaultIcon') then
            shell.DeleteSubKey('DefaultIcon');
        end;
        
        if (Parameter.All['AddConfLaunch'] as CBParameter).CB.Checked then
        begin
          var params_exec := shell.OpenOrCreate('params_exec');
          params_exec.SetValue('', Translate('ConfLaunch'));
          var params_exec_com := params_exec.OpenOrCreate('command');
          params_exec_com.SetValue('',$'"{ProgFilesName}\Executor.exe" "%1" "!conf"');
          params_exec_com.Close;
          params_exec.Close;
        end else
        begin
          if shell.ExistsSubKey('params_exec') then
            shell.DeleteSubKeyTree('params_exec');
        end;
        
        if (Parameter.All['AddEdit'] as CBParameter).CB.Checked then
        begin
          System.IO.File.Copy('Editor.exe',ProgFilesName+'\Editor.exe', true);
          
          var edit := shell.OpenOrCreate('edit');
          edit.SetValue('', Translate('Edit'));
          var edit_com := edit.OpenOrCreate('command');
          edit_com.SetValue('',$'"{ProgFilesName}\Editor.exe" "%1"');
          edit_com.Close;
          edit.Close;
        end else
        begin
          if shell.ExistsSubKey('edit') then
            shell.DeleteSubKeyTree('edit');
        end;
        
        shell.Close;
        key.Close;
        
//        if MessageBox.Show('text','cap',MessageBoxButtons.YesNo) = System.Windows.Forms.DialogResult.Yes then
//          writeln('+') else
//          writeln('-');
        
      end else
      begin
        var key := Registry.ClassesRoot.OpenSubKey(RegName);
        if key <> nil then
        begin
          key.Close;
          Registry.ClassesRoot.DeleteSubKeyTree(RegName);
        end;
        
        key := Registry.ClassesRoot.OpenSubKey('.sac');
        if key <> nil then
        begin
          var val := key.GetValue('') as string;
          key.Close;
          if val = RegName then
            Registry.ClassesRoot.DeleteSubKeyTree('.sac');
        end;
        
        DeleteFolder(ProgFilesName);
      end;
    end;
    
    constructor;
    begin
      Icon := System.Drawing.Icon.FromHandle((new Bitmap(1,1)).GetHicon);
      FormBorderStyle := System.Windows.Forms.FormBorderStyle.Fixed3D;
      f := self;
      
      
      
      LParameter.Create('temp', sender->
      begin
        curr_locale := sender.L.SelectedItem as string;
        Parameter.ValidateNameAll;
      end, 'EN', 'RU');
      
      CBParameter.Create('AssociateDotSAC', CheckState.Indeterminate).AddParams(
        CBParameter.Create('AddIcon', CheckState.Checked),
        CBParameter.Create('AddConfLaunch', CheckState.Checked),
        CBParameter.Create('AddCreateNew', CheckState.Unchecked),
        CBParameter.Create('AddEdit', CheckState.Unchecked)
      );
      
      var proc1: Action0 := Save+Halt;
      var proc2: Action0 := Save;
      BsParameter.Create(
        ('Ok',proc1),
        ('Apply',proc2)
      );
      
      
      
      Parameter.ValidateNameAll;
    end;
  
  end;

begin
  Application.Run(new MForm);
end.