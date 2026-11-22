extends SceneTree
## Forward+ verification suite for Phase 8 (SFX & Dynamic Music Audio System).
## Run with isolated APPDATA and CHRIST_FALLOW_QA_APPDATA.

const Farming = preload("res://scripts/core/farming_rules.gd")

var _state: Node
var _data: Node
var _prefs: Node
var _sound: Node
var _shell: Node
var _failed := false
var _pass_count := 0
var _fail_count := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, caption: String) -> void:
	if condition:
		_pass_count += 1
		print("PASS ", caption)
	else:
		_fail_count += 1
		_failed = true
		push_error("FAIL " + caption)


func frames(count: int = 2) -> void:
	for _i in range(count):
		await process_frame


func key_press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev, true)
	ev = InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	root.push_input(ev, true)


func click_at(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	root.push_input(ev, true)
	ev = InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	root.push_input(ev, true)


func button_in(scope: Node, label: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn != null and btn.text == label and btn.is_visible_in_tree() and not btn.disabled:
			return btn
	return null


func press(scope: Node, label: String) -> void:
	var btn := button_in(scope, label)
	check(btn != null, "action button visible: " + label)
	if btn != null:
		btn.grab_focus()
		key_press(KEY_ENTER)


func _run() -> void:
	var scratch := OS.get_environment("CHRIST_FALLOW_QA_APPDATA").replace("\\", "/").rstrip("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch + "/"):
		push_error("Set APPDATA and CHRIST_FALLOW_QA_APPDATA to an isolated writable directory.")
		quit(1)
		return

	_state = root.get_node("GameState")
	_data = root.get_node("GameData")
	_prefs = root.get_node("Preferences")
	_sound = root.get_node_or_null("/root/SoundManager")
	check(_sound != null, "SoundManager autoload present")
	if _sound == null:
		quit(1)
		return

	# ── (a) Audio buses exist ──
	var master_idx := AudioServer.get_bus_index(&"Master")
	var music_idx := AudioServer.get_bus_index(&"Music")
	var sfx_idx := AudioServer.get_bus_index(&"SFX")
	check(master_idx == 0, "Master audio bus exists at index 0")
	check(music_idx > 0 and AudioServer.get_bus_send(music_idx) == &"Master", "Music audio bus exists and routes to Master")
	check(sfx_idx > 0 and AudioServer.get_bus_send(sfx_idx) == &"Master", "SFX audio bus exists and routes to Master")

	# ── (b) Preferences persistence & AudioServer bus volume/mute ──
	_prefs.set_value("master", 0.50)
	_prefs.set_value("music", 0.35)
	_prefs.set_value("sfx", 0.25)
	_prefs.set_value("ambience", 0.45)
	check(is_equal_approx(float(_prefs.get_value("master")), 0.50), "Preferences stores master")
	check(is_equal_approx(float(_prefs.get_value("music")), 0.35), "Preferences stores music")
	check(is_equal_approx(float(_prefs.get_value("sfx")), 0.25), "Preferences stores sfx")
	check(is_equal_approx(float(_prefs.get_value("ambience")), 0.45), "Preferences stores ambience")
	check(is_equal_approx(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.50)), "Master bus volume_db tracks Preferences")
	check(is_equal_approx(AudioServer.get_bus_volume_db(music_idx), linear_to_db(0.35)), "Music bus volume_db tracks Preferences")
	check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_idx), linear_to_db(0.25)), "SFX bus volume_db tracks Preferences")
	check(not AudioServer.is_bus_mute(master_idx) and not AudioServer.is_bus_mute(music_idx) and not AudioServer.is_bus_mute(sfx_idx), "Non-zero audio buses are unmuted")

	_prefs.set_value("sfx", 0.0)
	_prefs.set_value("music", 0.0)
	check(AudioServer.is_bus_mute(sfx_idx) and AudioServer.is_bus_mute(music_idx), "Setting music/sfx to 0.0 mutes Music and SFX buses")
	check(not _sound.play_ui_sfx("ui_click"), "play_ui_sfx respects muted SFX bus")

	_prefs.set_value("master", 0.85)
	_prefs.set_value("music", 0.70)
	_prefs.set_value("sfx", 0.80)
	_prefs.set_value("ambience", 0.65)
	check(not AudioServer.is_bus_mute(sfx_idx) and not AudioServer.is_bus_mute(music_idx), "Restored audio buses are unmuted")
	check(_prefs.save(), "Preferences.save() succeeds")
	var cfg := ConfigFile.new()
	check(cfg.load(_prefs.PATH) == OK, "Saved preferences ConfigFile loads cleanly")
	check(is_equal_approx(float(cfg.get_value("interface", "master", -1.0)), 0.85), "Persisted master preference matches")
	check(is_equal_approx(float(cfg.get_value("interface", "music", -1.0)), 0.70), "Persisted music preference matches")
	check(is_equal_approx(float(cfg.get_value("interface", "sfx", -1.0)), 0.80), "Persisted sfx preference matches")
	check(is_equal_approx(float(cfg.get_value("interface", "ambience", -1.0)), 0.65), "Persisted ambience preference matches")

	# ── (c) All 16 SFX and 4 music resources exist & load cleanly ──
	var expected_sfx := [
		"melee_swing", "melee_hit", "club_smash", "bow_release",
		"javelin_throw", "shield_block", "wood_chop", "stone_mine",
		"build_hammer", "building_complete", "warhorn", "blessing_cast",
		"level_up", "ui_click", "animal_roar", "footstep_grass",
	]
	check(_sound.SFX_CUES.size() == 16, "SoundManager defines all 16 SFX cues")
	for cue in expected_sfx:
		var path: String = str(_sound.SFX_CUES.get(cue, ""))
		var exists := not path.is_empty() and ResourceLoader.exists(path)
		var stream := load(path) as AudioStreamWAV if exists else null
		check(exists and stream != null and stream.get_length() > 0.0, "SFX resource exists & loads: " + cue)

	var expected_music := {
		"PEACE_DAY": "res://assets/audio/music/valley_day_peace.wav",
		"NIGHT": "res://assets/audio/music/valley_night_hearth.wav",
		"COMBAT": "res://assets/audio/music/tribal_combat_drums.wav",
		"ARENA": "res://assets/audio/music/arena_chant_drums.wav",
	}
	check(_sound.MUSIC_TRACKS.size() == 5, "SoundManager defines all 5 music states (TITLE + 4 loops)")
	for state_key in expected_music:
		var mpath: String = str(_sound.MUSIC_TRACKS.get(state_key, ""))
		var mexists: bool = mpath == str(expected_music[state_key]) and ResourceLoader.exists(mpath)
		var mstream := load(mpath) as AudioStreamWAV if mexists else null
		check(mexists and mstream != null and mstream.get_length() > 0.0, "Music resource exists & loads: " + state_key)
	check(ResourceLoader.exists(_sound.MUSIC_TRACKS["TITLE"]) and load(_sound.MUSIC_TRACKS["TITLE"]) is AudioStreamWAV, "TITLE ambience resource loads")

	# ── (d) play_ui_sfx, play_sfx_3d, telemetry, cooldown throttling, and pool reuse ──
	var initial_children: int = _sound.get_child_count()
	_sound.reset_telemetry()
	check(_sound.play_ui_sfx("ui_click"), "play_ui_sfx plays ui_click")
	check(_sound.get_cue_play_count("ui_click") == 1, "ui_click telemetry incremented to 1")
	check(not _sound.play_ui_sfx("ui_click"), "play_ui_sfx throttles duplicate trigger inside cooldown")
	check(_sound.get_cue_play_count("ui_click") == 1, "throttled ui_click does not increment telemetry")

	check(_sound.play_sfx_3d("melee_swing", Vector3(2.0, 0.0, 3.0)), "play_sfx_3d plays melee_swing")
	check(_sound.get_cue_play_count("melee_swing") == 1, "melee_swing telemetry incremented to 1")
	check(not _sound.play_sfx_3d("melee_swing", Vector3(2.0, 0.0, 3.0)), "play_sfx_3d throttles duplicate trigger inside cooldown")
	check(_sound.get_cue_play_count("melee_swing") == 1, "throttled melee_swing does not increment telemetry")

	# Fill the 3D pool with long cues before exercising recycling and per-cue throttling.
	check(_sound._ui_pool.size() == 6 and _sound._sfx_3d_pool.size() == 16, "SoundManager builds six 2D and sixteen 3D players")
	OS.delay_msec(105)
	for cue in expected_sfx:
		_sound.play_sfx_3d(cue, Vector3.ZERO, 0.0)
	await frames(1)
	_sound.reset_telemetry()
	_sound.play_sfx_3d("wood_chop", Vector3.ZERO)
	_sound.play_sfx_3d("stone_mine", Vector3.ZERO)
	check(not _sound.play_sfx_3d("wood_chop", Vector3.ZERO) and not _sound.play_sfx_3d("stone_mine", Vector3.ZERO)
		and _sound.get_cue_play_count("wood_chop") == 1 and _sound.get_cue_play_count("stone_mine") == 1,
		"Rapid harvest requests are throttled in the 3D pool")
	check(_sound.get_child_count() == initial_children, "SoundManager pool recycling leaves child count unchanged (%d)" % initial_children)

	# ── (e) Title -> SettingsScreen layout -> Campaign -> Music States -> SFX Hooks -> Return to Title ──
	var title_scene: PackedScene = load("res://scenes/ui/title_screen.tscn")
	_shell = title_scene.instantiate()
	root.add_child(_shell)
	await frames(3)
	check(not _state.game_active, "Title starts without active campaign")
	var title_track: AudioStreamPlayer = _sound._music_b if _sound._music_a.stream == null else _sound._music_a
	check(_sound.get_active_music_state() == "TITLE" and title_track.playing, "The pooled TITLE track plays at startup")
	_prefs.set_value("ambience", 0.30)
	check(is_equal_approx(title_track.volume_db, linear_to_db(0.30)), "Title ambience slider changes the TITLE track gain")
	_prefs.set_value("ambience", 0.65)

	# Verify SettingsScreen Audio tab & bounds at 1280x720 with large UI scale (1.1)
	_prefs.set_value("reduced_motion", true)
	_prefs.set_value("ui_scale", 1.1)
	press(_shell._title, "Start")
	await frames(4)
	press(_shell._title, "Settings")
	await frames(3)
	var settings_page: Control = _shell._page
	check(settings_page != null, "SettingsScreen opens on Title")
	if settings_page != null:
		var tabs := settings_page.find_children("*", "TabContainer", true, false)
		check(not tabs.is_empty(), "SettingsScreen has TabContainer")
		if not tabs.is_empty():
			var tc := tabs[0] as TabContainer
			var audio_tab := tc.get_node_or_null("Audio")
			check(audio_tab != null, "SettingsScreen has Audio tab")
			if audio_tab != null:
				tc.current_tab = audio_tab.get_index()
				await frames(2)
				var sliders := audio_tab.find_children("*", "HSlider", true, false)
				check(sliders.size() == 4, "Audio tab exposes 4 sliders (Master, Music, SFX, Title ambience)")
		# Verify modal frame fits inside 1280x720 at ui_scale=1.1 (~1163x654 logical) without clipping.
		var frame_panels := settings_page.find_children("*", "PanelContainer", true, false)
		if not frame_panels.is_empty():
			var frame_rect := (frame_panels[0] as PanelContainer).get_global_rect()
			check(frame_rect.size.x <= 1280.0 / 1.1 and frame_rect.size.y <= 720.0 / 1.1,
				"SettingsScreen fits within 1280x720 at --large-ui (size=%s)" % str(frame_rect.size))
	press(_shell._page, "Done")
	await frames(3)
	_prefs.set_value("ui_scale", 1.0)

	# Launch new campaign through TitleScreen Awakening
	press(_shell._title, "New Game")
	await frames(3)
	_shell._page._tribe.text = "Audio QA Tribe"
	press(_shell._page, "Awaken in the Valley")
	await frames(12)
	check(_state.game_active and _state.get_faction_leader(0) != null, "Campaign launches from TitleScreen")
	check(_sound.get_last_music_state() == "PEACE_DAY", "Daytime campaign start selects PEACE_DAY music (got %s)" % _sound.get_last_music_state())
	check(_sound._music_a.playing and _sound._music_b.playing, "Campaign launch crossfades from title ambience")

	# Night music transition
	_state.time_of_day = 23.0
	await frames(3)
	check(_sound.get_last_music_state() == "NIGHT", "Nighttime (23.0) transitions music to NIGHT (got %s)" % _sound.get_last_music_state())
	_state.time_of_day = 10.0
	await frames(3)
	check(_sound.get_last_music_state() == "PEACE_DAY", "Daytime (10.0) transitions music back to PEACE_DAY (got %s)" % _sound.get_last_music_state())

	# Wait out any prior SFX cooldowns, then exercise gameplay SFX hooks
	OS.delay_msec(110)
	_sound.reset_telemetry()
	var pc: Node = _state.player_controller
	var hud: Control = _state.hud_controller
	var fc0: Node = _state.faction_controllers[0]

	# LMB melee cleave (click clear center-right screen point in third-person)
	pc._attack_cd = 0.0
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(960.0, 420.0)
	motion.global_position = Vector2(960.0, 420.0)
	root.push_input(motion, true)
	await frames(1)
	click_at(Vector2(960.0, 420.0))
	await frames(2)
	var cleave_played: bool = (int(_sound.get_cue_play_count("melee_swing")) + int(_sound.get_cue_play_count("club_smash")) + int(_sound.get_cue_play_count("bow_release"))) >= 1
	check(cleave_played, "LMB cleave triggers weapon swing/release SFX")

	# F javelin throw
	OS.delay_msec(80)
	pc._javelin_cd = 0.0
	key_press(KEY_F)
	await frames(2)
	check(_sound.get_cue_play_count("javelin_throw") >= 1, "KEY_F triggers javelin_throw SFX")

	# H Warhorn toggle
	OS.delay_msec(100)
	key_press(KEY_H)
	await frames(2)
	check(_sound.get_cue_play_count("warhorn") >= 1 and _state.warhorn_active, "KEY_H triggers warhorn SFX and activates warhorn")
	key_press(KEY_H)
	await frames(2)
	check(_sound.get_cue_play_count("ui_click") >= 1 and not _state.warhorn_active, "Second KEY_H plays ui_click and stands down warhorn")

	# Construction complete SFX
	OS.delay_msec(100)
	var hut: Node = fc0.spawn_building("SLEEPING_HUT", Vector3(6.0, 0.0, 56.0), 0.0, false)
	check(hut != null and not hut.is_constructed, "Spawned unconstructed Sleeping Hut blueprint")
	if hut != null:
		hut.advance_construction(9999.0)
		await frames(2)
		check(hut.is_constructed and _sound.get_cue_play_count("building_complete") >= 1, "Construction completion triggers building_complete SFX")

	# Level-up SFX
	OS.delay_msec(100)
	_state.award_xp(0, 500.0, "Audio QA Level Up")
	await frames(2)
	check(_sound.get_cue_play_count("level_up") >= 1, "Player tribal level-up triggers level_up SFX")

	# Combat / raid_alert switches music to COMBAT, then settles back once _combat_music_timer expires
	_state.raid_alert.emit(1, 0, "QA Raid Alert")
	await frames(2)
	check(_sound.get_last_music_state() == "COMBAT" and _state._combat_music_timer > 0.0,
		"raid_alert switches music to COMBAT (got %s)" % _sound.get_last_music_state())

	_state._combat_music_timer = 0.0
	await frames(2)
	check(_sound.get_last_music_state() == "PEACE_DAY", "Clearing combat timer restores PEACE_DAY")

	_state.notify_combat_audio(0.25)
	await frames(2)
	check(_sound.get_last_music_state() == "COMBAT", "notify_combat_audio switches music to COMBAT")
	for _i in range(30):
		await frames(1)
		if _state._combat_music_timer <= 0.0 and _sound.get_last_music_state() == "PEACE_DAY":
			break
	check(_state._combat_music_timer <= 0.0 and _sound.get_last_music_state() == "PEACE_DAY",
		"Combat music settles back cleanly to PEACE_DAY after _combat_music_timer expires (got %s)" % _sound.get_last_music_state())

	# restore_mount_from_save() must NOT emit mount roar or blessing_cast
	var pen: Node = fc0.spawn_building("ANIMAL_PEN", Vector3(-8.0, 0.0, 56.0), 0.0, true)
	var boar: Node3D = _state.world_node._spawn_animal("BOAR", Vector3(-8.0, 0.0, 58.0))
	check(pen != null and boar != null, "Spawned pen and boar for mount silence check")
	if boar != null:
		boar.domesticate(0, pen.global_position, 0.0)
		boar.training_feeds = Farming.MOUNT_TRAINING
		boar.set_rider(_state.get_faction_leader(0).unit_id)
		OS.delay_msec(100)
		_sound.reset_telemetry()
		pc.restore_mount_from_save()
		await frames(2)
		check(pc.is_mounted(), "restore_mount_from_save mounted boar")
		check(_sound.get_cue_play_count("animal_roar") == 0 and _sound.get_cue_play_count("blessing_cast") == 0,
			"restore_mount_from_save does not emit mount roar or blessing_cast")
		pc.dismount_from(boar)

	# Return to Title via Pause menu restores TITLE music state cleanly
	key_press(KEY_ESCAPE)
	await frames(3)
	press(hud._overlays._pause_screen, "Return to Title")
	await frames(3)
	press(hud._overlays._confirmation, "Return to Title")
	await frames(8)
	check(not _state.game_active and _shell._title.visible, "Return to Title restores TitleScreen")
	check(_sound.get_active_music_state() == "TITLE", "Return to Title restores active TITLE music")
	await frames(24)
	var cleared_tracks := 0
	for track in [_sound._music_a, _sound._music_b]:
		if not track.playing and track.stream == null:
			cleared_tracks += 1
	check(cleared_tracks == 1, "Return to Title fade releases the outgoing campaign stream")

	_sound.shutdown()
	check(_sound.get_children().all(func(player): return not player.playing and player.stream == null),
		"Shutdown stops and clears every pooled stream")
	if is_instance_valid(_shell):
		root.remove_child(_shell)
		_shell.queue_free()
	await frames(2)

	if _failed or _fail_count > 0:
		push_error("AUDIO SYSTEM VERIFICATION FAILED (%d failed, %d passed)" % [_fail_count, _pass_count])
		quit(1)
		return
	print("AUDIO SYSTEM VERIFICATION PASSED (%d checks)" % _pass_count)
	quit(0)
