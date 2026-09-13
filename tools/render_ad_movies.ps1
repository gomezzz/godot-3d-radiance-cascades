param([string]$GodotBin = 'godot')
$ErrorActionPreference = 'Stop'
$env:APPDATA = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../artifacts'))
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force assets/video | Out-Null
foreach ($campaign in @('aer', 'rest')) {
    $moviePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../assets/video/$campaign.ogv"))
    $movieArgs = @('--path', 'tools/ad_movie', '--write-movie', $moviePath, '--fixed-fps', '24', '--resolution', '1920x1080', '--position', '0,0', '--audio-driver', 'Dummy', '--', "--$campaign")
    & $GodotBin @movieArgs
    if ($LASTEXITCODE -ne 0) { throw "Movie render failed: $campaign" }
}
