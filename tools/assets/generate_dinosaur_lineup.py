"""Export three rigged size variants of six Christ Fallow dinosaur designs."""

import argparse
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent / "examples"))
from generate_examples import export_gltf, human, join_and_rename, mesh_part, reset, set_frames, stone, weight
from generate_wildlife_lineup import add_clip


@dataclass(frozen=True)
class Variant:
    name: str
    size: float
    breadth: float
    ornament: float
    colors: tuple


def variants(compact, standard, large):
    return (
        Variant(compact[0], 0.74, 0.92, 0.74, compact[1]),
        Variant(standard[0], 1.0, 1.0, 1.0, standard[1]),
        Variant(large[0], 1.23, 1.10, 1.22, large[1]),
    )


# Hide, underside, dark ridge, display color, and pale markings.
PALETTES = {
    "velociraptor": variants(
        ("bracken", ("8F633C", "DDC295", "49382C", "A89A60", "E1D4AB")),
        ("embercrest", ("A05230", "E4C49A", "413A39", "D56337", "EFD19B")),
        ("nightfeather", ("4C5969", "A4A5A7", "292C3B", "79609B", "C8BBC9"))),
    "parasaurolophus": variants(
        ("reedbank", ("71865E", "CDC78A", "3D5149", "C5A847", "D6C590")),
        ("coppercrest", ("9E7150", "E2BF89", "544339", "CB633A", "E2A56D")),
        ("bluecrest", ("578886", "B6CFB0", "2F535F", "4482AA", "D8DBB9"))),
    "stegosaurus": variants(
        ("mossplate", ("6F8053", "C0B581", "38483A", "96A74F", "C9C874")),
        ("rustplate", ("797057", "CDB489", "4D4C3C", "C26742", "E5AC6F")),
        ("slateplate", ("657C84", "AEBBB4", "3C4E5D", "768BB3", "ABBAD6"))),
    "triceratops": variants(
        ("ochrefrill", ("A6804B", "D2BC91", "6D553D", "BC913C", "E1C178")),
        ("redshield", ("856A55", "D9B38D", "554A43", "A94338", "DB8465")),
        ("ironfrill", ("626C75", "B0BDAD", "3E4D58", "537C83", "A6C8BE"))),
    "tyrannosaurus": variants(
        ("sandjaw", ("A98A56", "DDC69F", "685440", "8A643F", "D2AF69")),
        ("ridgejaw", ("8A6247", "D3AC83", "4F4237", "A94E35", "D99856")),
        ("blackcrown", ("465150", "A3A48B", "2D3839", "735446", "B49966"))),
    "brachiosaurus": variants(
        ("fernback", ("70856A", "BBC39C", "435F52", "9DA66F", "D0CF9B")),
        ("sunspine", ("AA8960", "DCBE8D", "6B5C4B", "C39D50", "E6C789")),
        ("stormneck", ("637D8B", "A6C1C3", "3A4D61", "7D758F", "C3BCD3"))),
}

# Each axial section describes its forward coordinate, height, half-width, and half-depth.
TORSOS = {
    "velociraptor": ((-.60, .74, .07, .09), (-.45, .75, .205, .235), (-.14, .74, .215, .195),
                    (.14, .78, .155, .155), (.26, .83, .075, .094)),
    "parasaurolophus": ((-1.08, 1.67, .18, .23), (-.66, 1.68, .48, .53), (-.15, 1.60, .52, .53),
                       (.55, 1.53, .39, .41), (.91, 1.56, .23, .28), (1.05, 1.64, .11, .17)),
    "stegosaurus": ((-1.57, 1.54, .17, .21), (-1.19, 1.53, .61, .65), (-.64, 1.47, .70, .74),
                   (.13, 1.23, .63, .65), (.79, 1.07, .46, .43), (1.26, 1.01, .24, .25), (1.51, .98, .13, .15)),
    "triceratops": ((-1.50, 1.51, .20, .24), (-1.19, 1.49, .62, .65), (-.62, 1.48, .79, .76),
                   (.20, 1.51, .84, .78), (.87, 1.53, .75, .68), (1.27, 1.54, .51, .46), (1.50, 1.55, .33, .33)),
    "tyrannosaurus": ((-1.44, 2.23, .20, .29), (-1.01, 2.25, .73, .82), (-.33, 2.25, .86, .88),
                     (.46, 2.37, .68, .70), (.94, 2.53, .49, .52), (1.25, 2.69, .35, .39)),
    "brachiosaurus": ((-1.96, 2.69, .34, .40), (-1.47, 2.67, .94, .95), (-.55, 2.92, 1.12, 1.09),
                     (.65, 3.15, 1.09, 1.14), (1.48, 3.37, .83, .97), (1.89, 3.54, .57, .66)),
}

