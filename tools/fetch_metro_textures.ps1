$ErrorActionPreference = "Stop"
# Download only the explicitly selected CC0 maps and verify the publisher's hashes.
$destination = Join-Path $PSScriptRoot "../assets/textures"
foreach ($asset in @("large_floor_tiles_02", "long_white_tiles", "concrete_wall_006", "metal_plate", "rusty_painted_metal", "rubber_tiles", "blue_metal_plate")) {
    $resolution = if ($asset -in @('large_floor_tiles_02', 'long_white_tiles')) { '4k' } else { '2k' }
    $manifest = Invoke-RestMethod "https://api.polyhaven.com/files/$asset"
    $folder = Join-Path $destination $asset
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    foreach ($map in @("Diffuse", "nor_gl", "Rough", "Displacement")) {
        $entry = $manifest.$map.$resolution.jpg
        if (-not $entry.url -or -not $entry.md5) { throw "Missing $resolution JPG $asset/$map" }
        $target = Join-Path $folder "$map.jpg"
        $matches = (Test-Path -LiteralPath $target) -and ((Get-FileHash -LiteralPath $target -Algorithm MD5).Hash.ToLowerInvariant() -eq $entry.md5)
        if (-not $matches) {
            $temporary = "$target.download"
            Invoke-WebRequest -UseBasicParsing $entry.url -OutFile $temporary
            if ((Get-FileHash -LiteralPath $temporary -Algorithm MD5).Hash.ToLowerInvariant() -ne $entry.md5) {
                throw "Downloaded texture checksum mismatch: $temporary"
            }
            Move-Item -LiteralPath $temporary -Destination $target -Force
        }
        if ((Get-FileHash -LiteralPath $target -Algorithm MD5).Hash.ToLowerInvariant() -ne $entry.md5) {
            throw "Texture checksum mismatch: $target"
        }
        Write-Host "Verified $asset/$map"
    }
}
