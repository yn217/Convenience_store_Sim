param(
    [switch]$RequireOcclusionSplit
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
    $checks = @(
        ,@("tools/assets/validate_products.py")
        ,@("tools/assets/validate_customers.py")
        ,@("tools/assets/validate_manifests.py", "--catalog", "data/fixtures/mvp_v1.json", "--dir", "assets/generated/fixtures")
        ,@("tools/assets/validate_fixture_zoom.py")
        ,@("tools/assets/validate_product_lod.py")
        ,@("tools/assets/validate_provenance.py")
        ,@("tools/assets/validate_provenance_coverage.py")
    )
    foreach ($check in $checks) {
        Write-Host ">>> python $($check -join ' ')"
        if ($check.Length -gt 1) {
            & python $check[0] $check[1..($check.Length - 1)]
        } else {
            & python $check[0]
        }
        if ($LASTEXITCODE -ne 0) {
            throw "asset audit failed: $($check -join ' ')"
        }
    }
    Write-Host ">>> python tools/assets/audit_occlusion_contract.py"
    if ($RequireOcclusionSplit) {
        & python tools/assets/audit_occlusion_contract.py --require-split
    } else {
        & python tools/assets/audit_occlusion_contract.py
    }
    if ($LASTEXITCODE -ne 0) {
        throw "occlusion audit failed"
    }
    Write-Host "Asset audits completed. Godot runtime acceptance remains a separate gate."
}
finally {
    Pop-Location
}
