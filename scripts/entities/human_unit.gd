extends CharacterBody3D

const Look = preload("res://scripts/ui/fallow_theme.gd")
const UnitStats = preload("res://scripts/entities/unit_stats.gd")
const Layout = preload("res://scripts/core/world_layout.gd")
const FOOT_CAPSULE_CENTER := Vector3(0.0, 0.85, 0.0)

const CampaignSave = preload("res://scripts/core/campaign_save.gd")

var unit_id: int = 0
var archetype := ""
var unit_name: String = "Tribesman"
var faction_id: int = 0:
	set(value):
		if value == faction_id:
			return
		var old_fid: int = faction_id
		faction_id = value
		if _index_registered:
			GameState.spatial_index.on_unit_faction_changed(self, old_fid, value)
var original_faction_id: int = 0
var gender: int = GameData.Gender.MALE
var lineage: int = GameData.Lineage.CRAG_BORN
var role: int = GameData.Role.FORAGER
var warrior_class: int = GameData.WarriorClass.SPEARMAN

var is_leader: bool = false:
	set(value):
		if value == is_leader:
			return
		is_leader = value
		if _index_registered:
			GameState.spatial_index.on_unit_leader_changed(self)
var is_player_controlled: bool = false
var is_caveman: bool = false
var is_child: bool = false
var growth_progress: float = 0.0

var base_hp_stat: float = 100.0
var base_melee_stat: float = 12.0
var base_ranged_stat: float = 11.0
var close_quarters_damage: float = 12.0
var ranged_attack_damage: float = 11.0
var unarmed_attack_damage: float = 4.5
var melee_rank: int = 0
var ranged_rank: int = 0
var training_xp: float = 0.0

var morale: float = 78.0
var is_revolting: bool = false
var is_wounded: bool = false
var is_healing_in_shack: bool = false
var wounded_timer: float = 0.0
var being_rescued: bool = false

var has_equipped_weapon: bool = false
var weapon_tier: int = 1
var has_armor: bool = false
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var is_ranged_weapon: bool = false
var projectile_type: String = ""

var hp: float = 100.0
var max_hp: float = 100.0
var move_speed: float = 6.0
var attack_damage: float = 12.0
var attack_range: float = 2.0
var attack_cooldown_max: float = 1.0
var armor: float = 0.0

var squad_order: int = GameData.SquadOrder.FOLLOW
var hold_position: Vector3 = Vector3.ZERO
var fire_at_will: bool = true
var raid_target_pos: Vector3 = Vector3.ZERO
var is_raiding: bool = false

const CombatVFX = preload("res://scripts/core/combat_vfx.gd")
const TribesmanAnimator = preload("res://scripts/entities/tribesman_animator.gd")
const SkinnedTribesmanTrial = preload("res://scripts/entities/skinned_tribesman_trial.gd")
const CragBornTrial = preload("res://scripts/entities/crag_born_trial.gd")
const HumanMeshBuilder = preload("res://scripts/core/human_mesh_builder.gd")
const UnitAIRoutines = preload("res://scripts/entities/unit_ai_routines.gd")
const UnitCombatAI = preload("res://scripts/entities/unit_combat_ai.gd")

var is_dead: bool = false
var is_arena_combatant: bool = false
var is_arena_opponent: bool = false
var arena_recovery_remaining: float = 0.0
var is_arena_champion: bool = false


func is_out_of_commission() -> bool:
	return arena_recovery_remaining > 0.0

var _visual_root: Node3D = null
var _skinned_trial: SkinnedTribesmanTrial = null
var _leader_nameplate: Label3D
var _mounted := false
var _collider: CollisionShape3D
var _foot_shape: CapsuleShape3D
var _rider_seat := Vector3.ZERO
var _rider_hip_height := 0.0
var _riding_leg_spread := 0.0
var _rider_lift := 0.0
var _body_pivot: Node3D = null
var _animator: TribesmanAnimator = TribesmanAnimator.new()
var _active_class_key: String = ""
var _hp_bg: MeshInstance3D = null
var _hp_fill: MeshInstance3D = null
var _selection_ring: MeshInstance3D = null
var _state_label: Label3D = null

var _attack_cd: float = 0.0
var _ai_think_cd: float = 0.0
var _index_registered: bool = false
var _scan_enemy_cd: float = 0.0
var _scan_enemy_radius: float = -1.0
var _scan_enemy: Node = null
var _scan_wild_cd: float = 0.0
var _scan_wild_radius: float = -1.0
var _scan_wild: Node = null
var _scan_bld_cd: float = 0.0
var _scan_bld_radius: float = -1.0
var _scan_bld: Node = null
var _nav_path: PackedVector3Array = PackedVector3Array()
var _nav_idx: int = 0
var _nav_target: Vector3 = Vector3(INF, 0.0, INF)
var _nav_repath_cd: float = 0.0
var _nav_revision: int = -1
var _nav_progress_pos := Vector3.INF
var _last_label_text: String = ""
var _last_move_idle: bool = false
var _work_timer: float = 0.0
var _work_sfx_cd: float = 0.0
var _swing_timer: float = 0.0
var _swing_duration: float = 0.34
var _active_attack_anim: String = ""
var _skinned_hit_priority: bool = false
var _death_anim_state: String = "DEATH_BACK"
var _is_working_this_frame: bool = false
var _hit_flash_timer: float = 0.0
var _death_timer: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
var _last_anim_pos: Vector3 = Vector3.ZERO
var _buff_timer: float = 0.0
var _buff_speed_mult: float = 1.0
var _buff_armor_bonus: float = 0.0

var _target_node: Node = null
var _carry_type: String = ""
var _carry_amount: float = 0.0
var _dusk_eaten_today: int = -1
var _night_morale_today: int = -1
var _warhorn_fatigue_timer: float = 0.0
var _patrol_angle: float = 0.0
var _leader_blessing_cd: float = 0.0
var _retreating_to_heal: bool = false
var _kiting_this_frame: bool = false
var _self_defense_target: Node = null
var _self_defense_timer: float = 0.0
var _unarmed_punch_vis_timer: float = 0.0
var _rescue_shaman: Node = null
var _rescue_lease_timer: float = 0.0
var _field_aid_applied: bool = false
var _active_craft_item: String = ""
var _campfire_heal_cd: float = 0.0
var _recruit_perks_mult: float = 1.0
var _first_person_hidden: bool = false
var _cached_fp_meshes: Array[MeshInstance3D] = []
var _cached_fp_shadow_modes: Array[int] = []
var _cached_fp_small_meshes: Array[MeshInstance3D] = []
var _cached_fp_small_layers: Array[int] = []
var _fp_anim_idle_time: float = 0.0


func setup(p_params: Dictionary) -> void:
	unit_id = int(p_params["unit_id"]) if p_params.has("unit_id") else GameState.allocate_unit_id()
	faction_id = int(p_params.get("faction_id", 0))
	original_faction_id = int(p_params.get("original_faction_id", maxi(0, faction_id)))
	gender = int(p_params.get("gender", GameData.Gender.MALE))
	lineage = int(p_params.get("lineage", GameData.Lineage.CRAG_BORN))
	role = int(p_params.get("role", GameData.Role.FORAGER))
	warrior_class = int(p_params.get("warrior_class", GameData.WarriorClass.SPEARMAN))
	is_leader = bool(p_params.get("is_leader", false))
	is_player_controlled = bool(p_params.get("is_player_controlled", false))
	is_caveman = bool(p_params.get("is_caveman", false))
	archetype = str(p_params.get("archetype", ""))
	is_child = bool(p_params.get("is_child", false))
	growth_progress = float(p_params.get("growth_progress", 0.0))
	base_hp_stat = float(p_params.get("base_hp_stat", randf_range(88.0, 114.0)))
	base_melee_stat = float(p_params.get("base_melee_stat", randf_range(9.5, 14.5)))
	base_ranged_stat = float(p_params.get("base_ranged_stat", randf_range(8.5, 13.5)))
	melee_rank = int(p_params.get("melee_rank", 0))
	ranged_rank = int(p_params.get("ranged_rank", 0))
	training_xp = float(p_params.get("training_xp", 0.0))
	morale = float(p_params.get("morale", randf_range(72.0, 86.0)))
	is_revolting = bool(p_params.get("is_revolting", false))
	is_wounded = bool(p_params.get("is_wounded", false))
	is_healing_in_shack = bool(p_params.get("is_healing_in_shack", false))
	being_rescued = bool(p_params.get("being_rescued", is_healing_in_shack))
	wounded_timer = float(p_params.get("wounded_timer", 0.0))
	arena_recovery_remaining = maxf(0.0, float(p_params.get("arena_recovery_remaining", 0.0)))
	is_arena_champion = bool(p_params.get("is_arena_champion", false))
	is_arena_combatant = bool(p_params.get("is_arena_combatant", false))
	is_arena_opponent = false
	var raw_w_id: String = str(p_params.get("equipped_weapon_id", ""))
	equipped_weapon_id = raw_w_id if GameData.WEAPON_DEFS.has(raw_w_id) else ""
	var raw_a_id: String = str(p_params.get("equipped_armor_id", ""))
	equipped_armor_id = raw_a_id if GameData.ARMOR_DEFS.has(raw_a_id) else ""
	has_equipped_weapon = bool(p_params.get("has_equipped_weapon", is_leader or is_caveman or equipped_weapon_id != ""))
	if equipped_weapon_id != "":
		has_equipped_weapon = true
	weapon_tier = int(p_params.get("weapon_tier", 1))
	has_armor = bool(p_params.get("has_armor", is_leader or (equipped_armor_id != "" and equipped_armor_id != "NONE")))
	if equipped_armor_id == "NONE":
		has_armor = false
	elif equipped_armor_id != "":
		has_armor = true
	squad_order = int(p_params.get("squad_order", GameData.SquadOrder.FOLLOW))
	hold_position = p_params.get("hold_position", Vector3.ZERO)
	if p_params.has("fire_at_will"):
		fire_at_will = bool(p_params["fire_at_will"])
	elif faction_id == 0 and GameState.combat_command_system != null:
		fire_at_will = bool(GameState.combat_command_system.global_fire_at_will)
	else:
		fire_at_will = true
	is_raiding = bool(p_params.get("is_raiding", false))
	raid_target_pos = p_params.get("raid_target_pos", Vector3.ZERO)
	_recruit_perks_mult = maxf(1.0, float(p_params.get("recruit_perks_mult", 1.0)))

	if p_params.has("unit_name") and str(p_params["unit_name"]) != "":
		unit_name = str(p_params["unit_name"])
	else:
		unit_name = _pick_random_name()

	if p_params.has("pos"):
		global_position = p_params["pos"]

	_patrol_angle = randf_range(0.0, TAU)
	_ai_think_cd = randf_range(0.0, 0.4)

	_foot_shape = CapsuleShape3D.new()
	_foot_shape.radius = 0.36
	_foot_shape.height = 1.65
	_collider = CollisionShape3D.new()
	_collider.shape = _foot_shape
	_collider.position = FOOT_CAPSULE_CENTER
	add_child(_collider)

	_rebuild_visual()
	_create_hp_bar()
	recalculate_stats(true)
	_register_in_index()


