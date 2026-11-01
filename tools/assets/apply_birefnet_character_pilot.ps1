param(
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [string]$ComfyRoot = "F:\Stable Diffusion\ComfyUI-Windows\ComfyUI_windows_portable\ComfyUI",
    [switch]$SkipExisting
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$sourceDir = Join-Path $repoRoot "assets\runtime\character_pilot"
$derivedDir = Join-Path $sourceDir "derived_alpha"
$inputDir = Join-Path $ComfyRoot "input"
$outputDir = Join-Path $ComfyRoot "output"
$modelPath = Join-Path $ComfyRoot "models\background_removal\birefnet.safetensors"

if (-not (Test-Path -LiteralPath $modelPath)) {
    throw "BiRefNet model is missing: $modelPath"
}
New-Item -ItemType Directory -Path $derivedDir -Force | Out-Null
New-Item -ItemType Directory -Path $inputDir -Force | Out-Null

$files = @(
    "event_neighbor_mentions.png",
    "fullbody_dynamic_201.png",
    "fullbody_emotion_05.png",
    "fullbody_tutorial_layout.png",
    "functional_opening_checklist.png",
    "functional_rival_store.png",
    "functional_sold_out.png",
    "functional_low_stock.png",
    "functional_expiry.png",
    "functional_queue.png",
    "functional_access_blocked.png",
    "functional_empty_handed.png",
    "functional_staff_short.png",
    "functional_three_sales.png",
    "functional_ten_sales.png",
    "functional_fifty_visitors.png",
    "functional_six_categories.png"
)

foreach ($file in $files) {
    $source = Join-Path $sourceDir $file
    $destination = Join-Path $derivedDir $file
    if ($SkipExisting -and (Test-Path -LiteralPath $destination)) {
        Write-Host "skip $file"
        continue
    }

    $inputName = "codex_birefnet_$file"
    Copy-Item -LiteralPath $source -Destination (Join-Path $inputDir $inputName) -Force
    $prefix = "codex_birefnet_$([IO.Path]::GetFileNameWithoutExtension($file))"
    $prompt = [ordered]@{
        "1" = [ordered]@{ class_type = "LoadImage"; inputs = [ordered]@{ image = $inputName } }
        "2" = [ordered]@{ class_type = "LoadBackgroundRemovalModel"; inputs = [ordered]@{ bg_removal_name = "birefnet.safetensors" } }
        "3" = [ordered]@{ class_type = "RemoveBackground"; inputs = [ordered]@{ bg_removal_model = @("2", 0); image = @("1", 0) } }
        "4" = [ordered]@{ class_type = "InvertMask"; inputs = [ordered]@{ mask = @("3", 0) } }
        "5" = [ordered]@{ class_type = "JoinImageWithAlpha"; inputs = [ordered]@{ image = @("1", 0); alpha = @("4", 0) } }
        "6" = [ordered]@{ class_type = "SaveImage"; inputs = [ordered]@{ images = @("5", 0); filename_prefix = $prefix } }
    }
    $body = [ordered]@{ prompt = $prompt; client_id = "codex-birefnet-pilot" } | ConvertTo-Json -Depth 12
    $queued = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -ContentType "application/json" -Body $body
    $entry = $null
    for ($attempt = 0; $attempt -lt 180; $attempt++) {
        Start-Sleep -Seconds 2
        try { $history = Invoke-RestMethod -Uri "$ComfyUrl/history/$($queued.prompt_id)" -TimeoutSec 10 } catch { continue }
        if ($history.PSObject.Properties.Name.Count -eq 0) { continue }
        $entry = $history.($queued.prompt_id)
        if ($entry.status.completed -or $entry.status.status_str -eq "error") { break }
    }
    if ($null -eq $entry -or $entry.status.status_str -ne "success") {
        throw "BiRefNet failed for $file"
    }
    $outputName = $entry.outputs."6".images[0].filename
    Copy-Item -LiteralPath (Join-Path $outputDir $outputName) -Destination $destination -Force
    Write-Host "processed $file -> $destination"
}
