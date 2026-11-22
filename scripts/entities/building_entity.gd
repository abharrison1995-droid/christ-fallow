extends StaticBody3D

const Projectile3D = preload("res://scripts/entities/projectile_3d.gd")
const CombatVFX = preload("res://scripts/core/combat_vfx.gd")
const UnitAIRoutines = preload("res://scripts/entities/unit_ai_routines.gd")
const Farming = preload("res://scripts/core/farming_rules.gd")
const Gate = preload("res://scripts/core/standing_stone_gate.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")

var building_type: String = "CAMPFIRE"
var faction_id: int = 0:
	set(value):
		if value == faction_id:
			return
		var old_fid: int = faction_id
		faction_id = value
		if _index_registered:
			GameState.spatial_index.on_building_faction_changed(self, old_fid, value)
var is_constructed: bool = false
var build_progress: float = 0.0
var build_time: float = 5.0
var hp: float = 200.0
var max_hp: float = 200.0
var damage_stage: int = 0 # 0=INTACT, 1=DAMAGED, 2=CRITICAL, 3=DESTROYED
var is_destroyed: bool = false
var crop_stage: int = Farming.CropStage.EMPTY
var crop_progress := 0.0
var crop_work := 0.0
var crop_tended := false
var _pen_clock := 0.0

var _visual_root: Node3D = null
var _status_bar_mesh: MeshInstance3D = null
var _col_shape: CollisionShape3D = null
var _other_pier: CollisionShape3D
var _critical_particles: GPUParticles3D = null

var _watchtower_cd: float = 0.0
var _repro_timer: float = 0.0
var _dusk_heal_timer: float = 0.0
var _combat_timer: float = 0.0
var _bar_alpha: float = 0.0
var _flash_timer: float = 0.0
var _sink_timer: float = 0.0
var _index_registered: bool = false
var _obstacle_registered: bool = false
var _scan_cd: float = 0.0

static var _bar_shader: Shader = null


static func _get_bar_shader() -> Shader:
	if _bar_shader == null:
		_bar_shader = Shader.new()
		_bar_shader.code = """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled, unshaded, shadows_disabled, fog_disabled;

instance uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
instance uniform float bar_alpha : hint_range(0.0, 1.0) = 1.0;
instance uniform vec4 fill_color : source_color = vec4(0.25, 0.85, 0.35, 1.0);
instance uniform vec4 bg_color : source_color = vec4(0.08, 0.08, 0.08, 0.85);

void vertex() {
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	float scale_z = length(MODEL_MATRIX[2].xyz);

	vec3 cameradir_x = INV_VIEW_MATRIX[0].xyz;
	vec3 cameradir_y = INV_VIEW_MATRIX[1].xyz;
	vec3 cameradir_z = INV_VIEW_MATRIX[2].xyz;

	vec4 scaled_x = vec4(cameradir_x * scale_x, 0.0);
	vec4 scaled_y = vec4(cameradir_y * scale_y, 0.0);
	vec4 scaled_z = vec4(cameradir_z * scale_z, 0.0);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(scaled_x, scaled_y, scaled_z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	if (bar_alpha <= 0.001) {
		discard;
	}
	vec2 uv = UV;
	float border_x = 0.02;
	float border_y = 0.15;
	vec3 col = bg_color.rgb;
	float a = bg_color.a;

	if (uv.x >= border_x && uv.x <= (1.0 - border_x) && uv.y >= border_y && uv.y <= (1.0 - border_y)) {
		float inner_x = (uv.x - border_x) / (1.0 - 2.0 * border_x);
		if (inner_x <= fill_ratio) {
			col = fill_color.rgb;
			a = fill_color.a;
		}
	}
	ALBEDO = col;
	ALPHA = a * bar_alpha;
}
"""
	return _bar_shader


