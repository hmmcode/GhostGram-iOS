@echo off
rem GhostGram Desktop: configure and build Release, then pack into D:\GhostGram-Desktop.
rem API keys come from D:\TBuild\api.txt (line 1: api_id, line 2: api_hash).
setlocal EnableDelayedExpansion
set VSLANG=1033

call "D:\VS\BuildTools\VC\Auxiliary\Build\vcvars64.bat" -vcvars_ver=14.44 >nul || goto error

set API=-D TDESKTOP_API_TEST=ON
if exist D:\TBuild\api.txt (
  set /a LINE=0
  for /f "usebackq tokens=* delims=" %%L in ("D:\TBuild\api.txt") do (
    set /a LINE+=1
    if !LINE!==1 set API_ID=%%L
    if !LINE!==2 set API_HASH=%%L
  )
  set API=-D TDESKTOP_API_ID=!API_ID! -D TDESKTOP_API_HASH=!API_HASH!
  echo Using API keys from D:\TBuild\api.txt
) else (
  echo D:\TBuild\api.txt not found: building with Telegram test keys.
)

cd /d D:\TBuild\tdesktop\Telegram
if not exist ..\out\Telegram.sln (
  python configure.py x64 !API! -D DESKTOP_APP_DISABLE_AUTOUPDATE=ON -D DESKTOP_APP_DISABLE_CRASH_REPORTS=ON || goto error
)
cmake --build ..\out --config Release --parallel || goto error

if not exist D:\GhostGram-Desktop\TelegramForcePortable mkdir D:\GhostGram-Desktop\TelegramForcePortable
copy /y ..\out\Release\Telegram.exe D:\GhostGram-Desktop\GhostGram.exe >nul || goto error
copy /y D:\TBuild\tdesktop\Telegram\Resources\ghost\GhostLiquid.tdesktop-theme D:\GhostGram-Desktop\ >nul
echo BUILD DONE: D:\GhostGram-Desktop\GhostGram.exe
exit /b 0

:error
echo BUILD FAILED
exit /b 1
