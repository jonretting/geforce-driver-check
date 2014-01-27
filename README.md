Geforce Driver Check (GDC)
==========================
### Checks for new Nvidia Display Drivers then does an automated unattended install, or with many more options.
Copyright (c) 2013 Jon Retting

- [GDC Github repo](https://github.com/jonretting/geforce-driver-check)
- [GDC on SourceForge](https://sourceforge.net/projects/geforce-driver-check/)

### [Latest v1.049](https://sourceforge.net/projects/geforce-driver-check/files/latest/download)

RELEASE NOTES:
--------------
#### v1.05 :
- fix check only exit condition
- use environments globals for defaults first, if exist and not empty
- use more bash builtins over sub shell executions
- various code cleanups
- allow data parse/store functions to call parent query function on demand

#### v1.049 :
- various function optimizations
- improve nvidia web query handling
- increased exception handling for root paths and downloads path
- added devices and notebook devices dbase files as tarball
- verify adapter description again devices dbase, instead of just notebook detection

#### v1.048-2 :
- proper detection of graphics card when non-nvidia card is present
- checks for compatabile NVIDIA card early on
- improved wmic installed driver information query
- updated notebook devices db to latest 332.21

#### v1.048-1 :
- better architecture and os version detection including fixes
- added user agent to web data queries huge increase in speed upwards of twice as fast
- fix non executable files having +x permissions

#### v1.048 RC3 :
- CYGWIN 32-bit and 64-bit support
- Force reinstall option [-R] with download validation checks
- Properly detects host architecture and Windows version
- Untested with multiple graphic adapter setups
- User is prompted before new driver download and setup.exe execution
- Supports non-admin account execution
- Most common bugs fixed

INFO:
-----
- Requires CYGWIN
- Currently supports only Windows 7 x64 and Windows 8 x64
- Works with Desktop and Notebook Graphics adapters
- No configuration needed to run, simply bash the slut
- Compares your current version with latest available from Nvidias website
- Downloads latest version if current version is older
- Option to Force-Reinstall latest version will verify integrity of downloaded archive, and act accordingly
- Will search your Program Files (x86/x64) for 7-Zip (7z.exe) will prompt for optional creation of symlink'
- If 7zip is not found, GDC will prompt to download x64 msi, then prompt to attended or unattended install
- Supports the international driver package version when "-i" is invoked
- Only installs Display Driver, HD Audio, and PshyX
- User interaction required before download/install procedure (unless [-s] or [-y] is invoked)
- Displays Nvidia installation progress box
- Runs driver setup with all driver packages when [-A] is invoked enables [-a] as well
- You can check and see if a new version is available with [-C] won't prompt to download and continue
- Extracts new display driver by default to /cygdrive/c/NVIDIA/GDC-"driver-ver#"
- The -r option will enable Nvidia driver installer to prompt user to reboot if needed (untested)

DEPENDENCIES:
-------------
wget, 7-Zip (prompts to download/install 7-Zip if not found)

OPTIONS:
--------
	geforce.sh [-asycCAirVh] [-d=/download/path]
	-a    Attended install (user must traverse Nvidia setup GUI)
	-s    Silent install (don’t show Nvidia progress bar)
	-y    Answer 'yes' to all prompts
	-c    Clean install (removes all saved profiles and settings)
	-d    Specify download location
	-C    Only check for new version (returns version#, 0=update available, 1=no update)
    -R    Force Reinstalls latest driver version (integrity checks on current installer package)
	-A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
	-i    Download international driver package (driver package for non-English installs)
	-r    Don't disable reboot prompt when reboot is needed (could be bugged)
	-V    Displays version info
	-h    this crupt

	See INFO for more information

EXAMPLES:
---------
- Run default
	`./geforce.sh`

- Run with International (driver package for non English installs)
	`./geforce.sh -i`

- Run with all packages enabled (GFexperience, Geforce Vission, etc) fully attended install
	`./geforce.sh -A`

- Run with fully attended install enabled, will requires user to progress through Nvidia setup GUI
	`./geforce.sh -a`

- Run completely silent answers "yes" to all prompts, doesn't display any Nvidia GUI (no driver install progress window)
	`./geforce.sh -s`

- Run and only see if you need an update and exit
	`./geforce.sh -C`

- Run with Download path specified, yes to all prompts, and silent driver install (no Nvidia GUI)
	`./geforce.sh -d "/home/me/Downloads" -s -y`

### TODO:
- *make compatible with multiple installed nvidia card environments
- correct handling of assorted nvidia graphics hardware
- atempt to use registry as informational data fallback
- create windows shortcuts to geforce.sh option, launch from windows bat file
- add notification email switch when update is available
- make crontab friendly
- add long format options --re-install
- allow for other types ex: x86 version, only whql
- add geforce inspector tool install options
- add ntune o/c settings option show oc pane
- add driver purge style installation, complete graphics driver removal
- make readme not terrible