func setup(p_type: String, p_faction_id: int, p_pos: Vector3, p_rot_y: float = 0.0, p_constructed: bool = false) -> void:
	building_type = p_type
	faction_id = p_faction_id
	global_position = p_pos
	rotation.y = p_rot_y
	is_constructed = p_constructed

	var b_info: Dictionary = GameData.BUILDINGS.get(building_type, GameData.BUILDINGS["CAMPFIRE"])
	build_time = float(b_info["build_time"])
	var hp_mult := 1.0
	var faction_dict: Dictionary = GameState.factions.get(faction_id, {})
	if int(faction_dict.get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.KRAG_UL:
		hp_mult = 1.25
	hp_mult *= PerkSystem.get_building_hp_mult(faction_dict)
	max_hp = float(b_info["max_hp"]) * hp_mult
	hp = max_hp if is_constructed else max_hp * 0.25
	build_progress = build_time if is_constructed else 0.0
	damage_stage = 0
	is_destroyed = false

	var col_shape := CollisionShape3D.new()
	var collider_size: Vector3 = b_info.get("collider_size", Vector3.ZERO)
	if building_type == Gate.TYPE:
		var pier := BoxShape3D.new()
		pier.size = Gate.PIER_SIZE
		col_shape.shape = pier
		col_shape.position = Vector3(-Gate.PIER_OFFSET, pier.size.y * 0.5, 0.0)
		_other_pier = CollisionShape3D.new()
		_other_pier.shape = pier
		_other_pier.position = Vector3(Gate.PIER_OFFSET, pier.size.y * 0.5, 0.0)
		add_child(_other_pier)
	elif collider_size != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = collider_size
		col_shape.shape = box
		col_shape.position.y = box.size.y * 0.5
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = float(b_info["radius"]) * 0.72
		cyl.height = 2.5
		col_shape.shape = cyl
		col_shape.position.y = cyl.height * 0.5
	col_shape.disabled = building_type in Farming.WALKABLE_BUILDINGS
	add_child(col_shape)
	_col_shape = col_shape

	_rebuild_visual()
	_create_status_bar()
	_scan_cd = 0.0
	if is_inside_tree() and not _index_registered:
		_index_registered = true
		GameState.spatial_index.register_building(self)
	_sync_nav_obstacle()


## Constructed, intact buildings block pathing; blueprints and rubble do not.
func _sync_nav_obstacle() -> void:
	var should_block: bool = is_constructed and not is_destroyed and is_inside_tree() and building_type not in Farming.WALKABLE_BUILDINGS
	if should_block and not _obstacle_registered:
		_obstacle_registered = true
		GameState.valley_nav.register_building_obstacle(self, building_type, _nav_footprint_radius())
	elif not should_block and _obstacle_registered:
		_obstacle_registered = false
		GameState.valley_nav.unregister_building_obstacle(self)


func _nav_footprint_radius() -> float:
	var info: Dictionary = GameData.BUILDINGS.get(building_type, GameData.BUILDINGS["CAMPFIRE"])
	if building_type == "PALISADE_WALL":
		return 2.0
	return float(info["radius"]) + 0.4


func _disable_collision() -> void:
	if _col_shape != null:
		_col_shape.set_deferred("disabled", true)
	if _other_pier != null:
		_other_pier.set_deferred("disabled", true)


func _exit_tree() -> void:
	if _obstacle_registered:
		_obstacle_registered = false
		GameState.valley_nav.unregister_building_obstacle(self)
	if _index_registered:
		_index_registered = false
		GameState.spatial_index.unregister_building(self)


func _rebuild_visual() -> void:
	if _visual_root != null:
		remove_child(_visual_root)
		_visual_root.queue_free()
	var col: Color = GameData.FACTION_COLORS.get(faction_id, Color.WHITE)
	_visual_root = MeshFactory.build_building_stages(building_type, col, not is_constructed)
	add_child(_visual_root)
	_apply_damage_stage()


func refresh_faction_color() -> void:
	_rebuild_visual()


func _create_status_bar() -> void:
	if _status_bar_mesh != null:
		return
	var sm := ShaderMaterial.new()
	sm.shader = _get_bar_shader()

	var qm := QuadMesh.new()
	qm.size = Vector2(2.2, 0.22)

	var mi := MeshInstance3D.new()
	mi.name = "StatusBarMesh"
	mi.mesh = qm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, _get_bar_height(), 0.0)
	add_child(mi)
	_status_bar_mesh = mi
	_update_status_bar()


func _get_bar_height() -> float:
	match building_type:
		"CAMPFIRE":
			return 2.4
		"WATCHTOWER":
			return 4.8
		"SACRED_TOTEM":
			return 4.4
		"SLEEPING_HUT", "FORAGER_LODGE", "CRAFTING_PIT", "BARRACKS", "SHAMAN_SHACK":
			return 3.5
		_:
			return 3.0


