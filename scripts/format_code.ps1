## Applies gdformat to all GDScript under the project root.
$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Gdformat = Join-Path $ProjectRoot ".venv\Scripts\gdformat.exe"
if (-not (Test-Path $Gdformat)) {
	Write-Error "Missing $Gdformat — run scripts/bootstrap_dev_env.ps1 first."
}
Set-Location $ProjectRoot
& $Gdformat .
exit $LASTEXITCODE
