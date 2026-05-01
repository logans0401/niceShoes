## Creates `.venv` at the repo root and installs `requirements-dev.txt` (gdtoolkit: gdformat, gdlint).
## Run once per clone: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap_dev_env.ps1`
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectRoot
if (-not (Test-Path ".venv\Scripts\python.exe")) {
	python -m venv .venv
}
& .\.venv\Scripts\pip.exe install --upgrade pip
& .\.venv\Scripts\pip.exe install -r requirements-dev.txt
Write-Host "NiceShoes dev env ready: gdformat + gdlint in .venv"