func _register_in_index() -> void:
	if _index_registered or not is_inside_tree():
		return
	_index_registered = true
	GameState.spatial_index.register_unit(self)


func _unregister_from_index() -> void:
	if not _index_registered:
		return
	_index_registered = false
	GameState.spatial_index.unregister_unit(self)


func _exit_tree() -> void:
	_unregister_from_index()


func _pick_random_name() -> String:
	if is_caveman:
		return GameData.CAVEMAN_NAMES[randi() % GameData.CAVEMAN_NAMES.size()]
	if gender == GameData.Gender.MALE:
		return GameData.FIRST_NAMES_MALE[randi() % GameData.FIRST_NAMES_MALE.size()]
	return GameData.FIRST_NAMES_FEMALE[randi() % GameData.FIRST_NAMES_FEMALE.size()]


func _is_warhorn_militia() -> bool:
	return faction_id == 0 and GameState.warhorn_active and role != GameData.Role.WARRIOR and not is_leader and not is_caveman and not is_child


func _get_effective_warrior_class() -> int:
	if _is_warhorn_militia():
		return GameData.WarriorClass.SPEARMAN
	return warrior_class


func _get_class_key() -> String:
	if is_caveman and archetype == GameData.FLINTMASK_SCOUT:
		return archetype
	var militia := _is_warhorn_militia()
	return GameData.resolve_class_key(role, _get_effective_warrior_class(), is_leader, is_caveman, militia)


func _get_class_def() -> Dictionary:
	return GameData.CLASS_DEFINITIONS.get(_get_class_key(), GameData.CLASS_DEFINITIONS["FORAGER"])


func _rebuild_visual() -> void:
	_cached_fp_meshes.clear()
	_cached_fp_shadow_modes.clear()
	_cached_fp_small_meshes.clear()
	_cached_fp_small_layers.clear()
	_fp_anim_idle_time = 0.0
	if _skinned_trial != null:
		remove_child(_skinned_trial)
		_skinned_trial.queue_free()
		_skinned_trial = null
	if _visual_root != null:
		remove_child(_visual_root)
		_visual_root.queue_free()
	var col: Color = Color(0.75, 0.72, 0.65)
	if is_revolting or faction_id == -2:
		col = Color(0.95, 0.25, 0.14)
	elif is_wounded or faction_id == -3:
		col = Color(0.65, 0.45, 0.28)
	elif faction_id >= 0 and GameData.FACTION_COLORS.has(faction_id):
		col = GameData.FACTION_COLORS[faction_id]

	var militia := _is_warhorn_militia()
	var eff_role := GameData.Role.WARRIOR if militia else role
	var eff_class := _get_effective_warrior_class()
	_active_class_key = _get_class_key()
	_visual_root = MeshFactory.build_human_mesh(lineage, gender, col, is_leader, is_caveman, eff_role, eff_class, is_child)
	add_child(_visual_root)
	_body_pivot = _visual_root.get_node_or_null("BodyPivot")

	var eff_lin := GameData.resolve_effective_lineage(lineage, is_caveman)
	var hunch := float(GameData.LINEAGE_DATA.get(eff_lin, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN]).get("spine_hunch", 0.0))
	_animator.bind(_visual_root, hunch)
	if is_wounded:
		_animator.update(0.5, {"is_wounded": true})
	else:
		var cdef := _get_class_def()
		_animator.update(0.5, {"idle_stance": str(cdef.get("idle_stance", "RELAXED"))})

	_refresh_gear_visual()
	if is_player_controlled and is_leader and faction_id == 0 and not is_dead \
			and SkinnedTribesmanTrial.LAUNCH_FLAG in OS.get_cmdline_user_args():
		var trial := SkinnedTribesmanTrial.new()
		var spear := _visual_root.find_child("GREAT_SPEAR", true, false) as Node3D
		var lineage_height := float(GameData.LINEAGE_DATA[eff_lin]["height_scale"])
		if trial.setup(MeshFactory, col, spear):
			trial.name = "SkinnedTribesmanTrial"
			trial.set_rig_scale(Vector3.ONE * lineage_height)
			add_child(trial)
			_skinned_trial = trial
			_skinned_trial.update_action("WOUNDED" if is_wounded else "IDLE", 0.0, 0.0, _is_psx_jitter_enabled(), _hit_flash_ratio())
			_set_trial_visible(true)
		else:
			trial.free()
	elif not is_dead and CragBornTrial.supports_lineage(eff_lin) and CragBornTrial.enabled():
		var trial_kit := "FORAGER" if (role == GameData.Role.FORAGER and militia) else _active_class_key
		if CragBornTrial.supports_kit(trial_kit, is_child):
			var pilot := CragBornTrial.new()
			var variant := CragBornTrial.select_body_variant(gender, is_child, unit_id)
			if pilot.setup_kit(MeshFactory, col, variant, trial_kit, eff_lin):
				pilot.name = "SkinnedLineageLeader" if is_leader else ("CragBornTrial" if eff_lin == GameData.Lineage.CRAG_BORN else "SkinnedLineageRig")
				add_child(pilot)
				_skinned_trial = pilot
				pilot.equip_gear(MeshFactory, get_equipped_weapon_id(), get_equipped_armor_id(), weapon_tier)
				pilot.update_action("WOUNDED" if is_wounded else "IDLE", 0.0, 0.0, _is_psx_jitter_enabled(), _hit_flash_ratio())
				_set_trial_visible(true)
			else:
				pilot.free()
	_sync_rider_visual()
	if _first_person_hidden:
		_rebuild_fp_mesh_cache()
		_apply_first_person_shadow_mode()


func is_first_person_hidden() -> bool:
	return _first_person_hidden


func get_eye_height() -> float:
	var eff_lin: int = GameData.resolve_effective_lineage(lineage, is_caveman)
	var h_scale: float = float(GameData.LINEAGE_DATA.get(eff_lin, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN]).get("height_scale", 1.0))
	return 1.58 * h_scale + _rider_lift


func set_first_person_view(active: bool) -> void:
	if _first_person_hidden == active:
		return
	_first_person_hidden = active
	_fp_anim_idle_time = 0.0
	if active and _cached_fp_meshes.is_empty():
		_rebuild_fp_mesh_cache()
	_apply_first_person_shadow_mode()
	_sync_leader_nameplate()
	_update_hp_bar()


func _rebuild_fp_mesh_cache() -> void:
	# Restore any surviving meshes to their true 3rd-person state before re-scanning.
	for i in range(_cached_fp_meshes.size()):
		var prev_mi := _cached_fp_meshes[i]
		if is_instance_valid(prev_mi) and i < _cached_fp_shadow_modes.size():
			prev_mi.cast_shadow = _cached_fp_shadow_modes[i]
	for i in range(_cached_fp_small_meshes.size()):
		var prev_small := _cached_fp_small_meshes[i]
		if is_instance_valid(prev_small) and i < _cached_fp_small_layers.size():
			prev_small.layers = _cached_fp_small_layers[i]
	_cached_fp_meshes.clear()
	_cached_fp_shadow_modes.clear()
	_cached_fp_small_meshes.clear()
	_cached_fp_small_layers.clear()
	for root_node in [_visual_root, _skinned_trial]:
		if root_node == null or not is_instance_valid(root_node):
			continue
		for node in root_node.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi == null:
				continue
			_cached_fp_meshes.append(mi)
			_cached_fp_shadow_modes.append(mi.cast_shadow)
			var is_small_acc := mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var cur: Node = mi
			while not is_small_acc and cur != null and cur != root_node:
				var cname := String(cur.name)
				if cname in ["Crown", "Cape", "Back", "WeaponMount", "OffhandMount", "Weapon", "Offhand", "TrialWeaponHand"]:
					is_small_acc = true
				cur = cur.get_parent()
			if not is_small_acc and mi.mesh != null and mi.get_aabb().size.length() < 0.34:
				is_small_acc = true
			if is_small_acc:
				_cached_fp_small_meshes.append(mi)
				_cached_fp_small_layers.append(mi.layers)


func _apply_first_person_shadow_mode() -> void:
	for i in range(_cached_fp_meshes.size()):
		var mi := _cached_fp_meshes[i]
		if is_instance_valid(mi):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if _first_person_hidden else _cached_fp_shadow_modes[i]
	for i in range(_cached_fp_small_meshes.size()):
		var mi := _cached_fp_small_meshes[i]
		if is_instance_valid(mi):
			# Shadow casting OFF still draws the mesh. Clear its render layers as well.
			mi.layers = 0 if _first_person_hidden else _cached_fp_small_layers[i]
			if _first_person_hidden:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_mounted(mount_shape: CapsuleShape3D, leg_spread: float = 0.0) -> void:
	_mounted = mount_shape != null
	_riding_leg_spread = leg_spread
	_rider_seat = Vector3.ZERO
	_collider.set_deferred("shape", mount_shape if _mounted else _foot_shape)
	_collider.set_deferred("position", Vector3.UP * mount_shape.height * 0.5 if _mounted else FOOT_CAPSULE_CENTER)
	_sync_rider_visual()
	_set_hand_mounts_visible(not _mounted)
	_update_hp_bar()


