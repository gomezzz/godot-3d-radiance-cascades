param([string]$GodotBin = "")
$ErrorActionPreference = "Stop"
$env:LOCALAPPDATA = Join-Path $PSScriptRoot "..\artifacts"
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
python -m gdtoolkit.formatter --check addons/radiance_cascades scripts tests
if ($LASTEXITCODE -ne 0) { throw "Formatting check failed" }
python -m gdtoolkit.linter addons/radiance_cascades scripts tests
if ($LASTEXITCODE -ne 0) { throw "Lint failed" }
foreach ($mode in @("import", "test", "mesh-test", "ui-test", "capture")) {
    $commandArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
        (Join-Path $PSScriptRoot "run.ps1"), "-Mode", $mode)
    if ($GodotBin) { $commandArgs += @("-GodotBin", $GodotBin) }
    if ($mode -eq "capture") {
        $commandArgs += @("-Frames", "180", "-CapturePath", "res://artifacts/check-hall.png")
    }
    $ErrorActionPreference = "Continue"
    $output = & powershell @commandArgs 2>&1
    $runExit = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    $logPath = Join-Path $PSScriptRoot "..\artifacts\check-$mode.log"
    $output | Out-File -LiteralPath $logPath -Encoding utf8
    $output | ForEach-Object { Write-Host $_ }
    if ($runExit -ne 0) { throw "$mode failed with exit code $runExit" }
    # The managed Windows sandbox denies certificate-store access. This exact
    # engine diagnostic is unrelated to shaders; all other errors fail the gate.
    $errors = $output | Select-String -Pattern "SCRIPT ERROR:|ERROR:|FAIL:"
    $unexpected = $errors | Where-Object {
        $_.Line -notmatch "^ERROR: Failed to read the root certificate store\.$"
    }
    if ($unexpected) { throw "$mode emitted errors; see $logPath" }
    if ($mode -eq "test" -and -not ($output -match "GPU_TESTS: 22 checks, 0 failures")) {
        throw "GPU test completion marker missing"
    }
    if ($mode -eq "ui-test" -and -not ($output -match "UI_TESTS: 0 failures")) {
        throw "UI test completion marker missing"
    }
    if ($mode -eq "mesh-test" -and -not ($output -match "MESH_TESTS: 21 checks, 0 failures")) {
        throw "Mesh test completion marker missing"
    }
    if ($mode -eq "capture" -and -not ($output -match "HALL_BENCHMARK")) {
        throw "Full-HD hall did not finish rendering"
    }
}
Write-Host "=== SUCCESS ==="
