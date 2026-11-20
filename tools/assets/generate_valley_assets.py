"""Generate the valley's scenery, Tusked Boar and Sabertooth models."""

import argparse
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_tribesman_rig import SkinnedMesh, material, pose_rotation


PALETTE = {
    "bark": (0.20, 0.105, 0.056),
    "wood": (0.44, 0.25, 0.12),
    "pine": (0.068, 0.20, 0.12),
    "pine_tip": (0.15, 0.32, 0.17),
    "leaf": (0.22, 0.34, 0.095),
    "leaf_lit": (0.37, 0.46, 0.16),
    "berry": (0.50, 0.025, 0.046),
    "berry_lit": (0.74, 0.082, 0.054),
    "slate": (0.26, 0.30, 0.31),
    "chalk": (0.46, 0.45, 0.37),
    "moss": (0.22, 0.35, 0.115),
    "reed": (0.31, 0.42, 0.115),
    "straw": (0.56, 0.40, 0.17),
    "cattail": (0.30, 0.132, 0.052),
    "bristle": (0.23, 0.12, 0.074),
    "mane": (0.092, 0.059, 0.045),
    "boar_side": (0.34, 0.20, 0.125),
    "snout": (0.41, 0.23, 0.17),
    "ochre": (0.52, 0.235, 0.082),
    "saddle": (0.31, 0.132, 0.054),
    "sand": (0.68, 0.49, 0.26),
    "ivory": (0.79, 0.70, 0.49),
    "mouth": (0.29, 0.075, 0.060),
    "dark": (0.056, 0.040, 0.038),
    "eye": (0.95, 0.54, 0.10),
}


class ValleyMesh(SkinnedMesh):
    def __init__(self):
        super().__init__()
        self.materials = {key: material(f"Mat_{key.title()}", color, 0.94)
                          for key, color in PALETTE.items()}

    def loft(self, rings, surfaces, sides=8, *, along_y=False, uneven=0.0):
        """Build horizontal muzzle/body sections or vertical rock/plant sections."""
        first = len(self.vertices)
        if along_y:
            rings = [((x, -z, y), width, depth, bone) for (x, y, z), width, depth, bone in rings]
            if rings[0][0][2] > rings[-1][0][2]:
                rings, surfaces = list(reversed(rings)), list(reversed(surfaces))
        self.tube(rings, surfaces, sides=sides, axis=(0, 0, 1))
        for i in range(first, len(self.vertices)):
            vertex = self.vertices[i]
            if uneven:
                ring, side = divmod(i - first, sides)
                vertex.z += uneven * (math.sin(side * 2.13 + ring * 0.89) * 0.75
                                     + math.cos(side * 0.91) * 0.25)
            if along_y:
                self.vertices[i] = Vector((vertex.x, vertex.z, -vertex.y))

    def stem(self, rings, surfaces, sides=6, bone="Body"):
        """Sweep a tapered section along a bent centerline."""
        profiles = [(pos, width, width, bone) for pos, width in rings]
        dx, dy, dz = Vector(rings[-1][0]) - Vector(rings[0][0])
        if abs(dy) > 2.0 * math.hypot(dx, dz):
            self.loft(profiles, surfaces, sides, along_y=True)
        else:
            self.tube(profiles, surfaces, sides=sides)

    def pod(self, pos, width, depth, height, surface, bone="Body", sides=7):
        x, y, z = pos
        self.loft([((x, y, z - height * 0.5), width * 0.45, depth * 0.48, bone),
                   ((x, y, z - height * 0.18), width, depth, bone),
                   ((x, y, z + height * 0.24), width * 0.89, depth * 0.94, bone),
                   ((x, y, z + height * 0.5), width * 0.39, depth * 0.44, bone)],
                  [surface] * 3, sides)

    def tuft(self, start, elbow, tip, width, angle, surface):
        side = Vector((math.cos(angle) * width, math.sin(angle) * width, 0))
        start, elbow, tip = (Vector(pos) for pos in (start, elbow, tip))
        first = len(self.vertices)
        self.vertices.extend((start - side * 0.32, start + side * 0.32,
                              elbow - side, elbow + side, elbow + Vector((0, 0, 0.045)), tip))
        self.weights.extend([{"Body": 1.0}] * 6)
        for indices in [(0, 2, 4), (0, 4, 1), (1, 4, 3), (2, 5, 4), (4, 5, 3)]:
            self._face(tuple(first + i for i in indices), [(0, 0), (0.5, 1), (1, 0)], surface)


