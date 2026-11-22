extends RefCounted
## Procedural articulated Stone Age humanoid rig, race traits, class gear, and weapons.


static func find_chest(visual_root: Node3D) -> Node3D:
	if visual_root == null:
		return null
	var body_pivot := visual_root.get_node_or_null("BodyPivot")
	var hips := body_pivot.get_node_or_null("HipsPivot") if body_pivot != null else null
	var spine := hips.get_node_or_null("SpinePivot") if hips != null else null
	return spine.get_node_or_null("ChestPivot") if spine != null else null


static func set_hand_mounts_visible(visual_root: Node3D, vis: bool) -> void:
	var chest := find_chest(visual_root)
	if chest == null:
		return
	var sh_r := chest.get_node_or_null("ShoulderR")
	var el_r := sh_r.get_node_or_null("ElbowR") if sh_r != null else null
	var wm := el_r.get_node_or_null("WeaponMount") if el_r != null else null
	if wm != null:
		wm.visible = vis
	var sh_l := chest.get_node_or_null("ShoulderL")
	var el_l := sh_l.get_node_or_null("ElbowL") if sh_l != null else null
	var om := el_l.get_node_or_null("OffhandMount") if el_l != null else null
	if om != null:
		om.visible = vis


static func build_human_mesh(mf: Node, lineage: int, gender: int, faction_color: Color, is_leader: bool, is_caveman: bool, role: int = GameData.Role.FORAGER, warrior_class: int = GameData.WarriorClass.SPEARMAN, is_child: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "VisualRoot"

	var eff_lineage: int = GameData.resolve_effective_lineage(lineage, is_caveman)
	var l_data: Dictionary = GameData.LINEAGE_DATA.get(eff_lineage, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN])
	var class_key: String = GameData.resolve_class_key(role, warrior_class, is_leader, is_caveman, false)

	var h_scale: float = float(l_data["height_scale"])
	var w_scale: float = float(l_data["width_scale"])
	var shoulder_scale: float = float(l_data.get("shoulder_scale", 1.0))
	var chest_depth: float = float(l_data.get("chest_depth", 1.0))
	var limb_thick: float = float(l_data.get("limb_thick", 1.0))
	var head_scale: float = float(l_data.get("head_scale", 1.0))
	var spine_hunch: float = float(l_data.get("spine_hunch", 0.0))

	if is_child:
		h_scale *= 0.66
		w_scale *= 0.72
		head_scale *= 1.18

	var body_pivot: Node3D = mf.make_pivot(root, "BodyPivot", Vector3.ZERO, Vector3(0.0, 180.0, 0.0))
	body_pivot.scale = Vector3(w_scale, h_scale, w_scale)

	# Palette & Materials
	var skin_col: Color = l_data["skin_color"]
	var hair_col: Color = l_data.get("hair_color", Color(0.16, 0.12, 0.10))
	var paint_col: Color = l_data.get("warpaint_color", faction_color)
	var accent_col: Color = l_data.get("accent_color", Color(0.6, 0.45, 0.3))
	var tunic_col: Color = faction_color if not is_caveman else Color(0.34, 0.24, 0.16)
	if is_leader:
		tunic_col = faction_color.lightened(0.08)

	var skin_mat: StandardMaterial3D = mf.make_mat(skin_col, 0.88, Color.BLACK, 0.0, 1.0, "skin")
	var skin_shadow_mat: StandardMaterial3D = mf.make_mat(skin_col.darkened(0.16), 0.90, Color.BLACK, 0.0, 1.0, "skin")
	var tunic_mat: StandardMaterial3D = mf.make_mat(tunic_col, 0.88, Color.BLACK, 0.0, 1.0, "hide")
	var tunic_dark_mat: StandardMaterial3D = mf.make_mat(tunic_col.darkened(0.28), 0.92, Color.BLACK, 0.0, 1.0, "hide")
	var hide_mat: StandardMaterial3D = mf.make_mat(Color(0.46, 0.31, 0.19), 0.92, Color.BLACK, 0.0, 1.0, "hide")
	var fur_mat: StandardMaterial3D = mf.make_mat(Color(0.28, 0.20, 0.14) if not is_caveman else Color(0.22, 0.16, 0.12), 0.96, Color.BLACK, 0.0, 1.0, "hide")
	var hair_mat: StandardMaterial3D = mf.make_mat(hair_col, 0.94, Color.BLACK, 0.0, 1.0, "hide")
	var bone_mat: StandardMaterial3D = mf.make_mat(Color(0.88, 0.84, 0.72), 0.82, Color.BLACK, 0.0, 1.0, "bone")
	var wood_mat: StandardMaterial3D = mf.make_mat(Color(0.44, 0.28, 0.15), 0.92, Color.BLACK, 0.0, 1.0, "wood")
	var is_ember_paint: bool = (eff_lineage == GameData.Lineage.ASH_WALKER or eff_lineage == GameData.Lineage.FEN_TIDAL)
	var paint_mat: StandardMaterial3D = mf.make_mat(paint_col, 0.72, paint_col * 0.45 if is_ember_paint else Color.BLACK, 0.85 if is_ember_paint else 0.0, 1.0, "skin")
	var eye_col: Color = Color(0.95, 0.56, 0.16) if eff_lineage == GameData.Lineage.ASH_WALKER else (Color(0.94, 0.86, 0.24) if eff_lineage == GameData.Lineage.FEN_TIDAL else Color(0.08, 0.07, 0.07))
	var eye_mat: StandardMaterial3D = mf.make_mat(eye_col, 0.4, eye_col if is_ember_paint else Color.BLACK, 1.1 if is_ember_paint else 0.0)

	# 1. Articulated Hips & Lower Body (Pelvis centered at y=0.64 so feet rest cleanly at y=0.0)
	var hips: Node3D = mf.make_pivot(body_pivot, "HipsPivot", Vector3(0.0, 0.64, 0.0))

	var pelvis := CylinderMesh.new()
	pelvis.top_radius = 0.19 if gender == GameData.Gender.MALE else 0.21
	pelvis.bottom_radius = 0.20 if gender == GameData.Gender.MALE else 0.23
	pelvis.height = 0.16
	mf.add_mesh(hips, pelvis, Vector3(0.0, 0.0, 0.0), tunic_dark_mat, Vector3.ZERO, "Pelvis")

	var belt := CylinderMesh.new()
	belt.top_radius = 0.215
	belt.bottom_radius = 0.215
	belt.height = 0.09
	mf.add_mesh(hips, belt, Vector3(0.0, 0.06, 0.0), fur_mat)
	var buckle := BoxMesh.new()
	buckle.size = Vector3(0.11, 0.09, 0.06)
	mf.add_mesh(hips, buckle, Vector3(0.0, 0.06, 0.21), bone_mat)

	var loin_f := BoxMesh.new()
	loin_f.size = Vector3(0.22, 0.26, 0.05)
	mf.add_mesh(hips, loin_f, Vector3(0.0, -0.10, 0.17), tunic_mat, Vector3(-6.0, 0.0, 0.0))
	var loin_b := BoxMesh.new()
	loin_b.size = Vector3(0.26, 0.26, 0.05)
	mf.add_mesh(hips, loin_b, Vector3(0.0, -0.10, -0.18), hide_mat, Vector3(6.0, 0.0, 0.0))

	# Articulated Legs
	var hip_x: float = 0.125
	for side: String in ["L", "R"]:
		var sign_x: float = 1.0 if side == "L" else -1.0
		var hip: Node3D = mf.make_pivot(hips, "Hip" + side, Vector3(sign_x * hip_x, -0.02, 0.0))

		var thigh := CylinderMesh.new()
		thigh.top_radius = 0.095 * limb_thick
		thigh.bottom_radius = 0.075 * limb_thick
		thigh.height = 0.30
		mf.add_mesh(hip, thigh, Vector3(0.0, -0.15, 0.0), skin_mat, Vector3.ZERO, "Thigh" + side)

		var knee: Node3D = mf.make_pivot(hip, "Knee" + side, Vector3(0.0, -0.30, 0.0))
		var kneecap := SphereMesh.new()
		kneecap.radius = 0.076 * limb_thick
		kneecap.height = 0.13
		mf.add_mesh(knee, kneecap, Vector3(0.0, 0.0, 0.01), hide_mat)

		var shin := CylinderMesh.new()
		shin.top_radius = 0.074 * limb_thick
		shin.bottom_radius = 0.056 * limb_thick
		shin.height = 0.26
		mf.add_mesh(knee, shin, Vector3(0.0, -0.13, 0.0), skin_shadow_mat, Vector3.ZERO, "Shin" + side)

		var wrap := CylinderMesh.new()
		wrap.top_radius = 0.068 * limb_thick
		wrap.bottom_radius = 0.064 * limb_thick
		wrap.height = 0.12
		mf.add_mesh(knee, wrap, Vector3(0.0, -0.20, 0.0), fur_mat if is_caveman else hide_mat)

		var foot := BoxMesh.new()
		foot.size = Vector3(0.11 * limb_thick, 0.08, 0.22)
		mf.add_mesh(knee, foot, Vector3(0.0, -0.28, 0.045), hide_mat, Vector3.ZERO, "Foot" + side)

	# 2. Spine & Chest Hierarchy
	var spine: Node3D = mf.make_pivot(hips, "SpinePivot", Vector3(0.0, 0.08, 0.0), Vector3(spine_hunch, 0.0, 0.0))
	var abdomen := CylinderMesh.new()
	abdomen.top_radius = (0.20 if gender == GameData.Gender.MALE else 0.165) * clampf(shoulder_scale, 0.9, 1.15)
	abdomen.bottom_radius = 0.185
	abdomen.height = 0.26
	mf.add_mesh(spine, abdomen, Vector3(0.0, 0.12, 0.0), tunic_mat, Vector3.ZERO, "Abdomen", Vector3(1.0, 1.0, 0.78 * chest_depth))

	var chest: Node3D = mf.make_pivot(spine, "ChestPivot", Vector3(0.0, 0.24, 0.0))
	var chest_w: float = (0.245 if gender == GameData.Gender.MALE else 0.195) * shoulder_scale
	var ribcage := CylinderMesh.new()
	ribcage.top_radius = chest_w
	ribcage.bottom_radius = (0.19 if gender == GameData.Gender.MALE else 0.165) * shoulder_scale
	ribcage.height = 0.36
	mf.add_mesh(chest, ribcage, Vector3(0.0, 0.17, 0.0), tunic_mat, Vector3.ZERO, "Chest", Vector3(1.0, 1.0, 0.78 * chest_depth))

	var shoulder_strap := BoxMesh.new()
	shoulder_strap.size = Vector3(chest_w * 1.85, 0.08, 0.28 * chest_depth)
	mf.add_mesh(chest, shoulder_strap, Vector3(0.0, 0.27, 0.0), hide_mat, Vector3(0.0, 0.0, 14.0))

	if gender == GameData.Gender.FEMALE:
		var bust_wrap := BoxMesh.new()
		bust_wrap.size = Vector3(chest_w * 1.45, 0.12, 0.24 * chest_depth)
		mf.add_mesh(chest, bust_wrap, Vector3(0.0, 0.19, 0.05), tunic_dark_mat)
	else:
		var chest_paint := BoxMesh.new()
		chest_paint.size = Vector3(chest_w * 1.25, 0.11, 0.04)
		mf.add_mesh(chest, chest_paint, Vector3(0.0, 0.22, 0.15 * chest_depth), paint_mat)

	var collar := TorusMesh.new()
	collar.inner_radius = 0.12
	collar.outer_radius = 0.18
	mf.add_mesh(chest, collar, Vector3(0.0, 0.34, 0.01), mf.make_mat(accent_col, 0.85, Color.BLACK, 0.0, 1.0, "bone"), Vector3(10.0, 0.0, 0.0))

	var back_mount: Node3D = mf.make_pivot(chest, "BackGearMount", Vector3(0.0, 0.17, -0.17 * chest_depth))
	var cape_pivot: Node3D = mf.make_pivot(chest, "CapePivot", Vector3(0.0, 0.32, -0.17 * chest_depth))
	var armor_mount: Node3D = mf.make_pivot(chest, "ArmorMount", Vector3.ZERO)
	armor_mount.visible = false
	_build_tiered_armor_mount(mf, armor_mount, chest_w, chest_depth, hide_mat, bone_mat, paint_mat)

	# 3. Neck & Sculpted Race Head
	var neck: Node3D = mf.make_pivot(chest, "NeckPivot", Vector3(0.0, 0.35, 0.0))
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.078 * limb_thick
	neck_mesh.bottom_radius = 0.092 * limb_thick
	neck_mesh.height = 0.12
	mf.add_mesh(neck, neck_mesh, Vector3(0.0, 0.05, 0.0), skin_shadow_mat)

	var head: Node3D = mf.make_pivot(neck, "HeadPivot", Vector3(0.0, 0.09, 0.0))
	head.scale = Vector3.ONE * head_scale
	_build_race_head(mf, head, l_data, gender, is_caveman, skin_mat, skin_shadow_mat, hair_mat, bone_mat, paint_mat, eye_mat)

	# 4. Articulated Arms (Left on +X, Right on -X -> matches 3rd-person camera facing -Z)
	var shoulder_x: float = chest_w + 0.075
	for side: String in ["L", "R"]:
		var sign_x: float = 1.0 if side == "L" else -1.0
		var shoulder: Node3D = mf.make_pivot(chest, "Shoulder" + side, Vector3(sign_x * shoulder_x, 0.28, 0.0))

		var deltoid := SphereMesh.new()
		deltoid.radius = 0.088 * limb_thick
		deltoid.height = 0.16 * limb_thick
		mf.add_mesh(shoulder, deltoid, Vector3(0.0, -0.02, 0.0), skin_mat)

		var u_arm := CylinderMesh.new()
		u_arm.top_radius = 0.074 * limb_thick
		u_arm.bottom_radius = 0.062 * limb_thick
		u_arm.height = 0.24
		mf.add_mesh(shoulder, u_arm, Vector3(0.0, -0.13, 0.0), skin_mat, Vector3.ZERO, "UpperArm" + side)

		var elbow: Node3D = mf.make_pivot(shoulder, "Elbow" + side, Vector3(0.0, -0.25, 0.0))
		var f_arm := CylinderMesh.new()
		f_arm.top_radius = 0.062 * limb_thick
		f_arm.bottom_radius = 0.050 * limb_thick
		f_arm.height = 0.22
		mf.add_mesh(elbow, f_arm, Vector3(0.0, -0.11, 0.0), skin_shadow_mat, Vector3.ZERO, "Forearm" + side)

		var bracer := CylinderMesh.new()
		bracer.top_radius = 0.066 * limb_thick
		bracer.bottom_radius = 0.058 * limb_thick
		bracer.height = 0.11
		mf.add_mesh(elbow, bracer, Vector3(0.0, -0.14, 0.0), hide_mat)

		var hand := SphereMesh.new()
		hand.radius = 0.056 * limb_thick
		hand.height = 0.10
		mf.add_mesh(elbow, hand, Vector3(0.0, -0.23, 0.015), skin_mat, Vector3.ZERO, "Hand" + side)

		if side == "R":
			var weapon_mount: Node3D = mf.make_pivot(elbow, "WeaponMount", Vector3(0.0, -0.24, 0.03))
			_build_weapon_variants(mf, weapon_mount, wood_mat, bone_mat, hide_mat, faction_color)
		else:
			var offhand_mount: Node3D = mf.make_pivot(elbow, "OffhandMount", Vector3(0.0, -0.22, 0.02))
			_build_offhand_variants(mf, offhand_mount, wood_mat, bone_mat, hide_mat, faction_color)

	# 5. Class-Specific Headgear, Back Gear, Capes & Outfit Accents
	_build_class_kit(mf, chest, head, cape_pivot, back_mount, class_key, l_data, faction_color, hide_mat, fur_mat, bone_mat, wood_mat)

	return root


