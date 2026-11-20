extends "res://scripts/ui/drawers/feature_drawer.gd"

var _selected_faction: int = 1
var _raid_feedback_fid: int = -1
var _raid_feedback_text: String = ""
var _raid_feedback_color: Color = Look.MUTED


func _init() -> void:
	title = "Valley Diplomacy"


func build_content() -> void:
	var player_pow: float = GameState.get_faction_military_power(0)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	self.add_child(columns)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 235
	columns.add_child(list)

	var valid_factions: Array[int] = []
	for fid in range(1, 7):
		if not GameState.factions.has(fid):
			continue
		var fdata: Dictionary = GameState.factions[fid]
		if fid == 6 and not bool(fdata.get("is_founded", false)):
			continue
		valid_factions.append(fid)

	if not valid_factions.has(_selected_faction):
		_selected_faction = valid_factions[0] if not valid_factions.is_empty() else 1
		_raid_feedback_fid = -1
		_raid_feedback_text = ""

	for fid in valid_factions:
		var fdata: Dictionary = GameState.factions[fid]
		var col: Color = GameData.FACTION_COLORS.get(fid, Color.WHITE)
		var target: int = fid
		var button := Look.button(fdata["name"], func():
			if _selected_faction != target:
				_selected_faction = target
				_raid_feedback_fid = -1
				_raid_feedback_text = ""
			refresh()
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = target == _selected_faction
		tag(button, "faction:%d" % target)
		list.add_child(button)
		if target != _selected_faction:
			continue
		var card := _card(columns, col.darkened(0.2))

		var vb := VBoxContainer.new()
		card.add_child(vb)

		var lin_key: int = int(fdata.get("primary_lineage", GameData.Lineage.CRAG_BORN))
		var god_key: int = int(fdata.get("patron_god", GameData.PatronGod.NONE))
		var lin_name: String = GameData.LINEAGE_DATA.get(lin_key, GameData.LINEAGE_DATA[GameData.Lineage.CRAG_BORN])["short_name"]
		var god_name: String = GameData.GOD_DATA.get(god_key, GameData.GOD_DATA[GameData.PatronGod.NONE])["name"]
		var state_val := GameState.get_diplomatic_state(0, fid)
		var state_str := "Defeated" if fdata["is_defeated"] else ("ALLIED" if state_val == GameData.DiplomaticState.ALLIED else ("AT WAR" if state_val == GameData.DiplomaticState.AT_WAR else "Neutral"))
		var opinion := GameState.get_diplomatic_opinion(0, fid)

		var title_lbl := Label.new()
		title_lbl.text = fdata["name"]
		title_lbl.theme_type_variation = &"SectionTitle"
		title_lbl.add_theme_color_override("font_color", col.lightened(0.25))
		vb.add_child(title_lbl)
		var relation := Look.label("%s   ·   Opinion %+d" % [state_str, opinion])
		vb.add_child(relation)
		var leadership := Look.label("%s   ·   %s   ·   %s" % [fdata["leader_name"], lin_name, god_name], &"QuietLabel")
		leadership.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(leadership)

		var spec_lbl := Label.new()
		var preset: Dictionary = GameData.RIVAL_PRESETS.get(fid, {})
		if fid != 5:
			var breakdown: Dictionary = GameState.get_diplomatic_opinion_breakdown(0, fid)
			var god_mod: int = int(breakdown.get("god", 0))
			var tenet_mod: int = int(breakdown.get("tenets", 0))
			var offering_mod: int = int(breakdown.get("peaceful_offering", 0))
			var rel_mod: int = int(breakdown.get("actions", 0))
			var bound_mod: int = int(breakdown.get("state_bound", 0))
			var total_op: int = int(breakdown.get("total", opinion))
			var parts := PackedStringArray([
				"God: %+d" % god_mod,
				"Tenets: %+d" % tenet_mod,
			])
			if offering_mod != 0:
				parts.append("Peaceful Offering: %+d" % offering_mod)
			parts.append("Gifts/Actions: %+d" % rel_mod)
			if bound_mod != 0:
				var bound_label := "War Bound" if state_val == GameData.DiplomaticState.AT_WAR else ("Ally Bound" if state_val == GameData.DiplomaticState.ALLIED else "State Bound")
				parts.append("%s: %+d" % [bound_label, bound_mod])
			var cap_mod: int = total_op - (god_mod + tenet_mod + offering_mod + rel_mod + bound_mod)
			if cap_mod != 0:
				parts.append("Cap: %+d" % cap_mod)
			var rival_pow: float = GameState.get_faction_military_power(fid)
			spec_lbl.text = "%s | Units: %d | Strength: %d (Yours: %d) | Opinion Breakdown [%s]" % [
				str(preset.get("personality_desc", "")), GameState.get_faction_units(fid, true).size(), int(rival_pow), int(player_pow), ", ".join(parts)
			]
		else:
			spec_lbl.text = "%s | Living Raiders: %d" % [str(preset.get("personality_desc", "")), GameState.get_faction_units(fid, true).size()]
		spec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vb.add_child(spec_lbl)

		if fid != 5 and not fdata["is_defeated"]:
			_add_diplomacy_actions(vb, fid, fdata, state_val)


func _find_war_enemy(ally_id: int) -> int:
	for enemy_id in range(1, 5):
		if enemy_id == ally_id or not GameState.factions.has(enemy_id):
			continue
		if not bool(GameState.factions[enemy_id].get("is_defeated", false)) and GameState.get_diplomatic_state(0, enemy_id) == GameData.DiplomaticState.AT_WAR:
			return enemy_id
	return -1


func _add_diplomacy_actions(vb: VBoxContainer, target_id: int, fdata: Dictionary, state_val: int) -> void:
	var act_row := GridContainer.new()
	act_row.columns = 2
	vb.add_child(act_row)

	var gift_b := Button.new()
	gift_b.text = "Send Gift (20F, 15W)"
	gift_b.pressed.connect(func():
		if GameState.combat_command_system:
			GameState.combat_command_system.send_gift(target_id)
	)
	tag(gift_b, "gift")
	act_row.add_child(gift_b)

	var preach_b := Button.new()
	preach_b.text = "Preach Faith (15 Faith)"
	preach_b.pressed.connect(func():
		if GameState.combat_command_system:
			GameState.combat_command_system.preach_religion(target_id)
	)
	tag(preach_b, "preach")
	act_row.add_child(preach_b)

	var raid_feedback_lbl: Label = null
	if state_val == GameData.DiplomaticState.ALLIED:
		raid_feedback_lbl = Look.label("", &"QuietLabel", 14)
		raid_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ready_enemy_id: int = _find_war_enemy(target_id)
		if _raid_feedback_fid == target_id and not _raid_feedback_text.is_empty():
			raid_feedback_lbl.text = _raid_feedback_text
			raid_feedback_lbl.modulate = _raid_feedback_color
		elif ready_enemy_id > 0:
			raid_feedback_lbl.text = "War target ready: %s." % str(GameState.factions[ready_enemy_id]["name"])
			raid_feedback_lbl.modulate = Look.MUTED
		else:
			raid_feedback_lbl.text = "You are not currently at war with any rival tribe."
			raid_feedback_lbl.modulate = Look.MUTED

		var call_b := Button.new()
		call_b.text = "Call Ally to Raid War Enemies"
		call_b.pressed.connect(func():
			var enemy_id: int = _find_war_enemy(target_id)
			if enemy_id > 0:
				var enemy_name: String = str(GameState.factions[enemy_id]["name"])
				_raid_feedback_fid = target_id
				_raid_feedback_text = "Called %s to raid %s." % [str(fdata["name"]), enemy_name]
				_raid_feedback_color = Look.MOSS
				if is_instance_valid(raid_feedback_lbl):
					raid_feedback_lbl.text = _raid_feedback_text
					raid_feedback_lbl.modulate = _raid_feedback_color
				if GameState.combat_command_system:
					GameState.combat_command_system.call_ally_to_war(target_id, enemy_id)
			else:
				_raid_feedback_fid = target_id
				_raid_feedback_text = "You have no active tribal wars to call %s into." % str(fdata["name"])
				_raid_feedback_color = Look.GOLD
				if is_instance_valid(raid_feedback_lbl):
					raid_feedback_lbl.text = _raid_feedback_text
					raid_feedback_lbl.modulate = _raid_feedback_color
				GameState.push_log(_raid_feedback_text, "info")
		)
		tag(call_b, "call")
		act_row.add_child(call_b)
	else:
		var ally_b := Button.new()
		ally_b.text = "Propose Alliance (Need +35)"
		ally_b.pressed.connect(func():
			if GameState.combat_command_system:
				GameState.combat_command_system.propose_alliance(target_id)
		)
		tag(ally_b, "ally")
		act_row.add_child(ally_b)

	if state_val == GameData.DiplomaticState.AT_WAR:
		var peace_b := Button.new()
		peace_b.text = "Offer Peace (25F, 15 Flint)"
		peace_b.pressed.connect(func():
			if GameState.combat_command_system:
				GameState.combat_command_system.offer_peace_tribute(target_id)
		)
		tag(peace_b, "peace")
		act_row.add_child(peace_b)
	else:
		var war_b := Button.new()
		war_b.text = "Declare War"
		war_b.pressed.connect(func():
			if GameState.combat_command_system:
				GameState.combat_command_system.declare_war(target_id)
		)
		tag(war_b, "war")
		act_row.add_child(war_b)

	if raid_feedback_lbl != null:
		vb.add_child(raid_feedback_lbl)
