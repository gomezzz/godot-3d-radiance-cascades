# Verification record

## Point lighting, sound remaster and diagnostic epilogue (2026-09-13)

The GPU suite now has 44 checks, including point-source indirect injection,
visibility blocking, intensity linearity and production-buffer debug atlas reads.
The occlusion study's native direct term and RC indirect term are independently
ablated in rendered tests; the stationary field converges without visible flicker.
The new example uses scanned concrete normal/roughness maps and a smooth sphere.
This hybrid scene is not evidence that RC alone provides pixel-sharp direct shadows.

Train source mean level rose from -24.9 to -16.5 dBFS; peak is -2.1 dBFS.
Craigsmith's CC0 0:27-1:20 electrical excerpt is 53 seconds after convolution;
mastered arc RMS is -14.8 dBFS. Tests run with Dummy audio, so final perceived
loudness and acoustic aesthetics still require listening on the target system.

After train contact, tests advance the 1.5 s fade, five-second black hold, then
15/8/8-second diagnostic shots without a countdown and an eight-second closing credit screen.
Four explanation lines fade in during the opening ten seconds and remain visible.
The tests also check hidden cursor state, the plain GitHub address and credit timing.
Embers now use 54-triangle folded flakes with an 18-edge torn perimeter and
per-instance GPU deformation; tests check vertex count, depth, cooling and drag.
Each camera pose and the real GPU texture RID
are checked, with captures at `artifacts/metro-debug-0.png` through `-2.png`.
The shaded/irradiance/albedo views accompany C0-C4 radiance/transmittance maps.
Only the existing seven-texture RID shutdown warning remains in the focused run.

Older sections below describe earlier revisions and their then-current timings.

## Hot core, drone failure and track traversal (2026-09-13)

The drone has paired asynchronous red/blue battery navigation beacons, a more
irregular bounded patrol and a proximity-triggered kinematic tumble. Its spherical
collision hull avoids corner penetration while the visible model rotates; the
outward kick clears the benches. Tests wait for physics ticks and assert it
settles above the platform, rather than accepting any downward position.

The orb traverses 32 metres of usable platform over 18 seconds before crossing
the rails. Its small HDR core and screen-reading heat shell render on the GPU;
a pixel ablation confirms the heat effect changes the image. Shorter 3–5 m arcs
retain geometry contacts with finer jagged segments. Track collision tests verify
the walker-only surface and a capsule sweep across both rail heads. Ray transport
continues to use the detailed geometry, not the walking assist collider.

Train gain is raised 12 dB before attenuation and uses the nearest carriage rather
than a point near the nose. A temporary master limiter caps digital peaks at -1 dB
and is removed with the scene. Playback uses the existing recording; the louder
speaker/headphone mix still needs user listening feedback. QHD core and crashed
drone captures were inspected. The pre-existing seven-texture shutdown warning
remains; test teardown now allows an audio mix block to finish in the fast picker.

## Deforming plasma and persistent blackout (2026-09-12)

The lightning now travels on the puddled platform (x = -5) before crossing to
the train. Vertex displacement supplies coherent bulges and a multi-frequency
size pulse; shading uses the deformed surface derivatives. Physics-frame rays
choose real geometry contacts and ribbon widths taper to zero at their tips.
Integration checks validate the platform position, sustained zero native-light
energy, disabled PBR/display emission, multiple collider-backed arc endpoints,
randomized ember angle bounds and the existing collision/fade/hold sequence.
The custom ember vertex shader consumes the particle angle and adds a second
tumble axis. QHD captures show varying flake orientations, the deformed core,
dark displays and orb reflections. The barrel remains lit during the event.

## Crossing event, ash flakes and reference-scene fixes (2026-09-12)

38 GPU checks cover both ordinary and visibility-aware cascade merging; 21 mesh,
14 UI, 72 metro and 11 picker/reference checks pass. Real B key input changes
bounce feedback and rendered pixels in both examples. Their fixed scenes remain
stable after convergence. Moving-light temporal aliasing is reduced by blending,
not eliminated by a reference-quality angular integration scheme.