def pine(mesh):
    mesh.stem([((0, 0, -0.08), 0.40), ((-0.07, 0.04, 0.50), 0.27),
               ((-0.27, 0.14, 1.68), 0.19), ((-0.12, 0.26, 2.87), 0.15),
               ((0.47, 0.25, 4.20), 0.08), ((0.85, 0.18, 5.48), 0.026)],
              ["bark", "wood", "bark", "bark", "wood"], sides=7)
    for i in range(5):
        angle = 1.27 * i
        x, y = math.cos(angle), math.sin(angle)
        mesh.stem([((0.12 * x, 0.12 * y, 0.29), 0.20), ((0.48 * x, 0.48 * y, 0.10), 0.12),
                   ((0.93 * x, 0.93 * y, 0.01), 0.027)], ["bark", "bark"])
    whorls = [
        ((-0.24, 0.12, 2.08), 1.60, 1.62),
        ((-0.10, 0.25, 2.96), 1.43, 1.46),
        ((0.26, 0.29, 3.69), 1.12, 1.45),
        ((0.57, 0.23, 4.38), 0.84, 1.24),
    ]
    for i, ((x, y, z), width, length) in enumerate(whorls):
        for branch in range(3):
            angle = (branch + i * 0.38) * math.tau / 3.0
            bx, by = math.cos(angle), math.sin(angle)
            mesh.stem([((x, y, z - 0.08), 0.12),
                       ((x + bx * width * 0.76, y + by * width * 0.67, z + 0.02), 0.035)],
                      ["bark"])
        mesh.loft([((x, y, z + 0.09), width * 0.68, width * 0.58, "Body"),
                   ((x, y, z + 0.14), width, width * 0.80, "Body"),
                   ((x + 0.12, y, z + length * 0.42), width * 0.63, width * 0.60, "Body"),
                   ((x + 0.24, y - 0.04, z + length), 0.065, 0.065, "Body")],
                  ["pine", "pine", "pine_tip"], sides=11, uneven=0.22)


def outcrop(mesh):
    slabs = [
        (-0.43, -0.12, 0.13, 0.90, 0.84, 1.36, -0.18),
        (0.54, 0.12, 0.02, 0.64, 0.62, 1.07, 0.18),
        (0.13, 0.52, 0.03, 0.53, 0.49, 0.73, -0.07),
        (-0.77, -0.67, -0.01, 0.48, 0.35, 0.45, 0.11),
    ]
    for i, (x, y, z, w, d, h, lean) in enumerate(slabs):
        mesh.loft([((x, y, z - 0.22), w * 0.86, d * 0.85, "Body"),
                   ((x, y, z + h * 0.23), w, d, "Body"),
                   ((x + lean, y + 0.03, z + h * 0.68), w * 0.91, d * 0.88, "Body"),
                   ((x + lean * 1.3, y + 0.14, z + h * 0.84), w * 0.80, d * 0.78, "Body"),
                   ((x + lean * 1.4, y + 0.09, z + h), w * 0.69, d * 0.68, "Body")],
                  ["slate", "chalk", "slate", "moss" if i in (0, 2) else "chalk"],
                  sides=7, uneven=0.13)
    for x, y, w in [(-1.22, 0.30, 0.26), (1.02, 0.47, 0.31), (0.03, -0.80, 0.32)]:
        mesh.pod((x, y, 0.13), w, w * 0.73, 0.31, "slate")


def berries(mesh):
    rng = random.Random(197)
    for i in range(8):
        angle = i * math.tau / 8
        x, y = 0.59 * math.cos(angle), 0.58 * math.sin(angle)
        z = rng.uniform(0.51, 0.82)
        mesh.stem([((x * 0.18, y * 0.18, 0.03), 0.075), ((x * 0.61, y * 0.61, z * 0.55), 0.055),
                   ((x, y, z), 0.022)], ["bark", "wood"])
        mesh.pod((x, y, z), 0.46, 0.42, rng.uniform(0.48, 0.68), "leaf" if i % 3 else "leaf_lit")
        for j in range(4):
            spread = angle + rng.uniform(-0.60, 0.60)
            gap = rng.uniform(0.24, 0.40)
            mesh.pod((x + gap * math.cos(spread), y + gap * math.sin(spread), z + rng.uniform(0.04, 0.21)),
                     0.105, 0.094, 0.18, "berry_lit" if j == 0 else "berry", sides=5)
    mesh.pod((0.04, -0.06, 0.96), 0.46, 0.43, 0.64, "leaf_lit")
    for x, y in [(-0.26, -0.1), (-0.15, 0.06), (0.22, 0.03), (0.25, -0.16), (-0.04, -0.30)]:
        mesh.pod((x, y, 1.16), 0.107, 0.092, 0.18, "berry", sides=5)