static func _build_race_head(mf: Node, head: Node3D, l_data: Dictionary, gender: int, is_caveman: bool, skin_mat: Material, skin_shadow_mat: Material, hair_mat: Material, bone_mat: Material, paint_mat: Material, eye_mat: Material) -> void:
	var jaw_w: float = float(l_data.get("jaw_width", 1.0))
	var brow_d: float = float(l_data.get("brow_depth", 1.0))
	var ear_style: String = str(l_data.get("ear_style", "human"))
	var hair_style: String = str(l_data.get("hair_style", "braided_beard"))

	var cranium := SphereMesh.new()
	cranium.radius = 0.175
	cranium.height = 0.34
	mf.add_mesh(head, cranium, Vector3(0.0, 0.17, 0.0), skin_mat, Vector3.ZERO, "Head")

	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.22 * jaw_w, 0.14, 0.21)
	mf.add_mesh(head, jaw, Vector3(0.0, 0.08, 0.05), skin_shadow_mat)

	var brow := BoxMesh.new()
	brow.size = Vector3(0.23, 0.055 * brow_d, 0.10 * brow_d)
	mf.add_mesh(head, brow, Vector3(0.0, 0.21, 0.14), skin_shadow_mat)

	var nose := PrismMesh.new()
	nose.size = Vector3(0.055, 0.08, 0.07)
	mf.add_mesh(head, nose, Vector3(0.0, 0.15, 0.175), skin_shadow_mat, Vector3(12.0, 0.0, 0.0))

	for sx in [-0.062, 0.062]:
		var eye := BoxMesh.new()
		eye.size = Vector3(0.042, 0.028, 0.03)
		mf.add_mesh(head, eye, Vector3(sx, 0.175, 0.162), eye_mat)

	if is_caveman:
		for sx in [-0.055, 0.055]:
			var tusk := PrismMesh.new()
			tusk.size = Vector3(0.025, 0.055, 0.025)
			mf.add_mesh(head, tusk, Vector3(sx, 0.06, 0.16), bone_mat, Vector3(-12.0, 0.0, 0.0))
	else:
		for sx in [-0.09, 0.09]:
			var cheek_mark := BoxMesh.new()
			cheek_mark.size = Vector3(0.05, 0.025, 0.03)
			mf.add_mesh(head, cheek_mark, Vector3(sx, 0.13, 0.145), paint_mat, Vector3(0.0, 0.0, -18.0 if sx < 0 else 18.0))

	for sx in [-1.0, 1.0]:
		if ear_style == "pointed":
			var ear := PrismMesh.new()
			ear.size = Vector3(0.04, 0.14, 0.08)
			mf.add_mesh(head, ear, Vector3(sx * 0.19, 0.17, 0.0), skin_mat, Vector3(-20.0, 0.0, sx * -55.0))
		elif ear_style == "swept":
			var ear := BoxMesh.new()
			ear.size = Vector3(0.035, 0.08, 0.12)
			mf.add_mesh(head, ear, Vector3(sx * 0.17, 0.17, -0.02), skin_mat, Vector3(15.0, sx * -20.0, 0.0))
		elif ear_style == "finned":
			var fin := PrismMesh.new()
			fin.size = Vector3(0.03, 0.18, 0.12)
			mf.add_mesh(head, fin, Vector3(sx * 0.19, 0.17, -0.02), paint_mat, Vector3(10.0, sx * -25.0, sx * -32.0))
		else:
			var ear := BoxMesh.new()
			ear.size = Vector3(0.035, 0.075, 0.05)
			mf.add_mesh(head, ear, Vector3(sx * 0.165, 0.15, 0.0), skin_shadow_mat)

	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.185
	hair_cap.height = 0.26
	mf.add_mesh(head, hair_cap, Vector3(0.0, 0.23, -0.02), hair_mat)

	match hair_style:
		"topknot":
			var knot := CylinderMesh.new()
			knot.top_radius = 0.045
			knot.bottom_radius = 0.07
			knot.height = 0.18
			mf.add_mesh(head, knot, Vector3(0.0, 0.37, -0.05), hair_mat, Vector3(-22.0, 0.0, 0.0))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.05
			ring.outer_radius = 0.08
			mf.add_mesh(head, ring, Vector3(0.0, 0.33, -0.03), bone_mat)
		"spiky":
			for idx in range(3):
				var sp := PrismMesh.new()
				sp.size = Vector3(0.08, 0.16, 0.08)
				mf.add_mesh(head, sp, Vector3((idx - 1) * 0.07, 0.34, -0.03), hair_mat, Vector3(-18.0, 0.0, (idx - 1) * -20.0))
		"crest":
			var mohawk := BoxMesh.new()
			mohawk.size = Vector3(0.07, 0.14, 0.28)
			mf.add_mesh(head, mohawk, Vector3(0.0, 0.32, -0.02), hair_mat)
		"braided_beard":
			if gender == GameData.Gender.MALE:
				var beard := CylinderMesh.new()
				beard.top_radius = 0.11
				beard.bottom_radius = 0.05
				beard.height = 0.20
				mf.add_mesh(head, beard, Vector3(0.0, 0.01, 0.10), hair_mat, Vector3(-10.0, 0.0, 0.0))
		"ash_locks":
			for sx in [-0.14, 0.14]:
				var lock := CylinderMesh.new()
				lock.top_radius = 0.04
				lock.bottom_radius = 0.025
				lock.height = 0.26
				mf.add_mesh(head, lock, Vector3(sx, 0.12, -0.05), hair_mat)
		"fin_crest":
			for i in range(3):
				var f_sp := PrismMesh.new()
				f_sp.size = Vector3(0.04, 0.15, 0.10)
				mf.add_mesh(head, f_sp, Vector3(0.0, 0.33 - float(i) * 0.04, -0.02 - float(i) * 0.08), paint_mat, Vector3(-28.0 * float(i), 0.0, 0.0))
		"wild_mane":
			var mane := SphereMesh.new()
			mane.radius = 0.23
			mane.height = 0.34
			mf.add_mesh(head, mane, Vector3(0.0, 0.22, -0.06), hair_mat)
			var shaggy_beard := CylinderMesh.new()
			shaggy_beard.top_radius = 0.13
			shaggy_beard.bottom_radius = 0.09
			shaggy_beard.height = 0.22
			mf.add_mesh(head, shaggy_beard, Vector3(0.0, 0.01, 0.09), hair_mat)

	if gender == GameData.Gender.FEMALE:
		for sx in [-0.11, 0.11]:
			var braid := CapsuleMesh.new()
			braid.radius = 0.052
			braid.height = 0.30
			mf.add_mesh(head, braid, Vector3(sx, 0.06, -0.14), hair_mat, Vector3(14.0, 0.0, sx * 0.6))


