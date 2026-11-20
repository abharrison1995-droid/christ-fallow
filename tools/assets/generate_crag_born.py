"""Generate the Crag-Born body variants and shared Stone Age role gear."""

import argparse
import math
import sys
from pathlib import Path

import bpy

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_tribesman_rig import SkinnedMesh, animate, joint, make_armature, material


class PilotMesh(SkinnedMesh):
    def __init__(self):
        super().__init__()
        for name, color in {
            "auburn": (0.135, 0.051, 0.026),
            "leather": (0.36, 0.19, 0.091),
            "wood": (0.29, 0.135, 0.054),
            "flint": (0.27, 0.32, 0.34),
            "edge": (0.53, 0.58, 0.55),
            "reed": (0.52, 0.36, 0.14),
            "straw": (0.72, 0.54, 0.25),
        }.items():
            self.materials[name] = material(f"Mat_{name.title()}", color, 0.96)

    def bar(self, start, end, radius, surface, bone="Chest", sides=6):
        self.tube([(start, radius, radius, bone), (end, radius, radius, bone)],
                  [surface], sides=sides)

    def plate(self, points, depth, surface, rim, bone="Chest"):
        """Make a faceted solid from a counterclockwise outline in the X/Z plane."""
        start = len(self.vertices)
        count = len(points)
        self.vertices.extend((x, y + offset, z) for offset in (-depth, depth) for x, y, z in points)
        self.weights.extend([{bone: 1.0}] * (count * 2))
        uv = [(x, z) for x, _, z in points]
        back, front = list(range(start, start + count)), list(range(start + count, start + 2 * count))
        self._face(tuple(back), uv, surface)
        self._face(tuple(reversed(front)), list(reversed(uv)), surface)
        for i in range(count):
            nxt = (i + 1) % count
            self._face((back[nxt], back[i], front[i], front[nxt]),
                       [(0, 0), (1, 0), (1, 1), (0, 1)], rim)


def body(mesh, variant):
    broad = variant == "broad"
    child = variant == "child"
    chest_width = 0.326 if broad else (0.249 if child else 0.274)
    hip_width = 0.246 if broad else (0.218 if child else 0.257)
    waist = 0.215 if broad else 0.178
    mesh.tube([
        ((0, 0.016, 0.79), hip_width + 0.018, 0.174, "Hips"),
        ((0, 0.012, 0.94), hip_width, 0.164, "Hips"),
        ((0, 0.0, 1.04), waist, 0.126, {"Hips": 0.65, "Spine": 0.35}),
        ((0, 0.0, 1.12), waist, 0.135, {"Hips": 0.18, "Spine": 0.82}),
        ((0, 0.009, 1.30), chest_width - 0.028, 0.170, {"Spine": 0.35, "Chest": 0.65}),
        ((0, -0.004, 1.43), chest_width, 0.145, "Chest"),
        ((0, 0.0, 1.52), 0.111 if broad else 0.098, 0.095, {"Chest": 0.77, "Neck": 0.23}),
        ((0, 0.018, 1.60), 0.080, 0.079, {"Neck": 0.66, "Head": 0.34}),
    ], ["hide", "leather", "trim", "skin", "skin", "skin", "skin"], sides=10)
    mesh.tube([
        ((-0.025, 0.182, 0.755), 0.092, 0.017, "Hips"),
        ((-0.018, 0.182, 0.91), 0.120, 0.019, "Hips"),
        ((-0.018, 0.143, 1.089), 0.137, 0.017, {"Hips": 0.40, "Spine": 0.60}),
    ], ["trim", "trim"], sides=6)
    mesh.bar((0.10, 0.137, 1.034), (0.10, 0.139, 1.103), 0.048, "bone", "Hips")


def braid(mesh, start, end, radius, dark):
    for strand, surface in enumerate(("hair", dark, dark)):
        profiles = []
        for step in range(13):
            t = step / 12
            phase = t * 2.35 * math.tau + strand * math.tau / 3
            taper = 1.0 - 0.43 * t
            x = start[0] + (end[0] - start[0]) * t + math.cos(phase) * radius * 0.48 * taper
            y = start[1] + (end[1] - start[1]) * t + math.sin(phase) * radius * 0.48 * taper
            z = start[2] + (end[2] - start[2]) * t
            profiles.append(((x, y, z), radius * 0.59 * taper, radius * 0.59 * taper, "Head"))
        mesh.tube(profiles, [surface] * 12, sides=5)
    mesh.bar((end[0], end[1], end[2] - 0.005), (end[0], end[1], end[2] + 0.029),
             radius * 0.78, "bone", "Head")


