"""Kessel Reach — Proving Ground: the first playable map's terrain.

A 240 m dust basin enclosed by cliff walls, with impassable mesas, one
walkable plateau reached by two ramps, and low dune ripples. Heights come from
`height(x, y)` so gameplay tooling can reuse the same function later.
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
WALL = 10.0

# impassable mesas: centre x, y, radius x, y, height
MESAS = [
    (-22.0, 30.0, 16.0, 11.0, 7.0),
    (38.0, -8.0, 12.0, 18.0, 8.5),
    (-60.0, -34.0, 9.0, 9.0, 6.0),
    (10.0, -62.0, 14.0, 8.0, 6.5),
    (70.0, 62.0, 11.0, 13.0, 7.5),
    (-78.0, 58.0, 10.0, 14.0, 9.0),
    (86.0, -70.0, 8.0, 8.0, 5.5),
]
# walkable plateau and its ramps (start outside, end on top, half width)
PLATEAU = (-6.0, 78.0, 34.0, 20.0, 3.2)
RAMPS = [((-6.0, 40.0), (-6.0, 62.0), 12.0), ((44.0, 78.0), (22.0, 78.0), 11.0)]


def _smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fbm(x: float, y: float, scale: float, octaves: int = 4) -> float:
    return noise.fractal(Vector((x / scale, y / scale, 0.0)), 1.0, 2.0, octaves)


def _blob(x: float, y: float, cx: float, cy: float, rx: float, ry: float, edge: float) -> float:
    """1 inside a wobbly ellipse, falling to 0 over `edge` metres outside it."""
    wobble = 1.0 + 0.22 * _fbm(x + cx * 3.1, y - cy * 1.7, 9.0, 3)
    d = math.hypot((x - cx) / (rx * wobble), (y - cy) / (ry * wobble))
    metres_inside = (1.0 - d) * min(rx, ry)
    return _smooth(-edge, 0.0, metres_inside)


def height(x: float, y: float) -> float:
    h = 0.45 * _fbm(x, y, 46.0) + 0.10 * math.sin(0.55 * (x + 0.6 * y) + 2.0 * _fbm(x, y, 30.0, 2))
    for cx, cy, rx, ry, top in MESAS:
        mask = _blob(x, y, cx, cy, rx, ry, 3.0)
        h += mask * (top + 0.5 * _fbm(x, y, 7.0, 2))
    cx, cy, rx, ry, top = PLATEAU
    plateau = _blob(x, y, cx, cy, rx, ry, 2.5)
    for (ax, ay), (bx, by), half_width in RAMPS:
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy)
        t = ((x - ax) * dx + (y - ay) * dy) / (length * length)
        side = abs((x - ax) * dy - (y - ay) * dx) / length
        ramp = min(max(t, 0.0), 1.0) * _smooth(half_width, half_width - 3.0, side)
        if -0.05 <= t <= 1.3:
            plateau = max(plateau, ramp)
    h += plateau * top
    edge = SIZE / 2.0 - max(abs(x), abs(y))
    rim = _smooth(16.0 + 5.0 * _fbm(x, y, 18.0, 2), 4.0, edge)
    return h + rim * (WALL + 1.2 * _fbm(x, y, 9.0, 2))


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
    mesh = bpy.data.meshes.new("kessel_proving_ground")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(bpy.data.materials.get("fl_terrain") or bpy.data.materials.new("fl_terrain"))
    # "-col" makes Godot generate a static trimesh collider on import.
    obj = bpy.data.objects.new("kessel_proving_ground-col", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_rocks(seed: int = 11, attempts: int = 2600):
    """Decorative scree: flat-shaded stones at cliff feet, pebbles elsewhere.

    Kept under knee height on walkable ground so units never visibly clip.
    """
    rng = random.Random(seed)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    half = SIZE / 2.0 - 6.0
    for _ in range(attempts):
        x, y = rng.uniform(-half, half), rng.uniform(-half, half)
        z = height(x, y)
        slope = math.hypot(height(x + 1.0, y) - z, height(x, y + 1.0) - z)
        if 0.12 < slope < 0.9:
            radius = rng.uniform(0.35, 1.1)
        elif slope <= 0.12 and rng.random() < 0.10:
            radius = rng.uniform(0.12, 0.32)
        else:
            continue
        verts = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)["verts"]
        squash = Vector((rng.uniform(0.7, 1.3), rng.uniform(0.7, 1.3), rng.uniform(0.45, 0.8)))
        spin = Matrix.Rotation(rng.uniform(0.0, math.tau), 4, "Z")
        for v in verts:
            v.co = Vector((v.co.x * squash.x, v.co.y * squash.y, v.co.z * squash.z))
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.16
            v.co = spin @ v.co + Vector((x, y, z + radius * 0.15))
        u, v_coord = fl.swatch_uv("kessel_rock" if rng.random() < 0.7 else "kessel_rock_pale")
        for face in {f for v in verts for f in v.link_faces}:
            for loop in face.loops:
                loop[uv_layer].uv = (u, v_coord)
    mesh = bpy.data.meshes.new("kessel_rocks")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(bpy.data.materials.get(fl.ATLAS_MATERIAL)
                          or bpy.data.materials.new(fl.ATLAS_MATERIAL))
    obj = bpy.data.objects.new("kessel_rocks", mesh)
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
