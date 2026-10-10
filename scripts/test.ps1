<# Runs backend tests + lint and frontend analysis + tests. Uses mocked Gemini: no API credits consumed. #>
. "$PSScriptRoot\common.ps1"
$venvPy = Join-Path $Script:Root "backend\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPy)) { Write-Fail "Run .\scripts\setup.ps1 first."; exit 1 }
$failed = 0

Write-Step "Backend: ruff (lint + format check)"
Push-Location (Join-Path $Script:Root "backend")
& $venvPy -m ruff check .;           if ($LASTEXITCODE -ne 0) { $failed++ }
& $venvPy -m ruff format --check .;  if ($LASTEXITCODE -ne 0) { $failed++ }
Write-Step "Backend: pytest"
& $venvPy -m pytest -q;              if ($LASTEXITCODE -ne 0) { $failed++ }
Pop-Location

Write-Step "Frontend: flutter analyze"
Push-Location (Join-Path $Script:Root "frontend")
flutter analyze --no-fatal-infos;                     if ($LASTEXITCODE -ne 0) { $failed++ }
Write-Step "Frontend: flutter test"
flutter test;                        if ($LASTEXITCODE -ne 0) { $failed++ }
Pop-Location

if ($failed -eq 0) { Write-Ok "All checks passed." } else { Write-Fail "$failed check group(s) failed. Copy the first error above and report it."; exit 1 }
