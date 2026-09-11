# Verification record

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