func _update_status_bar() -> void:
	if _status_bar_mesh == null or is_destroyed:
		return

	var ratio: float = 0.0
	var col: Color = Color.WHITE

	if not is_constructed:
		ratio = clampf(build_progress / maxf(build_time, 0.1), 0.02, 1.0)
		if _flash_timer > 0.0:
			col = Color(1.0, 0.25, 0.2)
		else:
			col = Color(0.25, 0.85, 1.0)
		_status_bar_mesh.visible = true
		_bar_alpha = 1.0
	else:
		ratio = clampf(hp / maxf(max_hp, 1.0), 0.02, 1.0)
		if _flash_timer > 0.0:
			col = Color(1.0, 0.2, 0.15)
		elif ratio > 0.5:
			col = Color(0.32, 0.88, 0.32).lerp(Color(0.95, 0.85, 0.2), (1.0 - ratio) * 2.0)
		else:
			col = Color(0.95, 0.85, 0.2).lerp(Color(0.92, 0.22, 0.22), (0.5 - ratio) * 2.0)

		if _combat_timer > 0.0 and hp < max_hp * 0.999:
			_status_bar_mesh.visible = true
			if _combat_timer <= 1.0:
				_bar_alpha = clampf(_combat_timer / 1.0, 0.0, 1.0)
			else:
				_bar_alpha = 1.0
		else:
			_bar_alpha = 0.0
			_status_bar_mesh.visible = false

	_status_bar_mesh.set_instance_shader_parameter("fill_ratio", ratio)
	_status_bar_mesh.set_instance_shader_parameter("bar_alpha", _bar_alpha)
	_status_bar_mesh.set_instance_shader_parameter("fill_color", col)


func _sync_damage_stage() -> void:
	var new_stage := 0
	if hp <= 0.0:
		new_stage = 3
	elif is_constructed and hp <= max_hp * 0.33:
		new_stage = 2
	elif is_constructed and hp <= max_hp * 0.66:
		new_stage = 1
	else:
		new_stage = 0

	if new_stage != damage_stage:
		damage_stage = new_stage
		_apply_damage_stage()


func _apply_damage_stage() -> void:
	if _visual_root == null:
		return

	var s_intact := _visual_root.get_node_or_null("Stage_Intact")
	var s_damaged := _visual_root.get_node_or_null("Stage_Damaged")
	var s_critical := _visual_root.get_node_or_null("Stage_Critical")
	var s_rubble := _visual_root.get_node_or_null("Stage_Rubble")

	if s_intact != null:
		s_intact.visible = (damage_stage == 0)
	if s_damaged != null:
		s_damaged.visible = (damage_stage == 1)
	if s_critical != null:
		s_critical.visible = (damage_stage == 2)
	if s_rubble != null:
		s_rubble.visible = (damage_stage == 3)

	_sync_stage_lights()
	_sync_crop_visual()

	if damage_stage == 2 and not is_destroyed:
		_ensure_critical_particles()
		_dim_lights_for_critical()
	elif _critical_particles != null:
		_critical_particles.emitting = false


func _get_active_stage_node() -> Node3D:
	if _visual_root == null:
		return null
	match damage_stage:
		0:
			return _visual_root.get_node_or_null("Stage_Intact") as Node3D
		1:
			return _visual_root.get_node_or_null("Stage_Damaged") as Node3D
		2:
			return _visual_root.get_node_or_null("Stage_Critical") as Node3D
		3:
			return _visual_root.get_node_or_null("Stage_Rubble") as Node3D
		_:
			return null


func _find_in_active_stage(node_name: String) -> Node:
	var st := _get_active_stage_node()
	if st == null:
		return null
	var node := st.get_node_or_null(node_name)
	# Blender and the glTF importer may suffix names that repeat across stages.
	return node if node != null else st.find_child(node_name + "*", false, false)


func _sync_stage_lights() -> void:
	if _visual_root == null:
		return
	var stage_names := ["Stage_Intact", "Stage_Damaged", "Stage_Critical", "Stage_Rubble"]
	for stage_idx in range(4):
		var st := _visual_root.get_node_or_null(stage_names[stage_idx])
		if st != null:
			var is_active: bool = (stage_idx == damage_stage) and not is_destroyed
			for l in st.find_children("*", "Light3D", true, false):
				if l is Light3D:
					(l as Light3D).visible = is_active


func _dim_lights_for_critical() -> void:
	var cl := _find_in_active_stage("CampfireLight") as OmniLight3D
	if cl != null:
		cl.light_energy = 0.9
	var sl := _find_in_active_stage("ShamanLight") as OmniLight3D
	if sl != null:
		sl.light_energy = 0.6