# Knee direction in the fore and hind legs keeps each stance readable in profile.
FEET = {
    "velociraptor": ((.54, (.165, -.38, .76), (.22, -.13, .48), (.20, -.33, .17)),),
    "parasaurolophus": ((.62, (.30, .57, 1.50), (.35, .74, .81), (.37, .82, .15)),
                       (.81, (.36, -.62, 1.68), (.48, -.33, .92), (.47, -.69, .20))),
    "stegosaurus": ((.74, (.39, .85, 1.11), (.45, .75, .54), (.47, .88, .14)),
                   (1.02, (.51, -.99, 1.58), (.58, -.68, .80), (.57, -1.02, .20))),
    "triceratops": ((1.04, (.58, .96, 1.48), (.68, .83, .76), (.66, 1.01, .19)),
                   (1.07, (.55, -1.02, 1.51), (.68, -.69, .76), (.65, -.99, .17))),
    "tyrannosaurus": ((1.32, (.64, -.77, 2.26), (.79, -.19, 1.35), (.76, -.66, .31)),),
    "brachiosaurus": ((1.35, (.67, 1.42, 3.31), (.82, 1.36, 1.60), (.84, 1.47, .25)),
                     (1.43, (.72, -1.22, 2.69), (.86, -1.00, 1.32), (.83, -1.29, .27))),
}

TAILS = {
    "velociraptor": ((-.43, .75), (-1.03, .74), (-1.60, .86)),
    "parasaurolophus": ((-.82, 1.65), (-1.70, 1.32), (-2.69, .93)),
    "stegosaurus": ((-1.25, 1.55), (-2.19, 1.26), (-3.24, 1.22)),
    "triceratops": ((-1.25, 1.54), (-2.02, 1.26), (-2.85, .71)),
    "tyrannosaurus": ((-1.11, 2.29), (-2.72, 1.88), (-4.58, 2.01)),
    "brachiosaurus": ((-1.62, 2.74), (-3.10, 1.83), (-5.50, 1.08)),
}

NECKS = {
    "velociraptor": ((.12, .79), (.31, 1.05), (.52, 1.09), (.90, 1.05)),
    "parasaurolophus": ((.61, 1.48), (.89, 2.06), (1.12, 2.43), (1.72, 2.37)),
    "stegosaurus": ((.99, 1.02), (1.46, .96), (1.75, .89), (2.22, .78)),
    "triceratops": ((1.02, 1.51), (1.36, 1.56), (1.60, 1.48), (2.45, 1.14)),
    "tyrannosaurus": ((.78, 2.41), (1.25, 2.74), (1.73, 2.99), (3.21, 2.92)),
    "brachiosaurus": ((1.50, 3.34), (2.27, 5.22), (2.71, 7.13), (3.63, 7.20)),
}

ACTIONS = {
    "velociraptor": "Pounce", "parasaurolophus": "Call", "stegosaurus": "TailSweep",
    "triceratops": "HeadCharge", "tyrannosaurus": "Bite", "brachiosaurus": "Browse",
}


def axial(point):
    return (0.0, *point)


