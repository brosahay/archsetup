@echo off
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 00000001 /f
@echo on
echo "Windows time fix added!"
pause
