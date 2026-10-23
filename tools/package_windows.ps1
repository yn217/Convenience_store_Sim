# Local distribution (no export templates needed): a folder with the Godot runtime, the project files
# and a launcher. Output: dist\ConvenienceStoreSim\ (Play.bat starts the game) and dist\ConvenienceStoreSim.zip.
param([switch]$NoZip)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT
if (-not $godot) { $godot = Join-Path (Split-Path -Parent $root) '_tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' }
if (-not (Test-Path $godot)) { Write-Error "Godot not found: $godot (set `$env:GODOT)"; exit 3 }
$out = Join-Path $root 'dist\ConvenienceStoreSim'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force (Join-Path $out 'game') | Out-Null
# Import once so .godot\imported exists, then copy only what the game needs at run time.
& $godot --headless --path $root --import --quit | Out-Null
foreach ($item in 'project.godot', 'icon.svg', 'scenes', 'scripts', 'data', '.godot') {
    $src = Join-Path $root $item
    if (Test-Path $src) { Copy-Item -Recurse -Force $src (Join-Path $out 'game') }
}
New-Item -ItemType Directory -Force (Join-Path $out 'game\assets') | Out-Null
Copy-Item -Recurse -Force (Join-Path $root 'assets\generated') (Join-Path $out 'game\assets\generated')
Copy-Item $godot (Join-Path $out 'Godot.exe')
Set-Content -Encoding ASCII (Join-Path $out 'Play.bat') "@echo off`r`ncd /d %~dp0`r`nstart `"`" Godot.exe --path game`r`n"
Copy-Item (Join-Path $root 'README.md') $out
if (-not $NoZip) {
    $zip = Join-Path $root 'dist\ConvenienceStoreSim.zip'
    if (Test-Path $zip) { Remove-Item $zip }
    Compress-Archive -Path $out -DestinationPath $zip
}
Write-Host "packaged: $out"
