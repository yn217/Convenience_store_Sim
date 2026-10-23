# Starts the game from the source tree (Windows).
# Godot: set $env:GODOT to Godot_v4.7.2-stable_win64.exe (the GUI build), or place it at ..\_tools\godot-4.7.2\ next to this repository's parent folder.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT
if (-not $godot) { $godot = Join-Path (Split-Path -Parent $root) '_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' }
if (-not (Test-Path $godot)) { Write-Error "Godot not found: $godot (set `$env:GODOT)"; exit 3 }
& $godot --path $root