func _ensure_critical_particles() -> void:
	if _critical_particles == null:
		var p := GPUParticles3D.new()
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pmat.emission_sphere_radius = 0.8
		pmat.direction = Vector3(0.0, 1.0, 0.0)
		pmat.spread = 20.0
		pmat.initial_velocity_min = 1.0
		pmat.initial_velocity_max = 2.2
		pmat.gravity = Vector3(0.0, 0.5, 0.0)
		pmat.scale_min = 0.08
		pmat.scale_max = 0.18

		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 5
		sm.rings = 2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.2, 0.2, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = mat

		p.process_material = pmat
		p.draw_pass_1 = sm
		p.amount = 12
		p.lifetime = 1.6
		p.position = Vector3(0.0, 1.8, 0.0)
		add_child(p)
		_critical_particles = p
	_critical_particles.emitting = true


func _spawn_debris_burst() -> void:
	var particles := GPUParticles3D.new()
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 1.0
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 65.0
	pmat.initial_velocity_min = 3.5
	pmat.initial_velocity_max = 7.0
	pmat.gravity = Vector3(0.0, -12.0, 0.0)
	pmat.scale_min = 0.15
	pmat.scale_max = 0.35

	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.28, 0.18)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.95
	box.material = mat

	particles.process_material = pmat
	particles.draw_pass_1 = box
	particles.amount = 22
	particles.lifetime = 1.8
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.position = Vector3(0.0, 0.8, 0.0)
	add_child(particles)
	particles.emitting = true


func sync_visual_from_state() -> void:
	_sync_damage_stage()
	_update_status_bar()


func advance_construction(amount: float) -> void:
	if is_constructed or is_destroyed:
		return
	build_progress = minf(build_time, build_progress + amount)
	hp = lerpf(max_hp * 0.25, max_hp, build_progress / maxf(build_time, 0.1))
	if build_progress >= build_time:
		var had_constructed_campfire := false
		if building_type == "CAMPFIRE":
			had_constructed_campfire = GameState.has_building(faction_id, "CAMPFIRE", true)
		is_constructed = true
		hp = max_hp
		damage_stage = 0
		_rebuild_visual()
		_sync_nav_obstacle()
		var sm: Node = GameState.get_node_or_null("/root/SoundManager")
		if sm != null:
			sm.play_sfx_3d("building_complete", global_position, 0.04, 0.0)
		if building_type == "CAMPFIRE" and GameState.factions.has(faction_id):
			if not bool(GameState.factions[faction_id].get("is_founded", false)) or not had_constructed_campfire:
				GameState.factions[faction_id]["camp_position"] = global_position
		if faction_id == 0:
			var b_name: String = GameData.BUILDINGS[building_type]["name"]
			GameState.push_log("%s construction completed!" % b_name, "success")
			if building_type == "CAMPFIRE" and not GameState.factions[0]["is_founded"]:
				GameState.factions[0]["is_founded"] = true
				GameState.factions[0]["camp_position"] = global_position
				GameState.push_log("Your tribal colony is founded! Open [C] Colony & [R] Religion.", "success")
			elif building_type == "SACRED_TOTEM":
				GameState.push_log("Sacred Totem raised! Open [R] Religion to choose your Patron God.", "success")
		GameState.award_xp(faction_id, clampf(build_time * 4.5, 20.0, 60.0), "Constructed building")
	_update_status_bar()


func repair(amount: float) -> void:
	if is_destroyed or not is_constructed:
		return
	hp = minf(max_hp, hp + amount)
	_sync_damage_stage()
	_update_status_bar()


func take_damage(amount: float, attacker_faction: int) -> void:
	if is_destroyed or GameState.has_truce(faction_id, attacker_faction):
		return

	hp -= amount
	_flash_timer = 0.25

	if attacker_faction == 0 and faction_id > 0 and faction_id < 5:
		GameState.set_diplomatic_state(0, faction_id, GameData.DiplomaticState.AT_WAR)
	elif attacker_faction >= 0 and attacker_faction < 5 and faction_id == 0:
		GameState.set_diplomatic_state(0, attacker_faction, GameData.DiplomaticState.AT_WAR)

	if attacker_faction != faction_id and GameState.is_hostile(faction_id, attacker_faction):
		_combat_timer = 5.0
		if faction_id == 0:
			GameState.notify_combat_audio(14.0)
		if not is_constructed:
			CombatVFX.spawn_damage_popup(self, "BLUEPRINT DAMAGED!", Color(1.0, 0.35, 0.2), 1.2)

	if hp <= 0.0:
		_destroy(attacker_faction)
	else:
		_sync_damage_stage()
		_update_status_bar()


