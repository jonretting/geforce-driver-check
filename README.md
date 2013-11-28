geforce-driver-check
====================

Checks for newer Nvidia Display Driver then installs silently or with many more options
By: Jon Retting

INFO:
- Currently supports only Windows 7 x64 and Windows 8 x64
- Compares your current version with latest available from Nvidias website
- Downloads latest version if current version is older
- Prompts to launch downloaded new version executable
- Only installs Display Driver, HD Audio, and PshyX
- Will install automatically, no interaction needed
- Removes all non-used display driver inf packages recursively
- Removes old driver inf packages ex: oem7.inf

WARNING: This is not for custom video adapter drivers like some mobile Nvidia devices!

DEPENDENCIES: PnPutil (part of windows), wget, 7-Zip, cygpath

CONFIGURE:
- Specify default download folder by changing $DOWNLOADDIR="/directory"
  or use the -d option

RUNNING:
- execute by bashing geforce.sh
  examples: 
    - ./geforce.sh
    - /dir/geforce-driver-update/geforce.sh
    - alias geforce='/dir/geforce-driver-update/geforce.sh'
    - ln -s "/dir/geforce-driver-update/geforce.sh" /usr/bin/geforce.sh
    - bash geforce.sh
    - bash /dir/geforce-driver-update/geforce.sh

USAGE:
- -a    Attended install (user must traverse Nvidia setup GUI)
- -s    Silent install (dont show Nvidia progress bar)
- -y    Answer 'yes' to all prompts
- -c    Clean install (removes all saved profiles and settings)
- -d    Specify download location
- -C    Only check for new version (returns version#, 0=update available, 1=no update)
- -A    Enable all Nvidia packages (GFExperience, NV3DVision, etc) uses attended install
- -V    Displays version info
- -h    this crupt

TODO: 
- add notification switch when update is available
- make crontab friendly
- allow for other types ex: x86 version, only whql
- verify system os and architecture