func can_stand_at(point: Vector3, mount: RID) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _foot_shape
	query.transform.origin = point + FOOT_CAPSULE_CENTER
	query.collision_mask = collision_mask
	query.exclude = [get_rid(), mount]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _sync_rider_visual() -> void:
	_rider_hip_height = 0.0
	if _mounted and _body_pivot != null:
		var hips := _body_pivot.get_node_or_null("HipsPivot") as Node3D
		if hips != null:
			_rider_hip_height = hips.position.y * _body_pivot.scale.y
	if _mounted and _skinned_trial != null:
		_rider_hip_height = _skinned_trial.riding_hip_height()
	update_rider_seat(_rider_seat)
	_sync_leader_nameplate()


func update_rider_seat(seat: Vector3) -> void:
	_rider_seat = seat
	var lift := seat.y - _rider_hip_height
	var lift_change := lift - _rider_lift
	_rider_lift = lift
	var rider_position := Vector3(seat.x, lift, seat.z)
	if _visual_root != null:
		_visual_root.position = rider_position
	if _skinned_trial != null:
		_skinned_trial.position = rider_position
	if _leader_nameplate != null:
		_leader_nameplate.position.y += lift_change
	if _hp_bg != null and _hp_fill != null:
		_hp_bg.position.y += lift_change
		_hp_fill.position.y += lift_change


func _sync_leader_nameplate() -> void:
	var identity: Array = GameData.LEADER_IDENTITIES.get(faction_id, [])
	if _first_person_hidden or not is_leader or is_dead or is_wounded or identity.is_empty():
		if _leader_nameplate != null:
			_leader_nameplate.hide()
		return
	if _leader_nameplate == null:
		_leader_nameplate = Label3D.new()
		_leader_nameplate.name = "LeaderNameplate"
		_leader_nameplate.font = Look.body_font()
		_leader_nameplate.font_size = 24
		_leader_nameplate.pixel_size = 0.014
		_leader_nameplate.outline_size = 6
		_leader_nameplate.outline_modulate = Look.INK
		_leader_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_leader_nameplate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_leader_nameplate.visibility_range_end = 44.0
		add_child(_leader_nameplate)
	var lin: int = GameData.resolve_effective_lineage(lineage, is_caveman)
	var height := float(GameData.LINEAGE_DATA[lin]["height_scale"])
	_leader_nameplate.position.y = 2.35 * height + 0.6 + _rider_lift
	var tint: Color = GameData.FACTION_COLORS.get(faction_id, Look.GOLD)
	_leader_nameplate.modulate = tint.lightened(0.5)
	_leader_nameplate.text = "%s %s\n%s" % [identity[0], unit_name, identity[1]]
	_leader_nameplate.show()


func _refresh_negotiation_prompt() -> void:
	if not is_leader or _leader_nameplate == null or faction_id == 0:
		return
	var player: Node = GameState.get_faction_leader(0)
	var facing_player := false
	if player != null and global_position.distance_to((player as Node3D).global_position) < Layout.SCAN_RANGE_NEGOTIATE:
		facing_player = GameState.nearby_rival_leader((player as Node3D).global_position) == self
	var identity: Array = GameData.LEADER_IDENTITIES[faction_id]
	var suffix: String = "[E] Negotiate" if facing_player else identity[1]
	var caption := "%s %s\n%s" % [identity[0], unit_name, suffix]
	if _leader_nameplate.text != caption:
		_leader_nameplate.text = caption


func _is_psx_jitter_enabled() -> bool:
	return GameState.world_node == null or not GameState.world_node.has_method("is_psx_filter_enabled") or GameState.world_node.is_psx_filter_enabled()


func _hit_flash_ratio() -> float:
	return clampf(_hit_flash_timer / 0.16, 0.0, 1.0)


func _set_trial_visible(use_trial: bool) -> void:
	if _skinned_trial != null:
		_skinned_trial.visible = use_trial
		_visual_root.visible = not use_trial


func get_equipped_weapon_id() -> String:
	if equipped_weapon_id != "" and GameData.WEAPON_DEFS.has(equipped_weapon_id):
		return equipped_weapon_id
	if has_equipped_weapon or is_leader or is_caveman:
		return GameData.resolve_default_weapon_id(role, warrior_class, is_leader, is_caveman)
	return ""


func get_equipped_armor_id() -> String:
	if equipped_armor_id != "" and GameData.ARMOR_DEFS.has(equipped_armor_id):
		return equipped_armor_id
	return GameData.resolve_default_armor_id(has_armor, weapon_tier, is_leader)


func equip_loadout(weapon_id: String = "__KEEP__", armor_id: String = "__KEEP__") -> void:
	if weapon_id != "__KEEP__":
		equipped_weapon_id = weapon_id if (weapon_id == "" or GameData.WEAPON_DEFS.has(weapon_id)) else ""
		has_equipped_weapon = equipped_weapon_id != ""
	if armor_id != "__KEEP__":
		equipped_armor_id = armor_id if (armor_id == "" or GameData.ARMOR_DEFS.has(armor_id)) else ""
		has_armor = equipped_armor_id != "" and equipped_armor_id != "NONE"
	recalculate_stats(false)


func _refresh_gear_visual() -> void:
	if _visual_root == null:
		return
	var desired_key := _get_class_key()
	if desired_key != _active_class_key:
		_rebuild_visual()
		return
	var w_str := "SPEAR"
	var use_tool := false
	if not is_child and (role == GameData.Role.WARRIOR or is_leader or is_caveman or _is_warhorn_militia() or equipped_weapon_id != ""):
		match _get_effective_warrior_class():
			GameData.WarriorClass.SPEARMAN:
				w_str = "SPEAR"
			GameData.WarriorClass.KNIFE_RAIDER:
				w_str = "KNIFE"
			GameData.WarriorClass.ARCHER:
				w_str = "BOW"
			GameData.WarriorClass.BRUTE:
				w_str = "CLUB"
			GameData.WarriorClass.JAVELINEER:
				w_str = "JAVELIN"
	else:
		use_tool = true

	var eff_weapon_id := "" if use_tool else get_equipped_weapon_id()
	var eff_armor_id := get_equipped_armor_id()
	HumanMeshBuilder.update_human_gear(MeshFactory, _visual_root, w_str, weapon_tier, has_armor, use_tool, desired_key, eff_weapon_id, eff_armor_id)
	if _skinned_trial is CragBornTrial:
		_skinned_trial.equip_gear(MeshFactory, eff_weapon_id, eff_armor_id, weapon_tier)
	if _first_person_hidden:
		_rebuild_fp_mesh_cache()
		_apply_first_person_shadow_mode()


func play_attack_animation(anim_name: String = "", duration: float = 0.40) -> void:
	var eff_anim := anim_name
	if eff_anim == "":
		var eff_wid := get_equipped_weapon_id()
		if not _is_working_this_frame and eff_wid != "" and GameData.WEAPON_DEFS.has(eff_wid):
			eff_anim = str(GameData.WEAPON_DEFS[eff_wid].get("attack_anim", _get_class_def().get("attack_anim", "TOOL_SWING")))
		else:
			eff_anim = str(_get_class_def().get("attack_anim", "TOOL_SWING"))
	_active_attack_anim = eff_anim
	_skinned_hit_priority = false
	_swing_duration = duration
	_swing_timer = duration
	_animator.trigger_attack(eff_anim, duration)
	if _skinned_trial != null:
		_set_trial_visible(true)
		if eff_anim == "TOOL_SWING" or eff_anim.begins_with("WORK_"):
			_skinned_trial.restart_clip(&"Work")
		else:
			_skinned_trial.restart_clip(&"Attack")


func _create_hp_bar() -> void:
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.10, 0.05)
	bg.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.08, 0.08, 0.08, 0.85)
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bmat
	bg.position = Vector3(0.0, 2.35, 0.0)
	add_child(bg)
	_hp_bg = bg

	var fill := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.05, 0.07, 0.07)
	fill.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.25, 0.88, 0.35) if faction_id == 0 else Color(0.92, 0.25, 0.25)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = fmat
	fill.position = Vector3(0.0, 2.35, 0.0)
	add_child(fill)
	_hp_fill = fill

	# Leader indicator ring on ground
	if is_leader:
		_ensure_selection_ring()

	var lbl := Label3D.new()
	lbl.font = Look.body_font()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 22
	lbl.pixel_size = 0.013
	lbl.outline_size = 5
	lbl.outline_modulate = Look.INK
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lbl.position = Vector3(0.0, 2.70, 0.0)
	lbl.visible = false
	add_child(lbl)
	_state_label = lbl


func _ensure_selection_ring() -> void:
	var fc: Color = GameData.FACTION_COLORS.get(faction_id, Color.GOLD)
	if _selection_ring == null or not is_instance_valid(_selection_ring):
		var ring := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = 0.65
		rm.outer_radius = 0.78
		ring.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = fc
		rmat.emission_enabled = true
		rmat.emission = fc
		rmat.emission_energy_multiplier = 1.2
		ring.material_override = rmat
		ring.position = Vector3(0.0, 0.06, 0.0)
		add_child(ring)
		_selection_ring = ring
	else:
		_selection_ring.visible = true
		var rmat := _selection_ring.material_override as StandardMaterial3D
		if rmat != null:
			rmat.albedo_color = fc
			rmat.emission = fc


func recalculate_stats(reset_hp: bool = false) -> void:
	var effective_faction := original_faction_id if faction_id < 0 else faction_id
	var faction_dict: Dictionary = GameState.factions.get(effective_faction, {})
	var patron: int = faction_dict.get("patron_god", GameData.PatronGod.NONE)
	var stats := UnitStats.derive({
		"lineage": lineage,
		"archetype": archetype,
		"is_caveman": is_caveman,
		"role": role,
		"warrior_class": warrior_class,
		"is_leader": is_leader,
		"is_child": is_child,
		"base_hp_stat": base_hp_stat,
		"base_melee_stat": base_melee_stat,
		"base_ranged_stat": base_ranged_stat,
		"melee_rank": melee_rank,
		"ranged_rank": ranged_rank,
		"weapon_tier": weapon_tier,
		"has_equipped_weapon": has_equipped_weapon,
		"has_armor": has_armor,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"is_arena_champion": is_arena_champion,
	}, patron, faction_dict)
	var previous_ratio := hp / maxf(max_hp, 1.0)
	max_hp = stats["max_hp"]
	move_speed = stats["move_speed"]
	close_quarters_damage = stats["close_quarters_damage"]
	ranged_attack_damage = stats["ranged_attack_damage"]
	unarmed_attack_damage = stats["unarmed_attack_damage"]
	attack_damage = stats["attack_damage"]
	attack_range = stats["attack_range"]
	attack_cooldown_max = stats["attack_cooldown_max"]
	armor = stats["armor"]
	is_ranged_weapon = bool(stats.get("is_ranged", false))
	projectile_type = str(stats.get("projectile_type", ""))
	hp = max_hp if reset_hp else clampf(previous_ratio * max_hp, 1.0, max_hp)
	_refresh_gear_visual()
	_update_hp_bar()


