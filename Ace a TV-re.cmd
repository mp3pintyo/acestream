@echo off
rem Hasznalat: dupla kattintas (bekeri a linket), vagy:  "Ace a TV-re.cmd" acestream://<id>
rem Leallitas:  "Ace a TV-re.cmd" stop
set "ID=%~1"
if "%ID%"=="" set /p "ID=Ace Stream link vagy ID: "
if /i "%ID%"=="stop" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cast-to-lgtv.ps1" -Stop
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cast-to-lgtv.ps1" -Id "%ID%"
)
pause
