extends RefCounted
## Imported and procedural Stone Age buildings, wildlife, resources, and projectiles.

const BUILDING_STAGE_NAMES := ["Stage_Intact", "Stage_Damaged", "Stage_Critical", "Stage_Rubble"]
const WILDLIFE_MODELS := {
	"BOAR": "tusked_boar", "SLATEBACK_BOAR": "slateback_boar",
	"SABERTOOTH": "sabertooth", "REEDJAW": "reedjaw",
}
const RESOURCE_MODELS := {"TREE": "windbent_pine", "STONE": "moss_limestone", "BERRY_BUSH": "berry_thicket"}


static func _instantiate_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null


static func build_environment_mesh(asset: String) -> Node3D:
	var model := _instantiate_model("res://assets/models/environment/%s.glb" % asset)
	if model != null:
		_apply_psx_glb_materials(model)
	return model


static func _make_blueprint_material(mf: Node) -> StandardMaterial3D:
	return mf.make_mat(Color(0.25, 0.85, 1.0, 0.45), 0.3, Color(0.2, 0.7, 1.0), 0.8, 0.45)


static func _instantiate_building_glb(building_type: String) -> Node3D:
	var glb_path := "res://assets/models/buildings/%s_stages.glb" % building_type.to_lower()
	var inst := _instantiate_model(glb_path)
	if inst == null:
		return null
	if has_building_stages(inst):
		return inst
	inst.free()
	return null


static func build_building_mesh(mf: Node, building_type: String, faction_color: Color, is_blueprint: bool, damage_stage: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "BuildingVisual"
	var glb_inst := _instantiate_building_glb(building_type)
	if glb_inst != null:
		var stage_idx := 0 if is_blueprint else clampi(damage_stage, 0, BUILDING_STAGE_NAMES.size() - 1)
		var stage_node := glb_inst.get_node_or_null(str(BUILDING_STAGE_NAMES[stage_idx])) as Node3D
		if stage_node != null:
			glb_inst.remove_child(stage_node)
			stage_node.transform = glb_inst.transform * stage_node.transform
			stage_node.visible = true
			glb_inst.free()
			_strip_non_visual_nodes(stage_node, is_blueprint)
			root.add_child(stage_node)
			if is_blueprint:
				_apply_material_recursive(root, _make_blueprint_material(mf))
			else:
				_apply_glb_materials_and_tint(mf, stage_node, faction_color)
			return root
		glb_inst.free()

	_build_stage_geometry(root, mf, building_type, faction_color, is_blueprint, damage_stage)
	if is_blueprint:
		_apply_material_recursive(root, _make_blueprint_material(mf))
	return root


static func build_building_stages(mf: Node, building_type: String, faction_color: Color, is_blueprint: bool) -> Node3D:
	var glb_inst := _instantiate_building_glb(building_type)
	if glb_inst != null:
		if is_blueprint:
			_strip_non_visual_nodes(glb_inst, true)
			for i in range(BUILDING_STAGE_NAMES.size()):
				var stage_node := glb_inst.get_node_or_null(str(BUILDING_STAGE_NAMES[i])) as Node3D
				if stage_node != null:
					stage_node.visible = (i == 0)
			_apply_material_recursive(glb_inst, _make_blueprint_material(mf))
		else:
			_apply_glb_materials_and_tint(mf, glb_inst, faction_color)
		return glb_inst

	var root := Node3D.new()
	root.name = "BuildingVisual"

	var s0 := Node3D.new()
	s0.name = "Stage_Intact"
	_build_stage_geometry(s0, mf, building_type, faction_color, is_blueprint, 0)
	s0.visible = true
	root.add_child(s0)

	var s1 := Node3D.new()
	s1.name = "Stage_Damaged"
	_build_stage_geometry(s1, mf, building_type, faction_color, is_blueprint, 1)
	s1.visible = false
	root.add_child(s1)

	var s2 := Node3D.new()
	s2.name = "Stage_Critical"
	_build_stage_geometry(s2, mf, building_type, faction_color, is_blueprint, 2)
	s2.visible = false
	root.add_child(s2)

	var s3 := Node3D.new()
	s3.name = "Stage_Rubble"
	_build_stage_geometry(s3, mf, building_type, faction_color, is_blueprint, 3)
	s3.visible = false
	root.add_child(s3)

	if is_blueprint:
		_apply_material_recursive(root, _make_blueprint_material(mf))

	return root


static func has_building_stages(model: Node3D) -> bool:
	for stage_name in BUILDING_STAGE_NAMES:
		if not model.get_node_or_null(stage_name) is Node3D:
			return false
	return true


static func _strip_non_visual_nodes(node: Node, strip_lights: bool = false) -> void:
	for c in node.get_children():
		if c is StaticBody3D or c is CollisionShape3D or (strip_lights and c is Light3D):
			node.remove_child(c)
			if c.is_inside_tree():
				c.queue_free()
			else:
				c.free()
		else:
			_strip_non_visual_nodes(c, strip_lights)


static func _apply_psx_glb_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for slot in range(mi.mesh.get_surface_count()):
				var base_mat: Material = mi.get_surface_override_material(slot)
				if base_mat == null:
					base_mat = mi.mesh.surface_get_material(slot)
				if base_mat is StandardMaterial3D:
					var mat_dup := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					mat_dup.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					mat_dup.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mat_dup.roughness = maxf(mat_dup.roughness, 0.86)
					mi.set_surface_override_material(slot, mat_dup)
	for c in node.get_children():
		_apply_psx_glb_materials(c)


static func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_apply_material_recursive(c, mat)


static func _apply_glb_materials_and_tint(mf: Node, node: Node, faction_color: Color) -> void:
	# Strip any embedded static colliders from glb (-convcolonly or generated)
	if node is StaticBody3D or node is CollisionShape3D:
		var p := node.get_parent()
		if p != null:
			p.remove_child(node)
			if node.is_inside_tree():
				node.queue_free()
			else:
				node.free()
			return

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var n_name := mi.name.to_lower()
		var node_is_trim := ("faction" in n_name or "trim" in n_name or "banner" in n_name)

		if mi.mesh != null:
			var surface_count := mi.mesh.get_surface_count()
			for slot in range(surface_count):
				var base_mat: Material = mi.get_surface_override_material(slot)
				if base_mat == null:
					base_mat = mi.mesh.surface_get_material(slot)

				var mat_name := base_mat.resource_name.to_lower() if base_mat != null else ""
				if node_is_trim or "faction" in mat_name or "trim" in mat_name or "banner" in mat_name:
					var banner_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.85, Color.BLACK, 0.0, 1.0, "hide")
					mi.set_surface_override_material(slot, banner_mat)
				elif base_mat is StandardMaterial3D:
					var mat_dup := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					mat_dup.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					mat_dup.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mat_dup.roughness = maxf(mat_dup.roughness, 0.86)
					mi.set_surface_override_material(slot, mat_dup)

		if node_is_trim and mi.mesh != null and mi.mesh.get_surface_count() == 0:
			var banner_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.85, Color.BLACK, 0.0, 1.0, "hide")
			mi.material_override = banner_mat

	var children := node.get_children()
	for c in children:
		if is_instance_valid(c):
			_apply_glb_materials_and_tint(mf, c, faction_color)


