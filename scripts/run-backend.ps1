<# Starts the API on http://localhost:8000 (docs at /docs). Add -Reload for auto-restart while editing code. #>
param([switch]$Reload)
. "$PSScriptRoot\common.ps1"
$venvPy = Join-Path $Script:Root "backend\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) { Write-Fail "Run .\scripts\setup.ps1 first."; exit 1 }
& $venvPy (Join-Path $Script:Root "scripts\check_config.py")
if ($LASTEXITCODE -ne 0) { exit 1 }
$envMap = Read-DotEnv (Join-Path $Script:Root ".env")
$port = if ($envMap["BACKEND_PORT"]) { $envMap["BACKEND_PORT"] } else { "8000" }
Set-Location (Join-Path $Script:Root "backend")
Write-Host "API:        http://localhost:$port/api/v1/health"
Write-Host "Readiness:  http://localhost:$port/api/v1/health/ready   (checks database + Gemini model)"
Write-Host "Docs:       http://localhost:$port/docs"
$uvArgs = @("-m", "uvicorn", "app.main:app_factory", "--factory", "--host", "127.0.0.1", "--port", $port)
if ($Reload) { $uvArgs += "--reload" }
# If the server ever stops by itself, say why and start it again (Ctrl+C stops for good).
$restarts = 0
while ($true) {
    $started = Get-Date
    & $venvPy @uvArgs
    $code = $LASTEXITCODE
    if ($code -eq 0 -or $code -eq -1073741510) { break }   # clean stop or Ctrl+C
    if (((Get-Date) - $started).TotalSeconds -gt 60) { $restarts = 0 }
    $restarts++
    Write-Host ""
    Write-Host "The backend stopped unexpectedly (exit code $code). Details: backend\logs\backend.log and crash.log" -ForegroundColor Yellow
    if ($restarts -gt 5) { Write-Host "It keeps stopping right after it starts, so it will not restart again." -ForegroundColor Red; exit $code }
    Write-Host "Restarting in 3 seconds... (press Ctrl+C to stop)"
    Start-Sleep -Seconds 3
}
