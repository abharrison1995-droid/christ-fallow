extends Node
## Global audio manager autoload owning buses, pooled 2D/3D SFX, throttling, and dynamic music crossfades.

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

const UI_POOL_SIZE := 6
const SFX_3D_POOL_SIZE := 16
const SFX_3D_MAX_DISTANCE := 38.0
const SFX_3D_UNIT_SIZE := 8.0
const DEFAULT_FADE_SECONDS := 1.2
const SILENT_DB := -40.0

const SFX_CUES := {
	"melee_swing": "res://assets/audio/sfx/melee_swing.wav",
	"melee_hit": "res://assets/audio/sfx/melee_hit.wav",
	"club_smash": "res://assets/audio/sfx/club_smash.wav",
	"bow_release": "res://assets/audio/sfx/bow_release.wav",
	"javelin_throw": "res://assets/audio/sfx/javelin_throw.wav",
	"shield_block": "res://assets/audio/sfx/shield_block.wav",
	"wood_chop": "res://assets/audio/sfx/wood_chop.wav",
	"stone_mine": "res://assets/audio/sfx/stone_mine.wav",
	"build_hammer": "res://assets/audio/sfx/build_hammer.wav",
	"building_complete": "res://assets/audio/sfx/building_complete.wav",
	"warhorn": "res://assets/audio/sfx/warhorn.wav",
	"blessing_cast": "res://assets/audio/sfx/blessing_cast.wav",
	"level_up": "res://assets/audio/sfx/level_up.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"animal_roar": "res://assets/audio/sfx/animal_roar.wav",
	"footstep_grass": "res://assets/audio/sfx/footstep_grass.wav",
}

const CUE_COOLDOWNS_MS := {
	"melee_swing": 55,
	"melee_hit": 50,
	"club_smash": 65,
	"bow_release": 60,
	"javelin_throw": 60,
	"shield_block": 55,
	"wood_chop": 75,
	"stone_mine": 75,
	"build_hammer": 80,
	"building_complete": 90,
	"warhorn": 90,
	"blessing_cast": 90,
	"level_up": 90,
	"ui_click": 45,
	"animal_roar": 90,
	"footstep_grass": 70,
}

const MUSIC_TRACKS := {
	"TITLE": "res://assets/ui/title_ambience.wav",
	"PEACE_DAY": "res://assets/audio/music/valley_day_peace.wav",
	"NIGHT": "res://assets/audio/music/valley_night_hearth.wav",
	"COMBAT": "res://assets/audio/music/tribal_combat_drums.wav",
	"ARENA": "res://assets/audio/music/arena_chant_drums.wav",
}

var _ui_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _ui_cursor: int = 0
var _sfx_3d_cursor: int = 0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music_track: int = 0  # 0 -> _music_a, 1 -> _music_b
var _music_tween: Tween = null
var _last_music_state: String = ""
var _active_music_state: String = ""
var _title_volume_db: float = 0.0

var _sfx_streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _last_cue_msec: Dictionary = {}
var _cue_play_counts: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _shutting_down: bool = false


func _ready() -> void:
	_shutting_down = false
	_rng.randomize()
	ensure_audio_buses()
	_build_pools()
	_preload_audio()
	if has_node("/root/Preferences"):
		Preferences.changed.connect(_apply_ambience_volume)
		_apply_ambience_volume()
		Preferences.call_deferred("_apply")


func _exit_tree() -> void:
	shutdown()


func ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		var music_idx := AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, BUS_MUSIC)
		AudioServer.set_bus_send(music_idx, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var sfx_idx := AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, BUS_SFX)
		AudioServer.set_bus_send(sfx_idx, BUS_MASTER)