The laboratory passes direct launch and actual picker-button scene transition.
Removed its redundant fullscreen/swapchain reset and deferred scene replacement
until the button signal completes. The reported original launch crash was not
reproduced under the isolated APPDATA test environment; this is launch hardening,
not a confirmed root-cause diagnosis of the user's crash.

The lightning integration test exercises opposite-platform triggering, actual
zero lamp energies during blackout, emissive RC proxy activation, train contact
through Godot physics, pause/mute after contact, full fade, a ten-second black
hold and return to the picker. QHD captures of the lightning and barrel flakes
were inspected. Ash is angular mesh geometry with particle drag, cooling colour
and heat-dependent emission. The audio was rebuilt by FFT convolution with a
synthetic hall impulse response; the final speaker mix has not been human-auditioned.

The existing seven-texture shutdown warning remains. No commit, push or repository
visibility change was performed.

## Picker, classic RC examples, flashlight and fog removal (2026-09-12)

The expanded gate passes 22 numerical GPU, 21 mesh, 14 UI, 72 metro and
7 picker/classic-example checks (**136 total**) plus formatting/lint and the
QHD hall render. The two small examples have no native lights: rendered ablation
checks show that both RC illumination and diffuse bounce feedback affect pixels.
The picker, Cornell box and occlusion scene captures were visually inspected.

Removed the fixed-colour gutter volumes: they integrated density but did not
evaluate incident light or a scattering phase function. Textured drains remain.
The flashlight is a native shadowed SpotLight3D with a 16-degree half-angle,
17-metre range and localized low-density native FogVolume. It uses Godot's light
scattering, not the RC field. Native fog temporal reprojection is disabled to
avoid temporal trails on flickering/moving spotlights; finite fog-grid artifacts
remain possible. F toggles it; metro GI freeze moved to B. Pixel tests verify
illumination changes, not a quantitative scattering reference solution.

Lamp dropouts use independently seeded integer hashes at two time scales rather
than the previous repeating 7.5-second sine timeline. A regression compares the
old cycle offset. Replay remains deterministic. The opening blur is a screen
mipmap filter driven from full blur to zero over 2.5 seconds, not physical lens DOF.

The existing seven-texture shutdown warning remains.

## Taller, thinner steam and graffiti (2026-09-12)

After resolving the full-disk interruption, validation completed: formatter and
linter passed; 22 GPU + 21 mesh + 14 UI + 71 metro checks (**128 total**) passed,
and the QHD hall capture completed. The existing seven-texture shutdown warning
remains; no new shader errors were reported.

Steam volumes are 3.5 metres high rather than 2.2, with density gain reduced from
1.15 to 0.72 and exponential height dilution plus a soft upper fade. Rendered
visibility and adjacent-frame stability checks pass. Native spotlight haze is
unchanged. Captures were visually inspected; this does not establish stability
at every possible moving-camera angle.

Four generated weathered paint styles blend into wall and selected pillar tile
materials, retaining normal/roughness detail and RC lighting. The atlas retains
transparency and now has mipmaps. Separate rendered ablation checks verify that
both wall and pillar graffiti affect pixels. The initial wall test camera was
blocked by an advertisement; it now targets an exposed wall section.
See `artifacts/graffiti-wall.png`, `graffiti-pillar.png`, and `steam-detail.png`.
Source artwork and the generation prompt are in `assets/textures/graffiti/`.

## Wider shots, stable gutter steam and metal drone (2026-09-12)

`tools/check_changes.ps1` completed with `=== SUCCESS ===`: formatter/linter,
22 GPU + 21 mesh + 14 UI + 68 metro checks (**125 total**), plus the hall capture.
The station now has 951 assemblies / 11,412 static triangles. Native QHD
fullscreen remains verified. No isolated metro performance benchmark was taken.

The intro holds three wide shots for five seconds each, then travels for nine
seconds, handing off at z=14 opposite the barrel at z=-14.4. Tests cover the
24-second handoff, faster 4.3 m/s walking, 6 m/s jump impulse, floor/wall collision,
and the supplied Orion footfall excerpt. Audio playback is tested with the dummy
driver; the new recording has not been human-auditioned in the final mix.

