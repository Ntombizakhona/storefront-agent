# Preflight: are the Dynatrace tokens valid before you run the agent? PS 7+.
#
# Usage:
#   ./scripts/check-dynatrace.ps1                # reads .env
#   ./scripts/check-dynatrace.ps1 -EnvFile .env
#
# Checks:
#   1) OTLP token  -> empty protobuf probe to DT_OTLP_ENDPOINT/v1/metrics (auth check)
#   2) Platform token -> trivial DQL query against DT_ENVIRONMENT (best-effort)

[CmdletBinding()]
param([string]$EnvFile = ".env")

$ErrorActionPreference = "Stop"
$pass = $true

function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Bad($m)  { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:pass = $false }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "       $m" -ForegroundColor DarkGray }

if (-not (Test-Path $EnvFile)) { throw "Env file not found: $EnvFile" }

# --- Parse .env into a hashtable --------------------------------------------
$env_ = @{}
foreach ($line in Get-Content $EnvFile) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#") -or -not $t.Contains("=")) { continue }
    $k, $v = $t.Split("=", 2)
    $env_[$k.Trim()] = $v.Trim()
}

function StatusOf($err) {
    try { return [int]$err.Exception.Response.StatusCode.value__ } catch { return $null }
}

# --- 1) OTLP token: send a test metric --------------------------------------
$otlp = $env_["DT_OTLP_ENDPOINT"]
$otlpToken = $env_["DT_OTLP_TOKEN"]
if (-not $otlp -or -not $otlpToken) {
    Warn "DT_OTLP_ENDPOINT / DT_OTLP_TOKEN not set - skipping OTLP check."
}
else {
    $uri = ($otlp.TrimEnd("/")) + "/v1/metrics"
    # Probe with an empty OTLP protobuf body (valid empty message). Dynatrace
    # checks content-type first (JSON -> 415, inconclusive), so we use protobuf
    # to reach the auth layer: 401/403 = bad token, anything else = authenticated.
    try {
        $resp = Invoke-WebRequest -Uri $uri -Method Post -Body ([byte[]]@()) `
            -Headers @{ Authorization = "Api-Token $otlpToken" } `
            -ContentType "application/x-protobuf" -TimeoutSec 30
        Ok "OTLP token accepted (HTTP $($resp.StatusCode))."
    }
    catch {
        $code = StatusOf $_
        if ($code -in 401, 403) {
            Bad "OTLP token rejected (HTTP $code)."
            Info "Use an Access Token (dt0c01...) with scopes openTelemetryTrace.ingest + metrics.ingest -"
            Info "NOT a Platform Token (dt0s16...). Create at: Dynatrace > Access Tokens."
        }
        elseif ($code -eq 400) { Ok "OTLP token accepted (HTTP 400 on empty probe = authenticated)." }
        elseif ($code) { Warn "OTLP endpoint returned HTTP $code; token likely OK. Verify DT_OTLP_ENDPOINT ($uri)." }
        else { Bad "OTLP request failed: $($_.Exception.Message)" }
    }
}

# --- 2) Platform token: trivial DQL query (best-effort) ---------------------
$envUrl = $env_["DT_ENVIRONMENT"]
$platToken = $env_["DT_PLATFORM_TOKEN"]
if (-not $envUrl -or -not $platToken) {
    Warn "DT_ENVIRONMENT / DT_PLATFORM_TOKEN not set - skipping platform-token check."
}
else {
    $uri = ($envUrl.TrimEnd("/")) + "/platform/storage/query/v1/query:execute"
    $body = @{ query = "fetch logs | limit 1" } | ConvertTo-Json
    try {
        $resp = Invoke-WebRequest -Uri $uri -Method Post -Body $body `
            -Headers @{ Authorization = "Bearer $platToken" } `
            -ContentType "application/json" -TimeoutSec 30
        Ok "Platform token accepted (HTTP $($resp.StatusCode)) - DQL query executed."
    }
    catch {
        $code = StatusOf $_
        if ($code -in 401, 403) { Bad "Platform token rejected (HTTP $code) - check the token + MCP scopes (see docs/dynatrace-setup.md)." }
        elseif ($code) { Warn "Platform API returned HTTP $code (token authenticated). Endpoint shape may differ by tenant; the MCP server is the real test." }
        else { Bad "Platform request failed: $($_.Exception.Message)" }
    }
}

Write-Host ""
if ($pass) { Write-Host "Dynatrace preflight passed." -ForegroundColor Green; exit 0 }
else { Write-Host "Dynatrace preflight had failures - fix the FAIL items above." -ForegroundColor Yellow; exit 1 }