static func _build_tiered_armor_mount(mf: Node, armor_mount: Node3D, chest_w: float, chest_depth: float, hide_mat: Material, bone_mat: Material, paint_mat: Material) -> void:
	for sx in [-1.0, 1.0]:
		var pauldron := SphereMesh.new()
		pauldron.radius = 0.135
		pauldron.height = 0.18
		mf.add_mesh(armor_mount, pauldron, Vector3(sx * (chest_w + 0.055), 0.29, 0.0), hide_mat, Vector3(0.0, 0.0, sx * -18.0), "Pauldron" + ("L" if sx > 0 else "R"))
		var horn := PrismMesh.new()
		horn.size = Vector3(0.048, 0.14, 0.048)
		mf.add_mesh(armor_mount, horn, Vector3(sx * (chest_w + 0.09), 0.37, 0.0), bone_mat, Vector3(0.0, 0.0, sx * -30.0), "PauldronSpike" + ("L" if sx > 0 else "R"))

	var chest_plate := CylinderMesh.new()
	chest_plate.top_radius = chest_w * 1.05
	chest_plate.bottom_radius = chest_w * 0.88
	chest_plate.height = 0.30
	mf.add_mesh(armor_mount, chest_plate, Vector3(0.0, 0.17, 0.0), bone_mat, Vector3.ZERO, "ChestPlate", Vector3(1.0, 1.0, 0.82 * chest_depth))

	for ry in [0.12, 0.22]:
		var rib := BoxMesh.new()
		rib.size = Vector3(chest_w * 1.45, 0.045, 0.05)
		mf.add_mesh(armor_mount, rib, Vector3(0.0, ry, 0.16 * chest_depth), paint_mat, Vector3.ZERO, "ArmorTrim")


