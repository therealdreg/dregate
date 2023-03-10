@call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\bin\amd64\vcvars64.bat"
:Loopez
#nmake clean
nmake
echo "press enter to compile again"
pause
goto Loopez
pause