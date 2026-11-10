extends Node2D
## The story intro shown before a new campaign: the single-player version, or the
## squadron version for multiplayer. Space / Enter / A / click continues, Esc / Start skips.
## Online, the panels move on by themselves and only the host can skip, so everyone
## starts the battle together.

const AUTO_SECS := 6.5
const TYPE_SPEED := 55.0 # characters per second

@onready var _bg: Sprite2D = $Background
@onready var _art: Node2D = $Art
@onready var _box: NinePatchRect = $UI/Box
@onready var _fade: ColorRect = $UI/Fade

var _panels: Array = []
var _i := -1
var _t := 0.0
var _chars := 0.0
var _speaker: Label
var _text: Label
var _hint: Label
var _dots: Label
var _online := false
var _guest := false
var _leaving := false
var _art_kind := "none"
var _swarm_tex := []
var _ships: Array = []


func _ready() -> void:
	_online = Global.story_kind == "online"
	_guest = _online and not Net.is_host()
	_panels = Story.panels(Global.story_kind)
	_box.texture = load("res://assets/ui/panel.png")
	_speaker = UI.label("", 20, "extrabold", Color("#8fe9ff"), 6)
	_speaker.position = Vector2(60, 34)
	_box.add_child(_speaker)
	_text = UI.label("", 30, "bold", Color("#eef4ff"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.position = Vector2(60, 70)
	_text.size = Vector2(1280, 140)
	_box.add_child(_text)
	var hint := "Waiting for the host…" if _guest else "SPACE / A  continue     ·     ESC / START  skip"
	_hint = UI.place(UI.label(hint, 18, "bold", Color(0.78, 0.86, 1, 0.6), 2, HORIZONTAL_ALIGNMENT_CENTER), 960, 1040)
	$UI.add_child(_hint)
	_dots = UI.place(UI.label("", 22, "bold", Color(0.78, 0.86, 1, 0.7), 8, HORIZONTAL_ALIGNMENT_RIGHT), 1620, 790, 300)
	$UI.add_child(_dots)
	_art.draw.connect(_draw_art)
	for k in ["drone", "crab", "squid", "beetle", "wraith"]:
		_swarm_tex.append([load("res://assets/sprites/aliens/%s_8_0.png" % k), load("res://assets/sprites/aliens/%s_8_1.png" % k)])
	_ships = _squadron_textures()
	Audio.play_music(Audio.music("pluto"))
	_next()
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)


func _squadron_textures() -> Array:
	var out := []
	var list: Array = Global.play_start.get("players", [])
	for p in list:
		out.append(Global.ship_texture(int(p.get("color", 0))))
	if out.is_empty():
		for c in [0, 1, 2, 3]:
			out.append(Global.ship_texture(c))
	return out


func _next() -> void:
	_i += 1
	if _i >= _panels.size():
		_finish()
		return
	var p: Dictionary = _panels[_i]
	_bg.texture = load("res://assets/backgrounds/%s.png" % p.get("bg", "pluto"))
	$Stars.setup(_i * 131 + 7)
	_art_kind = p.get("art", "none")
	_speaker.text = str(p.get("speaker", ""))
	_text.text = str(p.get("text", ""))
	_text.visible_characters = 0
	_chars = 0.0
	_t = 0.0
	_dots.text = "%d / %d" % [_i + 1, _panels.size()]
	_box.modulate.a = 0.0
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.3)
	Audio.play("menu_move")


func _process(dt: float) -> void:
	_t += dt
	_chars += dt * TYPE_SPEED
	_text.visible_characters = int(_chars)
	_bg.scale = Vector2.ONE * (1.0 + _t * 0.008)
	_art.queue_redraw()
	if _online and not _leaving and _t > AUTO_SECS:
		if _i + 1 < _panels.size() or not _guest:
			_next()


func _input(event: InputEvent) -> void:
	if _leaving or _guest:
		return
	var pressed: bool = event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	if event.is_action("pause") or event.is_action("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action("ui_accept") or event.is_action("fire") or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if _text.visible_characters < _text.text.length():
			_chars = _text.text.length()
		else:
			_next()


func _finish() -> void:
	if _leaving or _guest:
		return
	_leaving = true
	Audio.play("menu_select")
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.4)
	t.tween_callback(func():
		var start: Dictionary = Global.play_start
		if _online:
			Net.start_game(start)
		Global.start_game(start))


func _draw_art() -> void:
	var k := minf(1.0, _t / 1.2)
	match _art_kind:
		"boss":
			var y := lerpf(-200, 330, 1.0 - pow(1.0 - k, 3))
			UI.draw_sprite(_art, preload("res://assets/sprites/boss/boss.png"), Vector2(960, y), 1.15, sin(_t * 0.9) * 0.03, Color(1, 1, 1, k))
			UI.draw_sprite(_art, preload("res://assets/sprites/boss/eye_calm.png"), Vector2(960, y - 9), 1.15, 0.0, Color(1, 1, 1, k))
		"swarm":
			var f := int(_t * 2) % 2
			for r in 4:
				for c in 11:
					var tex: Texture2D = _swarm_tex[(r + c) % _swarm_tex.size()][f]
					var x := 960 + (c - 5) * 120 + sin(_t * 0.8 + r) * 30
					var yy := 140 + r * 100 + _t * 12
					UI.draw_sprite(_art, tex, Vector2(x, yy), 0.9, 0.0, Color(1, 1, 1, k * 0.95))
		"ship":
			var y2 := lerpf(1200, 560, 1.0 - pow(1.0 - k, 3)) + sin(_t * 2) * 8
			UI.draw_sprite(_art, Global.ship_texture(0), Vector2(960, y2), 1.6, sin(_t * 1.3) * 0.05)
		"squadron":
			var n := _ships.size()
			for i in n:
				var x := 960 + (i - (n - 1) / 2.0) * 260
				var y3 := lerpf(1200, 560 + absf(i - (n - 1) / 2.0) * 60, 1.0 - pow(1.0 - minf(1.0, maxf(0.0, _t - i * 0.15) / 1.2), 3))
				UI.draw_sprite(_art, _ships[i], Vector2(x, y3 + sin(_t * 2 + i) * 8), 1.2, sin(_t * 1.3 + i) * 0.05)
