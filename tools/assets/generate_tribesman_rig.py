"""Build the 17-bone, skinned tribesman and its Idle and Walk clips."""

import argparse
import math
import os
import sys

import bpy
from mathutils import Euler, Vector


def joint(side, x, y, z):
    return (side * x, y, z)


def make_armature():
    data = bpy.data.armatures.new("TribesmanSkeleton")
    armature = bpy.data.objects.new("TribesmanArmature", data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, head, tail, parent=None):
        edit_bone = data.edit_bones.new(name)
        edit_bone.head, edit_bone.tail = head, tail
        if parent:
            edit_bone.parent = data.edit_bones[parent]

    bone("Hips", (0, 0, 0.97), (0, 0, 1.10))
    bone("Spine", (0, 0, 1.10), (0, 0, 1.27), "Hips")
    bone("Chest", (0, 0, 1.27), (0, 0, 1.45), "Spine")
    bone("Neck", (0, 0, 1.45), (0, 0.02, 1.57), "Chest")
    bone("Head", (0, 0.02, 1.57), (0, 0.02, 1.86), "Neck")
    for side, label in [(1, "L"), (-1, "R")]:
        shoulder = joint(side, 0.22, 0.0, 1.42)
        elbow = joint(side, 0.37, 0.0, 1.20)
        wrist = joint(side, 0.445, 0.021, 0.94)
        knuckles = joint(side, 0.47, 0.030, 0.83)
        bone(f"UpperArm.{label}", shoulder, elbow, "Chest")
        bone(f"LowerArm.{label}", elbow, wrist, f"UpperArm.{label}")
        bone(f"Hand.{label}", wrist, knuckles, f"LowerArm.{label}")

        hip = joint(side, 0.131, 0.0, 0.94)
        knee = joint(side, 0.144, 0.016, 0.52)
        ankle = joint(side, 0.148, -0.015, 0.14)
        toe = joint(side, 0.148, 0.152, 0.065)
        bone(f"UpperLeg.{label}", hip, knee, "Hips")
        bone(f"LowerLeg.{label}", knee, ankle, f"UpperLeg.{label}")
        bone(f"Foot.{label}", ankle, toe, f"LowerLeg.{label}")

    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.0
    return mat


