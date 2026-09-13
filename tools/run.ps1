param(
    [string]$GodotBin = "",
    [ValidateSet("demo", "import", "capture", "test", "ui-test", "mesh-test", "metro-test", "examples-test", "picker-test", "lightning-test")]
    [string]$Mode = "demo",
    [string]$CapturePath = "res://artifacts/helios.png",
    [switch]$NoGI,
    [switch]$NoBounce,
    [ValidateSet("auto", "picker", "hall", "lab", "metro", "cornell", "occlusion")][string]$Scene = "auto",
    [switch]$HighDetail,
    [switch]$LowDetail,
    [int]$Frames = 600,
    [int]$UpdateEvery = 1,
    [string]$BenchmarkPath = "res://artifacts/benchmark.json",
    [switch]$StaticCamera
)
$ErrorActionPreference = "Stop"
if ($Scene -eq 'auto') {
    $Scene = if ($Mode -eq 'demo') { 'picker' } else { 'hall' }
}
if ($Mode -eq 'capture' -and $Scene -in @('picker', 'cornell', 'occlusion')) {
    throw 'Use -Mode examples-test for picker/classic captures, or capture -Scene hall/lab/metro.'
}
if (-not $GodotBin) {
    if (Test-Path -LiteralPath "C:\Godot\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe") {
        $GodotBin = "C:\Godot\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
    } else {
        $GodotBin = (Get-Command godot -ErrorAction Stop).Source
    }
}
# Isolate tool-generated settings and logs from the user's editor profile.
$artifactPath = Join-Path $PSScriptRoot "..\artifacts"
New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null
$env:APPDATA = (Resolve-Path -LiteralPath $artifactPath).Path
$env:LOCALAPPDATA = $env:APPDATA
$launchArgs = @("--path", (Join-Path $PSScriptRoot ".."))
if ($Mode -eq "demo" -or $Mode -eq "capture") {
    $scenePath = "res://scenes/reactor_hall.tscn"
    if ($Scene -eq "lab") { $scenePath = "res://scenes/laboratory.tscn" }
    if ($Scene -eq "metro") { $scenePath = "res://scenes/metro_station.tscn" }
    if ($Scene -eq "picker") { $scenePath = "res://scenes/scene_picker.tscn" }
    if ($Scene -eq "cornell") { $scenePath = "res://scenes/cornell_box.tscn" }
    if ($Scene -eq "occlusion") { $scenePath = "res://scenes/occlusion_study.tscn" }
    $launchArgs += @($scenePath)
}
switch ($Mode) {
    "picker-test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--quit-after", "1800", "--script", "res://tests/test_picker_launch.gd")
    }
    "lightning-test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--quit-after", "1800", "--script", "res://tests/test_lightning.gd")
    }
    "import" { $launchArgs += @("--headless", "--editor", "--import", "--quit") }
    "demo" { $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan") }
    "capture" {
		$launchArgs += @("--quit-after", [string]([Math]::Max($Frames + 240, 600)))
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--", "--capture=$CapturePath")
        $launchArgs += @("--frames=$Frames", "--update-every=$UpdateEvery",
            "--benchmark=$BenchmarkPath")
        if ($HighDetail) { $launchArgs += "--high-detail" }
        if ($LowDetail) { $launchArgs += "--low-detail" }
        if ($StaticCamera) { $launchArgs += "--static-camera" }
        if ($NoGI) { $launchArgs += "--no-gi" }
        if ($NoBounce) { $launchArgs += "--no-bounce" }
    }
    "test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--script", "res://tests/test_gpu.gd")
    }
    "ui-test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--script", "res://tests/test_demo.gd")
    }
    "mesh-test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--script", "res://tests/test_mesh.gd")
    }
    "examples-test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--script", "res://tests/test_examples.gd")
    }
    "metro-test" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--script", "res://tests/test_metro.gd")
    }
}
& $GodotBin @launchArgs
exit $LASTEXITCODE
