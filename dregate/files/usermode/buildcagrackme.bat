set "CAPTH=%~dp0"
cd "%CAPTH%"
del cagrackme.obj
del cagrackme.exe
del cagrackme.ilk
del cagrackme.pdb
"%CAPTH%masmbin\ml.exe" /c /coff "%CAPTH%\cagrackme.asm"
"%CAPTH%masmbin\link.exe" /DEBUG /subsystem:console cagrackme.obj
del "%CAPTH%..\cagrackme.exe"
move "%CAPTH%cagrackme.exe" "%CAPTH%.."
echo "press enter to exit"
pause