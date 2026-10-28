# Local verification (no GitHub Actions): layering check, GDScript parse check, headless tests.
# Godot: set $env:GODOT to Godot_v4.7.2-stable_win64_console.exe, or place it at
# ..\_tools\godot-4.7.2\ next to this repository's parent folder.
param([switch]$SkipImport, [int]$Shards = 3)

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

Write-Host '== asset credits audit =='
python (Join-Path $PSScriptRoot 'validation\check_asset_credits.py') $root
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
# One Godot process loads every script (a launch per file took about 1.7 s each, over 6 minutes in all).
& $godot --headless --path $root --script res://tools/validation/parse_all.gd
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host '== headless tests =='
# Godot logs engine errors to stderr; judge by exit code only. The test files are split into $Shards parts run in
# parallel processes (tests/run_all.gd --shard=k/n); a few long store runs dominate the time, so one process waited
# on them one after the other.
$ErrorActionPreference = 'Continue'
$procs = @()
$logs = @()
for ($k = 0; $k -lt $Shards; $k++) {
    $out = Join-Path ([System.IO.Path]::GetTempPath()) ("cs_tests_{0}_{1}.log" -f $PID, $k)
    $err = "$out.err"
    $logs += $out
    $p = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$root`"", '--script', 'res://tests/run_all.gd', '--', "--shard=$k/$Shards") -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
    $null = $p.Handle   # keeps the process handle so ExitCode is readable after it ends
    $procs += $p
}
$procs | Wait-Process
$code = 0
$total = 0
for ($k = 0; $k -lt $Shards; $k++) {
    Get-Content $logs[$k] | Write-Host
    Get-Content "$($logs[$k]).err" | Where-Object { $_ -match '^FAIL ' } | Write-Host
    $line = Select-String -Path $logs[$k] -Pattern '^tests=(\d+)' | Select-Object -Last 1
    if ($line) { $total += [int]$line.Matches[0].Groups[1].Value }
    if ($procs[$k].ExitCode -ne 0) { $code = 1 }
    Remove-Item $logs[$k], "$($logs[$k]).err" -ErrorAction SilentlyContinue
}
Write-Host ("all shards: tests={0} exit={1}" -f $total, $code)
exit $code
