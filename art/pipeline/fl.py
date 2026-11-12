"""Farlanding modelling toolkit for Blender (bpy).

Models are Python recipes in art/models/. Each recipe builds named part objects
under one root empty, paints faces with palette swatches, and is exported to
game/assets/models/ as a .glb whose single material samples the shared palette
atlas. Run recipes live through the Blender MCP or headless with
`blender -b -P art/pipeline/build_all.py`.

Conventions
- 1 Blender unit = 1 metre. Models face -Y in Blender (= -Z, "forward", in Godot).
- Origin on the ground at the footprint centre.
- Moving parts are separate child objects with reserved names that the game
  animates in code: turret, barrel, wheel_*, leg_*, dish, rotor, track_*.
"""

from __future__ import annotations

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(REPO, "game", "assets")

# ---------------------------------------------------------------- palette ---
# name: (albedo sRGB, roughness, metallic, emission strength, team mask)
# Order is the atlas layout (row-major, GRID x GRID). Append only: reordering
# moves every exported model's UVs.
GRID = 8
SWATCHES: dict[str, tuple[tuple[float, float, float], float, float, float, float]] = {
    # Concord Survey
    "ceramic": ((0.82, 0.80, 0.74), 0.50, 0.0, 0.0, 0.0),
    "ceramic_shade": ((0.56, 0.55, 0.52), 0.60, 0.0, 0.0, 0.0),
    "orange": ((0.93, 0.36, 0.05), 0.45, 0.0, 0.0, 0.0),
    "graphite": ((0.10, 0.11, 0.13), 0.60, 0.2, 0.0, 0.0),
    "steel": ((0.42, 0.44, 0.47), 0.35, 1.0, 0.0, 0.0),
    "rubber": ((0.035, 0.035, 0.04), 0.90, 0.0, 0.0, 0.0),
    "glass": ((0.04, 0.16, 0.24), 0.08, 0.6, 0.0, 0.0),
    "glow_cyan": ((0.25, 0.95, 1.00), 0.40, 0.0, 4.0, 0.0),
    # shared
    "team": ((1.00, 1.00, 1.00), 0.50, 0.0, 0.0, 1.0),
    "team_glow": ((1.00, 1.00, 1.00), 0.40, 0.0, 3.0, 1.0),
    "glow_orange": ((1.00, 0.55, 0.12), 0.40, 0.0, 4.0, 0.0),
    "hazard": ((0.95, 0.72, 0.05), 0.55, 0.0, 0.0, 0.0),
    "copper": ((0.72, 0.38, 0.20), 0.35, 1.0, 0.0, 0.0),
    "white": ((0.92, 0.92, 0.92), 0.50, 0.0, 0.0, 0.0),
    "black": ((0.02, 0.02, 0.02), 0.70, 0.0, 0.0, 0.0),
    "glow_red": ((1.00, 0.12, 0.08), 0.40, 0.0, 4.0, 0.0),
    # Halcyon Combine
    "hull": ((0.15, 0.16, 0.18), 0.45, 0.6, 0.0, 0.0),
    "hull_light": ((0.28, 0.30, 0.33), 0.45, 0.6, 0.0, 0.0),
    "rust": ((0.36, 0.17, 0.09), 0.80, 0.3, 0.0, 0.0),
    "acid": ((0.10, 0.85, 0.62), 0.40, 0.0, 4.0, 0.0),
    "olive": ((0.24, 0.27, 0.17), 0.65, 0.1, 0.0, 0.0),
    "gunmetal": ((0.22, 0.23, 0.26), 0.30, 1.0, 0.0, 0.0),
    # Custodians / Antecedent
    "stone": ((0.70, 0.66, 0.58), 0.85, 0.0, 0.0, 0.0),
    "stone_dark": ((0.40, 0.37, 0.33), 0.90, 0.0, 0.0, 0.0),
    "brass": ((0.80, 0.60, 0.25), 0.30, 1.0, 0.0, 0.0),
    "glow_white": ((1.00, 0.95, 0.80), 0.40, 0.0, 5.0, 0.0),
    # Kessel Reach scenery
    "kessel_rock": ((0.47, 0.27, 0.18), 0.90, 0.0, 0.0, 0.0),
    "kessel_rock_pale": ((0.72, 0.52, 0.36), 0.90, 0.0, 0.0, 0.0),
}
ATLAS_MATERIAL = "fl_palette"


