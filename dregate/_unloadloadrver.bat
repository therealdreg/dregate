set "CAPTH=%~dp0"
"%CAPTH%w2k_load.exe" "%CAPTH%\files\objfre_wxp_x86\i386\drvdregate.sys" /unload 
echo starting driver in 3 secs
ping 192.0.2.1 -n 1 -w 3000
"%CAPTH%w2k_load.exe" "%CAPTH%\files\objfre_wxp_x86\i386\drvdregate.sys"
echo driver started! continue in 3 secs....
ping 192.0.2.1 -n 1 -w 3000
