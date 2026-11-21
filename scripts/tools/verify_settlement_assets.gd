extends "res://scripts/tools/verify_crag_born.gd"

const GROUPS := {
	"settlement": ["CAMPFIRE", "FORAGER_LODGE", "CRAFTING_PIT"],
	"warband": ["SACRED_TOTEM", "SHAMAN_SHACK", "WEAPON_RACK", "BARRACKS"],
	"farm": ["CROP_FIELD", "ANIMAL_PEN"],
}
const STAGES := ["Stage_Intact", "Stage_Damaged", "Stage_Critical", "Stage_Rubble"]
const SITE := Vector3(94, 0, 38)
const TILE := Vector2i(280, 190)


func _run() -> void:
	_state = root.get_node("GameState")
	_factory = root.get_node("MeshFactory")
	var group := ""
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--batch="):
			group = arg.trim_prefix("--batch=")
		elif arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if not _check(GROUPS.has(group) and out_dir.is_absolute_path() and DirAccess.make_dir_recursive_absolute(out_dir) == OK
			and not scratch.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"),
			"Set a valid --batch, writable --out-dir, and isolated saves"):
		quit(1)
		return
	var kinds: Array = GROUPS[group]
	await _verify_campaign_buildings(kinds, group)
	await _capture_buildings(kinds, out_dir.path_join("%s-buildings.png" % group))
	if _issues.is_empty():
		print("SETTLEMENT ASSET VERIFICATION PASSED")
	quit(0 if _issues.is_empty() else 1)


func _verify_campaign_buildings(kinds: Array, group: String) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_state.start_new_campaign("Ena", "Asset Review", GameData.Lineage.CRAG_BORN)
	for resource in ["food", "wood", "stone", "flint", "bone", "hide", "faith"]:
		_state.add_resource(0, resource, 95.0)
	var buildings := {}
	for i in range(kinds.size()):
		var kind: String = kinds[i]
		var placed := _place(kind, SITE + Vector3(i * 8.0, 0, 0))
		if placed != null:
			buildings[kind] = placed
	if buildings.size() == kinds.size():
		if group == "settlement":
			_verify_settlement(buildings)
		elif group == "warband":
			_verify_warband(buildings)
		await _verify_damage_and_reload(buildings)
	main.free()
	await process_frame


func _place(kind: String, point: Vector3) -> Node:
	var model_file := "res://assets/models/buildings/%s_stages.glb" % kind.to_lower()
	var packed := load(model_file) as PackedScene
	if not _check(packed != null, "%s has a production GLB" % kind):
		return null
	var raw := packed.instantiate()
	for stage in STAGES:
		_check(raw.get_node_or_null(stage) != null, "%s imports %s" % [kind, stage])
	raw.free()
	var player: Node = _state.player_controller
	player.enter_build_mode(kind)
	var ghost: Node3D = player._blueprint_ghost
	_check(ghost.get_node_or_null("Stage_Intact") != null and ghost.find_children("*", "Light3D").is_empty(),
		"%s uses the unlit imported intact preview" % kind)
	player.blueprint_rot_y = PI * 0.25
	ghost.global_position = point
	player._try_place_blueprint()
	var found: Array = _state.get_faction_buildings(0, kind)
	if not _check(found.size() == 1, "%s can be placed" % kind):
		return null
	var building: Node = found.front()
	if not building.is_constructed:
		building.advance_construction(building.build_time + 0.1)
	_check(building.is_constructed and is_equal_approx(building.rotation.y, PI * 0.25), "%s builds at its preview rotation" % kind)
	if kind in ["CROP_FIELD", "ANIMAL_PEN"]:
		_check(building._col_shape.disabled, "%s remains walkable" % kind)
	return building


func _worker(point: Vector3, role: int) -> Node:
	var worker: Node = _state.faction_controllers[0].spawn_colonist(point, GameData.Lineage.CRAG_BORN,
		GameData.Gender.FEMALE, role)
	worker.set_physics_process(false)
	return worker


func _verify_settlement(buildings: Dictionary) -> void:
	var camp: Node = buildings["CAMPFIRE"]
	var lodge: Node = buildings["FORAGER_LODGE"]
	var pit: Node = buildings["CRAFTING_PIT"]
	_check(_state.factions[0]["is_founded"] and camp._find_in_active_stage("CampfireLight") != null
		and camp._find_in_active_stage("FlameMesh") != null, "Campfire founds the settlement with its light and flame")
	var gatherer := _worker(camp.global_position + Vector3(1.7, 0, 0), GameData.Role.FORAGER)
	var berries := Node3D.new()
	berries.set_meta("node_type", "BERRY_BUSH")
	_state.resources_container.add_child(berries)
	berries.global_position = gatherer.global_position + Vector3(0, 0, 1.5)
	gatherer._target_node = berries
	gatherer._day_work_routine(3.5)
	_check(is_equal_approx(gatherer._carry_amount, 6.25) and lodge.is_constructed, "The finished Lodge raises food yield by 25 percent")
	var stock: Dictionary = _state.factions[0]["resources"]
	var food: float = stock["food"]
	gatherer._day_work_routine(0.1)
	_check(stock["food"] > food, "Campfire accepts the harvest as a drop-off")
	gatherer.hp -= 8.0
	var hurt: float = gatherer.hp
	_state.current_phase = GameData.SchedulePhase.DUSK_HEARTH
	camp._physics_process(2.1)
	_check(gatherer.hp > hurt, "Campfire heals nearby workers at dusk")
	_state.current_phase = GameData.SchedulePhase.DAY_WORK
	var crafter := _worker(pit.global_position + Vector3(1.9, 0, 0), GameData.Role.BUILDER_CRAFTER)
	var faction: Node = _state.faction_controllers[0]
	_check(faction.queue_craft("spears"), "The built Crafting Pit enables recipe queueing")
	crafter._day_work_routine(20.0)
	_check(_state.factions[0]["craft_queue"].is_empty() and faction.upgrade_stone_age_tier(),
		"Crafting Pit completes the recipe and enables a tier upgrade")