static func _build_class_kit(mf: Node, chest: Node3D, head: Node3D, cape_pivot: Node3D, back_mount: Node3D, class_key: String, l_data: Dictionary, faction_color: Color, hide_mat: Material, fur_mat: Material, bone_mat: Material, wood_mat: Material) -> void:
	var cdef: Dictionary = GameData.CLASS_DEFINITIONS.get(class_key, GameData.CLASS_DEFINITIONS["FORAGER"])
	var hg: String = str(cdef.get("headgear", "NONE"))
	var bg: String = str(cdef.get("back_gear", "NONE"))
	var has_cape: bool = bool(cdef.get("has_cape", false))
	var shoulder_scale: float = float(l_data.get("shoulder_scale", 1.0))

	var crest_col: Color = faction_color.lightened(0.25)
	var crest_mat: StandardMaterial3D = mf.make_mat(crest_col, 0.70)
	var glow_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.35, faction_color, 1.4)

	match hg:
		"LEADER_CROWN":
			var crown := TorusMesh.new()
			crown.inner_radius = 0.18
			crown.outer_radius = 0.235
			mf.add_mesh(head, crown, Vector3(0.0, 0.34, 0.0), mf.make_mat(Color(1.0, 0.82, 0.24), 0.35, faction_color, 1.3), Vector3(8.0, 0.0, 0.0), "LeaderCrown")
			for sx in [-0.16, 0.16]:
				var horn := CylinderMesh.new()
				horn.top_radius = 0.015
				horn.bottom_radius = 0.042
				horn.height = 0.24
				mf.add_mesh(head, horn, Vector3(sx, 0.36, 0.02), bone_mat, Vector3(-12.0, 0.0, sx * -160.0))
		"BONE_CREST":
			var band := CylinderMesh.new()
			band.top_radius = 0.19
			band.bottom_radius = 0.19
			band.height = 0.06
			mf.add_mesh(head, band, Vector3(0.0, 0.25, 0.0), bone_mat)
			var plume := BoxMesh.new()
			plume.size = Vector3(0.05, 0.15, 0.16)
			mf.add_mesh(head, plume, Vector3(0.0, 0.34, -0.02), crest_mat)
		"PELT_COWL":
			var cowl := CylinderMesh.new()
			cowl.top_radius = 0.22 * shoulder_scale
			cowl.bottom_radius = 0.28 * shoulder_scale
			cowl.height = 0.16
			mf.add_mesh(chest, cowl, Vector3(0.0, 0.33, -0.02), fur_mat)
		"FEATHER_HOOD", "PELT_HOOD":
			var hood := BoxMesh.new()
			hood.size = Vector3(0.36, 0.28, 0.34)
			mf.add_mesh(head, hood, Vector3(0.0, 0.23, -0.04), fur_mat if hg == "PELT_HOOD" else hide_mat)
			var feather := PrismMesh.new()
			feather.size = Vector3(0.04, 0.18, 0.06)
			mf.add_mesh(head, feather, Vector3(0.15, 0.32, -0.05), crest_mat, Vector3(-18.0, 0.0, -25.0))
		"SKULL_CAP":
			var cap := SphereMesh.new()
			cap.radius = 0.205
			cap.height = 0.22
			mf.add_mesh(head, cap, Vector3(0.0, 0.26, 0.0), bone_mat)
			var jaw_guard := BoxMesh.new()
			jaw_guard.size = Vector3(0.24, 0.08, 0.10)
			mf.add_mesh(head, jaw_guard, Vector3(0.0, 0.08, 0.13), bone_mat)
		"PLUME_BAND":
			var pband := CylinderMesh.new()
			pband.top_radius = 0.19
			pband.bottom_radius = 0.19
			pband.height = 0.05
			mf.add_mesh(head, pband, Vector3(0.0, 0.25, 0.0), crest_mat)
			for i in range(2):
				var pl := PrismMesh.new()
				pl.size = Vector3(0.04, 0.20, 0.05)
				mf.add_mesh(head, pl, Vector3(-0.08 + float(i) * 0.16, 0.35, -0.04), bone_mat, Vector3(-22.0, 0.0, -15.0 + float(i) * 30.0))
		"SKULL_ANTLER_MASK":
			var mask := BoxMesh.new()
			mask.size = Vector3(0.26, 0.24, 0.14)
			mf.add_mesh(head, mask, Vector3(0.0, 0.18, 0.14), bone_mat)
			for sx in [-1.0, 1.0]:
				var ant := CylinderMesh.new()
				ant.top_radius = 0.015
				ant.bottom_radius = 0.035
				ant.height = 0.34
				mf.add_mesh(head, ant, Vector3(sx * 0.18, 0.38, 0.02), bone_mat, Vector3(-18.0, 0.0, sx * -32.0))
				var fork := CylinderMesh.new()
				fork.top_radius = 0.01
				fork.bottom_radius = 0.022
				fork.height = 0.18
				mf.add_mesh(head, fork, Vector3(sx * 0.26, 0.44, 0.05), glow_mat, Vector3(12.0, 0.0, sx * -55.0))
		"LEAF_BAND", "WORK_BAND", "MINER_WRAP", "CRAFT_VISOR", "TRAINING_BAND":
			var wrap_col := Color(0.26, 0.56, 0.24) if hg == "LEAF_BAND" else (Color(0.75, 0.28, 0.22) if hg == "TRAINING_BAND" else Color(0.54, 0.42, 0.28))
			var band := CylinderMesh.new()
			band.top_radius = 0.19
			band.bottom_radius = 0.19
			band.height = 0.055
			mf.add_mesh(head, band, Vector3(0.0, 0.25, 0.0), mf.make_mat(wrap_col, 0.90))
			if hg == "LEAF_BAND":
				var leaf := PrismMesh.new()
				leaf.size = Vector3(0.06, 0.14, 0.04)
				mf.add_mesh(head, leaf, Vector3(0.14, 0.31, 0.02), mf.make_mat(Color(0.24, 0.65, 0.26), 0.85), Vector3(0.0, 0.0, -30.0))

	if has_cape:
		var cape := BoxMesh.new()
		if class_key == "SHAMAN":
			cape.size = Vector3(0.46 * shoulder_scale, 0.56, 0.05)
			mf.add_mesh(cape_pivot, cape, Vector3(0.0, -0.26, -0.02), fur_mat, Vector3(8.0, 0.0, 0.0))
		elif class_key == "HUNTER":
			cape.size = Vector3(0.42 * shoulder_scale, 0.44, 0.05)
			mf.add_mesh(cape_pivot, cape, Vector3(0.0, -0.20, -0.02), hide_mat, Vector3(10.0, 0.0, 0.0))
		else:
			cape.size = Vector3(0.48 * shoulder_scale, 0.76, 0.06)
			mf.add_mesh(cape_pivot, cape, Vector3(0.0, -0.36, -0.03), mf.make_mat(faction_color.darkened(0.18), 0.88), Vector3(10.0, 0.0, 0.0))

	match bg:
		"ARROW_QUIVER":
			var quiv := CylinderMesh.new()
			quiv.top_radius = 0.065
			quiv.bottom_radius = 0.05
			quiv.height = 0.44
			mf.add_mesh(back_mount, quiv, Vector3(0.08, 0.02, -0.04), hide_mat, Vector3(12.0, 0.0, -24.0))
			for i in range(3):
				var arr := CylinderMesh.new()
				arr.top_radius = 0.012
				arr.bottom_radius = 0.012
				arr.height = 0.22
				mf.add_mesh(back_mount, arr, Vector3(0.14 + float(i) * 0.025, 0.24, -0.03), bone_mat, Vector3(12.0, 0.0, -24.0))
		"JAVELIN_BUNDLE":
			for i in range(3):
				var jv := CylinderMesh.new()
				jv.top_radius = 0.018
				jv.bottom_radius = 0.018
				jv.height = 0.92
				mf.add_mesh(back_mount, jv, Vector3(-0.04 + float(i) * 0.05, 0.08, -0.05), wood_mat, Vector3(10.0, 0.0, -20.0))
		"FORAGER_BASKET":
			var basket := CylinderMesh.new()
			basket.top_radius = 0.19
			basket.bottom_radius = 0.14
			basket.height = 0.36
			mf.add_mesh(back_mount, basket, Vector3(0.0, 0.0, -0.11), mf.make_mat(Color(0.58, 0.44, 0.22), 0.94, Color.BLACK, 0.0, 1.0, "wood"))
			for bpos in [Vector3(-0.06, 0.18, -0.10), Vector3(0.05, 0.19, -0.13), Vector3(0.0, 0.20, -0.07)]:
				var berry := SphereMesh.new()
				berry.radius = 0.05
				berry.height = 0.10
				mf.add_mesh(back_mount, berry, bpos, mf.make_mat(Color(0.84, 0.18, 0.26), 0.7))
		"TIMBER_PACK":
			for lz in [-0.04, 0.04]:
				var log_m := CylinderMesh.new()
				log_m.top_radius = 0.065
				log_m.bottom_radius = 0.07
				log_m.height = 0.56
				mf.add_mesh(back_mount, log_m, Vector3(0.0, 0.04 + lz * 0.5, -0.10 + lz * 0.5), wood_mat, Vector3(0.0, 0.0, 72.0))
		"ORE_SATCHEL", "BUILDER_PACK", "TOTEM_POUCH":
			var pack := BoxMesh.new()
			pack.size = Vector3(0.28, 0.28, 0.16)
			mf.add_mesh(back_mount, pack, Vector3(0.0, 0.0, -0.09), hide_mat)
			if bg == "TOTEM_POUCH":
				var charm := SphereMesh.new()
				charm.radius = 0.06
				charm.height = 0.12
				mf.add_mesh(back_mount, charm, Vector3(0.0, 0.16, -0.12), glow_mat)
		"TROPHY_RACK":
			var sk := SphereMesh.new()
			sk.radius = 0.11
			sk.height = 0.20
			mf.add_mesh(chest, sk, Vector3(-0.22 * shoulder_scale, 0.34, 0.0), bone_mat)
		"FUR_PELT":
			var pelt := BoxMesh.new()
			pelt.size = Vector3(0.46 * shoulder_scale, 0.36, 0.18)
			mf.add_mesh(chest, pelt, Vector3(-0.04, 0.24, -0.06), fur_mat, Vector3(8.0, 0.0, -14.0))
		"DUAL_SHEATH":
			for sx: float in [-1.0, 1.0]:
				var sheath_pivot: Node3D = mf.make_pivot(
					back_mount,
					"DualSheath" + ("L" if sx > 0.0 else "R"),
					Vector3(0.0, 0.01, -0.055 - (0.018 if sx > 0.0 else 0.0)),
					Vector3(8.0, 0.0, sx * 36.0)
				)
				var sheath := BoxMesh.new()
				sheath.size = Vector3(0.068, 0.36, 0.036)
				mf.add_mesh(sheath_pivot, sheath, Vector3.ZERO, hide_mat)
				var collar := BoxMesh.new()
				collar.size = Vector3(0.088, 0.055, 0.048)
				mf.add_mesh(sheath_pivot, collar, Vector3(0.0, 0.165, 0.0), bone_mat)
				var band := BoxMesh.new()
				band.size = Vector3(0.078, 0.045, 0.044)
				mf.add_mesh(sheath_pivot, band, Vector3(0.0, -0.03, 0.0), fur_mat)
				var chape := PrismMesh.new()
				chape.size = Vector3(0.058, 0.08, 0.032)
				mf.add_mesh(sheath_pivot, chape, Vector3(0.0, -0.21, 0.0), bone_mat, Vector3(0.0, 0.0, 180.0))


