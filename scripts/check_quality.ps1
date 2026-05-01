## Lint + format-check + headless Godot harness. Use before commits / in CI locally.
## 1) gdformat --check  2) gdlint  3) tests/run_headless.ps1
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectRoot

$Gdformat = Join-Path $ProjectRoot ".venv\Scripts\gdformat.exe"
$Gdlint = Join-Path $ProjectRoot ".venv\Scripts\gdlint.exe"
if (-not (Test-Path $Gdformat) -or -not (Test-Path $Gdlint)) {
	Write-Error "Missing gdtoolkit in .venv - run scripts/bootstrap_dev_env.ps1 first."
}

& $Gdformat --check .
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
& $Gdlint .
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

$Headless = Join-Path $ProjectRoot "tests\run_headless.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Headless
exit $LASTEXITCODE
