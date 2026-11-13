"""Verdance — Understory: a mossy basin under the crowns of giant trees.

A 240 m map of soft green ground about half a metre up. Thirteen groves stand on it:
each is one or two giant trunks (impassable) holding a wide crown ten metres up. The
ground under a crown is walkable and hidden from the air and from far away: GROVES is
the gameplay data for that (the map's canopy zones), and the crown mesh is drawn from
the same list. Root ridges (impassable) split the basin into lanes; a shallow stream
winds across it and can be waded anywhere. Both bases sit on open shelves. A wall of
roots and rock closes the map.

The layout is point-symmetric about the centre.
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
WALL = 10.0
FLOOR = 0.5
STREAM_BED = -0.3

# Groves: centre x, y, radius x, y. The ground inside is under canopy.
_HALF_GROVES = [(-84.0, -30.0, 20.0, 16.0), (-70.0, 40.0, 18.0, 22.0), (-20.0, -70.0, 16.0, 14.0),
                (-30.0, 80.0, 20.0, 15.0), (-36.0, 10.0, 13.0, 12.0), (-96.0, 84.0, 14.0, 14.0)]
GROVES = ([(0.0, 0.0, 22.0, 18.0)] + _HALF_GROVES
          + [(-x, -y, rx, ry) for x, y, rx, ry in _HALF_GROVES])
CROWN_HEIGHT = 10.5
TRUNK_RADIUS = 2.4

# Root ridges, impassable: centre lines and half width.
_HALF_RIDGES = [[(-40.0, -112.0), (-47.0, -78.0), (-44.0, -52.0), (-33.0, -32.0)],
                [(-112.0, 8.0), (-92.0, 14.0), (-72.0, 10.0)]]
RIDGES = _HALF_RIDGES + [[(-x, -y) for x, y in line] for line in _HALF_RIDGES]
RIDGE_HALF_WIDTH = 3.2
RIDGE_HEIGHT = 5.0

# The stream: shallow, wadeable everywhere.
STREAM = [(-120.0, 56.0), (-92.0, 66.0), (-52.0, 58.0), (-30.0, 38.0), (-10.0, 30.0),
          (10.0, -30.0), (30.0, -38.0), (52.0, -58.0), (92.0, -66.0), (120.0, -56.0)]
STREAM_HALF_WIDTH = 3.0

# Open shelves, a little higher: centre x, y, radius x, y, height. The first two are
# the bases (Concord south-west, Combine north-east).
SHELVES = [(-80.0, -85.0, 26.0, 20.0, 1.3), (80.0, 80.0, 26.0, 20.0, 1.3),
           (-8.0, -38.0, 13.0, 10.0, 1.0), (8.0, 38.0, 13.0, 10.0, 1.0)]


def _smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fbm(x: float, y: float, scale: float, octaves: int = 4) -> float:
    return noise.fractal(Vector((x / scale, y / scale, 0.0)), 1.0, 2.0, octaves)


def _blob(x: float, y: float, cx: float, cy: float, rx: float, ry: float, edge: float) -> float:
    wobble = 1.0 + 0.2 * _fbm(x + cx * 3.1, y - cy * 1.7, 9.0, 3)
    d = math.hypot((x - cx) / (rx * wobble), (y - cy) / (ry * wobble))
    return _smooth(-edge, 0.0, (1.0 - d) * min(rx, ry))


def _line_distance(x: float, y: float, line) -> float:
    best = 1e9
    for (ax, ay), (bx, by) in zip(line, line[1:]):
        dx, dy = bx - ax, by - ay
        t = min(max(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0.0), 1.0)
        best = min(best, math.hypot(x - ax - t * dx, y - ay - t * dy))
    return best


def trunks():
    """Trunk centres (x, y): one per grove, two for the long ones."""
    out = []
    for cx, cy, rx, ry in GROVES:
        if max(rx, ry) >= 20.0:
            along = (rx * 0.42, 0.0) if rx >= ry else (0.0, ry * 0.42)
            out.append((cx - along[0], cy - along[1]))
            out.append((cx + along[0], cy + along[1]))
        else:
            out.append((cx, cy))
    return out


def height(x: float, y: float) -> float:
    # Moss floor: slow swells, with hummocks where roots run under it.
    h = FLOOR + 0.22 * _fbm(x, y, 40.0) + 0.07 * _fbm(x, y, 7.0, 2)
    for cx, cy, rx, ry, top in SHELVES:
        mask = _blob(x, y, cx, cy, rx, ry, 8.0)
        h = max(h, h + mask * (top - h))
    width = STREAM_HALF_WIDTH * (1.0 + 0.25 * _fbm(x, y, 16.0, 2))
    stream = _smooth(width + 3.0, width - 1.0, _line_distance(x, y, STREAM))
    h = h + stream * (STREAM_BED - h)
    # The ground rises a little to each trunk's foot (the trunks are their own mesh).
    for tx, ty in trunks():
        h += 0.9 * _smooth(TRUNK_RADIUS + 5.0, TRUNK_RADIUS, math.hypot(x - tx, y - ty))
    for line in RIDGES:
        width = RIDGE_HALF_WIDTH * (1.0 + 0.3 * _fbm(x, y, 11.0, 2))
        ridge = _smooth(width + 1.2, width - 1.6, _line_distance(x, y, line))
        h += ridge * (RIDGE_HEIGHT + 1.2 * _fbm(x, y, 5.0, 2))
    edge = SIZE / 2.0 - max(abs(x), abs(y))
    rim = _smooth(15.0 + 5.0 * _fbm(x, y, 18.0, 2), 4.0, edge)
    return h + rim * (WALL - h + 1.8 * _fbm(x, y, 8.0, 2))


def _atlas_material():
    return (bpy.data.materials.get(fl.ATLAS_MATERIAL)
            or bpy.data.materials.new(fl.ATLAS_MATERIAL))


def _paint(bm, uv_layer, verts, swatch: str) -> None:
    u, v_coord = fl.swatch_uv(swatch)
    for face in {f for v in verts for f in v.link_faces}:
        for loop in face.loops:
            loop[uv_layer].uv = (u, v_coord)


def _link(name: str, bm, material, smooth: bool = True):
    mesh = bpy.data.meshes.new(name.replace("-col", ""))
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


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
    material = (bpy.data.materials.get("fl_terrain_verdance")
                or bpy.data.materials.new("fl_terrain_verdance"))
    # "-col" makes Godot generate a static trimesh collider on import.
    return _link("verdance_basin_ground-col", bm, material)


def build_trunks(seed: int = 11):
    """The giant trunks: flared at the foot, forking under the crown. Colliders."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    for tx, ty in trunks():
        base = height(tx, ty) - 1.2
        top = CROWN_HEIGHT + 1.0
        rings = [(0.0, 1.4), (1.2, 1.12), (3.0, 1.0), (7.0, 0.92), (top - base, 0.8)]
        segments = 12
        spin = rng.uniform(0.0, math.tau)
        loops = []
        for z, scale in rings:
            ring = []
            for s in range(segments):
                angle = spin + math.tau * s / segments
                # buttress roots: every third segment stands out at the foot
                flare = 1.0 + (0.45 if s % 3 == 0 else 0.0) * max(0.0, 1.0 - z / 3.4)
                r = TRUNK_RADIUS * scale * flare
                ring.append(bm.verts.new((tx + math.cos(angle) * r, ty + math.sin(angle) * r,
                                          base + z)))
            loops.append(ring)
        verts = [v for ring in loops for v in ring]
        for lower, upper in zip(loops, loops[1:]):
            for s in range(segments):
                n = (s + 1) % segments
                bm.faces.new((lower[s], lower[n], upper[n], upper[s]))
        _paint(bm, uv_layer, verts, "rust")
        # boughs reaching into the crown
        for b in range(5):
            angle = spin + math.tau * b / 5 + rng.uniform(-0.3, 0.3)
            reach = rng.uniform(5.0, 8.0)
            start = Vector((tx, ty, base + rng.uniform(6.0, 8.0)))
            end = Vector((tx + math.cos(angle) * reach, ty + math.sin(angle) * reach,
                          CROWN_HEIGHT + rng.uniform(-0.3, 0.8)))
            made = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.55,
                                         radius2=0.22, depth=(end - start).length)
            turn = Vector((0, 0, 1)).rotation_difference((end - start).normalized()).to_matrix()
            for v in made["verts"]:
                v.co = turn @ v.co + (start + end) / 2.0
            _paint(bm, uv_layer, made["verts"], "rust")
    material = bpy.data.materials.get("fl_bark") or bpy.data.materials.new("fl_bark")
    return _link("verdance_trunks-col", bm, material)


