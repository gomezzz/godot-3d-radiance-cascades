param(
    [string]$GodotBin = "",
    [ValidateSet("demo", "import", "capture", "test", "ui-test", "mesh-test")]
    [string]$Mode = "demo",
    [string]$CapturePath = "res://artifacts/helios.png",
    [switch]$NoGI,
    [switch]$NoBounce,
    [ValidateSet("hall", "lab")][string]$Scene = "hall",
    [switch]$HighDetail,
    [switch]$LowDetail,
    [int]$Frames = 600,
    [int]$UpdateEvery = 1,
    [string]$BenchmarkPath = "res://artifacts/benchmark.json",
    [switch]$StaticCamera
)
$ErrorActionPreference = "Stop"
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
    $launchArgs += @($scenePath)
}
switch ($Mode) {
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
}
& $GodotBin @launchArgs
exit $LASTEXITCODE
