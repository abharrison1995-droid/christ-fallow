extends RefCounted
## HUD panel construction, alignment, and live status refresh helpers for HUDController.

const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const PerkSystem = preload("res://scripts/core/perk_system.gd")
const HUDDrawers = preload("res://scripts/ui/hud_drawers.gd")
const Look = preload("res://scripts/ui/fallow_theme.gd")
const MinimapWidget = preload("res://scripts/ui/minimap_widget.gd")

const DRAWER_LINKS := [
	["Build", "B", "BUILD"], ["Colony", "C", "COLONY"], ["Perks", "K", "PERKS"],
	["Faith", "R", "RELIGION"], ["Diplomacy", "V", "DIPLOMACY"], ["Command", "Tab", "MENU"],
]


static func make_panel_style(bg: Color = Color(0.08, 0.10, 0.086, 0.96), border: Color = Look.EDGE) -> StyleBoxFlat:
	return Look.panel(bg, border, 14)


static func align_upper_hud(hud: Control) -> void:
	var vp_size: Vector2 = hud.size if (hud.size.x > 0.0 and hud.size.y > 0.0) else hud.get_viewport_rect().size
	var objective_top: float = (hud._top_bar as Control).get_rect().end.y + 6.0
	var objective_height: float = maxf(38.0, (hud._objective_panel as Control).get_combined_minimum_size().y)
	var below_objectives: float = objective_top + objective_height + 10.0
	hud._objective_panel.offset_top = objective_top
	hud._objective_panel.offset_bottom = objective_top + objective_height
	hud._tutorial_panel.offset_top = below_objectives
	hud._tutorial_panel.offset_bottom = below_objectives + 132.0
	var build_banner_height: float = maxf(47.0, (hud._build_banner as Control).get_combined_minimum_size().y)
	hud._build_banner.offset_top = below_objectives
	hud._build_banner.offset_bottom = below_objectives + build_banner_height
	var raid_top: float = below_objectives + build_banner_height + 10.0
	hud._raid_panel.offset_top = raid_top
	hud._raid_panel.offset_bottom = raid_top

	var minimap_left: float = minf(hud._minimap_panel.position.x, vp_size.x - 232.0) if hud._minimap_panel.size.x > 0.0 else (vp_size.x - 232.0)
	var margin_x := 20.0
	var right_limit: float = minimap_left - 12.0
	var max_width: float = maxf(320.0, right_limit - margin_x)
	var drawer_w: float = minf(1082.0, max_width)
	var drawer_left: float = clampf((vp_size.x - drawer_w) * 0.5, margin_x, maxf(margin_x, right_limit - drawer_w))
	var squad_top: float = minf(hud._squad_bar.position.y, vp_size.y - 158.0) if hud._squad_bar.size.y > 0.0 else (vp_size.y - 158.0)
	var drawer_bottom: float = minf(vp_size.y * 0.82, squad_top - 6.0)
	drawer_bottom = maxf(drawer_bottom, below_objectives + 120.0)
	hud._drawer_panel.offset_left = drawer_left
	hud._drawer_panel.offset_right = drawer_left + drawer_w
	hud._drawer_panel.offset_top = below_objectives
	hud._drawer_panel.offset_bottom = drawer_bottom


static func set_hud_visible(hud: Control, vis: bool) -> void:
	hud._top_bar.visible = vis
	hud._objective_panel.visible = vis
	hud._tutorial_panel.visible = vis and not GameState.tutorial_completed and not GameState.tutorial_skipped
	hud._minimap_panel.visible = vis
	hud._event_panel.visible = vis
	hud._squad_bar.visible = vis
	if not vis:
		hud._world_map.close()
		hud._build_banner.hide()
		hud._inspector_panel.close()
		hud._raid_panel.hide()
		clear_hud_highlight(hud)


