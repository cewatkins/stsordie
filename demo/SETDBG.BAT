@echo off
set NOCOM3=1
set NOCOM4=1
set POLL=1
if "%1"=="" goto defexe
debug %1
goto done
:defexe
debug PCH12.EXE
:done
