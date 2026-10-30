@echo off
rem Starts the game window from this folder (double-click, or run from a terminal).
rem Godot is looked up in this order: the GODOT environment variable, the shared copy in
rem ..\_tools\godot-4.7.2, then godot on PATH. Extra arguments are passed on to Godot.
setlocal
chcp 65001 > nul
set "ROOT=%~dp0"

set "EXE="
if defined GODOT if exist "%GODOT%" set "EXE=%GODOT%"
if not defined EXE if exist "%ROOT%..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" set "EXE=%ROOT%..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not defined EXE (
	where godot > nul 2>&1 && set "EXE=godot"
)
if not defined EXE (
	echo Godot 4.7.2 was not found.
	echo Set GODOT to the path of Godot_v4.7.2-stable_win64.exe, or put it in ..\_tools\godot-4.7.2\.
	pause
	exit /b 1
)

start "" "%EXE%" --path "%ROOT%." %*
endlocal
