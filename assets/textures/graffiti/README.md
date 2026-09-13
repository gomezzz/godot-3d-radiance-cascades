# Weathered graffiti atlas

`paint_atlas.png` is original generated artwork made with the built-in image
generation tool, not a scanned third-party asset. The transparent PNG is preserved.
Four tags are sampled directly in the station tile shader; normal maps, roughness
and RC illumination remain active. Paint does not change constant-albedo BVH
bounce transport. Mipmaps and anisotropic filtering reduce distant shimmer.

Generation prompt:

> Use case: photorealistic-natural. Asset type: game graffiti paint decal atlas,
> 1024x1024 square, genuinely transparent RGBA background. Generate four separate
> worn spray-painted graffiti tags arranged in four equal horizontal rows, each
> entirely inside its own quarter of the image with generous transparent margins.
> Top row broad angular interlocking illegible silver-grey letter tag with dark
> outline; second row faded rust-red hurried looping illegible marker tag; third
> row dirty off-white rough crossed strokes and abstract handstyle tag; bottom row
> faded grey-green angular illegible tag. Realistic spray overspray, broken paint,
> drips, rubbed-away patches, small transparent holes. Flat front-on paint ONLY,
> absolutely no wall, no tiles, no surface, no baked shadows, no lighting, no
> checkerboard background, no border, no logos or legible slogans. This is for a
> dark abandoned metro, not polished graphic design.

The returned atlas has uneven row spacing; shader sampling bounds follow the
actual artwork rather than assuming exact quarter divisions.
