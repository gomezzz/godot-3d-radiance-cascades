# Original NORTHLINE parody commercials

`aer.ogv` and `rest.ogv` are original fictional advertisements authored for this project, not third-party footage. Each is 1920 x 1080, 24 fps, approximately 15 seconds, encoded as Ogg Theora by Godot 4.7's MovieWriter. The movies intentionally have no audible commercial soundtrack.

Source scenes, procedural geometry, camera animation and typography are in `tools/ad_movie`. Run `powershell -File tools/render_ad_movies.ps1` from the repository to regenerate both files. The renderer uses installed system fonts; typography can differ between machines.

The shipped application only decodes these two movies and shares the feeds across four panels. It does not render the advertising studio scenes in real time.
