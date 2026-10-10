<#
 One-time setup. Safe to re-run. Does not modify any other repository, delete data, or print secrets.
 Usage (from the repo root):  powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
#>
. "$PSScriptRoot\common.ps1"
Set-Location $Script:Root
$problems = 0

Write-Step "Checking prerequisites"
$py = Find-Python
if ($null -eq $py) { Write-Fail "Python 3.11 or newer was not found. Install it from https://www.python.org/downloads/ (tick 'Add to PATH'), then re-run."; $problems++ }
else { Write-Ok ("Python found: " + ($py -join " ")) }
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) { Write-Fail "Flutter SDK was not found. Install it from https://docs.flutter.dev/get-started/install/windows/web and make sure 'flutter' is on PATH."; $problems++ }
else { Write-Ok "Flutter found." }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Warn2 "Git not found (optional, only needed for version control)." }
if ($problems -gt 0) { Write-Fail "Fix the items above and run setup again."; exit 1 }

Write-Step "Creating .env"
if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env"; Write-Warn2 "Created .env from .env.example. Open it and fill in your Supabase and Gemini values." }
else { Write-Ok ".env already exists (left untouched)." }

Write-Step "Backend: virtual environment and dependencies"
$venv = Join-Path $Script:Root "backend\.venv"
if (-not (Test-Path $venv)) { & $py[0] @($py | Select-Object -Skip 1) -m venv $venv; if ($LASTEXITCODE -ne 0) { Write-Fail "Could not create the virtual environment."; exit 1 } }
$venvPy = Join-Path $venv "Scripts\python.exe"
& $venvPy -m pip install --upgrade pip --quiet
& $venvPy -m pip install -r (Join-Path $Script:Root "backend\requirements-dev.txt")
if ($LASTEXITCODE -ne 0) { Write-Fail "Dependency installation failed. Check your internet connection and the error above."; exit 1 }
Write-Ok "Backend dependencies installed."

Write-Step "Frontend: Flutter Web dependencies"
flutter config --enable-web | Out-Null
Push-Location (Join-Path $Script:Root "frontend")
try {
    if (-not (Test-Path ".metadata")) { flutter create --platforms=web --project-name viralforge_experiment --org com.viralforge . }
    flutter pub get
    if ($LASTEXITCODE -ne 0) { Write-Fail "flutter pub get failed."; exit 1 }
} finally { Pop-Location }
Write-Ok "Frontend dependencies resolved."

Write-Step "Validating configuration"
& $venvPy (Join-Path $Script:Root "scripts\check_config.py")
$cfgOk = ($LASTEXITCODE -eq 0)
if ($cfgOk) { Write-FrontendConfig }

Write-Host ""
if ($cfgOk) {
    Write-Ok "Setup complete."
    Write-Host "Next: 1) run supabase\setup.sql in your Supabase SQL Editor (see README step 3)"
    Write-Host "      2) .\scripts\run-backend.ps1   (terminal 1)"
    Write-Host "      3) .\scripts\run-frontend.ps1  (terminal 2)"
} else {
    Write-Warn2 "Setup finished, but .env still needs values. Edit .env, then run .\scripts\setup.ps1 again."
}
