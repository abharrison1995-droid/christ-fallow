"""Generate six review prototypes in the Christ Fallow art style."""

import argparse
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "examples"))
from generate_examples import box_part, export_gltf, join_and_rename, reset, stone, timber


def beacon(m):
    parts = [stone((0, 0, 0.20), (1.22, 1.08, 0.44), m["lichen"]),
             timber((0, 0, 0.04), (0.02, -0.05, 2.51), 0.155, m["oak"], True)]
    for side in (-1, 1):
        start, elbow, tip = (side * 0.11, -0.04, 1.79), (side * 0.50, -0.023, 2.19), (side * 0.60, -0.12, 2.73)
        parts += [timber(start, elbow, 0.095, m["bone"]), timber(elbow, tip, 0.062, m["bone"], True),
                  timber(elbow, (side * 0.79, -0.25, 2.44), 0.049, m["bone"], True)]
    parts += [stone((0.01, -0.19, 2.14), (0.42, 0.18, 0.38), m["chalk"], 0.19),
              box_part((0.015, -0.29, 2.14), (0.24, 0.065, 0.25), m["mark"], (0, math.pi * 0.25, 0))]
    for i in range(4):
        parts.append(box_part((i * 0.033 - 0.05, -0.19, 1.15 - i * 0.19), (0.36, 0.086, 0.10), m["trim"], (0, i * 0.16, 0)))
    return parts


def weir(m):
    parts = []
    for side in (-1, 1):
        for i in range(6):
            x = side * (0.38 + i * 0.25)
            y = -0.36 + i * 0.39
            parts.append(timber((x, y, -0.08), (x, y, 0.78 + i * 0.025), 0.065, m["bark"], True))
        for row in range(4):
            h = 0.12 + row * 0.15
            parts.append(timber((side * 0.31, -0.37, h), (side * 1.69, 1.67, h + 0.05), 0.044, m["reed"]))
        parts.append(stone((side * 1.59, 1.60, 0.055), (0.62, 0.61, 0.32), m["lichen"]))
    for i in range(8):
        a = i * math.tau / 8
        x, y = 0.32 * math.cos(a), 0.33 * math.sin(a) - 0.51
        parts.append(timber((x, y, 0.11), (x * 0.83, y, 0.53), 0.039, m["straw"]))
    parts.append(box_part((0, -0.50, 0.08), (0.65, 0.68, 0.11), m["oak"]))
    return parts


def ibex(m):
    parts = [stone((0, -0.11, 1.10), (0.78, 1.81, 0.83), m["skin"], detail=1),
             stone((0, -0.14, 1.41), (0.60, 1.26, 0.27), m["lichen"], detail=1),
             stone((0, 0.44, 1.23), (0.74, 0.84, 0.86), m["bark"], detail=1),
             stone((0, 0.89, 1.53), (0.43, 0.61, 0.55), m["chalk"], detail=1),
             stone((0, 1.14, 1.42), (0.35, 0.29, 0.28), m["bark"])]
    for side in (-1, 1):
        for y in (-0.62, 0.58):
            knee = (side * 0.245, y + (0.08 if y < 0 else -0.06), 0.49)
            hoof = (side * 0.271, y + 0.01, 0.105)
            parts += [timber((side * 0.221, y, 1.04), knee, 0.101, m["skin"]),
                      timber(knee, hoof, 0.055, m["bark"]), stone(hoof, (0.17, 0.22, 0.18), m["black"])]
        arc = [(side * 0.11, 0.83, 1.71), (side * 0.196, 0.76, 2.04),
               (side * 0.24, 0.49, 2.20), (side * 0.27, 0.21, 2.07), (side * 0.26, 0.13, 1.84)]
        for p, q, rad in zip(arc, arc[1:], (0.105, 0.089, 0.065, 0.037)):
            parts.append(timber(p, q, rad, m["bone"]))
        parts.append(stone((side * 0.18, 1.01, 1.55), (0.085, 0.10, 0.081), m["eye"]))
    parts.append(timber((0, -0.83, 1.11), (0.08, -1.15, 1.13), 0.091, m["bark"]))
    return parts


def cache(m):
    parts = [stone((0, 0, 0.14), (2.39, 1.87, 0.29), m["lichen"])]
    for i in range(9):
        angle = i * math.tau / 9
        parts.append(stone((0.83 * math.cos(angle), 0.69 * math.sin(angle), 0.22),
                           (0.48, 0.36, 0.41), m["black"] if i % 3 else m["chalk"], angle))
    parts += [box_part((0.0, 0.02, 0.45), (1.48, 1.18, 0.16), m["bark"], (0.04, -0.12, 0.17)),
              box_part((0.04, -0.20, 0.57), (0.79, 0.58, 0.055), m["trim"], (0.04, -0.12, 0.17)),
              timber((-0.28, -0.27, 0.62), (0.38, -0.16, 0.59), 0.07, m["reed"])]
    return parts


def courier(m):
    parts = [stone((0, 0.02, 0.60), (0.79, 0.49, 1.02), m["skin"], detail=1),
             box_part((0, -0.215, 0.63), (0.79, 0.11, 0.39), m["trim"], (0.04, 0.13, 0)),
             timber((-0.46, 0.012, 0.98), (0.47, 0.024, 1.01), 0.10, m["reed"]),
             timber((-0.44, -0.031, 0.25), (0.43, -0.038, 0.28), 0.11, m["bark"])]
    for i in range(5):
        x = (i - 2) * 0.136
        parts.append(stone((x, -0.29, 0.60 - 0.054 * abs(i - 2)), (0.12, 0.09, 0.20), m["bone"], x * 0.47))
    for side in (-1, 1):
        parts.append(timber((side * 0.256, 0.15, 0.38), (side * 0.278, 0.13, 1.05), 0.054, m["oak"]))
    return parts


def sled(m):
    parts = []
    for side in (-1, 1):
        x = side * 0.47
        parts += [timber((x, -1.27, 0.12), (x, 1.08, 0.13), 0.108, m["bone"]),
                  timber((x, 1.05, 0.13), (x * 0.92, 1.51, 0.48), 0.094, m["bone"]),
                  timber((side * 0.20, 1.08, 0.34), (side * 0.047, 1.95, 0.56), 0.033, m["reed"])]
    for i in range(7):
        parts.append(timber((-0.53, -0.99 + i * 0.30, 0.30), (0.54, -0.99 + i * 0.30, 0.34), 0.077, m["oak"]))
    parts += [stone((-0.12, -0.46, 0.57), (0.83, 1.19, 0.54), m["skin"], detail=1),
              stone((0.10, 0.36, 0.57), (0.63, 0.58, 0.49), m["reed"]),
              timber((-0.48, 0.17, 0.68), (0.52, 0.19, 0.54), 0.049, m["trim"])]
    return parts


MODELS = {
    "antler_beacon": beacon, "river_fish_weir": weir, "mossback_ibex": ibex,
    "obsidian_cache": cache, "shell_courier_kit": courier, "bone_sled": sled,
}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for name, make in MODELS.items():
        mats = reset()
        join_and_rename(make(mats), name)
        export_gltf(args.out_dir / "wildcard" / f"{name}.glb")
