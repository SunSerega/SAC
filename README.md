How to install/uninstall:
-

- Automatic method:

Installing:
1. Download [Config.exe](https://github.com/SunSerega/SAC/raw/master/Config.exe);
2. Place it in folder, you want SAC to be installed to;
3. Launch it, check all modules, you want to be installed, and press OK;
4. Restart your computer, for all icons and context menu shortcuts to be properly allocated.

Some space in ProgramFiles and in Registry would be used.
Uninstalling would clear everything that was created.

Uninstalling:
1. Download [Config.exe](https://github.com/SunSerega/SAC/raw/master/Config.exe) (skip first 2 if you still have it);
2. Place it in folder, you installed SAC to;
3. Launch it, uncheck all and press OK.
4. Restart your computer, for all icons and context menu shortcuts to be properly deleted.

If "Lib" folder is not empty - it would not be deleted when uninstalling.

---

- Manual method:

Installing:
1. Download all modules you need:
	- [SAC.exe](http://github.com/SunSerega/SAC/raw/master/SAC.exe) - runs scripts;
	- [Editor.exe](http://github.com/SunSerega/SAC/raw/master/Editor.exe) - editor for scripts;
2. Create "Lib" folder, next to SAC.exe, if you want to have standard lib of scripts;

To start script it would need to be properly placed in "Lib" folder, or executed with SAC.exe via command line, like this:
"*YourFolder*\SAC.exe" "*ScriptFolder*\*ScriptName*.sac"
If you want to start editor - you the same command, just replace "SAC.exe" with "Editor.exe".

Uninstalling:
1. Just delete everything you created when installing.

How to "Lib" folder:
-

"Lib" folder and it's subfolders must contain set of subfolders and/or script_folders (or be empty) to properly work.
Script_folder is folder with file "main.sac" inside of it.
Script_folder can also contain any other files.

How to command line:
-

If you used automatic installing method - you could chose to install "Configured launch" module.
If so - just press RMB on .sac file you want to execute and press "Configured launch".
(remember, you need to restart computer for this button to be created)
If not - open command line (press Win+R) and enter this string, replacing things in ** with proper names:
"*YourFolder*\SAC.exe" "*ScriptFolder*\*ScriptName*.sac" "!conf".

If you want to know allowed command line agrs list - it is shown in Configured launch.
Start it but just do not start the actual script.