func _build_pools() -> void:
	for i in range(UI_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "UI_SFX_%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_ui_pool.append(p)

	for i in range(SFX_3D_POOL_SIZE):
		var p3d := AudioStreamPlayer3D.new()
		p3d.name = "SFX_3D_%d" % i
		p3d.bus = BUS_SFX
		p3d.max_distance = SFX_3D_MAX_DISTANCE
		p3d.unit_size = SFX_3D_UNIT_SIZE
		add_child(p3d)
		_sfx_3d_pool.append(p3d)

	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicTrackA"
	_music_a.bus = BUS_MUSIC
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicTrackB"
	_music_b.bus = BUS_MUSIC
	add_child(_music_b)


func _preload_audio() -> void:
	for cue in SFX_CUES:
		var path: String = SFX_CUES[cue]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_sfx_streams[cue] = stream

	for state in MUSIC_TRACKS:
		var path: String = MUSIC_TRACKS[state]
		if ResourceLoader.exists(path):
			var raw := load(path)
			if raw is AudioStreamWAV:
				var wav := raw.duplicate() as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
				_music_streams[state] = wav
			elif raw is AudioStream:
				_music_streams[state] = raw


func _music_volume_offset(track: AudioStreamPlayer) -> float:
	return _title_volume_db if track.stream != null and track.stream == _music_streams.get("TITLE") else 0.0


func _apply_ambience_volume() -> void:
	var next_db := linear_to_db(maxf(0.00001, float(Preferences.get_value("ambience"))))
	for track in [_music_a, _music_b]:
		if track.stream != null and track.stream == _music_streams.get("TITLE"):
			track.volume_db += next_db - _title_volume_db
	_title_volume_db = next_db


func _set_track_fade(db: float, track: AudioStreamPlayer) -> void:
	track.volume_db = db + _music_volume_offset(track)


func play_ui_sfx(cue: String, pitch_jitter: float = 0.05) -> bool:
	if _shutting_down or _is_sfx_muted():
		return false
	var stream: AudioStream = _get_sfx_stream(cue)
	if stream == null or _ui_pool.is_empty():
		return false
	var now_ms := Time.get_ticks_msec()
	if _is_cue_throttled(cue, now_ms):
		return false

	var player := _acquire_ui_player()
	player.stream = stream
	player.volume_db = 0.0
	player.pitch_scale = _compute_pitch(pitch_jitter)
	if not _is_headless_audio():
		player.play()
	_record_cue_play(cue, now_ms)
	return true


func play_sfx_3d(cue: String, world_pos: Vector3, pitch_jitter: float = 0.08, volume_db: float = 0.0) -> bool:
	if _shutting_down or _is_sfx_muted():
		return false
	var stream: AudioStream = _get_sfx_stream(cue)
	if stream == null or _sfx_3d_pool.is_empty():
		return false
	var now_ms := Time.get_ticks_msec()
	if _is_cue_throttled(cue, now_ms):
		return false

	var player := _acquire_3d_player()
	player.stream = stream
	player.global_position = world_pos
	player.volume_db = volume_db
	player.pitch_scale = _compute_pitch(pitch_jitter)
	if not _is_headless_audio():
		player.play()
	_record_cue_play(cue, now_ms)
	return true


func set_music_state(state: String, fade_seconds: float = DEFAULT_FADE_SECONDS) -> bool:
	if _shutting_down:
		return false
	var key := state.strip_edges().to_upper()
	if not MUSIC_TRACKS.has(key):
		return false
	if _active_music_state == key:
		_last_music_state = key
		return true

	var stream: AudioStream = _get_music_stream(key)
	if stream == null:
		return false
	_last_music_state = key

	var incoming := _music_b if _active_music_track == 0 else _music_a
	var outgoing := _music_a if _active_music_track == 0 else _music_b
	_active_music_track = 1 if _active_music_track == 0 else 0
	_active_music_state = key

	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
		_music_tween = null

	incoming.stop()
	incoming.stream = stream

	var use_instant := _is_headless_audio() or fade_seconds <= 0.0 or not is_inside_tree() or not outgoing.playing
	if use_instant:
		outgoing.stop()
		outgoing.stream = null
		_set_track_fade(0.0, incoming)
		if not _is_headless_audio():
			incoming.play()
		return true

	_set_track_fade(SILENT_DB, incoming)
	incoming.play()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_method(_set_track_fade.bind(incoming), SILENT_DB, 0.0, fade_seconds)
	_music_tween.tween_method(_set_track_fade.bind(outgoing), outgoing.volume_db - _music_volume_offset(outgoing), SILENT_DB, fade_seconds)
	_music_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(outgoing):
			outgoing.stop()
			outgoing.stream = null
	)
	return true


