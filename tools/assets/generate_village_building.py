"""
generate_village_building.py
Headless Blender Python script to generate 4-stage destroyable village buildings
for Christ Fallow (Godot 4.3 Forward+ PSX aesthetic).

Generates:
- assets/models/buildings/sleeping_hut_stages.glb
- assets/models/buildings/palisade_wall_stages.glb

Node Contract:
- Stage_Intact
- Stage_Damaged
- Stage_Critical
- Stage_Rubble
- Collider-convcolonly
"""

import argparse
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Ensure a collection exists
    if not bpy.data.collections:
        col = bpy.data.collections.new("Scene Collection")
        bpy.context.scene.collection.children.link(col)


def make_flat_material(name, color_rgba, roughness=0.94, specular=0.0):
    mat = bpy.data.materials.get(name)
    if not mat:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = color_rgba
            bsdf.inputs["Roughness"].default_value = roughness
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = specular
            elif "Specular" in bsdf.inputs:
                bsdf.inputs["Specular"].default_value = specular
    return mat


def set_flat_shading(obj):
    if obj.type == 'MESH':
        for poly in obj.data.polygons:
            poly.use_smooth = False


def create_materials():
    return {
        "wood": make_flat_material("Mat_Wood", (0.36, 0.22, 0.12, 1.0), roughness=0.94),
        "dark_wood": make_flat_material("Mat_DarkWood", (0.22, 0.14, 0.08, 1.0), roughness=0.96),
        "stone": make_flat_material("Mat_Stone", (0.40, 0.39, 0.37, 1.0), roughness=0.94),
        "thatch": make_flat_material("Mat_Thatch", (0.56, 0.45, 0.24, 1.0), roughness=0.96),
        "frayed": make_flat_material("Mat_FrayedThatch", (0.38, 0.28, 0.13, 1.0), roughness=0.98),
        "hide": make_flat_material("Mat_Hide", (0.48, 0.34, 0.22, 1.0), roughness=0.92),
        "faction": make_flat_material("FactionTrim", (0.85, 0.20, 0.20, 1.0), roughness=0.85),
        "charred": make_flat_material("Mat_Charred", (0.10, 0.08, 0.07, 1.0), roughness=0.98),
    }