class SkinnedMesh:
    def __init__(self):
        self.vertices = []
        self.weights = []
        self.faces = []
        self.faces_uv = []
        self.face_materials = []
        self.materials = {
            "skin": material("Mat_Skin", (0.52, 0.28, 0.15), 0.92),
            "trim": material("FactionTrim", (0.62, 0.20, 0.09), 0.94),
            "hair": material("Mat_Hair", (0.065, 0.037, 0.026), 0.98),
            "hide": material("Mat_Hide", (0.20, 0.103, 0.045), 0.96),
            "fur": material("Mat_Fur", (0.29, 0.19, 0.105), 0.98),
            "bone": material("Mat_Bone", (0.77, 0.66, 0.44), 0.93),
        }

    def _face(self, indices, uvs, surface):
        self.faces.append(indices)
        self.faces_uv.append(uvs)
        self.face_materials.append(surface)

    def tube(self, profiles, surfaces, sides=8, axis=None):
        """Connect weighted rings into a closed tube with a cylindrical UV strip."""
        first = len(self.vertices)
        centers = [Vector(row[0]) for row in profiles]
        length = len(profiles)
        for i, (_, width, depth, weights) in enumerate(profiles):
            direction = (Vector(axis) if axis else
                         (centers[min(i + 1, length - 1)] - centers[max(0, i - 1)]).normalized())
            right = Vector((0, 1, 0)).cross(direction).normalized()
            forward = direction.cross(right)
            for side in range(sides):
                angle = (side + 0.5) * math.tau / sides
                self.vertices.append(centers[i] + right * (width * math.cos(angle))
                                     + forward * (depth * math.sin(angle)))
                self.weights.append(weights if isinstance(weights, dict) else {weights: 1.0})
        for i, surface in enumerate(surfaces):
            lower = first + i * sides
            upper = lower + sides
            v0, v1 = i / (length - 1), (i + 1) / (length - 1)
            for side in range(sides):
                nxt = (side + 1) % sides
                u0, u1 = side / sides, (side + 1) / sides
                self._face((lower + side, lower + nxt, upper + nxt, upper + side),
                           [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], surface)
        cap_uvs = [(0.5 + 0.47 * math.cos(side * math.tau / sides),
                    0.5 + 0.47 * math.sin(side * math.tau / sides)) for side in range(sides)]
        self._face(tuple(reversed(range(first, first + sides))), list(reversed(cap_uvs)), surfaces[0])
        top = first + (length - 1) * sides
        self._face(tuple(range(top, top + sides)), cap_uvs, surfaces[-1])

    def build(self, armature):
        obj = self.build_mesh("TribesmanMesh")
        groups = {bone.name: obj.vertex_groups.new(name=bone.name) for bone in armature.data.bones}
        for i, weights in enumerate(self.weights):
            for bone, weight in weights.items():
                groups[bone].add([i], weight, "REPLACE")
        obj.parent = armature
        deform = obj.modifiers.new("SkeletonDeform", "ARMATURE")
        deform.object = armature
        return obj.data

    def build_mesh(self, name):
        data = bpy.data.meshes.new(name)
        data.from_pydata(self.vertices, [], self.faces)
        data.update()
        material_indices = {}
        for key, surface in self.materials.items():
            material_indices[key] = len(data.materials)
            data.materials.append(surface)
        uvs = data.uv_layers.new(name="UVMap")
        for face, surface, face_uvs in zip(data.polygons, self.face_materials, self.faces_uv):
            face.material_index = material_indices[surface]
            face.use_smooth = False
            for loop, uv in zip(face.loop_indices, face_uvs):
                uvs.data[loop].uv = uv
        obj = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def build_body(mesh):
    mesh.tube([
        ((0, 0.025, 0.79), 0.266, 0.194, "Hips"),
        ((0, 0.009, 0.94), 0.253, 0.165, "Hips"),
        ((0, 0.0, 1.07), 0.184, 0.127, {"Hips": 0.55, "Spine": 0.45}),
        ((0, 0.0, 1.13), 0.188, 0.134, "Spine"),
        ((0, 0.0, 1.29), 0.219, 0.147, {"Spine": 0.36, "Chest": 0.64}),
        ((0, 0.0, 1.42), 0.248, 0.132, "Chest"),
        ((0, 0.007, 1.49), 0.107, 0.091, {"Chest": 0.74, "Neck": 0.26}),
        ((0, 0.016, 1.59), 0.078, 0.075, {"Neck": 0.66, "Head": 0.34}),
    ], ["hide", "fur", "trim", "hide", "hide", "skin", "skin"])

    # Long front flap and a pale clasp break up the hide outfit at gameplay zoom.
    mesh.tube([
        ((0.021, 0.199, 0.75), 0.097, 0.023, "Hips"),
        ((0.013, 0.177, 0.91), 0.127, 0.029, "Hips"),
        ((0, 0.137, 1.07), 0.110, 0.025, {"Hips": 0.60, "Spine": 0.40}),
    ], ["trim", "trim"], sides=6)
    mesh.tube([
        ((0.001, 0.157, 1.061), 0.048, 0.017, "Spine"),
        ((0.001, 0.157, 1.128), 0.048, 0.017, "Spine"),
    ], ["bone"], sides=6)


