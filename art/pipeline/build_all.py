"""Rebuild every model and the palette textures.

Headless:  blender -b -P art/pipeline/build_all.py
Live:      exec this file through the Blender MCP.
A recipe's file name is its asset name: <faction>_<kind>_<name>.py, exported to
game/assets/models/<faction>/.
"""

import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(os.path.dirname(HERE), "models")
for path in (HERE, MODELS):
    if path not in sys.path:
        sys.path.insert(0, path)

import fl  # noqa: E402

importlib.reload(fl)


def build_all() -> None:
    print("palette:", fl.write_palette_textures())
    for file_name in sorted(os.listdir(MODELS)):
        if not file_name.endswith(".py"):
            continue
        name = file_name[:-3]
        module = importlib.reload(importlib.import_module(name))
        fl.reset_scene()
        root = module.build()
        print("model:", fl.export(root, name.split("_")[0]))


build_all()
