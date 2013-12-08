Geforce Driver Check (GDC)
==========================
### Checks for new Nvidia Display Drivers then does an automatted unattended install, or with many more options.
Copyright (c) 2013 Jon Retting

- [GDC Github repo](https://github.com/jonretting/geforce-driver-check)
- [GDC Webpage](http://jonretting.github.io/geforce-driver-check/)
- [Latest Milestone v1.041](http://sourceforge.net/projects/geforce-driver-check/files/geforce-driver-check-beta-v1.041.zip/download)
- [GDC on SourceForge](https://sourceforge.net/projects/geforce-driver-check/)

INFO:
-----
- Requires CYGWIN
- Currently supports only Windows 7 x64 and Windows 8 x64
- Works with Desktop and Notebook Graphics adapaters
- Compares your current version with latest available from Nvidias website
- Downloads latest version if current version is older
- If 7zip is not found, GDC will prompt to download x64 msi, then prompt to attended or unattended install
- Supports the international driver package version when "-i" is envoked
- Only installs Display Driver, HD Audio, and PshyX
- Prompts to install after downloading (no prompt, no progress when "-s" is envoked
- Will install automatically, no interaction needed
- Displays Nvidia installation progress box
- Runs driver setup with all driver packages when "-A" is envoked enables "-a" aswell
- Script will search your Program Files (x86/x64) for 7-Zip (7z.exe) will prompt for optional creation of symlink'
- You can check and see if a new version is available with "-C" won't download new driver, won't install
- Extracts new display driver by default to /cygdrive/c/NVIDIA/GDC-"driver-ver#"
- The -r option will enable Nvidia driver installer to prompy user to reboot if needed (untested)
- Use only linux/cygwin paths, all paths are checked before being used
- If default DOWNLOAD_PATH="/cygdrive/e/Downloads" is incorrent, fallback is Windows user's Downloads library

DEPENDENCIES:
-------------
wget, 7-Zip (prompts to install if not found), cygpath

CONFIGURE:
----------
- Specify default DOWNLOAD_PATH="/path" or use the -d option, fallback is /cygdrive/c/Users/current-user=name/Downloads as fallback
- Specify your root os path if different than ROOT_PATH="/cygdrive/c"

OPTIONS:
--------
	geforce.sh [-a] [-s] [-y] [-c] [-d] [-C] [-A] [-V] [-h]
	-a    Attended install (user must traverse Nvidia setup GUI)
	-s    Silent install (dont show Nvidia progress bar)
	-y    Answer 'yes' to all prompts
	-c    Clean install (removes all saved profiles and settings)
	-d    Specify download location
	-C    Only check for new version (returns version#, 0=update available, 1=no update)
	-A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
	-i    Download international driver package (driver package for non English installs)
	-r    Don't disable reboot prompt when reboot is needed (could be buged)
	-V    Displays version info
	-h    this crupt

	See INFO for more information

EXAMPLES:
--------
• Run default

	./geforce.sh
• Run with International (driver package for non English installs)

	./geforce.sh -i
• Run with all packages enabled (GFexperience, Geforce Vission, etc) fully attended install

	./geforce.sh -A
• Run with fully attended install enabled, will requires user to progress through Nvidia setup GUI

	./geforce.sh -a
• Run completely silent answers "yes" to all prompts, doesn't display any Nvidia GUI (no driver install progress window)

	./geforce.sh -s
• Run and only see if you need an update and exit

	./geforce.sh -C
• Run with Download path specified, yes to all prompts, and silent driver install (no Nvidia GUI)

	./geforce.sh -d "/home/me/Downloads" -s -y

TODO:
-----
- add notification email switch when update is available
- make crontab friendly
- allow for other types ex: x86 version, only whql
- specify root path as option
- add reinstallation option force reinstall
- maybe add D3DOverrider 
- add ntune o/c settings option show oc pane
- maybe add NVIDIA Pixel Clock Patcher
- make readme not terrible