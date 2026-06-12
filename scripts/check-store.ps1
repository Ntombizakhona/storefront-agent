# Preflight: is a WooCommerce store ready for the agent? PowerShell 7+.
#
# Usage:
#   ./scripts/check-store.ps1 -Url https://observability-first.nkulemabaso.com
#
# Checks: (1) strict HTTPS cert is valid for the host, (2) wp-json reachable,
# (3) WooCommerce + Abilities API namespaces present.

[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Url)

$ErrorActionPreference = "Stop"
$base = $Url.TrimEnd("/")
$hostName = ([System.Uri]$base).Host
$pass = $true

function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:pass = $false }
function Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

# 1) Strict HTTPS (validates the certificate, incl. hostname/SAN).
try {
    $r = Invoke-WebRequest "$base/wp-json/" -Method Head -TimeoutSec 30
    Ok "Valid HTTPS (wp-json HEAD $($r.StatusCode))"
}
catch {
    Bad "HTTPS/cert problem: $($_.Exception.Message)"
    Info "If this is a cert mismatch, issue/AutoSSL a cert that covers $hostName."
}

# 2) wp-json reachable + 3) namespaces (skip-cert so we still report on a bad cert).
try {
    $j = (Invoke-WebRequest "$base/wp-json/" -TimeoutSec 30 -SkipCertificateCheck).Content | ConvertFrom-Json
    Ok "wp-json reachable"
    $ns = @($j.namespaces)
    $hasWoo = $ns -contains "wc/v3" -or $ns -contains "wc/store"
    $hasAbilities = $ns -contains "wp-abilities/v1"
    if ($hasWoo) { Ok "WooCommerce REST present (wc/*)" } else { Bad "WooCommerce REST namespaces (wc/v3, wc/store) not found" }
    if ($hasAbilities) { Ok "Abilities API present (wp-abilities/v1)" } else { Bad "Abilities API (wp-abilities/v1) not found - update WordPress/WooCommerce" }
}
catch {
    Bad "Could not read wp-json: $($_.Exception.Message)"
}

Write-Host ""
if ($pass) {
    Write-Host "Store looks agent-ready. Set WP_API_URL=$base in .env, add credentials, then 'adk web'." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Store not ready yet - fix the FAIL items above." -ForegroundColor Yellow
    exit 1
}