def swatch_uv(name: str) -> tuple[float, float]:
    """Centre of a swatch cell in UV space (glTF flips V on export)."""
    index = list(SWATCHES).index(name)
    col, row = index % GRID, index // GRID
    return ((col + 0.5) / GRID, 1.0 - (row + 0.5) / GRID)


def material(name: str) -> bpy.types.Material:
    """Preview material for a swatch (Blender viewport only)."""
    mat = bpy.data.materials.get("sw_" + name)
    if mat is None:
        srgb, rough, metal, emit, _team = SWATCHES[name]
        rgb = tuple(c ** 2.2 for c in srgb)  # swatches are sRGB; nodes want linear
        mat = bpy.data.materials.new("sw_" + name)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emit > 0.0:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit
        mat.diffuse_color = (*rgb, 1.0)
    return mat


# ------------------------------------------------------------------ scene ---
def reset_scene() -> None:
    """Empty the file so a recipe always starts clean."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.curves):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def root(name: str) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ------------------------------------------------------------- primitives ---
class Part:
    """Accumulates geometry for one named object, then finishes it."""

    def __init__(self, name: str, parent: bpy.types.Object, pivot=(0.0, 0.0, 0.0)):
        self.name = name
        self.parent = parent
        self.pivot = Vector(pivot)
        self.bm = bmesh.new()
        self.slots: list[str] = []

    def _slot(self, swatch: str) -> int:
        if swatch not in self.slots:
            self.slots.append(swatch)
        return self.slots.index(swatch)

    def _add(self, geom, swatch: str, matrix: Matrix) -> list:
        verts = [g for g in geom if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        faces = {f for v in verts for f in v.link_faces}
        slot = self._slot(swatch)
        for face in faces:
            face.material_index = slot
        return verts

    @staticmethod
    def _matrix(loc, rot, scale) -> Matrix:
        rx, ry, rz = (math.radians(a) for a in rot)
        return (
            Matrix.Translation(Vector(loc))
            @ Matrix.Rotation(rz, 4, "Z")
            @ Matrix.Rotation(ry, 4, "Y")
            @ Matrix.Rotation(rx, 4, "X")
            @ Matrix.Diagonal((*scale, 1.0))
        )

    def box(self, size, loc=(0, 0, 0), swatch="ceramic", rot=(0, 0, 0), taper=None):
        """Box of `size` centred at `loc`. `taper=(sx, sy)` scales the top face."""
        geom = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        if taper is not None:
            for v in geom:
                if v.co.z > 0:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
        return self._add(geom, swatch, self._matrix(loc, rot, size))

    def cyl(self, radius, depth, loc=(0, 0, 0), swatch="steel", rot=(0, 0, 0),
            segments=16, radius_top=None):
        """Cylinder along local Z (rotate with `rot`); cone if radius_top differs."""
        top = radius if radius_top is None else radius_top
        geom = bmesh.ops.create_cone(
            self.bm, cap_ends=True, segments=segments,
            radius1=radius, radius2=top, depth=depth,
        )["verts"]
        return self._add(geom, swatch, self._matrix(loc, rot, (1, 1, 1)))

    def sphere(self, radius, loc=(0, 0, 0), swatch="glass", scale=(1, 1, 1), segments=16):
        geom = bmesh.ops.create_uvsphere(
            self.bm, u_segments=segments, v_segments=segments // 2, radius=radius
        )["verts"]
        return self._add(geom, swatch, self._matrix(loc, (0, 0, 0), scale))

    def mirror_x(self) -> None:
        """Duplicate everything built so far across the YZ plane."""
        geom = self.bm.verts[:] + self.bm.edges[:] + self.bm.faces[:]
        dup = bmesh.ops.duplicate(self.bm, geom=geom)["geom"]
        verts = [g for g in dup if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.scale(self.bm, vec=(-1, 1, 1), verts=verts)
        faces = [g for g in dup if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(self.bm, faces=faces)

    def finish(self, bevel=0.02, segments=2) -> bpy.types.Object:
        """Create the object: bevelled edges, weighted normals, pivot applied."""
        bmesh.ops.translate(self.bm, vec=-self.pivot, verts=self.bm.verts)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for swatch in self.slots:
            mesh.materials.append(material(swatch))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = self.parent
        obj["fl_pivot"] = tuple(self.pivot)
        obj.location = self.pivot - Vector(self.parent.get("fl_pivot", (0.0, 0.0, 0.0)))
        for poly in mesh.polygons:
            poly.use_smooth = True
        if bevel > 0.0:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(40)
            mod.harden_normals = True
        mod = obj.modifiers.new("normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        return obj


# ----------------------------------------------------------------- export ---
def _apply_and_atlas(obj: bpy.types.Object) -> None:
    """Apply modifiers, then replace material slots with palette-atlas UVs."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                           depsgraph=depsgraph)
    obj.modifiers.clear()
    # Recipes face -Y (Blender's front view); the game's forward is glTF -Z,
    # which is Blender +Y, so turn everything half a turn about Z.
    flip = Matrix.Rotation(math.pi, 4, "Z")
    mesh.transform(flip)
    obj.location = flip @ obj.location
    old_mesh = obj.data
    slot_names = [s.material.name[3:] if s.material else "ceramic" for s in obj.material_slots]
    obj.data = mesh
    name = old_mesh.name
    bpy.data.meshes.remove(old_mesh)
    mesh.name = name
    uv = mesh.uv_layers.new(name="palette") if not mesh.uv_layers else mesh.uv_layers[0]
    for poly in mesh.polygons:
        u, v = swatch_uv(slot_names[poly.material_index] if slot_names else "ceramic")
        for loop_index in poly.loop_indices:
            uv.data[loop_index].uv = (u, v)
        poly.material_index = 0
    atlas = bpy.data.materials.get(ATLAS_MATERIAL) or bpy.data.materials.new(ATLAS_MATERIAL)
    mesh.materials.clear()
    mesh.materials.append(atlas)


