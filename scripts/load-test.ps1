# Generates a traffic surge against the storefront so Dynatrace registers
# elevated load/latency for the demo's "observe" step. PowerShell 7+.
#
# Usage:
#   ./scripts/load-test.ps1 -Url https://your-store.example.com
#   ./scripts/load-test.ps1 -Url http://1.2.3.4 -DurationSeconds 120 -Concurrency 40
#
# Stop early with Ctrl+C. This only sends GET requests to public pages.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [int]$DurationSeconds = 90,
    [int]$Concurrency = 25,
    [int]$DelayMs = 0
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "This script needs PowerShell 7+ (uses ForEach-Object -Parallel). Try 'pwsh'."
}

# A few common WooCommerce paths to spread load realistically.
$paths = @("/", "/shop/", "/cart/", "/?s=jersey", "/?post_type=product")

Write-Host "Surging $Url for ${DurationSeconds}s at concurrency $Concurrency..." -ForegroundColor Cyan
Write-Host "(GET requests only; Ctrl+C to stop early)" -ForegroundColor DarkGray

$deadline = (Get-Date).AddSeconds($DurationSeconds)
$baseUrl = $Url.TrimEnd("/")

$results = 1..$Concurrency | ForEach-Object -Parallel {
    $base = $using:baseUrl
    $paths = $using:paths
    $deadline = $using:deadline
    $delayMs = $using:DelayMs

    $ok = 0; $err = 0; $totalMs = 0.0
    while ((Get-Date) -lt $deadline) {
        $target = $base + ($paths | Get-Random)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            Invoke-WebRequest -Uri $target -UseBasicParsing -TimeoutSec 30 | Out-Null
            $ok++
        }
        catch {
            $err++
        }
        $sw.Stop()
        $totalMs += $sw.Elapsed.TotalMilliseconds
        if ($delayMs -gt 0) { Start-Sleep -Milliseconds $delayMs }
    }
    [pscustomobject]@{ Ok = $ok; Err = $err; TotalMs = $totalMs }
} -ThrottleLimit $Concurrency

$ok = ($results | Measure-Object -Property Ok -Sum).Sum
$err = ($results | Measure-Object -Property Err -Sum).Sum
$totalMs = ($results | Measure-Object -Property TotalMs -Sum).Sum
$count = $ok + $err
$avg = if ($count -gt 0) { [math]::Round($totalMs / $count, 1) } else { 0 }

Write-Host ""
Write-Host "Done. Requests: $count  OK: $ok  Errors: $err  Avg latency: ${avg}ms" -ForegroundColor Green
Write-Host "Check Dynatrace now - load/latency for the store should be elevated." -ForegroundColor Yellow
