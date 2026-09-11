# Implementation notes

## Mesh support and HELIOS (current implementation)

The runtime now accepts ordinary MeshInstance3D triangle geometry, including imported ArrayMesh resources and triangle-producing PrimitiveMesh resources. Indexed and non-indexed surfaces are expanded into world-space triangles. Translation, rotation, and nonuniform scaling are baked into the snapshot. Per-surface constant albedo is converted to linear space; emission factors are retained as linear radiance. The tracer handles triangles as opaque, two-sided surfaces. Skinning, blend shapes, and texture maps are outside the implemented transport model.

`rc_mesh_bvh.gd` builds an eight-bin surface-area hierarchy across all three centroid axes, using leaves of up to four triangles. Coincident centroids are partitioned by count to ensure termination. Nodes are flattened in preorder with escape links, permitting stackless GLSL traversal. A node contains lower/upper bounds and triangle-start/count/escape metadata in three vec4 fields (48 bytes). A triangle contains three world vertices, albedo, and emission in five vec4 fields (80 bytes). Metadata is stored as exactly representable integer-valued floats; this implementation targets scenes well below 2^24 nodes/triangles.

The high-detail HELIOS scene has 72,012 triangles and 46,095 BVH nodes: approximately 7.60 MiB of static tracing data in addition to the cascade/atlas allocations below. Geometry is also held by Godot for normal rasterization. All 535 assemblies are batched into six material surfaces. The three moving spheres remain analytic and do not rebuild the BVH.

`RadianceCascades.rebuild_geometry()` explicitly rebuilds geometry after static mesh changes. It waits for outstanding dispatch submission, restores original source materials, recollects surfaces, builds a new CPU snapshot, and recreates the GPU resources on the rendering thread. Completion emits `initialized`. It can stall and resets history. Mesh materials are restored on controller removal. This is suitable for edits/loading, not for per-frame deformation.

Both compute bounce lookup and surface shading now use six filtered fetches: hardware bilinear interpolation in x/y, with two explicitly blended z slices per normal axis. Clamping to cell centers keeps sampling inside the correct atlas lobe and slice. Coarse cascade storage still uses explicit eight-probe interpolation. Fully opaque near samples skip unnecessary far-field sampling.

The current `volume_origin` and `probe_spacing` are configurable before initialization. HELIOS uses origin (-12,0,-12) and spacing 1; multiply the interval distances in the table below by two. The laboratory retains spacing 0.5. Normal bias is 0.6 times spacing. Push constants are 112 bytes, including volume spacing/bias and mesh-node count.

