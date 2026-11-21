"""Generate the standalone Christ Fallow sample GLBs with Blender 4.5."""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import generate_tribesman_rig as human
from generate_valley_assets import animate_bite
from generate_village_building import box_part, join_and_rename, make_flat_material, timber


STAGES = ("Stage_Intact", "Stage_Damaged", "Stage_Critical", "Stage_Rubble")
PALETTE = {
    "oak": ("Mat_Oak", (0.30, 0.148, 0.065)),
    "bark": ("Mat_Bark", (0.14, 0.075, 0.042)),
    "char": ("Mat_Charred", (0.061, 0.048, 0.045)),
    "reed": ("Mat_Reed", (0.57, 0.38, 0.14)),
    "straw": ("Mat_Straw", (0.76, 0.57, 0.26)),
    "stone": ("Mat_Limestone", (0.29, 0.31, 0.30)),
    "chalk": ("Mat_Chalk", (0.55, 0.49, 0.37)),
    "lichen": ("Mat_Lichen", (0.16, 0.235, 0.175)),
    "mark": ("Mat_Malachite", (0.071, 0.51, 0.39)),
    "trim": ("FactionTrim", (0.67, 0.115, 0.037)),
    "coal": ("Mat_Ember", (0.84, 0.19, 0.024)),
    "bone": ("Mat_Bone", (0.75, 0.64, 0.43)),
    "earth": ("Mat_Earth", (0.17, 0.101, 0.066)),
    "skin": ("Mat_Bristle", (0.21, 0.118, 0.084)),
    "plate": ("Mat_Slate", (0.25, 0.302, 0.35)),
    "fen": ("Mat_Fen", (0.115, 0.25, 0.19)),
    "ridge": ("Mat_Ridge", (0.045, 0.133, 0.12)),
    "throat": ("Mat_Throat", (0.57, 0.27, 0.087)),
    "eye": ("Mat_Amber", (0.94, 0.48, 0.057)),
    "black": ("Mat_Obsidian", (0.023, 0.021, 0.020)),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return {key: make_flat_material(name, (*color, 1.0)) for key, (name, color) in PALETTE.items()}


def mesh_part(name, vertices, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    data.materials.append(material)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def stone(pos, dims, material, angle=0.0, detail=0):
    """A faceted rock with dimensions given in world units."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1 + detail, radius=1.0, location=pos)
    obj = bpy.context.active_object
    obj.scale = tuple(value * 0.5 for value in dims)
    obj.rotation_euler.z = angle
    obj.data.materials.append(material)
    return obj


def upright(x, bottom, top, width, depth, material, lean=0.0):
    """An irregular octagonal standing stone with a sloping crown."""
    profile = [(-0.39, -0.5), (0.35, -0.46), (0.51, -0.26), (0.47, 0.31),
               (0.22, 0.49), (-0.37, 0.45), (-0.52, 0.22), (-0.53, -0.28)]
    vertices = [(x + dx * width, dy * depth, bottom) for dx, dy in profile]
    vertices.extend((x + lean + dx * width * 0.88, dy * depth * 0.90,
                     top + width * (dx * 0.28 + dy * 0.06)) for dx, dy in profile)
    faces = [tuple(reversed(range(8))), tuple(range(8, 16))]
    for i in range(8):
        j = (i + 1) % 8
        faces.append((i, j, j + 8, i + 8))
    return mesh_part("Split stone", vertices, faces, material)


def chip_field(mat):
    return [stone((x, y, z), dims, mat, angle) for x, y, z, dims, angle in [
        (-1.18, -0.31, 0.22, (0.90, 0.64, 0.53), 0.4),
        (-0.59, 0.52, 0.12, (0.58, 0.48, 0.31), 0.1),
        (0.20, 0.02, 0.20, (1.05, 0.62, 0.48), -0.45),
        (1.02, 0.37, 0.22, (1.12, 0.76, 0.55), 0.1),
        (1.46, -0.20, 0.11, (0.51, 0.46, 0.26), 0.5),
    ]]


def signal_tower(stage, mats):
    parts = chip_field(mats["stone"])
    if stage == 3:
        parts += [timber(start, end, 0.11, mats["char"], True) for start, end in [
            ((-1.25, 0.24, 0.20), (0.60, 1.10, 0.30)),
            ((0.1, -0.92, 0.10), (1.33, 0.24, 0.13)),
            ((-0.95, -0.83, 0.11), (0.55, -0.38, 0.29)),
        ]]
        return parts

    if stage == 2:
        parts += [
            timber((-1.0, 0.76, 0.02), (-0.70, 0.68, 2.22), 0.16, mats["char"], True),
            timber((-0.95, -0.68, 0.03), (-0.78, -0.62, 1.27), 0.15, mats["bark"], True),
            timber((1.0, -0.68, 0.03), (0.8, -0.50, 0.63), 0.16, mats["char"], True),
            box_part((0.49, -0.12, 0.73), (2.1, 1.35, 0.14), mats["bark"], (0.09, -0.46, 0.25)),
            stone((0.25, 0.44, 0.31), (0.87, 0.77, 0.45), mats["char"], 0.1),
        ]
        return parts

    deck = 2.37 if stage == 0 else 2.16
    tilt = (0, 0, 0) if stage == 0 else (0.06, 0.14, 0.03)
    for x in [-0.89, 0.89]:
        for y in [-0.70, 0.70]:
            height = deck + (0.06 if x < 0 else -0.08) if stage == 1 else deck
            parts.append(timber((x * 1.23, y * 1.15, 0.08), (x, y, height), 0.13, mats["oak"]))
    parts += [
        timber((-1.0, -0.72, 0.42), (0.91, -0.72, deck - 0.07), 0.08, mats["bark"]),
        timber((0.9, -0.69, 0.44), (-0.88, -0.69, deck - 0.07), 0.08, mats["bark"]),
        box_part((0, 0, deck), (2.22, 1.87, 0.18), mats["oak"], tilt),
        timber((-0.40, 1.24, 0.09), (-0.40, 0.72, deck), 0.055, mats["bark"]),
        timber((0.25, 1.24, 0.09), (0.25, 0.72, deck), 0.055, mats["bark"]),
    ]
    for rung in range(1, 7):
        if stage == 1 and rung in (3, 4):
            continue
        fraction = rung / 7
        y = 1.24 - fraction * 0.52
        parts.append(timber((-0.40, y, fraction * deck), (0.25, y, fraction * deck), 0.039, mats["reed"]))
    parts.append(stone((0, 0, deck + 0.16), (1.16, 1.12, 0.48), mats["stone"]))
    for x, y, z in [(-0.20, -0.02, 0.34), (0.00, 0.08, 0.49), (0.23, 0.04, 0.31)]:
        parts.append(stone((x, y, deck + z), (0.33, 0.28, 0.30 + z * 0.76), mats["coal"], z))
    for x in [-0.88, 0.88]:
        if stage == 1 and x > 0:
            continue
        parts.append(timber((x, 0.76, deck), (x, 0.76, deck + 0.61), 0.056, mats["oak"]))
    if stage == 0:
        parts.append(timber((-0.88, 0.76, deck + 0.58), (0.88, 0.76, deck + 0.58), 0.056, mats["reed"]))
    else:
        parts.append(timber((0.10, 1.37, 0.17), (1.43, 1.04, 0.38), 0.07, mats["bark"], True))
    parts.append(box_part((-0.71, 0.79, deck + 0.16), (0.53, 0.067, 0.86 if stage == 0 else 0.57),
                          mats["trim"], (0, 0.17 if stage else 0, 0.03)))
    return parts


def stone_gate(stage, mats):
    if stage == 3:
        parts = chip_field(mats["stone"])
        parts += [stone((-1.54, 0.14, 0.15), (0.69, 0.87, 0.38), mats["chalk"]),
                  stone((0.70, -0.50, 0.23), (0.70, 0.66, 0.43), mats["lichen"], 0.5)]
        return parts

    left = [2.47, 2.36, 1.68][stage]
    right = [2.46, 1.88, 0.72][stage]
    parts = [
        upright(-1.25, 0.02, left, 0.95, 0.96, mats["stone"], -0.06),
        upright(1.25, 0.02, right, 0.99, 0.90, mats["stone"], 0.085),
        stone((-1.34, 0.19, 0.12), (1.26, 0.99, 0.27), mats["lichen"], 0.4),
        stone((1.35, 0.16, 0.12), (1.25, 1.05, 0.26), mats["lichen"], -0.1),
    ]
    if stage == 0:
        parts.append(stone((0, 0.02, 2.63), (4.05, 1.20, 0.79), mats["chalk"], 0.045))
        parts.append(box_part((0, 0.575, 2.59), (0.31, 0.055, 0.32), mats["mark"], (0, math.pi * 0.25, 0)))
    elif stage == 1:
        parts.append(stone((-0.70, 0.02, 2.43), (2.04, 1.14, 0.70), mats["chalk"], 0.04))
        parts.append(stone((1.13, 0.41, 0.36), (1.70, 0.92, 0.68), mats["chalk"], -0.27))
    else:
        parts.extend(chip_field(mats["stone"]))
    for x, height in [(-1.25, left), (1.25, right)]:
        for i in range(1, 4):
            z = i * 0.42 + 0.28
            if z + 0.22 < height:
                angle = 0.48 if i % 2 else -0.48
                parts.append(box_part((x, 0.43, z), (0.27, 0.074, 0.16), mats["mark"], (0, angle, 0)))
    return parts


def wreath(center, radius, depth, material):
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4, location=center,
                                    major_radius=radius, minor_radius=depth)
    obj = bpy.context.active_object
    obj.data.materials.append(material)
    return obj


def reed_granary(stage, mats):
    if stage == 3:
        return [
            stone((0.24, -0.04, 0.19), (3.30, 1.80, 0.43), mats["earth"], 0.1),
            box_part((-0.70, 0.06, 0.19), (1.00, 0.64, 0.12), mats["reed"], (0.03, 0.16, 0.22)),
            box_part((0.71, 0.28, 0.25), (1.1, 0.43, 0.13), mats["oak"], (0.04, -0.14, -0.34)),
            stone((0.43, 0.21, 0.31), (1.00, 0.79, 0.27), mats["straw"], 0.2),
        ]
    deck = [0.84, 0.79, 0.40][stage]
    tilt = [0.0, 0.12, -0.24][stage]
    parts = [box_part((0, 0, deck), (3.02, 1.73, 0.16), mats["oak"], (0.015, tilt, 0))]
    for x in [-1.17, 1.17]:
        for y in [-0.65, 0.65]:
            height = deck - tilt * x
            if stage == 2 and x < 0:
                height = 0.25
            parts.append(timber((x * 1.12, y * 1.08, 0.02), (x, y, height), 0.119, mats["bark"], stage > 0))
    for index, x in enumerate([-0.72, 0.72]):
        if stage == 2 and index == 1:
            # The missing bin leaves spilled grain and a dislodged woven ring.
            parts += [stone((0.95, 0.44, 0.17), (1.25, 0.91, 0.33), mats["straw"], -0.2),
                      wreath((1.27, -0.14, 0.09), 0.49, 0.047, mats["bark"])]
            continue
        height = 1.00 if stage < 2 else 0.73
        base = deck - tilt * x + 0.08
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.55, radius2=0.45, depth=height,
                                       location=(x, 0, base + height / 2))
        bin_obj = bpy.context.active_object
        bin_obj.data.materials.append(mats["reed"])
        parts.append(bin_obj)
        for band in [0.18, 0.43, 0.82]:
            parts.append(wreath((x, 0, base + height * band), 0.55 - 0.1 * band, 0.036, mats["bark"]))
        if stage == 0 or (stage == 1 and index == 0):
            bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.62, radius2=0.12, depth=0.63,
                                           location=(x, 0, base + height + 0.29))
            cap = bpy.context.active_object
            cap.data.materials.append(mats["straw"])
            parts.append(cap)
        else:
            parts.append(stone((x, 0.03, base + height * 0.94), (0.86, 0.86, 0.29), mats["straw"]))
    if stage == 0:
        parts.append(box_part((0, 0.87, 0.89), (0.47, 0.056, 0.40), mats["trim"]))
    elif stage == 1:
        parts.append(stone((1.43, 0.65, 0.16), (0.81, 0.65, 0.27), mats["straw"]))
        parts.append(box_part((-0.26, 0.87, 0.87), (0.44, 0.056, 0.39), mats["trim"], (0.10, -0.14, 0)))
    return parts


def export_building(output, name, builder, colliders, production=False):
    mats = reset()
    facing = Matrix.Rotation(math.pi, 4, "Z")
    for index, stage in enumerate(STAGES):
        joined = join_and_rename(builder(index, mats), stage)
        # The authored front is Godot local +Z.
        joined.matrix_world = facing @ joined.matrix_world
        if production and builder == signal_tower and index < 3:
            add_tower_markers(joined, index, mats, facing)
    for index, (x, dims) in enumerate(colliders):
        collider = box_part((x, 0, dims[2] * 0.5), dims, mats["stone"])
        collider.name = "Collider-convcolonly" if index == 0 else f"Collider{index + 1}-convcolonly"
    export_gltf(output / f"{name}.glb", lights=production)


def add_tower_markers(stage, index, mats, facing):
    def place(node, point):
        node.parent = stage
        node.matrix_world = Matrix.Translation(facing @ Vector(point))

    bpy.context.view_layer.update()
    arrow = bpy.data.objects.new("ArrowOrigin", None)
    bpy.context.scene.collection.objects.link(arrow)
    deck_height = (2.37, 2.16, 0.73)[index]
    arrow_pos = (0.52, -0.48, deck_height + 0.84) if index < 2 else (0.49, -0.12, deck_height + 0.84)
    place(arrow, arrow_pos)

    brazier = (0.0, 0.04, deck_height + 0.45) if index < 2 else (0.25, 0.44, 0.44)
    flame_mat = mats["coal"].copy()
    shader = flame_mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Emission Color"].default_value = (1.0, 0.23, 0.025, 1.0)
    shader.inputs["Emission Strength"].default_value = 1.5 if index < 2 else 0.6
    tips = [stone((x, 0, height * 0.38), (0.18, 0.22, height), flame_mat, x * 3)
            for x, height in [(-0.12, 0.28), (0.02, 0.44), (0.13, 0.20)]]
    flame = join_and_rename(tips, "FlameMesh")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    place(flame, brazier)

    lamp = bpy.data.lights.new("SignalLight", "POINT")
    lamp.color = (1.0, 0.42, 0.13)
    lamp.energy = (0.8, 0.55, 0.22)[index]
    lamp.use_custom_distance = True
    lamp.cutoff_distance = 3.5
    light = bpy.data.objects.new("SignalLight", lamp)
    bpy.context.scene.collection.objects.link(light)
    place(light, (brazier[0], brazier[1], brazier[2] + 0.28))


def scout(output):
    reset()
    armature = human.make_armature()
    mesh = human.SkinnedMesh()
    cloth = mesh.materials["trim"].node_tree.nodes.get("Principled BSDF")
    cloth.inputs["Base Color"].default_value = (0.60, 0.105, 0.045, 1)
    human.build_body(mesh)
    human.build_limbs(mesh)
    human.build_head(mesh)
    # The pale split mask and red ridge read at tactics zoom.
    mesh.tube([
        ((0, 0.146, 1.592), 0.068, 0.041, "Head"),
        ((0, 0.171, 1.692), 0.128, 0.061, "Head"),
        ((0, 0.144, 1.804), 0.128, 0.043, "Head"),
        ((0, 0.094, 1.852), 0.103, 0.041, "Head"),
    ], ["bone", "bone", "bone"], sides=6)
    for x in [-0.055, 0.055]:
        mesh.tube([((x, 0.209, 1.698), 0.038, 0.022, "Head"),
                   ((x, 0.212, 1.729), 0.037, 0.023, "Head")], ["hair"], sides=5)
    mesh.tube([((0, 0.181, 1.748), 0.017, 0.027, "Head"),
               ((0, 0.119, 1.838), 0.020, 0.035, "Head")], ["trim"], sides=5)
    # The bent silhouette is a prop weighted to the right hand.
    mesh.tube([((-0.47, 0.03, 0.47), 0.023, 0.026, "Hand.R"),
               ((-0.46, 0.028, 0.92), 0.031, 0.031, "Hand.R"),
               ((-0.46, 0.088, 1.31), 0.036, 0.036, "Hand.R"),
               ((-0.46, 0.19, 1.46), 0.060, 0.080, "Hand.R"),
               ((-0.46, 0.20, 1.55), 0.04, 0.063, "Hand.R")],
              ["hide", "hide", "hair", "hair"], sides=6)
    mesh.build(armature)
    set_frames()
    armature.animation_data_create()
    human.animate(armature, "Idle", 60)
    human.animate(armature, "Walk", 24, walking=True)
    export_gltf(output / "characters" / "archetypes" / "flintmask_scout.glb", animated=True)


def creature_bones(body_height, leg_positions, head_pos, tail_pos, jaw_pos=None):
    data = bpy.data.armatures.new("CreatureSkeleton")
    armature = bpy.data.objects.new("CreatureRig", data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    center = data.edit_bones.new("Body")
    center.head, center.tail = (0, 0, body_height), (0, 0, body_height + 0.26)
    for name, origin, end in [*leg_positions, ("Head", *head_pos), ("Tail", *tail_pos)]:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = origin, end
        bone.parent = center
    if jaw_pos is not None:
        jaw = data.edit_bones.new("Jaw")
        jaw.head, jaw.tail = jaw_pos
        jaw.parent = data.edit_bones["Head"]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def weight(part, bone):
    group = part.vertex_groups.new(name=bone)
    group.add(list(range(len(part.data.vertices))), 1.0, "REPLACE")
    return part


def creature_animation(armature, walk):
    name = "Walk-loop" if walk else "Idle-loop"
    frames = 24 if walk else 60
    data = armature.animation_data
    action = bpy.data.actions.new(name)
    action.use_cyclic = True
    data.action = action
    for i in range(0, frames + 1, 3):
        phase = math.tau * (i % frames) / frames
        for bone in armature.pose.bones:
            bone.rotation_mode = "QUATERNION"
            if bone.name == "Head":
                human.pose_rotation(bone, pitch=0.065 * math.sin(phase * (2 if walk else 1)))
            elif bone.name == "Tail":
                human.pose_rotation(bone, twist=(0.27 if walk else 0.17) * math.sin(phase))
            elif bone.name == "Body":
                human.pose_rotation(bone, lean=0.035 * math.sin(phase))
            else:
                opposite = bone.name in ("Fore.R", "Hind.L")
                swing = 0.46 * math.cos(phase + (math.pi if opposite else 0)) if walk else 0.0
                human.pose_rotation(bone, pitch=swing)
            bone.keyframe_insert(data_path="rotation_quaternion", frame=i + 1)
    slot = data.action_slot
    data.action = None
    track = data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_slot = slot


def export_creature(output, name, parts, armature, production=False):
    model = join_and_rename(parts, "WildlifeMesh" if production else "CreatureMesh")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    model.parent = armature
    deform = model.modifiers.new("SkeletonDeform", "ARMATURE")
    deform.object = armature
    set_frames()
    armature.animation_data_create()
    if production:
        animate_bite(armature, name == "slateback_boar")
    else:
        creature_animation(armature, False)
        creature_animation(armature, True)
    export_gltf(output / "wildlife" / f"{name}.glb", animated=True)


def boar(output, production=False):
    mats = reset()
    legs = []
    for side, label in [(1, "L"), (-1, "R")]:
        legs.extend([(f"Fore.{label}", (side * 0.32, 0.49, 0.83), (side * 0.38, 0.54, 0.09)),
                     (f"Hind.{label}", (side * 0.32, -0.64, 0.79), (side * 0.34, -0.67, 0.09))])
    armature = creature_bones(0.90, legs, ((0, 0.57, 0.93), (0, 1.38, 0.62)),
                              ((0, -0.93, 0.85), (0, -1.32, 1.02)),
                              ((0, 0.86, 0.58), (0, 1.51, 0.51)) if production else None)
    parts = [
        weight(stone((0, -0.16, 0.91), (1.08, 2.26, 1.27), mats["skin"], detail=1), "Body"),
        weight(stone((0, 0.75, 0.91), (0.95, 1.07, 1.03), mats["bark"], detail=1), "Head"),
        weight(stone((0, 1.28, 0.63), (0.63, 0.86, 0.49), mats["skin"], detail=1), "Head"),
        weight(stone((0, 1.61, 0.65), (0.40, 0.22, 0.29), mats["black"]), "Head"),
        weight(timber((0, -0.90, 0.85), (0.13, -1.32, 1.06), 0.045, mats["skin"]), "Tail"),
    ]
    if production:
        parts.append(weight(stone((0, 1.25, 0.47), (0.58, 0.77, 0.25), mats["skin"], detail=1), "Jaw"))
    for y, height, width in [(0.53, 1.42, 0.98), (0.16, 1.51, 1.06), (-0.27, 1.49, 0.99), (-0.66, 1.38, 0.86)]:
        parts.append(weight(stone((0, y, height), (width, 0.52, 0.34), mats["plate"], 0.08, detail=1), "Body"))
        parts.append(weight(stone((0, y, height + 0.18), (0.24, 0.36, 0.25), mats["chalk"], 0.14), "Body"))
    for name, origin, end in legs:
        parts.append(weight(timber(origin, end, 0.137, mats["skin"]), name))
        parts.append(weight(stone(end, (0.26, 0.33, 0.20), mats["black"]), name))
    for sign in [-1, 1]:
        parts += [
            weight(timber((sign * 0.30, 1.18, 0.56), (sign * 0.48, 1.57, 0.79), 0.105, mats["bone"]), "Head"),
            weight(timber((sign * 0.47, 1.56, 0.76), (sign * 0.44, 1.77, 1.04), 0.064, mats["bone"], True), "Head"),
            weight(stone((sign * 0.36, 1.04, 0.97), (0.11, 0.15, 0.12), mats["eye"]), "Head"),
            weight(timber((sign * 0.30, 0.56, 1.15), (sign * 0.50, 0.37, 1.50), 0.10, mats["bark"], True), "Head"),
        ]
    export_creature(output, "slateback_boar", parts, armature, production)


def reedjaw(output, production=False):
    mats = reset()
    legs = []
    for side, label in [(1, "L"), (-1, "R")]:
        legs.extend([(f"Fore.{label}", (side * 0.32, 0.48, 0.43), (side * 0.75, 0.64, 0.08)),
                     (f"Hind.{label}", (side * 0.36, -0.63, 0.43), (side * 0.72, -0.55, 0.075))])
    armature = creature_bones(0.48, legs, ((0, 0.58, 0.53), (0, 1.47, 0.45)),
                              ((0, -0.82, 0.45), (0.12, -1.88, 0.16)),
                              ((0, 0.9, 0.35), (0, 1.83, 0.29)) if production else None)
    parts = [
        weight(stone((0, 0.01, 0.48), (1.04, 2.09, 0.81), mats["fen"], detail=1), "Body"),
        weight(stone((0, 0.56, 0.35), (0.79, 1.07, 0.43), mats["throat"], detail=1), "Body"),
        weight(stone((0, 0.97, 0.59), (0.92, 1.12, 0.58), mats["fen"], detail=1), "Head"),
        weight(stone((0, 1.36, 0.43), (0.84, 1.11, 0.26), mats["ridge"], detail=1), "Head"),
        weight(stone((0, 1.38, 0.31), (0.76, 0.91, 0.21), mats["throat"], detail=1), "Jaw" if production else "Head"),
        weight(timber((0, -0.71, 0.47), (0.13, -1.54, 0.24), 0.23, mats["ridge"]), "Tail"),
        weight(timber((0.12, -1.42, 0.27), (0.53, -2.15, 0.23), 0.103, mats["fen"], True), "Tail"),
    ]
    for y, height in [(0.63, 0.92), (0.37, 0.98), (0.07, 0.99), (-0.24, 0.93), (-0.55, 0.87)]:
        parts.append(weight(stone((0, y, height - 0.11), (0.27, 0.31, 0.42), mats["ridge"], 0.13), "Body"))
    for name, origin, end in legs:
        midpoint = Vector(origin).lerp(Vector(end), 0.53)
        midpoint.z += 0.03
        parts.append(weight(timber(origin, midpoint, 0.16, mats["fen"]), name))
        parts.append(weight(timber(midpoint, end, 0.10, mats["ridge"]), name))
        parts.append(weight(stone(end, (0.25, 0.35, 0.13), mats["fen"]), name))
    for sign in [-1, 1]:
        parts += [
            weight(stone((sign * 0.35, 1.11, 0.76), (0.26, 0.34, 0.29), mats["ridge"]), "Head"),
            weight(stone((sign * 0.43, 1.20, 0.78), (0.10, 0.14, 0.12), mats["eye"]), "Head"),
        ]
        for x, y in [(0.22, 1.72), (0.30, 1.53), (0.35, 1.33)]:
            parts.append(weight(timber((sign * x, y, 0.46), (sign * x, y + 0.035, 0.31),
                                       0.024, mats["bone"], True), "Head"))
    export_creature(output, "reedjaw", parts, armature, production)


def set_frames():
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 61


def export_gltf(path, animated=False, lights=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", export_apply=not animated,
        export_skins=animated, export_animations=animated, export_animation_mode="NLA_TRACKS",
        export_frame_range=False, export_lights=lights,
    )


def main():
    parser = argparse.ArgumentParser(description="Generate the six standalone asset samples.")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--production", action="store_true", help="Export campaign-ready buildings and wildlife to assets/models.")
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    output = options.out_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    buildings = output / "buildings"
    if options.production:
        export_building(buildings, "watchtower_stages", signal_tower, [(0, (2.65, 2.28, 3.02))], production=True)
        export_building(buildings, "storage_pit_stages", reed_granary, [(0, (3.10, 1.83, 2.47))], production=True)
        boar(output, production=True)
        reedjaw(output, production=True)
        return
    export_building(buildings, "ridge_signal_tower", signal_tower, [(0, (2.65, 2.28, 3.02))])
    export_building(buildings, "standing_stone_gate", stone_gate,
                    [(-1.25, (1.04, 1.05, 2.51)), (1.25, (1.04, 1.05, 2.51))])
    export_building(buildings, "reed_granary", reed_granary, [(0, (3.10, 1.83, 2.47))])
    scout(output)
    boar(output)
    reedjaw(output)


if __name__ == "__main__":
    main()
