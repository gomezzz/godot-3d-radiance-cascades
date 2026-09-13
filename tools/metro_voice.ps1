param([ValidateSet('doctor', 'generate')][string]$Mode = 'doctor')
$ErrorActionPreference = 'Stop'
# Public ungated weights must not inherit an unrelated expired login token.
$env:HF_HUB_DISABLE_IMPLICIT_TOKEN = '1'
# Run in a Conda-initialized PowerShell with VoiceForge installed in voiceforge.
Get-Command conda -ErrorAction Stop | Out-Null
conda activate voiceforge
voiceforge doctor
if ($LASTEXITCODE -ne 0) { throw 'VoiceForge doctor failed' }
if ($Mode -eq 'doctor') { exit 0 }
voiceforge cast assets/voice_source/cast.json -o artifacts/metro-voice
if ($LASTEXITCODE -ne 0) { throw 'VoiceForge cast failed' }
voiceforge gen assets/voice_source/script.json -c assets/voice_source/cast.json -o artifacts/metro-voice
if ($LASTEXITCODE -ne 0) { throw 'VoiceForge generation failed' }
voiceforge qa -o artifacts/metro-voice --strict
if ($LASTEXITCODE -ne 0) { throw 'VoiceForge QA failed' }
voiceforge install -o artifacts/metro-voice assets/audio/voice
if ($LASTEXITCODE -ne 0) { throw 'VoiceForge install failed' }
