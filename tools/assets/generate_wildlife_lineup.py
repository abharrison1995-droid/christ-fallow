"""Export Deer, Dire Wolf, Woolly Mammoth, and Giant Cave Bear."""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "examples"))
from generate_examples import creature_bones, export_gltf, human, join_and_rename, reset, set_frames, stone, timber, weight

PALETTES = {
    "deer": {"coat": (0.46, 0.245, 0.108), "belly": (0.74, 0.59, 0.36), "back": (0.28, 0.12, 0.05)},
    "dire_wolf": {"coat": (0.31, 0.32, 0.33), "belly": (0.58, 0.55, 0.48), "back": (0.13, 0.14, 0.16)},
    "mammoth": {"coat": (0.26, 0.128, 0.071), "belly": (0.19, 0.103, 0.067), "back": (0.39, 0.222, 0.133)},
    "cave_bear": {"coat": (0.23, 0.147, 0.098), "belly": (0.38, 0.25, 0.17), "back": (0.13, 0.077, 0.048)},
}

# Stance half-width, fore and hind sockets, hip height, head and tail joints, foot spread.
PROPORTIONS = {
    "deer": (0.20, 0.53, -0.58, 1.025, (0, 0.51, 1.15), (0, 1.15, 1.52), (0, -0.96, 1.045), (0, -1.23, 1.20), 0.035),
    "dire_wolf": (0.235, 0.48, -0.52, 0.81, (0, 0.50, 0.89), (0, 1.29, 0.94), (0, -0.79, 0.86), (0, -1.44, 0.45), 0.04),
    "mammoth": (0.56, 0.80, -0.91, 1.45, (0, 0.67, 1.73), (0, 1.43, 1.72), (0, -1.58, 1.48), (0, -1.95, 0.76), 0.11),
    "cave_bear": (0.43, 0.67, -0.70, 1.14, (0, 0.65, 1.31), (0, 1.29, 1.17), (0, -1.13, 1.11), (0, -1.39, 0.97), 0.10),
}


def poly(parts, bone, point, dims, mat, angle=0.0, detail=1):
    parts.append(weight(stone(point, dims, mat, angle, detail), bone))


def rod(parts, bone, start, end, radius, mat):
    parts.append(weight(timber(start, end, radius, mat), bone))


def tapered_tail(parts, start, end, size, mats):
    mid = Vector(start).lerp(Vector(end), 0.60)
    rod(parts, "Tail", start, mid, size, mats["coat"])
    rod(parts, "Tail", mid, end, size * 0.64, mats["back"])


def deer(parts, mats):
    poly(parts, "Body", (0, -0.08, 1.09), (0.62, 1.76, 0.75), mats["coat"])
    poly(parts, "Body", (0, -0.52, 0.98), (0.54, 0.70, 0.46), mats["belly"])
    poly(parts, "Head", (0, 0.69, 1.22), (0.43, 0.74, 0.69), mats["coat"])
    poly(parts, "Head", (0, 1.02, 1.49), (0.41, 0.61, 0.42), mats["coat"])
    poly(parts, "Head", (0, 1.26, 1.42), (0.26, 0.27, 0.22), mats["black"])
    poly(parts, "Tail", (0, -1.13, 1.12), (0.25, 0.31, 0.18), mats["belly"], detail=0)
    for sign in (-1, 1):
        rod(parts, "Head", (sign * 0.16, 0.95, 1.58), (sign * 0.39, 0.85, 1.73), 0.071, mats["coat"])
        joint = (sign * 0.24, 0.84, 1.92)
        rod(parts, "Head", (sign * 0.11, 0.91, 1.63), joint, 0.045, mats["bone"])
        rod(parts, "Head", joint, (sign * 0.39, 0.60, 2.15), 0.027, mats["bone"])
        rod(parts, "Head", joint, (sign * 0.25, 1.01, 2.08), 0.024, mats["bone"])
        poly(parts, "Head", (sign * 0.171, 1.12, 1.52), (0.071, 0.09, 0.077), mats["eye"], detail=0)
        for index in range(4):
            poly(parts, "Body", (sign * (0.28 - index * 0.011), -0.53 + index * 0.22, 1.22 + 0.036 * (index % 2)),
                 (0.09, 0.16, 0.095), mats["belly"], detail=0)


