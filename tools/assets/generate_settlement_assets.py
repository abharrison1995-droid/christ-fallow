"""Export the remaining four-stage settlement buildings in three production batches."""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "examples"))
from generate_examples import box_part, export_gltf, join_and_rename, mesh_part, reset, stone, timber, upright

STAGES = ("Stage_Intact", "Stage_Damaged", "Stage_Critical", "Stage_Rubble")


def debris(mats, size=1.0):
    parts = []
    for i in range(7):
        a = i * 2.4
        r = (0.34 + i * 0.14) * size
        parts.append(stone((math.cos(a) * r, math.sin(a) * r, 0.075),
                           (0.30 + 0.04 * (i % 3), 0.29, 0.14 + (i % 2) * 0.10),
                           mats["stone" if i % 3 else "char"], a))
    return parts


def campfire(stage, mats):
    parts = [stone((0, 0, 0.04), (1.76, 1.71, 0.13), mats["char"])]
    for i in range(11 - stage * 2):
        a = i * math.tau / 11
        parts.append(stone((0.90 * math.cos(a), 0.86 * math.sin(a), 0.13 - stage * 0.025),
                           (0.58, 0.40, 0.37 - stage * 0.055), mats["stone"], a))
    for i in range(4 - stage):
        a = i * 0.94
        dx, dy = math.cos(a) * 0.63, math.sin(a) * 0.63
        parts.append(timber((-dx, -dy, 0.16), (dx * 0.64, dy * 0.64, 0.28 - stage * 0.025),
                            0.094, mats["bark" if i % 2 and stage == 0 else "char"], stage > 0))
    return parts


def shelter(mats, stage, size, raised=False):
    if stage == 3:
        return debris(mats)
    w, d, height = size
    beam = mats["bark" if stage != 2 else "char"]
    left = height * (0.61 if stage == 2 else 1.0)
    right = height * (0.39 if stage == 2 else 0.88 if stage else 1.0)
    ridge = (left + right) * 0.48
    parts = [timber((x, y, 0.03), (x * 0.95, y, level), 0.106, beam, stage > 0)
             for x, level in [(-w, left), (w, right)] for y in (-d, d if raised else d * 0.82)]
    parts.append(timber((-w, d, left), (w, d, right), 0.096, beam, stage > 0))
    front = -d * (0.27 if stage == 1 else -0.32 if stage == 2 else 1.10)
    for side in (-1, 1):
        edge = side * w * 1.12
        corners = [(edge, front, (left if side < 0 else right) - 0.14),
                   (edge, d * 1.10, (left if side < 0 else right) - 0.09),
                   (0, d * 1.07, ridge + 0.44), (0, front * (0.68 if stage == 1 else 1.0), ridge + 0.37)]
        parts.append(mesh_part("Hide canopy", corners, [(0, 1, 2, 3), (3, 2, 1, 0)], mats["reed" if raised else "skin"]))
    parts.append(box_part((0, front, ridge + 0.21), (0.38, 0.06, 0.39), mats["trim"], (0, -0.19, 0)))
    return parts


def lodge(stage, mats):
    parts = shelter(mats, stage, (1.16, 0.89, 1.53), True)
    for i in range(3 - stage):
        x = (i - 1) * 0.65
        parts.append(box_part((x, 0.66, 0.86 - stage * 0.19), (0.46, 0.07, 0.68), mats["skin"], (0, x * 0.23, 0)))
        parts.append(stone((x, -0.64, 0.16), (0.38, 0.37, 0.31), mats["reed"]))
    return parts


def crafting_pit(stage, mats):
    parts = debris(mats, 0.75)
    if stage == 3:
        return parts
    parts.append(stone((0, 0.02, 0.16), (2.72, 1.65, 0.34), mats["earth"]))
    for i in range(4 - stage):
        x = -0.91 + i * 0.53
        parts.append(stone((x, 0.24, 0.33), (0.65, 0.64, 0.41), mats["chalk"], x * 0.74))
        parts.append(stone((x + 0.084, 0.25, 0.54), (0.32, 0.18, 0.075), mats["black"], x))
    for side in (-1, 1):
        parts.append(timber((side * 1.10, 0.86, 0), (side * 1.07, 0.81, 1.27 - stage * 0.43), 0.075, mats["oak"], stage > 0))
    parts.append(timber((-1.04, 0.83, 1.27 - stage * 0.43), (1.04, 0.83, 1.27 - stage * 0.43), 0.076, mats["oak"]))
    parts.append(box_part((0, 0.8, 1.03 - stage * 0.43), (0.44, 0.064, 0.49), mats["trim"]))
    return parts