static func build_top_bar(hud: Control) -> void:
	hud._top_bar = PanelContainer.new()
	hud._top_bar.add_theme_stylebox_override("panel", make_panel_style())
	hud._top_bar.anchor_right = 1.0
	hud._top_bar.offset_left = 20.0
	hud._top_bar.offset_top = 18.0
	hud._top_bar.offset_right = -252.0
	hud.add_child(hud._top_bar)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	hud._top_bar.add_child(stack)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 18)
	stack.add_child(summary)
	hud._clock_label = Look.label("", &"SectionTitle", 19)
	summary.add_child(hud._clock_label)
	hud._pop_label = Look.label("", &"QuietLabel", 14)
	hud._pop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._pop_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(hud._pop_label)
	hud._pause_btn = Look.button("Pause  P", hud._overlays.toggle_pause)
	summary.add_child(hud._pause_btn)

	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 8)
	stack.add_child(resources)
	for key in ["food", "wood", "stone", "flint", "hide", "bone", "faith"]:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", Look.panel(Look.SURFACE, Look.EDGE, 5, 4))
		resources.add_child(tile)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(row)
		row.add_child(Look.label(str(key).capitalize(), &"QuietLabel", 13))
		var amount: Label = Look.label("0", &"SectionTitle", 18)
		row.add_child(amount)
		hud._resource_values[key] = amount

	var navigation := HBoxContainer.new()
	stack.add_child(navigation)
	for item in DRAWER_LINKS:
		var tab: String = str(item[2])
		var button: Button = Look.button("%s  %s" % [item[0], item[1]], func(): hud.toggle_drawer(tab))
		button.toggle_mode = true
		navigation.add_child(button)
		hud._drawer_links[tab] = button
	hud._stock_label = Look.label("", &"QuietLabel", 13)
	hud._stock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._stock_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	navigation.add_child(hud._stock_label)

	hud._objective_panel = PanelContainer.new()
	hud._objective_panel.add_theme_stylebox_override("panel", Look.panel(Color(0.09, 0.115, 0.095, 0.93), Look.EDGE, 9))
	hud._objective_panel.anchor_right = 1.0
	hud._objective_panel.offset_left = 20
	hud._objective_panel.offset_top = 157
	hud._objective_panel.offset_right = -252
	hud.add_child(hud._objective_panel)
	var objectives := HBoxContainer.new()
	hud._objective_panel.add_child(objectives)
	hud._objective_label = Look.label("", &"QuietLabel", 14)
	hud._objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objectives.add_child(hud._objective_label)
	hud._grace_label = Look.label("", &"SectionTitle", 15)
	objectives.add_child(hud._grace_label)


static func build_tutorial_panel(hud: Control) -> void:
	hud._tutorial_panel = PanelContainer.new()
	hud._tutorial_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.09, 0.115, 0.09, 0.96), Color("687454")))
	hud._tutorial_panel.anchor_left = 0.0
	hud._tutorial_panel.anchor_right = 0.0
	hud._tutorial_panel.anchor_top = 0.0
	hud._tutorial_panel.anchor_bottom = 0.0
	hud._tutorial_panel.offset_left = 20.0
	hud._tutorial_panel.offset_top = 205.0
	hud._tutorial_panel.offset_right = 371.0
	hud._tutorial_panel.offset_bottom = 332.0
	hud.add_child(hud._tutorial_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	hud._tutorial_panel.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)

	hud._tutorial_title = Look.label("", &"SectionTitle", 18)
	hud._tutorial_title.text = "Awakening Guide (Step 1/5)"
	hud._tutorial_title.add_theme_color_override("font_color", Look.MOSS)
	hud._tutorial_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hud._tutorial_title)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.tooltip_text = "Hide guide (your early Peace Buffer before bandit attacks remains active)"
	skip_btn.pressed.connect(func():
		skip_btn.release_focus()
		hud._on_skip_tutorial_pressed()
	)
	hdr.add_child(skip_btn)

	hud._tutorial_body = Label.new()
	hud._tutorial_body.text = "Walk near 3 wandering locals and press [E] to recruit them into your tribe."
	hud._tutorial_body.add_theme_font_size_override("font_size", 13)
	hud._tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud._tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hud._tutorial_body)

	hud._tutorial_progress = Label.new()
	hud._tutorial_progress.text = "[ ] Recruit tribesfolk (0/3)"
	hud._tutorial_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._tutorial_progress.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	hud._tutorial_progress.add_theme_font_size_override("font_size", 12)
	vb.add_child(hud._tutorial_progress)