func _destroy(attacker_faction: int) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	hp = 0.0
	damage_stage = 3
	_sync_nav_obstacle()
	if _index_registered:
		_index_registered = false
		GameState.spatial_index.unregister_building(self)
	_apply_damage_stage()

	_disable_collision()

	if _critical_particles != null:
		_critical_particles.emitting = false

	if _status_bar_mesh != null:
		_status_bar_mesh.visible = false

	_spawn_debris_burst()

	if building_type == "CAMPFIRE" and GameState.factions.has(faction_id):
		var remaining_camps := GameState.get_faction_buildings(faction_id, "CAMPFIRE", true)
		if not remaining_camps.is_empty():
			GameState.factions[faction_id]["camp_position"] = (remaining_camps[0] as Node3D).global_position

	if faction_id == 0:
		var b_name: String = GameData.BUILDINGS[building_type]["name"]
		GameState.push_log("ALERT: Our %s was destroyed!" % b_name, "danger")
	elif (faction_id >= 1 and faction_id <= 4) or faction_id == 6:
		if building_type == "CAMPFIRE" or building_type == "SACRED_TOTEM":
			GameState.trigger_conquest_if_eligible(faction_id, attacker_faction)
		else:
			GameState.call_deferred("check_victory_conditions")

	_sync_stage_lights()
	if _visual_root != null:
		for l in _visual_root.find_children("*", "Light3D", true, false):
			if l is Light3D:
				(l as Light3D).visible = false
		for f in _visual_root.find_children("FlameMesh*", "MeshInstance3D", true, false):
			if f is MeshInstance3D:
				(f as MeshInstance3D).visible = false

	_sink_timer = 8.0


func _physics_process(delta: float) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		return

	if is_destroyed:
		_sink_timer -= delta
		if _sink_timer <= 3.0:
			global_position.y -= delta * 0.15
		if _sink_timer <= 0.0:
			queue_free()
		return

	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		_update_status_bar()

	if _combat_timer > 0.0:
		_combat_timer = maxf(0.0, _combat_timer - delta)
		_update_status_bar()

	if not is_constructed:
		return
	var faction_dict: Dictionary = GameState.factions.get(faction_id, {})
	if damage_stage < 3 and hp < max_hp and _combat_timer <= 0.0:
		var regen: float = PerkSystem.get_building_regen_per_sec(faction_dict)
		if regen > 0.0:
			hp = minf(max_hp, hp + regen * delta)
			sync_visual_from_state()
	if building_type == "CROP_FIELD" and crop_stage == Farming.CropStage.GROWING:
		_grow_crop(delta)
	elif building_type == "ANIMAL_PEN":
		_pen_clock += delta
		if _pen_clock >= Farming.PEN_INTERVAL:
			_pen_clock = fmod(_pen_clock, Farming.PEN_INTERVAL)
			_feed_and_breed()

	# Campfire Dusk & Hearth aura healing + organic ember flicker
	if building_type == "CAMPFIRE":
		if _visual_root != null and damage_stage < 3:
			var t_sec := float(Time.get_ticks_msec()) * 0.001
			var flicker := 1.0 + sin(t_sec * 13.0 + global_position.x) * 0.14 + cos(t_sec * 21.0) * 0.08
			var flame := _find_in_active_stage("FlameMesh") as MeshInstance3D
			if flame != null:
				var scale_f := 0.5 if damage_stage == 2 else 1.0
				flame.scale = Vector3(1.0 + (flicker - 1.0) * 0.4, flicker, 1.0 + (flicker - 1.0) * 0.4) * scale_f
			var c_light := _find_in_active_stage("CampfireLight") as OmniLight3D
			if c_light != null:
				var energy_base := 1.0 if damage_stage == 2 else 3.2
				c_light.light_energy = energy_base * flicker
		if damage_stage < 3 and GameState.current_phase == GameData.SchedulePhase.DUSK_HEARTH:
			_dusk_heal_timer += delta
			if _dusk_heal_timer >= 2.0:
				_dusk_heal_timer = 0.0
				var heal_amt := 5.0
				if faction_dict.get("patron_god") == GameData.PatronGod.SOL_KAR:
					heal_amt = 8.5
				heal_amt *= PerkSystem.get_campfire_heal_mult(faction_dict)
				for u in GameState.get_faction_units(faction_id, true):
					if u.global_position.distance_to(global_position) <= 10.0 and float(u.get("_campfire_heal_cd")) <= 0.0:
						u._campfire_heal_cd = 1.95
						u.heal(heal_amt)

	# Sleeping Hut natural reproduction at night
	if building_type == "SLEEPING_HUT" and damage_stage < 3 and GameState.current_phase == GameData.SchedulePhase.NIGHT_SLEEP:
		_repro_timer += delta
		if _repro_timer >= 14.0:
			_repro_timer = 0.0
			_try_reproduce()

	# Watchtower defensive arrow fire
	if building_type == "WATCHTOWER" and damage_stage < 3:
		_watchtower_cd = maxf(0.0, _watchtower_cd - delta)
		_scan_cd -= delta
		if _watchtower_cd <= 0.0 and _scan_cd <= 0.0:
			_scan_cd = randf_range(0.18, 0.28)
			var tower_range: float = 22.0 + PerkSystem.get_watchtower_range_bonus(faction_dict)
			var target := _find_nearest_hostile(tower_range)
			if target != null:
				_fire_watchtower_arrow(target)
				_watchtower_cd = 1.65 / PerkSystem.get_watchtower_mult(faction_dict)