def sacred_totem(stage, mats):
    parts = debris(mats, 0.70)
    if stage == 3:
        return parts + [timber((-0.95, -0.4, 0.12), (0.81, 0.28, 0.15), 0.20, mats["char"], True)]
    height = (3.05, 2.50, 1.42)[stage]
    parts.append(stone((0, 0, 0.17), (1.38, 1.30, 0.39), mats["chalk"]))
    parts.append(timber((0, 0, 0.06), (0.06 * stage, 0.009, height), 0.235, mats["oak" if stage < 2 else "char"], stage > 0))
    for z in (0.56, 1.08, 1.66, 2.21, 2.68):
        if z < height - 0.21:
            parts.append(box_part((0, -0.221, z), (0.34, 0.055, 0.29), mats["trim"], (0, math.pi / 4, 0)))
    if stage < 2:
        for side in (-1, 1):
            parts.append(timber((side * 0.10, 0.0, height - 0.57), (side * 0.55, -0.16, height - 0.08), 0.079, mats["bone"], True))
    return parts


def healing_shack(stage, mats):
    parts = shelter(mats, stage, (1.06, 0.94, 1.79), False)
    for i in range(3 - stage):
        x = -0.72 + i * 0.49
        parts.append(stone((x, -0.63, 0.15), (0.35, 0.27, 0.29), mats["lichen"]))
        parts.append(timber((x, -0.72, 0.13), (x + 0.04, -0.64, 0.50), 0.045, mats["reed"]))
    return parts


def weapon_rack(stage, mats):
    parts = debris(mats, 0.66) if stage else [box_part((0, 0, 0.10), (2.16, 0.68, 0.19), mats["oak"])]
    if stage == 3:
        return parts
    h = (1.86, 1.41, 0.73)[stage]
    for side in (-1, 1):
        parts.append(timber((side * 0.98, 0.19, 0.08), (side * 0.93, 0.16, h), 0.121, mats["bark"], stage > 0))
    parts.append(timber((-0.94, 0.13, h * 0.83), (0.92, 0.11, h * 0.78), 0.086, mats["oak"]))
    parts.append(box_part((-0.66, -0.01, h * 0.67), (0.36, 0.11, 0.38), mats["trim"]))
    for i in range(5 - stage * 2):
        x = -0.44 + i * 0.29
        parts.append(timber((x - 0.11, -0.15, 0.14), (x + 0.08, 0, h * 0.92), 0.041, mats["oak"]))
        parts.append(stone((x + 0.08, -0.013, h * 0.95), (0.15, 0.12, 0.28), mats["black"]))
    return parts


def barracks(stage, mats):
    parts = [stone((0, 0, 0.030), (3.65, 3.42, 0.091), mats["earth"])] + debris(mats, 0.82)
    if stage == 3:
        return parts
    h = (1.90, 1.46, 0.83)[stage]
    for x in (-1.06, 1.06):
        parts.append(timber((x, 0.63, 0), (x * 0.98, 0.60, h), 0.119, mats["bark"], stage > 0))
        parts.append(stone((x, 0.50, h * 0.59), (0.79, 0.22, 0.72), mats["reed"], x * 0.21))
        parts.append(stone((x, 0.36, h * 0.60), (0.35, 0.12, 0.34), mats["trim"]))
    parts.append(timber((-1.16, 0.68, h), (1.16, 0.68, h * 0.88), 0.084, mats["oak"], stage > 0))
    return parts


def crop_field(stage, mats):
    parts = [box_part((0, 0, 0.033), (3.70, 3.20, 0.072), mats["earth"])]
    for i in range((5, 5, 4, 3)[stage]):
        y = -1.29 + i * 0.63
        parts.append(stone((0, y, 0.09), (3.53 - stage * 0.36, 0.44, 0.16), mats["bark"], 0.026 * stage * (i - 2)))
    return parts + (debris(mats, 0.55) if stage >= 2 else [])