static func _build_weapon_variants(mf: Node, mount: Node3D, wood_mat: Material, bone_mat: Material, hide_mat: Material, faction_color: Color) -> void:
	var flint_mat: StandardMaterial3D = mf.make_mat(Color(0.26, 0.28, 0.32), 0.45)
	var stone_mat: StandardMaterial3D = mf.make_mat(Color(0.46, 0.45, 0.42), 0.88)
	var spirit_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.3, faction_color, 1.8)

	var spear: Node3D = mf.make_pivot(mount, "SPEAR")
	spear.visible = false
	spear.rotation_degrees.x = 68.0
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.026
	shaft.bottom_radius = 0.028
	shaft.height = 1.72
	mf.add_mesh(spear, shaft, Vector3(0.0, 0.0, 0.38), wood_mat, Vector3(90.0, 0.0, 0.0))
	var sp_grip := CylinderMesh.new()
	sp_grip.top_radius = 0.034
	sp_grip.bottom_radius = 0.034
	sp_grip.height = 0.24
	mf.add_mesh(spear, sp_grip, Vector3(0.0, 0.0, 0.0), hide_mat, Vector3(90.0, 0.0, 0.0))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.09, 0.28, 0.045)
	mf.add_mesh(spear, tip, Vector3(0.0, 0.0, 1.32), flint_mat, Vector3(90.0, 0.0, 0.0), "Tip")

	var gspear: Node3D = mf.make_pivot(mount, "GREAT_SPEAR")
	gspear.visible = false
	gspear.rotation_degrees.x = 62.0
	var gshaft := CylinderMesh.new()
	gshaft.top_radius = 0.032
	gshaft.bottom_radius = 0.032
	gshaft.height = 1.95
	mf.add_mesh(gspear, gshaft, Vector3(0.0, 0.0, 0.42), wood_mat, Vector3(90.0, 0.0, 0.0))
	var gblade := PrismMesh.new()
	gblade.size = Vector3(0.16, 0.36, 0.06)
	mf.add_mesh(gspear, gblade, Vector3(0.0, 0.0, 1.44), flint_mat, Vector3(90.0, 0.0, 0.0), "Tip")
	var gcross := BoxMesh.new()
	gcross.size = Vector3(0.28, 0.06, 0.06)
	mf.add_mesh(gspear, gcross, Vector3(0.0, 0.0, 1.18), bone_mat)

	var knife: Node3D = mf.make_pivot(mount, "KNIFE")
	knife.visible = false
	var khandle := CylinderMesh.new()
	khandle.top_radius = 0.03
	khandle.bottom_radius = 0.026
	khandle.height = 0.20
	mf.add_mesh(knife, khandle, Vector3(0.0, 0.0, 0.04), wood_mat, Vector3(90.0, 0.0, 0.0))
	var kblade := PrismMesh.new()
	kblade.size = Vector3(0.07, 0.30, 0.038)
	mf.add_mesh(knife, kblade, Vector3(0.0, 0.02, 0.24), flint_mat, Vector3(82.0, 0.0, 0.0), "Tip")

	var club: Node3D = mf.make_pivot(mount, "WAR_CLUB")
	club.visible = false
	var chaft := CylinderMesh.new()
	chaft.top_radius = 0.034
	chaft.bottom_radius = 0.028
	chaft.height = 0.85
	mf.add_mesh(club, chaft, Vector3(0.0, 0.0, 0.36), wood_mat, Vector3(90.0, 0.0, 0.0))
	var c_head := BoxMesh.new()
	c_head.size = Vector3(0.20, 0.24, 0.32)
	mf.add_mesh(club, c_head, Vector3(0.0, 0.02, 0.78), bone_mat, Vector3.ZERO, "Tip")
	for sx in [-0.11, 0.11]:
		var tooth := PrismMesh.new()
		tooth.size = Vector3(0.06, 0.10, 0.08)
		mf.add_mesh(club, tooth, Vector3(sx, 0.02, 0.80), flint_mat, Vector3(0.0, 0.0, -90.0 if sx < 0 else 90.0))

	var bclub: Node3D = mf.make_pivot(mount, "BONE_CLUB")
	bclub.visible = false
	var bshaft := CylinderMesh.new()
	bshaft.top_radius = 0.065
	bshaft.bottom_radius = 0.028
	bshaft.height = 0.78
	mf.add_mesh(bclub, bshaft, Vector3(0.0, 0.0, 0.34), bone_mat, Vector3(90.0, 0.0, 0.0))
	var b_knot := SphereMesh.new()
	b_knot.radius = 0.12
	b_knot.height = 0.20
	mf.add_mesh(bclub, b_knot, Vector3(0.0, 0.0, 0.72), stone_mat, Vector3.ZERO, "Tip")

	var javelin: Node3D = mf.make_pivot(mount, "JAVELIN")
	javelin.visible = false
	javelin.rotation_degrees.x = 68.0
	var jshaft := CylinderMesh.new()
	jshaft.top_radius = 0.022
	jshaft.bottom_radius = 0.022
	jshaft.height = 1.40
	mf.add_mesh(javelin, jshaft, Vector3(0.0, 0.0, 0.22), wood_mat, Vector3(90.0, 0.0, 0.0))
	var jtip := PrismMesh.new()
	jtip.size = Vector3(0.08, 0.24, 0.04)
	mf.add_mesh(javelin, jtip, Vector3(0.0, 0.0, 0.98), flint_mat, Vector3(90.0, 0.0, 0.0), "Tip")

	var staff: Node3D = mf.make_pivot(mount, "SHAMAN_STAFF")
	staff.visible = false
	var st_pole := CylinderMesh.new()
	st_pole.top_radius = 0.032
	st_pole.bottom_radius = 0.026
	st_pole.height = 1.75
	mf.add_mesh(staff, st_pole, Vector3(0.0, 0.0, 0.30), wood_mat, Vector3(90.0, 0.0, 0.0))
	var st_cross := BoxMesh.new()
	st_cross.size = Vector3(0.28, 0.05, 0.05)
	mf.add_mesh(staff, st_cross, Vector3(0.0, 0.0, 1.02), bone_mat)
	var st_orb := SphereMesh.new()
	st_orb.radius = 0.095
	st_orb.height = 0.19
	mf.add_mesh(staff, st_orb, Vector3(0.0, 0.0, 1.22), spirit_mat, Vector3.ZERO, "Tip")

	var arr_hand: Node3D = mf.make_pivot(mount, "ARROW_HAND")
	arr_hand.visible = false
	var ash := CylinderMesh.new()
	ash.top_radius = 0.014
	ash.bottom_radius = 0.014
	ash.height = 0.65
	mf.add_mesh(arr_hand, ash, Vector3(0.0, 0.0, 0.26), wood_mat, Vector3(90.0, 0.0, 0.0))
	var atip := PrismMesh.new()
	atip.size = Vector3(0.05, 0.12, 0.03)
	mf.add_mesh(arr_hand, atip, Vector3(0.0, 0.0, 0.62), flint_mat, Vector3(90.0, 0.0, 0.0), "Tip")

	var axe: Node3D = mf.make_pivot(mount, "FELLING_AXE")
	axe.visible = false
	var a_haft := CylinderMesh.new()
	a_haft.top_radius = 0.028
	a_haft.bottom_radius = 0.026
	a_haft.height = 0.78
	mf.add_mesh(axe, a_haft, Vector3(0.0, 0.0, 0.32), wood_mat, Vector3(90.0, 0.0, 0.0))
	var a_blade := PrismMesh.new()
	a_blade.size = Vector3(0.07, 0.22, 0.20)
	mf.add_mesh(axe, a_blade, Vector3(0.0, 0.08, 0.65), flint_mat, Vector3.ZERO, "Tip")

	var pick: Node3D = mf.make_pivot(mount, "MINING_PICK")
	pick.visible = false
	var p_haft := CylinderMesh.new()
	p_haft.top_radius = 0.028
	p_haft.bottom_radius = 0.025
	p_haft.height = 0.72
	mf.add_mesh(pick, p_haft, Vector3(0.0, 0.0, 0.30), wood_mat, Vector3(90.0, 0.0, 0.0))
	var p_head := BoxMesh.new()
	p_head.size = Vector3(0.08, 0.30, 0.09)
	mf.add_mesh(pick, p_head, Vector3(0.0, 0.0, 0.62), flint_mat, Vector3.ZERO, "Tip")

	var mallet: Node3D = mf.make_pivot(mount, "BUILD_MALLET")
	mallet.visible = false
	var m_haft := CylinderMesh.new()
	m_haft.top_radius = 0.026
	m_haft.bottom_radius = 0.024
	m_haft.height = 0.52
	mf.add_mesh(mallet, m_haft, Vector3(0.0, 0.0, 0.22), wood_mat, Vector3(90.0, 0.0, 0.0))
	var m_head := CylinderMesh.new()
	m_head.top_radius = 0.08
	m_head.bottom_radius = 0.08
	m_head.height = 0.22
	mf.add_mesh(mallet, m_head, Vector3(0.0, 0.0, 0.48), stone_mat, Vector3.ZERO, "Tip")

	var sickle: Node3D = mf.make_pivot(mount, "SICKLE_TOOL")
	sickle.visible = false
	var s_haft := CylinderMesh.new()
	s_haft.top_radius = 0.024
	s_haft.bottom_radius = 0.022
	s_haft.height = 0.28
	mf.add_mesh(sickle, s_haft, Vector3(0.0, 0.0, 0.12), wood_mat, Vector3(90.0, 0.0, 0.0))
	var s_blade := BoxMesh.new()
	s_blade.size = Vector3(0.04, 0.20, 0.08)
	mf.add_mesh(sickle, s_blade, Vector3(0.0, 0.08, 0.28), flint_mat, Vector3(25.0, 0.0, 0.0), "Tip")

	var tsp: Node3D = mf.make_pivot(mount, "SPARRING_SPEAR")
	tsp.visible = false
	tsp.rotation_degrees.x = 68.0
	var t_shaft := CylinderMesh.new()
	t_shaft.top_radius = 0.025
	t_shaft.bottom_radius = 0.025
	t_shaft.height = 1.45
	mf.add_mesh(tsp, t_shaft, Vector3(0.0, 0.0, 0.28), wood_mat, Vector3(90.0, 0.0, 0.0))
	var t_pad := SphereMesh.new()
	t_pad.radius = 0.065
	t_pad.height = 0.13
	mf.add_mesh(tsp, t_pad, Vector3(0.0, 0.0, 1.02), hide_mat)


