# Local verification (no GitHub Actions): layering check, GDScript parse check, headless tests.
# Godot: set $env:GODOT to Godot_v4.7.2-stable_win64_console.exe, or place it at
# ..\_tools\godot-4.7.2\ next to this repository's parent folder.
param([switch]$SkipImport)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT
if (-not $godot) { $godot = Join-Path (Split-Path -Parent $root) '_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path $godot)) { Write-Error "Godot not found: $godot (set `$env:GODOT)"; exit 3 }

$version = (& $godot --version).Trim()
if (-not $version.StartsWith('4.7.2.stable')) { Write-Error "Godot 4.7.2-stable required, got $version"; exit 3 }
Write-Host "Godot $version"

Write-Host '== layering check =='
python (Join-Path $PSScriptRoot 'validation\check_layering.py') $root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== catalog sync check =='
python (Join-Path $PSScriptRoot 'validation\check_catalog.py') $root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== asset pipeline (python: validator + unit tests) =='
python (Join-Path $PSScriptRoot 'assets\validate_manifests.py') --dir (Join-Path $root 'assets\generated\fixtures') --catalog (Join-Path $root 'data\fixtures\mvp_v1.json')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python (Join-Path $PSScriptRoot 'assets\validate_customers.py') --dir (Join-Path $root 'assets\generated\characters')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python -m unittest discover -s (Join-Path $root 'tests\tools')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipImport) {
    Write-Host '== import (builds global class cache) =='
    & $godot --headless --path $root --import --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host '== GDScript parse check =='
$failed = $false
Get-ChildItem -Path (Join-Path $root 'scripts'), (Join-Path $root 'tests') -Recurse -Filter *.gd | ForEach-Object {
    $res = 'res://' + $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    & $godot --headless --path $root --check-only --script $res
    if ($LASTEXITCODE -ne 0) { Write-Host "parse error: $res"; $failed = $true }
}
if ($failed) { exit 1 }

Write-Host '== headless tests =='
# Godot logs engine errors to stderr; judge by exit code only.
$ErrorActionPreference = 'Continue'
& $godot --headless --path $root --script res://tests/run_all.gd
exit $LASTEXITCODE
