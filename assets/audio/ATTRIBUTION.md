# Lightning event

Current source: [S21-07 Huge electrical arcs.wav](https://freesound.org/people/craigsmith/sounds/675755/)
by **craigsmith**, SSE Vintage Electricity collection; [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Licence verified from the sound page on 2026-09-13. Public HQ preview downloaded as
`huge_arcs_source.mp3`: https://cdn.freesound.org/previews/675/675755_2524442-hq.mp3 .
`lightning_arc.wav` uses exactly **0:27-1:20** (53 seconds), a 55 Hz high-pass,
offline FFT convolution, dynamic compression and -13 LUFS mastering target.
`lightning_impact.wav` combines a transient from this excerpt with original
synthetic bass/noise, the same convolution and a -12 LUFS target.
Both use -1.5 dBTP mastering ceilings; the master bus also limits the live mix.
Arc playback is positional at 0 dB with a 32 m reference distance.

The previous, now unused `electric_sparks_source.mp3` is retained with its credit:
[Electric Sparks.wav](https://freesound.org/people/kev_durr/sounds/396470/)
by **kev_durr**, June 29, 2017, CC0; downloaded 2026-09-12.
`lightning_station_ir.wav` is an original synthetic impulse response for a
35 x 21 x 4.8 m hall: distance/343 early reflections and a 2.8 s RT60 decay.
It is an artistic acoustic approximation, not measured station acoustics.
Rebuild with `python tools/build_lightning_audio.py` (NumPy, SciPy, FFmpeg).

# Train rush recording

Source: [Passing freight train](https://freesound.org/people/videog/sounds/149377/)
by **videog**, Freesound, published March 21, 2012.
License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

Downloaded the publicly accessible high-quality MP3 preview on 2026-09-11:
https://cdn.freesound.org/previews/149/149377_2688492-hq.mp3

`train_rush.wav` is an edited 8-second excerpt starting at 28 seconds, converted
to mono 44.1 kHz PCM16. Processing: 60 Hz high-pass, 9 kHz low-pass, loudness
compression at 4:1, -11 LUFS / -1.5 dBTP mastering target, 0.25-second fade-in
and 0.7-second fade-out. Rebuild with `tools/build_train_audio.ps1`.
The remaster measures -16.5 dBFS mean / -2.1 dBFS peak, versus -24.9 / -6.2
previously. The scene spatializes playback and provides an M mute toggle.
This is a real freight-train recording used as a dramatic metro sound effect,
not a recording of the fictional train model. The original source is CC0;
credit is retained for provenance. No Freesound account or runtime network
access is required.

## Station ambience (2026-09-12)

- `electric_hum.wav`: [electric hum 1](https://freesound.org/people/FOSSarts/sounds/740085/), **FOSSarts**, CC0. Doorbell transformer recorded with Zoom H1essentials. Public HQ MP3 preview: https://cdn.freesound.org/previews/740/740085_14631530-hq.mp3 . Edited into a seven-second crossfaded loop, mono 44.1 kHz, 45 Hz high-pass and 2.2 kHz low-pass. Kept quiet in-game and ducked under speech.
- `tunnel_bang.wav`: [metalbang0.wav](https://freesound.org/people/SamsterBirdies/sounds/435699/), **SamsterBirdies**, CC0. Public HQ preview: https://cdn.freesound.org/previews/435/435699_5487341-hq.mp3 . Slowed to 75%, band-limited and given short staggered echoes; positional playback alternates tunnel ends at irregular intervals.

`tools/fetch_metro_ambience.ps1` documents and reproduces these edits. Both source recordings remain CC0, independently of the code license.

The quiet transformer recording receives +26 dB source gain after filtering,
then -20 dB playback gain (-27 dB under speech). Final source mean/peak are
approximately -24.0/-8.8 dBFS; the bang source measures -26.6/-7.8 dBFS before
its -15 dB positional playback gain. This avoids an inaudibly quiet raw loop
without raising the mix to jump-scare volume.

## Archived public-address voice (unused)

These historical recordings are **not loaded or played by the current scene**.
The following provenance applies only to the retained files, not the current
soundtrack or closing-screen credits.

Three original announcement texts were regenerated locally using the user's **VoiceForge**, Qwen3-TTS 1.7B CustomVoice, the female **Serena** preset and explicit monotonous, evenly paced, detached delivery instructions. This replaces the previous Ryan voice. No real person's voice was cloned. Source cast and script: `assets/voice_source/`; reproduction: `tools/metro_voice.ps1 -Mode generate`. Model weights are Apache-2.0; see [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS).

VoiceForge strict QA: three lines, zero issues, no measured truncation/clipping/silence/drift. Generated lengths are approximately 6.96, 7.85 and 10.33 seconds, mono 24 kHz, installed as Vorbis and leveled together per character. The scene applies 330 Hz high-pass, 3.5 kHz low-pass and room reverb. "Persecuted" is deliberately retained from the requested fictional announcement.

Playback and timing are automated-test verified; vocal delivery and final speaker mix have not been human-auditioned.

## Additional foley

`metallic_ambience.wav` is a forty-second composition derived from the same CC0
SamsterBirdies impact credited above. Three differently slowed, low-pass-filtered
layers with staggered repetition, echoes and fade envelopes suggest distant
machinery behind the walls. It is not a newly downloaded recording or music track.

`footstep.wav` is extracted from a user-supplied Orion project recording,
`footsteps.mp3`. Pass its location with `-SourcePath` to the importer.
`tools/import_orion_footsteps.ps1` extracts 0.42–0.78 seconds, applies short fades,
gain and limiting, and writes mono 44.1 kHz WAV. Playback alternates pitch and
follows actual grounded travel distance, with a landing step. The original
recording was identified by the user as **[Footsteps, Concrete, A.wav](https://freesound.org/people/InspectorJ/sounds/336598/)**
by **InspectorJ ([www.jshaw.co.uk](https://www.jshaw.co.uk/))** of Freesound.org,
licensed **[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)**.
The supplied MP3 may already have been sped up (user report; not verified).
The extraction, fades, gain, limiting and runtime pitch variation are adaptations.
Retain this attribution and modification notice; this asset is not CC0 or MIT.
The supplied source file is unchanged.
`tools/build_metro_foley.ps1` reproduces only the metallic ambience using FFmpeg.
