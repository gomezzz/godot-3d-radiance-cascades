$ErrorActionPreference = 'Stop'
# Layer the already credited CC0 impact into distant, non-rhythmic machinery.
ffmpeg -y -i assets/audio/tunnel_bang.wav -filter_complex '[0:a]asplit=3[a][b][c];[a]asetrate=17640,aresample=44100,lowpass=f=650,aecho=0.8:0.6:631|1237:0.5|0.3,apad=whole_dur=11,aloop=loop=-1:size=485100[a1];[b]asetrate=26460,aresample=44100,lowpass=f=900,adelay=4300,apad=whole_dur=17,aloop=loop=-1:size=749700[b1];[c]asetrate=22050,aresample=44100,lowpass=f=480,adelay=8200,apad=whole_dur=19,aloop=loop=-1:size=837900[c1];[a1][b1][c1]amix=inputs=3:normalize=0,atrim=duration=40,highpass=f=70,afade=t=in:d=2,afade=t=out:st=37:d=3,alimiter=limit=0.6' -ac 1 -ar 44100 assets/audio/metallic_ambience.wav
if ($LASTEXITCODE -ne 0) { throw 'Metal ambience render failed' }
# Footsteps now come from the user's Orion recording; keep its separate importer.