def reeds(mesh):
    rng = random.Random(484)
    for i in range(24):
        angle = i * 2.3999632
        radius = rng.uniform(0.12, 0.66)
        x, y = math.cos(angle) * radius, math.sin(angle) * radius * 0.64
        height = rng.uniform(0.46, 1.13)
        dx, dy = math.cos(angle + 0.55), math.sin(angle + 0.55)
        mesh.tuft((x, y, -0.04), (x + dx * 0.12, y + dy * 0.12, height * 0.62),
                  (x + dx * 0.32, y + dy * 0.32, height), rng.uniform(0.041, 0.082), angle,
                  "reed" if i % 3 else "leaf")
        if i % 4 == 0:
            stem_top = (x + 0.09, y + 0.077, height + 0.23)
            mesh.stem([((x, y, 0.0), 0.031), (stem_top, 0.020)], ["straw"])
            mesh.stem([(stem_top, 0.050), ((stem_top[0] + 0.025, stem_top[1], stem_top[2] + 0.23), 0.038)],
                      ["cattail"], sides=7)


def armature_for(joints):
    data = bpy.data.armatures.new("WildlifeSkeleton")
    rig = bpy.data.objects.new("WildlifeRig", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, start, end, parent in joints:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = start, end
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def mammal_joints(boar):
    body_z, neck, jaw_y, jaw_z = (0.84, (0, 0.41, 0.91), 0.82, 0.62) if boar else (
        1.01, (0, 0.45, 1.10), 0.82, 0.91)
    joints = [
        ("Body", (0, 0, body_z), (0, 0, body_z + 0.32), None),
        ("Head", neck, (0, 1.31 if boar else 1.20, jaw_z + 0.13), "Body"),
        ("Jaw", (0, jaw_y, jaw_z), (0, jaw_y + 0.39, jaw_z - 0.10), "Head"),
        ("Tail", (0, -0.77, body_z + 0.07), (0, -1.28, body_z + 0.17 if boar else body_z - 0.13),
         "Body"),
    ]
    for side, suffix in [(-1, "R"), (1, "L")]:
        for pair, yy, zz, xx in [
            ("Fore", 0.52 if boar else 0.49, 0.72 if boar else 0.96, 0.29),
            ("Hind", -0.57 if boar else -0.62, 0.68 if boar else 0.89, 0.29),
        ]:
            start = (side * xx, yy, zz)
            foot = (side * (xx + 0.025), yy + (0.045 if pair == "Fore" else -0.025), 0.12)
            joints.append((f"{pair}.{suffix}", start, foot, "Body"))
    return joints


def limbs(mesh, joints, boar):
    for bone, start, foot, _ in joints[4:]:
        x, y, z = start
        side = -1 if x < 0 else 1
        thigh = 0.17 if boar else (0.195 if bone.startswith("Hind") else 0.176)
        knee_y = y + (0.095 if bone.startswith("Hind") else -0.08)
        mesh.loft([((foot[0], foot[1], 0.095), 0.096, 0.087, bone),
                   ((foot[0], foot[1] - 0.09, 0.28), 0.088, 0.083, bone),
                   ((x + side * 0.04, knee_y, z * 0.55), 0.11, 0.13, bone),
                   ((x, y, z * 0.83), thigh, thigh * 1.08, bone),
                   ((x * 0.88, y, z + 0.14), thigh * 0.82, thigh * 0.84, bone)],
                  ["mane" if boar else "sand", "bristle" if boar else "ochre",
                   "boar_side" if boar else "ochre", "bristle" if boar else "saddle"], sides=8)
        if boar:
            for toe in (-0.048, 0.048):
                mesh.pod((foot[0] + toe, foot[1] + 0.046, 0.090), 0.057, 0.116, 0.163, "dark", bone)
        else:
            mesh.pod((foot[0], foot[1] + 0.065, 0.103), 0.121, 0.171, 0.182, "sand", bone)


def boar_model(mesh):
    mesh.loft([((0, -0.88, 0.75), 0.22, 0.30, "Body"),
               ((0, -0.62, 0.82), 0.42, 0.45, "Body"),
               ((0, -0.12, 0.89), 0.49, 0.52, "Body"),
               ((0, 0.41, 0.91), 0.49, 0.58, "Body"),
               ((0, 0.66, 0.83), 0.37, 0.39, {"Body": 0.65, "Head": 0.35})],
              ["bristle", "boar_side", "bristle", "mane"], 10, along_y=True)
    mesh.loft([((0, 0.46, 0.88), 0.36, 0.39, {"Head": 0.85, "Body": 0.15}),
               ((0, 0.73, 0.90), 0.40, 0.36, "Head"),
               ((0, 1.00, 0.79), 0.33, 0.25, "Head"),
               ((0, 1.30, 0.64), 0.22, 0.16, "Head"),
               ((0, 1.43, 0.66), 0.18, 0.13, "Head")],
              ["mane", "bristle", "boar_side", "snout"], 9, along_y=True)
    muzzle(mesh, boar=True)
    for i in range(9):
        yy = -0.75 + i * 0.139
        height = 1.14 + 0.33 * math.sin((i + 0.5) / 10 * math.pi / 1.33)
        mesh.stem([((0, yy, height - 0.16), 0.14), ((-0.023, yy - 0.047, height + 0.10), 0.021)],
                  ["mane"], sides=5)
    mesh.stem([((0, -0.77, 0.90), 0.080), ((0.025, -1.02, 0.95), 0.050),
               ((0.11, -1.17, 1.06), 0.035), ((0.10, -1.25, 1.03), 0.013)],
              ["bristle", "boar_side", "mane"], bone="Tail")


def cat_model(mesh):
    mesh.loft([((0, -0.89, 0.96), 0.23, 0.25, "Body"),
               ((0, -0.58, 1.00), 0.40, 0.36, "Body"),
               ((0, -0.18, 0.99), 0.32, 0.31, "Body"),
               ((0, 0.42, 1.03), 0.46, 0.46, "Body"),
               ((0, 0.66, 1.06), 0.32, 0.36, {"Body": 0.60, "Head": 0.40})],
              ["ochre", "sand", "ochre", "saddle"], 10, along_y=True)
    mesh.loft([((0, 0.48, 1.10), 0.29, 0.29, "Head"),
               ((0, 0.79, 1.14), 0.365, 0.33, "Head"),
               ((0, 0.99, 1.12), 0.31, 0.25, "Head"),
               ((0, 1.19, 1.02), 0.23, 0.15, "Head"),
               ((0, 1.29, 1.03), 0.15, 0.112, "Head")],
              ["saddle", "ochre", "sand", "sand"], 10, along_y=True)
    muzzle(mesh, boar=False)
    mesh.stem([((0, -0.83, 1.07), 0.096), ((-0.04, -1.04, 0.97), 0.081),
               ((-0.13, -1.27, 0.93), 0.063), ((-0.17, -1.42, 0.99), 0.035)],
              ["ochre", "ochre", "saddle"], bone="Tail")


def muzzle(mesh, boar):
    if boar:
        mouth = [(0.76, 0.59, 0.26, 0.138), (1.01, 0.56, 0.237, 0.108), (1.34, 0.56, 0.17, 0.074)]
        nose = (0, 1.406, 0.66)
        eye = (0.307, 0.94, 0.94)
        ear = (0.294, 0.70, 1.12)
    else:
        mouth = [(0.77, 0.90, 0.225, 0.15), (1.00, 0.875, 0.213, 0.115), (1.23, 0.887, 0.15, 0.064)]
        nose = (0, 1.266, 1.049)
        eye = (0.259, 1.004, 1.20)
        ear = (0.245, 0.66, 1.36)

    mesh.loft([((0, y, z), width, depth, "Jaw") for y, z, width, depth in mouth],
              ["bristle" if boar else "sand", "snout" if boar else "mouth"], 8, along_y=True)
    mesh.pod(nose, 0.16 if boar else 0.126, 0.070, 0.15 if boar else 0.115, "dark", "Head")
    for side in (-1, 1):
        sx, yy, zz = eye
        mesh.pod((side * sx, yy, zz), 0.048, 0.081, 0.13, "dark", "Head")
        mesh.pod((side * (sx + 0.031), yy + 0.016, zz + 0.009), 0.025, 0.043, 0.076, "eye", "Head")
        sx, yy, zz = ear
        mesh.stem([((side * sx, yy, zz), 0.105), ((side * (sx + 0.05), yy - 0.055, zz + 0.12), 0.106),
                   ((side * (sx + 0.10), yy - 0.078, zz + (0.30 if boar else 0.197)),
                    0.026 if boar else 0.052)], ["bristle" if boar else "saddle", "mane"], bone="Head")
        if boar:
            mesh.stem([((side * 0.17, 1.10, 0.53), 0.083), ((side * 0.31, 1.30, 0.54), 0.068),
                       ((side * 0.36, 1.46, 0.63), 0.043), ((side * 0.33, 1.52, 0.78), 0.009)],
                      ["ivory"] * 3, bone="Jaw")
        else:
            mesh.stem([((side * 0.169, 1.11, 0.99), 0.073), ((side * 0.182, 1.16, 0.85), 0.065),
                       ((side * 0.165, 1.12, 0.65), 0.040), ((side * 0.14, 1.055, 0.555), 0.007)],
                      ["ivory"] * 3, bone="Head")


def animate_bite(rig, boar):
    """Key the coil, open jaw, snap and recovery over the existing 0.36 s attack."""
    rig.animation_data_create()
    action = bpy.data.actions.new("Bite")
    rig.animation_data.action = action
    # Frame, forward rise, vertical dip, body pitch, head pitch, jaw gape, foreleg pitch.
    poses = [
        (1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
        (3, -0.13, -0.085, -0.11, 0.30 if boar else -0.20, 0.67, -0.12),
        (5, 0.30 if boar else 0.32, 0.005, 0.06, -0.26 if boar else 0.16, 0.58, 0.25),
        (6, 0.32, 0.07 if boar else 0.01, 0.09, 0.25 if boar else 0.27, 0.0, 0.13),
        (8, 0.13, -0.042, 0.038, 0.05, 0.10, -0.11),
        (12, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    ]
    for frame, forward, height, torso, head, jaw, foreleg in poses:
        for bone in rig.pose.bones:
            bone.rotation_mode = "QUATERNION"
            pitch = {
                "Body": torso, "Head": head, "Jaw": -jaw,
                "Fore.L": foreleg, "Fore.R": foreleg * 0.83,
                "Hind.L": -foreleg * 0.47, "Hind.R": -foreleg * 0.39,
            }.get(bone.name, 0.0)
            pose_rotation(bone, pitch=pitch, twist=foreleg * 0.4 if bone.name == "Tail" else 0.0)
            bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        body = rig.pose.bones["Body"]
        body.location = body.bone.matrix_local.to_quaternion().inverted() @ Vector((0.0, forward, height))
        body.keyframe_insert(data_path="location", frame=frame)
    slot = rig.animation_data.action_slot
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, 1, action)
    strip.action_slot = slot


def export(path, skinned=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_skins=skinned,
                              export_animations=skinned, export_animation_mode="NLA_TRACKS",
                              export_frame_range=False, export_apply=False)


def build_models(out):
    for name, build in [("windbent_pine", pine), ("moss_limestone", outcrop),
                        ("berry_thicket", berries), ("riverbank_reeds", reeds)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        mesh = ValleyMesh()
        build(mesh)
        mesh.build_mesh(name)
        export(out / "environment" / f"{name}.glb")

    for name, build in [("tusked_boar", boar_model), ("sabertooth", cat_model)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        boar = name == "tusked_boar"
        mesh = ValleyMesh()
        joints = mammal_joints(boar)
        rig = armature_for(joints)
        build(mesh)
        limbs(mesh, joints, boar)
        data = mesh.build(rig)
        data.name = "WildlifeMesh"
        rig.children[0].name = "WildlifeMesh"
        animate_bite(rig, boar)
        export(out / "wildlife" / f"{name}.glb", skinned=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True, help="Root of the assets/models tree.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    build_models(args.out_dir.resolve())
