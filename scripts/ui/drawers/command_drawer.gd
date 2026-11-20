extends "res://scripts/ui/drawers/feature_drawer.gd"

const Options = preload("res://scripts/ui/hud_drawers.gd")


func _init() -> void:
	title = "Tribal Command"


func build_content() -> void:
	var sections := GridContainer.new()
	sections.columns = 2
	self.add_child(sections)
	for entry in [
		["Build   B", "Found your settlement and place structures.", "BUILD"],
		["Colony   C", "Manage your roster, workforce, and crafting queue.", "COLONY"],
		["Faith   R", "Choose a patron and sacred tenets.", "RELIGION"],
		["Diplomacy   V", "Read relations and send envoys to rival tribes.", "DIPLOMACY"],
	]:
		var tab: String = entry[2]
		var button := Look.button(entry[0], func(): navigate_requested.emit(tab), &"MenuButtonRow")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = entry[1]
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag(button, tab)
		sections.add_child(button)
	_populate_menu_warband_card()
	self.add_child(Look.button("Campaign Pause Menu   P", func(): pause_requested.emit()))


func _populate_menu_warband_card() -> void:
	var war_panel: PanelContainer = _card(self)
	var wvb := VBoxContainer.new()
	wvb.add_theme_constant_override("separation", 8)
	war_panel.add_child(wvb)

	var w_hdr := Label.new()
	w_hdr.text = "Warband Squads & Combat Orders"
	w_hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	wvb.add_child(w_hdr)

	var ccs: Node = GameState.combat_command_system
	var sel_cls: int = int(ccs.selected_warrior_class) if ccs != null else -1
	var cur_ord: int = int(ccs.last_issued_order) if ccs != null else GameData.SquadOrder.FOLLOW
	var is_faw: bool = bool(ccs.global_fire_at_will) if ccs != null else true

	var sq_row := HBoxContainer.new()
	sq_row.add_theme_constant_override("separation", 8)
	wvb.add_child(sq_row)
	for sq in Options.SQUAD_CLASS_SPECS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(sq["full"])
		var sid: int = int(sq["id"])
		btn.modulate = Color(1.0, 0.88, 0.40) if sid == sel_cls else Color.WHITE
		btn.pressed.connect(func():
			if GameState.combat_command_system != null:
				GameState.combat_command_system.select_squad(sid)
		)
		tag(btn, "squad:%d" % sid)
		sq_row.add_child(btn)

	var ord_row := HBoxContainer.new()
	ord_row.add_theme_constant_override("separation", 8)
	wvb.add_child(ord_row)
	for o in Options.TACTICAL_ORDER_SPECS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = str(o["full"])
		var oid: int = int(o["id"])
		btn.modulate = Color(0.55, 0.95, 0.65) if oid == cur_ord else Color.WHITE
		btn.pressed.connect(func():
			if GameState.combat_command_system != null:
				GameState.combat_command_system.issue_player_order(oid)
		)
		tag(btn, "order:%d" % oid)
		ord_row.add_child(btn)

	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 8)
	wvb.add_child(st_row)

	var faw_btn := Button.new()
	faw_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faw_btn.text = "Archers: Fire at Will" if is_faw else "Archers: Hold Fire"
	faw_btn.modulate = Color(0.75, 0.95, 0.75) if is_faw else Color(0.95, 0.75, 0.55)
	faw_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.toggle_fire_at_will()
	)
	tag(faw_btn, "fire")
	st_row.add_child(faw_btn)

	var horn_btn := Button.new()
	horn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horn_btn.text = "Tribal Warhorn: ON (Militia Raised)" if GameState.warhorn_active else "Tribal Warhorn: OFF ([H])"
	horn_btn.modulate = Color(1.0, 0.52, 0.42) if GameState.warhorn_active else Color.WHITE
	horn_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.toggle_warhorn()
	)
	tag(horn_btn, "warhorn")
	st_row.add_child(horn_btn)
