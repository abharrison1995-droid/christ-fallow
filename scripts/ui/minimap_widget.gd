extends Control

const Look = preload("res://scripts/ui/fallow_theme.gd")
const AwakeningGuide = preload("res://scripts/core/awakening_guide.gd")
const FACTION_TAGS := {
	0: "YOU",
	1: "GOL",
	2: "SUN",
	3: "FANG",
	4: "EAR",
	6: "REB",
}


var _elapsed: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not GameState.game_active:
		return
	_elapsed += delta
	if _elapsed >= 0.10:
		_elapsed = 0.0
		queue_redraw()


func _to_map(world_pos: Vector3) -> Vector2:
	var extent := GameState.valley_layout.radar_half_extent
	var nx := (world_pos.x + extent) / (extent * 2.0)
	var nz := (world_pos.z + extent) / (extent * 2.0)
	return Vector2(clampf(nx, 0.0, 1.0) * size.x, clampf(nz, 0.0, 1.0) * size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("19221b"))
	for division in range(1, 5):
		var x := size.x * float(division) / 5.0
		var y := size.y * float(division) / 5.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("28342a"))
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("28342a"))
	draw_rect(Rect2(Vector2.ZERO, size), Look.EDGE, false, 1.0)

	var font: Font = get_theme_default_font()

	# Draw River strip hint
	var r1 := _to_map(GameState.valley_layout.river_start())
	var r2 := _to_map(GameState.valley_layout.river_end())
	draw_line(r1, r2, Color("405657"), 5.0, true)
	for ford in GameState.valley_layout.river_crossings():
		var fp := _to_map(ford["pos"])
		draw_rect(Rect2(fp - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), Color("a39a82"), true)
		draw_rect(Rect2(fp - Vector2(3.5, 3.5), Vector2(7.0, 7.0)), Color("4b4638"), false, 1.0)

	# Draw Buildings / Campfires
	if GameState.buildings_container != null:
		for b in GameState.buildings_container.get_children():
			if not is_instance_valid(b) or b.get("hp") <= 0.0:
				continue
			var fid: int = int(b.get("faction_id"))
			var col: Color = GameData.FACTION_COLORS.get(fid, Color.WHITE)
			var mp := _to_map((b as Node3D).global_position)
			var bt: String = str(b.get("building_type"))
			if bt == "CAMPFIRE" or bt == "SACRED_TOTEM":
				_draw_diamond(mp, 4.0, col)
			else:
				draw_rect(Rect2(mp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col.darkened(0.2), true)

	# Draw Faction Camp Labels
	if font != null:
		for fid in FACTION_TAGS.keys():
			if not GameState.factions.has(fid):
				continue
			var fdata: Dictionary = GameState.factions[fid]
			if fdata.get("is_defeated"):
				continue
			if (fid == 0 or fid == 6) and not bool(fdata.get("is_founded", false)):
				continue
			var camp_pos: Vector3 = fdata.get("camp_position", Vector3.ZERO)
			var mp := _to_map(camp_pos)
			var col: Color = GameData.FACTION_COLORS.get(fid, Color.WHITE).lightened(0.25)
			draw_string(font, mp + Vector2(-10.0, -6.0), FACTION_TAGS[fid], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)

	# Draw Caveman Caves
	if GameState.resources_container != null:
		for n in GameState.resources_container.get_children():
			if is_instance_valid(n) and n.get_meta("node_type", "") == "CAVEMAN_CAVE":
				var mp := _to_map((n as Node3D).global_position)
				_draw_diamond(mp, 3.8, Look.DANGER)
				if font != null:
					draw_string(font, mp + Vector2(-12.0, -5.0), "CAVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.86, 0.52, 0.42))

	# Draw Boss Megafauna
	if GameState.wildlife_container != null:
		for w in GameState.wildlife_container.get_children():
			if not is_instance_valid(w) or w.get("is_dead"):
				continue
			if w.get("is_boss"):
				var mp := _to_map((w as Node3D).global_position)
				draw_arc(mp, 4.0, 0.0, TAU, 12, Look.GOLD, 1.5, true)

	# Draw Units + Player Facing + Raid Pulse
	var pulse := 6.0
	if not bool(Preferences.get_value("reduced_motion")):
		pulse += 2.0 * sin(float(Time.get_ticks_msec()) * 0.008)
	if GameState.units_container != null:
		for u in GameState.units_container.get_children():
			if not is_instance_valid(u) or u.get("is_dead"):
				continue
			var u3d := u as Node3D
			var fid: int = int(u.get("faction_id"))
			var mp := _to_map(u3d.global_position)
			if fid == 0 and u.get("is_leader"):
				var fwd: Vector3 = -u3d.global_transform.basis.z
				var tip := mp + Vector2(fwd.x, fwd.z).normalized() * 9.0
				draw_line(mp, tip, Color(1.0, 0.95, 0.50), 2.0)
				draw_circle(mp, 4.5, Color(1.0, 0.92, 0.25))
				draw_circle(mp, 2.2, Color.WHITE)
			elif fid == 0:
				var c := Color(0.35, 0.78, 1.0) if u.get("role") == GameData.Role.WARRIOR else Color(0.55, 0.92, 0.55)
				draw_circle(mp, 2.2, c)
			elif fid == -1:
				draw_circle(mp, 2.0, Color(0.95, 0.90, 0.40))
			elif fid == -2:
				draw_circle(mp, 2.8, Color(1.0, 0.25, 0.10))
				draw_arc(mp, pulse, 0.0, TAU, 14, Color(1.0, 0.35, 0.15, 0.9), 1.5)
			elif fid == -3:
				draw_circle(mp, 2.4, Color(0.95, 0.65, 0.18))
			elif fid == 5:
				draw_circle(mp, 2.5, Color(0.95, 0.22, 0.22))
				if GameState.factions.has(0) and bool(GameState.factions[0].get("is_founded")):
					if u3d.global_position.distance_to(GameState.factions[0]["camp_position"]) < 65.0:
						draw_arc(mp, pulse, 0.0, TAU, 16, Color(1.0, 0.22, 0.20, 0.85), 1.5)
			else:
				var col: Color = GameData.FACTION_COLORS.get(fid, Color.RED)
				draw_circle(mp, 2.4 if u.get("is_leader") else 1.8, col)
				if u.get("is_raiding") and GameState.is_hostile(0, fid):
					draw_arc(mp, pulse, 0.0, TAU, 16, Color(1.0, 0.28, 0.22, 0.85), 1.5)

	# Draw Awakening Guide Objective Ring
	var guide_target: Dictionary = AwakeningGuide.get_objective_target(GameState)
	if bool(guide_target.get("active", false)) and bool(guide_target.get("has_position", false)):
		var gmp: Vector2 = _to_map(guide_target["position"])
		var ring_r := 6.5
		var ring_alpha := 0.90
		if not bool(Preferences.get_value("reduced_motion")):
			var wave := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.007)
			ring_r = 5.5 + wave * 3.5
			ring_alpha = 0.65 + wave * 0.35
		draw_arc(gmp, ring_r, 0.0, TAU, 20, Color(1.0, 0.86, 0.28, ring_alpha), 1.8, true)
		draw_arc(gmp, 3.2, 0.0, TAU, 12, Color(1.0, 0.95, 0.65, 0.92), 1.2, true)

	# Compass Direction Labels (N / S / E / W)
	if font != null:
		var comp_col := Color(0.85, 0.76, 0.55, 0.88)
		draw_string(font, Vector2(size.x * 0.5 - 4.0, 11.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, comp_col)
		draw_string(font, Vector2(size.x * 0.5 - 4.0, size.y - 4.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, comp_col)
		draw_string(font, Vector2(4.0, size.y * 0.5 + 4.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, comp_col)
		draw_string(font, Vector2(size.x - 13.0, size.y * 0.5 + 4.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, comp_col)


func _draw_diamond(pos: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0.0, -radius), pos + Vector2(radius, 0.0),
		pos + Vector2(0.0, radius), pos + Vector2(-radius, 0.0),
	]), color)
