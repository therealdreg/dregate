@echo off

if exist "%1.exe" del "%1.exe"

if not exist rsrc.obj goto nores

\masm32\bin\Link /SUBSYSTEM:WINDOWS /OPT:NOREF "%1.obj" rsrc.obj
dir "%1.*"
goto TheEnd

:nores
\masm32\bin\Link /SUBSYSTEM:WINDOWS /OPT:NOREF "%1.obj"
dir "%1.*"

:TheEnd

if errorlevel 0 dir "%1.*" > \masm32\bin\lnk.txt

\masm32\thegun \masm32\bin\lnk.txt