static func _build_stage_geometry(root: Node3D, mf: Node, building_type: String, faction_color: Color, is_blueprint: bool, stage: int) -> void:
	var wood_mat: StandardMaterial3D = mf.make_mat(Color(0.36, 0.22, 0.12), 0.94, Color.BLACK, 0.0, 1.0, "wood")
	var dark_wood_mat: StandardMaterial3D = mf.make_mat(Color(0.22, 0.14, 0.08), 0.96, Color.BLACK, 0.0, 1.0, "wood")
	var stone_mat: StandardMaterial3D = mf.make_mat(Color(0.40, 0.39, 0.37), 0.94, Color.BLACK, 0.0, 1.0, "stone")
	var thatch_mat: StandardMaterial3D = mf.make_mat(Color(0.56, 0.45, 0.24), 0.96, Color.BLACK, 0.0, 1.0, "hide")
	var hide_mat: StandardMaterial3D = mf.make_mat(Color(0.48, 0.34, 0.22), 0.92, Color.BLACK, 0.0, 1.0, "hide")
	var banner_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.85, Color.BLACK, 0.0, 1.0, "hide")
	var char_mat: StandardMaterial3D = mf.make_mat(Color(0.14, 0.11, 0.09), 0.98, Color.BLACK, 0.0, 1.0, "wood")
	var ash_mat: StandardMaterial3D = mf.make_mat(Color(0.26, 0.24, 0.22), 0.96, Color.BLACK, 0.0, 1.0, "ground")

	var w_mat: StandardMaterial3D = char_mat if stage >= 2 else wood_mat
	var dw_mat: StandardMaterial3D = char_mat if stage >= 2 else dark_wood_mat
	var th_mat: StandardMaterial3D = char_mat if stage == 2 else thatch_mat
	var hd_mat: StandardMaterial3D = char_mat if stage == 2 else hide_mat

	match building_type:
		"CAMPFIRE":
			if stage == 3:
				var ash := CylinderMesh.new()
				ash.top_radius = 0.9
				ash.bottom_radius = 1.2
				ash.height = 0.08
				mf.add_mesh(root, ash, Vector3(0.0, 0.04, 0.0), ash_mat)
				for i in range(5):
					var ang := float(i) * TAU / 5.0 + 0.3
					var rock := SphereMesh.new()
					rock.radius = 0.22
					rock.height = 0.30
					mf.add_mesh(root, rock, Vector3(cos(ang) * (1.0 + float(i % 2) * 0.35), 0.12, sin(ang) * (1.0 + float(i % 2) * 0.35)), stone_mat)
				for j in range(2):
					var log_m := CylinderMesh.new()
					log_m.top_radius = 0.10
					log_m.bottom_radius = 0.12
					log_m.height = 1.1
					mf.add_mesh(root, log_m, Vector3(float(j) * 0.4 - 0.2, 0.08, 0.1), char_mat, Vector3(88.0, float(j) * 75.0, 0.0))
			else:
				var rock_count := 8 if stage == 0 else (7 if stage == 1 else 5)
				for i in range(rock_count):
					var ang := float(i) * TAU / 8.0
					var rock := SphereMesh.new()
					rock.radius = 0.25
					rock.height = 0.35
					var offset_dist := 1.1 if stage == 0 else (1.1 + (0.3 if i % 3 == 0 else 0.0))
					mf.add_mesh(root, rock, Vector3(cos(ang) * offset_dist, 0.15, sin(ang) * offset_dist), stone_mat)
				var log_count := 3 if stage <= 1 else 2
				for j in range(log_count):
					var log_m := CylinderMesh.new()
					log_m.top_radius = 0.12
					log_m.bottom_radius = 0.14
					log_m.height = 1.6
					var log_rot := Vector3(72.0, float(j) * 60.0, 0.0)
					if stage == 1 and j == 1:
						log_rot = Vector3(85.0, 80.0, 10.0)
					mf.add_mesh(root, log_m, Vector3(0.0, 0.25, 0.0), dw_mat, log_rot)
				var flame := PrismMesh.new()
				if stage == 0:
					flame.size = Vector3(0.68, 1.15, 0.68)
				elif stage == 1:
					flame.size = Vector3(0.55, 0.90, 0.55)
				else:
					flame.size = Vector3(0.35, 0.55, 0.35)
				var flame_energy := 3.0 if stage == 0 else (2.0 if stage == 1 else 0.9)
				var flame_mat: StandardMaterial3D = mf.make_mat(Color(1.0, 0.45, 0.10), 0.3, Color(1.0, 0.38, 0.06), flame_energy)
				mf.add_mesh(root, flame, Vector3(0.0, 0.62 if stage < 2 else 0.35, 0.0), flame_mat, Vector3.ZERO, "FlameMesh")
				if not is_blueprint:
					var light := OmniLight3D.new()
					light.name = "CampfireLight"
					light.light_color = Color(1.0, 0.50, 0.16)
					light.light_energy = 3.2 if stage == 0 else (2.2 if stage == 1 else 0.8)
					light.omni_range = 16.0 if stage < 2 else 9.0
					light.shadow_enabled = (stage == 0)
					light.position = Vector3(0.0, 1.45, 0.0)
					root.add_child(light)

		"SLEEPING_HUT":
			if stage == 3:
				var mound := CylinderMesh.new()
				mound.top_radius = 1.5
				mound.bottom_radius = 2.2
				mound.height = 0.24
				mf.add_mesh(root, mound, Vector3(0.0, 0.12, 0.0), thatch_mat)
				var cap := CylinderMesh.new()
				cap.top_radius = 0.9
				cap.bottom_radius = 1.4
				cap.height = 0.14
				mf.add_mesh(root, cap, Vector3(0.1, 0.22, -0.1), char_mat)
				for k in range(3):
					var stick := CylinderMesh.new()
					stick.top_radius = 0.06
					stick.bottom_radius = 0.08
					stick.height = 1.4
					mf.add_mesh(root, stick, Vector3(float(k) * 0.6 - 0.6, 0.15, 0.2), dw_mat, Vector3(85.0, float(k) * 55.0, 0.0))
			else:
				var base := CylinderMesh.new()
				base.top_radius = 0.3
				base.bottom_radius = 2.15
				base.height = 2.4 if stage == 0 else (2.2 if stage == 1 else 1.6)
				var base_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 5.0) if stage == 1 else Vector3(10.0, 0.0, 16.0))
				var base_pos := Vector3(0.0, 1.2, 0.0) if stage == 0 else (Vector3(0.0, 1.1, 0.0) if stage == 1 else Vector3(0.1, 0.85, 0.0))
				mf.add_mesh(root, base, base_pos, th_mat, base_rot)

				var hide_cap := CylinderMesh.new()
				hide_cap.top_radius = 0.15
				hide_cap.bottom_radius = 1.55
				hide_cap.height = 1.4 if stage < 2 else 0.9
				var cap_pos := Vector3(0.0, 1.75, 0.0) if stage == 0 else (Vector3(0.0, 1.65, 0.0) if stage == 1 else Vector3(0.3, 1.25, 0.1))
				var cap_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 7.0) if stage == 1 else Vector3(-14.0, 16.0, 0.0))
				mf.add_mesh(root, hide_cap, cap_pos, hd_mat, cap_rot)

				if stage < 2:
					var doorway := BoxMesh.new()
					doorway.size = Vector3(0.85, 1.15, 0.7)
					var d_rot := Vector3.ZERO if stage == 0 else Vector3(0.0, 8.0, -4.0)
					mf.add_mesh(root, doorway, Vector3(0.0, 0.58, 1.55), dw_mat, d_rot)

					var banner := BoxMesh.new()
					banner.size = Vector3(0.45, 0.55, 0.08)
					mf.add_mesh(root, banner, Vector3(0.0, 2.55 if stage == 0 else 2.35, 0.0), banner_mat)

		"FORAGER_LODGE":
			if stage == 3:
				var flat_roof := BoxMesh.new()
				flat_roof.size = Vector3(3.2, 0.12, 2.7)
				mf.add_mesh(root, flat_roof, Vector3(0.0, 0.06, 0.0), thatch_mat)
				for x in [-1.3, 1.3]:
					for z in [-1.1, 1.1]:
						var stub := CylinderMesh.new()
						stub.top_radius = 0.10
						stub.bottom_radius = 0.12
						stub.height = 0.4
						mf.add_mesh(root, stub, Vector3(x, 0.2, z), w_mat)
			else:
				for x in [-1.4, 1.4]:
					for z in [-1.2, 1.2]:
						if stage == 2 and x < 0.0 and z < 0.0:
							var stub := CylinderMesh.new()
							stub.top_radius = 0.10
							stub.bottom_radius = 0.12
							stub.height = 0.8
							mf.add_mesh(root, stub, Vector3(x, 0.4, z), char_mat)
						else:
							var post := CylinderMesh.new()
							post.top_radius = 0.10
							post.bottom_radius = 0.12
							post.height = 2.1
							var p_rot := Vector3.ZERO
							if stage == 1 and x < 0:
								p_rot = Vector3(6.0, 0.0, -5.0)
							elif stage == 2:
								p_rot = Vector3(14.0, 0.0, 12.0) if x > 0 else Vector3(-12.0, 0.0, -8.0)
							mf.add_mesh(root, post, Vector3(x, 1.05, z), w_mat, p_rot)

				var roof := BoxMesh.new()
				roof.size = Vector3(3.3, 0.22, 2.9)
				var r_pos := Vector3(0.0, 2.15, 0.0) if stage == 0 else (Vector3(0.0, 1.95, 0.0) if stage == 1 else Vector3(0.2, 1.3, 0.0))
				var r_rot := Vector3(8.0, 0.0, 0.0) if stage == 0 else (Vector3(14.0, 0.0, -8.0) if stage == 1 else Vector3(26.0, 0.0, -18.0))
				mf.add_mesh(root, roof, r_pos, th_mat, r_rot)

				var basket := CylinderMesh.new()
				basket.top_radius = 0.45
				basket.bottom_radius = 0.35
				basket.height = 0.65
				var b1_rot := Vector3.ZERO if stage == 0 else Vector3(70.0, 20.0, 0.0)
				mf.add_mesh(root, basket, Vector3(-0.6, 0.35, 0.3), hd_mat, b1_rot)
				if stage < 2:
					mf.add_mesh(root, basket, Vector3(0.6, 0.35, -0.3), banner_mat)

		"CRAFTING_PIT":
			if stage == 3:
				var rim := CylinderMesh.new()
				rim.top_radius = 1.8
				rim.bottom_radius = 2.0
				rim.height = 0.16
				mf.add_mesh(root, rim, Vector3(0.0, 0.08, 0.0), stone_mat)
				var ash := CylinderMesh.new()
				ash.top_radius = 1.3
				ash.bottom_radius = 1.5
				ash.height = 0.08
				mf.add_mesh(root, ash, Vector3(0.0, 0.05, 0.0), ash_mat)
				var anvil := BoxMesh.new()
				anvil.size = Vector3(0.75, 0.35, 0.65)
				mf.add_mesh(root, anvil, Vector3(0.0, 0.2, 0.0), mf.make_mat(Color(0.28, 0.28, 0.30), 0.8), Vector3(16.0, 22.0, 0.0))
			else:
				var pit_ring := CylinderMesh.new()
				pit_ring.top_radius = 1.9
				pit_ring.bottom_radius = 2.1
				pit_ring.height = 0.35 if stage < 2 else 0.22
				mf.add_mesh(root, pit_ring, Vector3(0.0, 0.18 if stage < 2 else 0.11, 0.0), stone_mat)

				var anvil := BoxMesh.new()
				anvil.size = Vector3(0.95, 0.75, 0.75)
				var a_rot := Vector3.ZERO if stage == 0 else (Vector3(5.0, 0.0, 0.0) if stage == 1 else Vector3(14.0, 18.0, 0.0))
				mf.add_mesh(root, anvil, Vector3(0.0, 0.55 if stage < 2 else 0.4, 0.0), mf.make_mat(Color(0.32, 0.32, 0.34), 0.75), a_rot)

				if stage < 2:
					var rack := BoxMesh.new()
					rack.size = Vector3(1.5, 1.2, 0.25)
					var rack_rot := Vector3.ZERO if stage == 0 else Vector3(8.0, 0.0, 0.0)
					mf.add_mesh(root, rack, Vector3(0.0, 0.85, -1.3), w_mat, rack_rot)

					var flint_slab := PrismMesh.new()
					flint_slab.size = Vector3(0.4, 0.5, 0.4)
					mf.add_mesh(root, flint_slab, Vector3(0.9, 0.45, 0.5), mf.make_mat(Color(0.2, 0.22, 0.26), 0.35))

		"WEAPON_RACK":
			if stage == 3:
				for x in [-0.8, 0.8]:
					var stub := CylinderMesh.new()
					stub.top_radius = 0.08
					stub.bottom_radius = 0.10
					stub.height = 0.4
					mf.add_mesh(root, stub, Vector3(x, 0.2, 0.0), char_mat)
				var bar := CylinderMesh.new()
				bar.top_radius = 0.05
				bar.bottom_radius = 0.05
				bar.height = 1.8
				mf.add_mesh(root, bar, Vector3(0.0, 0.08, 0.2), char_mat, Vector3(0.0, 25.0, 90.0))
			else:
				for x in [-0.9, 0.9]:
					var post := CylinderMesh.new()
					post.top_radius = 0.08
					post.bottom_radius = 0.10
					post.height = 1.8
					var p_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 7.0 if x > 0 else -7.0) if stage == 1 else Vector3(14.0, 0.0, 22.0 if x > 0 else -18.0))
					mf.add_mesh(root, post, Vector3(x, 0.9, 0.0), w_mat, p_rot)

				var bar := CylinderMesh.new()
				bar.top_radius = 0.06
				bar.bottom_radius = 0.06
				bar.height = 2.2
				var b_pos := Vector3(0.0, 1.45, 0.0) if stage < 2 else Vector3(0.2, 1.1, 0.0)
				var b_rot := Vector3(0.0, 0.0, 90.0) if stage == 0 else (Vector3(0.0, 0.0, 84.0) if stage == 1 else Vector3(15.0, 0.0, 65.0))
				mf.add_mesh(root, bar, b_pos, w_mat, b_rot)

				var spear_count := 3 if stage == 0 else (2 if stage == 1 else 1)
				for x_s in [-0.45, 0.0, 0.45].slice(0, spear_count):
					var sp := CylinderMesh.new()
					sp.top_radius = 0.03
					sp.bottom_radius = 0.03
					sp.height = 1.65 if stage < 2 else 0.9
					mf.add_mesh(root, sp, Vector3(x_s, 0.95 if stage < 2 else 0.55, 0.15), mf.make_mat(Color(0.6, 0.45, 0.28)), Vector3(-12.0, 0.0, 0.0))

				var shield := CylinderMesh.new()
				shield.top_radius = 0.38
				shield.bottom_radius = 0.38
				shield.height = 0.10
				var sh_pos := Vector3(0.0, 0.85, -0.18) if stage < 2 else Vector3(0.0, 0.35, -0.2)
				var sh_rot := Vector3(90.0, 0.0, 0.0) if stage == 0 else Vector3(80.0, 15.0, 0.0)
				mf.add_mesh(root, shield, sh_pos, banner_mat, sh_rot)

		"SACRED_TOTEM":
			if stage == 3:
				var plinth := CylinderMesh.new()
				plinth.top_radius = 1.35
				plinth.bottom_radius = 1.65
				plinth.height = 0.32
				mf.add_mesh(root, plinth, Vector3(0.0, 0.16, 0.0), stone_mat)
				var toppled := CylinderMesh.new()
				toppled.top_radius = 0.36
				toppled.bottom_radius = 0.46
				toppled.height = 3.6
				mf.add_mesh(root, toppled, Vector3(0.0, 0.45, 0.6), char_mat, Vector3(90.0, 15.0, 0.0))
				var sk := SphereMesh.new()
				sk.radius = 0.20
				sk.height = 0.38
				var skull_mat: StandardMaterial3D = mf.make_mat(Color(0.76, 0.68, 0.58), 0.88)
				mf.add_mesh(root, sk, Vector3(-0.7, 0.2, 1.4), skull_mat)
			else:
				var plinth := CylinderMesh.new()
				plinth.top_radius = 1.35
				plinth.bottom_radius = 1.65
				plinth.height = 0.55
				mf.add_mesh(root, plinth, Vector3(0.0, 0.28, 0.0), stone_mat)

				var pole := CylinderMesh.new()
				pole.top_radius = 0.36
				pole.bottom_radius = 0.46
				pole.height = 3.8
				var p_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 6.0) if stage == 1 else Vector3(0.0, 0.0, 22.0))
				var p_pos := Vector3(0.0, 2.1, 0.0) if stage < 2 else Vector3(0.4, 1.9, 0.0)
				mf.add_mesh(root, pole, p_pos, dw_mat, p_rot)

				var cross := BoxMesh.new()
				cross.size = Vector3(1.85, 0.32, 0.32)
				var c_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 6.0) if stage == 1 else Vector3(0.0, 0.0, 36.0))
				var c_pos := Vector3(0.0, 3.15, 0.0) if stage == 0 else (Vector3(0.1, 3.1, 0.0) if stage == 1 else Vector3(0.7, 2.7, 0.0))
				mf.add_mesh(root, cross, c_pos, w_mat, c_rot)

				var skull_mat: StandardMaterial3D = mf.make_mat(Color(0.76, 0.68, 0.58), 0.88)
				var blood_mat: StandardMaterial3D = mf.make_mat(Color(0.45, 0.06, 0.06), 0.90)
				if stage < 2:
					for sx in [-0.75, 0.75]:
						var sk := SphereMesh.new()
						sk.radius = 0.20
						sk.height = 0.38
						mf.add_mesh(root, sk, Vector3(sx, 2.95, 0.16), skull_mat)
					var altar_stain := CylinderMesh.new()
					altar_stain.top_radius = 0.85
					altar_stain.bottom_radius = 0.95
					altar_stain.height = 0.06
					mf.add_mesh(root, altar_stain, Vector3(0.0, 0.58, 0.45), blood_mat)

				var spirit_gem := SphereMesh.new()
				spirit_gem.radius = 0.38 if stage < 2 else 0.22
				spirit_gem.height = 0.76 if stage < 2 else 0.44
				var gem_energy := 2.6 if stage == 0 else (1.4 if stage == 1 else 0.6)
				var glow_mat: StandardMaterial3D = mf.make_mat(faction_color, 0.2, faction_color, gem_energy)
				var gem_pos := Vector3(0.0, 4.15, 0.0) if stage == 0 else (Vector3(0.2, 4.05, 0.0) if stage == 1 else Vector3(1.1, 3.4, 0.0))
				mf.add_mesh(root, spirit_gem, gem_pos, glow_mat, Vector3.ZERO, "TotemSpirit")

		"STORAGE_PIT":
			if stage == 3:
				var mound := CylinderMesh.new()
				mound.top_radius = 1.6
				mound.bottom_radius = 1.85
				mound.height = 0.22
				mf.add_mesh(root, mound, Vector3(0.0, 0.11, 0.0), stone_mat)
				var ash := CylinderMesh.new()
				ash.top_radius = 1.1
				ash.bottom_radius = 1.4
				ash.height = 0.08
				mf.add_mesh(root, ash, Vector3(0.0, 0.08, 0.0), ash_mat)
			else:
				var mound := CylinderMesh.new()
				mound.top_radius = 1.15
				mound.bottom_radius = 1.75
				mound.height = 1.05 if stage < 2 else 0.55
				mf.add_mesh(root, mound, Vector3(0.0, 0.52 if stage < 2 else 0.27, 0.0), stone_mat)

				var tarp := CylinderMesh.new()
				tarp.top_radius = 0.2
				tarp.bottom_radius = 1.45
				tarp.height = 0.9 if stage < 2 else 0.45
				var t_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 7.0) if stage == 1 else Vector3(12.0, 18.0, 0.0))
				mf.add_mesh(root, tarp, Vector3(0.0, 1.35 if stage < 2 else 0.65, 0.0), hd_mat, t_rot)

		"PALISADE_WALL":
			if stage == 3:
				for x in [-1.2, -0.6, 0.0, 0.6, 1.2]:
					var stub := CylinderMesh.new()
					stub.top_radius = 0.16
					stub.bottom_radius = 0.24
					stub.height = 0.45
					mf.add_mesh(root, stub, Vector3(x, 0.22, 0.0), char_mat)
				var beam := BoxMesh.new()
				beam.size = Vector3(2.6, 0.18, 0.25)
				mf.add_mesh(root, beam, Vector3(0.0, 0.1, 0.3), dw_mat, Vector3(0.0, 8.0, 0.0))
			else:
				var stakes := [-1.2, -0.6, 0.0, 0.6, 1.2]
				for idx in range(stakes.size()):
					var x: float = stakes[idx]
					if stage == 2 and (idx == 2 or idx == 3):
						var stub := CylinderMesh.new()
						stub.top_radius = 0.16
						stub.bottom_radius = 0.24
						stub.height = 0.75
						mf.add_mesh(root, stub, Vector3(x, 0.37, 0.0), char_mat)
					else:
						var stake := CylinderMesh.new()
						stake.top_radius = 0.14
						stake.bottom_radius = 0.24
						stake.height = 2.75 if stage == 0 else (2.35 if idx == 1 else 2.75)
						var s_rot := Vector3.ZERO
						if stage == 1 and idx == 0:
							s_rot = Vector3(0.0, 0.0, -8.0)
						elif stage == 2:
							s_rot = Vector3(12.0, 0.0, 16.0 if x > 0 else -16.0)
						mf.add_mesh(root, stake, Vector3(x, 1.37 if stage < 2 else 1.2, 0.0), w_mat, s_rot)

				var beam := BoxMesh.new()
				beam.size = Vector3(3.1, 0.26, 0.35) if stage < 2 else Vector3(1.6, 0.22, 0.30)
				var b_pos := Vector3(0.0, 1.4, 0.0) if stage < 2 else Vector3(-0.6, 0.9, 0.0)
				var b_rot := Vector3.ZERO if stage == 0 else (Vector3(0.0, 0.0, 4.0) if stage == 1 else Vector3(8.0, 0.0, -18.0))
				mf.add_mesh(root, beam, b_pos, dw_mat, b_rot)

		"WATCHTOWER":
			if stage == 3:
				for x in [-0.9, 0.9]:
					for z in [-0.9, 0.9]:
						var stump := CylinderMesh.new()
						stump.top_radius = 0.14
						stump.bottom_radius = 0.18
						stump.height = 0.55
						mf.add_mesh(root, stump, Vector3(x, 0.27, z), char_mat)
				var fallen_post := CylinderMesh.new()
				fallen_post.top_radius = 0.14
				fallen_post.bottom_radius = 0.18
				fallen_post.height = 3.2
				mf.add_mesh(root, fallen_post, Vector3(0.3, 0.18, -0.2), char_mat, Vector3(84.0, 35.0, 0.0))
				var broken_deck := BoxMesh.new()
				broken_deck.size = Vector3(1.8, 0.20, 1.5)
				mf.add_mesh(root, broken_deck, Vector3(-0.2, 0.12, 0.2), dw_mat, Vector3(8.0, 15.0, 0.0))
			else:
				var leg_h := 4.2 if stage == 0 else (3.9 if stage == 1 else 3.2)
				var leg_y := 2.1 if stage == 0 else (1.95 if stage == 1 else 1.6)
				for x in [-0.9, 0.9]:
					for z in [-0.9, 0.9]:
						if stage == 2 and x > 0 and z > 0:
							var stump := CylinderMesh.new()
							stump.top_radius = 0.14
							stump.bottom_radius = 0.18
							stump.height = 1.2
							mf.add_mesh(root, stump, Vector3(x, 0.6, z), char_mat)
							continue
						var leg := CylinderMesh.new()
						leg.top_radius = 0.14
						leg.bottom_radius = 0.18
						leg.height = leg_h
						var l_rot := Vector3.ZERO
						if stage == 1 and x < 0:
							l_rot = Vector3(3.0, 0.0, -3.0)
						elif stage == 2:
							l_rot = Vector3(10.0, 0.0, -12.0)
						mf.add_mesh(root, leg, Vector3(x, leg_y, z), w_mat, l_rot)

				var deck := BoxMesh.new()
				deck.size = Vector3(2.4, 0.25, 2.4)
				var d_pos := Vector3(0.0, 3.6, 0.0) if stage == 0 else (Vector3(-0.1, 3.4, 0.0) if stage == 1 else Vector3(-0.3, 2.7, 0.1))
				var d_rot := Vector3.ZERO if stage == 0 else (Vector3(3.0, 0.0, -2.0) if stage == 1 else Vector3(12.0, 0.0, -15.0))
				mf.add_mesh(root, deck, d_pos, dw_mat, d_rot)

				var parapet := BoxMesh.new()
				parapet.size = Vector3(2.45, 0.75, 0.18)
				var p_rot := d_rot
				var p_y_offset := 0.45
				mf.add_mesh(root, parapet, d_pos + Vector3(0.0, p_y_offset, 1.15), banner_mat, p_rot)
				if stage < 2:
					mf.add_mesh(root, parapet, d_pos + Vector3(0.0, p_y_offset, -1.15), banner_mat, p_rot)

		"BARRACKS":
			if stage == 3:
				var ring := CylinderMesh.new()
				ring.top_radius = 2.1
				ring.bottom_radius = 2.3
				ring.height = 0.12
				mf.add_mesh(root, ring, Vector3(0.0, 0.06, 0.0), stone_mat)
				var broken_post := CylinderMesh.new()
				broken_post.top_radius = 0.10
				broken_post.bottom_radius = 0.12
				broken_post.height = 1.4
				mf.add_mesh(root, broken_post, Vector3(-0.3, 0.1, 0.2), char_mat, Vector3(85.0, 40.0, 0.0))
				var d_head := SphereMesh.new()
				d_head.radius = 0.22
				mf.add_mesh(root, d_head, Vector3(0.6, 0.18, 0.5), th_mat)
			else:
				var ring := CylinderMesh.new()
				ring.top_radius = 2.1
				ring.bottom_radius = 2.3
				ring.height = 0.22 if stage < 2 else 0.14
				mf.add_mesh(root, ring, Vector3(0.0, 0.11 if stage < 2 else 0.07, 0.0), stone_mat)

				for x in [-1.5, 1.5]:
					var post := CylinderMesh.new()
					post.top_radius = 0.10
					post.bottom_radius = 0.12
					post.height = 2.3 if stage < 2 else 1.8
					var p_rot := Vector3.ZERO if stage == 0 else (Vector3(4.0, 0.0, -5.0) if stage == 1 else Vector3(18.0, 0.0, 12.0))
					mf.add_mesh(root, post, Vector3(x, 1.15 if stage < 2 else 0.9, -1.3), w_mat, p_rot)

				var awning := BoxMesh.new()
				awning.size = Vector3(3.4, 0.18, 1.4)
				var a_pos := Vector3(0.0, 2.25, -1.2) if stage == 0 else (Vector3(0.0, 2.05, -1.2) if stage == 1 else Vector3(0.0, 1.35, -1.2))
				var a_rot := Vector3(14.0, 0.0, 0.0) if stage == 0 else (Vector3(24.0, 0.0, -8.0) if stage == 1 else Vector3(38.0, 0.0, 16.0))
				mf.add_mesh(root, awning, a_pos, hd_mat, a_rot)

				var d_post := CylinderMesh.new()
				d_post.top_radius = 0.10
				d_post.bottom_radius = 0.12
				d_post.height = 1.65 if stage < 2 else 1.1
				var dp_rot := Vector3.ZERO if stage == 0 else (Vector3(8.0, 0.0, 0.0) if stage == 1 else Vector3(45.0, 20.0, 0.0))
				mf.add_mesh(root, d_post, Vector3(-0.9, 0.85 if stage < 2 else 0.5, 0.7), dw_mat, dp_rot)

				var d_bar := BoxMesh.new()
				d_bar.size = Vector3(0.95, 0.18, 0.18)
				var db_rot := dp_rot
				mf.add_mesh(root, d_bar, Vector3(-0.9, 1.35 if stage < 2 else 0.85, 0.7), w_mat, db_rot)

				var d_head := SphereMesh.new()
				d_head.radius = 0.22
				mf.add_mesh(root, d_head, Vector3(-0.9, 1.72 if stage < 2 else 1.15, 0.7), th_mat)

				var t_leg := CylinderMesh.new()
				t_leg.top_radius = 0.08
				t_leg.bottom_radius = 0.10
				t_leg.height = 1.3
				var tl_rot := Vector3.ZERO if stage == 0 else (Vector3(12.0, 0.0, 0.0) if stage == 1 else Vector3(75.0, 30.0, 0.0))
				var tl_pos := Vector3(1.1, 0.65, 0.8) if stage < 2 else Vector3(1.1, 0.25, 0.8)
				mf.add_mesh(root, t_leg, tl_pos, w_mat, tl_rot)

				var target_disc := CylinderMesh.new()
				target_disc.top_radius = 0.55
				target_disc.bottom_radius = 0.55
				target_disc.height = 0.22
				var td_rot := Vector3(82.0, 0.0, 0.0) if stage == 0 else (Vector3(70.0, 25.0, 0.0) if stage == 1 else Vector3(10.0, 45.0, 0.0))
				var td_pos := Vector3(1.1, 1.25, 0.8) if stage < 2 else Vector3(1.1, 0.18, 0.8)
				mf.add_mesh(root, target_disc, td_pos, th_mat, td_rot)

				var bullseye := CylinderMesh.new()
				bullseye.top_radius = 0.22
				bullseye.bottom_radius = 0.22
				bullseye.height = 0.26
				mf.add_mesh(root, bullseye, td_pos, banner_mat, td_rot)

		"SHAMAN_SHACK":
			var herb_mat: StandardMaterial3D = mf.make_mat(Color(0.24, 0.42, 0.22), 0.94, Color.BLACK, 0.0, 1.0, "hide")
			if stage == 3:
				var rubble_hut := CylinderMesh.new()
				rubble_hut.top_radius = 1.4
				rubble_hut.bottom_radius = 2.0
				rubble_hut.height = 0.25
				mf.add_mesh(root, rubble_hut, Vector3(0.0, 0.12, 0.0), char_mat)
				var spilled_cauldron := CylinderMesh.new()
				spilled_cauldron.top_radius = 0.38
				spilled_cauldron.bottom_radius = 0.46
				spilled_cauldron.height = 0.55
				mf.add_mesh(root, spilled_cauldron, Vector3(0.85, 0.22, 1.35), stone_mat, Vector3(0.0, 0.0, 90.0))
				var puddle := CylinderMesh.new()
				puddle.top_radius = 0.65
				puddle.bottom_radius = 0.75
				puddle.height = 0.04
				var puddle_mat: StandardMaterial3D = mf.make_mat(Color(0.18, 0.45, 0.25), 0.5, Color(0.15, 0.4, 0.2), 0.5)
				mf.add_mesh(root, puddle, Vector3(1.25, 0.03, 1.35), puddle_mat)
			else:
				var hut := CylinderMesh.new()
				hut.top_radius = 0.35 if stage < 2 else 0.45
				hut.bottom_radius = 1.95
				hut.height = 2.2 if stage == 0 else (2.0 if stage == 1 else 1.4)
				var h_rot := Vector3.ZERO if stage == 0 else (Vector3(4.0, 0.0, -3.0) if stage == 1 else Vector3(16.0, 0.0, -14.0))
				mf.add_mesh(root, hut, Vector3(0.0, 1.1 if stage == 0 else (1.0 if stage == 1 else 0.7), 0.0), hd_mat, h_rot)

				var cap := CylinderMesh.new()
				cap.top_radius = 0.18
				cap.bottom_radius = 1.45
				cap.height = 1.1 if stage < 2 else 0.6
				var cap_mat: StandardMaterial3D = char_mat if stage == 2 else herb_mat
				var cap_pos := Vector3(0.0, 1.85 if stage == 0 else (1.7 if stage == 1 else 1.1), 0.0)
				mf.add_mesh(root, cap, cap_pos, cap_mat, h_rot)

				if stage < 2:
					var mat_pad := BoxMesh.new()
					mat_pad.size = Vector3(1.3, 0.10, 1.9)
					mf.add_mesh(root, mat_pad, Vector3(-0.7, 0.06, 1.5), th_mat)

				var cauldron := CylinderMesh.new()
				cauldron.top_radius = 0.38
				cauldron.bottom_radius = 0.46
				cauldron.height = 0.55
				var c_rot := Vector3.ZERO if stage == 0 else (Vector3(6.0, 0.0, 0.0) if stage == 1 else Vector3(18.0, 0.0, 12.0))
				mf.add_mesh(root, cauldron, Vector3(0.85, 0.28, 1.35), stone_mat, c_rot)

				var brew := SphereMesh.new()
				brew.radius = 0.32
				brew.height = 0.28
				var brew_glow := 2.2 if stage == 0 else (1.4 if stage == 1 else 0.6)
				var brew_mat: StandardMaterial3D = mf.make_mat(Color(0.28, 0.92, 0.42), 0.3, Color(0.22, 0.88, 0.38), brew_glow)
				mf.add_mesh(root, brew, Vector3(0.85, 0.54 if stage < 2 else 0.48, 1.35), brew_mat, c_rot)

				if not is_blueprint:
					var sl := OmniLight3D.new()
					sl.name = "ShamanLight"
					sl.light_color = Color(0.38, 0.95, 0.48)
					sl.light_energy = 1.8 if stage == 0 else (1.2 if stage == 1 else 0.5)
					sl.omni_range = 10.0 if stage < 2 else 5.0
					sl.position = Vector3(0.85, 1.1 if stage < 2 else 0.8, 1.35)
					root.add_child(sl)




