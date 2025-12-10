@echo off
title Project Swivel Launcher
echo [SWIVEL] Checking dependencies...
call npm install
pushd ..\server
call npm install
popd
pushd client
call npm install
popd
echo [SWIVEL] Starting Systems...
echo [SWIVEL] A Browser window should open automatically.
echo [SWIVEL] If this window closes immediately, something crashed.
npm start
pause