def join_and_rename(part_objs, new_name):
    """Joins multiple part meshes into a single stage mesh object."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in part_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = part_objs[0]
    bpy.ops.object.join()
    unified = bpy.context.view_layer.objects.active
    unified.name = new_name
    set_flat_shading(unified)
    return unified


def box_part(location, size, material, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.scale = size
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(scale=True)
    return obj


def timber(start, end, radius, material, splintered=False):
    start, end = Vector(start), Vector(end)
    along = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=radius, depth=along.length,
                                       location=(start + end) * 0.5)
    obj = bpy.context.active_object
    obj.rotation_euler = along.to_track_quat("Z", "Y").to_euler()
    if splintered:
        for vertex in obj.data.vertices:
            if vertex.co.z > 0:
                vertex.co.z += vertex.co.x * 0.65 - abs(vertex.co.y) * 0.35
    obj.data.materials.append(material)
    return obj


def thatch_panel(angle, eave, crown, material, torn=False):
    """A thick roof panel with a ragged edge facing the missing section."""
    half_angle = math.pi / 8
    left, right = angle - half_angle, angle + half_angle

    def end_point(radius, z, direction):
        return (math.cos(direction) * radius, math.sin(direction) * radius, z)

    edge = [end_point(eave[0], eave[1], left)]
    if torn:
        edge.extend([end_point(eave[0] * 0.82, eave[1] + 0.24, angle - 0.09),
                     end_point(eave[0] * 0.93, eave[1] + 0.07, angle + 0.03)])
    edge.extend([end_point(eave[0], eave[1], right),
                 end_point(crown[0], crown[1], right),
                 end_point(crown[0], crown[1], left)])
    count = len(edge)
    vertices = edge + [(x * 0.99, y * 0.99, z - 0.07) for x, y, z in edge]
    faces = [tuple(range(count)), tuple(reversed(range(count, count * 2)))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((next_index, index, index + count, next_index + count))
    mesh = bpy.data.meshes.new("ThatchPanel")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new("ThatchPanel", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ---------------------------------------------------------------------------
# SLEEPING HUT GENERATOR
# ---------------------------------------------------------------------------
def build_sleeping_hut(output_dir):
    reset_scene()
    mats = create_materials()

    # --- STAGE 0: INTACT ---
    intact_parts = []

    # Main thatch cone (8 radial segments for authentic PSX look)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=2.15, depth=2.4, location=(0, 0, 1.2)
    )
    hut_base = bpy.context.active_object
    hut_base.data.materials.append(mats["thatch"])
    # Taper top
    for v in hut_base.data.vertices:
        if v.co.z > 0.0:
            v.co.x *= 0.15
            v.co.y *= 0.15
    hut_base.data.update()
    intact_parts.append(hut_base)

    # Hide cap on top
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=7, radius=1.55, depth=1.4, location=(0, 0, 1.75)
    )
    hut_cap = bpy.context.active_object
    hut_cap.data.materials.append(mats["hide"])
    for v in hut_cap.data.vertices:
        if v.co.z > 0.0:
            v.co.x *= 0.1
            v.co.y *= 0.1
    hut_cap.data.update()
    intact_parts.append(hut_cap)

    # Doorframe timber posts and lintel
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 1.55, 0.58))
    doorway = bpy.context.active_object
    doorway.scale = (0.85, 0.7, 1.15)
    doorway.data.materials.append(mats["dark_wood"])
    bpy.ops.object.transform_apply(scale=True)
    intact_parts.append(doorway)

    # Faction banner at apex
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 2.55))
    banner = bpy.context.active_object
    banner.scale = (0.45, 0.08, 0.55)
    banner.data.materials.append(mats["faction"])
    bpy.ops.object.transform_apply(scale=True)
    intact_parts.append(banner)

    stage_intact = join_and_rename(intact_parts, "Stage_Intact")

    # --- STAGE 1: DAMAGED ---
    damaged_parts = []
    # Leave two front-side panels open so the missing thatch reads from overhead.
    for index in [0, 3, 4, 5, 6, 7]:
        torn = index in (0, 3)
        damaged_parts.append(thatch_panel(index * math.pi / 4, (2.05, 0.13 if torn else 0.04),
                                            (0.32, 2.28), mats["frayed" if torn else "thatch"], torn))
    for angle in [0.42, 0.95, 1.45, 1.98]:
        eave = (math.cos(angle) * 1.95, math.sin(angle) * 1.95, 0.15)
        apex = (math.cos(angle) * 0.22, math.sin(angle) * 0.22, 2.40)
        damaged_parts.append(timber(eave, apex, 0.065, mats["dark_wood"], splintered=True))
    damaged_parts.append(box_part((0.02, 0.18, 2.25), (0.66, 0.54, 0.13), mats["hide"], (0.12, -0.04, 0.1)))

    # Chipped doorway
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.05, 1.52, 0.55), rotation=(0, 0.06, 0))
    doorway_d = bpy.context.active_object
    doorway_d.scale = (0.85, 0.65, 1.1)
    doorway_d.data.materials.append(mats["dark_wood"])
    bpy.ops.object.transform_apply(scale=True)
    damaged_parts.append(doorway_d)

    # Tilted torn banner
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.08, 0, 2.35), rotation=(0.12, 0.18, 0))
    banner_d = bpy.context.active_object
    banner_d.scale = (0.42, 0.08, 0.45)
    banner_d.data.materials.append(mats["faction"])
    bpy.ops.object.transform_apply(scale=True)
    damaged_parts.append(banner_d)

    # Debris rocks around base
    bpy.ops.mesh.primitive_cube_add(size=0.35, location=(1.2, 1.4, 0.15))
    rock1 = bpy.context.active_object
    rock1.data.materials.append(mats["stone"])
    damaged_parts.append(rock1)

    stage_damaged = join_and_rename(damaged_parts, "Stage_Damaged")

    # --- STAGE 2: CRITICAL ---
    critical_parts = []
    # Two low pieces of thatch remain. The ragged rafter silhouette carries this stage.
    for angle, height in [(math.pi * 0.98, 0.76), (math.pi * 1.28, 0.43)]:
        critical_parts.append(thatch_panel(angle, (2.0, 0.04), (0.40, height), mats["frayed"], torn=True))
    for angle, tip_radius, height in [(0.28, 1.05, 1.62), (1.16, 1.30, 0.73),
                                      (2.12, 0.67, 1.52), (3.70, 0.82, 0.91), (5.12, 1.26, 1.31)]:
        foot = (math.cos(angle) * 1.94, math.sin(angle) * 1.94, 0.04)
        tip = (math.cos(angle + 0.22) * tip_radius, math.sin(angle + 0.22) * tip_radius, height)
        critical_parts.append(timber(foot, tip, 0.11, mats["charred"], splintered=True))
    critical_parts.append(timber((-0.38, 0.72, 0.12), (1.22, -0.12, 0.58),
                                  0.085, mats["dark_wood"], splintered=True))

    # Charred collapsed doorway
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.2, 1.35, 0.3), rotation=(0.2, 0.3, 0.5))
    crit_door = bpy.context.active_object
    crit_door.scale = (0.8, 0.5, 0.9)
    crit_door.data.materials.append(mats["charred"])
    bpy.ops.object.transform_apply(scale=True)
    critical_parts.append(crit_door)

    # Burnt scorched center mound
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.9, depth=0.5, location=(0, 0, 0.25)
    )
    ash_mound = bpy.context.active_object
    ash_mound.data.materials.append(mats["charred"])
    critical_parts.append(ash_mound)

    stage_critical = join_and_rename(critical_parts, "Stage_Critical")

    # --- STAGE 3: RUBBLE ---
    rubble_parts = []
    # Flattened debris pile
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=7, radius=2.2, depth=0.4, location=(0, 0, 0.2)
    )
    rubble_base = bpy.context.active_object
    rubble_base.data.materials.append(mats["charred"])
    for v in rubble_base.data.vertices:
        if v.co.z > 0.0:
            v.co.x *= 0.6
            v.co.y *= 0.6
    rubble_base.data.update()
    rubble_parts.append(rubble_base)

    # Splintered logs on ground
    for (rx, ry, rz_rot) in [(-0.8, 0.5, 0.4), (0.7, -0.6, 1.2), (0.2, 0.9, 2.1)]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=5, radius=0.1, depth=1.2, location=(rx, ry, 0.15),
            rotation=(1.57, 0, rz_rot)
        )
        splinter = bpy.context.active_object
        splinter.data.materials.append(mats["wood"])
        rubble_parts.append(splinter)

    # Thatch remnants
    bpy.ops.mesh.primitive_cube_add(size=0.6, location=(-0.3, -0.4, 0.25), rotation=(0.1, 0.2, 0.3))
    thatch_scrap = bpy.context.active_object
    thatch_scrap.data.materials.append(mats["thatch"])
    rubble_parts.append(thatch_scrap)

    stage_rubble = join_and_rename(rubble_parts, "Stage_Rubble")

    # --- COLLIDER (Convex Hull for Godot glTF importer) ---
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=8, radius=2.2, depth=2.4, location=(0, 0, 1.2)
    )
    collider = bpy.context.active_object
    collider.name = "Collider-convcolonly"

    # Export GLB
    # Blender +Y exports to Godot -Z. The preview faces Godot +Z.
    facing = Matrix.Rotation(math.pi, 4, 'Z')
    for stage in (stage_intact, stage_damaged, stage_critical, stage_rubble):
        stage.matrix_world = facing @ stage.matrix_world

    out_path = os.path.join(output_dir, "sleeping_hut_stages.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=False,
        export_apply=True
    )
    print(f"Exported: {out_path}")


# ---------------------------------------------------------------------------
# PALISADE WALL GENERATOR
# ---------------------------------------------------------------------------
def build_palisade_wall(output_dir):
    reset_scene()
    mats = create_materials()

    log_x_positions = [-1.4, -0.7, 0.0, 0.7, 1.4]

    # --- STAGE 0: INTACT ---
    intact_parts = []
    for x in log_x_positions:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.15, depth=2.2, location=(x, 0, 1.1)
        )
        log = bpy.context.active_object
        log.data.materials.append(mats["wood"])
        # Sharpen top vertex
        for v in log.data.vertices:
            if v.co.z > 0.8:
                v.co.x *= 0.1
                v.co.y *= 0.1
        log.data.update()
        intact_parts.append(log)

    # Crossbeam horizontal log
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.12, depth=3.2, location=(0, 0.16, 1.1),
        rotation=(0, 1.5708, 0)
    )
    crossbeam = bpy.context.active_object
    crossbeam.data.materials.append(mats["dark_wood"])
    intact_parts.append(crossbeam)

    # Wrap the beam so the marker reads from both sides.
    intact_parts.append(box_part((0.36, 0.16, 1.1), (0.31, 0.29, 0.38), mats["faction"]))

    stage_intact = join_and_rename(intact_parts, "Stage_Intact")

    # --- STAGE 1: DAMAGED ---
    damaged_parts = []
    for i, x in enumerate(log_x_positions):
        snapped = i == 2
        height = 1.28 if snapped else 2.15
        rot_y = 0.09 if i % 2 == 0 else -0.08
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.14, depth=height, location=(x, 0, height * 0.5),
            rotation=(0, rot_y, 0)
        )
        log_d = bpy.context.active_object
        log_d.data.materials.append(mats["wood"])
        for v in log_d.data.vertices:
            if snapped and v.co.z > 0:
                v.co.z += 0.85 * v.co.x - 0.25 * abs(v.co.y)
            elif v.co.z > 0.8:
                v.co.x *= 0.1
                v.co.y *= 0.1
        log_d.data.update()
        damaged_parts.append(log_d)

    # Tilted cracked crossbeam
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.11, depth=3.1, location=(0, 0.14, 0.95),
        rotation=(0.04, 1.52, 0)
    )
    crossbeam_d = bpy.context.active_object
    crossbeam_d.data.materials.append(mats["dark_wood"])
    damaged_parts.append(crossbeam_d)
    damaged_parts.append(box_part((0.36, 0.14, 0.93), (0.28, 0.26, 0.31), mats["faction"], (0.04, -0.05, 0)))
    damaged_parts.append(timber((-0.04, 0.43, 0.12), (0.70, 0.60, 0.28),
                                 0.095, mats["wood"], splintered=True))

    stage_damaged = join_and_rename(damaged_parts, "Stage_Damaged")

    # --- STAGE 2: CRITICAL ---
    critical_parts = []
    # 2 logs snapped in half, 1 missing/fallen, 2 severely leaning
    # Log 1: snapped short
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.15, depth=0.9, location=(-1.4, 0, 0.45)
    )
    log1 = bpy.context.active_object
    log1.data.materials.append(mats["charred"])
    critical_parts.append(log1)

    # Log 2: tilted heavily
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.14, depth=2.1, location=(-0.7, 0.3, 0.9),
        rotation=(0.4, -0.2, 0)
    )
    log2 = bpy.context.active_object
    log2.data.materials.append(mats["charred"])
    critical_parts.append(log2)

    # Log 4: broken jagged
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.14, depth=1.3, location=(0.7, 0, 0.65)
    )
    log4 = bpy.context.active_object
    log4.data.materials.append(mats["charred"])
    critical_parts.append(log4)

    # Fallen broken beam on ground
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.11, depth=2.2, location=(0.1, 0.4, 0.12),
        rotation=(1.45, 0.3, 0.2)
    )
    beam_crit = bpy.context.active_object
    beam_crit.data.materials.append(mats["dark_wood"])
    critical_parts.append(beam_crit)

    stage_critical = join_and_rename(critical_parts, "Stage_Critical")

    # --- STAGE 3: RUBBLE ---
    rubble_parts = []
    # Ground splinter pile
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.15))
    mound = bpy.context.active_object
    mound.scale = (3.2, 0.8, 0.25)
    mound.data.materials.append(mats["charred"])
    bpy.ops.object.transform_apply(scale=True)
    rubble_parts.append(mound)

    # 3 broken stump remnants
    for x in [-1.1, 0.1, 1.2]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=5, radius=0.14, depth=0.35, location=(x, 0, 0.18)
        )
        stump = bpy.context.active_object
        stump.data.materials.append(mats["charred"])
        rubble_parts.append(stump)

    stage_rubble = join_and_rename(rubble_parts, "Stage_Rubble")

    # --- COLLIDER ---
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.1))
    collider = bpy.context.active_object
    collider.scale = (3.2, 0.5, 2.2)
    bpy.ops.object.transform_apply(scale=True)
    collider.name = "Collider-convcolonly"

    # Export GLB
    out_path = os.path.join(output_dir, "palisade_wall_stages.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=False,
        export_apply=True
    )
    print(f"Exported: {out_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate the staged village building models.")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    os.makedirs(args.out_dir, exist_ok=True)
    print("Building sleeping_hut_stages.glb...")
    build_sleeping_hut(args.out_dir)
    print("Building palisade_wall_stages.glb...")
    build_palisade_wall(args.out_dir)
    print("All village buildings generated successfully!")
