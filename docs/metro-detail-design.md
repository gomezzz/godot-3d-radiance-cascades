# NORTHLINE detail pass

## Transit hardware refinement

Palette: smoked glass `#070d12`, aged amber `#e5aa55`, dusty white `#d3ddda`,
porcelain shell `#e0e8eb`, alarm red `#ed301b`. Wayfinding uses a low-resolution
monospace matrix, centered station identity and a left-moving service ticker;
advertisements retain their separate cinematic artwork. Layout: `[identity / route]`
over `[scrolling closure notice]`, behind dirty glass in scanned-metal housings.
This follows transit dot-matrix hardware rather than adding heavy noise across
the movies. Motion is confined to the service notice, subtle display noise and
the drone's small status beacon.

The display design uses transit hardware rather than floating graphics: recessed black glass, a metal case and wall brackets. Subtle scanned roughness breaks up highlights; display pixels fade below screen-space resolution instead of shimmering as moire. Station identity and wayfinding remain quiet, separate from advertisements.

Design tokens: transit black `#070d12`, glass white `#d3ddda`, exit green `#087746`, oxygen blue `#bad9ed`, oxygen ink `#173856`, sleep-provider purple `#3b294d`. Bahnschrift is the preferred industrial sans with Arial as the platform font alternative. Large left-aligned slogans occupy the left half; a moving product occupies the right; genuine advertising conditions occupy the footer.

Four 4.6 x 2.59 m displays, two per platform, share two 1920 x 1080 24 fps Theora movies. The brief calls for commercial imagery inside a decaying horror station, so the advertisements deliberately do not reuse the station's green-black palette. "aer" sells oxygen by the breath; "RestAssured" finances a two-square-metre sleeping pod. Each original 15-second movie has three five-second shots: orbiting product photography, a camera push or corridor dolly, and a closing sales pitch. They are rendered offline from `tools/ad_movie`, not static illustrations with a shader overlay. Two decoders serve all four screens; pause stops playback and replay restarts both streams.

The train now has eight hollow carriages, 160 empty seats, grab rails, end doors, rubber floors and sixteen clinical white lights. Raster window openings expose the interior; 24 coarse analytical proxies handle exterior RC transport. Interior-only materials accept local direct diffuse light because their volume is deliberately occluded by the coarse exterior transport proxy. This is an explicit hybrid approximation, not fine interior RC tracing. Glass refraction is not implemented. Eight moving collision hulls keep walking separate from the passing car interiors.

Platform and tunnel emergency lightboxes use a running-person/door/arrow pictogram with text. The maintenance tunnels extend past both portals. The fire barrel is hollow geometry, scanned worn metal, glowing coals, a 32-step ray-marched volume and 20 GPU embers. Three-dimensional rising noise breaks up the flame silhouette from every viewing angle. One animated RC source illuminates nearby station surfaces; a local light supplies barrel illumination and specular highlights.

Four physical gutter grates anchor soft, rising FogVolumes. Global volumetric density is zero: density is added only around the vents and in a thin aerosol volume carried by the surveillance drone. The drone has scanned metal, ducted rotors, sensor LEDs, a moving gimbal and one shadowed spotlight. It follows a deterministic platform patrol, using the same pausable timeline as the train and fire. Its light scatters in native volumetrics and supplies station specular highlights; directional drone diffuse transport is not added to RC. The three wall mirrors share a QHD render target while puddles keep their lower-resolution view to contain the cost.

The 10-second moving intro and 2560 x 1440 fullscreen presentation remain. Space pauses the shared timeline, M mutes the entire soundscape, and C/R restart it. Hum is continuous, tunnel bangs are sparse and spatialized, and three generated announcements recur on a 96-second timeline. Train audio ducks during announcements. All assets are local after installation.
