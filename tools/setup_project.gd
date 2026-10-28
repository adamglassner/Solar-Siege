extends SceneTree
## Editor tool: (re)generates the input map, the UI theme and the level resources.
## Run from the project folder:  godot --headless --script res://tools/setup_project.gd

const LEVELS := [
	["Mercury", "The Scorched Frontier", "Closest world to the Sun. Daytime surface tops 430 °C.",
		["squid", "crab", "crab", "drone", "drone"], 9, 46, 0.45, 360, 0.0, 26, 0, "#8a7f78"],
	["Venus", "Beneath the Acid Clouds", "Its thick clouds trap heat, making it the hottest planet of all.",
		["squid", "crab", "crab", "drone", "drone"], 10, 54, 0.62, 380, 0.0, 24, 25, "#b39a5a"],
	["Earth", "Defend the Homeworld", "The only world known to harbour life. Make sure it stays that way.",
		["cruiser", "squid", "crab", "crab", "drone", "drone"], 10, 60, 0.88, 400, 0.01, 22, 100, "#5a8c63"],
	["Mars", "The Red Siege", "Home to Olympus Mons, a volcano nearly three times the height of Everest.",
		["squid", "squid", "beetle", "crab", "drone", "drone"], 10, 66, 1.05, 420, 0.03, 21, -20, "#9a4b33"],
	["Jupiter", "Storm of the Giant", "Its Great Red Spot is a storm wider than the entire Earth.",
		["cruiser", "squid", "beetle", "beetle", "crab", "drone"], 11, 72, 1.25, 440, 0.05, 20, 30, "#a07850"],
	["Saturn", "Battle of the Rings", "Its rings are mostly water ice, yet only about ten metres thick.",
		["wraith", "squid", "beetle", "crab", "crab", "drone"], 11, 78, 1.45, 460, 0.07, 19, 50, "#a89a6e"],
	["Uranus", "The Sideways World", "Tipped on its side, each pole gets 42 years of sunlight, then 42 of night.",
		["cruiser", "wraith", "squid", "beetle", "crab", "drone"], 11, 84, 1.65, 480, 0.09, 18, 160, "#5a9ea0"],
	["Neptune", "Winds of the Abyss", "Supersonic winds here reach 2,100 km/h, the fastest in the solar system.",
		["wraith", "wraith", "beetle", "beetle", "crab", "crab"], 11, 90, 1.85, 500, 0.11, 17, 200, "#3e5fa8"],
	["Pluto", "The Edge of Darkness", "At the frozen edge of the system, the invasion's mothership awaits.",
		["cruiser", "wraith", "wraith", "beetle", "squid", "crab"], 11, 96, 2.05, 520, 0.13, 16, 280, "#9a8a9e"],
]


func _init() -> void:
	_inputs()
	_levels()
	_theme()
	ProjectSettings.set_setting("gui/theme/custom", "res://assets/ui/theme.tres")
	ProjectSettings.save()
	print("setup complete")
	quit()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _inputs() -> void:
	var actions := {
		"move_left": [_key(KEY_LEFT), _key(KEY_A), _joy(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_RIGHT), _key(KEY_D), _joy(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"fire": [_key(KEY_SPACE), _key(KEY_Z), _joy(JOY_BUTTON_A)],
		"bomb": [_key(KEY_B), _key(KEY_SHIFT), _joy(JOY_BUTTON_B)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_BUTTON_START)],
	}
	for name in actions:
		ProjectSettings.set_setting("input/" + name, {"deadzone": 0.35, "events": actions[name]})


func _levels() -> void:
	for i in LEVELS.size():
		var d: Array = LEVELS[i]
		var lv := LevelData.new()
		var slug := String(d[0]).to_lower()
		lv.planet = d[0]
		lv.tagline = d[1]
		lv.fact = d[2]
		lv.rows = PackedStringArray(d[3])
		lv.cols = d[4]
		lv.speed = d[5]
		lv.fire_rate = d[6]
		lv.bullet_speed = d[7]
		lv.dive_chance = d[8]
		lv.saucer_every = d[9]
		lv.hue_shift = d[10]
		lv.alien_tint = i
		var base := Color.html(d[11])
		lv.bunker_dust = Color.from_hsv(base.h, 0.3, 0.65)
		lv.background = load("res://assets/backgrounds/%s.png" % slug)
		lv.bunker_texture = load("res://assets/bunkers/%s.png" % slug)
		lv.music = load("res://assets/audio/music/%s.wav" % slug)
		lv.boss = slug == "pluto"
		ResourceSaver.save(lv, "res://data/levels/%02d_%s.tres" % [i + 1, slug])


func _sbt(path: String, pad: int, margin: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_texture_margin(side, pad + margin)
		s.set_expand_margin(side, pad)
		s.set_content_margin(side, 14)
	return s


func _font(path: String, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.spacing_glyph = spacing
	return f


func _theme() -> void:
	var t := Theme.new()
	t.default_font = _font("res://assets/fonts/Inter-Bold.ttf", 0)
	t.default_font_size = 26
	var btn_font := _font("res://assets/fonts/Inter-ExtraBold.ttf", 4)
	ResourceSaver.save(btn_font, "res://assets/fonts/button_font.tres")
	var normal := _sbt("res://assets/ui/button_normal.png", 4, 14)
	var focus := _sbt("res://assets/ui/button_focus.png", 30, 14)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", focus)
	t.set_stylebox("hover_pressed", "Button", focus)
	t.set_stylebox("disabled", "Button", normal)
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", btn_font)
	t.set_font_size("font_size", "Button", 30)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.78, 0.82, 0.9, 0.45))
	t.set_stylebox("panel", "PanelContainer", _sbt("res://assets/ui/panel.png", 30, 14))
	t.set_color("font_color", "Label", Color.WHITE)
	ResourceSaver.save(t, "res://assets/ui/theme.tres")
