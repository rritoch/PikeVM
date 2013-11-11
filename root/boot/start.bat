@echo off
set BOOTDIR=%~dp0
set PIKEMASTER=%BOOTDIR%master-1.1.pike
set PIKESYS=%BOOTDIR%system-1.1
set PIKELOGERR=%BOOTDIR%error.log
IF NOT EXIST "C:\Program Files\Pike\bin\pike.exe" GOTO NEWOS
rem set PIKE_INCLUDE_PATH=C:\Program Files\Pike\lib\include
rem set PIKE_MODULE_PATH=C:\Program Files\Pike\lib\modules
"C:\Program Files\Pike\bin\pike"  -m %PIKEMASTER% %PIKESYS%  -I "C:\Program Files\Pike\lib\include" -M "C:\Program Files\Pike\lib\modules" --log-level 0 2>%PIKELOGERR% 
GOTO FINISH
:NEWOS
IF NOT EXIST "C:\Program Files (x86)\Pike\bin\pike.exe" GOTO NOPIKE
rem set PIKE_INCLUDE_PATH=C:\Program Files (x86)\Pike\lib\include
rem set PIKE_MODULE_PATH=C:\Program Files (x86)\Pike\lib\modules
"C:\Program Files (x86)\Pike\bin\pike" -m %PIKEMASTER% %PIKESYS% -I "C:\Program Files (x86)\Pike\lib\include" -M "C:\Program Files (x86)\Pike\lib\modules" --log-level 0 
GOTO FINISH

:NOPIKE
echo "Unable to locate pike!"

:FINISH
pause