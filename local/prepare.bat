@echo off
rem GhostGram Desktop: fetch Telegram Desktop, apply GhostGram, build libraries.
setlocal
set VSLANG=1033
set GIT_AUTHOR_NAME=GhostGram Local
set GIT_AUTHOR_EMAIL=ghost@localhost
set GIT_COMMITTER_NAME=GhostGram Local
set GIT_COMMITTER_EMAIL=ghost@localhost

call "D:\VS\BuildTools\VC\Auxiliary\Build\vcvars64.bat" -vcvars_ver=14.44 || goto error

if not exist D:\TBuild mkdir D:\TBuild
if not exist D:\TBuild\ThirdParty mkdir D:\TBuild\ThirdParty
if not exist D:\TBuild\Libraries mkdir D:\TBuild\Libraries
cd /d D:\TBuild

if not exist D:\TBuild\tdesktop (
  git -c core.longpaths=true clone --recursive --depth 1 --shallow-submodules -b v7.4.6 https://github.com/telegramdesktop/tdesktop.git || goto error
  python %~dp0..\desktop\patch.py D:\TBuild\tdesktop || goto error
)

set CARGO_INCREMENTAL=0
call D:\TBuild\tdesktop\Telegram\build\prepare\win.bat silent || goto error
echo PREPARE DONE
exit /b 0

:error
echo PREPARE FAILED
exit /b 1
