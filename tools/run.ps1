param(
    [string]$GodotBin = "",
    [ValidateSet("demo", "import", "capture", "test", "ui-test")]
    [string]$Mode = "demo",
    [string]$CapturePath = "res://artifacts/laboratory.png",
    [switch]$NoGI,
    [switch]$NoBounce
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
switch ($Mode) {
    "import" { $launchArgs += @("--headless", "--editor", "--import", "--quit") }
    "demo" { $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan") }
    "capture" {
        $launchArgs += @("--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
            "--audio-driver", "Dummy", "--", "--capture=$CapturePath")
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
}
& $GodotBin @launchArgs
exit $LASTEXITCODE