def export(root_obj: bpy.types.Object, subdir: str) -> str:
    """Write root_obj and its children to game/assets/models/<subdir>/<name>.glb."""
    out_dir = os.path.join(ASSETS, "models", subdir)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, root_obj.name + ".glb")
    children = [o for o in root_obj.children_recursive if o.type == "MESH"]
    for obj in children:
        _apply_and_atlas(obj)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj is root_obj or obj in children)
    bpy.context.view_layer.objects.active = root_obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_materials="EXPORT",
        export_animations=False,
    )
    return path


def write_palette_textures() -> list[str]:
    """Write the palette atlas textures the game's unit shader samples.

    palette_albedo.png : rgb = base colour
    palette_surface.png: r = roughness, g = metallic, b = emission/8, a = team mask
    """
    out_dir = os.path.join(ASSETS, "textures")
    os.makedirs(out_dir, exist_ok=True)
    cell = 4
    size = GRID * cell
    albedo = [0.0, 0.0, 0.0, 1.0] * (size * size)
    surface = [0.5, 0.0, 0.0, 0.0] * (size * size)
    for index, (rgb, rough, metal, emit, team) in enumerate(SWATCHES.values()):
        col, row = index % GRID, index // GRID
        for py in range(cell):
            for px in range(cell):
                x = col * cell + px
                y = size - 1 - (row * cell + py)  # image rows are bottom-up
                i = (y * size + x) * 4
                albedo[i:i + 4] = [*rgb, 1.0]
                surface[i:i + 4] = [rough, metal, emit / 8.0, team]
    paths = []
    for name, pixels, colorspace in (
        ("palette_albedo", albedo, "sRGB"),
        ("palette_surface", surface, "Non-Color"),
    ):
        image = bpy.data.images.new(name, size, size, alpha=True)
        image.colorspace_settings.name = colorspace
        image.pixels.foreach_set(pixels)
        image.filepath_raw = os.path.join(out_dir, name + ".png")
        image.file_format = "PNG"
        image.save()
        paths.append(image.filepath_raw)
        bpy.data.images.remove(image)
    return paths
