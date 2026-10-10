<# Starts the Flutter Web app in Chrome on http://localhost:5173 (needs the backend running too). #>
. "$PSScriptRoot\common.ps1"
if (-not (Test-Path (Join-Path $Script:Root ".env"))) { Write-Fail "Run .\scripts\setup.ps1 first."; exit 1 }
Write-FrontendConfig
$envMap = Read-DotEnv (Join-Path $Script:Root ".env")
$port = if ($envMap["FRONTEND_PORT"]) { $envMap["FRONTEND_PORT"] } else { "5173" }
Set-Location (Join-Path $Script:Root "frontend")
flutter run -d chrome --web-port $port --dart-define-from-file=config.json
