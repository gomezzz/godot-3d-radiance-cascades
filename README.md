# Radiance Cascades / Light Laboratory

A runnable **3D world-space radiance cascades prototype for Godot**, implemented in GDScript and Vulkan compute shaders. The scene is lit by emissive geometry and an optional environment term. There are no Godot lights, baked lightmaps, SDFGI, or screen-space GI.

Open `project.godot` in **Godot 4.7** and press **F5**. Forward+ and a compute-capable GPU are required for the tested configuration. Godot 4.6 should expose the APIs used here, but has not been validated. Compatibility/WebGL is unsupported.

## Explore

- Right mouse drag: orbit. Wheel: zoom. R: reset camera. Space: animate/pause the cyan emitter. Escape: quit.
- Adjust emitter power, diffuse bounce feedback, and occluder position in the sidebar.
- Freeze the field to inspect the last solution. Camera movement does not invalidate it: the probes live in world space.
- Switch between lit surfaces, irradiance, and albedo; show the interior portion of the finest probe grid.
- Turn radiance lighting off to see emissive surfaces alone. This toggle affects surface shading; it deliberately leaves the solver running for comparisons.

The scene is authored in `scenes/laboratory.tscn`, including geometry, radiance, albedo, camera, and environment. The organization, inspectable controls, capture workflow, and format/lint/test gate take inspiration from `C:\Code\godot\godot-starter`. The unrelated game, audio, and narrative systems are not dependencies.

## What is implemented

Five volumetric probe grids store RGB radiance and scalar transmittance. Probe spacing doubles at each level while directional samples quadruple. Adjacent distance intervals are traced analytically against transformed boxes and spheres. Coarse results are trilinearly sampled and merged into finer intervals with `L = L_near + T_near * L_far` and `T = T_near * T_far`.

Each angular parent averages four children **after** visibility/radiance merging. A resolve pass integrates the finest level into six directional diffuse lobes. Godot spatial materials sample that atlas with trilinear spatial interpolation and an ambient-cube normal reconstruction. A previous-frame atlas supplies optional diffuse bounce feedback and temporal smoothing. All production compute resources stay on the GPU through `Texture2DRD`; readback is used only by tests and captures.

See [architecture and references](docs/implementation.md) for the layout, approximation choices, and extension points.

## Reuse in a Godot scene

1. Copy `addons/radiance_cascades/` into a Forward+ project and let Godot import the scripts. This is a runtime module; no editor plugin needs enabling.
2. Attach `rc_primitive.gd` to MeshInstance3D nodes using **BoxMesh** or spherical **SphereMesh** resources. Set `albedo` and `radiance`; radiance is linear HDR RGB. Transforms can translate, rotate, and scale, including nonuniformly scaled spheres.
3. Add a Node with `radiance_cascades.gd`. Assign its `geometry_root` to the parent containing those primitives. Its material overrides implement the diffuse RC shading.
4. Keep the scene in the current probe volume: origin `(-6, 0, -6)`, extent `(12, 8, 12)`, finest spacing `0.5`. Primitive registration happens at startup; runtime transform, mesh, and color changes are uploaded every update. Recreate the controller after adding/removing nodes. Hide/show is not currently an exclusion mechanism for the tracer.
5. When exporting, include `*.glslinc` in the export preset's **non-resource file filter**. These text sources are compiled at runtime, intentionally bypassing Godot's standalone GLSL importer.

This does **not** automatically illuminate ordinary StandardMaterial3D objects or voxelize imported meshes. It replaces materials on registered RCPrimitive nodes. Save any materials you want to restore before attaching the controller. Only one controller should own a given geometry root.

## Validation

On this Windows workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_changes.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run.ps1 -Mode capture
```

Pass `-GodotBin C:\path\to\godot.exe` to either tool for another installation. The local test gate requires Python with `gdtoolkit` (`python -m pip install gdtoolkit`). It checks formatting, lint, import, numerical GPU integration, and live input/UI behavior. Temporary editor profiles, test logs, and captures go to ignored `artifacts/`.

For other platforms, run the equivalent commands from the project root:

```text
gdformat --check addons/radiance_cascades scripts tests
gdlint addons/radiance_cascades scripts tests
godot --headless --editor --import --quit
godot --rendering-method forward_plus --rendering-driver vulkan --script tests/test_gpu.gd
godot --rendering-method forward_plus --rendering-driver vulkan --script tests/test_demo.gd
godot --rendering-method forward_plus --rendering-driver vulkan -- --capture=res://artifacts/laboratory.png
```

GPU tests must use a real rendering device; `--headless` is for import only. See [verification results](docs/validation.md). Linux/macOS, other GPU vendors, and exported executables are not yet tested.

## Current limits

This is a bounded research/demo implementation, not a replacement for Godot's general-purpose GI renderer. It uses at most 64 analytic primitives and has no acceleration structure. Fixed probe spacing, finite direction bins, a 0.3-unit surface bias, and ambient-cube reconstruction can blur contact shadows and leak light across thin geometry. Very small emitters can be missed. Temporal feedback can lag moving geometry. Specular reflections, transparency, mesh voxelization, adaptive/sparse grids, and multivolume streaming are future work.

The starting reference is [Alexander Sannikov's Radiance Cascades paper](https://github.com/Raikiri/RadianceCascadesPaper); [tmpvar's 3D grid experiment](https://github.com/tmpvar/radiance-cascades-3d-grid) provides a useful independent world-space implementation reference. This project is an original implementation of the concepts, not a port of either repository.