func crop_needs_work() -> bool:
	if building_type != "CROP_FIELD" or not is_constructed or is_destroyed:
		return false
	return crop_stage != Farming.CropStage.GROWING or (not crop_tended and crop_progress >= Farming.CROP_GROW_TIME * Farming.CROP_TEND_FRACTION)


func work_crop(delta: float) -> float:
	if not crop_needs_work() or not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		return 0.0
	crop_work += maxf(0.0, delta)
	if crop_work < Farming.CROP_WORK_TIMES[crop_stage]:
		return 0.0
	crop_work = 0.0
	var harvested := 0.0
	match crop_stage:
		Farming.CropStage.EMPTY:
			crop_stage = Farming.CropStage.GROWING
		Farming.CropStage.GROWING:
			crop_tended = true
			_grow_crop(Farming.CROP_TEND_BOOST)
		Farming.CropStage.RIPE:
			harvested = (24.0 if crop_tended else 18.0) * PerkSystem.get_lodge_crop_yield_mult(GameState.factions.get(faction_id, {}))
			crop_stage = Farming.CropStage.EMPTY
			crop_progress = 0.0
			crop_tended = false
			GameState.award_xp(faction_id, 12.0, "Harvested crop")
	_sync_crop_visual()
	return harvested


func _grow_crop(delta: float) -> void:
	crop_progress = minf(Farming.CROP_GROW_TIME, crop_progress + delta)
	if crop_progress >= Farming.CROP_GROW_TIME:
		crop_stage = Farming.CropStage.RIPE
		crop_work = 0.0
	_sync_crop_visual()


func _sync_crop_visual() -> void:
	if building_type != "CROP_FIELD":
		return
	var crops := _find_in_active_stage("Crops") as Node3D
	if crops != null:
		crops.visible = is_constructed and crop_stage != Farming.CropStage.EMPTY
		crops.scale.y = lerpf(0.12, 1.0, crop_progress / Farming.CROP_GROW_TIME)


func get_herd() -> Array[Node]:
	var herd: Array[Node] = []
	if building_type != "ANIMAL_PEN" or is_destroyed or not is_constructed or GameState.wildlife_container == null:
		return herd
	for animal in GameState.wildlife_container.get_children():
		if not animal.is_dead and animal.owner_faction == faction_id and animal.pen_position is Vector3 \
				and global_position.is_equal_approx(animal.pen_position):
			herd.append(animal)
	return herd


func _feed_and_breed() -> void:
	var herd := get_herd()
	var fed_adults := {}
	for animal in herd:
		if animal.rider_unit_id != 0 or animal.global_position.distance_to(global_position) > Farming.PEN_RADIUS:
			continue
		if not GameState.spend_resources(faction_id, {"food": Farming.FEED_COST}):
			break
		animal.feed_livestock()
		if animal.maturity_remaining <= 0.0:
			var species: String = animal.animal_type
			fed_adults[species] = int(fed_adults.get(species, 0)) + 1
	var pen_cap: int = Farming.PEN_CAPACITY + PerkSystem.get_pen_extra_capacity(GameState.factions.get(faction_id, {}))
	if herd.size() >= pen_cap:
		return
	for species in fed_adults:
		if fed_adults[species] >= 2 and GameState.spend_resources(faction_id, {"food": Farming.BREED_COST}):
			var offspring: Node = GameState.world_node._spawn_animal(species, global_position + Vector3(0.7, 0.0, 0.7))
			offspring.domesticate(faction_id, global_position, Farming.MATURITY_TIME)
			if faction_id == 0:
				GameState.push_log("A young %s was born in the Animal Pen." % offspring.animal_name, "success")
			break