def rgb(hex_value):
    channels = [int(hex_value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels)


def surfaces(variant):
    materials = reset()
    for label, tint in zip(("hide", "under", "ridge", "display", "mark"), variant.colors):
        materials[label] = human.material("Dinosaur_" + label.title(), rgb(tint), 0.91)
    return materials


def loft(parts, sections, mats, style="hide", sides=10, bands=()):
    """Sweep elliptical sections on a centerline and skin each ring to its named joint."""
    centers = [Vector(section[0]) for section in sections]
    vertices, faces, groups = [], [], {}
    for i, (_, breadth, depth, bones) in enumerate(sections):
        tangent = (centers[min(i + 1, len(centers) - 1)] - centers[max(i - 1, 0)]).normalized()
        side = Vector((1, 0, 0)) - tangent * tangent.x
        side.normalize()
        up = side.cross(tangent).normalized()
        for j in range(sides):
            angle = math.tau * j / sides
            vertices.append(centers[i] + side * (breadth * math.cos(angle)) + up * (depth * math.sin(angle)))
        bindings = {bones: 1.0} if isinstance(bones, str) else bones
        for bone, strength in bindings.items():
            groups.setdefault(bone, []).append((list(range(i * sides, (i + 1) * sides)), strength))

    colors = []
    for i in range(len(sections) - 1):
        vertical_sign = -1.0 if centers[i + 1].y < centers[i].y else 1.0
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((i * sides + j, (i + 1) * sides + j, (i + 1) * sides + k, i * sides + k))
            height = vertical_sign * math.sin(math.tau * (j + 0.5) / sides)
            shade = style
            if style == "hide":
                shade = "under" if height < -0.52 else "ridge" if height > 0.68 else "hide"
                if i in bands and abs(height) < 0.72:
                    shade = "mark"
            colors.append(shade)
    faces += [tuple(range(sides)), tuple(reversed(range(len(vertices) - sides, len(vertices))))]
    colors += [style, style]
    part = mesh_part("Faceted skin", vertices, faces, mats[style])
    slots = {style: 0}
    for polygon, color in zip(part.data.polygons, colors):
        if color not in slots:
            slots[color] = len(part.data.materials)
            part.data.materials.append(mats[color])
        polygon.material_index = slots[color]
    for bone, assignments in groups.items():
        group = part.vertex_groups.new(name=bone)
        for indices, strength in assignments:
            group.add(indices, strength, "REPLACE")
    parts.append(part)


def axis_loft(parts, data, bone, mats, style="hide", sides=10, bands=()):
    loft(parts, [(axial((y, z)), w, h, bone) for y, z, w, h in data], mats, style, sides, bands)


def taper(parts, points, radii, bone, mats, shade, depth=0.83, sides=7):
    loft(parts, [(point, radius, radius * depth, bone) for point, radius in zip(points, radii)], mats, shade, sides)


def badge(parts, bone, position, dimensions, mats, shade, detail=0):
    parts.append(weight(stone(position, dimensions, mats[shade], detail=detail), bone))


def eye(parts, point, radius, mats, color="eye"):
    for sign in (-1, 1):
        x, y, z = point
        badge(parts, "Head", (sign * x, y, z), (radius, radius * 2.6, radius * 2.1), mats, "ridge", 1)
        badge(parts, "Head", (sign * (x + radius * .40), y + radius * .21, z), (radius * .66, radius * 1.57, radius * 1.25), mats, color, 1)
        badge(parts, "Head", (sign * (x + radius * .71), y + radius * .40, z + radius * .12), (radius * .28, radius * .61, radius * .91), mats, "black")


def teeth(parts, x, y_start, y_end, z, radius, count, mats):
    for sign in (-1, 1):
        for i in range(count):
            fraction = i / max(1, count - 1)
            y = y_start + (y_end - y_start) * fraction
            edge = sign * x * (0.86 + .14 * math.sin(math.pi * fraction))
            length = radius * (2.8 - 1.3 * fraction)
            taper(parts, [(edge, y, z), (edge, y + .22 * length, z - length)],
                  [radius, 0.010 * radius], "Head", mats, "bone", sides=5)


def velociraptor(parts, mats, detail):
    axis_loft(parts, [(.12, .78, .118, .127), (.29, .97, .097, .116), (.45, 1.05, .097, .100)],
              "Neck", mats)
    axis_loft(parts, [(.41, 1.05, .074, .080), (.57, 1.075, .123, .110), (.74, 1.025, .083, .053),
                      (.92, 1.012, .040, .036)], "Head", mats, sides=8)
    axis_loft(parts, [(.47, 1.00, .065, .033), (.66, .956, .077, .024), (.90, .977, .035, .015)],
              "Jaw", mats, "under", 8)
    eye(parts, (.107, .62, 1.106), .024, mats)
    teeth(parts, .066, .71, .86, .988, .0105, 4, mats)
    for sign, label in ((1, "L"), (-1, "R")):
        arm = "Arm." + label
        taper(parts, [(sign * .12, .12, .79), (sign * .25, .17, .57), (sign * .22, .40, .53)],
              [.054, .055, .027], arm, mats, "ridge")
        for i in range(5):
            base = (.17 + .016 * i, .34 - i * .045, .61 + .018 * i)
            tip = (.30 + i * .023 * detail, .27 - i * .087 * detail, .53 - i * .018)
            taper(parts, [(sign * base[0], *base[1:]), (sign * tip[0], *tip[1:])],
                  [.044, .005], arm, mats, "display" if i % 2 == 0 else "ridge", depth=.35)
        for i in range(3):
            x = sign * (.17 + .046 * i)
            taper(parts, [(x, .38, .53), (x, .47, .49)], [.015, .0015], arm, mats, "bone", sides=5)
        x = sign * .21
        taper(parts, [(x, -.20, .096), (x, -.10, .214), (x, -.063, .117)],
              [.034, .027, .003], "FootHind." + label, mats, "bone")
        for i in range(3):
            taper(parts, [(sign * .026, .64 - i * .065, 1.13),
                          (sign * (.050 + i * .009), .47 - i * .075, 1.19 + i * .028 * detail)],
                  [.026, .003], "Head", mats, "display", depth=.60)
        for i in range(5):
            taper(parts, [(sign * .012, -1.26 - i * .053, .77 + i * .012),
                          (sign * (.10 - i * .009) * detail, -1.58 - i * .043, .86 + i * .013)],
                  [.022, .004], "TailTip", mats, "display" if i % 2 == 0 else "ridge", depth=.25)


def parasaurolophus(parts, mats, detail):
    axis_loft(parts, [(.51, 1.53, .30, .34), (.87, 1.91, .29, .30), (1.00, 2.25, .23, .30),
                      (1.18, 2.42, .20, .24)], {"Neck": .72, "NeckTip": .28}, mats)
    axis_loft(parts, [(1.02, 2.45, .13, .15), (1.23, 2.52, .23, .235), (1.45, 2.45, .19, .15),
                      (1.72, 2.38, .195, .061), (1.86, 2.35, .139, .041)], "Head", mats)
    axis_loft(parts, [(1.23, 2.36, .17, .088), (1.68, 2.31, .18, .075), (1.85, 2.30, .12, .032)],
              "Jaw", mats, "under", 8)
    crest = [(1.38, 2.62, .144, .103), (1.18, 2.81, .133, .119), (.87, 2.98, .12, .118),
             (.87 - .42 * detail, 3.02 + .15 * detail, .103, .098),
             (.87 - .62 * detail, 3.00 + .15 * detail, .044, .045)]
    axis_loft(parts, crest, "Head", mats, "display", 8)
    axis_loft(parts, crest[-2:], "Head", mats, "mark", 8)
    eye(parts, (.206, 1.39, 2.55), .041, mats)


def plate(parts, center, width, height, bone, mats):
    x, y, z = center
    profile = [(-.53, 0), (.44, 0), (.63, .37), (.22, 1), (-.18, .92), (-.61, .43)]
    vertices = [(x + layer * width * (0.145 if h < .9 else .06), y + dy * width, z + h * height)
                for layer in (-1, 1) for dy, h in profile]
    faces = [(0, 1, 2, 3, 4, 5), (11, 10, 9, 8, 7, 6)]
    faces.extend((i, i + 6, (i + 1) % 6 + 6, (i + 1) % 6) for i in range(6))
    part = mesh_part("Dorsal plate", vertices, faces, mats["display"])
    part.data.materials.append(mats["mark"])
    for i in (4, 5, 6):
        part.data.polygons[i].material_index = 1
    parts.append(weight(part, bone))


def stegosaurus(parts, mats, detail):
    axis_loft(parts, [(1.18, 1.02, .215, .206), (1.57, .94, .15, .171), (1.84, .87, .137, .137)],
              "Neck", mats)
    axis_loft(parts, [(1.69, .91, .086, .095), (1.88, .875, .179, .144), (2.12, .82, .122, .089),
                      (2.26, .78, .064, .050)], "Head", mats)
    axis_loft(parts, [(1.79, .79, .106, .056), (2.20, .738, .082, .034)], "Jaw", mats, "under", 8)
    eye(parts, (.148, 1.94, .914), .035, mats)
    for i, (y, z, width, height) in enumerate([
        (1.26, 1.12, .26, .22), (.95, 1.34, .34, .43), (.55, 1.53, .48, .60), (.06, 1.70, .62, .73),
        (-.46, 1.92, .73, .84), (-.98, 2.03, .65, .80), (-1.47, 1.83, .53, .60),
        (-1.92, 1.61, .36, .45), (-2.26, 1.46, .27, .32), (-2.55, 1.40, .21, .24),
    ]):
        bone = "Tail" if i in (7, 8) else "TailTip" if i == 9 else "Body"
        plate(parts, ((-.14 if i % 2 else .14), y, z), width, height * detail, bone, mats)
    for sign in (-1, 1):
        for y, z, size in [(-2.65, 1.25, .65), (-3.04, 1.22, .52)]:
            taper(parts, [(sign * .095, y, z), (sign * .40 * detail, y - .19, z + .13),
                          (sign * size * detail, y - .29, z + .24)], [.107, .064, .004],
                  "TailTip", mats, "bone")


def triceratops(parts, mats, detail):
    axis_loft(parts, [(1.11, 1.54, .49, .44), (1.49, 1.53, .53, .42), (1.78, 1.48, .46, .39)], "Neck", mats)
    axis_loft(parts, [(1.42, 1.56, .40, .38), (1.82, 1.53, .52, .36), (2.07, 1.39, .40, .28),
                      (2.32, 1.27, .252, .223), (2.56, 1.17, .090, .103)], "Head", mats)
    axis_loft(parts, [(1.62, 1.28, .29, .15), (2.21, 1.063, .24, .134), (2.50, 1.08, .10, .068)],
              "Jaw", mats, "under", 8)
    axis_loft(parts, [(2.33, 1.24, .18, .14), (2.58, 1.15, .072, .102), (2.62, 1.05, .031, .039)],
              "Head", mats, "ridge", 7)
    outline = [(-.39, 1.37), (-.78, 1.61), (-.92, 1.97), (-.80, 2.26), (-.58, 2.45),
               (-.29, 2.52), (0, 2.57), (.29, 2.52), (.58, 2.45), (.80, 2.26), (.92, 1.97), (.78, 1.61), (.39, 1.37)]
    rim = [(x * detail, 1.40 - (z - 1.37) * .30, 1.45 + (z - 1.45) * detail) for x, z in outline]
    center = Vector((0, 1.49, 1.83))
    inner = [center.lerp(Vector(p), .72) for p in rim]
    rear = [(x, y - .14, z) for x, y, z in rim]
    n = len(rim)
    front_index = 3 * n
    faces = [tuple(reversed(range(2 * n, 3 * n)))]
    for i in range(n):
        j = (i + 1) % n
        faces += [(i, j, n + j, n + i), (i, 2 * n + i, 2 * n + j, j), (n + i, n + j, front_index)]
    shield = mesh_part("Frill shield", [*rim, *inner, *rear, center], faces, mats["display"])
    shield.data.materials.append(mats["mark"])
    for i, polygon in enumerate(shield.data.polygons):
        if i % 3 == 1:
            polygon.material_index = 1
    parts.append(weight(shield, "Head"))
    for i, (x, y, z) in enumerate(rim[2:-2]):
        taper(parts, [(x, y, z), (x * 1.075, y - .042, z + .11 + .024 * (i % 2))],
              [.079, .014], "Head", mats, "bone", sides=6)
    for sign in (-1, 1):
        taper(parts, [(sign * .323, 1.88, 1.74), (sign * .43, 2.15, 2.02),
                      (sign * .46, 2.15 + .48 * detail, 2.09 + .25 * detail)],
              [.181, .119, .008], "Head", mats, "bone")
    taper(parts, [(0, 2.28, 1.39), (0, 2.42, 1.67), (0, 2.57, 1.68 + .15 * detail)],
          [.137, .077, .005], "Head", mats, "bone")
    eye(parts, (.476, 1.98, 1.63), .061, mats)


def tyrannosaurus(parts, mats, detail):
    axis_loft(parts, [(.84, 2.45, .53, .52), (1.18, 2.70, .48, .50), (1.57, 2.89, .37, .38),
                      (1.84, 2.96, .35, .33)], "Neck", mats)
    axis_loft(parts, [(1.55, 3.02, .300, .303), (1.94, 3.14, .63, .522), (2.32, 3.14, .56, .45),
                      (2.87, 3.06, .42, .30), (3.26, 3.01, .36, .233), (3.44, 3.01, .23, .160)],
              "Head", mats, sides=10)
    axis_loft(parts, [(1.66, 2.83, .31, .26), (2.05, 2.64, .53, .23), (2.66, 2.72, .45, .145),
                      (3.20, 2.73, .35, .091), (3.40, 2.77, .23, .057)], "Jaw", mats, "under", 10)
    teeth(parts, .385, 2.38, 3.23, 2.81, .056, 7, mats)
    eye(parts, (.525, 2.30, 3.26), .073, mats)
    for sign, label in ((1, "L"), (-1, "R")):
        taper(parts, [(sign * .43, 1.91, 3.38), (sign * .52, 2.17, 3.52 + .14 * detail),
                      (sign * .41, 2.58, 3.43)], [.130, .134, .060], "Head", mats, "ridge")
        badge(parts, "Head", (sign * .365, 3.14, 3.09), (.071, .14, .093), mats, "ridge")
        arm = "Arm." + label
        taper(parts, [(sign * .50, .70, 2.43), (sign * .61, .89, 1.99), (sign * .58, 1.16, 2.04)],
              [.132, .095, .046], arm, mats, "hide")
        for j in range(2):
            x = sign * (.53 + j * .094)
            taper(parts, [(x, 1.12, 2.03), (x, 1.29, 1.95), (x, 1.33, 1.90)], [.039, .027, .003], arm, mats, "bone")


def brachiosaurus(parts, mats, detail):
    long_neck = [
        ((0, 1.40, 3.42), .73, .77, "Body"),
        ((0, 1.89, 3.98), .61, .61, {"Body": .42, "Neck": .58}),
        ((0, 2.17, 4.65), .48, .51, "Neck"), ((0, 2.37, 5.43), .369, .41, {"Neck": .62, "NeckTip": .38}),
        ((0, 2.49, 6.15), .290, .31, "NeckTip"), ((0, 2.66, 6.79), .251, .27, "NeckTip"),
        ((0, 2.79, 7.18), .26, .31, {"NeckTip": .38, "Head": .62}),
    ]
    loft(parts, long_neck, mats, bands=(2, 4))
    axis_loft(parts, [(2.63, 7.22, .224, .26), (2.91, 7.36, .383, .40), (3.22, 7.23, .38, .30),
                      (3.59, 7.16, .33, .17), (3.75, 7.13, .22, .116)], "Head", mats)
    axis_loft(parts, [(2.89, 7.06, .278, .145), (3.37, 6.998, .30, .12), (3.72, 7.01, .23, .073)],
              "Jaw", mats, "under", 8)
    badge(parts, "Head", (0, 2.99, 7.58), (.43, .61, .38 * detail), mats, "ridge", 1)
    eye(parts, (.355, 3.21, 7.28), .061, mats)
    for sign in (-1, 1):
        for i, (y, z) in enumerate(((1.44, 4.20), (1.79, 4.52), (2.04, 5.02), (2.20, 5.62), (2.36, 6.24))):
            bone = "Neck" if i < 3 else "NeckTip"
            badge(parts, bone, (sign * (.40 - i * .037), y, z), (.16, .24, .34), mats, "display")


SCULPTS = {fn.__name__: fn for fn in (velociraptor, parasaurolophus, stegosaurus, triceratops, tyrannosaurus, brachiosaurus)}


def rig_layout(species):
    height = TORSOS[species][1][1]
    tail, pivot, tip = map(axial, TAILS[species])
    collar, middle, head, snout = map(axial, NECKS[species])
    bones = [
        ("Body", (0, 0, height), (0, .5, height + .09), None),
        ("Tail", tail, pivot, "Body"), ("TailTip", pivot, tip, "Tail"),
        ("Neck", collar, middle, "Body"), ("NeckTip", middle, head, "Neck"),
        ("Head", head, snout, "NeckTip"), ("Jaw", (0, head[1] + .05, head[2] - .07), snout, "Head"),
    ]
    legs = []
    feet = FEET[species]
    for label, sign in (("L", 1), ("R", -1)):
        for index, (size, *points) in enumerate(feet):
            group = "Fore" if index == 0 and len(feet) == 2 else "Hind"
            upper, lower, foot = (name + group + "." + label for name in ("Upper", "Lower", "Foot"))
            hip, knee, ankle = [(x * sign, y, z) for x, y, z in points]
            toe = (ankle[0], ankle[1] + .33 * size, max(.042, ankle[2] - .13 * size))
            bones += [(upper, hip, knee, "Body"), (lower, knee, ankle, upper), (foot, ankle, toe, lower)]
            legs.append((group, label, (upper, lower, foot), hip, knee, ankle, toe, size))
        if len(feet) == 1:
            shoulder, hand = ((.12, .12, .79), (.22, .40, .53)) if species == "velociraptor" else (
                (.50, .70, 2.43), (.58, 1.16, 2.04))
            bones.append(("Arm." + label, (sign * shoulder[0], *shoulder[1:]), (sign * hand[0], *hand[1:]), "Body"))
    return bones, legs


def make_rig(bones, placement):
    data = bpy.data.armatures.new("DinosaurSkeleton")
    armature = bpy.data.objects.new("DinosaurRig", data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, start, end, parent in bones:
        joint = data.edit_bones.new(name)
        joint.head = placement @ Vector(start)
        joint.tail = placement @ Vector(end)
        if parent:
            joint.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def limb(parts, leg, mats, species):
    group, _, (upper, lower, foot), hip, knee, ankle, toe, size = leg
    heavy = species in ("stegosaurus", "triceratops", "brachiosaurus")
    width = size * (.30 if heavy else .24)
    shoulder = Vector(hip).lerp(Vector(knee), .36)
    shin = Vector(knee).lerp(Vector(ankle), .59)
    loft(parts, [
        (hip, width, width * 1.18, upper), (shoulder, width * .92, width * 1.08, upper),
        (knee, width * .62, width * .69, {upper: .5, lower: .5}),
        (shin, width * (.65 if heavy else .48), width * .53, lower),
        (ankle, width * .45, width * .47, {lower: .4, foot: .6}),
        (toe, width * .66, width * .48, foot),
    ], mats, sides=8)
    digits = 4 if heavy else 3
    for i in range(digits):
        offset = (i - (digits - 1) / 2.0) * width * .51
        x, y, z = toe
        reaches = .39 if group == "Hind" and not heavy else .24
        tip = (x + offset * 1.25, y + reaches * size - abs(offset) * .36, max(.024, z - .032 * size))
        taper(parts, [(x + offset * .72, y - .11 * size, z), tip], [width * .36, width * .17],
              foot, mats, "under" if heavy else "ridge")
        taper(parts, [tip, (tip[0], tip[1] + size * .052, max(.012, tip[2] - size * .029))],
              [width * .17, width * .030], foot, mats, "bone" if not heavy else "ridge", sides=5)


def skin(parts, species, variant, legs, mats):
    points = TORSOS[species]
    axis_loft(parts, points, "Body", mats, sides=12, bands=(1, 3))
    (base, pivot, tip) = TAILS[species]
    tail_width = points[1][2] * .66
    spine = [(axial(base), tail_width, tail_width * .97, {"Body": .55, "Tail": .45}),
             (Vector(axial(base)).lerp(Vector(axial(pivot)), .46), tail_width * .78, tail_width * .72, "Tail"),
             (axial(pivot), tail_width * .56, tail_width * .52, {"Tail": .57, "TailTip": .43}),
             (Vector(axial(pivot)).lerp(Vector(axial(tip)), .53), tail_width * .28, tail_width * .21, "TailTip"),
             (axial(tip), tail_width * .050, tail_width * .074, "TailTip")]
    loft(parts, spine, mats, bands=(2,))
    for leg in legs:
        limb(parts, leg, mats, species)
    SCULPTS[species](parts, mats, variant.ornament)


def movement(t, height, legs, strength):
    clock = math.tau * t
    swing = math.sin(clock)
    angles = {
        "Body": (0.029 * abs(strength) * math.cos(2 * clock), 0.032 * swing * strength, 0),
        "Neck": (0.042 * swing, 0, .033 * swing),
        "NeckTip": (0.038 * math.sin(clock - .6), 0, -.034 * swing),
        "Tail": (0, 0, (.10 + .16 * strength) * swing),
        "TailTip": (0, 0, (.08 + .14 * strength) * math.sin(clock - .52)),
    }
    for group, side, (upper, lower, foot), *_ in legs:
        limb_phase = clock + ((math.pi if side == "R" else 0) + (.83 * math.pi if group == "Fore" else 0))
        stride = math.cos(limb_phase)
        lift = max(0.0, math.sin(limb_phase))
        angles[upper] = (strength * stride, 0, 0)
        angles[lower] = (-strength * lift * .71, 0, 0)
        angles[foot] = (strength * (.36 * lift - .29 * stride), 0, 0)
    return angles, height * ((.006 + .017 * strength) * math.sin(clock) ** 2)


def display(t, species, height):
    anticipation = math.sin(math.pi * min(t / .40, 1.0))
    action = math.sin(math.pi * min(max((t - .22) / .78, 0.0), 1.0)) ** 1.7
    poses = {
        "velociraptor": {"Body": (-.21 * action, 0, 0), "Neck": (-.32 * action, 0, 0), "Jaw": (-.45 * action, 0, 0),
                        "Tail": (.23 * action, 0, 0), "Arm.L": (.61 * action, 0, .15 * action),
                        "Arm.R": (.61 * action, 0, -.15 * action), "UpperHind.L": (-.71 * action, 0, 0)},
        "parasaurolophus": {"Neck": (.26 * action, 0, 0), "NeckTip": (.23 * action, 0, .09 * action),
                           "Jaw": (-.34 * action, 0, 0)},
        "stegosaurus": {"Body": (0, 0, -.08 * action), "Tail": (0, 0, -.41 * anticipation + .72 * action),
                       "TailTip": (.11 * action, 0, -.35 * anticipation + .86 * action)},
        "triceratops": {"Neck": (.26 * anticipation - .33 * action, 0, 0),
                       "Head": (-.25 * action, 0, 0), "UpperFore.L": (.37 * action, 0, 0),
                       "UpperFore.R": (-.25 * action, 0, 0)},
        "tyrannosaurus": {"Body": (-.11 * action, 0, 0), "Neck": (.18 * anticipation - .27 * action, 0, 0),
                         "Jaw": (-.50 * action - .13 * anticipation, 0, 0),
                         "Tail": (.22 * action, 0, .13 * action)},
        "brachiosaurus": {"Neck": (-.24 * action, 0, .13 * action), "NeckTip": (-.30 * action, 0, .12 * action),
                         "Head": (.17 * action, 0, 0), "Jaw": (-.16 * action, 0, 0)},
    }
    lift = height * (.37 * action - .11 * anticipation) if species == "velociraptor" else 0.0
    return poses[species], lift


def build(output, species, variant):
    mats = surfaces(variant)
    bones, legs = rig_layout(species)
    parts = []
    skin(parts, species, variant, legs, mats)
    model = join_and_rename(parts, "DinosaurMesh")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    s = variant.size
    floor = min(vertex.co.z for vertex in model.data.vertices)
    # Bake scale and ground alignment into both rest meshes and joints before keying poses.
    placement = Matrix.Translation(Vector((0.0, 0.0, -floor * s))) @ Matrix.Diagonal((s * variant.breadth, s, s, 1.0))
    model.data.transform(placement)
    rig = make_rig(bones, placement)
    model.parent = rig
    model.modifiers.new("SkeletonDeform", "ARMATURE").object = rig
    set_frames()
    rig.animation_data_create()
    height = (TORSOS[species][1][1] - floor) * s
    add_clip(rig, "Idle", 60, lambda t: movement(t, height, legs, 0.0), True)
    stride, period = {"velociraptor": (.52, 22), "parasaurolophus": (.39, 30), "tyrannosaurus": (.37, 32)}.get(species, (.27, 38))
    add_clip(rig, "Walk", period, lambda t: movement(t, height, legs, stride), True)
    add_clip(rig, ACTIONS[species], 26 if species in ("velociraptor", "tyrannosaurus") else 46,
             lambda t: display(t, species, height))
    export_gltf(output / "dinosaurs" / f"{species}_{variant.name}.glb", animated=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--species", choices=PALETTES, help="Export only one species and its three variants.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    for species in ([args.species] if args.species else PALETTES):
        for variant in PALETTES[species]:
            build(args.out_dir, species, variant)
