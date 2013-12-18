Geforce Driver Check (GDC)
==========================
### Checks for new Nvidia Display Drivers then does an automated unattended install, or with many more options.
Copyright (c) 2013 Jon Retting

- [GDC Github repo](https://github.com/jonretting/geforce-driver-check)
- [GDC Webpage](http://jonretting.github.io/geforce-driver-check/)
- [GDC on SourceForge](https://sourceforge.net/projects/geforce-driver-check/)

###[Latest Milestone v1.046 RC3](https://sourceforge.net/projects/geforce-driver-check/files/latest/download)
####v1.046 RC3 NOTES:
- CYGWIN 32-bit and 64-bit support
- Force reinstall option [-R] with download validation checks
- Properly detects host architecture and Windows version
- Untested with multiple graphic adapter setups
- User is prompted before new driver download and setup.exe execution
- Supports non-admin account execution

INFO:
-----
- Requires CYGWIN
- Currently supports only Windows 7 x64 and Windows 8 x64
- Works with Desktop and Notebook Graphics adapaters
- No configuration needed to run, simply bash the slut
- Compares your current version with latest available from Nvidias website
- Downloads latest version if current version is older
- Option to Force-Reinstall latest version will verify integrity of downloaded archive, and act acordingly
- Will search your Program Files (x86/x64) for 7-Zip (7z.exe) will prompt for optional creation of symlink'
- If 7zip is not found, GDC will prompt to download x64 msi, then prompt to attended or unattended install
- Supports the international driver package version when "-i" is envoked
- Only installs Display Driver, HD Audio, and PshyX
- User interaction required before download/install procedure (unless [-s] or [-y] is envoked)
- Displays Nvidia installation progress box
- Runs driver setup with all driver packages when [-A] is envoked enables [-a] aswell
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
	-s    Silent install (dont show Nvidia progress bar)
	-y    Answer 'yes' to all prompts
	-c    Clean install (removes all saved profiles and settings)
	-d    Specify download location
	-C    Only check for new version (returns version#, 0=update available, 1=no update)
    -R    Force Reinstalls latest driver version (integrity checks on current installer package)
	-A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
	-i    Download international driver package (driver package for non English installs)
	-r    Don't disable reboot prompt when reboot is needed (could be buged)
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
- create windows shortcuts to geforce.sh option, launch from windows bat file
- add notification email switch when update is available
- make crontab friendly
- add long format options --re-install
- correct handling of assorted nvidia graphics hardware
- allow for other types ex: x86 version, only whql
- add geforce inspector tool install options
- add ntune o/c settings option show oc pane
- maybe add NVIDIA Pixel Clock Patcher
- add driver purge style installation, complete graphics driver removal
- make readme not terrible
