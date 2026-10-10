# Shared helpers for the ViralForge scripts (dot-sourced).
$ErrorActionPreference = "Stop"
$Script:Root = Split-Path -Parent $PSScriptRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

function Read-DotEnv([string]$Path) {
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    foreach ($line in Get-Content $Path) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#") -or -not $t.Contains("=")) { continue }
        $i = $t.IndexOf("=")
        $map[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim().Trim('"').Trim("'")
    }
    return $map
}

function Find-Python {
    foreach ($candidate in @(@("py", "-3"), @("python"), @("python3"))) {
        try {
            $exe = $candidate[0]; $args2 = @($candidate | Select-Object -Skip 1)
            $v = & $exe @args2 --version 2>&1
            if ($v -match "Python (\d+)\.(\d+)") {
                if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 11)) { return ,$candidate }
            }
        } catch { }
    }
    return $null
}

function Write-FrontendConfig {
    # Only PUBLIC values are written. The service-role key and Gemini key are never copied.
    $envMap = Read-DotEnv (Join-Path $Script:Root ".env")
    $api = if ($envMap["API_BASE_URL"]) { $envMap["API_BASE_URL"] } else { "http://localhost:8000/api/v1" }
    $cfg = [ordered]@{
        SUPABASE_URL      = $envMap["SUPABASE_URL"]
        SUPABASE_ANON_KEY = $envMap["SUPABASE_ANON_KEY"]
        API_BASE_URL      = $api
    }
    $path = Join-Path $Script:Root "frontend\config.json"
    ($cfg | ConvertTo-Json) | Set-Content -Path $path -Encoding UTF8
    Write-Ok "Wrote frontend\config.json (public values only)."
}
