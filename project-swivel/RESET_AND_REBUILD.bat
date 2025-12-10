@echo off
title Project Swivel Native Reset
echo cleaning up conflicting binaries...
if exist ..\server\node_modules rmdir /s /q ..\server\node_modules
if exist ..\server\package-lock.json del /f /q ..\server\package-lock.json
echo Reinstalling Native Dependencies for Windows...
pushd ..\server
call npm install
popd
echo Build Complete. You can now run LAUNCH_SWIVEL.bat
pause
