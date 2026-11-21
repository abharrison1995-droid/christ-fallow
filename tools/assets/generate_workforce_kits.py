"""Export the six workforce kits on the shared hand and chest mounts."""

import argparse
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_role_kits import build_gear, build_role_moves


def axe(mesh):
    mesh.bar((0, 0, -0.25), (0, 0, 0.54), 0.045, "wood")
    mesh.plate([(-0.055, 0, 0.36), (0.16, 0, 0.27), (0.24, 0, 0.47), (0.14, 0, 0.66),
                (-0.05, 0, 0.54)], 0.044, "flint", "edge")
    mesh.bar((0, 0, 0.33), (0, 0, 0.54), 0.063, "leather")


def pick(mesh):
    mesh.bar((0, 0, -0.26), (0, 0, 0.51), 0.042, "wood")
    mesh.plate([(-0.26, 0, 0.38), (-0.09, 0, 0.50), (0.12, 0, 0.50), (0.25, 0, 0.40),
                (0.08, 0, 0.43), (-0.06, 0, 0.41)], 0.049, "flint", "edge")
    mesh.bar((0, 0, 0.32), (0, 0, 0.49), 0.061, "leather")


def mallet(mesh):
    mesh.bar((0, 0, -0.25), (0, 0, 0.42), 0.042, "wood")
    mesh.bar((-0.16, 0, 0.40), (0.17, 0, 0.43), 0.101, "flint")
    mesh.bar((0, 0, 0.315), (0, 0, 0.51), 0.061, "leather")


def adze(mesh):
    mesh.bar((0, 0, -0.16), (0, 0, 0.33), 0.036, "wood")
    mesh.plate([(-0.06, 0, 0.32), (0.05, 0, 0.30), (0.14, 0, 0.21), (0.12, 0, 0.15)],
               0.033, "flint", "edge")


def timber_pack(mesh):
    for i, x in enumerate((-0.14, 0.0, 0.14)):
        mesh.bar((x - 0.065, 0, -0.29), (x + 0.063, 0.012, 0.30 + i * 0.04), 0.076, "wood")
    for z in (-0.16, 0.19):
        mesh.bar((-0.18, -0.06, z), (0.185, -0.06, z + 0.06), 0.035, "trim")


def satchel(mesh):
    mesh.tube([((0, 0, -0.27), 0.132, 0.083, "Chest"), ((0, 0.016, -0.12), 0.215, 0.123, "Chest"),
               ((0, 0, 0.11), 0.186, 0.102, "Chest"), ((0, 0, 0.17), 0.13, 0.074, "Chest")],
              ["hide", "leather", "trim"], sides=8)
    for x in (-0.105, 0.037, 0.117):
        mesh.bar((x, 0.01, 0.11), (x + 0.02, -0.02, 0.224), 0.043, "flint", sides=5)


def pelt(mesh):
    mesh.plate([(-0.19, 0.13, 0.14), (-0.12, 0.16, -0.22), (0.15, 0.11, -0.185),
                (0.21, 0.08, 0.15), (0.08, 0.07, 0.25)], 0.041, "fur", "hide")
    mesh.bar((-0.139, 0.17, 0.09), (0.116, 0.144, 0.15), 0.037, "trim")
    for x in (-0.035, 0.039, 0.106):
        mesh.bar((x, 0.168, 0.12), (x + 0.014, 0.17, 0.06), 0.024, "bone")


def staff(mesh):
    mesh.bar((0, 0, -0.60), (0, 0, 0.51), 0.043, "wood")
    mesh.bar((0, 0, -0.15), (0, 0, 0.11), 0.054, "leather")
    mesh.plate([(-0.13, 0, 0.50), (0.13, 0, 0.47), (0.1, 0, 0.65), (0.01, 0, 0.70),
                (-0.08, 0, 0.63)], 0.057, "bone", "trim")
    for side in (-1, 1):
        mesh.bar((side * 0.083, 0, 0.60), (side * 0.18, 0, 0.76), 0.035, "bone")


def charm(mesh):
    mesh.bar((0, 0, -0.12), (0, 0, 0.15), 0.039, "leather")
    mesh.plate([(-0.12, 0, 0.055), (0.11, 0, 0.07), (0.05, 0, 0.23), (-0.02, 0, 0.27)],
               0.035, "bone", "trim")


def sparring_spear(mesh):
    mesh.bar((0, 0, -0.53), (0, 0, 0.72), 0.038, "wood")
    mesh.bar((0, 0, 0.56), (0, 0, 0.72), 0.074, "hide", sides=8)
    mesh.bar((0, 0, -0.09), (0, 0, 0.09), 0.055, "trim")


GEAR = {
    "hunter": {"pelt_capelet": pelt},
    "lumberjack": {"axe": axe, "timber_pack": timber_pack},
    "stoneknapper": {"pick": pick, "stone_satchel": satchel},
    "builder_crafter": {"mallet": mallet, "adze": adze},
    "shaman": {"spirit_staff": staff, "ritual_charm": charm},
    "trainee": {"sparring_spear": sparring_spear},
}
POSES = {
    "ShamanCast": (17, {"Chest": (0.12, 0.04, 0.20), "Head": (-0.15, 0.0, -0.13),
                        "UpperArm.R": (1.06, -0.77, 0.12), "LowerArm.R": (0.74, -0.15, 0.03),
                        "UpperArm.L": (1.17, 0.49, -0.39), "LowerArm.L": (0.89, 0.08, 0.08)}),
}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    build_gear(args.out_dir, GEAR)
    build_role_moves(args.out_dir, "specialist", POSES)
