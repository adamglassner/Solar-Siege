extends Node
## Plays the sound effects and music in assets/audio. Volumes come from Global.settings.

const SFX := [
	"laser", "laser_dual", "laser_spread", "alien_shot", "alien_shot_heavy",
	"explode_small", "explode_big", "explode_huge", "hit_armor", "player_hit",
	"pu_dual", "pu_spread", "pu_speed", "pu_shield", "pu_bomb", "pu_rapid", "pu_life",
	"bomb", "shield_block", "bunker_hit", "menu_move", "menu_select", "menu_back", "denied",
	"level_start", "level_clear", "game_over", "victory", "boss_warn", "boss_laser_charge", "boss_laser",
]
const VOICES := 24

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music: AudioStreamPlayer
var _music_path := ""
var _saucer: AudioStreamPlayer
var _saucer_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for n in SFX:
		_streams[n] = load("res://assets/audio/sfx/%s.wav" % n)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_saucer = AudioStreamPlayer.new()
	_saucer.bus = "SFX"
	_saucer.stream = load("res://assets/audio/sfx/saucer_loop.wav")
	add_child(_saucer)
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = Global.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(s.master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(s.music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(s.sfx, 0.0001)))


## Plays a sound effect by name (see SFX). Identical sounds are throttled so big waves don't clip.
func play(name: String) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		push_warning("Unknown sound: " + name)
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap := 0.03 if name.begins_with("explode") else (0.05 if name == "alien_shot" else 0.015)
	if now - float(_last.get(name, -10.0)) < gap:
		return
	_last[name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()


## Starts a looping music track (an AudioStream, or null to stop).
func play_music(stream: AudioStream) -> void:
	if stream == null:
		_music.stop()
		_music_path = ""
		return
	if stream.resource_path == _music_path and _music.playing:
		return
	_music_path = stream.resource_path
	_music.stream = stream
	_music.play()


func music(name: String) -> AudioStream:
	return load("res://assets/audio/music/%s.wav" % name)


func saucer_start() -> void:
	if _saucer_tween:
		_saucer_tween.kill()
	_saucer.volume_db = -30.0
	_saucer.play()
	_saucer_tween = create_tween()
	_saucer_tween.tween_property(_saucer, "volume_db", 0.0, 0.2)


func saucer_stop() -> void:
	if not _saucer.playing:
		return
	if _saucer_tween:
		_saucer_tween.kill()
	_saucer_tween = create_tween()
	_saucer_tween.tween_property(_saucer, "volume_db", -40.0, 0.15)
	_saucer_tween.tween_callback(_saucer.stop)
