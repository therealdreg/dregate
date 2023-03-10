set "CAPTH=%~dp0"
cd "%CAPTH%"
del cgateloop.obj
del cgateloop.exe
del cgateloop.ilk
del cgateloop.pdb
"%CAPTH%masmbin\ml.exe" /c /coff "%CAPTH%\cgateloop.asm"
"%CAPTH%masmbin\link.exe" /DEBUG /subsystem:console cgateloop.obj
del "%CAPTH%..\cgateloop.exe"
move "%CAPTH%cgateloop.exe" "%CAPTH%.."
echo "press enter to exit"
pause