# Verification record

Tested on Windows, Godot **4.7.stable.official.5b4e0cb0f**, Vulkan 1.4.329, NVIDIA GeForce RTX 4060 Ti.

- Production compute shaders compiled and executed on the GPU.
- **22 GPU checks passed**: contiguous intervals, constant-environment conservation at every output probe/lobe, zero-emission clearing, transmittance endpoints, directional response, linear emitter scaling, blocking/restoration, finite and bounded samples at all levels, transformed boxes and ellipsoids, and diffuse feedback growth/boundedness.
- Live scene/UI tests exercise pointer clicks, slider dragging, key input, camera orbit input, field freeze/resume, probe display, and material lighting toggles. Scene teardown is exercised with queued rendering work.
- GDScript formatting and lint are enforced with gdtoolkit; editor import checks class discovery and shader/material parsing. `tools/check_changes.ps1` requires explicit suite completion markers and rejects engine/script errors.
- Three 1280 × 800 captures were rendered: lit, GI contribution disabled, and bounce feedback disabled. The lit image was visually inspected for scene composition, lighting, controls, and clipping. Generated files are in `artifacts/`.

A 300-update static capture reported **164.1 average FPS after the first 30 updates**, near this machine's 165 Hz display cap. VSync was enabled; this is a short end-to-end demo observation, not an uncapped benchmark or isolated GPU timing. It does not characterize other GPUs or scene sizes.

For a fixed lower-room crop `(420,460)–(1050,700)`, mean display RGB was approximately `(39.42,42.14,44.73)` with bounce, `(37.37,40.60,43.36)` without bounce, and `(1.58,2.54,3.79)` with the GI contribution disabled. This confirms a visible response in non-emissive geometry; it is not a physically linear irradiance comparison because the screenshots are tone-mapped.

The managed Windows environment prints `ERROR: Failed to read the root certificate store.` during engine startup. No network access is needed by the running demo. The validation wrapper allows only this exact diagnostic; other `ERROR`, `SCRIPT ERROR`, and test failures fail the gate.

Not validated: release export, other platforms, other GPU vendors, Mobile renderer, large scenes, arbitrary meshes, physically accurate convergence, or absence of light leaks in every configuration.
