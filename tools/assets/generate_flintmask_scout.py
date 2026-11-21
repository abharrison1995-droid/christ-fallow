"""Export the campaign Flintmask Scout body and hooked club."""

import argparse
import math
import sys
from pathlib import Path

import bpy

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_crag_born import PilotMesh, body, head, limbs, export
from generate_role_kits import build_gear
from generate_tribesman_rig import animate, animate_action_clips, make_armature


def club(mesh):
    mesh.tube([((0, 0, -0.17), 0.041, 0.039, "Chest"), ((0, 0, 0.13), 0.043, 0.043, "Chest"),
               ((0.038, 0, 0.52), 0.069, 0.059, "Chest"), ((0.108, 0.008, 0.68), 0.103, 0.081, "Chest"),
               ((0.211, 0.013, 0.61), 0.061, 0.052, "Chest")], ["leather", "wood", "wood", "wood"], sides=7)
    mesh.plate([(0.095, 0.028, 0.59), (0.111, 0.036, 0.73), (0.267, 0.045, 0.665),
                (0.227, 0.045, 0.50)], 0.044, "flint", "edge")


def mask(mesh):
    mesh.plate([(-0.119, 0.124, 1.782), (-0.043, 0.163, 1.822), (0.102, 0.134, 1.775),
                (0.095, 0.149, 1.646), (0.022, 0.178, 1.567), (-0.084, 0.145, 1.632)],
               0.029, "flint", "edge", "Head")
    for side in (-1, 1):
        mesh.bar((side * 0.043, 0.192, 1.731), (side * 0.086, 0.166, 1.750), 0.016, "bone", "Head")
        mesh.bar((side * 0.09, 0.106, 1.709), (side * 0.138, -0.052, 1.748), 0.025, "leather", "Head")
    mesh.bar((-0.023, 0.199, 1.692), (0.026, 0.188, 1.647), 0.026, "trim", "Head")


def build_scout(models):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = make_armature()
    mesh = PilotMesh("stalker")
    body(mesh, "cropped", "stalker")
    head(mesh, "cropped", "stalker")
    mask(mesh)
    limbs(mesh, "braided", "stalker")
    mesh.build(armature)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_end = 61
    armature.animation_data_create()
    hunch = math.radians(-8.0)
    animate(armature, "Idle", 60, hunch=hunch)
    animate(armature, "Walk", 24, walking=True, hunch=hunch)
    animate(armature, "GuardIdle", 60, guard=True, hunch=hunch)
    animate(armature, "GuardWalk", 24, walking=True, guard=True, hunch=hunch)
    animate_action_clips(armature, hunch=hunch)
    bpy.context.scene.frame_set(1)
    export(models / "characters" / "archetypes" / "flintmask_scout.glb", True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    build_scout(args.out_dir)
    build_gear(args.out_dir, {"flintmask_scout": {"hooked_club": club}})