def head(mesh, variant):
    broad = variant == "broad"
    child = variant == "child"
    hair = "hair" if broad else "auburn"
    width = 0.144 if broad else (0.152 if child else 0.128)
    crown = 1.914 if child else 1.866
    jaw = 0.111 if broad else 0.085
    mesh.tube([
        ((0, 0.038, 1.566), jaw * 0.84, 0.091, "Head"),
        ((0, 0.061, 1.637), jaw, 0.112, "Head"),
        ((0, 0.030, 1.721), width, 0.130, "Head"),
        ((0, 0.016, 1.801), width, 0.128, "Head"),
        ((0, -0.004, crown), width * 0.64, 0.097, "Head"),
    ], ["skin"] * 4, sides=10)
    mesh.tube([
        ((0, -0.074, 1.668 if broad else 1.623), width * 0.84, 0.102, "Head"),
        ((0, -0.040, 1.762), width * 1.10, 0.120, "Head"),
        ((0, -0.011, crown - 0.023), width * 1.02, 0.139, "Head"),
        ((0, -0.030, crown + 0.031), width * 0.66, 0.092, "Head"),
    ], [hair] * 3, sides=9)
    mesh.tube([
        ((0, 0.150, 1.649), 0.037, 0.024, "Head"),
        ((0, 0.165, 1.683), 0.036, 0.035, "Head"),
        ((0, 0.138, 1.734), 0.021, 0.017, "Head"),
    ], ["skin", "skin"], sides=5)
    for side in (-1, 1):
        mesh.bar(joint(side, 0.045, 0.149, 1.728), joint(side, 0.105, 0.117, 1.737),
                 0.020 if broad else 0.015, hair, "Head")
        mesh.bar(joint(side, 0.046, 0.148, 1.699), joint(side, 0.093, 0.127, 1.703),
                 0.011, "hair", "Head", sides=5)
        mesh.bar(joint(side, width * 0.91, 0.023, 1.654),
                 joint(side, width, 0.026, 1.728), 0.027, "skin", "Head")
    if broad:
        mesh.tube([
            ((0, 0.128, 1.546), 0.079, 0.044, "Head"),
            ((0, 0.122, 1.603), 0.113, 0.066, "Head"),
            ((0, 0.114, 1.658), 0.106, 0.063, "Head"),
        ], ["hair", "hair"], sides=8)
        for side in (-1, 1):
            braid(mesh, joint(side, 0.061, 0.150, 1.595), joint(side, 0.072, 0.173, 1.441),
                  0.047, "auburn")
    elif child:
        braid(mesh, (0.01, -0.087, 1.940), (0.026, -0.213, 1.788), 0.054, "auburn")
    else:
        braid(mesh, (-0.099, 0.021, 1.852), (-0.163, 0.162, 1.478), 0.059, "auburn")
        braid(mesh, (0.099, 0.021, 1.852), (0.183, -0.150, 1.485), 0.059, "auburn")


