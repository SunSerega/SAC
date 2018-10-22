<details>
<summary>
How to install/uninstall
</summary>

- Automatic method:

Installing:
1. Download [Config.exe](https://github.com/SunSerega/SAC/raw/master/Config.exe);
2. Place it in folder, you want SAC to be installed to;
3. Launch it, check all modules, you want to be installed, and press OK;
4. Restart your computer, for all icons and context menu shortcuts to be properly allocated.

Some space in ProgramFiles and in Registry would be used.\
Uninstalling would clear everything that was created when installing.

Uninstalling:
1. Download [Config.exe](https://github.com/SunSerega/SAC/raw/master/Config.exe) (skip first 2 if you still have it);
2. Place it in folder, you installed SAC to;
3. Launch it, uncheck all and press OK.
4. Restart your computer, for all icons and context menu shortcuts to be properly deleted.

---

- Manual method

Installing:
1. Download all modules you need:
	- [SAC.exe](http://github.com/SunSerega/SAC/raw/master/SAC.exe) - runs scripts;
	- [Editor.exe](http://github.com/SunSerega/SAC/raw/master/Editor.exe) - editor for scripts;
	- [Help.exe](http://github.com/SunSerega/SAC/raw/master/Help.exe) - manual for operators;
	- [WK.exe](http://github.com/SunSerega/SAC/raw/master/WK.exe) - shows key codes;
2. Create "Lib" folder, next to SAC.exe, if you want to have standard lib of scripts;
3. Copy "Lang" folder from repository to folder with "SAC.exe"

To start script it would need to be properly placed in "Lib" folder, or executed with SAC.exe via command line (Win+R), like this:\
`"*SAC_exe_Folder*\SAC.exe" "*ScriptFolder*\*ScriptName*.sac"`\
If you want to start editor - use the same command, just replace "SAC.exe" with "Editor.exe".

Uninstalling:
1. Just delete everything you created when installing.

---

</details>

<details>
<summary>
How to build
</summary>

1. Install [PABC.Net](PascalABC.Net);
2. Compile "PackAll.pas";
3. Start "PackAll.exe".

When its done - it would say "Ready".\
Then, use one of installing methods, to apply your build.

</details>

<details>
<summary>
How to "Lib" folder:
</summary>

"Lib" folder and it's subfolders must contain set of subfolders and/or script_folders (or be empty) to properly work.\
Script_folder is folder with file "main.sac" inside of it.\
Script_folder can also contain any other files.

---

</details>

<details>
<summary>
How to command line
</summary>

If you used automatic installing method - you could chose to install "Configured launch" module.\
If so - just press RMB on .sac file you want to execute and press "Configured launch".\
(remember, you need to restart computer for this button to be created)\
If not - open command line (press Win+R) and enter this string, replacing things in ** with proper names:\
`"*SAC_exe_Folder*\SAC.exe" "*ScriptFolder*\*ScriptName*.sac" "!conf"`\

If you want to know allowed command line agrs list - it is shown in Configured launch.\
Start it but just do not start the actual script.

---

</details>

<details>
<summary>
How to feedback
</summary>

Please, try to Not put anything except issues and feature requests in issues.

For other types of feedback you can use:

[PABC.Net forum page of SAC](http://forum.mmcs.sfedu.ru/t/sac-scriptautoclicker/2607)\
My email: `latchenko3@yandex.ru`\
[My vk](https://vk.com/sun_serega)

---

</details>
