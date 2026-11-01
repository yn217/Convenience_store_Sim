param(
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [string]$ComfyRoot = "F:\Stable Diffusion\ComfyUI-Windows\ComfyUI_windows_portable\ComfyUI"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$candidateRoot = Join-Path $repoRoot "assets\review\imagegen_candidates\20261031\issue30_31_32_comfyui\character_sprites_1024x1536\functional_50_poses"
$derivedDir = Join-Path $repoRoot "assets\runtime\character_pilot\derived_alpha"
$inputDir = Join-Path $ComfyRoot "input"
$outputDir = Join-Path $ComfyRoot "output"
$modelPath = Join-Path $ComfyRoot "models\background_removal\birefnet.safetensors"

if (-not (Test-Path -LiteralPath $modelPath)) { throw "BiRefNet model is missing: $modelPath" }
New-Item -ItemType Directory -Path $derivedDir -Force | Out-Null
New-Item -ItemType Directory -Path $inputDir -Force | Out-Null

$candidates = @(
    @{ id = "event_local_fair"; trigger = "evt_local_fair"; source = "rikka_pose_009_functional_00001_.png" },
    @{ id = "event_roadworks"; trigger = "evt_roadworks"; source = "rikka_pose_010_functional_00001_.png" },
    @{ id = "event_hot_day"; trigger = "evt_hot_day"; source = "rikka_pose_011_functional_00001_.png" },
    @{ id = "event_cold_day"; trigger = "evt_cold_day"; source = "rikka_pose_012_functional_00001_.png" },
    @{ id = "event_sweets_spotlight"; trigger = "evt_sweets_spotlight"; source = "rikka_pose_013_functional_00001_.png" },
    @{ id = "event_snack_buzz"; trigger = "evt_snack_buzz"; source = "rikka_pose_014_functional_00001_.png" },
    @{ id = "event_lunch_pick"; trigger = "evt_lunch_pick"; source = "rikka_pose_019_functional_00001_.png" },
    @{ id = "event_drink_pick"; trigger = "evt_drink_pick"; source = "rikka_pose_020_functional_00001_.png" },
    @{ id = "event_bread_feature"; trigger = "evt_bread_feature"; source = "rikka_pose_021_functional_00001_.png" },
    @{ id = "event_after_work"; trigger = "evt_after_work"; source = "rikka_pose_015_functional_00001_.png" }
)

foreach ($candidate in $candidates) {
    $source = Join-Path $candidateRoot $candidate.source
    if (-not (Test-Path -LiteralPath $source)) { throw "Candidate image is missing: $source" }
    $inputName = "codex_birefnet_$($candidate.id).png"
    Copy-Item -LiteralPath $source -Destination (Join-Path $inputDir $inputName) -Force
    $prefix = "codex_birefnet_$($candidate.id)"
    $prompt = [ordered]@{
        "1" = [ordered]@{ class_type = "LoadImage"; inputs = [ordered]@{ image = $inputName } }
        "2" = [ordered]@{ class_type = "LoadBackgroundRemovalModel"; inputs = [ordered]@{ bg_removal_name = "birefnet.safetensors" } }
        "3" = [ordered]@{ class_type = "RemoveBackground"; inputs = [ordered]@{ bg_removal_model = @("2", 0); image = @("1", 0) } }
        "4" = [ordered]@{ class_type = "InvertMask"; inputs = [ordered]@{ mask = @("3", 0) } }
        "5" = [ordered]@{ class_type = "JoinImageWithAlpha"; inputs = [ordered]@{ image = @("1", 0); alpha = @("4", 0) } }
        "6" = [ordered]@{ class_type = "SaveImage"; inputs = [ordered]@{ images = @("5", 0); filename_prefix = $prefix } }
    }
    $body = [ordered]@{ prompt = $prompt; client_id = "codex-birefnet-event-pilot" } | ConvertTo-Json -Depth 12
    $queued = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -ContentType "application/json" -Body $body
    $entry = $null
    for ($attempt = 0; $attempt -lt 180; $attempt++) {
        Start-Sleep -Seconds 2
        try { $history = Invoke-RestMethod -Uri "$ComfyUrl/history/$($queued.prompt_id)" -TimeoutSec 10 } catch { continue }
        if ($history.PSObject.Properties.Name.Count -eq 0) { continue }
        $entry = $history.($queued.prompt_id)
        if ($entry.status.completed -or $entry.status.status_str -eq "error") { break }
    }
    if ($null -eq $entry -or $entry.status.status_str -ne "success") { throw "BiRefNet failed for $($candidate.id)" }
    $outputName = $entry.outputs."6".images[0].filename
    Copy-Item -LiteralPath (Join-Path $outputDir $outputName) -Destination (Join-Path $derivedDir "$($candidate.id).png") -Force
    Write-Host "processed $($candidate.id) -> $($candidate.trigger)"
}
