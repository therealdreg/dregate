set "CAPTH=%~dp0"
echo "executing .bat as admin"
"%CAPTH%files\dregate.exe" -r "cmd.exe /C ""%CAPTH%_cgateloop.bat""" >NUL