func _update_hp_bar() -> void:
	if _hp_bg == null or _hp_fill == null:
		return
	if _first_person_hidden:
		_hp_bg.visible = false
		_hp_fill.visible = false
		if _state_label != null:
			_state_label.visible = false
		return
	var visual_height := _skinned_trial.scale.y if _skinned_trial is CragBornTrial else 1.0
	_hp_bg.position.y = 2.35 * visual_height + _rider_lift
	_hp_fill.position.y = _hp_bg.position.y
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.02, 1.0)
	_hp_fill.scale.x = ratio
	var show := is_leader or hp < max_hp * 0.99 or faction_id == 5 or is_revolting or is_wounded or arena_recovery_remaining > 0.0 or is_arena_combatant or is_arena_opponent
	_hp_bg.visible = show
	_hp_fill.visible = show
	var fmat := _hp_fill.material_override as StandardMaterial3D
	if fmat != null:
		if is_wounded:
			fmat.albedo_color = Color(0.95, 0.65, 0.18)
		elif is_revolting or faction_id == -2:
			fmat.albedo_color = Color(1.0, 0.30, 0.12)
		elif faction_id == 0:
			fmat.albedo_color = Color(0.25, 0.88, 0.35)
		elif faction_id == -1:
			fmat.albedo_color = Color(0.95, 0.85, 0.25)
		else:
			fmat.albedo_color = Color(0.92, 0.28, 0.25)

	if _state_label != null:
		if is_dead:
			_state_label.visible = false
		elif is_wounded:
			_state_label.visible = true
			_state_label.position = Vector3(0.0, 1.35, 0.0)
			_state_label.modulate = Color(1.0, 0.72, 0.22)
		elif arena_recovery_remaining > 0.0:
			_state_label.visible = true
			_state_label.position = Vector3(0.0, 2.55 * visual_height + _rider_lift, 0.0)
			_state_label.text = "Recovering (%ds)" % ceili(arena_recovery_remaining)
			_state_label.modulate = Color(0.95, 0.72, 0.28)
		elif is_revolting or faction_id == -2:
			_state_label.visible = true
			_state_label.position.y = 2.70 * visual_height
			_state_label.text = "Revolting"
			_state_label.modulate = Look.DANGER
		elif faction_id == -1:
			_state_label.visible = true
			_state_label.position.y = 2.45 * visual_height
			_state_label.text = "Wanderer  ·  E Recruit"
			_state_label.modulate = Look.GOLD
		else:
			_state_label.visible = false


func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(max_hp, hp + amount)
	_update_hp_bar()


func apply_temporary_buff(duration: float, speed_mult: float, armor_bonus: float) -> void:
	_buff_timer = maxf(_buff_timer, duration)
	_buff_speed_mult = maxf(_buff_speed_mult, speed_mult)
	_buff_armor_bonus = maxf(_buff_armor_bonus, armor_bonus)


func modify_morale(delta_m: float) -> void:
	if is_leader or is_child or is_caveman or is_wounded:
		return
	morale = clampf(morale + delta_m, 0.0, 100.0)


func start_revolt() -> void:
	if is_leader or is_child or is_revolting or is_wounded:
		return
	is_revolting = true
	original_faction_id = faction_id if faction_id >= 0 else 0
	faction_id = -2
	is_raiding = false
	_rebuild_visual()
	_update_hp_bar()
	GameState.push_log("REVOLT! %s rebelled due to low morale! Subdue them non-lethally." % unit_name, "danger")


func enter_wounded_state() -> void:
	is_revolting = false
	is_wounded = true
	is_healing_in_shack = false
	being_rescued = false
	_rescue_shaman = null
	_rescue_lease_timer = 0.0
	_field_aid_applied = false
	faction_id = -3
	hp = 5.0
	wounded_timer = 60.0
	velocity = Vector3.ZERO
	_knockback_vel = Vector3.ZERO
	_rebuild_visual()
	_update_hp_bar()
	CombatVFX.spawn_damage_popup(self, "INCAPACITATED!", Color(1.0, 0.72, 0.22), 1.2)
	GameState.push_log("%s was subdued and is WOUNDED! Send a Shaman or press [E] within 60s to heal at a Shaman Shack!" % unit_name, "warning")


func claim_rescue(shaman: Node, lease_seconds: float = 1.5) -> void:
	if not is_wounded or is_healing_in_shack:
		return
	_rescue_shaman = shaman
	_rescue_lease_timer = maxf(_rescue_lease_timer, lease_seconds)
	being_rescued = true


func clear_rescue_claim() -> void:
	_rescue_shaman = null
	_rescue_lease_timer = 0.0
	if not is_healing_in_shack:
		being_rescued = false


func apply_field_aid() -> bool:
	if not is_wounded or is_healing_in_shack or _field_aid_applied:
		return false
	_field_aid_applied = true
	wounded_timer = minf(wounded_timer + 20.0, 90.0)
	_update_hp_bar()
	return true


func send_to_shaman_shack(shack_pos: Vector3) -> void:
	if not is_wounded:
		return
	is_healing_in_shack = true
	being_rescued = true
	_rescue_shaman = null
	_rescue_lease_timer = 0.0
	global_position = shack_pos + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
	_update_hp_bar()