func stop_music(fade_seconds: float = 0.4) -> void:
	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
		_music_tween = null
	_active_music_state = ""
	if _is_headless_audio() or fade_seconds <= 0.0 or not is_inside_tree():
		for track in [_music_a, _music_b]:
			if is_instance_valid(track):
				track.stop()
				track.stream = null
		return
	var any_playing := false
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	for track in [_music_a, _music_b]:
		if is_instance_valid(track) and track.playing:
			any_playing = true
			_music_tween.tween_method(_set_track_fade.bind(track), track.volume_db - _music_volume_offset(track), SILENT_DB, fade_seconds)
	if not any_playing:
		_music_tween.kill()
		_music_tween = null
		return
	_music_tween.chain().tween_callback(func() -> void:
		for track in [_music_a, _music_b]:
			if is_instance_valid(track):
				track.stop()
				track.stream = null
	)


func shutdown() -> void:
	_shutting_down = true
	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
		_music_tween = null
	_active_music_state = ""
	for track in [_music_a, _music_b]:
		if is_instance_valid(track):
			track.stop()
			track.stream = null
	for p in _ui_pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p3d in _sfx_3d_pool:
		if is_instance_valid(p3d):
			p3d.stop()
			p3d.stream = null


func get_last_music_state() -> String:
	return _last_music_state


func get_active_music_state() -> String:
	return _active_music_state


func get_cue_play_count(cue: String) -> int:
	return int(_cue_play_counts.get(cue, 0))


func reset_telemetry() -> void:
	_last_cue_msec.clear()
	_cue_play_counts.clear()
	_last_music_state = ""


func _get_sfx_stream(cue: String) -> AudioStream:
	if _sfx_streams.has(cue):
		return _sfx_streams[cue] as AudioStream
	var path: String = SFX_CUES.get(cue, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_sfx_streams[cue] = stream
	return stream


func _get_music_stream(state: String) -> AudioStream:
	if _music_streams.has(state):
		return _music_streams[state] as AudioStream
	var path: String = MUSIC_TRACKS.get(state, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var raw := load(path)
	if raw is AudioStreamWAV:
		var wav := raw.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_music_streams[state] = wav
		return wav
	if raw is AudioStream:
		_music_streams[state] = raw
		return raw
	return null


func _is_cue_throttled(cue: String, now_ms: int) -> bool:
	var cooldown_ms: int = int(CUE_COOLDOWNS_MS.get(cue, 60))
	var last_ms: int = int(_last_cue_msec.get(cue, -100000))
	return (now_ms - last_ms) < cooldown_ms


func _record_cue_play(cue: String, now_ms: int) -> void:
	_last_cue_msec[cue] = now_ms
	_cue_play_counts[cue] = int(_cue_play_counts.get(cue, 0)) + 1


func _is_sfx_muted() -> bool:
	if AudioServer.is_bus_mute(0):
		return true
	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0 and AudioServer.is_bus_mute(sfx_idx):
		return true
	return false


func _is_headless_audio() -> bool:
	return DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("Dummy")


func _compute_pitch(pitch_jitter: float) -> float:
	if pitch_jitter <= 0.0:
		return 1.0
	return _rng.randf_range(maxf(0.5, 1.0 - pitch_jitter), 1.0 + pitch_jitter)


func _acquire_ui_player() -> AudioStreamPlayer:
	for p in _ui_pool:
		if not p.playing:
			return p
	_ui_cursor = (_ui_cursor + 1) % _ui_pool.size()
	var stolen := _ui_pool[_ui_cursor]
	stolen.stop()
	return stolen


func _acquire_3d_player() -> AudioStreamPlayer3D:
	for p3d in _sfx_3d_pool:
		if not p3d.playing:
			return p3d
	_sfx_3d_cursor = (_sfx_3d_cursor + 1) % _sfx_3d_pool.size()
	var stolen := _sfx_3d_pool[_sfx_3d_cursor]
	stolen.stop()
	return stolen