static func build_wildlife_mesh(mf: Node, animal_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "AnimalVisual"

	var anim_pivot := Node3D.new()
	anim_pivot.name = "AnimalPivot"
	anim_pivot.rotation_degrees.y = 180.0
	root.add_child(anim_pivot)
	if WILDLIFE_MODELS.has(animal_type):
		var model := _instantiate_model("res://assets/models/wildlife/%s.glb" % WILDLIFE_MODELS[animal_type])
		if model != null:
			var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player != null and player.has_animation("Bite"):
				player.name = "BiteAnimation"
				_apply_psx_glb_materials(model)
				model.rotation.y = PI  # The existing procedural pivot turns +Z models around.
				anim_pivot.add_child(model)
				return root
			model.free()

	match animal_type:
		"DEER":
			var mat: StandardMaterial3D = mf.make_mat(Color(0.68, 0.48, 0.28), 0.85)
			var body := CapsuleMesh.new()
			body.radius = 0.32
			body.height = 1.25
			mf.add_mesh(anim_pivot, body, Vector3(0.0, 0.88, 0.0), mat, Vector3(90.0, 0.0, 0.0))
			var head := SphereMesh.new()
			head.radius = 0.22
			mf.add_mesh(anim_pivot, head, Vector3(0.0, 1.38, 0.65), mat)
			var ant_mat: StandardMaterial3D = mf.make_mat(Color(0.85, 0.80, 0.70), 0.7)
			var ant := CylinderMesh.new()
			ant.top_radius = 0.03
			ant.bottom_radius = 0.05
			ant.height = 0.55
			mf.add_mesh(anim_pivot, ant, Vector3(-0.14, 1.68, 0.62), ant_mat, Vector3(-15.0, 0.0, 22.0))
			mf.add_mesh(anim_pivot, ant, Vector3(0.14, 1.68, 0.62), ant_mat, Vector3(-15.0, 0.0, -22.0))
			for x in [-0.18, 0.18]:
				for z in [-0.36, 0.36]:
					var leg := CylinderMesh.new()
					leg.top_radius = 0.06
					leg.bottom_radius = 0.04
					leg.height = 0.72
					mf.add_mesh(anim_pivot, leg, Vector3(x, 0.36, z), mat)

		"BOAR", "SLATEBACK_BOAR":
			var mat: StandardMaterial3D = mf.make_mat(Color(0.38, 0.28, 0.24), 0.92)
			var body := SphereMesh.new()
			body.radius = 0.45
			body.height = 1.05
			mf.add_mesh(anim_pivot, body, Vector3(0.0, 0.62, 0.0), mat, Vector3(90.0, 0.0, 0.0))
			var tusk := PrismMesh.new()
			tusk.size = Vector3(0.06, 0.22, 0.06)
			var tusk_mat: StandardMaterial3D = mf.make_mat(Color(0.95, 0.92, 0.85), 0.4)
			mf.add_mesh(anim_pivot, tusk, Vector3(-0.18, 0.58, 0.56), tusk_mat, Vector3(45.0, 0.0, 0.0))
			mf.add_mesh(anim_pivot, tusk, Vector3(0.18, 0.58, 0.56), tusk_mat, Vector3(45.0, 0.0, 0.0))

		"WOLF", "REEDJAW":
			var mat: StandardMaterial3D = mf.make_mat(Color(0.45, 0.47, 0.50), 0.88)
			var body := CapsuleMesh.new()
			body.radius = 0.28
			body.height = 1.15
			mf.add_mesh(anim_pivot, body, Vector3(0.0, 0.68, 0.0), mat, Vector3(90.0, 0.0, 0.0))
			var head := BoxMesh.new()
			head.size = Vector3(0.32, 0.30, 0.46)
			mf.add_mesh(anim_pivot, head, Vector3(0.0, 0.88, 0.66), mat)

		"SABERTOOTH":
			var mat: StandardMaterial3D = mf.make_mat(Color(0.84, 0.64, 0.28), 0.82)
			var body := CapsuleMesh.new()
			body.radius = 0.38
			body.height = 1.48
			mf.add_mesh(anim_pivot, body, Vector3(0.0, 0.80, 0.0), mat, Vector3(90.0, 0.0, 0.0))
			var head := SphereMesh.new()
			head.radius = 0.30
			mf.add_mesh(anim_pivot, head, Vector3(0.0, 1.05, 0.82), mat)
			var fang := PrismMesh.new()
			fang.size = Vector3(0.05, 0.26, 0.05)
			var fang_mat: StandardMaterial3D = mf.make_mat(Color(0.98, 0.95, 0.90), 0.3)
			mf.add_mesh(anim_pivot, fang, Vector3(-0.12, 0.82, 1.05), fang_mat, Vector3(175.0, 0.0, 0.0))
			mf.add_mesh(anim_pivot, fang, Vector3(0.12, 0.82, 1.05), fang_mat, Vector3(175.0, 0.0, 0.0))

		"MAMMOTH":
			var fur: StandardMaterial3D = mf.make_mat(Color(0.34, 0.22, 0.14), 0.96)
			var body := SphereMesh.new()
			body.radius = 1.35
			body.height = 3.2
			mf.add_mesh(anim_pivot, body, Vector3(0.0, 1.95, 0.0), fur, Vector3(90.0, 0.0, 0.0))
			var head := SphereMesh.new()
			head.radius = 0.85
			mf.add_mesh(anim_pivot, head, Vector3(0.0, 2.45, 1.55), fur)
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.22
			trunk.bottom_radius = 0.12
			trunk.height = 1.55
			mf.add_mesh(anim_pivot, trunk, Vector3(0.0, 1.55, 2.25), fur, Vector3(22.0, 0.0, 0.0))
			var ivory: StandardMaterial3D = mf.make_mat(Color(0.95, 0.92, 0.84), 0.45)
			var tusk := CylinderMesh.new()
			tusk.top_radius = 0.06
			tusk.bottom_radius = 0.14
			tusk.height = 1.9
			mf.add_mesh(anim_pivot, tusk, Vector3(-0.55, 1.75, 2.35), ivory, Vector3(68.0, -18.0, 0.0))
			mf.add_mesh(anim_pivot, tusk, Vector3(0.55, 1.75, 2.35), ivory, Vector3(68.0, 18.0, 0.0))
			for x in [-0.7, 0.7]:
				for z in [-0.85, 0.85]:
					var leg := CylinderMesh.new()
					leg.top_radius = 0.34
					leg.bottom_radius = 0.30
					leg.height = 1.5
					mf.add_mesh(anim_pivot, leg, Vector3(x, 0.75, z), fur)

		"CAVE_BEAR":
			var fur: StandardMaterial3D = mf.make_mat(Color(0.28, 0.20, 0.16), 0.95)
			var body := SphereMesh.new()
			body.radius = 0.95
			body.height = 2.2
			mf.add_mesh(anim_pivot, body, Vector3(0.0, 1.25, 0.0), fur, Vector3(85.0, 0.0, 0.0))
			var head := SphereMesh.new()
			head.radius = 0.56
			mf.add_mesh(anim_pivot, head, Vector3(0.0, 1.72, 1.15), fur)
			for x in [-0.52, 0.52]:
				for z in [-0.65, 0.65]:
					var leg := CylinderMesh.new()
					leg.top_radius = 0.26
					leg.bottom_radius = 0.24
					leg.height = 1.0
					mf.add_mesh(anim_pivot, leg, Vector3(x, 0.50, z), fur)

	return root


static func build_resource_node_mesh(mf: Node, node_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ResourceVisual"
	if RESOURCE_MODELS.has(node_type):
		var model := build_environment_mesh(RESOURCE_MODELS[node_type])
		if model != null:
			root.add_child(model)
			return root

	match node_type:
		"TREE":
			var trunk_mat: StandardMaterial3D = mf.make_mat(Color(0.42, 0.27, 0.15), 0.92)
			var leaf_mat: StandardMaterial3D = mf.make_mat(Color(0.18, 0.44, 0.19), 0.88)
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.22
			trunk.bottom_radius = 0.34
			trunk.height = 2.8
			mf.add_mesh(root, trunk, Vector3(0.0, 1.4, 0.0), trunk_mat)
			var cone1 := CylinderMesh.new()
			cone1.top_radius = 0.15
			cone1.bottom_radius = 1.65
			cone1.height = 2.4
			mf.add_mesh(root, cone1, Vector3(0.0, 3.2, 0.0), leaf_mat)
			var cone2 := CylinderMesh.new()
			cone2.top_radius = 0.05
			cone2.bottom_radius = 1.25
			cone2.height = 2.1
			mf.add_mesh(root, cone2, Vector3(0.0, 4.5, 0.0), leaf_mat)

		"STONE":
			var stone_mat: StandardMaterial3D = mf.make_mat(Color(0.52, 0.52, 0.50), 0.86)
			var rock := SphereMesh.new()
			rock.radius = 1.25
			rock.height = 1.65
			mf.add_mesh(root, rock, Vector3(0.0, 0.65, 0.0), stone_mat)
			var rock2 := BoxMesh.new()
			rock2.size = Vector3(1.1, 0.95, 1.0)
			mf.add_mesh(root, rock2, Vector3(0.7, 0.48, 0.4), stone_mat, Vector3(10.0, 28.0, -8.0))

		"FLINT":
			var flint_mat: StandardMaterial3D = mf.make_mat(Color(0.18, 0.20, 0.26), 0.35)
			for i in range(4):
				var shard := PrismMesh.new()
				shard.size = Vector3(0.85, 1.45, 0.65)
				var ang := float(i) * 1.4
				mf.add_mesh(root, shard, Vector3(cos(ang) * 0.45, 0.62, sin(ang) * 0.45), flint_mat, Vector3(12.0, float(i) * 45.0, 8.0))

		"BERRY_BUSH":
			var bush_mat: StandardMaterial3D = mf.make_mat(Color(0.22, 0.50, 0.20), 0.88)
			var berry_mat: StandardMaterial3D = mf.make_mat(Color(0.82, 0.15, 0.25), 0.4)
			var bush := SphereMesh.new()
			bush.radius = 0.85
			bush.height = 1.15
			mf.add_mesh(root, bush, Vector3(0.0, 0.52, 0.0), bush_mat)
			for b_pos in [Vector3(0.45, 0.8, 0.4), Vector3(-0.4, 0.75, 0.45), Vector3(0.15, 0.95, -0.38)]:
				var berry := SphereMesh.new()
				berry.radius = 0.14
				mf.add_mesh(root, berry, b_pos, berry_mat)

		"CAVEMAN_CAVE":
			var cave_mat: StandardMaterial3D = mf.make_mat(Color(0.24, 0.21, 0.19), 0.96, Color.BLACK, 0.0, 1.0, "stone")
			var dark_mat: StandardMaterial3D = mf.make_mat(Color(0.03, 0.02, 0.02), 1.0)
			var gore_mat: StandardMaterial3D = mf.make_mat(Color(0.42, 0.05, 0.05), 0.92)
			var bone_mat: StandardMaterial3D = mf.make_mat(Color(0.78, 0.72, 0.62), 0.85)
			var mound := SphereMesh.new()
			mound.radius = 4.2
			mound.height = 5.4
			mf.add_mesh(root, mound, Vector3(0.0, 1.6, -1.0), cave_mat)
			var mouth := BoxMesh.new()
			mouth.size = Vector3(2.4, 2.4, 1.2)
			mf.add_mesh(root, mouth, Vector3(0.0, 1.2, 2.3), dark_mat)
			var stain := CylinderMesh.new()
			stain.top_radius = 1.4
			stain.bottom_radius = 1.6
			stain.height = 0.05
			mf.add_mesh(root, stain, Vector3(0.0, 0.04, 3.2), gore_mat)
			for sx in [-1.8, -1.1, 1.2, 1.8]:
				var stake := CylinderMesh.new()
				stake.top_radius = 0.06
				stake.bottom_radius = 0.08
				stake.height = 1.75
				mf.add_mesh(root, stake, Vector3(sx, 0.85, 2.3), mf.make_mat(Color(0.28, 0.18, 0.10), 0.94, Color.BLACK, 0.0, 1.0, "wood"))
				var skull := SphereMesh.new()
				skull.radius = 0.24
				mf.add_mesh(root, skull, Vector3(sx, 1.82, 2.3), bone_mat)

	return root


static func build_projectile_mesh(mf: Node, proj_type: String, tier: int) -> Node3D:
	var root := Node3D.new()
	var shaft_mat: StandardMaterial3D = mf.make_mat(Color(0.55, 0.38, 0.20), 0.8)
	var tip_col := Color(0.75, 0.75, 0.72) if tier == 1 else (Color(0.28, 0.30, 0.35) if tier == 2 else Color(0.2, 0.12, 0.32))
	var tip_mat: StandardMaterial3D = mf.make_mat(tip_col, 0.3, tip_col * 0.3 if tier >= 3 else Color.BLACK, 0.6 if tier >= 3 else 0.0)

	if proj_type == "JAVELIN":
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.04
		shaft.bottom_radius = 0.04
		shaft.height = 1.45
		mf.add_mesh(root, shaft, Vector3.ZERO, shaft_mat, Vector3(90.0, 0.0, 0.0))
		var tip := PrismMesh.new()
		tip.size = Vector3(0.12, 0.26, 0.06)
		mf.add_mesh(root, tip, Vector3(0.0, 0.0, -0.78), tip_mat, Vector3(-90.0, 0.0, 0.0))
	else:
		var arrow := CylinderMesh.new()
		arrow.top_radius = 0.022
		arrow.bottom_radius = 0.022
		arrow.height = 0.85
		mf.add_mesh(root, arrow, Vector3.ZERO, shaft_mat, Vector3(90.0, 0.0, 0.0))
		var tip := PrismMesh.new()
		tip.size = Vector3(0.08, 0.18, 0.04)
		mf.add_mesh(root, tip, Vector3(0.0, 0.0, -0.46), tip_mat, Vector3(-90.0, 0.0, 0.0))

	return root