Gutter steam now uses deterministic 40-step depth-clipped ray marching instead
of native temporally reprojected fog. Visibility and adjacent-frame brightness
checks pass. This stationary-camera regression is not a guarantee against all
view-dependent transparency artifacts. The drone's spotlight haze still uses
native fog. Grates have scanned metal albedo, normal and roughness maps.

The metal wedge drone has a red visor and a one-shot reflection probe. Its full
patrol is sampled for conservative clearance from ceiling signs and beams.
Rendered intro, drone, steam and fire captures are under `artifacts/`.

Known shutdown warning: `7 RIDs of type "Texture" were leaked.` It persists even
when the reflection probe is freed before scene shutdown; its precise ownership
has not been established. The gate passes because this is a warning, not a
shader/runtime error. The existing sandbox certificate-store diagnostic remains.

## Walking / cinematic and hardware refinement (2026-09-12)

`tools/check_changes.ps1` completed with `=== SUCCESS ===`: formatter/linter,
22 GPU + 21 mesh + 14 UI + 64 metro checks (**121 total**), plus the hall capture.
The revised metro has 22 pillars, eight cars at 32 m/s, 37 analytic proxies and
11,556 static triangles. The train remains within the 64-object GPU allocation.

New checks exercise the real physics walker against floors, walls and pillars;
Space jump and landing; distance-triggered footsteps; the extra 40-second metallic
loop; P pause; three locked camera shots; a 15-second walking handoff; textured
dim luminaires; scrolling matrix displays; the drone beacon and far-end barrel.
Rendered steam contributes visible pixels and stays below the adjacent-frame
brightness-change threshold in the stationary-camera regression. This is not a
guarantee against every volumetric reprojection artifact at every camera angle.

VoiceForge doctor, generation, strict QA and installation completed for all three
Serena female-preset announcements with monotone instructions. QA reports zero
issues or drift flags, with generated durations 6.964 / 7.851 / 10.327 seconds.
The preset/direction changed; delivery and speaker mix are not human-auditioned.

Close-up captures: `artifacts/barrel-detail.png`, `security-detail.png`,
`steam-detail.png`, `intro-0.7.png`, `intro-2.7.png`, `intro-4.7.png`,
`intro-9.4.png`. The first camera and train-glance framing were adjusted after
inspection and the targeted metro suite rerun. Physics uses detailed static
station collision, a barrel cylinder and coarse moving train hulls; the player
cannot board through the visual window openings. There is no player-body mirror
model or train-impact damage system.

No isolated performance claim is made for this revision. A diagnostic inspection
found substantial concurrent GPU load, including other Godot sessions and another
game. Those user processes were left untouched. The current full-gate hall capture
measured only 22.87 FPS under that load, so older 139 FPS figures below are historical,
not a guarantee for this session or the extended train.

## Movies, volumetric effects and QHD mirrors (2026-09-12)

Full `tools/check_changes.ps1` gate completed with `=== SUCCESS ===`: formatter,
linter, 22 GPU, 21 mesh, 14 UI and 48 metro checks (**105 total**), plus the hall
capture. No shader/script errors; only the known certificate-store diagnostic
is excluded. Metro assertions include actual Theora decoding and rendered frame
differences, paused video, QHD mirror allocation, four native FogVolumes and
drone displacement with a shadowed spotlight. Fire, steam, drone and commercial
close-ups were inspected in `artifacts/barrel-detail.png`, `steam-detail.png`,
`security-detail.png`, `advert-a.png`, `advert-b.png` and `advert-in-station.png`.

The two original movies were rendered successfully as 361 frames each at
1920 x 1080 / 24 fps by Godot 4.7. They are approximately 15 seconds long.
No external commercial footage is required. Their studio source is included
in formatter/linter checks; the runtime suite exercises the shipped decoders.

