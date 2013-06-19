@echo off

set BOOTDIR=%~dp0
set PIKEMASTER=%BOOTDIR%master-1.0.pike
set PIKESYS=%BOOTDIR%system-1.0
set PIKELOGERR=%BOOTDIR%error.log
IF NOT EXIST "C:\Program Files\Pike\bin\pike.exe" GOTO NEWOS

"C:\Program Files\Pike\bin\pike" -m %PIKEMASTER% %PIKESYS% 

GOTO FINISH
:NEWOS
IF NOT EXIST "C:\Program Files (x86)\Pike\bin\pike.exe" GOTO NOPIKE

"C:\Program Files (x86)\Pike\bin\pike" -m %PIKEMASTER% %PIKESYS%

GOTO FINISH

:NOPIKE
echo "Unable to locate pike!"

:FINISH
pause