"""Thalassa Low — Tidewater: tidal flats cut by channels the sea fills twice a mission.

A 240 m map of pale flats about half a metre above the low-water line. One deep
channel crosses it from the north-west to the south-east and never dries; a causeway
bridges it in the middle and two fords either side of that are passable only at low
tide. Shallow pans hold the rich deposits and flood with the fords. Both bases sit on
shoals well above the high-water line. A rocky reef rims the map.

Water levels (metres, the same numbers the tide rule uses):
    LOW_WATER  = -1.3   only the deep channel holds water
    HIGH_WATER =  0.15  fords and pans are under about 0.7 m
Heights come from `height(x, y)` (Blender x, y; Godot x, -z).
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

import fl

SIZE = 240.0
STEP = 1.5
WALL = 9.0
LOW_WATER = -1.3
HIGH_WATER = 0.15
FLATS = 0.65
DEEP = -2.4
FORD = -0.55
PAN = -0.5

# The deep channel's centre line (Blender x, y), north-west to south-east.
CHANNEL = [(-120.0, 34.0), (-78.0, 22.0), (-40.0, 30.0), (-6.0, 6.0), (30.0, -6.0),
           (62.0, -34.0), (88.0, -30.0), (120.0, -52.0)]
CHANNEL_HALF_WIDTH = 9.0
# Crossings: centre x, y, half length along the channel, floor height.
CAUSEWAY = (12.0, 0.0, 9.0, FLATS)
FORDS = [(-58.0, 25.0, 8.0, FORD), (74.0, -32.0, 8.0, FORD)]
# Tidal pans (rich ground that floods): centre x, y, radius x, y.
PANS = [(-30.0, -62.0, 17.0, 12.0), (36.0, 58.0, 16.0, 13.0), (-88.0, -8.0, 10.0, 13.0),
        (92.0, 12.0, 11.0, 12.0)]
# Shoals, always dry: centre x, y, radius x, y, height. The first two are the bases
# (Concord south-west, Combine north-east).
SHOALS = [(-80.0, -85.0, 26.0, 20.0, 2.2), (80.0, 80.0, 26.0, 20.0, 2.2),
          (-14.0, 70.0, 15.0, 11.0, 1.8), (20.0, -74.0, 15.0, 10.0, 1.8),
          (-70.0, 78.0, 12.0, 10.0, 1.6), (78.0, -84.0, 12.0, 9.0, 1.6)]
# Sea stacks, impassable: centre x, y, radius x, y, height.
STACKS = [(-34.0, 2.0, 7.0, 6.0, 7.0), (48.0, 22.0, 6.0, 8.0, 8.0), (-4.0, -36.0, 8.0, 6.0, 6.5),
          (-96.0, 50.0, 7.0, 7.0, 7.5), (100.0, 48.0, 6.0, 7.0, 6.0), (2.0, 40.0, 5.0, 6.0, 6.0)]


def _smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fbm(x: float, y: float, scale: float, octaves: int = 4) -> float:
    return noise.fractal(Vector((x / scale, y / scale, 0.0)), 1.0, 2.0, octaves)


def _blob(x: float, y: float, cx: float, cy: float, rx: float, ry: float, edge: float) -> float:
    wobble = 1.0 + 0.2 * _fbm(x + cx * 3.1, y - cy * 1.7, 9.0, 3)
    d = math.hypot((x - cx) / (rx * wobble), (y - cy) / (ry * wobble))
    return _smooth(-edge, 0.0, (1.0 - d) * min(rx, ry))


def _channel_distance(x: float, y: float) -> float:
    best = 1e9
    for (ax, ay), (bx, by) in zip(CHANNEL, CHANNEL[1:]):
        dx, dy = bx - ax, by - ay
        t = min(max(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0.0), 1.0)
        best = min(best, math.hypot(x - ax - t * dx, y - ay - t * dy))
    return best


def height(x: float, y: float) -> float:
    # Flats with long, low sand ripples.
    h = FLATS + 0.16 * _fbm(x, y, 40.0) + 0.05 * math.sin(0.5 * (x - 0.7 * y) + 2.0 * _fbm(x, y, 26.0, 2))
    for cx, cy, rx, ry in PANS:
        h = h + _blob(x, y, cx, cy, rx, ry, 5.0) * (PAN - FLATS)
    # The deep channel, its banks sloping over a few metres.
    width = CHANNEL_HALF_WIDTH * (1.0 + 0.18 * _fbm(x, y, 22.0, 2))
    channel = _smooth(width + 5.0, width - 2.0, _channel_distance(x, y))
    floor = DEEP
    for cx, cy, half, level in [CAUSEWAY] + FORDS:
        crossing = _smooth(half + 5.0, half - 1.0, math.hypot(x - cx, y - cy))
        floor = floor + crossing * (level - floor)
    h = h + channel * (floor - h)
    for cx, cy, rx, ry, top in SHOALS:
        mask = _blob(x, y, cx, cy, rx, ry, 9.0)
        h = max(h, h + mask * (top - h))
    for cx, cy, rx, ry, top in STACKS:
        h += _blob(x, y, cx, cy, rx, ry, 2.5) * (top + 0.6 * _fbm(x, y, 6.0, 2))
    edge = SIZE / 2.0 - max(abs(x), abs(y))
    rim = _smooth(15.0 + 5.0 * _fbm(x, y, 18.0, 2), 4.0, edge)
    return h + rim * (WALL - h + 1.2 * _fbm(x, y, 9.0, 2))


def build():
    fl.reset_scene()
    count = int(SIZE / STEP) + 1
    bm = bmesh.new()
    rows = []
    for j in range(count):
        y = -SIZE / 2.0 + j * STEP
        rows.append([bm.verts.new((-SIZE / 2.0 + i * STEP, y, height(-SIZE / 2.0 + i * STEP, y)))
                     for i in range(count)])
    for j in range(count - 1):
        for i in range(count - 1):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    mesh = bpy.data.meshes.new("thalassa_tidewater_ground")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(bpy.data.materials.get("fl_terrain_thalassa")
                          or bpy.data.materials.new("fl_terrain_thalassa"))
    # "-col" makes Godot generate a static trimesh collider on import.
    obj = bpy.data.objects.new("thalassa_tidewater_ground-col", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_rocks(seed: int = 23, attempts: int = 2600):
    """Decorative reef rock at the stacks' feet and along the banks, pebbles on the flats."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    half = SIZE / 2.0 - 6.0
    for _ in range(attempts):
        x, y = rng.uniform(-half, half), rng.uniform(-half, half)
        z = height(x, y)
        slope = math.hypot(height(x + 1.0, y) - z, height(x, y + 1.0) - z)
        if 0.14 < slope < 0.9:
            radius = rng.uniform(0.3, 1.0)
        elif slope <= 0.14 and z > 0.2 and rng.random() < 0.07:
            radius = rng.uniform(0.1, 0.28)
        else:
            continue
        verts = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)["verts"]
        squash = Vector((rng.uniform(0.7, 1.3), rng.uniform(0.7, 1.3), rng.uniform(0.4, 0.75)))
        spin = Matrix.Rotation(rng.uniform(0.0, math.tau), 4, "Z")
        for v in verts:
            v.co = Vector((v.co.x * squash.x, v.co.y * squash.y, v.co.z * squash.z))
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.16
            v.co = spin @ v.co + Vector((x, y, z + radius * 0.15))
        u, v_coord = fl.swatch_uv("stone_dark" if rng.random() < 0.7 else "gunmetal")
        for face in {f for v in verts for f in v.link_faces}:
            for loop in face.loops:
                loop[uv_layer].uv = (u, v_coord)
    mesh = bpy.data.meshes.new("thalassa_rocks")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(bpy.data.materials.get(fl.ATLAS_MATERIAL)
                          or bpy.data.materials.new(fl.ATLAS_MATERIAL))
    obj = bpy.data.objects.new("thalassa_rocks", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export(obj, extra=()) -> str:
    out_dir = os.path.join(fl.ASSETS, "models", "terrain")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, obj.data.name + ".glb")
    for other in bpy.context.scene.objects:
        other.select_set(other is obj or other in extra)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_yup=True, export_materials="EXPORT",
                              export_animations=False)
    return path
