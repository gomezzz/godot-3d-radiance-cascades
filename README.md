# HELIOS — 3D Radiance Cascades for Godot

A GPU global-illumination experiment with **arbitrary triangle mesh support** and a dramatic **1920 × 1080 reactor hall**. Five world-space radiance cascades light the scene from emissive geometry, with diffuse bounce feedback, moving emitters, and a cinematic camera.

![HELIOS reactor hall rendered at 1920 × 1080](docs/images/helios.png)

**Yes, this uses GPU shaders.** Vulkan compute shaders trace rays through a triangle BVH, merge cascades, and resolve diffuse lighting. Godot spatial shaders sample the result. The CPU builds the static BVH and uploads moving analytic objects; it does not calculate the lighting. No hardware ray-tracing extension, native module, Blender installation, or baked lightmap is required.

## Run

Open `project.godot` in **Godot 4.7**, select **Forward+**, and press **F5**. The default scene is HELIOS at native Full HD with 2× MSAA. The original small laboratory is retained at `scenes/laboratory.tscn`.

On Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1 -Scene lab
```

Pass `-GodotBin C:\path\to\godot.exe` for another installation. On other platforms, use `godot --path .` with a compute-capable Vulkan renderer. Compatibility/WebGL is unsupported. Only the Windows/NVIDIA configuration below has been tested.

## The scene

HELIOS contains **535 structural assemblies and 72,012 static triangles**, batched into six material surfaces. Curved ribs, toroidal reactor cages, cooling pipes, machinery banks, galleries, railings, and stairs all participate in GPU ray traversal. Three orbiting emissive spheres provide dynamic illumination. The scene is generated deterministically by `scripts/reactor_geometry.gd`; it is actual mesh geometry, not a screen-space backdrop.

| Control | Action |
| --- | --- |
| RMB drag | Look around; stop the camera tour |
| Hold RMB + WASD / Q / E | Fly forward, sideways, down, and up |
| Wheel | Change orbit-camera distance |
| C | Toggle cinematic camera |
| Space | Pause/resume emitter motion |
| G | Toggle the GI contribution on surfaces |
| 1 / 2 / 3 | Lit materials / irradiance / albedo |
| F | Freeze/resume the radiance field |
| H | Hide/show the HUD |
| R | Reset camera |
| Escape | Quit |

Camera movement does not invalidate the lighting field. G changes surface shading while the solver continues running; F stops solver updates.

## Measured performance

Godot **4.7.stable**, Vulkan, **RTX 4060 Ti**, Windows, native **1920 × 1080**, 2× MSAA, moving camera/emitters, GI updated every frame:

| Scene | Triangles | Average FPS | Median frame | 95th-percentile frame |
| --- | ---: | ---: | ---: | ---: |
| HELIOS, default high detail | 72,012 | **161.3** | 6.24 ms | 7.69 ms |

Measured over 1,200 frames after 120 warm-up frames. VSync remained enabled on a 165 Hz display, so this is substantially display-capped, **not an uncapped GPU throughput benchmark**. The CPU BVH build took about 1.22 seconds once at startup. These results do not predict other GPUs or arbitrary scenes.

The earlier median-split BVH reached approximately 52 FPS at this detail level. Binned surface-area splitting greatly reduces overlap from the hall's long floors and rails. GPU ray results were checked against independent CPU triangle intersections after the optimization. See [verification details](docs/validation.md).

Why the approach helps here: radiance is traced into a bounded world-space field and reused across screen pixels. Adding emissive surfaces does not create a separate shadow map or a full lighting pass per light. A BVH skips groups of triangles, while mesh batching reduces draw calls. This does not make tracing cost independent of scene complexity.

## Use your own meshes

1. Copy `addons/radiance_cascades/` into a Forward+ project.
2. Put your static MeshInstance3D nodes beneath a common Node3D. Imported glTF/GLB ArrayMesh resources and indexed/non-indexed triangle surfaces are supported, including multiple surfaces and transformed instances.
3. Add a Node with `radiance_cascades.gd`, and assign its `geometry_root`. No editor-plugin activation is needed.
4. Set `volume_origin` and `probe_spacing` **before the controller enters the tree**. The grid is 24 × 16 × 24; extent is grid × spacing. HELIOS uses origin `(-12,0,-12)`, spacing `1`, extent `(24,16,24)`.
5. Use BaseMaterial3D surface albedo and emission factors. The controller installs RC shader materials and restores original overrides when removed. A glTF import/export round trip is covered by tests.
6. After changing static mesh geometry, transforms, or topology, call `rebuild_geometry()`. It rebuilds the CPU BVH, recreates GPU resources, and resets lighting history. Wait for `initialized` before relying on the new field. This explicit operation can stall; it is not intended for per-frame deformation.
7. For inexpensive moving boxes/spheres, attach `rc_primitive.gd` and use its `albedo` / linear-HDR `radiance` properties. Up to 64 analytic objects update without rebuilding the static triangle BVH.

**Material scope:** per-surface constant albedo and emission factors. Texture maps, normal maps, alpha masks, skinning, blend shapes, and custom source shaders are not implemented in transport. Mesh triangles are opaque and traced from both sides. Do not treat this as a drop-in implementation of every StandardMaterial3D feature.

The controller owns material overrides while installed. Keep mesh geometry within the volume; lighting outside it clamps to boundary probes. Include `*.glslinc` in the export preset's **non-resource file filter** because these shader sources are loaded as text and compiled at runtime. Executable export has not been validated.

## Architecture

```text
Static triangle meshes ── CPU surface-area BVH build ── GPU geometry buffers
Dynamic analytic objects ────────────────────────────────┘
                                                          │
                     cascade 4 → 3 → 2 → 1 → 0  (GPU)
                                                          │
