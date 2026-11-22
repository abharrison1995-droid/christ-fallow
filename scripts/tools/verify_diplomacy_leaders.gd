extends SceneTree
## Starts a campaign and exercises leader encounters, treaties, succession, and conquest reloads.

var _state: Node
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to the same isolated directory.")
		quit(1)
		return
	_state = root.get_node("GameState")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(17394)
	_state.start_new_campaign("Enoch", "Diplomacy Probe", GameData.Lineage.CRAG_BORN)
	_check_leaders()
	await _check_negotiations()
	await _check_succession_and_tribute("user://diplomacy-probe-%d.json" % Time.get_ticks_usec())
	_state.end_campaign()
	root.remove_child(main)
	main.queue_free()
	await process_frame
	if _failures == 0:
		print("DIPLOMACY LEADERS VERIFICATION PASSED")
	quit(0 if _failures == 0 else 1)


func _check_leaders() -> void:
	var nameplates := {}
	for fid in range(5):
		var leader: Node = _state.get_faction_leader(fid)
		if not _check(leader != null and leader._leader_nameplate != null, "Faction %d has a named world leader" % fid):
			continue
		var nameplate: Label3D = leader._leader_nameplate
		_check(nameplate.visible and nameplate.text.contains(leader.unit_name) and not nameplates.has(nameplate.text),
			"Faction %d has an individual crest, name, and title" % fid)
		nameplates[nameplate.text] = true
		for unit in _state.get_faction_units(fid):
			if unit != leader:
				_check(leader.max_hp > unit.max_hp, "Faction %d leader has the strongest health pool" % fid)


func _check_negotiations() -> void:
	var resources: Dictionary = _state.factions[0]["resources"]
	resources["food"] = 180.0
	resources["wood"] = 120.0
	resources["flint"] = 100.0
	var hud: Node = _state.hud_controller
	var first: Node = _state.get_faction_leader(1)
	_approach(first)
	_check(first._leader_nameplate.text.contains("[E] Negotiate"), "Approaching a live leader shows the negotiation prompt")
	_key(KEY_E)
	await process_frame
	var drawer: Node = hud._drawer_views["DIPLOMACY"]
	_check(hud._active_tab == "DIPLOMACY" and drawer._selected_faction == 1 and _has_label(drawer, first.unit_name),
		"E opens the approached leader's diplomacy card")
	var stock: Dictionary = _state.factions[1]["resources"]
	var gift_before: float = stock["food"]
	_press(drawer, "gift")
	_press(drawer, "gift")
	_press(drawer, "ally")
	_check(is_equal_approx(float(stock["food"]), gift_before + 40.0)
		and _state.get_diplomatic_state(0, 1) == GameData.DiplomaticState.ALLIED,
		"Two gifts transfer stock and unlock an in-person alliance")
	_key(KEY_ESCAPE)
	var second: Node = _state.get_faction_leader(2)
	_state.combat_command_system.declare_war(2)
	_approach(second)
	_key(KEY_E)
	await process_frame
	_check(drawer._selected_faction == 2 and _has_label(drawer, second.unit_name),
		"Approaching another village selects its live representative")
	_state.faction_controllers[2].launch_raid_against(0)
	var player: Node = _state.get_faction_leader(0)
	var target: Node = player._find_nearest_enemy_unit(25.0)
	_check(target != null and target.faction_id == 2, "War fills the combat target cache")
	_press(drawer, "peace")
	_check(_has_label(drawer, "Truce") and is_equal_approx(_state.get_truce_days(0, 2), 2.0),
		"Peace establishes a visible two-day truce")
	target = player._find_nearest_enemy_unit(25.0)
	_check(target == null or target.faction_id != 2, "Peace immediately invalidates a cached combat target")
	var hp: float = second.hp
	second.take_damage(40.0, _state.get_faction_leader(0), 0)
	_check(is_equal_approx(hp, float(second.hp)) and not _state.set_diplomatic_state(2, 0, GameData.DiplomaticState.AT_WAR),
		"Neither direct strikes nor AI declarations can break a truce")
	_state.combat_command_system.declare_war(2)
	_state.faction_controllers[2].launch_raid_against(0)
	for unit in _state.get_faction_units(2):
		_check(not unit.is_raiding, "The former enemy cannot raid the player during truce")
	_check(_state.get_diplomatic_state(0, 2) == GameData.DiplomaticState.NEUTRAL,
		"Player declaration remains neutral during truce")
	_key(KEY_ESCAPE)


