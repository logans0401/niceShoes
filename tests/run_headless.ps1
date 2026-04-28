# Headless test run for NiceShoes (Godot 4.6.x).
# Default engine folder matches local install: D:\Godot
param(
	[string] $GodotDir = "D:\Godot"
)

$ErrorActionPreference = "Stop"
$exe = Get-ChildItem -Path $GodotDir -Filter "*console*.exe" -File -ErrorAction SilentlyContinue |
	Sort-Object Name | Select-Object -First 1
if (-not $exe) {
	$exe = Get-ChildItem -Path $GodotDir -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
		Sort-Object Name | Select-Object -First 1
}
if (-not $exe) {
	Write-Error "No Godot executable found in $GodotDir (expected *console*.exe or Godot*.exe)."
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Write-Host "Using: $($exe.FullName)"
& $exe.FullName --headless --path $ProjectRoot -s "res://tests/test_harness.gd"
exit $LASTEXITCODE