func take_damage(amount: float, attacker: Node, attacker_faction: int) -> void:
	if is_dead or is_wounded or GameState.has_truce(faction_id, attacker_faction):
		return
	if is_arena_combatant and attacker != null and not (attacker.get("is_arena_opponent") == true or attacker.get_meta("is_arena_opponent", false) == true):
		return
	if is_arena_opponent and attacker != null and not (attacker.get("is_arena_combatant") == true or attacker.get_meta("is_arena_combatant", false) == true):
		return
	var total_armor := armor + _buff_armor_bonus
	var mitigated := UnitStats.mitigated_damage(amount, total_armor)
	if faction_id == 0 and is_arena_combatant and (hp - mitigated) <= 0.0:
		hp = maxf(1.0, max_hp * 0.20)
		is_arena_combatant = false
		set_meta("is_arena_combatant", false)
		arena_recovery_remaining = 25.0 if is_leader else 55.0
		is_raiding = false
		clear_combat_target()
		_knockback_vel = Vector3.ZERO
		velocity = Vector3.ZERO
		var sm_ko: Node = GameState.get_node_or_null("/root/SoundManager")
		if sm_ko != null:
			sm_ko.play_ui_sfx("ui_click", 0.05)
		CombatVFX.spawn_damage_popup(self, "Knocked Out!", Color(1.0, 0.72, 0.22), 1.15)
		if GameState.arena_bout.has("arena_pos"):
			global_position = (GameState.arena_bout["arena_pos"] as Vector3) + Vector3(0.0, 0.0, 6.2)
		GameState.spatial_index.update_unit(self)
		_update_hp_bar()
		GameState.arena_state_changed.emit()
		return
	hp -= mitigated
	_update_hp_bar()

	# Directional damage flinch, knockback & hit feedback
	_set_hit_flash(0.16)
	var hit_dir_body := Vector3(0.0, 0.0, 1.0)
	var eff_lin := GameData.resolve_effective_lineage(lineage, is_caveman)
	var kb_resist := float(GameData.LINEAGE_DATA.get(eff_lin, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN]).get("knockback_resist", 0.0))
	var atk_is_boss: bool = (attacker != null and attacker.get("is_boss") == true)
	var atk_is_brute: bool = (attacker != null and attacker.get("warrior_class") != null and int(attacker.get("warrior_class")) == GameData.WarriorClass.BRUTE and (attacker.get("role") == GameData.Role.WARRIOR or attacker.get("is_caveman") == true))
	var atk_valk_spear := false
	if attacker != null and GameState.factions.has(attacker_faction) and int(GameState.factions[attacker_faction].get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.VALK_TOR:
		if attacker.get("is_leader") == true:
			atk_valk_spear = true
		elif attacker.has_method("_get_effective_warrior_class"):
			var atk_cls: int = int(attacker._get_effective_warrior_class())
			var atk_role: int = int(attacker.get("role"))
			if (atk_role == GameData.Role.WARRIOR or attacker._is_warhorn_militia()) and (atk_cls == GameData.WarriorClass.SPEARMAN or atk_cls == GameData.WarriorClass.JAVELINEER):
				atk_valk_spear = true
	if attacker != null and attacker is Node3D:
		var atk_pos: Vector3 = (attacker as Node3D).global_position
		var kb := global_position - atk_pos
		kb.y = 0.0
		if kb.length_squared() > 0.001:
			var kb_str := 6.5 * (1.0 - kb_resist * 0.7)
			if atk_is_boss or atk_is_brute:
				kb_str *= 1.45
			if atk_valk_spear:
				kb_str *= 1.25
			_knockback_vel = kb.normalized() * kb_str
			var to_atk := (atk_pos - global_position)
			to_atk.y = 0.0
			if to_atk.length_squared() > 0.001:
				var local_atk := global_transform.basis.inverse() * to_atk.normalized()
				hit_dir_body = Vector3(-local_atk.x, 0.0, -local_atk.z).normalized()

	var ckey := _get_class_key()
	var has_shield: bool = (ckey == "SPEARMAN" or ckey == "JAVELINEER" or ckey == "LEADER" or ckey == "TRAINEE")
	var is_heavy: bool = (mitigated >= max_hp * 0.16) or atk_is_boss or atk_is_brute
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		var blocked_dmg := amount - mitigated
		var is_shielded_block: bool = (has_shield or has_armor) and (blocked_dmg >= 2.0 or (has_shield and not is_heavy))
		var hit_cue := "shield_block" if is_shielded_block else "melee_hit"
		sm.play_sfx_3d(hit_cue, global_position, 0.08, -1.0)
	if (faction_id == 0 and attacker_faction != 0 and (attacker == null or attacker.get("is_child") != true)) or (attacker_faction == 0 and faction_id != 0 and not is_child):
		GameState.notify_combat_audio(14.0)
	_animator.trigger_damage(hit_dir_body, is_heavy, has_shield)
	_skinned_hit_priority = true
	if _skinned_trial != null:
		_skinned_trial.restart_clip(&"Hit")

	if attacker != null and is_instance_valid(attacker) and attacker is CharacterBody3D and attacker.get("is_dead") != true and attacker.get("is_wounded") != true:
		_self_defense_target = attacker
		_self_defense_timer = 6.0

	var dmg_col := Color(1.0, 0.25, 0.22) if faction_id == 0 else Color(1.0, 0.88, 0.28)
	CombatVFX.spawn_damage_popup(self, "-%d" % roundi(mitigated), dmg_col, 1.0)

	# Provoke diplomacy if player hits neutral tribe or vice versa
	if attacker_faction == 0 and ((faction_id >= 1 and faction_id <= 4) or faction_id == 6):
		GameState.set_diplomatic_state(0, faction_id, GameData.DiplomaticState.AT_WAR)
	elif ((attacker_faction >= 1 and attacker_faction <= 4) or attacker_faction == 6) and faction_id == 0:
		GameState.set_diplomatic_state(0, attacker_faction, GameData.DiplomaticState.AT_WAR)

	if hp <= 0.0:
		if is_revolting and original_faction_id == 0:
			enter_wounded_state()
			return
		_die(attacker, attacker_faction, hit_dir_body)


func _die(killer: Node, killer_faction: int, hit_dir_body: Vector3 = Vector3(0.0, 0.0, 1.0)) -> void:
	if is_dead:
		return
	is_dead = true
	hp = 0.0
	_unregister_from_index()

	if GameState.factions.has(killer_faction) and GameState.has_tenet(killer_faction, "BLOOD_SACRIFICE"):
		GameState.add_resource(killer_faction, "faith", 8.0)
		if killer != null and is_instance_valid(killer) and killer.has_method("heal"):
			killer.heal(10.0)
	if not is_arena_opponent and killer_faction in [0, 1, 2, 3, 4, 6] and killer_faction != faction_id:
		GameState.award_xp(killer_faction, 75.0 if is_leader else 18.0, "Combat victory")

	# Capturing defeated Nomadic Cavemen for Enlightenment
	if is_caveman and not is_arena_opponent and killer_faction == 0 and GameState.factions.has(0):
		GameState.factions[0]["captured_cavemen"] += 1
		GameState.add_resource(0, "food", 5.0)
		GameState.add_resource(0, "bone", 2.0)
		GameState.push_log("Captured Nomadic Caveman %s! Enlighten them in [C] Colony." % unit_name, "success")

	# Tribal Succession if Player Leader falls (synchronous so there is no leaderless save window)
	if faction_id == 0 and is_leader:
		is_player_controlled = false
		var fc = GameState.faction_controllers.get(0)
		if fc != null and fc.has_method("handle_player_leader_death"):
			fc.handle_player_leader_death(self)
	elif ((faction_id >= 1 and faction_id <= 4) or faction_id == 6) and is_leader:
		GameState.trigger_conquest_if_eligible(faction_id, killer_faction)
	elif faction_id == 0:
		GameState.push_log("%s (%s) has fallen." % [unit_name, GameData.ROLE_NAMES.get(role, "Tribesman")], "warning")

	collision_layer = 0
	collision_mask = 0
	if _hp_bg != null:
		_hp_bg.visible = false
	if _hp_fill != null:
		_hp_fill.visible = false
	if _selection_ring != null:
		_selection_ring.visible = false
	if _state_label != null:
		_state_label.visible = false
	if _leader_nameplate != null:
		_leader_nameplate.hide()
	velocity = Vector3.ZERO
	_knockback_vel = Vector3.ZERO
	_death_timer = 8.0
	var dv := -1
	if is_caveman or (role == GameData.Role.WARRIOR and warrior_class == GameData.WarriorClass.BRUTE):
		dv = TribesmanAnimator.DeathVariant.KNEE_CRUMPLE
	elif absf(hit_dir_body.x) > 0.50:
		dv = TribesmanAnimator.DeathVariant.SIDE_COLLAPSE
	elif hit_dir_body.z < -0.25:
		dv = TribesmanAnimator.DeathVariant.KNEE_CRUMPLE
	else:
		dv = TribesmanAnimator.DeathVariant.BACKWARD_STAGGER
	_animator.trigger_death(dv, hit_dir_body)
	if dv == TribesmanAnimator.DeathVariant.KNEE_CRUMPLE:
		_death_anim_state = "DEATH_KNEE_CRUMPLE"
	elif dv == TribesmanAnimator.DeathVariant.SIDE_COLLAPSE:
		_death_anim_state = "DEATH_SIDE_COLLAPSE"
	else:
		_death_anim_state = "DEATH_BACK"
	if _skinned_trial != null:
		_set_trial_visible(true)
		_skinned_trial.restart_clip(&"Death")
		_skinned_trial.update_action(_death_anim_state, 0.0, 0.0, _is_psx_jitter_enabled(), _hit_flash_ratio())
	CombatVFX.spawn_damage_popup(self, "SLAIN!", Color(1.0, 0.20, 0.16), 1.35)
	CombatVFX.spawn_blood_pool(self, 0.72)
	GameState.call_deferred("check_victory_conditions")


func _set_hit_flash(duration: float) -> void:
	_hit_flash_timer = maxf(_hit_flash_timer, duration)
	if _skinned_trial != null:
		_set_trial_visible(true)
		_skinned_trial.set_hit_flash(_hit_flash_ratio())
	else:
		CombatVFX.apply_overlay_recursive(_visual_root, CombatVFX.get_hit_flash_material())


func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _skinned_trial != null:
			_skinned_trial.set_hit_flash(_hit_flash_ratio())
		elif _hit_flash_timer <= 0.0:
			CombatVFX.apply_overlay_recursive(_visual_root, null)


func _process_dead_corpse(delta: float) -> void:
	_update_hit_flash(delta)
	if _skinned_trial == null:
		_animator.update(delta, {"is_dead": true})
	else:
		_skinned_trial.update_action(_death_anim_state, 0.0, delta, _is_psx_jitter_enabled(), _hit_flash_ratio())
	_death_timer -= delta
	if _death_timer <= 1.0:
		var s := clampf(_death_timer, 0.05, 1.0)
		if _visual_root != null:
			_visual_root.scale = Vector3(1.0, s, 1.0)
		if _skinned_trial != null:
			_skinned_trial.squash_corpse(s)
	if _death_timer <= 0.0:
		queue_free()


func _update_wounded_animation(delta: float) -> void:
	if _skinned_trial == null:
		_animator.update(delta, {"is_wounded": true})
	else:
		_skinned_trial.update_action("WOUNDED", 0.0, delta, _is_psx_jitter_enabled(), _hit_flash_ratio())
	if _state_label != null:
		_state_label.visible = true
		_state_label.position = Vector3(0.0, 1.35, 0.0)
		var wl_text: String = ""
		var wl_col := Color(1.0, 0.72, 0.22)
		if is_healing_in_shack:
			wl_text = "Healing at the Shack"
			wl_col = Color(0.45, 0.95, 0.60)
		elif being_rescued:
			wl_text = "Rescue in progress"
			wl_col = Color(0.55, 0.85, 1.0)
		else:
			wl_text = "Wounded  ·  E Aid  ·  %ds" % ceili(maxf(wounded_timer, 0.0))
		if wl_text != _last_label_text:
			_last_label_text = wl_text
			_state_label.text = wl_text
			_state_label.modulate = wl_col


func _update_procedural_animation(delta: float) -> void:
	if _knockback_vel.length_squared() > 0.04:
		move_and_collide(_knockback_vel * delta)
		_clamp_to_world_bounds()
		_knockback_vel = _knockback_vel.lerp(Vector3.ZERO, minf(1.0, 11.0 * delta))
	else:
		_knockback_vel = Vector3.ZERO

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if _last_anim_pos != Vector3.ZERO and delta > 0.0001:
		var dp := Vector2(global_position.x - _last_anim_pos.x, global_position.z - _last_anim_pos.z).length() / delta
		horiz_speed = maxf(horiz_speed, dp * 0.85)
	_last_anim_pos = global_position

	if _swing_timer > 0.0:
		if not _animator.is_attacking():
			play_attack_animation("", _swing_duration)
		_swing_timer = maxf(0.0, _swing_timer - delta)

	if _first_person_hidden:
		if _animator.is_attacking() or _animator.is_taking_damage() or _is_working_this_frame or horiz_speed > 0.15 or _mounted:
			_fp_anim_idle_time = 0.0
		elif _fp_anim_idle_time >= 0.24:
			return
		else:
			# Leave time for the standing pose to blend in before freezing its shadow.
			_fp_anim_idle_time += delta

	var cdef := _get_class_def()
	if _skinned_trial == null:
		_animator.update(delta, {
			"horiz_speed": horiz_speed,
			"mounted": _mounted,
			"riding_leg_spread": _riding_leg_spread,
			"is_working": _is_working_this_frame,
			"idle_stance": str(cdef.get("idle_stance", "RELAXED")),
			"work_anim": str(cdef.get("work_anim", "WORK_BUILD")),
		})
		return

	_animator.advance_action_timers(delta)
	var anim_state := "IDLE"
	if _animator.is_taking_damage() and (_skinned_hit_priority or not _animator.is_attacking()):
		anim_state = "DAMAGE_HEAVY"
	elif _animator.is_attacking():
		if _active_attack_anim != "":
			anim_state = _active_attack_anim
		else:
			var eff_wid := get_equipped_weapon_id()
			if eff_wid != "" and GameData.WEAPON_DEFS.has(eff_wid):
				anim_state = str(GameData.WEAPON_DEFS[eff_wid].get("attack_anim", cdef.get("attack_anim", "TOOL_SWING")))
			else:
				anim_state = str(cdef.get("attack_anim", "TOOL_SWING"))
	elif _is_working_this_frame:
		anim_state = str(cdef.get("work_anim", "WORK_BUILD"))
	elif horiz_speed > 0.25 and not _mounted:
		anim_state = "KITE" if _kiting_this_frame else "WALK"
	_skinned_trial.update_action(anim_state, horiz_speed, delta, not _first_person_hidden and _is_psx_jitter_enabled(), _hit_flash_ratio())
	if _mounted:
		_skinned_trial.apply_riding_pose(_riding_leg_spread)


func convert_to_faction(new_faction_id: int, enlighten_bonus: bool = false) -> void:
	faction_id = new_faction_id
	original_faction_id = new_faction_id
	is_leader = false
	is_player_controlled = false
	is_caveman = false
	archetype = ""
	is_revolting = false
	is_wounded = false
	is_healing_in_shack = false
	being_rescued = false
	_rescue_shaman = null
	_rescue_lease_timer = 0.0
	_field_aid_applied = false
	is_raiding = false
	_retreating_to_heal = false
	if _selection_ring != null and is_instance_valid(_selection_ring):
		_selection_ring.visible = false
	morale = maxf(morale, 72.0)
	role = GameData.Role.FORAGER
	squad_order = GameData.SquadOrder.FOLLOW
	if enlighten_bonus and GameState.has_tenet(new_faction_id, "KINSHIP"):
		weapon_tier = maxi(weapon_tier, 2)
	_rebuild_visual()
	GameState.apply_recruit_perks(new_faction_id, self)


func promote_to_player_leader() -> void:
	_promote_to_leader(true)


func promote_to_rival_leader() -> void:
	warrior_class = GameData.WarriorClass.SPEARMAN
	_promote_to_leader(false)


func _promote_to_leader(player_controlled: bool) -> void:
	is_leader = true
	is_player_controlled = player_controlled
	is_child = false
	is_raiding = false
	_retreating_to_heal = false
	role = GameData.Role.WARRIOR
	has_equipped_weapon = true
	equipped_weapon_id = ""
	has_armor = true
	if equipped_armor_id == "NONE":
		equipped_armor_id = ""
	if GameState.factions.has(faction_id):
		GameState.factions[faction_id]["leader_name"] = unit_name
		weapon_tier = maxi(weapon_tier, int(GameState.factions[faction_id].get("tech_tier", 1)))
	_ensure_selection_ring()
	_rebuild_visual()
	recalculate_stats(false)
	hp = max_hp
	_update_hp_bar()


func set_role_and_class(new_role: int, new_warrior_class: int = -1) -> void:
	role = new_role
	if new_warrior_class >= 0:
		warrior_class = new_warrior_class
	_target_node = null
	_carry_amount = 0.0
	_work_timer = 0.0
	_active_craft_item = ""
	if faction_id == 0 and GameState.game_active and not is_leader:
		GameState.tutorial_assigned_role = true
	if role == GameData.Role.WARRIOR:
		if faction_id == 0 and GameState.combat_command_system != null:
			fire_at_will = bool(GameState.combat_command_system.global_fire_at_will)
		try_equip_from_stockpile()
	recalculate_stats(false)


static func _armor_rank(armor_id: String) -> int:
	match armor_id:
		"OBSIDIAN_PLATE":
			return 4
		"PELT_MANTLE":
			return 3
		"BONE_GUARD":
			return 2
		"HIDE_TUNIC":
			return 1
	return 0


func try_equip_from_stockpile() -> void:
	if not GameState.factions.has(faction_id):
		return
	var fdata: Dictionary = GameState.factions[faction_id]
	var stock: Dictionary = fdata["stockpile"]
	var tier: int = int(fdata.get("tech_tier", 1))
	var equipped_any := false

	var cur_wid: String = get_equipped_weapon_id()
	if (is_leader or warrior_class == GameData.WarriorClass.BRUTE) and tier >= 3 and int(stock.get("obsidian_cleavers", 0)) > 0 and cur_wid != "OBSIDIAN_CLEAVER":
		stock["obsidian_cleavers"] = int(stock["obsidian_cleavers"]) - 1
		if equipped_weapon_id != "" and GameData.WEAPON_DEFS.has(equipped_weapon_id):
			var old_wkey: String = str(GameData.WEAPON_DEFS[equipped_weapon_id].get("stock_key", ""))
			if old_wkey != "":
				stock[old_wkey] = int(stock.get(old_wkey, 0)) + 1
		equipped_weapon_id = "OBSIDIAN_CLEAVER"
		has_equipped_weapon = true
		weapon_tier = tier
		equipped_any = true
	elif not has_equipped_weapon or weapon_tier < tier:
		var target_wid: String = "GREAT_SPEAR" if is_leader else GameData.resolve_default_weapon_id(GameData.Role.WARRIOR, warrior_class, false, false)
		var key: String = str(GameData.WEAPON_DEFS.get(target_wid, {}).get("stock_key", "spears"))
		if int(stock.get(key, 0)) > 0:
			stock[key] = int(stock[key]) - 1
			equipped_weapon_id = target_wid
			has_equipped_weapon = true
			weapon_tier = tier
			equipped_any = true

	var cur_aid: String = get_equipped_armor_id() if has_armor else "NONE"
	var cur_rank: int = _armor_rank(cur_aid)
	var upgrade_aid := ""
	var upgrade_key := ""
	if tier >= 3 and cur_rank < 4 and int(stock.get("obsidian_plate", 0)) > 0:
		upgrade_aid = "OBSIDIAN_PLATE"
		upgrade_key = "obsidian_plate"
	elif tier >= 2 and cur_rank < 3 and int(stock.get("pelt_mantle", 0)) > 0:
		upgrade_aid = "PELT_MANTLE"
		upgrade_key = "pelt_mantle"
	elif cur_rank < 2 and int(stock.get("armor", 0)) > 0:
		upgrade_aid = "BONE_GUARD"
		upgrade_key = "armor"
	elif cur_rank < 1 and int(stock.get("hide_tunic", 0)) > 0:
		upgrade_aid = "HIDE_TUNIC"
		upgrade_key = "hide_tunic"

	if upgrade_aid != "":
		stock[upgrade_key] = int(stock[upgrade_key]) - 1
		if equipped_armor_id != "" and equipped_armor_id != "NONE" and GameData.ARMOR_DEFS.has(equipped_armor_id):
			var old_akey: String = str(GameData.ARMOR_DEFS[equipped_armor_id].get("stock_key", ""))
			if old_akey != "":
				stock[old_akey] = int(stock.get(old_akey, 0)) + 1
		equipped_armor_id = upgrade_aid
		has_armor = true
		equipped_any = true

	if equipped_any:
		if faction_id == 0:
			GameState.resources_changed.emit(0)
		recalculate_stats(false)


func _physics_process(delta: float) -> void:
	if not GameState.game_active or GameState.is_paused or GameState.campaign_finished:
		return
	if is_dead:
		_process_dead_corpse(delta)
		return
	_refresh_negotiation_prompt()

	GameState.spatial_index.update_unit(self)
	_nav_repath_cd = maxf(0.0, _nav_repath_cd - delta)
	_scan_enemy_cd -= delta
	_scan_wild_cd -= delta
	_scan_bld_cd -= delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_work_sfx_cd = maxf(0.0, _work_sfx_cd - delta)
	_leader_blessing_cd = maxf(0.0, _leader_blessing_cd - delta)
	_campfire_heal_cd = maxf(0.0, _campfire_heal_cd - delta)
	_self_defense_timer = maxf(0.0, _self_defense_timer - delta)
	if _self_defense_timer <= 0.0 or (typeof(_self_defense_target) != TYPE_NIL and not is_instance_valid(_self_defense_target)):
		_self_defense_target = null
	if typeof(_target_node) != TYPE_NIL and not is_instance_valid(_target_node):
		_target_node = null
	if typeof(_scan_enemy) != TYPE_NIL and not is_instance_valid(_scan_enemy):
		_scan_enemy = null
		_scan_enemy_cd = 0.0
	if typeof(_scan_wild) != TYPE_NIL and not is_instance_valid(_scan_wild):
		_scan_wild = null
		_scan_wild_cd = 0.0
	if typeof(_scan_bld) != TYPE_NIL and not is_instance_valid(_scan_bld):
		_scan_bld = null
		_scan_bld_cd = 0.0
	if _unarmed_punch_vis_timer > 0.0:
		_unarmed_punch_vis_timer = maxf(0.0, _unarmed_punch_vis_timer - delta)
		if _unarmed_punch_vis_timer <= 0.0:
			_set_hand_mounts_visible(true)
	_kiting_this_frame = false
	_is_working_this_frame = false
	if _buff_timer > 0.0:
		_buff_timer -= delta
		if _buff_timer <= 0.0:
			_buff_speed_mult = 1.0
			_buff_armor_bonus = 0.0

	_update_hit_flash(delta)

	if _hp_bg != null and _hp_bg.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var dx := cam.global_position.x - _hp_bg.global_position.x
			var dz := cam.global_position.z - _hp_bg.global_position.z
			if (dx * dx + dz * dz) > 0.01:
				_hp_bg.look_at(cam.global_position, Vector3.UP)
				_hp_fill.look_at(cam.global_position, Vector3.UP)

	if is_child:
		growth_progress += delta / 70.0
		if growth_progress >= 1.0:
			is_child = false
			_rebuild_visual()
			GameState.apply_recruit_perks(faction_id, self)
			GameState.award_xp(faction_id, 25.0, "Youth came of age")
			if faction_id == 0:
				GameState.push_log("%s has grown into adulthood!" % unit_name, "info")

	if is_wounded:
		_update_wounded_animation(delta)
		if is_healing_in_shack:
			heal(12.0 * delta)
			if hp >= max_hp:
				is_wounded = false
				is_healing_in_shack = false
				being_rescued = false
				_rescue_shaman = null
				_rescue_lease_timer = 0.0
				_field_aid_applied = false
				faction_id = original_faction_id
				morale = 65.0
				_rebuild_visual()
				recalculate_stats(false)
				hp = max_hp
				_update_hp_bar()
				GameState.push_log("%s fully healed in the Shaman Shack and rejoined your tribe!" % unit_name, "success")
		else:
			hp = minf(max_hp * 0.50, hp + 0.6 * delta)
			_update_hp_bar()
			if being_rescued:
				var rescuer_valid := false
				if _rescue_shaman != null and is_instance_valid(_rescue_shaman):
					var r_dead: bool = (_rescue_shaman.get("is_dead") == true)
					var r_wounded: bool = (_rescue_shaman.get("is_wounded") == true)
					var r_revolting: bool = (_rescue_shaman.get("is_revolting") == true)
					var r_role: int = int(_rescue_shaman.get("role"))
					var r_fid: int = int(_rescue_shaman.get("faction_id"))
					if not r_dead and not r_wounded and not r_revolting and r_role == GameData.Role.SHAMAN and r_fid == original_faction_id:
						rescuer_valid = true
				if rescuer_valid and _rescue_lease_timer > 0.0:
					_rescue_lease_timer = maxf(0.0, _rescue_lease_timer - delta)
					if _rescue_lease_timer <= 0.0:
						clear_rescue_claim()
				else:
					clear_rescue_claim()
			if not being_rescued:
				wounded_timer -= delta
				if wounded_timer <= 0.0:
					is_wounded = false
					being_rescued = false
					_rescue_shaman = null
					_rescue_lease_timer = 0.0
					hp = max_hp * 0.75
					GameState.found_rebel_faction(self)
					GameState.check_victory_conditions()
		return

	if faction_id == 0 and not is_leader and not is_child:
		if GameState.warhorn_active and GameState.current_phase == GameData.SchedulePhase.DAY_WORK:
			_warhorn_fatigue_timer += delta
			if _warhorn_fatigue_timer >= 15.0:
				_warhorn_fatigue_timer = 0.0
				modify_morale(-3.0)
		if morale < 15.0 and not is_revolting and GameState.can_trigger_revolt():
			start_revolt()
			return

	var recovery_goal := global_position
	if arena_recovery_remaining > 0.0:
		recovery_goal = _process_arena_convalescence(delta)

	if is_player_controlled:
		# PlayerController drives velocity and attacks directly
		_update_procedural_animation(delta)
		return

	_ai_think_cd -= delta
	if arena_recovery_remaining > 0.0:
		if global_position.distance_to(recovery_goal) > 3.2:
			_steer_toward(recovery_goal, move_speed * 0.85)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	elif faction_id == -1:
		_process_wild_wanderer(delta)
	elif faction_id == -2 or is_revolting:
		_process_rebel_ai(delta)
	elif is_caveman:
		_process_feral_caveman(delta)
	else:
		_process_tribal_ai(delta)

	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0

	if not (is_on_floor() and velocity.x == 0.0 and velocity.z == 0.0 and _knockback_vel == Vector3.ZERO and _last_move_idle):
		move_and_slide()
		_clamp_to_world_bounds()
	_last_move_idle = is_on_floor() and velocity.x == 0.0 and velocity.z == 0.0
	if not _kiting_this_frame and Vector2(velocity.x, velocity.z).length() > 0.25:
		var look_p := global_position + Vector3(velocity.x, 0.0, velocity.z)
		look_at(look_p, Vector3.UP)
	if _is_working_this_frame:
		play_work_sound()
	_update_procedural_animation(delta)


func play_work_sound() -> void:
	if _work_sfx_cd > 0.0 or is_dead or is_wounded or is_player_controlled:
		return
	var cue := ""
	match role:
		GameData.Role.BUILDER_CRAFTER:
			cue = "build_hammer"
		GameData.Role.LUMBERJACK, GameData.Role.FORAGER, GameData.Role.FARMER:
			cue = "wood_chop"
		GameData.Role.STONEKNAPPER:
			cue = "stone_mine"
		_:
			return
	_work_sfx_cd = randf_range(0.75, 1.15)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and global_position.distance_squared_to(cam.global_position) > 38.0 * 38.0:
		return
	var sm: Node = GameState.get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_sfx_3d(cue, global_position, 0.10, -8.0)


func _clamp_to_world_bounds() -> void:
	global_position.x = clampf(global_position.x, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)
	global_position.z = clampf(global_position.z, -GameState.valley_layout.unit_half_extent, GameState.valley_layout.unit_half_extent)


func _process_wild_wanderer(_delta: float) -> void:
	UnitCombatAI.process_wild_wanderer(self, _delta)


func _process_feral_caveman(_delta: float) -> void:
	UnitCombatAI.process_feral_caveman(self, _delta)


func _process_rebel_ai(delta: float) -> void:
	UnitCombatAI.process_rebel_ai(self, delta)


func _process_arena_convalescence(delta: float) -> Vector3:
	var near_healer := false
	var best_shack_pos := Vector3.ZERO
	var has_shack := false
	var best_shack_d := INF
	var best_camp_pos := Vector3.ZERO
	var has_camp := false
	var best_camp_d := INF

	for b in GameState.get_faction_buildings(faction_id, "SHAMAN_SHACK", true):
		if not is_instance_valid(b) or b.get("is_destroyed") == true:
			continue
		var bp: Vector3 = (b as Node3D).global_position
		var d_sq := global_position.distance_squared_to(bp)
		if d_sq <= 6.5 * 6.5:
			near_healer = true
		if d_sq < best_shack_d:
			best_shack_d = d_sq
			best_shack_pos = bp
			has_shack = true

	for b in GameState.get_faction_buildings(faction_id, "CAMPFIRE", true):
		if not is_instance_valid(b) or b.get("is_destroyed") == true:
			continue
		var bp: Vector3 = (b as Node3D).global_position
		var d_sq := global_position.distance_squared_to(bp)
		if d_sq <= 6.5 * 6.5:
			near_healer = true
		if d_sq < best_camp_d:
			best_camp_d = d_sq
			best_camp_pos = bp
			has_camp = true

	var heal_mult := 1.75 if near_healer else 1.0
	arena_recovery_remaining = maxf(0.0, arena_recovery_remaining - delta * heal_mult)
	hp = minf(max_hp, hp + (max_hp * 0.015) * delta * heal_mult)
	_update_hp_bar()
	if arena_recovery_remaining <= 0.0:
		GameState.arena_state_changed.emit()

	if has_shack:
		return best_shack_pos
	if has_camp:
		return best_camp_pos
	if GameState.factions.has(faction_id) and bool(GameState.factions[faction_id].get("is_founded", false)):
		return _get_home_camp_pos()
	return global_position


func _process_tribal_ai(delta: float) -> void:
	var is_warrior_mode := (role == GameData.Role.WARRIOR) or is_leader or _is_warhorn_militia() or is_arena_combatant
	var player_warrior := is_warrior_mode and faction_id == 0 and not is_leader
	# These orders either search from camp or ignore enemies entirely (unless fighting in the Arena).
	if not is_arena_combatant and player_warrior and (squad_order == GameData.SquadOrder.GUARD_BASE or squad_order == GameData.SquadOrder.RETREAT):
		_process_player_warrior(delta, null)
		return

	# Enemy detection
	var scan_radius := Layout.SCAN_RANGE_COMBAT if is_warrior_mode else 9.0
	var enemy := _find_nearest_enemy_unit(scan_radius)
	if not is_instance_valid(enemy):
		enemy = null
	if enemy == null and is_warrior_mode:
		enemy = _find_nearest_hostile_wildlife(scan_radius)
		if not is_instance_valid(enemy):
			enemy = null

	if is_warrior_mode:
		if player_warrior:
			_process_player_warrior(delta, enemy)
		else:
			_process_ai_warrior(delta, enemy)
		return

	if UnitAIRoutines.respond_to_civilian_threat(self, enemy):
		return

	# Daily schedule phases for civilians
	match GameState.current_phase:
		GameData.SchedulePhase.DUSK_HEARTH:
			_dusk_routine(delta)
		GameData.SchedulePhase.NIGHT_SLEEP:
			_night_routine(delta)
		_:
			_day_work_routine(delta)


func _process_player_warrior(delta: float, enemy: Node) -> void:
	UnitCombatAI.process_player_warrior(self, delta, enemy)


func _process_ai_warrior(delta: float, enemy: Node) -> void:
	UnitCombatAI.process_ai_warrior(self, delta, enemy)


func _cast_rival_leader_blessing() -> void:
	UnitCombatAI.cast_rival_leader_blessing(self)


func _can_shoot_or_reach(enemy: Node) -> bool:
	return UnitCombatAI.can_shoot_or_reach(self, enemy)


func _face_point(p: Vector3) -> void:
	var target_p := Vector3(p.x, global_position.y, p.z)
	if global_position.distance_squared_to(target_p) > 0.01:
		look_at(target_p, Vector3.UP)


func _engage_target(target: Node) -> void:
	UnitCombatAI.engage_target(self, target)


func _engage_building(b: Node) -> void:
	UnitCombatAI.engage_building(self, b)


func _execute_attack_on(target: Node) -> void:
	UnitCombatAI.execute_attack_on(self, target)


func _fire_arrow_at(aim_pos: Vector3, dmg: float) -> void:
	UnitCombatAI.fire_arrow_at(self, aim_pos, dmg)


func _fire_javelin_at(aim_pos: Vector3, dmg: float) -> void:
	UnitCombatAI.fire_javelin_at(self, aim_pos, dmg)


func _dusk_routine(delta: float) -> void:
	UnitAIRoutines.run_dusk_routine(self, delta)


func _night_routine(delta: float) -> void:
	UnitAIRoutines.run_night_routine(self, delta)


func _day_work_routine(delta: float) -> void:
	UnitAIRoutines.run_day_work_routine(self, delta)


func _train_at_barracks(delta: float) -> void:
	UnitAIRoutines.run_train_at_barracks(self, delta)


func _gain_training_xp(xp_gain: float) -> void:
	UnitAIRoutines.gain_training_xp(self, xp_gain)


func _find_wounded_ally() -> Node:
	return UnitAIRoutines.find_wounded_ally(self)


## Beyond this range units head straight for the target (building centres are solid nav cells).
const NAV_DIRECT_RANGE := 6.0
const NAV_WAYPOINT_REACH := 2.2


func _nav_waypoint(target_pos: Vector3) -> Vector3:
	var nav = GameState.valley_nav
	if not nav.is_ready():
		return target_pos
	var flat_target := Vector3(target_pos.x, 0.0, target_pos.z)
	var needs_path: bool = _nav_target.distance_squared_to(flat_target) > 16.0 or _nav_revision != nav.revision
	if _nav_repath_cd <= 0.0:
		# Reuse a valid route while the unit moves. Stalled units retry after the normal delay.
		var stalled := global_position.distance_squared_to(_nav_progress_pos) < 0.25
		needs_path = needs_path or _nav_path.is_empty() or stalled
		_nav_progress_pos = global_position
		_nav_repath_cd = randf_range(0.45, 0.65)
	if needs_path:
		_nav_path = nav.find_path(global_position, target_pos)
		_nav_idx = 0
		_nav_target = flat_target
		_nav_revision = nav.revision
	while _nav_idx < _nav_path.size() - 1:
		var wp: Vector3 = _nav_path[_nav_idx]
		var dx: float = wp.x - global_position.x
		var dz: float = wp.z - global_position.z
		var can_skip: bool = nav.has_gate_clearance(global_position, _nav_path[_nav_idx + 1])
		var reach := NAV_WAYPOINT_REACH if can_skip else 0.11
		if dx * dx + dz * dz > reach * reach:
			break
		_nav_idx += 1
	if _nav_idx < _nav_path.size() - 1:
		return _nav_path[_nav_idx]
	return target_pos


func _steer_toward(target_pos: Vector3, spd: float) -> void:
	var goal := target_pos
	var raw := target_pos - global_position
	raw.y = 0.0
	var gate_clear: bool = GameState.valley_nav.has_gate_clearance(global_position, target_pos)
	if raw.length_squared() > NAV_DIRECT_RANGE * NAV_DIRECT_RANGE or not gate_clear:
		goal = _nav_waypoint(target_pos)
	var diff := goal - global_position
	diff.y = 0.0
	if diff.length() > (0.2 if gate_clear else 0.09):
		var dir := diff.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _follow_point(center: Vector3, spacing: float) -> void:
	var offset := Vector3(cos(_patrol_angle), 0.0, sin(_patrol_angle)) * spacing
	var goal := center + offset
	if global_position.distance_to(goal) > 1.8:
		_steer_toward(goal, move_speed * _buff_speed_mult)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _patrol_around(center: Vector3, radius: float, delta: float) -> void:
	_patrol_angle += delta * 0.35
	var goal := center + Vector3(cos(_patrol_angle) * radius, 0.0, sin(_patrol_angle) * radius)
	if global_position.distance_to(goal) > 1.5:
		_steer_toward(goal, move_speed * 0.65)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _get_home_camp_pos() -> Vector3:
	if GameState.factions.has(faction_id):
		return GameState.factions[faction_id].get("camp_position", Vector3.ZERO)
	return Vector3.ZERO


func _get_nearest_dropoff_pos() -> Vector3:
	return UnitAIRoutines.get_nearest_dropoff_pos(self)


func _find_nearest_blueprint() -> Node:
	return UnitAIRoutines.find_nearest_blueprint(self)


func _find_nearest_resource_node(types: Array, around: Vector3, max_dist: float) -> Node:
	return UnitAIRoutines.find_nearest_resource_node(types, around, max_dist)


func _find_nearest_prey(max_dist: float) -> Node:
	return UnitAIRoutines.find_nearest_prey(self, max_dist)


func _set_hand_mounts_visible(vis: bool) -> void:
	HumanMeshBuilder.set_hand_mounts_visible(_visual_root, vis)
	if _skinned_trial != null:
		_skinned_trial.set_hand_mounts_visible(vis)


func _engage_unarmed_self_defense(target: Node) -> void:
	UnitCombatAI.engage_unarmed_self_defense(self, target)


## Re-acquisition of scan targets is staggered (0.18-0.28 s jitter per unit); cached targets are revalidated every call.
func _scan_jitter() -> float:
	return randf_range(0.18, 0.28)


static func _cache_alive(n: Node) -> bool:
	return n != null and is_instance_valid(n) and not n.is_queued_for_deletion() and n.get("is_dead") != true


func clear_combat_target() -> void:
	_target_node = null
	_self_defense_target = null
	_self_defense_timer = 0.0
	_scan_enemy = null
	_scan_wild = null
	_scan_bld = null
	_scan_enemy_cd = 0.0
	_scan_wild_cd = 0.0
	_scan_bld_cd = 0.0


func _find_nearest_hostile_wildlife(radius: float) -> Node:
	return _find_cached_wildlife_near_point(global_position, radius)


func _find_cached_wildlife_near_point(point: Vector3, radius: float) -> Node:
	if typeof(_scan_wild) != TYPE_NIL and not is_instance_valid(_scan_wild):
		_scan_wild = null
		_scan_wild_cd = 0.0
	if not is_arena_combatant and not is_arena_opponent and _scan_wild_cd > 0.0 and is_equal_approx(_scan_wild_radius, radius):
		if typeof(_scan_wild) == TYPE_NIL:
			return null
		if _cache_alive(_scan_wild) and UnitAIRoutines.is_wildlife_hostile_to_faction(_scan_wild, faction_id, self):
			return _scan_wild
	_scan_wild_cd = _scan_jitter()
	_scan_wild_radius = radius
	_scan_wild = UnitAIRoutines.find_hostile_wildlife_near_point(self, point, radius)
	return _scan_wild


func _find_nearest_enemy_unit(radius: float) -> Node:
	return _find_cached_enemy_near_point(global_position, radius)


func _find_cached_enemy_near_point(point: Vector3, radius: float) -> Node:
	if typeof(_scan_enemy) != TYPE_NIL and not is_instance_valid(_scan_enemy):
		_scan_enemy = null
		_scan_enemy_cd = 0.0
	if not is_arena_combatant and not is_arena_opponent and _scan_enemy_cd > 0.0 and is_equal_approx(_scan_enemy_radius, radius):
		if typeof(_scan_enemy) == TYPE_NIL:
			return null
		if (_cache_alive(_scan_enemy) and not _scan_enemy.is_wounded
				and GameState.is_hostile(faction_id, _scan_enemy.faction_id)
				and not UnitAIRoutines.is_in_arena_bout(_scan_enemy)):
			return _scan_enemy
	_scan_enemy_cd = _scan_jitter()
	_scan_enemy_radius = radius
	_scan_enemy = _find_enemy_near_point(point, radius)
	return _scan_enemy


func _find_enemy_near_point(point: Vector3, radius: float) -> Node:
	return UnitAIRoutines.find_enemy_near_point(self, point, radius)


func _find_nearest_enemy_building(radius: float) -> Node:
	if is_arena_combatant or is_arena_opponent:
		return null
	if typeof(_scan_bld) != TYPE_NIL and not is_instance_valid(_scan_bld):
		_scan_bld = null
		_scan_bld_cd = 0.0
	if _scan_bld_cd > 0.0 and is_equal_approx(_scan_bld_radius, radius):
		if typeof(_scan_bld) == TYPE_NIL:
			return null
		if (is_instance_valid(_scan_bld) and not _scan_bld.is_queued_for_deletion()
				and not _scan_bld.is_destroyed and GameState.is_hostile(faction_id, _scan_bld.faction_id)):
			return _scan_bld
	_scan_bld_cd = _scan_jitter()
	_scan_bld_radius = radius
	_scan_bld = UnitAIRoutines.find_nearest_enemy_building(self, radius)
	return _scan_bld


func restore_snapshot(snapshot: Dictionary) -> void:
	setup(snapshot)
	_dusk_eaten_today = int(snapshot.get("dusk_eaten_today", -1))
	_night_morale_today = int(snapshot.get("night_morale_today", -1))
	_leader_blessing_cd = maxf(0.0, float(snapshot.get("leader_blessing_cd", 0.0)))
	_buff_timer = maxf(0.0, float(snapshot.get("buff_timer", 0.0)))
	if _buff_timer > 0.0:
		_buff_speed_mult = maxf(0.1, float(snapshot.get("buff_speed_mult", 1.0)))
		_buff_armor_bonus = float(snapshot.get("buff_armor_bonus", 0.0))
	else:
		_buff_speed_mult = 1.0
		_buff_armor_bonus = 0.0
	_carry_type = str(snapshot.get("carry_type", ""))
	_carry_amount = maxf(0.0, float(snapshot.get("carry_amount", 0.0)))
	if _carry_type.is_empty():
		_carry_amount = 0.0
	_field_aid_applied = bool(snapshot.get("field_aid_applied", false))
	hp = clampf(float(snapshot["hp"]), 0.0, max_hp)
	_update_hp_bar()


func serialize() -> Dictionary:
	return {
		"unit_id": unit_id,
		"unit_name": unit_name,
		"faction_id": faction_id,
		"gender": gender,
		"lineage": lineage,
		"role": role,
		"warrior_class": warrior_class,
		"is_leader": is_leader,
		"is_player_controlled": is_player_controlled,
		"is_caveman": is_caveman,
		"archetype": archetype,
		"is_child": is_child,
		"growth_progress": growth_progress,
		"original_faction_id": original_faction_id,
		"base_hp_stat": base_hp_stat,
		"base_melee_stat": base_melee_stat,
		"base_ranged_stat": base_ranged_stat,
		"melee_rank": melee_rank,
		"ranged_rank": ranged_rank,
		"training_xp": training_xp,
		"morale": morale,
		"is_revolting": is_revolting,
		"is_wounded": is_wounded,
		"is_healing_in_shack": is_healing_in_shack,
		"being_rescued": being_rescued,
		"wounded_timer": wounded_timer,
		"arena_recovery_remaining": arena_recovery_remaining,
		"is_arena_champion": is_arena_champion,
		"is_arena_combatant": is_arena_combatant,
		"field_aid_applied": _field_aid_applied,
		"has_equipped_weapon": has_equipped_weapon,
		"weapon_tier": weapon_tier,
		"has_armor": has_armor,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"hp": hp,
		"squad_order": squad_order,
		"hold_position": CampaignSave.pack_position(hold_position),
		"fire_at_will": fire_at_will,
		"is_raiding": is_raiding,
		"raid_target_pos": CampaignSave.pack_position(raid_target_pos),
		"dusk_eaten_today": _dusk_eaten_today,
		"night_morale_today": _night_morale_today,
		"leader_blessing_cd": _leader_blessing_cd,
		"buff_timer": _buff_timer,
		"buff_speed_mult": _buff_speed_mult,
		"buff_armor_bonus": _buff_armor_bonus,
		"carry_type": _carry_type,
		"carry_amount": _carry_amount,
		"recruit_perks_mult": _recruit_perks_mult,
		"pos": CampaignSave.pack_position(global_position),
	}
