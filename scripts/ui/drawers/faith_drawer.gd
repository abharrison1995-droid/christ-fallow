extends "res://scripts/ui/drawers/feature_drawer.gd"

func _init() -> void:
	title = "Faith"


func build_content() -> void:
	var f0: Dictionary = GameState.factions[0]
	var patron: int = int(f0.get("patron_god", GameData.PatronGod.NONE))
	var tenets: Array = f0.get("tenets", [])
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	self.add_child(columns)
	var gods := VBoxContainer.new()
	gods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(gods)
	gods.add_child(Look.label("Patron god", &"SectionTitle"))
	for id in GameData.GOD_DATA:
		if id == GameData.PatronGod.NONE:
			continue
		var gid: int = id
		var data: Dictionary = GameData.GOD_DATA[gid]
		var card := _faith_card(gods, "%s  ·  %s" % [data["name"], data["title"]],
			"%s   /   Q %s" % [data["buff_summary"], data["blessing_name"]], patron == gid)
		var choose := Look.button("Worshipped" if patron == gid else "Worship", func():
			GameState.select_player_patron(gid)
			refresh()
		)
		choose.disabled = patron == gid
		tag(choose, "patron:%d" % gid)
		card.add_child(choose)
	var beliefs := VBoxContainer.new()
	beliefs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(beliefs)
	beliefs.add_child(Look.label("Tenets   %d / 2" % tenets.size(), &"SectionTitle"))
	for key in GameData.TENET_DATA:
		var tenet: String = key
		var data: Dictionary = GameData.TENET_DATA[tenet]
		var adopted := tenets.has(tenet)
		var opposed := tenets.has(data["opposing"])
		var card := _faith_card(beliefs, data["name"], data["desc"], adopted)
		var caption := "Remove" if adopted else ("Opposed" if opposed else "Adopt")
		var action := Look.button(caption, func():
			GameState.set_player_tenet(tenet, not adopted)
			refresh()
		)
		action.disabled = opposed or (not adopted and tenets.size() >= 2)
		tag(action, "tenet:" + tenet)
		card.add_child(action)


func _faith_card(parent: Control, title: String, summary: String, selected: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	_card(parent, Look.GOLD if selected else Look.EDGE).add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	row.add_child(details)
	details.add_child(Look.label(title, &"SectionTitle", 17))
	var note := Look.label(summary, &"QuietLabel", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(note)
	return row
