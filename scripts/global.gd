extends Node
## Game-wide state: settings, save game, high score, scene switching and toasts.
## Files live in the user folder: %APPDATA%\Solar Siege on Windows.

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://savegame.json"
const HIGH_PATH := "user://highscore.json"

const DIFFICULTY := {
	"easy": {"label": "Easy", "lives": 5, "speed": 0.8, "fire": 0.6, "bullet": 0.85, "boss_hp": 0.7, "drop": 1.3},
	"normal": {"label": "Normal", "lives": 3, "speed": 1.0, "fire": 1.0, "bullet": 1.0, "boss_hp": 1.0, "drop": 1.0},
	"hard": {"label": "Hard", "lives": 3, "speed": 1.18, "fire": 1.4, "bullet": 1.15, "boss_hp": 1.35, "drop": 0.8},
}

const LEVEL_PATHS := [
	"res://data/levels/01_mercury.tres", "res://data/levels/02_venus.tres", "res://data/levels/03_earth.tres",
	"res://data/levels/04_mars.tres", "res://data/levels/05_jupiter.tres", "res://data/levels/06_saturn.tres",
	"res://data/levels/07_uranus.tres", "res://data/levels/08_neptune.tres", "res://data/levels/09_pluto.tres",
]

## Built-in alien rows per planet, used if a level file ever loads without its rows
## (so a level can never start empty and be "won" instantly).
const FALLBACK_ROWS := [
	["squid", "crab", "crab", "drone", "drone"],
	["squid", "crab", "crab", "drone", "drone"],
	["cruiser", "squid", "crab", "crab", "drone", "drone"],
	["squid", "squid", "beetle", "crab", "drone", "drone"],
	["cruiser", "squid", "beetle", "beetle", "crab", "drone"],
	["wraith", "squid", "beetle", "crab", "crab", "drone"],
	["cruiser", "wraith", "squid", "beetle", "crab", "drone"],
	["wraith", "wraith", "beetle", "beetle", "crab", "crab"],
	["cruiser", "wraith", "wraith", "beetle", "squid", "crab"],
]

## Ship colours players can pick in multiplayer: [id, label, hue for HUD and effects, saturation].
const SHIP_COLORS := [
	["blue", "Blue", 205.0, 90.0], ["red", "Red", 350.0, 90.0], ["green", "Green", 110.0, 80.0], ["gold", "Gold", 50.0, 95.0],
	["purple", "Purple", 285.0, 85.0], ["orange", "Orange", 25.0, 100.0], ["teal", "Teal", 170.0, 80.0], ["silver", "Silver", 215.0, 12.0],
]

var settings := {"master": 0.8, "music": 0.55, "sfx": 0.8, "fullscreen": false, "shake": true, "show_fps": false,
	"name": "", "color": 0, "last_host": ""}
var _ship_tex := {}
var levels: Array[LevelData] = []
## Parameters for the next PlayScene (level, score, lives, bombs, difficulty).
var play_start := {}
## Which story to show in the story scene: "single", "multi" or "online".
var story_kind := "single"
## Map open in the Level Editor (kept while test-playing it), and its file.
var editor_map := {}
var editor_path := ""
## Remembered lobby setup so "Back" from a game returns to the same screen.
var lobby_memory := {}

var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _fps_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in LEVEL_PATHS.size():
		var lv: LevelData = load(LEVEL_PATHS[i])
		if lv.rows.is_empty():
			push_warning("Level %s loaded without alien rows; using built-in rows." % LEVEL_PATHS[i])
			lv.rows = PackedStringArray(FALLBACK_ROWS[i])
		levels.append(lv)
	_load_settings()
	_build_overlay()
	apply_fullscreen()
	CustomMaps.install_examples()
	_connect_net.call_deferred()
	if "--autotest" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tools/autotest.gd"):
		add_child(load("res://tools/autotest.gd").new())