static func build_mode_banner(hud: Control) -> void:
	hud._build_banner = PanelContainer.new()
	hud._build_banner.add_theme_stylebox_override("panel", make_panel_style(Look.SURFACE, Look.GOLD))
	hud._build_banner.anchor_left = 0.5
	hud._build_banner.anchor_right = 0.5
	hud._build_banner.anchor_top = 0.0
	hud._build_banner.anchor_bottom = 0.0
	hud._build_banner.offset_left = -310.0
	hud._build_banner.offset_right = 310.0
	hud._build_banner.offset_top = 204.0
	hud._build_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._build_banner.visible = false
	hud.add_child(hud._build_banner)

	hud._build_banner_label = Label.new()
	hud._build_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._build_banner_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	hud._build_banner_label.add_theme_font_size_override("font_size", 13)
	hud._build_banner.add_child(hud._build_banner_label)


static func sync_build_banner(hud: Control) -> void:
	if hud._build_banner == null:
		return
	var pc: Node = GameState.player_controller
	var active: bool = pc != null and pc.is_build_mode
	hud._build_banner.visible = active
	if active and hud._build_banner_label != null:
		var bp_type: String = str(pc.blueprint_type)
		var info: Dictionary = GameData.BUILDINGS.get(bp_type, {})
		var b_name: String = str(info.get("name", bp_type))
		var warning: String = pc.blueprint_placement_message()
		var next_text := "%s   ·   LMB Place   T Rotate   Esc / RMB Cancel" % b_name
		if not warning.is_empty():
			next_text += "\n" + warning
		var changed: bool = hud._build_banner_label.text != next_text
		hud._build_banner_label.text = next_text
		hud._build_banner_label.modulate = Look.BONE if warning.is_empty() else Look.DANGER
		if changed:
			hud._align_upper_hud()


