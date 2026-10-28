# Local verification (no GitHub Actions): layering check, GDScript parse check, headless tests.
# Godot: set $env:GODOT to Godot_v4.7.2-stable_win64_console.exe, or place it at
# ..\_tools\godot-4.7.2\ next to this repository's parent folder.
# -Shards: parallel test processes; by default half the logical processors, at most 8 (8 took 2.6 min on 20).
param([switch]$SkipImport, [int]$Shards = [Math]::Max(1, [Math]::Min(8, [int]([Environment]::ProcessorCount / 2))))

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

if (-not $SkipImport) {
    Write-Host '== import (builds global class cache) =='
    & $godot --headless --path $root --import --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Everything below runs at once in separate processes; each one's output is shown when all have ended.
$ErrorActionPreference = 'Continue'
$jobs = @()
function Start-Check([string]$name, [string]$exe, [string[]]$argv) {
    $out = Join-Path ([System.IO.Path]::GetTempPath()) ("cs_tests_{0}_{1}.log" -f $PID, $script:jobs.Count)
    $p = Start-Process -FilePath $exe -ArgumentList $argv -RedirectStandardOutput $out -RedirectStandardError "$out.err" -NoNewWindow -PassThru
    $null = $p.Handle   # keeps the process handle so ExitCode is readable after it ends
    $script:jobs += [pscustomobject]@{ Name = $name; Proc = $p; Log = $out }
}
$q = { param($path) "`"$path`"" }
Start-Check 'asset pipeline: fixture validator' python @((& $q (Join-Path $PSScriptRoot 'assets\validate_manifests.py')), '--dir', (& $q (Join-Path $root 'assets\generated\fixtures')), '--catalog', (& $q (Join-Path $root 'data\fixtures\mvp_v1.json')))
Start-Check 'asset pipeline: customer validator' python @((& $q (Join-Path $PSScriptRoot 'assets\validate_customers.py')), '--dir', (& $q (Join-Path $root 'assets\generated\characters')))
Start-Check 'asset pipeline: python unit tests' python @('-m', 'unittest', 'discover', '-s', (& $q (Join-Path $root 'tests\tools')))
# One Godot process loads every script (a launch per file took about 1.7 s each, over 6 minutes in all).
Start-Check 'GDScript parse check' $godot @('--headless', '--path', (& $q $root), '--script', 'res://tools/validation/parse_all.gd')
# The tests are split into $Shards parts (tests/run_all.gd --shard=k/n), balanced by the times of the last run;
# a few long store runs dominate the time, so one process waited on them one after the other.
for ($k = 0; $k -lt $Shards; $k++) {
    Start-Check "headless tests $k/$Shards" $godot @('--headless', '--path', (& $q $root), '--script', 'res://tests/run_all.gd', '--', "--shard=$k/$Shards")
}
$jobs.Proc | Wait-Process

$code = 0
$total = 0
$times = @{}
foreach ($j in $jobs) {
    Write-Host "== $($j.Name) =="
    if ($j.Name -like 'asset pipeline: python*') {
        Get-Content "$($j.Log).err" | Write-Host   # unittest reports on stderr
    } else {
        Get-Content $j.Log | Write-Host
        # Godot logs engine errors to stderr; judge by exit code only, but show the test failures.
        $err = Get-Content "$($j.Log).err"
        if ($j.Proc.ExitCode -ne 0 -and $j.Name -notlike 'headless*') { $err | Write-Host } else { $err | Where-Object { $_ -match '^FAIL ' } | Write-Host }
    }
    if ($j.Name -like 'headless*') {
        $line = Select-String -Path $j.Log -Pattern '^tests=(\d+)' | Select-Object -Last 1
        if ($line) { $total += [int]$line.Matches[0].Groups[1].Value }
        foreach ($m in (Select-String -Path $j.Log -Pattern '^ran (\S+) \((\d+) ms\)')) { $times[$m.Matches[0].Groups[1].Value] = [int]$m.Matches[0].Groups[2].Value }
    }
    if ($j.Proc.ExitCode -ne 0) { Write-Host "$($j.Name): FAIL (exit $($j.Proc.ExitCode))"; $code = 1 }
    Remove-Item $j.Log, "$($j.Log).err" -ErrorAction SilentlyContinue
}
if ($times.Count -gt 0) {
    [System.IO.File]::WriteAllText((Join-Path $root '.godot\test_times.json'), ($times | ConvertTo-Json))   # balances the next run (no BOM)
}
Write-Host ("all shards: tests={0} exit={1}" -f $total, $code)
exit $code
