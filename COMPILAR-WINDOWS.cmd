@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-windows.ps1"
if errorlevel 1 (
  echo.
  echo No se genero el ejecutable. Revisa el mensaje anterior.
  pause
  exit /b 1
)
echo.
pause