def build_head(mesh):
    mesh.tube([
        ((0, 0.031, 1.541), 0.074, 0.080, "Head"),
        ((0, 0.046, 1.605), 0.102, 0.103, "Head"),
        ((0, 0.023, 1.698), 0.132, 0.121, "Head"),
        ((0, 0.016, 1.789), 0.132, 0.120, "Head"),
        ((0, 0.007, 1.845), 0.091, 0.090, "Head"),
    ], ["skin", "skin", "skin", "skin"])
    mesh.tube([
        ((0, -0.025, 1.690), 0.128, 0.087, "Head"),
        ((0, -0.016, 1.783), 0.143, 0.139, "Head"),
        ((0, -0.015, 1.851), 0.118, 0.114, "Head"),
        ((0, -0.031, 1.885), 0.068, 0.081, "Head"),
    ], ["hair", "hair", "hair"])
    mesh.tube([
        ((0.023, -0.072, 1.858), 0.050, 0.055, "Head"),
        ((0.030, -0.090, 1.942), 0.034, 0.041, "Head"),
    ], ["hair"], sides=6)
    mesh.tube([
        ((0, 0.132, 1.645), 0.034, 0.024, "Head"),
        ((0, 0.148, 1.687), 0.033, 0.037, "Head"),
        ((0, 0.129, 1.737), 0.018, 0.022, "Head"),
    ], ["skin", "skin"], sides=5)
    for side in [-1, 1]:
        x = side * 0.058
        mesh.tube([
            ((x, 0.125, 1.704), 0.028, 0.018, "Head"),
            ((x, 0.127, 1.722), 0.023, 0.018, "Head"),
        ], ["hair"], sides=5)
        mesh.tube([
            ((side * 0.122, 0.014, 1.647), 0.023, 0.035, "Head"),
            ((side * 0.129, 0.015, 1.733), 0.020, 0.034, "Head"),
        ], ["skin"], sides=5)


def build_limbs(mesh):
    for side, label in [(1, "L"), (-1, "R")]:
        arm, forearm, hand = (f"{part}.{label}" for part in ("UpperArm", "LowerArm", "Hand"))
        mesh.tube([
            (joint(side, 0.174, 0.0, 1.460), 0.092, 0.094, {"Chest": 0.68, arm: 0.32}),
            (joint(side, 0.243, 0.0, 1.412), 0.100, 0.100, {"Chest": 0.38, arm: 0.62}),
            (joint(side, 0.301, 0.0, 1.325), 0.078, 0.080, arm),
            (joint(side, 0.351, 0.0, 1.241), 0.065, 0.063, {arm: 0.84, forearm: 0.16}),
            (joint(side, 0.373, 0.0, 1.199), 0.063, 0.060, {arm: 0.52, forearm: 0.48}),
            (joint(side, 0.407, 0.008, 1.123), 0.073, 0.068, forearm),
            (joint(side, 0.432, 0.012, 1.015), 0.056, 0.053, {forearm: 0.88, hand: 0.12}),
            (joint(side, 0.445, 0.021, 0.94), 0.047, 0.045, {forearm: 0.52, hand: 0.48}),
            (joint(side, 0.455, 0.025, 0.892), 0.060, 0.054, hand),
            (joint(side, 0.476, 0.032, 0.840), 0.049, 0.042, hand),
        ], ["fur", "skin", "skin", "skin", "skin", "hide", "hide", "skin", "skin"], sides=7)

        thigh, calf, foot = (f"{part}.{label}" for part in ("UpperLeg", "LowerLeg", "Foot"))
        mesh.tube([
            (joint(side, 0.125, 0.0, 0.96), 0.108, 0.107, {"Hips": 0.64, thigh: 0.36}),
            (joint(side, 0.131, 0.0, 0.82), 0.098, 0.102, thigh),
            (joint(side, 0.139, 0.01, 0.64), 0.080, 0.084, {thigh: 0.90, calf: 0.10}),
            (joint(side, 0.144, 0.015, 0.52), 0.072, 0.075, {thigh: 0.50, calf: 0.50}),
            (joint(side, 0.148, 0.007, 0.415), 0.079, 0.074, calf),
            (joint(side, 0.148, -0.010, 0.255), 0.066, 0.065, calf),
            (joint(side, 0.148, -0.015, 0.14), 0.058, 0.059, {calf: 0.55, foot: 0.45}),
            (joint(side, 0.148, -0.013, 0.078), 0.063, 0.065, foot),
        ], ["hide", "skin", "skin", "skin", "fur", "hide", "hide"], sides=7)
        mesh.tube([
            (joint(side, 0.148, 0.058, 0.014), 0.086, 0.151, foot),
            (joint(side, 0.148, 0.049, 0.073), 0.083, 0.143, foot),
            (joint(side, 0.148, 0.007, 0.145), 0.064, 0.085, foot),
        ], ["hide", "fur"], sides=7)


def pose_rotation(pose_bone, pitch=0.0, lean=0.0, twist=0.0):
    rest = pose_bone.bone.matrix_local.to_quaternion()
    rotation = Euler((pitch, lean, twist), "XYZ").to_quaternion()
    pose_bone.rotation_quaternion = rest.inverted() @ rotation @ rest


