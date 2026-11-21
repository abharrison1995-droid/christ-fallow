"""Export modular Stone Age gear and shared class-specific attack clips."""

import argparse
import math
import sys
from pathlib import Path

import bpy

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_crag_born import PilotMesh, body, head, limbs, export
from generate_tribesman_rig import make_armature, pose_rotation, _finalize_action, _insert_frame, _reset_pose


def blade(mesh):
    mesh.bar((0, 0, -0.18), (0, 0, 0.14), 0.044, "leather")
    mesh.plate([(-0.062, 0, 0.06), (0.018, 0, 0.059), (0.132, 0, 0.25),
                (0.056, 0, 0.59), (-0.072, 0, 0.282)], 0.032, "flint", "edge")
    mesh.bar((-0.058, 0, 0.119), (0.057, 0, 0.119), 0.037, "bone")


def sheaths(mesh):
    for x, slant in [(-0.122, 0.11), (0.102, -0.11)]:
        mesh.tube([((x, -0.016, -0.36), 0.052, 0.035, "Chest"),
                   ((x + slant, 0, 0.24), 0.069, 0.043, "Chest"),
                   ((x + slant * 1.04, 0.003, 0.29), 0.079, 0.049, "Chest")],
                  ["hide", "trim"], sides=6)


def bow(mesh):
    mesh.tube([((0.08, 0, -0.67), 0.019, 0.022, "Chest"), ((-0.05, 0, -0.51), 0.032, 0.028, "Chest"),
               ((0, 0, 0), 0.048, 0.038, "Chest"), ((-0.05, 0, 0.51), 0.032, 0.028, "Chest"),
               ((0.08, 0, 0.67), 0.019, 0.022, "Chest")], ["wood"] * 4, sides=7)
    mesh.bar((0.08, 0, -0.66), (0.08, 0, 0.66), 0.009, "straw", sides=5)
    mesh.bar((0, 0, -0.11), (0, 0, 0.11), 0.056, "leather")


def arrow(mesh):
    mesh.bar((0, 0, -0.33), (0, 0, 0.46), 0.016, "wood")
    mesh.plate([(0, 0, 0.58), (-0.047, 0, 0.423), (0.049, 0, 0.423)], 0.018, "flint", "edge")
    mesh.plate([(-0.051, 0, -0.345), (0.048, 0, -0.29), (0.027, 0, -0.15), (-0.038, 0, -0.18)],
               0.011, "bone", "straw")


def quiver(mesh):
    mesh.tube([((0.12, 0.0, -0.39), 0.080, 0.052, "Chest"), ((0.015, 0.005, 0.17), 0.105, 0.080, "Chest"),
               ((-0.008, 0, 0.27), 0.12, 0.09, "Chest")], ["hide", "trim"], sides=8)
    for x, z in [(-0.084, 0.47), (0.014, 0.4), (0.086, 0.44)]:
        mesh.bar((x + 0.04, 0.004, 0.14), (x, 0.015, z), 0.018, "wood")
        mesh.bar((x, 0.015, z - 0.11), (x, 0.015, z), 0.03, "bone")


def maul(mesh):
    mesh.bar((0, 0, -0.32), (0, 0, 0.73), 0.058, "wood", sides=8)
    mesh.bar((0, 0, -0.15), (0, 0, 0.13), 0.066, "leather")
    mesh.tube([((0.0, 0.0, 0.56), 0.099, 0.078, "Chest"), ((-0.042, 0, 0.74), 0.20, 0.132, "Chest"),
               ((-0.040, 0, 0.96), 0.13, 0.114, "Chest")], ["flint", "flint"], sides=7)
    for x in (-0.14, 0.14):
        mesh.bar((x * 0.6, 0.111, 0.708), (x, 0.122, 0.865), 0.043, "bone")


def trophies(mesh):
    mesh.bar((-0.237, -0.018, 0.09), (0.237, -0.018, 0.16), 0.04, "wood")
    for i, x in enumerate((-0.17, 0.0, 0.18)):
        mesh.bar((x, -0.025, 0.126 + x * 0.16), (x + 0.03, -0.042, -0.17 + 0.03 * i), 0.048, "bone")
    mesh.bar((-0.19, -0.053, 0.065), (0.19, -0.053, 0.13), 0.035, "trim")


def javelin(mesh):
    mesh.bar((0, 0, -0.66), (0, 0, 0.80), 0.026, "wood")
    mesh.bar((0, 0, -0.097), (0, 0, 0.14), 0.035, "leather")
    mesh.plate([(0.0, 0.0, 1.011), (-0.078, 0.0, 0.771), (-0.014, 0.0, 0.816),
                (0.070, 0.0, 0.752)], 0.018, "flint", "edge")


