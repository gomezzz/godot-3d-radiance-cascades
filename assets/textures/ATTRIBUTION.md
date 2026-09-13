# Metro material sources

Downloaded 2026-09-11/12 from Poly Haven's public asset API. The original JPG
Diffuse, OpenGL normal (`nor_gl`), Rough and Displacement maps are included, without pixel edits.
Godot's import settings generate mipmaps and GPU compression for real-time use.

| Asset | Artists | Used on |
| --- | --- | --- |
| [Large Floor Tiles 02](https://polyhaven.com/a/large_floor_tiles_02) | Rob Tuytel | Platforms |
| [Long White Tiles](https://polyhaven.com/a/long_white_tiles) | Sergej Majboroda (photography), Jenelle van Heerden (processing) | Pillar cladding and walls |
| [Concrete Wall 006](https://polyhaven.com/a/concrete_wall_006) | Charlotte Baglioni (photography), Dario Barresi (processing) | Concrete beams, ceiling, track bed |
| [Metal Plate](https://polyhaven.com/a/metal_plate) | Rob Tuytel | Utility steel, benches, display housings |
| [Blue Metal Plate](https://polyhaven.com/a/blue_metal_plate) | Rob Tuytel | Train sheet-metal body and doors |
| [Rusty Painted Metal](https://polyhaven.com/a/rusty_painted_metal) | Amal Kumar | Worn paint, cabinets and fire barrel |
| [Rubber Tiles](https://polyhaven.com/a/rubber_tiles) | Amal Kumar | Train floor, seats, rubber components |

Floor and white-tile maps are 4K; the other five sets are 2K. All seven assets are [CC0](https://polyhaven.com/license). See the
[CC0 1.0 deed](https://creativecommons.org/publicdomain/zero/1.0/).
The assets retain their original license independently of this project's code.
No Poly Haven logos or site screenshots are redistributed.

`tools/fetch_metro_textures.ps1` retrieves these exact asset IDs and checks the
downloaded bytes against the publisher's MD5 manifests. Maps are renamed locally
to `Diffuse.jpg`, `nor_gl.jpg`, `Rough.jpg`, and `Displacement.jpg`. Original architectural repeat widths are 3 m, 1.3 m,
and 2 m respectively; tint/roughness adjustments are shader parameters.
