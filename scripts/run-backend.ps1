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
& $venvPy @uvArgs