def dire_wolf(parts, mats):
    poly(parts, "Body", (0, -0.10, 0.86), (0.68, 1.67, 0.64), mats["coat"])
    poly(parts, "Body", (0, 0.46, 0.98), (0.79, 0.75, 0.78), mats["back"])
    poly(parts, "Head", (0, 0.83, 1.00), (0.56, 0.75, 0.54), mats["coat"])
    poly(parts, "Head", (0, 1.25, 0.88), (0.37, 0.64, 0.29), mats["coat"])
    poly(parts, "Head", (0, 1.53, 0.9), (0.234, 0.25, 0.16), mats["black"])
    poly(parts, "Jaw", (0, 1.14, 0.74), (0.34, 0.67, 0.17), mats["belly"])
    tapered_tail(parts, (0, -0.78, 0.88), (0.12, -1.53, 0.36), 0.127, mats)
    for sign in (-1, 1):
        rod(parts, "Head", (sign * 0.17, 0.77, 1.16), (sign * 0.27, 0.72, 1.43), 0.096, mats["back"])
        poly(parts, "Head", (sign * 0.239, 1.02, 1.04), (0.09, 0.115, 0.076), mats["eye"], detail=0)
        rod(parts, "Head", (sign * 0.124, 1.31, 0.81), (sign * 0.121, 1.31, 0.74), 0.024, mats["bone"])


def mammoth(parts, mats):
    poly(parts, "Body", (0, -0.30, 1.45), (1.67, 3.07, 1.83), mats["coat"])
    poly(parts, "Body", (0, 0.53, 1.84), (1.70, 1.62, 1.97), mats["back"])
    poly(parts, "Head", (0, 1.19, 1.71), (1.15, 1.19, 1.22), mats["coat"])
    trunk = [(0, 1.62, 1.60), (0, 1.94, 1.15), (0.10, 2.04, 0.61), (0.20, 2.17, 0.46)]
    for start, end, width in zip(trunk, trunk[1:], (0.283, 0.207, 0.130)):
        rod(parts, "Jaw", start, end, width, mats["coat"])
    tapered_tail(parts, (0, -1.49, 1.48), (0.07, -1.99, 0.58), 0.077, mats)
    for sign in (-1, 1):
        poly(parts, "Head", (sign * 0.50, 1.03, 1.74), (0.34, 0.56, 0.50), mats["belly"], sign * 0.39)
        poly(parts, "Head", (sign * 0.47, 1.55, 1.80), (0.113, 0.14, 0.112), mats["black"], detail=0)
        tusk = [(sign * 0.34, 1.44, 1.31), (sign * 0.56, 1.79, 0.89), (sign * 0.71, 2.16, 0.77),
                (sign * 0.73, 2.42, 1.04), (sign * 0.64, 2.54, 1.34)]
        for start, end, width in zip(tusk, tusk[1:], (0.155, 0.130, 0.103, 0.055)):
            rod(parts, "Head", start, end, width, mats["bone"])
        for index in range(4):
            y = -1.24 + index * 0.53
            poly(parts, "Body", (sign * 0.61, y, 1.16 + 0.12 * (index % 2)), (0.48, 0.70, 0.71),
                 mats["back" if index % 2 else "coat"], sign * 0.21, 0)


def cave_bear(parts, mats):
    poly(parts, "Body", (0, -0.26, 1.18), (1.37, 2.38, 1.44), mats["coat"])
    poly(parts, "Body", (0, 0.49, 1.39), (1.47, 1.19, 1.45), mats["back"])
    poly(parts, "Head", (0, 1.03, 1.33), (0.96, 0.98, 0.77), mats["coat"])
    poly(parts, "Head", (0, 1.48, 1.14), (0.59, 0.70, 0.40), mats["belly"])
    poly(parts, "Head", (0, 1.77, 1.18), (0.41, 0.29, 0.23), mats["black"], detail=0)
    poly(parts, "Jaw", (0, 1.34, 1.00), (0.58, 0.68, 0.23), mats["coat"])
    poly(parts, "Tail", (0, -1.39, 1.10), (0.25, 0.32, 0.23), mats["coat"])
    for sign in (-1, 1):
        poly(parts, "Head", (sign * 0.38, 0.96, 1.67), (0.30, 0.24, 0.33), mats["back"])
        poly(parts, "Head", (sign * 0.342, 1.35, 1.43), (0.10, 0.12, 0.10), mats["eye"], detail=0)
        for x in (-0.092, 0.0, 0.092):
            rod(parts, "Fore.L" if sign > 0 else "Fore.R", (sign * 0.51 + x, 0.75, 0.07),
                (sign * 0.51 + x, 0.88, 0.044), 0.026, mats["bone"])


def add_clip(rig, name, frames, sample, loop=False):
    data = rig.animation_data
    action = bpy.data.actions.new(name + ("-loop" if loop else ""))
    data.action = action
    action.use_cyclic = loop
    for i in range(0, frames + 1, 2):
        turns, rise = sample(i / frames)
        for bone in rig.pose.bones:
            bone.rotation_mode = "QUATERNION"
            human.pose_rotation(bone, *turns.get(bone.name, (0.0, 0.0, 0.0)))
            bone.keyframe_insert(data_path="rotation_quaternion", frame=i + 1)
        body = rig.pose.bones["Body"]
        body.location = body.bone.matrix_local.to_quaternion().inverted() @ Vector((0, 0, rise))
        body.keyframe_insert(data_path="location", frame=i + 1)
    human._finalize_action(rig, action)


