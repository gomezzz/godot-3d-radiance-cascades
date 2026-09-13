param([Parameter(Mandatory=$true)][string]$SourcePath)
$ErrorActionPreference = 'Stop'
# Extract a single complete footfall so playback follows travelled distance.
ffmpeg -y -ss 0.42 -i $SourcePath -t 0.36 -af 'afade=t=in:d=0.008,afade=t=out:st=0.27:d=0.09,volume=5dB,alimiter=limit=0.8' -ac 1 -ar 44100 assets/audio/footstep.wav
if ($LASTEXITCODE -ne 0) { throw 'Orion footstep import failed' }
