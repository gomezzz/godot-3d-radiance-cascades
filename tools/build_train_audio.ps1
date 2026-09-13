$ErrorActionPreference = 'Stop'
# CC0 source and exact excerpt are documented in assets/audio/ATTRIBUTION.md.
if (-not (Test-Path -LiteralPath 'artifacts/train-source.mp3')) {
    curl.exe -L --fail https://cdn.freesound.org/previews/149/149377_2688492-hq.mp3 -o artifacts/train-source.mp3
    if ($LASTEXITCODE -ne 0) { throw 'Train source download failed' }
}
ffmpeg -y -ss 28 -i artifacts/train-source.mp3 -t 8 -af 'highpass=f=60,lowpass=f=9000,acompressor=threshold=0.08:ratio=4:attack=3:release=180,loudnorm=I=-11:TP=-1.5:LRA=5,afade=t=in:d=0.25,afade=t=out:st=7.3:d=0.7' -ac 1 -ar 44100 assets/audio/train_rush.wav
if ($LASTEXITCODE -ne 0) { throw 'Train mastering failed' }
