# Work tracker

## Done

- [x] Read the source paper and inspect world-space implementation references.
- [x] Build a native Godot world-space cascade hierarchy and emissive test scene.
- [x] Add diffuse feedback, live controls, probe visualization, and capture tooling.
- [x] Validate production shaders numerically on a GPU and exercise live scene controls.
- [x] Document integration, representation choices, and known limitations.

## Next

- [ ] Add independent brute-force reference renders and quantify lighting error.
- [x] Add arbitrary-mesh BVH traversal, glTF validation, and a Full-HD complex scene.
- [ ] Improve thin-wall visibility and near-field surface reconstruction.
- [x] Add configurable volume origin/spacing and geometry detail presets.
- [ ] Add isolated GPU timestamp profiling.

## Someday

- [x] Add explicit geometry recollection/rebuild and original material restoration.
- [ ] Sparse or scrolling probe volumes and incremental dirty updates.
- [ ] Specular transport and additional directional parameterizations.
- [ ] Validate exports and additional GPU/platform combinations.