func harvest_surplus_livestock() -> bool:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		return false
	var adults := {}
	for animal in get_herd():
		if animal.maturity_remaining <= 0.0 and animal.rider_unit_id == 0 \
				and animal.global_position.distance_to(global_position) <= Farming.PEN_RADIUS:
			var species: String = animal.animal_type
			var stock: Array = adults.get(species, [])
			stock.append(animal)
			adults[species] = stock
			if stock.size() >= 3:
				animal.harvest_livestock()
				return true
	return false


func _try_reproduce() -> void:
	if not GameState.factions.has(faction_id):
		return
	var fdata: Dictionary = GameState.factions[faction_id]
	var units := GameState.get_faction_units(faction_id, true)
	var cap := mini(GameState.get_housing_capacity(faction_id), GameState.get_max_population_cap(faction_id))
	if units.size() >= cap:
		return
	if float(fdata["resources"]["food"]) < 14.0:
		return

	var males := []
	var females := []
	for u in units:
		if not u.is_child:
			if u.gender == GameData.Gender.MALE:
				males.append(u)
			else:
				females.append(u)

	if males.is_empty() or females.is_empty():
		return

	var dad: Node = males[randi() % males.size()]
	var mom: Node = females[randi() % females.size()]
	var repro_mult := (float(GameData.LINEAGE_DATA[dad.lineage]["repro_mult"]) + float(GameData.LINEAGE_DATA[mom.lineage]["repro_mult"])) * 0.5
	if fdata.get("patron_god") == GameData.PatronGod.GAIA_MAR:
		repro_mult *= 1.35
	repro_mult *= PerkSystem.get_repro_chance_mult(fdata)

	var chance := clampf(0.28 * repro_mult, 0.10, 0.85)
	if randf() <= chance:
		GameState.spend_resources(faction_id, {"food": 10})
		var child_lineage: int = dad.lineage if randf() < 0.5 else mom.lineage
		var child_gender: int = GameData.Gender.MALE if randf() < 0.5 else GameData.Gender.FEMALE
		var fc = GameState.faction_controllers.get(faction_id)
		if fc != null and fc.has_method("spawn_colonist"):
			var spawn_pos := global_position + Vector3(randf_range(-2.2, 2.2), 0.0, randf_range(-2.2, 2.2))
			var child = fc.spawn_colonist(spawn_pos, child_lineage, child_gender, GameData.Role.FORAGER, false, true)
			if child != null:
				child.base_hp_stat = clampf(((float(dad.base_hp_stat) + float(mom.base_hp_stat)) * 0.5) * randf_range(0.94, 1.06), 80.0, 145.0)
				child.base_melee_stat = clampf(((float(dad.base_melee_stat) + float(mom.base_melee_stat)) * 0.5) * randf_range(0.94, 1.06), 8.0, 22.0)
				child.base_ranged_stat = clampf(((float(dad.base_ranged_stat) + float(mom.base_ranged_stat)) * 0.5) * randf_range(0.94, 1.06), 8.0, 21.0)
				GameState.apply_recruit_perks(faction_id, child)
				GameState.award_xp(faction_id, 25.0, "New birth")
			if faction_id == 0 and child != null:
				GameState.push_log("New birth in your tribe! %s (%s) was born in a Sleeping Hut." % [child.unit_name, GameData.LINEAGE_DATA[child_lineage]["short_name"]], "success")


