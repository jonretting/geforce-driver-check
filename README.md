edGeforce Driver Check (GDC)
==========================
### Checks for new Nvidia Display Drivers then does an automated unattended install, or with many more options.
Copyright (c) 2014 Jon Retting

`git clone https://github.com/jonretting/geforce-driver-check.git`

- [GDC Github repo](https://github.com/jonretting/geforce-driver-check)
- [GDC on SourceForge](https://sourceforge.net/projects/geforce-driver-check/)

### [Latest v1.920](https://sourceforge.net/projects/geforce-driver-check/files/latest/download)

#### [v1.0915-1](https://sourceforge.net/projects/geforce-driver-check/files/geforce-driver-check-10915-1.zip/download)
#### [v1.082](https://sourceforge.net/projects/geforce-driver-check/files/geforce-driver-check-1.082.zip/download)

### Release Notes:

#### 1.0920:
- removed 7z auto download and symlink functionality
- added 7za to replace 7z
- added 7za binary to GDC
- added 7za dependency check
- beta -U arg to remove previous driver version using windows PnPUtil
- added ShieldWirelessController and GfExperienceService to excluxed list
- rename func.src to func.sh
- update wget Mozilla user agent rv to 34.0

#### 1.0915-1:
- fixed pathing issue

#### 1.0915 :
- posix compliancy
- removed bash arrays
- use command instead of hash
- source in functions (func.src)
- source in config (config.conf)
- removed superfluous files
- update README info

#### 1.09 :
- removed various bashisms

#### 1.082 :
- bug fix filename validation per extraction error
- include 7za as valid 7z binary dependency
- add 337.50 Desktop Devices hwid list
- use double underscore for function names
- switch all variables to lowercase
- add additional recursive mkdir error handling

INFO:
-----
- Requires CYGWIN
- No configuration needed to run, simply bash/sh/dash/ash geforce.sh
- Currently supports: Windows 7 x64, Server 2008 r2, Windows 8/8.1 x64, (Server 2012 Untested)
- Works with Desktop and Notebook Graphics adapters
- Can be called from anywhere (supports alias/symlinks/shortcuts)
- Compares your current version with latest available from Nvidias website
- Downloads latest version if current version is older
- Supports the international driver package version when [-i] is invoked
- User interaction required before download/install procedure
- Go fully unattended with the [-s] silent install option or [-y] yes-to-all
- Option to Force-Reinstall latest version will verify integrity of downloaded archive and re-install
- Default config will only install Display Driver, HD-Audio, and PshyX (customize in config.conf)
- Specify default configuration options in config.conf
- Displays Nvidia installation progress box
- Only check if a new version is available with [-C]
- Runs driver setup with all driver packages when [-A] is invoked activate attended install
- Searches for 7-Zip (7z.exe) will prompt for optional creation of symlink
- If 7zip is not found, GDC will prompt to download x64 msi, then prompt to install

DEPENDENCIES:
-------------
wget, 7-Zip

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
- *add GDC rollback functionality to previously installed driver
- *trap ctrl-c/z and kill anything and everything script executed
- *use logger instead of tee, use custom logit to windows events
- *make compatible with multiple installed nvidia card environments
- remove .sh suffix for release candidate
- correct handling of assorted nvidia graphics hardware
- create windows shortcuts to geforce.sh option
- allow for other types ex: x86 version, only whql
- *add geforce inspector tool install options
- add driver purge style installation, complete graphics driver removal