def limbs(mesh, variant):
    broad = variant == "broad"
    child = variant == "child"
    shoulder = 0.147 if broad else (0.102 if child else 0.113)
    girth = 1.0 if broad else (0.78 if child else 0.92)
    for side, label in [(1, "L"), (-1, "R")]:
        arm, forearm, hand = (f"{part}.{label}" for part in ("UpperArm", "LowerArm", "Hand"))
        mesh.tube([
            (joint(side, 0.210, -0.002, 1.480), shoulder * 0.74, shoulder * 0.87, {"Chest": 0.85, arm: 0.15}),
            (joint(side, 0.263, -0.002, 1.413), shoulder, shoulder, {"Chest": 0.28, arm: 0.72}),
            (joint(side, 0.310, 0, 1.330), 0.103 * girth, 0.101 * girth, arm),
            (joint(side, 0.373, 0, 1.199), 0.078 * girth, 0.078 * girth, {arm: 0.51, forearm: 0.49}),
            (joint(side, 0.400, 0.010, 1.115), 0.100 * girth, 0.093 * girth, forearm),
            (joint(side, 0.430, 0.017, 1.006), 0.076 * girth, 0.069 * girth, {forearm: 0.88, hand: 0.12}),
            (joint(side, 0.445, 0.021, 0.94), 0.057 * girth, 0.051 * girth, {forearm: 0.47, hand: 0.53}),
            (joint(side, 0.455, 0.025, 0.885), 0.063 * girth, 0.057 * girth, hand),
            (joint(side, 0.475, 0.030, 0.840), 0.049 * girth, 0.045 * girth, hand),
        ], ["skin"] * 5 + ["leather", "skin", "skin"], sides=8)

        thigh, calf, foot = (f"{part}.{label}" for part in ("UpperLeg", "LowerLeg", "Foot"))
        mesh.tube([
            (joint(side, 0.126, 0, 0.959), 0.122, 0.123, {"Hips": 0.60, thigh: 0.40}),
            (joint(side, 0.131, 0, 0.805), 0.117, 0.116, thigh),
            (joint(side, 0.144, 0.016, 0.52), 0.079 * girth, 0.077 * girth, {thigh: 0.52, calf: 0.48}),
            (joint(side, 0.148, 0.0, 0.399), 0.097 * girth, 0.089 * girth, calf),
            (joint(side, 0.148, -0.011, 0.25), 0.072 * girth, 0.067 * girth, calf),
            (joint(side, 0.148, -0.015, 0.14), 0.067 * girth, 0.062 * girth, {calf: 0.50, foot: 0.50}),
            (joint(side, 0.148, -0.013, 0.079), 0.066 * girth, 0.062 * girth, foot),
        ], ["hide", "skin", "skin", "skin", "leather", "hide"], sides=8)
        mesh.tube([
            (joint(side, 0.148, 0.058, 0.018), 0.092 * girth, 0.144, foot),
            (joint(side, 0.148, 0.049, 0.075), 0.089 * girth, 0.139, foot),
            (joint(side, 0.148, 0.005, 0.149), 0.070 * girth, 0.079, foot),
        ], ["hide", "fur"], sides=7)


def spear(mesh):
    mesh.bar((0, 0, -0.78), (0, 0, 0.99), 0.034, "wood")
    mesh.bar((0, 0, -0.13), (0, 0, 0.14), 0.042, "leather")
    mesh.bar((0, 0, 0.841), (0, 0, 0.987), 0.051, "straw")
    mesh.plate([(0, 0, 0.880), (0.105, 0, 1.024), (0.013, 0, 1.249),
                (-0.097, 0, 1.037)], 0.024, "flint", "edge")


def buckler(mesh):
    # The grip is at the origin. The hide and boss face Blender +Y.
    points = [(math.cos(i * math.tau / 9) * 0.282, 0.107,
               math.sin(i * math.tau / 9) * 0.324) for i in range(9)]
    mesh.plate(points, 0.039, "hide", "leather")
    mesh.plate([(x * 0.87, 0.148, z * 0.87) for x, _, z in points], 0.016, "trim", "straw")
    mesh.plate([(x * 0.66, 0.168, z * 0.66) for x, _, z in points], 0.018, "leather", "hide")
    mesh.plate([(x * 0.32, 0.187, z * 0.32) for x, _, z in points], 0.039, "bone", "flint")
    mesh.bar((-0.115, 0.024, 0), (0.116, 0.026, 0), 0.040, "wood")
    for side in (-1, 1):
        mesh.bar((side * 0.168, 0.163, -0.135), (side * 0.157, 0.177, 0.127), 0.018, "bone")


def sickle(mesh):
    mesh.tube([
        ((-0.025, 0, -0.149), 0.032, 0.037, "Chest"),
        ((0, 0, 0), 0.042, 0.041, "Chest"),
        ((0.042, 0, 0.211), 0.050, 0.041, "Chest"),
        ((0.135, 0, 0.368), 0.055, 0.032, "Chest"),
    ], ["wood", "leather", "wood"], sides=7)
    mesh.plate([(0.042, 0, 0.166), (0.127, 0, 0.226), (0.196, 0, 0.347),
                (0.182, 0, 0.474), (0.035, 0, 0.530), (-0.090, 0, 0.498),
                (-0.178, 0, 0.377), (-0.071, 0, 0.411), (0.041, 0, 0.404),
                (0.089, 0, 0.348), (0.037, 0, 0.270)], 0.025, "flint", "edge")
    mesh.bar((0.029, 0, 0.156), (0.062, 0, 0.240), 0.054, "straw")


