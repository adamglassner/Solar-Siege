extends Node2D
## Main menu: Continue, New Game, Options, Multiplayer (coming soon) and Exit.

const KINDS := ["drone", "crab", "squid", "beetle", "wraith"]

@onready var _stars: Starfield = $Stars
@onready var _drifters: Node2D = $Drifters
@onready var _ship: Sprite2D = $HeroShip
@onready var _title: TextureRect = $UI/Title
@onready var _buttons_root: Control = $UI/Buttons

var _t := 0.0
var _spawn_t := 1.0
var _drift: Array = [] # [pos, vel, rot, vr, scale, textures]
var _buttons: Array = []
var _continue_info: Control
var _subtitle: Label


func _ready() -> void:
	_stars.setup(6 * 977 + 13)
	Audio.play_music(Audio.music("menu"))
	_drifters.draw.connect(_draw_drifters)
	var ui := $UI
	_subtitle = UI.place(UI.label("DEFEND THE SOLAR SYSTEM", 30, "bold", Color("#cfe4ff"), 14, HORIZONTAL_ALIGNMENT_CENTER, Color(0.47, 0.75, 1, 0.45), 8), 960, 300)
	ui.add_child(_subtitle)
	var hi := Global.high_score()
	if hi > 0:
		ui.add_child(UI.place(UI.label("HIGH SCORE  " + UI.format_score(hi), 22, "extrabold", Color("#ffd76b"), 3), 40, 1040, 600))
	ui.add_child(UI.place(UI.label("v" + Global.version() + "  ·  © 2026 Ironite", 22, "bold", Color(0.78, 0.86, 1, 0.6), 0, HORIZONTAL_ALIGNMENT_RIGHT), 1880, 1040, 600))
	_build()


func _build() -> void:
	for c in _buttons_root.get_children():
		c.queue_free()
	_buttons.clear()
	var save := Global.load_game()
	var items := []
	if not save.is_empty():
		items.append(["Continue", func(): Global.start_game(Global.load_game())])
	items.append(["New Game", _new_game])
	items.append(["Options", func(): OptionsMenu.open()])
	items.append(["Multiplayer", func(): Global.toast("Multiplayer is coming in a future update!")])
	items.append(["Credits", func(): InfoScreen.open_credits()])
	items.append(["Changelog", func(): InfoScreen.open_changelog()])
	items.append(["Exit", _exit_game])
	var step := 74.0
	var y := 372.0 if not save.is_empty() else 400.0
	for i in items.size():
		var b := GameButton.make(items[i][0], items[i][1], 620, 62)
		b.position = Vector2(960 - 310, y + i * step)
		if items[i][0] == "Multiplayer":
			b.locked = true
		_buttons_root.add_child(b)
		if b.locked:
			b.add_badge("COMING SOON")
		_buttons.append(b)
	GameButton.link_vertical(_buttons)
	_continue_info = null
	if not save.is_empty():
		var p := NinePatchRect.new()
		p.texture = load("res://assets/ui/panel_flat.png")
		for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
			p.set(m, 16)
		p.position = Vector2(960 - 310, y + items.size() * step + 4)
		p.size = Vector2(620, 60)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lv: LevelData = Global.levels[save.level]
		var txt := "Planet %d: %s  ·  Score %s  ·  %s" % [save.level + 1, lv.planet, UI.format_score(save.score), Global.DIFFICULTY[save.difficulty].label]
		var l := UI.label(txt, 22, "bold", Color("#bfe8ff"), 0, HORIZONTAL_ALIGNMENT_CENTER)
		l.size = p.size
		p.add_child(l)
		_buttons_root.add_child(p)
		_continue_info = p
		_buttons[0].focus_entered.connect(func(): _continue_info.visible = true)
		_buttons[0].focus_exited.connect(func(): _continue_info.visible = false)
	_buttons[0].focus_quietly()


func _new_game() -> void:
	if not Global.load_game().is_empty():
		Dialog.open("Start New Game?", ["Your saved progress will be overwritten."], [
			["Start New Game", func():
				Dialog.close_top()
				_choose_difficulty()],
			["Cancel", Dialog.close_top],
		])
	else:
		_choose_difficulty()


func _choose_difficulty() -> void:
	var items := []
	for d in ["easy", "normal", "hard"]:
		var info: Dictionary = Global.DIFFICULTY[d]
		items.append(["%s  ·  %d ships" % [info.label, info.lives], func():
			Global.clear_game()
			Global.start_game({"level": 0, "score": 0, "lives": info.lives, "bombs": 1, "difficulty": d})])
	items.append(["Back", Dialog.close_top])
	Dialog.open("Select Difficulty", ["Choose how fierce the invasion will be."], items)


func _exit_game() -> void:
	Dialog.open("Exit Solar Siege?", [], [
		["Exit", Global.quit_game],
		["Cancel", Dialog.close_top],
	], 620)


func _process(dt: float) -> void:
	_t += dt
	_title.position.y = 70 + sin(_t * 1.2) * 6
	_subtitle.position.y = 300 - _subtitle.size.y / 2 + sin(_t * 1.2) * 6
	_ship.position.y = 820 + sin(_t * 2.0) * 10
	_ship.rotation = sin(_t * 1.3) * 0.06
	_spawn_t -= dt
	if _spawn_t <= 0:
		_spawn_t = randf_range(2.5, 5.0)
		var left := randf() < 0.5
		var kind: String = KINDS.pick_random()
		var tex := [load("res://assets/sprites/aliens/%s_0_0.png" % kind), load("res://assets/sprites/aliens/%s_0_1.png" % kind)]
		_drift.append([Vector2(-80 if left else 2000, randf_range(140, 880)), Vector2((1 if left else -1) * randf_range(60, 130), randf_range(-15, 15)),
			0.0, randf_range(-0.3, 0.3), randf_range(0.7, 1.1), tex])
	var keep := []
	for d in _drift:
		d[0] += d[1] * dt
		d[2] += d[3] * dt
		if d[0].x > -200 and d[0].x < 2120:
			keep.append(d)
	_drift = keep
	_drifters.queue_redraw()


func _draw_drifters() -> void:
	var f := int(_t * 2) % 2
	for d in _drift:
		UI.draw_sprite(_drifters, d[5][f], d[0], d[4], d[2])