func _check_succession_and_tribute(path: String) -> void:
	var third: Node = _state.get_faction_leader(3)
	third.take_damage(third.max_hp + 100.0, null, 5)
	var heir: Node = _state.get_faction_leader(3)
	if not _check(heir != null and heir != third and not _state._conquest_pending_factions.has(3),
		"A village with a camp and survivors immediately elects a successor after a third-party kill"):
		return
	var heir_id: int = heir.unit_id
	var fourth: Node = _state.get_faction_leader(4)
	fourth.take_damage(fourth.max_hp + 100.0, _state.get_faction_leader(0), 0)
	_check(_state._conquest_pending_factions.has(4) and _state.is_paused and _state.get_faction_leader(4) == null,
		"The same outcome from a player attack pauses for conquest")
	_check(_state.save_game(path) and _state.load_game(path), "A pending conquest reloads")
	_check(_state.get_faction_leader(4) == null and _state._conquest_pending_factions.has(4),
		"Reload keeps the pending choice ahead of succession")
	_check(_state.get_faction_leader(3).unit_id == heir_id and _state.factions[3]["leader_name"] == _state.get_faction_leader(3).unit_name,
		"The new representative and name survive reload")
	_state.resolve_conquest(4, "TRIBUTARY")
	_check(_state.get_diplomatic_state(0, 4) == GameData.DiplomaticState.TRIBUTARY
		and _state.is_treaty_ally(0, 4) and _state.get_faction_leader(4) != null and not _state.is_paused,
		"Tributary conquest preserves the tribe and appoints its leader")
	_check(_state.save_game(path) and _state.load_game(path) and _state.get_truce_days(0, 2) == 2.0
		and _state.get_diplomatic_state(0, 4) == GameData.DiplomaticState.TRIBUTARY,
		"Both agreements survive an active campaign reload")
	var player_stock: Dictionary = _state.factions[0]["resources"]
	var payer_stock: Dictionary = _state.factions[4]["resources"]
	payer_stock["food"] = 10.0
	payer_stock["flint"] = 4.0
	var food: float = player_stock["food"]
	var flint: float = player_stock["flint"]
	_state.time_of_day = 23.95
	_state._process(2.0)
	_check(is_equal_approx(float(player_stock["food"]), food + 8.0) and is_equal_approx(float(payer_stock["food"]), 2.0)
		and is_equal_approx(float(player_stock["flint"]), flint + 3.0) and is_equal_approx(float(payer_stock["flint"]), 1.0),
		"A new day transfers actual food and flint stocks from a tributary")
	_check(_state.get_truce_days(0, 2) == 1.0, "A new day advances the truce")
	_state.time_of_day = 23.95
	_state._process(2.0)
	_check(is_equal_approx(float(player_stock["food"]), food + 10.0) and is_zero_approx(float(payer_stock["food"])),
		"An understocked tributary pays only its available resources")
	_check(not _state.has_truce(0, 2) and _state.set_diplomatic_state(2, 0, GameData.DiplomaticState.AT_WAR),
		"The declaration becomes valid after truce expiry")
	_approach(_state.get_faction_leader(3))
	_key(KEY_E)
	await process_frame
	var drawer: Node = _state.hud_controller._drawer_views["DIPLOMACY"]
	_check(drawer._selected_faction == 3 and _has_label(drawer, _state.get_faction_leader(3).unit_name),
		"The diplomacy card identifies a successor after reload")
	DirAccess.remove_absolute(path)


func _approach(target: Node) -> void:
	var leader: Node = _state.get_faction_leader(0)
	leader.global_position = target.global_position + Vector3(0.0, 0.0, 3.0)
	_state.spatial_index.update_unit(leader)
	target._refresh_negotiation_prompt()


func _press(drawer: Node, action: String) -> void:
	for button in drawer.find_children("*", "Button", true, false):
		if button.get_meta("drawer_focus", "") == action and not button.disabled:
			button.grab_focus()
			_key(KEY_ENTER)
			return
	_check(false, "Negotiation offers %s" % action)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _has_label(node: Node, value: String) -> bool:
	for label in node.find_children("*", "Label", true, false):
		if label.text.contains(value):
			return true
	return false


func _check(condition: bool, caption: String) -> bool:
	if not condition:
		_failures += 1
		push_error(caption)
	return condition
