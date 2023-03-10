set "CAPTH=%~dp0"
cd "%CAPTH%"
echo "driver cant be in a path with spaces"
rd /s /q objfre_wxp_x86
rd /s /q obj
build -cZg