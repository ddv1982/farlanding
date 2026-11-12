# Farlanding

A single-player 3D real-time strategy game about a survey expedition following
a trail of beacons across unknown planets. Built with Godot 4.7 and Blender.

![A Lander, a new Reactor, two Fabricators and a Hauler on Kessel Reach](docs/media/phase2-base.png)

## Run it

Open `game/` in Godot 4.7.2 and press Play, or:

```
godot --path game
```

## Work on it

| Read | For |
|---|---|
| `docs/PLAN.md` | Game design, architecture and the phased build plan |
| `docs/CONVENTIONS.md` | Code conventions |
| `docs/ART_STYLE.md` | Visual style and the scripted Blender pipeline |
| `docs/AUDIO_STYLE.md` | Sound identity and the synthesis pipeline |
| `docs/adr/` | Decisions that would be expensive to reverse |

Before pushing, run `tools/check.sh` (format, lint, import, script check,
tests, boot test). CI runs the same script.

Rebuild generated assets:

```
blender -b -P art/pipeline/build_all.py
uv run --python 3.12 --with numpy --with scipy audio_src/build.py
```