def basket(mesh):
    rings = [
        (0.014, -0.365, 0.135, 0.085),
        (0.000, -0.292, 0.222, 0.126),
        (-0.010, -0.157, 0.263, 0.153),
        (-0.016, -0.017, 0.250, 0.150),
        (-0.020, 0.126, 0.211, 0.130),
    ]
    # Follow the outer flare up and return down the inside to leave the mouth open.
    profiles = [((0, y, z), w, d, "Chest") for y, z, w, d in rings]
    y, z, w, d = rings[-1]
    profiles += [((0, y, z + 0.036), w + 0.010, d + 0.009, "Chest"),
                 ((0, y, z + 0.049), w - 0.028, d - 0.025, "Chest"),
                 ((0, y, z - 0.046), w - 0.040, d - 0.030, "Chest"),
                 ((0, 0, -0.312), 0.112, 0.066, "Chest")]
    mesh.tube(profiles, ["reed", "straw", "reed", "straw", "straw", "trim", "reed", "hide"],
              sides=12, axis=(0, 0, 1))
    for index in range(12):
        angle = (index + 0.5) * math.tau / 12
        weave = [((math.cos(angle) * w, y + math.sin(angle) * d, z),
                  0.018, 0.016, "Chest") for y, z, w, d in rings]
        mesh.tube(weave, ["straw", "reed", "straw", "reed"], sides=5)
    for side in (-1, 1):
        mesh.bar((side * 0.178, -0.072, 0.086), (side * 0.145, -0.107, 0.310), 0.025, "leather")
    mesh.bar((-0.145, -0.107, 0.310), (0.145, -0.107, 0.310), 0.025, "leather")


def guard_bib(mesh):
    mesh.plate([(-0.16, 0.152, -0.163), (0.09, 0.159, -0.183), (0.207, 0.145, 0.055),
                (0.136, 0.107, 0.220), (-0.112, 0.111, 0.211), (-0.205, 0.132, 0.060)],
               0.035, "leather", "fur")
    for i in range(3):
        z = 0.113 - i * 0.072
        y = 0.168 + i * 0.016
        mesh.plate([(-0.139, y, z - 0.074), (0.131, y, z - 0.069),
                    (0.143, y, z), (-0.132, y, z + 0.014)], 0.024, "bone", "leather")
    mesh.bar((-0.158, 0.161, -0.149), (-0.160, 0.165, 0.104), 0.039, "trim")


def workwear(mesh):
    # A light diagonal chest wrap. The broad ends leave the sleeves and forearms clear.
    mesh.plate([(-0.203, 0.088, -0.101), (-0.117, 0.133, -0.180),
                (0.180, 0.098, 0.157), (0.119, 0.066, 0.250), (0.059, 0.104, 0.187),
                (-0.011, 0.174, 0.072), (-0.092, 0.182, -0.020)],
               0.029, "trim", "leather")
    mesh.bar((0.129, 0.093, 0.196), (0.109, -0.121, 0.242), 0.043, "leather")
    mesh.bar((-0.050, 0.177, -0.006), (-0.004, 0.182, 0.048), 0.047, "bone")


def export(path, skinned):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", export_skins=skinned,
        export_animations=skinned, export_animation_mode="NLA_TRACKS",
        export_frame_range=False, export_apply=False,
    )


def build_models(models):
    for variant in ("broad", "braided", "child"):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        armature = make_armature()
        mesh = PilotMesh()
        body(mesh, variant)
        head(mesh, variant)
        limbs(mesh, variant)
        mesh.build(armature)
        bpy.context.scene.render.fps = 30
        bpy.context.scene.frame_end = 61
        armature.animation_data_create()
        animate(armature, "Idle", 60)
        animate(armature, "Walk", 24, walking=True)
        animate(armature, "GuardIdle", 60, guard=True)
        animate(armature, "GuardWalk", 24, walking=True, guard=True)
        bpy.context.scene.frame_set(1)
        export(models / "characters" / "lineages" / "crag_born" / f"crag_born_{variant}.glb", True)

    gear = {
        "spearman": (("spear", spear), ("hide_buckler", buckler), ("bone_guard", guard_bib)),
        "forager": (("flint_sickle", sickle), ("reed_basket", basket), ("workwear", workwear)),
    }
    for kit, parts in gear.items():
        for name, build in parts:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            mesh = PilotMesh()
            build(mesh)
            mesh.build_mesh(name)
            export(models / "gear" / kit / f"{name}.glb", False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path, help="Root of the assets/models tree.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    build_models(args.out_dir.resolve())