def gait(t, legs, amount, bounds):
    phase = math.tau * t
    sway = math.sin(phase)
    posed = {"Body": (0.03 * sway, 0.04 * sway, 0), "Head": (0.075 * sway, 0, 0), "Tail": (0, 0, 0.18 * sway)}
    for name, _, _ in legs:
        offset = (math.pi if name.startswith("Hind") else 0) + (0.26 if name.endswith(".R") else 0) if bounds else (
            math.pi if name in ("Fore.R", "Hind.L") else 0)
        posed[name] = (amount * math.cos(phase + offset), 0, 0)
    return posed, 0.025 * sway * sway + (0.12 * max(0.0, sway) if bounds else 0.0)


def attack(t, name):
    impact = (1.0 - t) ** 2
    if name == "Stomp":
        return {"Body": (0.24 * impact, 0, 0), "Head": (0.32 * impact, 0, 0), "Jaw": (0.55 * impact, 0, 0),
                "Fore.L": (0.29 * impact, 0, 0), "Fore.R": (0.29 * impact, 0, 0)}, -0.11 * impact
    if name == "Swipe":
        return {"Body": (-0.19 * impact, 0, -0.27 * impact), "Head": (0.20 * impact, 0, 0.36 * impact),
                "Fore.R": (-0.53 * impact, 0.39 * impact, 0.13 * impact), "Jaw": (-0.48 * impact, 0, 0)}, 0.09 * impact
    return {"Body": (0.21 * impact, 0, 0), "Head": (0.40 * impact, 0, 0), "Jaw": (-0.40 * impact, 0, 0),
            "Fore.L": (0.18 * impact, 0, 0), "Fore.R": (-0.18 * impact, 0, 0)}, 0.025 * impact


def build(output, name, sculpt, attack_name):
    mats = reset()
    for label, color in PALETTES[name].items():
        mats[label] = human.material("Mat_" + label.title(), color, 0.95)
    width, fore, hind, height, head, muzzle, tail, tail_tip, spread = PROPORTIONS[name]
    heavy = name in ("mammoth", "cave_bear")
    legs = [(f"{pair}.{label}", (sign * width, y, height), (sign * (width + spread), y + 0.07, 0.13 if heavy else 0.095))
            for pair, y in [("Fore", fore), ("Hind", hind)] for sign, label in [(1, "L"), (-1, "R")]]
    rig = creature_bones(height, legs, (head, muzzle), (tail, tail_tip), (head, muzzle) if attack_name else None)
    parts = []
    sculpt(parts, mats)
    for bone, origin, end in legs:
        mid = Vector(origin).lerp(Vector(end), 0.54)
        mid.y += 0.10 if bone.startswith("Hind") else -0.02
        radius = width * (0.65 if heavy else 0.46)
        rod(parts, bone, origin, mid, radius, mats["coat"])
        rod(parts, bone, mid, end, radius * (0.84 if heavy else 0.57), mats["coat"] if heavy else mats["back"])
        poly(parts, bone, end, (radius * 2.0, radius * 2.5, end[2] * 2.0), mats["belly"] if heavy else mats["black"], detail=0)
    model = join_and_rename(parts, "WildlifeMesh")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    model.parent = rig
    model.modifiers.new("SkeletonDeform", "ARMATURE").object = rig
    set_frames()
    rig.animation_data_create()
    add_clip(rig, "Idle", 60, lambda t: gait(t, legs, 0.0, False), True)
    add_clip(rig, "Walk", 34 if heavy else 26, lambda t: gait(t, legs, 0.37 if heavy else 0.47, False), True)
    if not heavy:
        add_clip(rig, "Run", 18, lambda t: gait(t, legs, 0.78, True), True)
    if attack_name:
        add_clip(rig, attack_name, 20 if heavy else 12, lambda t: attack(t, attack_name))
    export_gltf(output / "wildlife" / f"{name}.glb", animated=True)


BATCHES = {"woodland": [("deer", deer, ""), ("dire_wolf", dire_wolf, "Bite")],
           "megafauna": [("mammoth", mammoth, "Stomp"), ("cave_bear", cave_bear, "Swipe")]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--batch", required=True, choices=BATCHES)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for creature, sculpt, clip in BATCHES[args.batch]:
        build(args.out_dir, creature, sculpt, clip)