Current native 2560 x 1440 fullscreen capture on RTX 4060 Ti: **139.05 mean FPS**,
**6.882 ms median / 8.680 ms p95**, over **2,400 measured frames** after warm-up,
including intro handoff, real video playback, localized volumetrics and full
QHD wall reflections. Raw output: `artifacts/metro-effects-long.json`; image:
`artifacts/metro-effects-long.png`. A separate 600-frame run measured 141.91 FPS.
These are current-run measurements, not a controlled comparison against the
older 29.81 FPS result below. The large discrepancy has not been causally
isolated; do not attribute it to this effects patch or guarantee it elsewhere.

Limitations: volumetric steam is coarse-grid fog, not a fluid simulation; drone
illumination contributes fog scattering and native specular, not directional
RC diffuse transport. Theora decoding uses CPU time and cannot seek arbitrarily.
Movies restart on cutscene replay. Thin detail and the drone remain raster-only.

## Expanded metro detail / soundscape (2026-09-12)

Native QHD 2560 x 1440 fullscreen, Godot 4.7 Vulkan, RTX 4060 Ti, 2x MSAA.
This revision adds four 1080p animated ad panels, ten escape signs, hollow train
interiors, six local white lights, 4K architectural textures, seven scanned PBR
sets, tunnel shells, GPU fire and the generated/downloaded soundscape.

The feature revision is materially heavier than the older 1080p scene.
An initial 2,400-frame capture measured 18.57 FPS; removing redundant SSR,
restricting parallax to architecture, reducing shadowed lamps, compressing and
mipmapping the new textures, restricting interior lights by layer and batching
train geometry improved a short 180-frame check to **29.81 FPS**, **33.77 ms
median / 45.78 ms p95**. Raw current smoke benchmark:
`artifacts/northline-batch.json`. This short capture is not a sustained benchmark;
**60+ FPS at native QHD is not achieved**. Do not reuse the old 161 FPS result
as a claim about the expanded scene. Output remains native, without upscaling.

Diagnostic cumulative ablations are in ignored `artifacts/perf_probe.gd` and
`artifacts/quality_probe.gd`; they are rough whole-frame timings, not isolated GPU
timestamps. No-GI/no-post cases are diagnostic only, not the shipped defaults.

VoiceForge generated and installed three original announcements with the Ryan
preset. Strict QA reports 3 lines, zero issues, no truncation/clipping/silence,
and no drift flags (`artifacts/metro-voice/qa.json`). Public recordings and
generation settings are documented in the asset attribution files. Speaker
playback and vocal delivery have not been human-auditioned.

The metro suite now contains 43 checks, including animated feed pixel changes,
native fullscreen output, loaded 4K mip chains, train seats/lights, visible lit
interior pixels, escape signs, sound timeline/mute/pause and GPU fire animation.
The older lab UI click helper now routes an atomic synthetic pointer gesture
through the viewport GUI, preventing OS mouse events between frames from
stealing a test click. It still exercises real control hit-testing/signals.

Final `tools/check_changes.ps1` completed with `=== SUCCESS ===`: formatter and
linter clean, 22 GPU + 21 mesh + 14 UI + 43 metro checks (**100 total**) passed,
followed by the hall render/capture smoke test. Close-up captures were inspected
for the advertisements, white train interior and barrel. Raw screenshots:
`artifacts/advert-in-station.png`, `artifacts/train-interior.png`,
`artifacts/barrel-detail.png`. The only excluded engine diagnostic is the known
sandbox certificate-store denial; no shader/script/render errors were accepted.

## QHD fullscreen update

The project now starts fullscreen on the primary display, with a 2560 x 1440
viewport and explicit HUD scaling. A live metro capture confirmed window size
2560 x 1440, render target 2560 x 1440, and Window.MODE_FULLSCREEN (3).
Raw verification: `artifacts/qhd-exact.json`. Previous 1080p performance numbers
below are historical and should not be read as QHD benchmarks.

## Horror / cutscene revision (2026-09-11)

