@echo off
REM Kept so existing shortcuts still work. The real entry point is the .vbs
REM beside this file: cmd.exe always creates a console, so starting the manager
REM from a .bat flashes one up no matter what is done here. Handing straight to
REM the .vbs makes that flash as brief as Windows allows.
start "" wscript.exe "%~dp0Update Manager.vbs"