def bundle(mesh):
    for i, x in enumerate((-0.078, 0.005, 0.089)):
        offset = 0.095 * i
        mesh.bar((x - 0.21, 0, -0.56 + offset), (x + 0.17, 0, 0.57 + offset), 0.025, "wood")
        mesh.bar((x + 0.148, 0, 0.50 + offset), (x + 0.214, 0, 0.69 + offset), 0.036, "flint")
    mesh.bar((-0.139, -0.028, -0.05), (0.12, -0.03, 0.116), 0.052, "trim")


COMBAT_GEAR = {
    "knife_raider": {"dirk": blade, "sheaths": sheaths},
    "archer": {"bow": bow, "arrow": arrow, "quiver": quiver},
    "brute": {"flint_maul": maul, "trophy_rack": trophies},
    "javelineer": {"barbed_javelin": javelin, "javelin_bundle": bundle},
}

# The game applies contact or launches a projectile when it starts the action.
# These poses start at contact and animate the follow-through and recovery.
COMBAT_POSES = {
    "KnifeSlash": (12, {"Chest": (-0.12, 0.0, -0.58), "UpperArm.R": (1.25, -0.42, 0.58),
                        "LowerArm.R": (0.56, 0.03, 0.28), "UpperArm.L": (0.58, 0.50, -0.56),
                        "LowerArm.L": (1.15, 0.0, -0.26)}),
    "BowRelease": (11, {"Chest": (0.04, -0.06, -0.45), "Head": (0.0, 0.01, 0.38),
                         "UpperArm.L": (1.31, 0.14, -0.18), "LowerArm.L": (0.17, 0.0, 0.04),
                         "UpperArm.R": (1.04, -0.58, 0.46), "LowerArm.R": (1.71, 0.0, 0.16)}),
    "ClubSmash": (13, {"Chest": (-0.58, 0.0, -0.24), "Head": (0.29, 0.0, 0.0),
                        "UpperArm.R": (1.49, 0.12, -0.20), "LowerArm.R": (0.36, 0.0, 0.21),
                        "UpperArm.L": (0.59, -0.14, -0.36), "LowerArm.L": (0.77, 0.0, 0.02)}),
    "JavelinCast": (12, {"Chest": (-0.27, -0.13, -0.64), "Head": (0.06, 0.04, 0.42),
                          "UpperArm.R": (1.71, 0.05, 0.27), "LowerArm.R": (0.19, -0.05, 0.29),
                          "UpperArm.L": (0.81, 0.33, -0.28), "LowerArm.L": (0.83, 0.0, 0.0)}),
}


def build_role_moves(root, filename, poses):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = make_armature()
    # Include a bound reference mesh so the GLB imports the same skeleton paths as the bodies.
    mesh = PilotMesh()
    body(mesh, "broad", "crag_born")
    head(mesh, "broad", "crag_born")
    limbs(mesh, "broad", "crag_born")
    mesh.build(armature)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_end = 61
    data = armature.animation_data_create()
    hips = armature.pose.bones["Hips"]
    for name, (frames, contact) in poses.items():
        data.action = bpy.data.actions.new(name)
        for i in range(frames + 1):
            t = i / frames
            amount = 1.0 - t * t * (3.0 - 2.0 * t)
            _reset_pose(armature)
            for bone, angles in contact.items():
                pose_rotation(armature.pose.bones[bone], *(angle * amount for angle in angles))
            pose_rotation(armature.pose.bones["UpperLeg.L"], pitch=0.22 * amount)
            pose_rotation(armature.pose.bones["LowerLeg.L"], pitch=-0.25 * amount)
            _insert_frame(armature, hips, 0.0, 0.06 * amount, -0.10 * amount, i + 1)
        _finalize_action(armature, data.action)
    bpy.context.scene.frame_set(1)
    export(root / "characters" / "moves" / f"{filename}.glb", True)


def build_gear(root, kits):
    for kit, items in kits.items():
        for name, build in items.items():
            bpy.ops.wm.read_factory_settings(use_empty=True)
            mesh = PilotMesh()
            build(mesh)
            mesh.build_mesh(name)
            export(root / "gear" / kit / f"{name}.glb", False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    root = args.out_dir.resolve()
    build_gear(root, COMBAT_GEAR)
    build_role_moves(root, "combat", COMBAT_POSES)
