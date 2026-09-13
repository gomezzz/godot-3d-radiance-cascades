$ErrorActionPreference = 'Stop'
$sources = @(
    @('electric-hum', 'https://cdn.freesound.org/previews/740/740085_14631530-hq.mp3'),
    @('metal-bang', 'https://cdn.freesound.org/previews/435/435699_5487341-hq.mp3')
)
foreach ($source in $sources) {
    if (-not (Test-Path "artifacts/$($source[0]).mp3")) {
        Invoke-WebRequest -UseBasicParsing $source[1] -OutFile "artifacts/$($source[0]).mp3"
    }
}
# Crossfade identical spans for a seamless loop, retaining the recorded transformer.
ffmpeg -y -i artifacts/electric-hum.mp3 -i artifacts/electric-hum.mp3 -filter_complex '[0:a]atrim=start=1:end=9,asetpts=PTS-STARTPTS[a];[1:a]atrim=start=1:end=9,asetpts=PTS-STARTPTS[b];[a][b]acrossfade=d=1:c1=tri:c2=tri,asetpts=PTS-STARTPTS,atrim=start=7:end=14,asetpts=PTS-STARTPTS,highpass=f=45,lowpass=f=2200,alimiter=limit=0.7,volume=26dB' -ac 1 -ar 44100 assets/audio/electric_hum.wav
if ($LASTEXITCODE -ne 0) { throw 'Hum conversion failed' }
ffmpeg -y -i artifacts/metal-bang.mp3 -af 'asetrate=33075,aresample=44100,highpass=f=65,lowpass=f=3800,aecho=0.7:0.65:173|391|719:0.4|0.23|0.12,afade=t=out:st=1.3:d=0.5,alimiter=limit=0.7' -ac 1 -ar 44100 assets/audio/tunnel_bang.wav
if ($LASTEXITCODE -ne 0) { throw 'Bang conversion failed' }
