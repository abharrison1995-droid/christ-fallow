extends "res://scripts/ui/drawers/feature_drawer.gd"

var _selected_faction := 1


func _init() -> void:
	title = "Valley Diplomacy"


func build_content() -> void:
	var player_pow: float = GameState.get_faction_military_power(0)
	var f0: Dictionary = GameState.factions[0]
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	self.add_child(columns)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 235
	columns.add_child(list)

	for fid in range(1, 7):
		if not GameState.factions.has(fid):
			continue
		var fdata: Dictionary = GameState.factions[fid]
		if fid == 6 and not bool(fdata.get("is_founded", false)):
			continue
		var col: Color = GameData.FACTION_COLORS.get(fid, Color.WHITE)
		var target: int = fid
		var button := Look.button(fdata["name"], func():
			_selected_faction = target
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
			var god_mod := 30 if (int(f0.get("patron_god", 0)) != 0 and int(f0.get("patron_god", 0)) == int(fdata.get("patron_god", 0))) else 0
			var tenet_mod := 0
			var t0: Array = f0.get("tenets", [])
			var tb: Array = fdata.get("tenets", [])
			for t in t0:
				if tb.has(t):
					tenet_mod += 20
				elif tb.has(GameData.TENET_DATA.get(t, {}).get("opposing", "")):
					tenet_mod -= 20
			var dkey := GameState.get_diplomatic_key(0, fid)
			var rel_mod := int(GameState.diplomacy.get(dkey, {}).get("opinion_mod", 0))
			var rival_pow: float = GameState.get_faction_military_power(fid)
			spec_lbl.text = "%s | Units: %d | Strength: %d (Yours: %d) | Opinion Breakdown [God: %+d, Tenets: %+d, Gifts/Actions: %+d]" % [
				preset.get("personality_desc", ""), GameState.get_faction_units(fid, true).size(), int(rival_pow), int(player_pow), god_mod, tenet_mod, rel_mod
			]
		else:
			spec_lbl.text = "%s | Living Raiders: %d" % [preset.get("personality_desc", ""), GameState.get_faction_units(fid, true).size()]
		spec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vb.add_child(spec_lbl)

		if fid != 5 and not fdata["is_defeated"]:
			_add_diplomacy_actions(vb, fid, fdata, state_val)


func _add_diplomacy_actions(vb: VBoxContainer, target_id: int, fdata: Dictionary, state_val: int) -> void:
	var act_row := GridContainer.new()
	act_row.columns = 2
	vb.add_child(act_row)

	var gift_b := Button.new()
	gift_b.text = "Send Gift (20F, 15W)"
	gift_b.pressed.connect(func():
		if GameState.combat_command_system: GameState.combat_command_system.send_gift(target_id)
		refresh()
	)
	tag(gift_b, "gift")
	act_row.add_child(gift_b)

	var preach_b := Button.new()
	preach_b.text = "Preach Faith (15 Faith)"
	preach_b.pressed.connect(func():
		if GameState.combat_command_system: GameState.combat_command_system.preach_religion(target_id)
		refresh()
	)
	tag(preach_b, "preach")
	act_row.add_child(preach_b)

	if state_val == GameData.DiplomaticState.ALLIED:
		var call_b := Button.new()
		call_b.text = "Call Ally to Raid War Enemies"
		call_b.pressed.connect(func():
			var called := false
			for enemy_id in range(1, 5):
				if enemy_id != target_id and not GameState.factions[enemy_id]["is_defeated"] and GameState.get_diplomatic_state(0, enemy_id) == GameData.DiplomaticState.AT_WAR:
					if GameState.combat_command_system:
						GameState.combat_command_system.call_ally_to_war(target_id, enemy_id)
					called = true
					break
			if not called:
				GameState.push_log("You have no active tribal wars to call %s into." % fdata["name"], "info")
		)
		tag(call_b, "call")
		act_row.add_child(call_b)
	else:
		var ally_b := Button.new()
		ally_b.text = "Propose Alliance (Need +35)"
		ally_b.pressed.connect(func():
			if GameState.combat_command_system: GameState.combat_command_system.propose_alliance(target_id)
			refresh()
		)
		tag(ally_b, "ally")
		act_row.add_child(ally_b)

	if state_val == GameData.DiplomaticState.AT_WAR:
		var peace_b := Button.new()
		peace_b.text = "Offer Peace (25F, 15 Flint)"
		peace_b.pressed.connect(func():
			if GameState.combat_command_system: GameState.combat_command_system.offer_peace_tribute(target_id)
			refresh()
		)
		tag(peace_b, "peace")
		act_row.add_child(peace_b)
	else:
		var war_b := Button.new()
		war_b.text = "Declare War"
		war_b.pressed.connect(func():
			if GameState.combat_command_system: GameState.combat_command_system.declare_war(target_id)
			refresh()
		)
		tag(war_b, "war")
		act_row.add_child(war_b)