Acceleration reference: [PBRT, Bounding Volume Hierarchies](https://www.pbr-book.org/4ed/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies). Engine mesh ingestion uses [ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html) and tests [GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html) binary round trips.

## Research basis

- [Alexander Sannikov, Radiance Cascades](https://github.com/Raikiri/RadianceCascadesPaper/blob/main/out_latexmk2/RadianceCascades.pdf), with the [LaTeX source](https://github.com/Raikiri/RadianceCascadesPaper/blob/main/RadianceCascades.tex) used to read the equations: adjacent radiance/transmittance intervals, spatial/angular scaling, and the full 3D construction. The author identifies this as a self-published manuscript using a JCGT template, not a JCGT publication. This prototype uses the interval algebra and volumetric hierarchy; it does not claim to implement every optimization in the paper.
- [tmpvar/radiance-cascades-3d-grid](https://github.com/tmpvar/radiance-cascades-3d-grid): C++/OpenGL dense-world-grid experiment. Its [notes on merging](https://github.com/tmpvar/radiance-cascades-3d-grid/blob/main/NOTES.md) highlight the importance of correctly locating fine probes relative to a coarse grid, especially near negative cell coordinates. Here positions are mapped into the upper grid with an explicit half-cell offset and boundary clamp. No source code was copied. The upstream README says the demo depends on an unreleased HotCart wrapper; it was reviewed as a reference, not executed locally.
- Godot's [compute shader tutorial](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html), [RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html), and [Texture2DRD](https://docs.godotengine.org/en/stable/classes/class_texture2drd.html) document the engine integration mechanisms.

## Data flow

```text
RCPrimitive transforms / albedo / emission
                  |
             scene SSBO
                  |
   cascade 4 -> 3 -> 2 -> 1 -> 0     (barrier between levels)
                  |
       six-lobe diffuse resolve <--- previous irradiance atlas
                  |                            ^
             output atlas ---------------------+ (GPU copy)
                  |
           Texture2DRD / surface shader
```

`rc_primitive.gd` packs one inverse affine matrix and three vec4 fields per object: 112 bytes. Rays retain a world-distance parameter when transformed into object space, including nonuniform scale. Box slabs explicitly handle parallel axes; spheres use the full quadratic coefficient `dot(d,d)`. Surface normals return through the inverse transpose. Starting inside a solid makes an interval opaque and black.

`rc_gpu.gd` owns allocations, shader compilation, uniform sets, push constants, dispatch, and teardown. Production calls run on the render thread using the main RenderingDevice. The controller keeps only one dispatch request pending and snapshots scene data before enqueueing it. Tests use the exact same class on an independent local RenderingDevice, with explicit submit/sync and readback.

## Cascade layout

Origin: `(-6, 0, -6)`. Base grid: `24 × 16 × 24`. For level i: spacing = `0.5 * 2^i`; angular grid = `(8 * 2^i) × (4 * 2^i)`; interval = `[0.75 * (2^i - 1), 0.75 * (2^(i+1) - 1)]`.

| Level | Probe grid | Spacing | Stored directions/probe | Interval | RGBA32F storage |
| --- | --- | --- | --- | --- | --- |
| 0 | 24 × 16 × 24 | 0.5 | 32 | 0–0.75 | 4.50 MiB |
| 1 | 12 × 8 × 12 | 1 | 128 | 0.75–2.25 | 2.25 MiB |
| 2 | 6 × 4 × 6 | 2 | 512 | 2.25–5.25 | 1.125 MiB |
| 3 | 3 × 2 × 3 | 4 | 2048 | 5.25–11.25 | 0.5625 MiB |
| 4 | 2 × 1 × 2 | 8 | 8192 | 11.25–23.25 | 0.50 MiB |

Rounded coarse dimensions make the final level depart from exact geometric halving. Total cascade storage is 8.9375 MiB. Two 144 × 384 RGBA16F irradiance atlases add 0.84375 MiB; object data adds 7 KiB. Driver resources and shader pipelines are additional. Each update evaluates 2,342,912 ray segments (four children per stored angular bin) against the primitive list.

Angular bins uniformly partition longitude and cosine of polar angle, giving equal solid angle and exact four-child area weights. This parameterization is anisotropic near the poles: it is a practical sampling choice, not an exact realization of uniform angular spacing everywhere on the sphere. The source paper permits different directional representations. A cubemap or equal-area hierarchical spherical tessellation would be a useful quality comparison.

## Merge and resolve

Each invocation traces four child directions across its own interval. It interpolates the corresponding child direction from eight upper-grid probes, then merges before averaging the children. This retains the correlation between near visibility and far illumination at those sampled directions. Samples store premultiplied radiance and transmittance; opaque surfaces terminate a segment. The outermost cascade uses constant environment radiance beyond the finite far interval.

The finest 32 stored direction bins are cosine-weighted into six axes. Each lobe normalizes by its discrete sum of cosine weights so constant incident radiance is reproduced exactly. The stored quantity approximates irradiance divided by pi. Final normals use squared-component ambient-cube blending. Spatial interpolation is mathematically trilinear, implemented with the six filtered fetches described above. This is a low-order diffuse reconstruction, not arbitrary BRDF reconstruction.

The material and bounce gather both offset surfaces by 0.3 world units to avoid probes embedded in the receiving surface. This reduces self-occlusion but is not a visibility-aware gather. Clamp sampling extends boundary probes, so all scene geometry should stay within the documented volume. Thin walls and small gaps can still leak.

## Bounce feedback

On a traced surface, outgoing radiance is `emission + linear_albedo * previous_diffuse * feedback`. The scalar feedback is a user-controlled damping factor, default 0.65. Then the resolve temporally blends the current result with the previous field, default 0.3. Several updates converge toward a damped diffuse solution. This is approximate multi-bounce feedback, with biased reconstruction and temporal lag; it is not an unbiased path tracer or a fixed exact bounce count.

GPU barriers separate the cascade dispatches. After resolve, a GPU texture copy supplies the next update's history. The production path does not call `submit`, `sync`, or read back the cascade field on the CPU. The output texture remains a stable RID for materials. All owned RIDs are freed in reverse dependency order during teardown.

## Extension points

1. Extend the current static triangle BVH with refitting or instance-level acceleration for moving meshes; preserve the radiance/transmittance contract and world-distance intervals.
2. Add probe visibility/distance moments or surface-point near-field tracing to improve wall separation and contact shadows.
3. Make angular basis, grid dimensions, and level count configurable together. Origin and base spacing are already configurable; other layout changes must update both GDScript and shader definitions.
4. Add dirty-scene invalidation, visibility registration, dynamic primitive lifetimes, and per-cascade scheduling before scaling scene size.
5. Compare against an independent brute-force diffuse reference on small scenes. Current tests establish useful invariants and regressions, not a quantified bound on approximation error.
