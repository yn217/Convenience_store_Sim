param(
    [Parameter(Mandatory = $true)]
    [string[]]$CandidateId,
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [string]$ComfyRoot = "F:\Stable Diffusion\ComfyUI-Windows\ComfyUI_windows_portable\ComfyUI"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$placementPath = Join-Path $repoRoot "docs\art\COMFYUI_334_IMAGE_PLACEMENT_20261101.json"
$candidateRoot = Join-Path $repoRoot "assets\review\imagegen_candidates\20261031\issue30_31_32_comfyui"
$derivedRoot = Join-Path $repoRoot "assets\review\derived_alpha"
$inputDir = Join-Path $ComfyRoot "input"
$outputDir = Join-Path $ComfyRoot "output"
$modelPath = Join-Path $ComfyRoot "models\background_removal\birefnet.safetensors"

if (-not (Test-Path -LiteralPath $modelPath)) { throw "BiRefNet model is missing: $modelPath" }
$placement = Get-Content -LiteralPath $placementPath -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $derivedRoot -Force | Out-Null
New-Item -ItemType Directory -Path $inputDir -Force | Out-Null

foreach ($id in $CandidateId) {
    $entry = @($placement.assets | Where-Object { $_.asset_id -eq $id }) | Select-Object -First 1
    if ($null -eq $entry) { throw "Candidate not found in placement table: $id" }
    $source = Join-Path $candidateRoot $entry.candidate_relpath
    if (-not (Test-Path -LiteralPath $source)) { throw "Candidate source is missing: $source" }

    $inputName = "codex_birefnet_review_$id.png"
    $prefix = "codex_birefnet_review_$id"
    Copy-Item -LiteralPath $source -Destination (Join-Path $inputDir $inputName) -Force
    $prompt = [ordered]@{
        "1" = [ordered]@{ class_type = "LoadImage"; inputs = [ordered]@{ image = $inputName } }
        "2" = [ordered]@{ class_type = "LoadBackgroundRemovalModel"; inputs = [ordered]@{ bg_removal_name = "birefnet.safetensors" } }
        "3" = [ordered]@{ class_type = "RemoveBackground"; inputs = [ordered]@{ bg_removal_model = @("2", 0); image = @("1", 0) } }
        "4" = [ordered]@{ class_type = "InvertMask"; inputs = [ordered]@{ mask = @("3", 0) } }
        "5" = [ordered]@{ class_type = "JoinImageWithAlpha"; inputs = [ordered]@{ image = @("1", 0); alpha = @("4", 0) } }
        "6" = [ordered]@{ class_type = "SaveImage"; inputs = [ordered]@{ images = @("5", 0); filename_prefix = $prefix } }
    }
    $body = [ordered]@{ prompt = $prompt; client_id = "codex-birefnet-review" } | ConvertTo-Json -Depth 12
    $queued = Invoke-RestMethod -Method Post -Uri "$ComfyUrl/prompt" -ContentType "application/json" -Body $body
    $entryHistory = $null
    for ($attempt = 0; $attempt -lt 180; $attempt++) {
        Start-Sleep -Seconds 2
        try { $history = Invoke-RestMethod -Uri "$ComfyUrl/history/$($queued.prompt_id)" -TimeoutSec 10 } catch { continue }
        if ($history.PSObject.Properties.Name.Count -eq 0) { continue }
        $entryHistory = $history.($queued.prompt_id)
        if ($entryHistory.status.completed -or $entryHistory.status.status_str -eq "error") { break }
    }
    if ($null -eq $entryHistory -or $entryHistory.status.status_str -ne "success") { throw "BiRefNet failed for candidate $id" }
    $outputName = $entryHistory.outputs."6".images[0].filename
    Copy-Item -LiteralPath (Join-Path $outputDir $outputName) -Destination (Join-Path $derivedRoot "$id.png") -Force
    Write-Host "processed $id -> $(Join-Path $derivedRoot "$id.png")"
}
