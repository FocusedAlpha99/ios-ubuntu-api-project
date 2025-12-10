@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"
title Project Swivel Auto Fix

echo Locating Visual Studio installation...
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo ERROR: vswhere.exe not found at "%VSWHERE%".
  echo Please ensure Visual Studio Build Tools are installed.
  pause
  exit /b 1
)

for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -property installationPath`) do set "VSINSTALL=%%I"
if not defined VSINSTALL (
  echo ERROR: Unable to detect a Visual Studio installation.
  pause
  exit /b 1
)

echo Installing Spectre Mitigated Libraries... This may take a few minutes.
set "VSINSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe"
if not exist "%VSINSTALLER%" (
  echo ERROR: Visual Studio installer not found at "%VSINSTALLER%".
  pause
  exit /b 1
)
start /wait "" "%VSINSTALLER%" modify --installPath "%VSINSTALL%" --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64.Spectre --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --passive --norestart
if errorlevel 1 (
  echo ERROR: Visual Studio component installation failed.
  pause
  exit /b 1
)

echo Cleaning previous native artifacts...
if exist "server\node_modules" rmdir /s /q "server\node_modules"
if exist "server\package-lock.json" del /f /q "server\package-lock.json"
if exist "%USERPROFILE%\.node-gyp" rmdir /s /q "%USERPROFILE%\.node-gyp"

echo Rebuilding native dependencies from source...
pushd server >nul
call npm install --build-from-source
if errorlevel 1 (
  popd >nul
  echo ERROR: npm install failed. See above logs.
  pause
  exit /b 1
)
popd >nul

if exist "server\node_modules\node-pty\build\Release\conpty.node" (
  echo Fix Complete. System is ready.
  popd >nul
  pause
  exit /b 0
) else (
  echo Build failed. conpty.node not found.
  popd >nul
  pause
  exit /b 1
)