def build_canopy(seed: int = 5):
    """Leaf pads filling each grove's footprint, ten metres up."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for cx, cy, rx, ry in GROVES:
        pads = int(rx * ry * 0.19)
        for _ in range(pads):
            angle = rng.uniform(0.0, math.tau)
            d = math.sqrt(rng.random()) * 0.96
            x, y = cx + math.cos(angle) * rx * d, cy + math.sin(angle) * ry * d
            radius = rng.uniform(3.0, 5.2) * (1.0 - 0.3 * d)
            z = CROWN_HEIGHT + 1.6 * (1.0 - d * d) + rng.uniform(-0.5, 0.7)
            verts = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)["verts"]
            squash = Vector((rng.uniform(0.85, 1.2), rng.uniform(0.85, 1.2),
                             rng.uniform(0.22, 0.34)))
            for v in verts:
                lump = 1.0 + 0.16 * noise.noise(v.co * 0.6 + Vector((x, y, 0.0)))
                v.co = Vector((v.co.x * squash.x, v.co.y * squash.y, v.co.z * squash.z)) * lump
                v.co += Vector((x, y, z))
    material = bpy.data.materials.get("fl_canopy") or bpy.data.materials.new("fl_canopy")
    return _link("verdance_canopy", bm, material)


def build_undergrowth(seed: int = 23, attempts: int = 2600):
    """Mossy stones along the ridges and the stream, fern mounds on the open floor."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    half = SIZE / 2.0 - 6.0
    for _ in range(attempts):
        x, y = rng.uniform(-half, half), rng.uniform(-half, half)
        z = height(x, y)
        slope = math.hypot(height(x + 1.0, y) - z, height(x, y + 1.0) - z)
        near_stream = _line_distance(x, y, STREAM) < STREAM_HALF_WIDTH + 3.0
        if 0.14 < slope < 0.9 or (near_stream and rng.random() < 0.35):
            radius, swatch, flat = rng.uniform(0.3, 0.9), "stone_dark", rng.uniform(0.45, 0.75)
        elif slope <= 0.14 and rng.random() < 0.14:
            radius, swatch, flat = rng.uniform(0.25, 0.6), "olive", rng.uniform(0.5, 0.9)
        else:
            continue
        verts = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)["verts"]
        squash = Vector((rng.uniform(0.7, 1.3), rng.uniform(0.7, 1.3), flat))
        spin = Matrix.Rotation(rng.uniform(0.0, math.tau), 4, "Z")
        for v in verts:
            v.co = Vector((v.co.x * squash.x, v.co.y * squash.y, v.co.z * squash.z))
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.14
            v.co = spin @ v.co + Vector((x, y, z + radius * 0.12))
        _paint(bm, uv_layer, verts, swatch)
    return _link("verdance_undergrowth", bm, _atlas_material(), smooth=False)


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
