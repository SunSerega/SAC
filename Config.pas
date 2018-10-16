{$apptype windows}
{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}

uses System.Windows.Forms;
uses System.Drawing;
uses Microsoft.Win32;

uses LocaleData;
uses SettingsData;

var
  f: Form;
  
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
  
  {$region Config Parameter's}
  
  ParameterState = (StOn, StOff, StPart);
  Parameter = abstract class
    
    class RootParams := new List<Parameter>;
    class All := new Dictionary<string,Parameter>;
    
    Parent: Parameter;
    Name, Text: string;
    SubPar := new List<Parameter>;
    
    SubParStateChanged: procedure;
    
    
    
    function GetCBChecked: boolean; virtual := false;
    
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
      
      f.Width := Max(200,maxw + 10);
      f.Height := y + 68;
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
      if Name = '' then exit;
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
    
    function GetCBChecked: boolean; override;
    begin
      if (Parent is CBParameter) and not Parent.GetCBChecked then exit;
      
      Result := CB.CheckState <> CheckState.Unchecked;
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
      if SubPar.Count <> 0 then
        if SubPar.All(p->  (not (p is CBParameter)) or ((p as CBParameter).CB.CheckState = CheckState.Checked)  ) then
          self.CB.CheckState := CheckState.Checked else
        if SubPar.Any(p->  (not (p is CBParameter)) or ((p as CBParameter).CB.CheckState = CheckState.Checked)  ) then
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
  
  {$endregion Config Parameter's}
  
  {$region Lib file's}
  
  LibDir=class
    
    public constructor := exit;
    
    public class root := new LibDir;
    
    public sdirs := new Dictionary<string, LibDir>;
    public fls := new List<string>;
    
    public procedure Add(dir,fname: string);
    begin
      var ss := dir.Split(new char[]('\'), 2);
      if ss.Length=1 then
      begin
        var res: LibDir;
        if sdirs.ContainsKey(dir) then
          res := sdirs[dir] else
          res := new LibDir;
        res.fls.Add(fname);
        sdirs[dir] := res;
      end else
      begin
        var res: LibDir;
        if sdirs.ContainsKey(ss[0]) then
          res := sdirs[ss[0]] else
          res := new LibDir;
        res.Add(ss[1],fname);
        sdirs[ss[0]] := res;
      end;
    end;
    
    public procedure Delete(path: string := System.IO.Directory.GetCurrentDirectory+'\');
    begin
      
      foreach var kvp in sdirs do
        kvp.Value.Delete(path+kvp.Key+'\');
      self.sdirs.Clear;
      
      foreach var fname in fls do
        System.IO.File.Delete(path+fname);
      self.fls.Clear;
      
      if not System.IO.Directory.EnumerateFileSystemEntries(path).Any then
        System.IO.Directory.Delete(path);
      
    end;
    
  end;
  
  {$endregion Lib file's}
  
  MForm = class(Form)
    
    const RegName = 'ScriptAutoClicker';
    class ProgFilesName := System.Environment.GetEnvironmentVariable('ProgramFiles')+'\'+RegName;
    
    const version = 1;
    class misc_loaded: boolean;
    class sac_exe_loaded: boolean;
    
    
    
    class procedure DeleteFolder(dir: string; params excpt: array of string);
    begin
      if not System.IO.Directory.Exists(dir) then exit;
      System.IO.Directory.EnumerateDirectories(dir).ForEach(d->MForm.DeleteFolder(d, excpt));
      System.IO.Directory.EnumerateFiles(dir).Where(fname->not excpt.Contains(fname)).ForEach(System.IO.File.Delete);
      if not System.IO.Directory.EnumerateFileSystemEntries(dir).Any then
        System.IO.Directory.Delete(dir);
    end;
    
    class procedure FileFromStream(fname: string; str: System.IO.Stream);
    begin
      var f := System.IO.File.Create(fname);
      str.CopyTo(f);
      f.Close;
      str.Position := 0;
    end;
    
    class procedure LoadLib;
    begin
      System.IO.Directory.CreateDirectory('Lib');
      var br := new System.IO.BinaryReader(GetResourceStream('lib_pack'));
      while br.BaseStream.Position < br.BaseStream.Length do
      begin
        var d := br.ReadString;
        System.IO.Directory.CreateDirectory(d);
        var f := br.ReadString;
        LibDir.root.Add(d, f);
        var bw := new System.IO.BinaryWriter(System.IO.File.Create(d+'\'+f));
        var left := br.ReadInt64;
        while left > 0 do
        begin
          var curr := Min(4096, left);
          bw.Write(br.ReadBytes(curr));
          left -= curr;
        end;
        
        bw.Close;
      end;
      br.BaseStream.Position := 0;
    end;
    
    procedure Load;
    begin
      
      LoadLocale('#Config');
      LoadSettings;
      (Parameter.All['CurrLang'] as LParameter).L.SelectedItem := CurrLocale;
      
      {$resource 'Icon.ico'}
      {$resource 'Editor.exe'}
      if not System.IO.File.Exists('Icon.ico') then FileFromStream('Icon.ico', GetResourceStream('Icon.ico'));
      if not System.IO.File.Exists('Editor.exe') then FileFromStream('Editor.exe', GetResourceStream('Editor.exe'));
      {$resource 'lib_pack'}
      LoadLib;
      misc_loaded := true;
      
      {$resource 'SAC.exe'}
      if not System.IO.File.Exists('SAC.exe') then FileFromStream('SAC.exe', GetResourceStream('SAC.exe'));
      sac_exe_loaded := true;
      
      
      
      
      var root := Registry.ClassesRoot;
      
      
      
      var key := root.OpenSubKey('.sac');
      
      var DotSac := (key <> nil) and (key.GetValue('') as string = RegName);
      if not (DotSac or root.ExistsSubKey(RegName)) then
      begin
        if key <> nil then key.Close;
        exit;
      end;
      (Parameter.All['AssociateDotSAC'] as CBParameter).CB.Checked := DotSac;
      
      if key <> nil then
      begin
        
        (Parameter.All['AddCreateNew'] as CBParameter).CB.Checked := key.ExistsSubKey('ShellNew');
        
        key.Close;
      end;
      
      
      
      key := root.OpenSubKey(RegName);
      if key <> nil then
      begin
        
        (Parameter.All['AddIcon'] as CBParameter).CB.Checked := key.ExistsSubKey('DefaultIcon');
        
        var shell := key.OpenSubKey('shell');
        if shell <> nil then
        begin
          
          (Parameter.All['AddConfLaunch'] as CBParameter).CB.Checked := shell.ExistsSubKey('params_exec');
          (Parameter.All['AddEdit'] as CBParameter).CB.Checked := shell.ExistsSubKey('edit');
          
          shell.Close;
        end;
        
        key.Close;
      end;
      
      
      
      foreach var p in Parameter.All.Values do
        if p.SubParStateChanged <> nil then
          p.SubParStateChanged();
      
    end;
    
    procedure Save;
    begin
      var rest_needed := false;
      
      if Parameter.All['AssociateDotSAC'].GetCBChecked then
      begin
        var key := Registry.ClassesRoot.OpenSubKey('.sac');
        if key = nil then
          rest_needed := true else
        begin
          if not key.ExistsSubKey('ShellNew') then rest_needed := true;
          
          while (key <> nil) and (key.GetValue('') as string <> RegName) do
            case MessageBox.Show(string.Format(Translate('Text|reg used'), key.GetValue('')),Translate('Cap|reg used'),MessageBoxButtons.AbortRetryIgnore) of
              System.Windows.Forms.DialogResult.Ignore: break;
              System.Windows.Forms.DialogResult.Retry:
              begin
                key.Close;
                key := Registry.ClassesRoot.OpenSubKey('.sac');
              end;
              else exit;
            end;
          
          if key <> nil then key.Close;
          if Registry.ClassesRoot.ExistsSubKey('.sac') then
            Registry.ClassesRoot.DeleteSubKeyTree('.sac');
          
        end;
        key := Registry.ClassesRoot.CreateSubKey('.sac');
        key.SetValue('', RegName);
        
        if Parameter.All['AddCreateNew'].GetCBChecked then
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
                MessageBox.Show(string.Format(Translate('Text|reg ver'), val, version),Translate('Cap|reg ver'),MessageBoxButtons.OKCancel) <>
                System.Windows.Forms.DialogResult.OK
              then exit;
        end else
          key := Registry.ClassesRoot.CreateSubKey(RegName);
        
        if not misc_loaded then
        begin
          FileFromStream('Icon.ico', GetResourceStream('Icon.ico'));
          FileFromStream('Editor.exe', GetResourceStream('Editor.exe'));
          LoadLib;
          misc_loaded := true;
        end;
        
        if not sac_exe_loaded then
        begin
          FileFromStream('SAC.exe', GetResourceStream('SAC.exe'));
          sac_exe_loaded := true;
        end;
        
        key.SetValue('', 'SAC Script');
        key.SetValue('version', version);
        
        if not key.ExistsSubKey('shell') then rest_needed := true;
        var shell := key.OpenOrCreate('shell');
        shell.SetValue('','exec');
        
        System.IO.File.Copy('SAC.exe',ProgFilesName+'\Executor.exe', true);
        var exec := shell.OpenOrCreate('exec');
        exec.SetValue('',Translate('Exec'));
        var exec_com := exec.OpenOrCreate('command');
        exec_com.SetValue('',$'"{ProgFilesName}\Executor.exe" "%1"');
        exec_com.Close;
        exec.Close;
        
        if Parameter.All['AddIcon'].GetCBChecked then
        begin
          System.IO.File.Copy('Icon.ico',ProgFilesName+'\Icon.ico', true);
          
          if not key.ExistsSubKey('DefaultIcon') then rest_needed := true;
          var icon := key.OpenOrCreate('DefaultIcon');
          icon.SetValue('', $'"{ProgFilesName}\Icon.ico"');
          icon.Close;
        end else
        begin
          System.IO.File.Delete(ProgFilesName+'\Icon.ico');
          
          if shell.ExistsSubKey('DefaultIcon') then
          begin
            shell.DeleteSubKey('DefaultIcon');
            rest_needed := true;
          end;
        end;
        
        if Parameter.All['AddConfLaunch'].GetCBChecked then
        begin
          if not shell.ExistsSubKey('params_exec') then rest_needed := true;
          var params_exec := shell.OpenOrCreate('params_exec');
          params_exec.SetValue('', Translate('ConfLaunch'));
          var params_exec_com := params_exec.OpenOrCreate('command');
          params_exec_com.SetValue('',$'"{ProgFilesName}\Executor.exe" "%1" "!conf"');
          params_exec_com.Close;
          params_exec.Close;
        end else
          if shell.ExistsSubKey('params_exec') then
          begin
            shell.DeleteSubKeyTree('params_exec');
            rest_needed := true;
          end;
        
        if Parameter.All['AddEdit'].GetCBChecked then
        begin
          System.IO.File.Copy('Editor.exe',ProgFilesName+'\Editor.exe', true);
          
          if not shell.ExistsSubKey('edit') then rest_needed := true;
          var edit := shell.OpenOrCreate('edit');
          edit.SetValue('', Translate('Edit'));
          var edit_com := edit.OpenOrCreate('command');
          edit_com.SetValue('',$'"{ProgFilesName}\Editor.exe" "%1"');
          edit_com.Close;
          edit.Close;
        end else
          if shell.ExistsSubKey('edit') then
          begin
            shell.DeleteSubKeyTree('edit');
            rest_needed := true;
          end;
        
        shell.Close;
        key.Close;
        
        
        
        var sw := new System.IO.StreamWriter(System.IO.File.Create($'{ProgFilesName}\Settings.ini'));
        sw.WriteLine($'CurrLang={CurrLocale}');
        sw.Close;
        
      end else
      begin
        if Registry.ClassesRoot.ExistsSubKey(RegName) then
        begin
          Registry.ClassesRoot.DeleteSubKeyTree(RegName);
          rest_needed := true;
        end;
        
        var key := Registry.ClassesRoot.OpenSubKey('.sac');
        if key <> nil then
        begin
          var val := key.GetValue('') as string;
          key.Close;
          if val = RegName then
          begin
            Registry.ClassesRoot.DeleteSubKeyTree('.sac');
            rest_needed := true;
          end;
        end;
        
        if
          System.IO.File.Exists($'{ProgFilesName}\Settings.ini') and
          (
            MessageBox.Show(Translate('Text|SettingsDel'),Translate('Cap|SettingsDel'),MessageBoxButtons.YesNo)
            <>System.Windows.Forms.DialogResult.Yes
          )
        then
          DeleteFolder(ProgFilesName, $'{ProgFilesName}\Settings.ini') else
          DeleteFolder(ProgFilesName);
        
        if misc_loaded then
        begin
          misc_loaded := false;
          
          LibDir.root.Delete;
          
          if
            (not System.IO.Directory.Exists('Lib')) or
            (
              MessageBox.Show(Translate('Text|LibDel'),Translate('Cap|LibDel'),MessageBoxButtons.YesNo)
              =System.Windows.Forms.DialogResult.Yes
            )
          then
            DeleteFolder('Lib');
          
          System.IO.File.Delete('Icon.ico');
          System.IO.File.Delete('Editor.exe');
          
        end;
        
        System.IO.File.Delete('SAC.exe');
        sac_exe_loaded := false;
        
        rest_needed := true;
      end;
      
      
      
      if not rest_needed then exit;
      MessageBox.Show(Translate('Text|NeedRestart'),Translate('Cap|NeedRestart'),MessageBoxButtons.OK);
    end;
    
    procedure ClearAndExit;
    begin
      
      System.IO.File.Delete('Icon.ico');
      System.IO.File.Delete('Editor.exe');
      
      Halt;
    end;
    
    constructor;
    begin
      Icon := System.Drawing.Icon.FromHandle((new Bitmap(1,1)).GetHicon);
      FormBorderStyle := System.Windows.Forms.FormBorderStyle.Fixed3D;
      f := self;
      
      
      
      LParameter.Create('CurrLang', sender->
      begin
        CurrLocale := sender.L.SelectedItem as string;
        Parameter.ValidateNameAll;
      end, LangList);
      
      CBParameter.Create('AssociateDotSAC', CheckState.Indeterminate).AddParams(
        CBParameter.Create('AddIcon', CheckState.Checked),
        CBParameter.Create('AddConfLaunch', CheckState.Checked),
        CBParameter.Create('AddCreateNew', CheckState.Unchecked),
        CBParameter.Create('AddEdit', CheckState.Unchecked)
      );
      
      var proc1: Action0 := Save+ClearAndExit;
      var proc2: Action0 := Save;
      BsParameter.Create(
        ('Ok',proc1),
        ('Apply',proc2)
      );
      
      
      
      Load;
      Parameter.ValidateNameAll;
      
      self.Shown += procedure(o,e)->
      (Parameter.All['Ok'] as BPar).B.Focus;
      
    end;
  
  end;

begin
  try
    if
      //true or
      (CommandLineArgs.Length=1) and (CommandLineArgs[0]='SkipUAC')
    then
      Application.Run(new MForm) else
    begin
      var startInfo := new System.Diagnostics.ProcessStartInfo();
      startInfo.UseShellExecute := true;
      startInfo.WorkingDirectory := System.Environment.CurrentDirectory;
      startInfo.FileName := Application.ExecutablePath;
      startInfo.Verb := 'runas';
      startInfo.Arguments := 'SkipUAC';
      System.Diagnostics.Process.Start(startInfo);
      Halt;
    end;
  except
    on e: Exception do
    begin
      writeln('Error:');
      writeln(e);
      readln;
    end;
  end;
end.