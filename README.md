geforce-driver-check
====================

### Checks for newer Nvidia Display Driver then does an unattended install, or with many more options 
By: Jon Retting

INFO:
-----
- Requires CYGWIN
- Currently supports only Windows 7 x64 and Windows 8 x64
- Compares your current version with latest available from Nvidias website
- Downloads latest version if current version is older
- Prompts to launch downloaded new version executable
- Only installs Display Driver, HD Audio, and PshyX
- Prompts to install after downloading (no prompt, no progress when "-s" is envoked
- Will install automatically, no interaction needed
- Displays Nvidia installation progress box
- Runs driver setup with all driver packages when "-A" is envoked enables "-a" aswell
- Removes all non-used Nvidia display driver oem inf packages
- Removes old driver inf packages ex: oem7.inf
- Script will search your Program Files (x86/x64) for 7-Zip (7z.exe) will prompt for optional creation of symlink'
- You can check and see if a new version is available with "-C" won't download new driver, won't install
- Extracts new display driver by default to /cygdrive/c/GDC-"driver ver"

WARNING: 
--------
This is not for custom video adapter drivers like some mobile Nvidia devices!

DEPENDENCIES:
-------------
PnPutil (part of windows), wget, 7-Zip, cygpath

CONFIGURE:
----------
- Specify default download folder by changing DOWNLOADDIR="/directory"
  or use the -d option (do not use windows paths)
- Specify your root os path, default= /cygdrive/c

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
	-V    Displays version info
	-h    this crupt

	See INFO for mo information


TODO:
-----
- add notification email switch when update is available
- make crontab friendly
- allow for other types ex: x86 version, only whql
- verify system os and architecture
- support internation driver version option
- specify root path as option