Native 1920 x 1080, RTX 4060 Ti, Godot 4.7 Vulkan, 2x MSAA, five cascades updated
each frame, two live 768 x 432 reflection views, normal maps plus parallax,
flickering lights, 24 m/s train and scripted intro-to-flight handoff.
Over **2,400 measured frames after 120 warm-up frames**: **161.06 mean FPS**,
**6.105 ms median**, **7.257 ms p95**. VSync was enabled on the 165 Hz display.
The 14.9-second measured interval includes intro completion and another train cycle.
Raw results: `artifacts/horror-final.json`. The lit-vs-dark images are different
camera poses and are not a controlled photometric comparison.

32 metro checks cover the earlier material/proxy invariants plus height-map pixel
differences, twelve mipmapped maps, seven puddles/three mirrors, fourteen display
panels, loaded audio, mute/pause/trigger behavior, measured train displacement,
non-black reflected station pixels, recursion exclusion, moving intro camera,
skip/replay, automatic handoff and a real W key driving free flight without RMB.
The complete suite passed with `=== SUCCESS ===`: **89 checks** (22 GPU + 21 mesh + 14 UI + 32 metro).

Normal and height channel ablations both visibly alter the image; mirrors and
puddles were inspected in actual viewport captures. Train audio is a verified
eight-second mono PCM clip (352,800 samples, measured peak -6.2 dBFS). Playback
state and controls were tested with the dummy audio driver; speaker/headphone
mix quality was not auditioned. Sound source and editing details are credited.
The first capture found an audio playback reference surviving immediate engine
shutdown; the capture path now drains playback for five frames before quitting.

Preview: `docs/images/northline-horror.png`. The older bright-station measurements
below are retained as historical records, not claims about the new rendering path.

## NORTHLINE metro / PBR (2026-09-11)

Godot 4.7.stable, Vulkan, RTX 4060 Ti, Windows; native **1920 × 1080**, 2× MSAA,
SSR enabled, animated train/camera and two flickering lamps. Five GPU cascades
update every frame. The station has 33 pillars, 861 static assemblies, 10,332
static triangles and 7,701 BVH nodes, plus nine moving train proxies and twelve
analytic ceiling emitters. Detailed train raster geometry is additional to the
reported static triangle count.

The final run measured **4,800 frames after 120 warm-up frames**:
**163.11 average FPS**, **6.141 ms median**, **7.638 ms p95**. The measured interval
is about 29.43 seconds, longer than the train's 26.67-second loop. Static CPU BVH
construction took 168.288 ms. VSync was enabled on the 165 Hz display: this is a
display-capped observation, not uncapped throughput or a guarantee for other
hardware. Raw output is `artifacts/metro-final.json`; the final real viewport
capture is `docs/images/northline.png`.

The complete format/lint/import/GPU/mesh/UI/metro/capture gate passed with
`=== SUCCESS ===`: **75 checks** (22 GPU, 21 mesh, 14 earlier scene/input, 18 metro).
The metro suite checks native render dimensions, 33 pillars, 21 analytic objects,
PBR installation, nine 2K mipmapped textures, actual train movement, changed
proxy upload data, root alignment, unchanged static BVH, localized flicker,
steady-light opt-out, pause/tour keys, GI toggles and material restoration.
It also renders three channel-ablation comparisons against a frozen baseline:
albedo, normal and roughness each produce measurable pixel changes (mean absolute
RGB differences approximately 0.103, 0.0042 and 0.022 respectively). These checks
prove the maps are used, not that the BRDF or lighting is physically converged.

First visual inspection caught missing mipmaps and a foreground sign intruding
into the camera frame. Explicit mip chains/GPU texture compression and repositioned
signage resolved these. The final image was visually inspected. All nine downloaded
texture files matched Poly Haven's publisher-provided MD5 hashes.

Remaining approximations: constant material factors in bounce transport; analytic
train/window proxies rather than moving triangle traversal; opaque glass-like
panels; raster-only text/sign faces; screen-space reflections; coarse probe bias
and possible thin-wall leaks. No export, additional GPU vendor or platform testing
was added in this iteration.

## HELIOS / arbitrary meshes

Current tested configuration: Godot 4.7.stable, Vulkan, RTX 4060 Ti, Windows. Native render target **1920 × 1080**, 2× MSAA, five cascades recomputed every frame, animated emitters and camera. No rendering upscaler or reduced GI frame rate was used.