def animate(armature, name, frames, walking=False, guard=False):
    data = armature.animation_data
    action = bpy.data.actions.new(f"{name}-loop")
    action.use_cyclic = True
    data.action = action
    hips = armature.pose.bones["Hips"]
    for i in range(0, frames + 1, 3):
        phase = math.tau * (i % frames) / frames
        frame = i + 1
        for pose_bone in armature.pose.bones:
            pose_bone.rotation_mode = "QUATERNION"
            pose_rotation(pose_bone)
        if walking:
            shift = 0.022 * math.sin(phase)
            bob = -0.073 + 0.028 * math.sin(phase) ** 2
            pose_rotation(hips, lean=0.047 * math.sin(phase), twist=0.064 * math.cos(phase))
            pose_rotation(armature.pose.bones["Chest"], pitch=0.09, twist=-0.15 * math.cos(phase))
            for label, offset in [("L", 0.0), ("R", math.pi)]:
                cycle = phase + offset
                swing = math.cos(cycle)
                lift = max(0.0, -math.sin(cycle))
                hip_pitch = 0.59 * swing + 0.19 * lift
                knee_pitch = -0.10 - 0.94 * lift
                pose_rotation(armature.pose.bones[f"UpperLeg.{label}"], pitch=hip_pitch)
                pose_rotation(armature.pose.bones[f"LowerLeg.{label}"], pitch=knee_pitch)
                pose_rotation(armature.pose.bones[f"Foot.{label}"], pitch=-hip_pitch - knee_pitch + 0.16 * lift)
                pose_rotation(armature.pose.bones[f"UpperArm.{label}"], pitch=-0.34 * swing)
                pose_rotation(armature.pose.bones[f"LowerArm.{label}"], pitch=0.17 + 0.15 * (1 - swing))
        else:
            shift = 0.008 * math.sin(phase)
            bob = 0.010 * math.sin(phase)
            pose_rotation(armature.pose.bones["Chest"], pitch=0.038 * math.sin(phase))
            pose_rotation(armature.pose.bones["Head"], twist=0.055 * math.sin(phase))
            for label in ["L", "R"]:
                pose_rotation(armature.pose.bones[f"LowerArm.{label}"], pitch=0.14 + 0.03 * math.sin(phase))
        if guard:
            # Keep the shield in front and reduce spear swing while the legs use the shared gait.
            arm_sway = 0.11 * math.cos(phase) if walking else 0.035 * math.sin(phase)
            pose_rotation(armature.pose.bones["UpperArm.L"], pitch=0.36, lean=-0.08, twist=-0.22)
            pose_rotation(armature.pose.bones["LowerArm.L"], pitch=0.91 + arm_sway)
            pose_rotation(armature.pose.bones["UpperArm.R"], pitch=0.12 + arm_sway, lean=0.09)
            pose_rotation(armature.pose.bones["LowerArm.R"], pitch=0.56)
        hips.location = hips.bone.matrix_local.to_quaternion().inverted() @ Vector((shift, 0, bob))
        hips.keyframe_insert(data_path="location", frame=frame)
        for pose_bone in armature.pose.bones:
            pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    slot = data.action_slot
    data.action = None
    track = data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, 1, action)
    strip.action_slot = slot


def build_tribesman(output_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = make_armature()
    mesh = SkinnedMesh()
    build_body(mesh)
    build_head(mesh)
    build_limbs(mesh)
    data = mesh.build(armature)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 61
    armature.animation_data_create()
    animate(armature, "Idle", 60)
    animate(armature, "Walk", 24, walking=True)
    bpy.context.scene.frame_set(1)

    out_path = os.path.join(output_dir, "tribesman_base.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLB", export_skins=True,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_frame_range=False, export_apply=False,
    )
    triangles = sum(len(face.vertices) - 2 for face in data.polygons)
    print(f"Exported {out_path} with {len(data.vertices)} vertices and {triangles} triangles.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate the skinned tribesman.")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    os.makedirs(args.out_dir, exist_ok=True)
    build_tribesman(args.out_dir)