static func _build_offhand_variants(mf: Node, mount: Node3D, wood_mat: Material, bone_mat: Material, hide_mat: Material, faction_color: Color) -> void:
	var flint_mat: StandardMaterial3D = mf.make_mat(Color(0.26, 0.28, 0.32), 0.45)
	var buckler_mat: StandardMaterial3D = mf.make_mat(faction_color.darkened(0.15), 0.85, Color.BLACK, 0.0, 1.0, "hide")
	var str_mat: StandardMaterial3D = mf.make_mat(Color(0.85, 0.82, 0.72), 0.6)
	var charm_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.35, faction_color, 1.3)

	var buckler: Node3D = mf.make_pivot(mount, "BUCKLER_SHIELD")
	buckler.visible = false
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.05
	mf.add_mesh(buckler, disc, Vector3(0.09, 0.14, 0.02), buckler_mat, Vector3(0.0, 0.0, 90.0))
	var boss := SphereMesh.new()
	boss.radius = 0.08
	boss.height = 0.10
	mf.add_mesh(buckler, boss, Vector3(0.115, 0.14, 0.02), bone_mat, Vector3(0.0, 0.0, 90.0))

	var target: Node3D = mf.make_pivot(mount, "TARGET_SHIELD")
	target.visible = false
	var tdisc := CylinderMesh.new()
	tdisc.top_radius = 0.21
	tdisc.bottom_radius = 0.21
	tdisc.height = 0.04
	mf.add_mesh(target, tdisc, Vector3(0.08, 0.12, 0.02), hide_mat, Vector3(0.0, 0.0, 90.0))
	var tboss := SphereMesh.new()
	tboss.radius = 0.06
	tboss.height = 0.08
	mf.add_mesh(target, tboss, Vector3(0.10, 0.12, 0.02), buckler_mat, Vector3(0.0, 0.0, 90.0))

	var dirk: Node3D = mf.make_pivot(mount, "OFFHAND_DIRK")
	dirk.visible = false
	var d_h := CylinderMesh.new()
	d_h.top_radius = 0.026
	d_h.bottom_radius = 0.024
	d_h.height = 0.16
	mf.add_mesh(dirk, d_h, Vector3(0.0, 0.0, 0.03), wood_mat, Vector3(90.0, 0.0, 0.0))
	var d_b := PrismMesh.new()
	d_b.size = Vector3(0.055, 0.22, 0.032)
	mf.add_mesh(dirk, d_b, Vector3(0.0, 0.01, 0.19), flint_mat, Vector3(84.0, 0.0, 0.0), "Tip")

	for bow_name in ["BOW", "SHORT_BOW"]:
		var bow: Node3D = mf.make_pivot(mount, bow_name)
		bow.visible = false
		var bh: float = 1.08 if bow_name == "BOW" else 0.88
		var stave_top := CylinderMesh.new()
		stave_top.top_radius = 0.018
		stave_top.bottom_radius = 0.026
		stave_top.height = bh * 0.52
		mf.add_mesh(bow, stave_top, Vector3(0.0, -0.02, bh * 0.24), wood_mat, Vector3(74.0, 0.0, 0.0))
		var stave_bot := CylinderMesh.new()
		stave_bot.top_radius = 0.026
		stave_bot.bottom_radius = 0.018
		stave_bot.height = bh * 0.52
		mf.add_mesh(bow, stave_bot, Vector3(0.0, -0.02, -bh * 0.24), wood_mat, Vector3(106.0, 0.0, 0.0))
		var b_str := CylinderMesh.new()
		b_str.top_radius = 0.008
		b_str.bottom_radius = 0.008
		b_str.height = bh * 0.96
		mf.add_mesh(bow, b_str, Vector3(0.0, 0.055, 0.0), str_mat, Vector3(90.0, 0.0, 0.0))

	var fetish: Node3D = mf.make_pivot(mount, "FETISH_CHARM")
	fetish.visible = false
	var f_ring := TorusMesh.new()
	f_ring.inner_radius = 0.05
	f_ring.outer_radius = 0.08
	mf.add_mesh(fetish, f_ring, Vector3(0.0, 0.0, 0.06), bone_mat)
	var f_orb := SphereMesh.new()
	f_orb.radius = 0.05
	f_orb.height = 0.10
	mf.add_mesh(fetish, f_orb, Vector3(0.0, 0.0, 0.06), charm_mat)

	var herbs: Node3D = mf.make_pivot(mount, "HERB_BUNDLE")
	herbs.visible = false
	var hb := SphereMesh.new()
	hb.radius = 0.09
	hb.height = 0.16
	mf.add_mesh(herbs, hb, Vector3(0.0, 0.0, 0.06), mf.make_mat(Color(0.24, 0.58, 0.22), 0.92))

	var adze: Node3D = mf.make_pivot(mount, "FLINT_ADZE")
	adze.visible = false
	var az_h := CylinderMesh.new()
	az_h.top_radius = 0.024
	az_h.bottom_radius = 0.022
	az_h.height = 0.34
	mf.add_mesh(adze, az_h, Vector3(0.0, 0.0, 0.12), wood_mat, Vector3(90.0, 0.0, 0.0))
	var az_b := BoxMesh.new()
	az_b.size = Vector3(0.05, 0.12, 0.08)
	mf.add_mesh(adze, az_b, Vector3(0.0, 0.04, 0.28), flint_mat, Vector3.ZERO, "Tip")


