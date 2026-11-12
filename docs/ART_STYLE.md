# Art style and pipeline

## Look

Stylised, readable, chunky. Units must be identifiable from the highest camera
zoom by silhouette and colour blocking alone.

- **Shape first.** Big primitive forms, bevelled edges, no small greebles. If a
  detail is invisible at 40 m camera height, leave it out.
- **Three reads per unit:** faction (hull colour), owner (team-colour panels,
  always present on the top surface), role (silhouette).
- **Light means function.** Emissive swatches are reserved for sensors, engines,
  doorways and weapons.
- **Concord Survey:** off-white ceramic, safety orange, graphite underframes,
  cyan lights. Rounded and friendly, like field equipment.
- **Halcyon Combine:** graphite hulls, olive and rust, acid-teal lights. Angular.
- **Custodians / Antecedent:** pale stone, brass, warm white glow. Geometric.

## How assets are made

Every model is a Python recipe run in Blender, so the art is reviewable,
diffable and rebuildable.

| Path | Purpose |
|---|---|
| `art/pipeline/fl.py` | Toolkit: parts, primitives, palette, export |
| `art/models/<faction>_<kind>_<name>.py` | One recipe per model |
| `art/terrain/<map>.py` | Heightfield terrain and scatter per map |
| `art/pipeline/build_all.py` | Rebuilds every model and the palette |
| `art/pipeline/build_icons.py` | Renders a HUD icon per model into `game/assets/icons/` |

Rebuild everything: `blender -b -P art/pipeline/build_all.py`.

### Texturing: one palette for the whole game

Models carry no textures of their own. Each face is painted with a named
**swatch** (`fl.SWATCHES`); on export its UVs collapse onto that swatch's cell
in a shared 8x8 atlas:

- `palette_albedo.png` — base colour
- `palette_surface.png` — roughness, metallic, emission, team-colour mask

One shader (`game/presentation/shaders/unit.gdshader`) and one material serve
every unit and building, with team colour and damage as per-instance values.
Add swatches only at the end of the table: order is the atlas layout.

Each vertex also carries its height above the model origin (vertex colour, red
channel). The shader uses it to ground units: darker near the contact point
and a tint of planet dust on the lower hull.

Terrain uses no painted textures either: `terrain.gdshader` derives colour from
slope, height and world-space noise, so any heightfield is shaded for free.

### Model conventions

- 1 unit = 1 metre; origin on the ground at the footprint centre.
- Recipes face -Y (Blender front view). Export turns units to the game's forward
  (-Z); buildings keep their door towards +Z, the side the default camera sees.
- Moving parts are separate objects with reserved names, animated in code by
  `UnitVisual`: `wheel_*`, `leg_*`, `turret`, `barrel`, `dish`.
- A `-col` suffix on an object name makes Godot generate a static collider.
- Materials are swapped on import by name (`fl_palette`, `fl_terrain`) in
  `game/presentation/import/model_post_import.gd`.
