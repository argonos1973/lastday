# Project verification

- Local Godot executable: `work/godot4.7/Godot.app/Contents/MacOS/Godot` (Godot 4.7).
- Parse check: `work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/Main.gd`. Read the output: this executable can exit with status 0 even when it reports a script parse error.
- Run isolated SceneTree regression scripts using `--headless --path . --script /absolute/path/to/test.gd`; use a nonzero exit code on failed assertions. Override world initialization and saving in test doubles to avoid generating the full map or writing player saves.
- Export macOS with `work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS"`. The output is `build/macos/LastDay.app`; do not delete the existing app before exporting.
- Main owns the live HUD reference (`hud`). It creates the CanvasLayer dynamically without naming it `HUD`; UI shortcuts should use that reference rather than a hard-coded node path.
- After externally reexporting GLB assets, run Godot with `--headless --path . --import` before testing; running a script alone can load stale imported scenes.
- Rowboat regression: `work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/RowboatRegression.gd`. For a moving-water-effects capture, omit `--headless` and append `-- --preview`; it saves `/tmp/lastday_rowboat_preview.png` without generating the map or saving player data.
- Forest regression: `work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/ForestRegression.gd`. For a visual capture, omit `--headless` and append `-- --preview`; it saves `/tmp/lastday_forest_preview.png` without generating the full map.