static func _activate_hand_item(mf: Node, mount: Node, item_name: String, tip_col: Color, weapon_tier: int, tint_tip: bool) -> void:
	if item_name == "" or item_name == "NONE":
		return
	var item_node := mount.get_node_or_null(item_name) as Node3D
	if item_node == null:
		return
	item_node.visible = true
	if tint_tip:
		var tip := item_node.get_node_or_null("Tip") as MeshInstance3D
		if tip != null:
			tip.material_override = mf.make_mat(tip_col, 0.38, tip_col * 0.22 if weapon_tier >= 3 else Color.BLACK, 0.45 if weapon_tier >= 3 else 0.0)


static func update_human_gear(mf: Node, visual_root: Node3D, weapon_type: String, weapon_tier: int, has_armor: bool, is_worker_tool: bool, class_key: String = "", weapon_id: String = "", armor_id: String = "") -> void:
	var chest := find_chest(visual_root)
	if chest == null:
		return

	var eff_armor_id := armor_id if (armor_id != "" and GameData.ARMOR_DEFS.has(armor_id)) else ("BONE_GUARD" if has_armor else "NONE")
	var eff_has_armor := has_armor and eff_armor_id != "NONE"
	var armor_mount := chest.get_node_or_null("ArmorMount")
	if armor_mount != null:
		armor_mount.visible = eff_has_armor
		if eff_has_armor:
			var armor_col := Color(0.56, 0.38, 0.24) if weapon_tier == 1 else (Color(0.84, 0.80, 0.70) if weapon_tier == 2 else Color(0.20, 0.16, 0.26))
			var armor_tex := "bone"
			var use_glow := weapon_tier >= 3
			match eff_armor_id:
				"HIDE_TUNIC":
					armor_col = Color(0.54, 0.36, 0.22)
					armor_tex = "hide"
					use_glow = false
				"PELT_MANTLE":
					armor_col = Color(0.68, 0.62, 0.52)
					armor_tex = "hide"
					use_glow = false
				"OBSIDIAN_PLATE":
					var adef: Dictionary = GameData.ARMOR_DEFS["OBSIDIAN_PLATE"]
					armor_col = adef.get("tint", Color(0.20, 0.16, 0.26))
					armor_tex = "bone"
					use_glow = true
			var cp := armor_mount.get_node_or_null("ChestPlate") as MeshInstance3D
			if cp != null:
				cp.material_override = mf.make_mat(armor_col, 0.65, armor_col * 0.18 if use_glow else Color.BLACK, 0.35 if use_glow else 0.0, 1.0, armor_tex)
			for p_name in ["PauldronL", "PauldronR"]:
				var pd := armor_mount.get_node_or_null(p_name) as MeshInstance3D
				if pd != null:
					pd.material_override = mf.make_mat(armor_col.darkened(0.12), 0.75, armor_col * 0.14 if use_glow else Color.BLACK, 0.25 if use_glow else 0.0, 1.0, "hide")

	var sh_r := chest.get_node_or_null("ShoulderR")
	var sh_l := chest.get_node_or_null("ShoulderL")
	var el_r := sh_r.get_node_or_null("ElbowR") if sh_r != null else null
	var el_l := sh_l.get_node_or_null("ElbowL") if sh_l != null else null
	var w_mount := el_r.get_node_or_null("WeaponMount") if el_r != null else null
	var o_mount := el_l.get_node_or_null("OffhandMount") if el_l != null else null
	if w_mount == null or o_mount == null:
		return

	for c in w_mount.get_children():
		c.visible = false
	for c in o_mount.get_children():
		c.visible = false

	var eff_w := ""
	var eff_o := "NONE"
	var eff_tier := weapon_tier
	if weapon_id != "" and GameData.WEAPON_DEFS.has(weapon_id) and not is_worker_tool:
		var wdef: Dictionary = GameData.WEAPON_DEFS[weapon_id]
		eff_w = str(wdef.get("proc_weapon", "SPEAR"))
		eff_o = str(wdef.get("proc_offhand", "NONE"))
		if weapon_id == "OBSIDIAN_CLEAVER":
			eff_tier = maxi(weapon_tier, 3)
	elif class_key != "" and GameData.CLASS_DEFINITIONS.has(class_key):
		var cdef: Dictionary = GameData.CLASS_DEFINITIONS[class_key]
		eff_w = str(cdef.get("weapon", "SPEAR"))
		eff_o = str(cdef.get("offhand", "NONE"))
	else:
		var legacy_map := {
			"SPEAR": ["SPEAR", "BUCKLER_SHIELD"],
			"KNIFE": ["KNIFE", "OFFHAND_DIRK"],
			"BOW": ["ARROW_HAND", "BOW"],
			"CLUB": ["WAR_CLUB", "NONE"],
			"JAVELIN": ["JAVELIN", "TARGET_SHIELD"],
		}
		if is_worker_tool:
			eff_w = "MINING_PICK"
		elif legacy_map.has(weapon_type):
			eff_w = legacy_map[weapon_type][0]
			eff_o = legacy_map[weapon_type][1]

	var tip_col := Color(0.55, 0.52, 0.48) if eff_tier <= 1 else (Color(0.24, 0.28, 0.34) if eff_tier == 2 else Color(0.14, 0.10, 0.24))
	_activate_hand_item(mf, w_mount, eff_w, tip_col, eff_tier, eff_w != "SHAMAN_STAFF")
	_activate_hand_item(mf, o_mount, eff_o, tip_col, eff_tier, true)