The final high-detail run included **72,012 triangles, 535 assemblies, and 46,095 BVH nodes**. Over 1,200 measured frames after 120 warm-up frames: **161.34 average FPS**, **6.24 ms median frame**, **7.69 ms p95 frame**. CPU BVH build: **1,220.664 ms**. VSync remained enabled on a 165 Hz display, so results approach the display cap. This is a short end-to-end observation, not isolated GPU timing or a performance guarantee.

Before binned surface-area splitting, a 900-frame high-detail run measured 52.23 FPS (median 19.045 ms, p95 21.646 ms). Its median-based hierarchy overlapped large architectural triangles inefficiently. The new hierarchy retains every triangle; leaf coverage and independent ray tests guard against accidental geometry omission. Camera paths are time-driven and the runs have different durations, so the comparison is illustrative rather than a precisely controlled speedup ratio.

Current validation includes:

- 22 original GPU checks for interval, energy, transmittance, analytic geometry, and bounce invariants.
- 21 mesh/integration checks, including 512 GPU rays compared with independent CPU triangle intersections, 64 further rays against the full high-detail hall, indexed/non-indexed extraction, surface/material handling, BVH escape-link termination and exact leaf coverage, glTF serialization/import, mesh emission, material restoration, and explicit geometry rebuilding.
- Fourteen live scene/input checks for clicks, sliders, keyboard, camera movement, native Full-HD rendering, hall material controls, and freeze/resume.
- A native Full-HD hall capture as part of the final format/lint/import/test gate.

The README hero image is an actual 1920 × 1080 capture saved at `docs/images/helios.png`. Reproduction commands and remaining mesh/material limitations are in the README.

## Earlier laboratory baseline

Tested on Windows, Godot **4.7.stable.official.5b4e0cb0f**, Vulkan 1.4.329, NVIDIA GeForce RTX 4060 Ti.

- Production compute shaders compiled and executed on the GPU.
- **22 GPU checks passed**: contiguous intervals, constant-environment conservation at every output probe/lobe, zero-emission clearing, transmittance endpoints, directional response, linear emitter scaling, blocking/restoration, finite and bounded samples at all levels, transformed boxes and ellipsoids, and diffuse feedback growth/boundedness.
- Live scene/UI tests exercise pointer clicks, slider dragging, key input, camera orbit input, field freeze/resume, probe display, and material lighting toggles. Scene teardown is exercised with queued rendering work.
- GDScript formatting and lint are enforced with gdtoolkit; editor import checks class discovery and shader/material parsing. `tools/check_changes.ps1` requires explicit suite completion markers and rejects engine/script errors.
- Three 1280 × 800 captures were rendered: lit, GI contribution disabled, and bounce feedback disabled. The lit image was visually inspected for scene composition, lighting, controls, and clipping. Generated files are in `artifacts/`.

A 300-update static capture reported **164.1 average FPS after the first 30 updates**, near this machine's 165 Hz display cap. VSync was enabled; this is a short end-to-end demo observation, not an uncapped benchmark or isolated GPU timing. It does not characterize other GPUs or scene sizes.

For a fixed lower-room crop `(420,460)–(1050,700)`, mean display RGB was approximately `(39.42,42.14,44.73)` with bounce, `(37.37,40.60,43.36)` without bounce, and `(1.58,2.54,3.79)` with the GI contribution disabled. This confirms a visible response in non-emissive geometry; it is not a physically linear irradiance comparison because the screenshots are tone-mapped.

The managed Windows environment prints `ERROR: Failed to read the root certificate store.` during engine startup. No network access is needed by the running demo. The validation wrapper allows only this exact diagnostic; other `ERROR`, `SCRIPT ERROR`, and test failures fail the gate.

Still not validated: release export, other platforms, other GPU vendors, Mobile renderer, skinned/deforming geometry, physically accurate convergence, or absence of light leaks in every configuration. Arbitrary static triangle geometry and the larger HELIOS scene are now covered above.
