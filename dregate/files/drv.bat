set "CAPTH=%~dp0"
echo "driver cant be in a path with spaces"
@call C:\WINDDK\2600.1106\bin\setenv.bat C:\WINDDK\2600.1106\ fre WXP
cd "%CAPTH%"
@call rebuild.bat
pause
