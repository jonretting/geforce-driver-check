Geforce Driver Check (GDC)
==========================
### CHANGE LOG NOTES:

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