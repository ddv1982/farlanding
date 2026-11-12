"""Render a HUD icon for every unit and building recipe.

Run in Blender (GUI or `blender -b -P art/pipeline/build_icons.py`). Writes
game/assets/icons/<asset name>.png: 128 px, transparent background, the same
three-quarter view for every model so icons read as one set.
"""

import importlib
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(os.path.dirname(HERE), "models")
for path in (HERE, MODELS):
    if path not in sys.path:
        sys.path.insert(0, path)

import fl  # noqa: E402

ICON_TEAM_COLOR = (0.10, 0.42, 0.95)
SIZE = 128


def _bounds(root):
    points = [obj.matrix_world @ Vector(corner)
              for obj in root.children_recursive if obj.type == "MESH"
              for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def render_icon(name: str) -> str:
    module = importlib.reload(importlib.import_module(name))
    fl.reset_scene()
    root = module.build()
    bpy.context.view_layer.update()
    for swatch in ("team", "team_glow"):
        material = fl.material(swatch)
        bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*(c ** 2.2 for c in ICON_TEAM_COLOR), 1.0)
    low, high = _bounds(root)
    centre = (low + high) / 2.0
    radius = (high - low).length / 2.0

    camera_data = bpy.data.cameras.new("icon_camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = radius * 2.1
    camera = bpy.data.objects.new("icon_camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    direction = Vector((-0.75, -1.0, 0.8)).normalized()
    camera.location = centre + direction * radius * 4.0
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()

    sun_data = bpy.data.lights.new("icon_sun", "SUN")
    sun_data.energy = 3.5
    sun = bpy.data.objects.new("icon_sun", sun_data)
    sun.rotation_euler = (math.radians(48), 0.0, math.radians(-40))
    bpy.context.scene.collection.objects.link(sun)

    scene = bpy.context.scene
    scene.camera = camera
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = scene.world or bpy.data.worlds.new("icon_world")
    scene.world = world
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.55, 0.60, 0.70, 1.0)
    background.inputs["Strength"].default_value = 0.9
    out_dir = os.path.join(fl.ASSETS, "icons")
    os.makedirs(out_dir, exist_ok=True)
    scene.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


def build_icons() -> None:
    for file_name in sorted(os.listdir(MODELS)):
        if file_name.endswith(".py"):
            print("icon:", render_icon(file_name[:-3]))
    fl.reset_scene()
    for swatch in ("team", "team_glow"):
        material = bpy.data.materials.get("sw_" + swatch)
        if material is not None:
            bpy.data.materials.remove(material)


build_icons()