func _find_nearest_hostile(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_range
	var unit_candidates: Array = []
	if GameState.spatial_index.is_populated():
		unit_candidates = GameState.spatial_index.query_units_in_radius(global_position, max_range)
	elif GameState.units_container != null:
		unit_candidates = GameState.units_container.get_children()
	for u in unit_candidates:
		if not is_instance_valid(u) or u.get("is_dead") == true:
			continue
		if not GameState.is_hostile(faction_id, int(u.get("faction_id"))):
			continue
		var u3d := u as Node3D
		if u3d == null:
			continue
		var d := global_position.distance_to(u3d.global_position)
		if d < best_d:
			best_d = d
			best = u3d
	var wild_candidates: Array = []
	if GameState.spatial_index.is_populated():
		wild_candidates = GameState.spatial_index.query_wildlife_in_radius(global_position, max_range)
	elif GameState.wildlife_container != null:
		wild_candidates = GameState.wildlife_container.get_children()
	if true:
		for w in wild_candidates:
			if not UnitAIRoutines.is_wildlife_hostile_to_faction(w, faction_id):
				continue
			var w3d := w as Node3D
			if w3d == null:
				continue
			var d := global_position.distance_to(w3d.global_position)
			if d < best_d:
				best_d = d
				best = w3d
	return best


func _fire_watchtower_arrow(target: Node3D) -> void:
	if GameState.projectiles_container == null:
		return
	var dmg := 20.0
	if GameState.has_tenet(faction_id, "ANCESTRAL_STONE"):
		dmg *= 1.25
	dmg *= PerkSystem.get_watchtower_mult(GameState.factions.get(faction_id, {}))
	var origin := global_position + Vector3(0.0, 4.2, 0.0)
	var stage := _get_active_stage_node()
	if stage != null:
		var marker := stage.find_child("ArrowOrigin*", false, false) as Node3D
		if marker != null:
			origin = marker.global_position
	var aim: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	if target.has_method("projectile_hit_center"):
		aim = target.projectile_hit_center()
	var tier := 1
	if GameState.factions.has(faction_id):
		tier = int(GameState.factions[faction_id].get("tech_tier", 1))
	Projectile3D.spawn(self, faction_id, origin, aim, dmg, 30.0, "ARROW", tier, false)
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_sfx_3d("bow_release", origin, 0.08, -1.5)


func recalculate_max_hp(preserve_ratio: bool = true) -> void:
	if is_destroyed:
		return
	var b_info: Dictionary = GameData.BUILDINGS.get(building_type, GameData.BUILDINGS["CAMPFIRE"])
	var hp_mult := 1.0
	var faction_dict: Dictionary = GameState.factions.get(faction_id, {})
	if int(faction_dict.get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.KRAG_UL:
		hp_mult = 1.25
	hp_mult *= PerkSystem.get_building_hp_mult(faction_dict)
	var new_max: float = float(b_info["max_hp"]) * hp_mult
	if is_equal_approx(new_max, max_hp):
		return
	var ratio: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	max_hp = new_max
	if preserve_ratio:
		hp = clampf(max_hp * ratio, 0.0, max_hp)
	else:
		hp = clampf(hp, 0.0, max_hp)
	sync_visual_from_state()


func restore_snapshot(snapshot: Dictionary) -> void:
	setup(snapshot["building_type"], int(snapshot["faction_id"]), snapshot["pos"], float(snapshot["rot_y"]), snapshot["is_constructed"])
	build_progress = clampf(float(snapshot["build_progress"]), 0.0, build_time)
	hp = clampf(float(snapshot["hp"]), 0.0, max_hp)
	crop_stage = int(snapshot.get("crop_stage", Farming.CropStage.EMPTY))
	crop_progress = float(snapshot.get("crop_progress", 0.0))
	crop_work = float(snapshot.get("crop_work", 0.0))
	crop_tended = snapshot.get("crop_tended") == true
	_pen_clock = float(snapshot.get("pen_clock", 0.0))
	if hp <= 0.0:
		is_destroyed = true
		damage_stage = 3
		_sync_nav_obstacle()
		if _index_registered:
			_index_registered = false
			GameState.spatial_index.unregister_building(self)
		_disable_collision()
		if _status_bar_mesh != null:
			_status_bar_mesh.visible = false
		_sink_timer = 8.0
	sync_visual_from_state()


func serialize() -> Dictionary:
	var snapshot := {
		"building_type": building_type,
		"faction_id": faction_id,
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot_y": rotation.y,
		"is_constructed": is_constructed,
		"build_progress": build_progress,
		"hp": hp,
	}
	if building_type == "CROP_FIELD":
		snapshot.merge({"crop_stage": crop_stage, "crop_progress": crop_progress, "crop_work": crop_work, "crop_tended": crop_tended})
	elif building_type == "ANIMAL_PEN":
		snapshot["pen_clock"] = _pen_clock
	return snapshot