func _verify_warband(buildings: Dictionary) -> void:
	var totem: Node = buildings["SACRED_TOTEM"]
	var shack: Node = buildings["SHAMAN_SHACK"]
	var barracks: Node = buildings["BARRACKS"]
	var rack: Node = buildings["WEAPON_RACK"]
	var shaman := _worker(totem.global_position + Vector3(2, 0, 0), GameData.Role.SHAMAN)
	var stock: Dictionary = _state.factions[0]["resources"]
	var faith: float = stock["faith"]
	shaman._day_work_routine(4.1)
	_check(is_equal_approx(float(stock["faith"]) - faith, 2.5), "Shaman draws the totem Faith bonus")
	_state.factions[0]["captured_cavemen"] = 1
	_check(_state.combat_command_system.enlighten_captured_caveman(), "Sacred Totem enables captive enlightenment")
	var casualty := _worker(shaman.global_position + Vector3(1.7, 0, 0), GameData.Role.FORAGER)
	casualty.enter_wounded_state()
	shaman._day_work_routine(0.1)
	_check(casualty.is_healing_in_shack and shack._find_in_active_stage("ShamanLight") != null,
		"Shaman carries the casualty to the lit Healing Shack")
	casualty._physics_process(20.0)
	_check(not casualty.is_wounded, "Healing Shack restores the rescued villager")
	var trainee := _worker(barracks.global_position + Vector3(2.3, 0, 0), GameData.Role.TRAINEE)
	trainee._day_work_routine(3.7)
	_check(trainee.training_xp > 0.0, "Trainee accrues Barracks XP")
	var guard := _worker(rack.global_position + Vector3(1.8, 0, 0), GameData.Role.WARRIOR)
	guard.has_equipped_weapon = false
	guard.has_armor = false
	guard.try_equip_from_stockpile()
	_check(rack.is_constructed and guard.has_equipped_weapon and guard.has_armor, "Warrior collects the available rack equipment")


func _verify_damage_and_reload(buildings: Dictionary) -> void:
	for kind in buildings:
		var building: Node = buildings[kind]
		building.take_damage(building.max_hp * 0.40, 5)
		_check(building.damage_stage == 1, "%s enters damaged stage" % kind)
		building.take_damage(building.max_hp * 0.36, 5)
		_check(building.damage_stage == 2 and building._status_bar_mesh.visible, "%s shows critical hostile damage" % kind)
		var lamp_name := "CampfireLight" if kind == "CAMPFIRE" else "ShamanLight" if kind == "SHAMAN_SHACK" else ""
		if not lamp_name.is_empty():
			var lamp := building._find_in_active_stage(lamp_name) as OmniLight3D
			_check(lamp != null and lamp.visible and lamp.light_energy <= 1.0, "%s uses the dimmed critical light" % kind)
	var path := OS.get_user_data_dir().path_join("settlement-assets.json")
	if _check(_state.save_game(path) and _state.load_game(path), "Save and restore the imported settlement"):
		for kind in buildings:
			var restored: Node = _state.get_faction_buildings(0, kind).front()
			_check(restored.damage_stage == 2, "%s restores its imported damage stage" % kind)
			restored.take_damage(restored.max_hp, 5)
			await physics_frame
			await physics_frame
			_check(restored.damage_stage == 3 and restored._col_shape.disabled, "%s rubble has no collision" % kind)
	DirAccess.remove_absolute(path)


func _capture_buildings(kinds: Array, path: String) -> void:
	_setup_stage()
	var sheet := Image.create(TILE.x * 4, TILE.y * kinds.size(), false, Image.FORMAT_RGB8)
	_camera.position = Vector3(7.5, 8.5, 13.2)
	_camera.look_at(Vector3(0, 1.0, 0))
	for row in range(kinds.size()):
		for stage in range(4):
			var model: Node3D = _factory.build_building_mesh(kinds[row], Color(0.72, 0.48, 0.21), false, stage)
			_stage.add_child(model)
			await process_frame
			await RenderingServer.frame_post_draw
			var center := Vector2i(_camera.unproject_position(Vector3(0, 1.0, 0)))
			var shot := root.get_texture().get_image().get_region(Rect2i(center - TILE / 2, TILE))
			shot.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(stage * TILE.x, row * TILE.y))
			model.free()
	_check(sheet.save_png(path) == OK, "Capture all building damage stages")