def animal_pen(stage, mats):
    parts = [box_part((0, 0, 0.035), (4.2, 3.77, 0.068), mats["earth"])]
    if stage == 3:
        return parts + debris(mats)
    h = (0.82, 0.70, 0.41)[stage]
    back, left, right = (0, 1.78), (-1.91, 0), (1.91, 0)
    for (x, y), (dx, dy) in [(back, (1.91, 0)), (left, (0, 1.76)), (right, (0, 1.76))]:
        for a in (-1, 0, 1):
            px, py = x + a * dx, y + a * dy
            parts.append(timber((px, py, 0), (px - 0.015, py, h + 0.16), 0.085, mats["bark"], stage > 0))
        for z in ([h * 0.53, h] if stage == 0 else [h * 0.72]):
            parts.append(timber((x - dx, y - dy, z), (x + dx, y + dy, z * (1.0 - stage * 0.14)), 0.063, mats["oak"], stage > 0))
    parts.append(box_part((0.81, 1.22, 0.23), (1.23, 0.57, 0.38), mats["reed"]))
    parts.append(box_part((0.81, 1.22, 0.43), (1.00, 0.36, 0.042), mats["straw" if stage == 0 else "char"]))
    parts.append(box_part((1.43, 1.19, 0.36), (0.08, 0.41, 0.16), mats["trim"]))
    return parts


def place(stage, node, point):
    node.parent = stage
    node.matrix_world = Matrix.Translation((-point[0], -point[1], point[2]))


def lamp(stage, name, point, color, energy):
    data = bpy.data.lights.new(name, "POINT")
    data.color = color
    # Blender's glTF point light exporter converts watts to candela.
    data.energy = energy * (4.0 * math.pi) / 683.0
    data.use_custom_distance = True
    data.cutoff_distance = 5.0
    node = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(node)
    place(stage, node, point)


def add_stage_details(kind, stage, index, mats):
    if kind == "campfire":
        mat = mats["coal"]
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Emission Color"].default_value = (1.0, 0.21, 0.028, 1.0)
        shader.inputs["Emission Strength"].default_value = 1.6
        flames = [stone((x, y, height * 0.39), (0.22, 0.20, height), mat, x * 3)
                  for x, y, height in [(-0.16, 0.06, 0.63), (0.02, 0.0, 0.92), (0.18, -0.06, 0.56)]]
        flame = join_and_rename(flames, "FlameMesh")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        place(stage, flame, (0.0, 0.0, 0.27 - index * 0.051))
        lamp(stage, "CampfireLight", (0.0, 0.0, 0.79), (1.0, 0.41, 0.12), (3.2, 2.2, 0.9)[index])
    elif kind == "shaman_shack":
        lamp(stage, "ShamanLight", (-0.42, -0.73, 0.92 - index * 0.16), (0.38, 0.80, 0.67), (2.1, 1.3, 0.6)[index])
    elif kind == "crop_field":
        growth = []
        for row in range(5 - index):
            for column in range(7 - index * 2):
                x, y = -1.44 + column * 0.48, -1.26 + row * 0.63
                h = 0.42 - 0.09 * index + ((row + column * 3) % 4) * 0.047
                tip = (x + 0.102, y - 0.08, h)
                growth.append(timber((x, y, 0.016), tip, 0.028, mats["reed"]))
                growth.append(stone(tip, (0.12, 0.10, 0.22), mats["straw"]))
        crops = join_and_rename(growth, "Crops")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        place(stage, crops, (0, 0, 0.13))


BUILDINGS = {
    "settlement": {"campfire": (campfire, 2.0), "forager_lodge": (lodge, 2.4), "crafting_pit": (crafting_pit, 2.3)},
    "warband": {"sacred_totem": (sacred_totem, 1.8), "shaman_shack": (healing_shack, 2.2),
                "weapon_rack": (weapon_rack, 1.6), "barracks": (barracks, 2.5)},
    "farm": {"crop_field": (crop_field, 2.6), "animal_pen": (animal_pen, 3.2)},
}


def build(output, kind, geometry, radius):
    mats = reset()
    for index, name in enumerate(STAGES):
        stage = join_and_rename(geometry(index, mats), name)
        stage.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ stage.matrix_world
        if index < 3:
            add_stage_details(kind, stage, index, mats)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius * 0.72, depth=2.5, location=(0, 0, 1.25))
    bpy.context.active_object.name = "Collider-convcolonly"
    export_gltf(output / "buildings" / f"{kind}_stages.glb", lights=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--batch", required=True, choices=BUILDINGS)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for kind, (geometry, radius) in BUILDINGS[args.batch].items():
        build(args.out_dir, kind, geometry, radius)
