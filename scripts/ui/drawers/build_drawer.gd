extends "res://scripts/ui/drawers/feature_drawer.gd"

const Preview = preload("res://scripts/ui/mesh_preview.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")

const BUILD_GROUPS := {
	"Settlement": ["CAMPFIRE", "SLEEPING_HUT", "FORAGER_LODGE", "STORAGE_PIT", "CROP_FIELD", "ANIMAL_PEN"],
	"Craft & faith": ["CRAFTING_PIT", "WEAPON_RACK", "SACRED_TOTEM", "SHAMAN_SHACK"],
	"Defences": ["PALISADE_WALL", "STANDING_STONE_GATE", "WATCHTOWER", "BARRACKS"],
}

var _selected_building := "CAMPFIRE"
var _user_picked_step: int = -1
var _recommended_building := ""
var _recommended_badge: Label = null
var _refresh_requirements: Callable


func get_selected_building() -> String:
	return _selected_building


func get_recommended_building() -> String:
	return _recommended_building


func _init() -> void:
	title = "Build"


func build_content() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	self.add_child(row)

	var catalogue := ScrollContainer.new()
	catalogue.custom_minimum_size = Vector2(282, 270)
	catalogue.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalogue.follow_focus = true
	row.add_child(catalogue)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	catalogue.add_child(list)
	var target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	var active_step: int = int(target.get("step", 0))
	var rec_key: String = str(target.get("highlight_building", "")) if bool(target.get("active", false)) else ""
	_recommended_building = rec_key
	if not rec_key.is_empty() and GameData.BUILDINGS.has(rec_key) and _user_picked_step != active_step:
		_selected_building = rec_key

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	_card(row).add_child(detail)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	detail.add_child(title_row)
	var name_label := Look.label("", &"SectionTitle")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	_recommended_badge = Look.label("RECOMMENDED", &"QuietLabel", 13)
	_recommended_badge.add_theme_color_override("font_color", Look.GOLD)
	_recommended_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_recommended_badge)

	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", Look.panel(Color("181f1a"), Look.EDGE, 0))
	detail.add_child(preview_panel)
	var preview := Preview.new()
	preview.custom_minimum_size.y = 124
	preview_panel.add_child(preview)

	var description := Look.label("", &"QuietLabel")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(description)
	var price := Look.label("")
	detail.add_child(price)
	var place := Look.button("", func():
		close_requested.emit()
		if is_instance_valid(GameState.player_controller):
			GameState.player_controller.enter_build_mode(_selected_building)
	, &"PrimaryButton")
	tag(place, "place")
	detail.add_child(place)

	_refresh_requirements = func():
		var key: String = _selected_building
		var info: Dictionary = GameData.BUILDINGS[key]
		var founded: bool = GameState.factions[0]["is_founded"]
		var can_buy := GameState.can_afford(0, info["costs"], true)
		var locked := not founded and key != "CAMPFIRE"
		var discount: float = 0.8 if GameState.has_tenet(0, "ANCESTRAL_STONE") else 1.0
		var materials := PackedStringArray()
		var costs: Dictionary = info["costs"]
		for resource in costs:
			var amt: float = float(costs[resource])
			if resource == "wood" or resource == "stone":
				amt = ceilf(amt * discount)
			materials.append("%d %s" % [int(amt), str(resource).capitalize()])
		var hp_mult: float = 1.25 if int(GameState.factions[0].get("patron_god", GameData.PatronGod.NONE)) == GameData.PatronGod.KRAG_UL else 1.0
		var effective_hp: int = roundi(float(info["max_hp"]) * hp_mult)
		price.text = "   ·   ".join(materials) + "     /     %d HP" % effective_hp
		price.modulate = Look.BONE if can_buy else Look.DANGER
		place.disabled = locked or not can_buy
		if locked:
			place.text = "Requires a Campfire"
		elif not can_buy:
			place.text = "Insufficient Resources"
		elif not founded and key == "CAMPFIRE":
			place.text = "Place Campfire"
		else:
			place.text = "Place Blueprint"

	var options: Dictionary = {}
	var select_building := func(key: String, by_user: bool = false):
		_selected_building = key
		if by_user and active_step > 0:
			_user_picked_step = active_step
		for id in options:
			(options[id] as Button).set_pressed_no_signal(key == id)
		var info: Dictionary = GameData.BUILDINGS[key]
		name_label.text = info["name"]
		if _recommended_badge != null:
			_recommended_badge.visible = (not _recommended_building.is_empty() and key == _recommended_building)
		description.text = info["desc"]
		var model := _build_preview_model(key)
		preview.show_model(model, Vector3(4.2, 3.6, 5.5), 0.98)
		_refresh_requirements.call()

	var rec_style: StyleBoxFlat = null
	if not rec_key.is_empty():
		rec_style = Look.panel(Color("2e2a1e"), Look.GOLD, 6, 4)
		rec_style.set_border_width_all(2)
		rec_style.content_margin_left = 11
		rec_style.content_margin_right = 11

	for group in BUILD_GROUPS:
		list.add_child(Look.label(group, &"SectionTitle", 18))
		for key in BUILD_GROUPS[group]:
			var is_rec: bool = (not rec_key.is_empty() and key == rec_key)
			var caption: String = "%s  [RECOMMENDED]" % GameData.BUILDINGS[key]["name"] if is_rec else str(GameData.BUILDINGS[key]["name"])
			var button := Look.button(caption, select_building.bind(key, true))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.toggle_mode = true
			if is_rec and rec_style != null:
				button.add_theme_stylebox_override("normal", rec_style)
				button.add_theme_color_override("font_color", Look.GOLD)
			tag(button, key)
			options[key] = button
			list.add_child(button)
	select_building.call(_selected_building, false)


func update_live_values() -> void:
	var target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	var next_rec: String = str(target.get("highlight_building", "")) if bool(target.get("active", false)) else ""
	if next_rec != _recommended_building:
		refresh()
		return
	if _refresh_requirements.is_valid():
		_refresh_requirements.call()


func _build_preview_model(key: String) -> Node3D:
	var model: Node3D = MeshFactory.build_building_stages(key, Look.GOLD, false)
	if model != null:
		var intact: Node3D = model.get_node_or_null("Stage_Intact") as Node3D
		if intact != null:
			intact.visible = true
			for stage_name in ["Stage_Damaged", "Stage_Critical", "Stage_Rubble"]:
				var stage: Node3D = model.get_node_or_null(stage_name) as Node3D
				if stage != null:
					stage.visible = false
			return model
		model.free()
	return MeshFactory.build_building_mesh(key, Look.GOLD, false)
