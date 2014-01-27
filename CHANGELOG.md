Geforce Driver Check (GDC)
==========================
### CHANGE LOG NOTES:

#### 1.05 :
- fix check only exit condition
- use environments globals for defaults first, if exist and not empty
- use more bash builtins over sub shell executions
- various code cleanups
- allow data parse/store functions to call parent query function on demand
- add GDC icons arhive for future links/shortcuts

#### 1.049 :
- various function optimizations
- improve nvidia web query handling
- increased exception handling for root paths and downloads path
- added devices and notebook devices dbase files as tarball
- verify adapter description again devices dbase, instead of just notebook detection

#### 1.048-2 :
- proper detection of graphics card when non-nvidia card is present
- checks for compatabile NVIDIA card early on
- improved wmic installed driver information query
- updated notebook devices db to latest 332.21

#### 1.048-1 :
- better architecture and os version detection including fixes
- added user agent to web data queries huge increase in speed upwards of twice as fast
- fix non executable files having +x permissions

#### 1.048 RC3 :
- CYGWIN 32-bit and 64-bit support
- Force reinstall option [-R] with download validation checks
- Properly detects host architecture and Windows version
- Untested with multiple graphic adapter setups
- User is prompted before new driver download and setup.exe execution
- Supports non-admin account execution
- Most common bugs fixed