func ship_texture(color: int) -> Texture2D:
	color = clampi(color, 0, SHIP_COLORS.size() - 1)
	if not _ship_tex.has(color):
		_ship_tex[color] = load("res://assets/sprites/ships/ship_%s.png" % SHIP_COLORS[color][0])
	return _ship_tex[color]


func ship_color(color: int, light := 65.0) -> Color:
	var c: Array = SHIP_COLORS[clampi(color, 0, SHIP_COLORS.size() - 1)]
	return UI.hsl(c[2], c[3], light)


func pilot_name() -> String:
	var n: String = settings.name
	if n.strip_edges() == "":
		n = OS.get_environment("USERNAME")
		if n == "":
			n = OS.get_environment("USER")
	return Net.clean_name(n, "Pilot")


func _connect_net() -> void:
	## Online guests follow the host from screen to screen.
	Net.story_received.connect(func(players: Array):
		play_start = {"players": players}
		story_kind = "online"
		goto_scene("res://scenes/story.tscn"))
	Net.start_received.connect(func(s: Dictionary): start_game(s))
	Net.returned_to_lobby.connect(func():
		lobby_memory["tab"] = "online"
		goto_scene("res://scenes/lobby.tscn"))


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))


# ---------------------------------------------------------------- settings
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)
	Audio.apply_volumes()
	if _fps_label:
		_fps_label.visible = settings.show_fps


func apply_fullscreen() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


# ---------------------------------------------------------------- save game
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("level"):
		return {}
	var lv := int(data.level)
	if lv < 0 or lv >= levels.size() or not DIFFICULTY.has(str(data.get("difficulty", ""))):
		return {}
	return {"level": lv, "score": int(data.score), "lives": int(data.lives), "bombs": int(data.bombs),
		"difficulty": str(data.difficulty), "saved_at": int(data.get("saved_at", 0)),
		"powers": data.get("powers", {}) if typeof(data.get("powers")) == TYPE_DICTIONARY else {},
		"warp": float(data.get("warp", 0.0))}


func save_game(s: Dictionary) -> void:
	var data := s.duplicate()
	data["version"] = 1
	data["saved_at"] = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func clear_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func high_score() -> int:
	if not FileAccess.file_exists(HIGH_PATH):
		return 0
	var v = JSON.parse_string(FileAccess.get_file_as_string(HIGH_PATH))
	return int(v) if typeof(v) in [TYPE_FLOAT, TYPE_INT] else 0


func submit_score(n: int) -> bool:
	if n > high_score():
		_write_high(n)
		return true
	return false


func reset_high_score() -> void:
	_write_high(0)


func _write_high(n: int) -> void:
	var f := FileAccess.open(HIGH_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(n))


# ---------------------------------------------------------------- scenes
func goto_menu() -> void:
	Net.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Shows the story first (single player or squadron version), then starts the game.
func start_with_story(start: Dictionary, kind: String) -> void:
	play_start = start.duplicate(true)
	story_kind = kind
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/story.tscn")


func goto_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func start_game(start: Dictionary) -> void:
	play_start = start.duplicate()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/play.tscn")


func quit_game() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- overlay: toasts & FPS
func _build_overlay() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100
	add_child(_toast_layer)
	_toast_panel = PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/toast.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 44)
		sb.set_expand_margin(side, 30)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast_label = UI.label("", 28, "bold")
	_toast_panel.add_child(_toast_label)
	_toast_panel.modulate.a = 0.0
	_toast_layer.add_child(_toast_panel)
	_fps_label = UI.label("", 18, "bold", Color("#7fffa0"))
	_fps_label.position = Vector2(1780, 1046)
	_fps_label.visible = settings.show_fps
	_toast_layer.add_child(_fps_label)


func toast(msg: String, secs := 2.4) -> void:
	_toast_label.text = msg
	_toast_panel.reset_size()
	await get_tree().process_frame
	_toast_panel.position = Vector2(960 - _toast_panel.size.x / 2.0, 1080 - 150)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(secs - 0.45)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.33)


func _process(_dt: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
