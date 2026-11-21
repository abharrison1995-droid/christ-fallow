"""Export the shared lineage leader regalia and cleave clip."""

import argparse
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_role_kits import build_gear, build_role_moves


def great_spear(mesh):
    mesh.bar((0.0, 0, -0.72), (0.0, 0, 1.02), 0.038, "wood")
    mesh.bar((0.0, 0, -0.16), (0.0, 0, 0.16), 0.052, "leather")
    mesh.plate([(0.0, 0, 1.32), (-0.136, 0, 1.074), (-0.075, 0, 0.89),
                (0.10, 0, 0.93), (0.132, 0, 1.10)], 0.032, "flint", "edge")
    mesh.bar((-0.094, 0.023, 0.93), (0.079, 0.023, 0.93), 0.050, "bone")
    mesh.bar((-0.027, 0.018, 0.85), (-0.142, 0.023, 0.59), 0.044, "trim")


def crown(mesh):
    mesh.tube([((0, 0.006, 0.014), 0.161, 0.15, "Head"),
               ((0, 0.008, 0.074), 0.157, 0.142, "Head")], ["trim"], sides=10)
    mesh.plate([(0.0, 0.147, 0.189), (-0.058, 0.147, 0.093), (0.0, 0.147, 0.026),
                (0.06, 0.147, 0.093)], 0.021, "bone", "straw", "Head")
    for side in (-1, 1):
        mesh.tube([((side * 0.111, 0.054, 0.055), 0.049, 0.05, "Head"),
                   ((side * 0.151, 0.030, 0.109), 0.032, 0.033, "Head"),
                   ((side * 0.175, -0.023, 0.233), 0.004, 0.006, "Head")], ["bone", "bone"], sides=6)


def mantle(mesh):
    for side in (-1, 1):
        mesh.plate([(side * 0.012, 0, 0.18), (side * 0.227, -0.023, 0.19),
                    (side * 0.209, -0.041, -0.41), (side * 0.10, -0.021, -0.55)],
                   0.034, "trim", "hide")
        for i in range(3):
            x = side * (0.112 + 0.055 * i)
            mesh.bar((x, 0.005, 0.124), (x + side * 0.031, -0.013, 0.255 - i * 0.035), 0.041, "bone")


GEAR = {"leader": {"great_spear": great_spear, "bone_crown": crown, "split_mantle": mantle}}
POSES = {"LeaderCleave": (16, {"Chest": (-0.18, 0.04, -0.56), "Head": (0.08, 0.0, 0.26),
                              "UpperArm.R": (1.44, -0.30, 0.54), "LowerArm.R": (0.54, 0.17, 0.36),
                              "UpperArm.L": (0.64, 0.53, -0.38), "LowerArm.L": (0.58, 0.03, -0.29)})}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    build_gear(args.out_dir, GEAR)
    build_role_moves(args.out_dir, "leader", POSES)