static func build_minimap(hud: Control) -> void:
	hud._minimap_panel = PanelContainer.new()
	hud._minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud._minimap_panel.offset_left = -232
	hud._minimap_panel.offset_right = -20
	hud._minimap_panel.offset_top = 18
	hud._minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._minimap_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hud._minimap_panel.tooltip_text = "Open World Map [M]"
	hud._minimap_panel.gui_input.connect(hud._on_radar_input)
	hud._minimap_panel.add_theme_stylebox_override("panel", Look.panel(Look.INK, Look.EDGE, 10))
	hud.add_child(hud._minimap_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._minimap_panel.add_child(stack)
	stack.add_child(Look.label("Valley Radar  [M]", &"SectionTitle", 19))
	var minimap := Control.new()
	minimap.set_script(MinimapWidget)
	minimap.custom_minimum_size = Vector2(190, 173)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(minimap)


static func build_log_panel(hud: Control) -> void:
	hud._event_panel = PanelContainer.new()
	hud._event_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud._event_panel.offset_left = 20
	hud._event_panel.offset_right = 308
	hud._event_panel.offset_top = -111
	hud._event_panel.offset_bottom = -18
	hud.add_child(hud._event_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	hud._event_panel.add_child(stack)
	hud._event_toggle = Look.button("Event Log  +", hud._toggle_event_log)
	hud._event_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(hud._event_toggle)
	hud._latest_event = Look.label("", &"QuietLabel", 13)
	hud._latest_event.custom_minimum_size.y = 23
	hud._latest_event.mouse_filter = Control.MOUSE_FILTER_PASS
	hud._latest_event.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(hud._latest_event)
	hud._log_box = RichTextLabel.new()
	hud._log_box.add_theme_font_size_override("normal_font_size", 14)
	hud._log_box.scroll_following = true
	hud._log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud._log_box.hide()
	stack.add_child(hud._log_box)


static func build_squad_bar(hud: Control) -> void:
	hud._squad_bar = PanelContainer.new()
	hud._squad_bar.add_theme_stylebox_override("panel", make_panel_style())
	hud._squad_bar.anchor_left = 0.5
	hud._squad_bar.anchor_right = 0.5
	hud._squad_bar.anchor_top = 1.0
	hud._squad_bar.anchor_bottom = 1.0
	hud._squad_bar.offset_left = -350.0
	hud._squad_bar.offset_top = -158.0
	hud._squad_bar.offset_right = 350.0
	hud._squad_bar.offset_bottom = -18.0
	hud.add_child(hud._squad_bar)

	var vb := VBoxContainer.new()
	hud._squad_bar.add_child(vb)

	var top_r := HBoxContainer.new()
	top_r.add_theme_constant_override("separation", 12)
	vb.add_child(top_r)

	hud._leader_hp_label = Look.label("Leader", &"SectionTitle", 19)
	top_r.add_child(hud._leader_hp_label)

	hud._leader_hp_bar = ProgressBar.new()
	hud._leader_hp_bar.custom_minimum_size = Vector2(126, 8)
	hud._leader_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud._leader_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._leader_hp_bar.show_percentage = false
	hud._leader_hp_bar.max_value = 100.0
	hud._leader_hp_bar.value = 100.0
	top_r.add_child(hud._leader_hp_bar)

	hud._blessing_label = Label.new()
	hud._blessing_label.text = "[Q] Blessing Ready"
	hud._blessing_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.38))
	top_r.add_child(hud._blessing_label)

	hud._pov_btn = Button.new()
	hud._pov_btn.text = "POV: 3rd  Z"
	hud._pov_btn.toggle_mode = true
	hud._pov_btn.tooltip_text = "Toggle First-Person POV [Z]. Scroll up at close zoom to enter, down to exit."
	hud._pov_btn.pressed.connect(func():
		if is_instance_valid(GameState.player_controller) and GameState.player_controller.has_method("toggle_first_person"):
			GameState.player_controller.toggle_first_person()
		hud._pov_btn.release_focus()
	)
	top_r.add_child(hud._pov_btn)

	var sq_r := HBoxContainer.new()
	sq_r.add_theme_constant_override("separation", 6)
	vb.add_child(sq_r)

	for s in HUDDrawers.SQUAD_CLASS_SPECS:
		var btn := Button.new()
		btn.text = str(s["short"])
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sid: int = int(s["id"])
		btn.pressed.connect(func():
			if GameState.combat_command_system != null:
				GameState.combat_command_system.select_squad(sid)
			btn.release_focus()
		)
		sq_r.add_child(btn)
		hud._squad_btns[sid] = btn

	var ord_r := HBoxContainer.new()
	ord_r.add_theme_constant_override("separation", 6)
	vb.add_child(ord_r)

	for o in HUDDrawers.TACTICAL_ORDER_SPECS:
		var btn := Button.new()
		btn.text = str(o["short"])
		btn.toggle_mode = true
		btn.tooltip_text = str(o["full"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var oid: int = int(o["id"])
		btn.pressed.connect(func():
			if GameState.combat_command_system != null:
				GameState.combat_command_system.issue_player_order(oid)
			btn.release_focus()
		)
		ord_r.add_child(btn)
		hud._order_btns[oid] = btn

	hud._fire_btn = Button.new()
	hud._fire_btn.text = "Fire  F5"
	hud._fire_btn.toggle_mode = true
	hud._fire_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.toggle_fire_at_will()
		hud._fire_btn.release_focus()
	)
	ord_r.add_child(hud._fire_btn)

	hud._warhorn_btn = Button.new()
	hud._warhorn_btn.text = "Warhorn  H"
	hud._warhorn_btn.toggle_mode = true
	hud._warhorn_btn.pressed.connect(func():
		if GameState.combat_command_system != null:
			GameState.combat_command_system.toggle_warhorn()
		hud._warhorn_btn.release_focus()
	)
	ord_r.add_child(hud._warhorn_btn)


static func build_drawer_panel(hud: Control) -> void:
	hud._drawer_panel = PanelContainer.new()
	hud._drawer_panel.hide()
	hud._drawer_panel.add_theme_stylebox_override("panel", Look.panel(Look.INK, Look.GOLD, 16))
	hud._drawer_panel.anchor_left = 0.0
	hud._drawer_panel.anchor_right = 0.0
	hud._drawer_panel.anchor_top = 0.0
	hud._drawer_panel.anchor_bottom = 0.0
	hud._drawer_panel.offset_left = 20.0
	hud._drawer_panel.offset_top = 215.0
	hud._drawer_panel.offset_right = 1102.0
	hud._drawer_panel.offset_bottom = 650.0
	hud.add_child(hud._drawer_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	hud._drawer_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	hud._drawer_title = Look.label("", &"DisplayTitle", 33)
	hud._drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hud._drawer_title)
	hud._drawer_close = Look.button("Close  Esc", hud.close_drawer)
	hud._drawer_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(hud._drawer_close)
	stack.add_child(HSeparator.new())
	hud._drawer_scroll = ScrollContainer.new()
	hud._drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud._drawer_scroll.follow_focus = true
	hud._drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(hud._drawer_scroll)
	hud._drawer_content = VBoxContainer.new()
	hud._drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._drawer_content.add_theme_constant_override("separation", 12)
	hud._drawer_scroll.add_child(hud._drawer_content)


static func build_raid_panel(hud: Control) -> void:
	hud._raid_panel = PanelContainer.new()
	hud._raid_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud._raid_panel.offset_left = -255
	hud._raid_panel.offset_right = 255
	hud._raid_panel.offset_top = 268
	hud._raid_panel.add_theme_stylebox_override("panel", Look.panel(Color("432721"), Look.DANGER, 12))
	hud._raid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._raid_panel.hide()
	hud.add_child(hud._raid_panel)
	var alert := VBoxContainer.new()
	alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._raid_panel.add_child(alert)
	var title: Label = Look.label("Raid incoming", &"SectionTitle", 21)
	title.modulate = Look.DANGER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.add_child(title)
	hud._raid_banner = Look.label("")
	hud._raid_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._raid_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert.add_child(hud._raid_banner)


static func build_fp_reticle(hud: Control) -> void:
	var reticle := Control.new()
	reticle.name = "FirstPersonReticle"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.custom_minimum_size = Vector2(24, 24)
	reticle.offset_left = -12.0
	reticle.offset_top = -12.0
	reticle.offset_right = 12.0
	reticle.offset_bottom = 12.0
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.visible = false
	hud.add_child(reticle)

	var dot := ColorRect.new()
	dot.position = Vector2(11, 11)
	dot.size = Vector2(2, 2)
	dot.color = Look.GOLD
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.add_child(dot)

	for r: Array in [[Vector2(11, 3), Vector2(2, 5)], [Vector2(11, 16), Vector2(2, 5)], [Vector2(3, 11), Vector2(5, 2)], [Vector2(16, 11), Vector2(5, 2)]]:
		var tick := ColorRect.new()
		tick.position = r[0]
		tick.size = r[1]
		tick.color = Color(0.95, 0.90, 0.72, 0.85)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle.add_child(tick)

	hud._fp_reticle = reticle


static func sync_pov_state(hud: Control, can_toggle: bool) -> void:
	var pc: Node = GameState.player_controller
	var fp: bool = is_instance_valid(pc) and pc.get("is_first_person") == true
	if hud._pov_btn != null:
		hud._pov_btn.text = "POV: 1st  Z" if fp else "POV: 3rd  Z"
		hud._pov_btn.set_pressed_no_signal(fp)
		hud._pov_btn.disabled = not can_toggle
	if hud._fp_reticle != null:
		hud._fp_reticle.visible = fp and can_toggle and hud._top_bar.visible and not hud._inspector_panel.visible


static func update_top_bar(hud: Control) -> void:
	if not GameState.factions.has(0):
		return
	var f0: Dictionary = GameState.factions[0]
	var res: Dictionary = f0["resources"]
	var stock: Dictionary = f0["stockpile"]

	update_clock(hud)
	var units: Array = GameState.get_faction_units(0, true)
	var lvl: int = PerkSystem.get_level(f0)
	var xp: float = PerkSystem.get_xp(f0)
	var req_xp: float = PerkSystem.xp_for_next_level(lvl)
	var sp: int = PerkSystem.get_skill_points(f0)
	var xp_str := "MAX" if lvl >= PerkSystem.MAX_LEVEL else "%d/%d XP" % [int(xp), int(req_xp)]
	hud._pop_label.text = "Lv.%d (%s)  ·  Pop %d/%d  ·  Morale %d%%  ·  Captives %d" % [
		lvl, xp_str, units.size(), GameState.get_housing_capacity(0), int(GameState.get_average_morale(0)), int(f0.get("captured_cavemen", 0)),
	]
	if hud._drawer_links.has("PERKS"):
		(hud._drawer_links["PERKS"] as Button).text = ("Perks (+%d)  K" % sp) if sp > 0 else "Perks  K"
	for key in hud._resource_values:
		(hud._resource_values[key] as Label).text = str(int(res[key]))

	hud._stock_label.text = "Tier %d | Spears:%d Knives:%d Bows:%d Clubs:%d Javs:%d Armor:%d" % [
		int(f0.get("tech_tier", 1)), int(stock.get("spears", 0)), int(stock.get("knives", 0)), int(stock.get("bows", 0)), int(stock.get("clubs", 0)), int(stock.get("javelins", 0)), int(stock.get("armor", 0))
	]
	update_objective_banner(hud, f0)


static func update_clock(hud: Control) -> void:
	var hour := int(GameState.time_of_day)
	var minute := int((GameState.time_of_day - float(hour)) * 60.0)
	var phase := "Daylight"
	if GameState.current_phase == GameData.SchedulePhase.DUSK_HEARTH:
		phase = "Dusk"
	elif GameState.current_phase == GameData.SchedulePhase.NIGHT_SLEEP:
		phase = "Night"
	hud._clock_label.text = "Day %d   ·   %02d:%02d   ·   %s" % [GameState.day_count, hour, minute, phase]


static func update_objective_banner(hud: Control, f0: Dictionary) -> void:
	if hud._grace_label != null:
		if GameState.is_raid_grace_active():
			var rem: int = ceili(GameState.bandit_grace_remaining)
			var mins: int = rem / 60
			var secs: int = rem % 60
			hud._grace_label.text = "Peace Buffer: %d:%02d" % [mins, secs]
			hud._grace_label.add_theme_color_override("font_color", Color(0.49, 0.88, 0.96) if rem > 30 else Color(1.0, 0.72, 0.35))
		else:
			hud._grace_label.text = "Raiders Active"
			hud._grace_label.add_theme_color_override("font_color", Color(0.98, 0.48, 0.40))

	if hud._objective_label == null:
		return
	var wild_left: int = GameState.get_faction_units(-1, true).size()
	if f0.get("is_founded") != true:
		if wild_left > 0:
			hud._objective_label.text = "Objective: Recruit wanderers (%d left, [E]) & press [B] Build to light Campfire." % wild_left
		else:
			hud._objective_label.text = "Objective: Press [B] Build to place your Tribal Campfire."
	elif not GameState.has_building(0, "SACRED_TOTEM", true) or not GameState.has_building(0, "CRAFTING_PIT", true):
		hud._objective_label.text = "Objective: Press [B] Build for Sacred Totem & Crafting Pit, and assign workers in [C] Colony."
	elif int(f0.get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.NONE:
		hud._objective_label.text = "Objective: Press [R] Faith & Religion to choose your Patron God & Tenets."
	else:
		var united := 0
		for fid in range(1, 5):
			if GameState.factions.has(fid):
				if GameState.factions[fid].get("is_defeated") == true or GameState.is_treaty_ally(0, fid):
					united += 1
		hud._objective_label.text = "Objective: Unite the Valley (%d/4 Rival Tribes Allied or Conquered) — [V] Diplomacy." % united


static func clear_hud_highlight(hud: Control) -> void:
	hud._highlighted_hud_tab = ""
	for btn in hud._drawer_links.values():
		var button: Button = btn as Button
		if button != null:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_color_override("font_color")


static func sync_tutorial_highlights(hud: Control) -> void:
	var target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	var next_tab: String = str(target.get("highlight_hud", "")) if target.get("active") == true else ""
	if next_tab == hud._highlighted_hud_tab:
		return
	hud._highlighted_hud_tab = next_tab
	if hud._highlighted_hud_tab.is_empty():
		clear_hud_highlight(hud)
		return
	for key in hud._drawer_links.keys():
		var button: Button = hud._drawer_links[key] as Button
		if button == null:
			continue
		if str(key) == hud._highlighted_hud_tab:
			if hud._highlight_style == null:
				hud._highlight_style = Look.panel(Color("3d3320"), Look.GOLD, 6, 4)
				hud._highlight_style.set_border_width_all(2)
				hud._highlight_style.content_margin_left = 11
				hud._highlight_style.content_margin_right = 11
			button.add_theme_stylebox_override("normal", hud._highlight_style)
			button.add_theme_color_override("font_color", Look.GOLD)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_color_override("font_color")


static func update_tutorial_and_banners(hud: Control) -> void:
	sync_build_banner(hud)
	sync_tutorial_highlights(hud)
	if hud._tutorial_panel == null or not GameState.factions.has(0):
		return
	if GameState.tutorial_completed or GameState.tutorial_skipped:
		hud._tutorial_panel.visible = false
		return

	hud._tutorial_panel.visible = true
	var cur: int = GameState.tutorial_step
	var target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	var live_hint: String = str(target.get("hint", ""))
	hud._tutorial_title.text = "Awakening Guide (Step %d/5)" % cur
	if cur == 1:
		var rec: int = mini(AwakeningGuide.recruit_count(GameState), 3)
		hud._tutorial_body.text = live_hint if not live_hint.is_empty() else "Follow the golden beacon to wandering locals and press [E] to recruit 3 into your tribe."
		hud._tutorial_progress.text = "[%s] Recruit tribesfolk (%d/3)" % ["x" if rec >= 3 else " ", rec]
	elif cur == 2:
		var founded: bool = GameState.factions[0].get("is_founded") == true
		hud._tutorial_body.text = live_hint if not live_hint.is_empty() else "Open [B] Build, select Tribal Campfire, then [LMB] click clear ground to light it."
		hud._tutorial_progress.text = "[%s] Open [B] Build & light Tribal Campfire" % ("x" if founded else " ")
	elif cur == 3:
		hud._tutorial_body.text = live_hint if not live_hint.is_empty() else "Press [E] near a marked resource node to gather, and assign a villager role in [C] Colony."
		hud._tutorial_progress.text = "%s Harvest resource ([E])\n%s Assign villager role ([C] Colony)" % [
			"[x]" if GameState.tutorial_harvested else "[ ]",
			"[x]" if GameState.tutorial_assigned_role else "[ ]",
		]
	elif cur == 4:
		var has_hut_bp: bool = not GameState.get_faction_buildings(0, "SLEEPING_HUT", false).is_empty()
		var has_hut_done: bool = not GameState.get_faction_buildings(0, "SLEEPING_HUT", true).is_empty()
		if not live_hint.is_empty():
			hud._tutorial_body.text = live_hint
		elif has_hut_bp and not has_hut_done:
			hud._tutorial_body.text = "Walk to your Sleeping Hut blueprint and press [E] to help finish building it."
		else:
			hud._tutorial_body.text = "Open [B] Build to place a Sleeping Hut, then press [E] near it to help build."
		hud._tutorial_progress.text = "%s Place Sleeping Hut ([B] Build)\n%s Finish Sleeping Hut ([E] to help)" % [
			"[x]" if (has_hut_bp or has_hut_done) else "[ ]",
			"[x]" if has_hut_done else "[ ]",
		]
	else:
		hud._tutorial_body.text = live_hint if not live_hint.is_empty() else "Practice your Leader attacks: [LMB] Heavy Cleave and [F] or [RMB] Throw Javelin."
		hud._tutorial_progress.text = "%s Heavy Cleave ([LMB])\n%s Throw Javelin ([F] / [RMB])" % [
			"[x]" if GameState.tutorial_cleaved else "[ ]",
			"[x]" if GameState.tutorial_thrown else "[ ]",
		]


static func sync_leader_action_hint(hud: Control) -> void:
	var pc: Node = GameState.player_controller
	if not is_instance_valid(pc):
		return
	var mount_name: String = pc.get_mount_name()
	if not mount_name.is_empty():
		hud._blessing_label.text = "%s  ·  [E] Dismount" % mount_name
		return
	if is_instance_valid(pc.leader_unit) and pc.leader_unit.is_out_of_commission():
		hud._blessing_label.text = "[Out of Commission · %ds]" % ceili(pc.leader_unit.arena_recovery_remaining)
		return
	var cooldown: float = pc._blessing_cd
	hud._blessing_label.text = "[Q] Blessing Ready" if cooldown <= 0.0 else "[Q] Blessing (%.0fs)" % cooldown


static func update_squad_bar(hud: Control) -> void:
	var leader: Node = GameState.get_faction_leader(0)
	if leader != null:
		hud._leader_hp_label.text = "%s   ·   %d / %d HP" % [leader.unit_name, ceili(leader.hp), ceili(leader.max_hp)]
		hud._leader_hp_bar.max_value = leader.max_hp
		hud._leader_hp_bar.value = leader.hp

	sync_leader_action_hint(hud)

	var all_w := 0
	var sp_w := 0
	var kn_w := 0
	var ar_w := 0
	var br_w := 0
	var jv_w := 0
	for u in GameState.get_faction_units(0, true):
		if not u.is_leader and u.role == GameData.Role.WARRIOR:
			all_w += 1
			if u.warrior_class == GameData.WarriorClass.SPEARMAN:
				sp_w += 1
			elif u.warrior_class == GameData.WarriorClass.KNIFE_RAIDER:
				kn_w += 1
			elif u.warrior_class == GameData.WarriorClass.ARCHER:
				ar_w += 1
			elif u.warrior_class == GameData.WarriorClass.BRUTE:
				br_w += 1
			elif u.warrior_class == GameData.WarriorClass.JAVELINEER:
				jv_w += 1

	(hud._squad_btns[-1] as Button).text = "[1] All (%d)" % all_w
	(hud._squad_btns[GameData.WarriorClass.SPEARMAN] as Button).text = "[2] Spears (%d)" % sp_w
	(hud._squad_btns[GameData.WarriorClass.KNIFE_RAIDER] as Button).text = "[3] Knives (%d)" % kn_w
	(hud._squad_btns[GameData.WarriorClass.ARCHER] as Button).text = "[4] Archers (%d)" % ar_w
	(hud._squad_btns[GameData.WarriorClass.BRUTE] as Button).text = "[5] Brutes (%d)" % br_w
	(hud._squad_btns[GameData.WarriorClass.JAVELINEER] as Button).text = "[6] Javelins (%d)" % jv_w
