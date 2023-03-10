set "CAPTH=%~dp0"
echo "executing .bat as admin"
echo 28282 | "%CAPTH%files\dregate.exe" -r "cmd.exe /C ""%CAPTH%_cagrackme.bat""" >NUL