Previous irradiance ── diffuse feedback ── six-lobe resolve
                                                          │
                                  Texture2DRD → spatial shaders
```

The production path performs no lighting readback and no CPU ray tracing. The atlas uses hardware bilinear filtering within each slice plus explicit interpolation between slices, reducing a diffuse gather from 48 point fetches to six filtered fetches. [Implementation notes](docs/implementation.md) document interval layout, memory, BVH format, and approximations.

## Tests and captures

Requires Python with `gdtoolkit` for the formatting/lint gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_changes.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1 -Mode capture -Frames 1200
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1 -Mode capture -LowDetail
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1 -Mode capture -NoGI
```

The gate covers formatting, lint, import, **22 numerical GPU checks**, **21 mesh/integration checks**, **14 live scene/input checks**, and a Full-HD hall capture. The mesh suite compares 512 small-scene rays and 64 full-hall rays against independent CPU intersections, checks BVH coverage, imports glTF, and verifies material restoration and explicit geometry rebuilding.

Generated captures, logs, and benchmark JSON go to ignored `artifacts/`. Use `-CapturePath` and `-BenchmarkPath` to keep multiple results. `-UpdateEvery 2` deliberately reduces GI update frequency; the published result uses **1**. GPU tests require a real rendering device; `--headless` is only used for import.

## Limitations and references

This remains a research implementation. The fixed grid, finite direction bins, ambient-cube reconstruction, and normal bias can soften contact shadows or leak light through thin structures. Small emitters can be missed. Temporal feedback can lag moving geometry. There is no specular transport, sparse streaming, skeletal animation, or hardware ray-tracing backend.

The starting reference is [Alexander Sannikov's Radiance Cascades manuscript](https://github.com/Raikiri/RadianceCascadesPaper). [tmpvar's 3D grid experiment](https://github.com/tmpvar/radiance-cascades-3d-grid) informed the world-space layout; [PBRT's BVH chapter](https://www.pbr-book.org/4ed/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies) informed the acceleration strategy. This is an original implementation, not a source-code port. Project organization and validation take inspiration from `godot-starter`.
