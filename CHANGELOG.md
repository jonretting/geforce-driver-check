Geforce Driver Check (GDC)
==========================
### CHANGE LOG NOTES:

#### 1.076-1 :
- fix wget bad var name for url
- fix installer exit code issue
- all function names changed for better readability, and follows common naming conventions
- tab character indents replaced with four spaces per indent
- all vars renamed for better readability, and given GDC_ prefix to avoid any shell  confusion
- better Win OS architecture detection (no sub-shell), and more descriptive error
- better Win OS version detection (no-sub-shell), and more descriptive error

#### 1.06-BETA :
- add logger to deps list, and validate true
- add non functioning reminder options logger and verbose
- minify devices compat detect function
- prep adding log message output to windows event log
- remove hyphen from function names
- replace echo with printf where appropriate
- fix inf loop detect counter for source script path
- *remove/alter vast majority of bashisms

#### 1.051-BugFix :
- fix extract path
- fix international vars
- fix adapater type
- fix installed ver number
- fix install path
- add 7zip -y flag
- add Network.Service to do not install pkg array (is user editable array top of script)

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
