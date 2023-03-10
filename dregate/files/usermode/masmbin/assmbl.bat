@echo off

if exist "%1.obj" del "%1.obj"

\masm32\bin\ml /c /coff "%1.asm" > \masm32\bin\asmbl.txt

if errorlevel 0 dir "%1.*" >> \masm32\bin\asmbl.txt

\masm32\thegun.exe \masm32\bin\asmbl.txt