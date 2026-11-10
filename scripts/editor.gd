extends Node2D
## Level Editor: paint an alien formation on a grid, pick the backdrop, music and how
## hard the map plays, then save it, test it, or play it solo or with friends.
## Maps are saved in the user folder (see CustomMaps); the nine planets are never changed.

const GRID_POS := Vector2(330, 120)
const SPEEDS := [["Slow", 40.0], ["Normal", 55.0], ["Fast", 70.0], ["Very Fast", 90.0], ["Insane", 115.0]]
const FIRES := [["Ceasefire", 0.0], ["Light", 0.5], ["Normal", 1.0], ["Heavy", 1.6], ["Brutal", 2.4]]
const SHOTS := [["Slow", 320.0], ["Normal", 420.0], ["Fast", 540.0]]
const DIVERS := [["Off", 0.0], ["Few", 0.02], ["Some", 0.06], ["Many", 0.12]]
const TOOLS := [["drone", "Drone", "1 hit"], ["crab", "Crab", "1 hit"], ["squid", "Squid", "aimed shots"],
	["beetle", "Beetle", "2 hits"], ["wraith", "Wraith", "3 hits · spread"], ["cruiser", "Cruiser", "7 hits · 2 cells"], ["", "Eraser", "right-click"]]

var map: Dictionary
var path := ""
var dirty := false
var _grid: EditorGrid
var _name: LineEdit
var _tool_buttons: Array = []
var _count: Label
var _choices := {}
var _root: Control


func _ready() -> void:
	_root = $UI/Root
	map = CustomMaps.validate(Global.editor_map) if not Global.editor_map.is_empty() else CustomMaps.blank()
	path = Global.editor_path
	dirty = Global.lobby_memory.get("editor_dirty", false)
	$Preview.draw.connect(_draw_preview)
	_build()
	_apply_look()
	_update_count()


func _closest(list: Array, v: float) -> int:
	var best := 0
	for i in list.size():
		if absf(list[i][1] - v) < absf(list[best][1] - v):
			best = i
	return best


func _build() -> void:
	_root.add_child(UI.place(UI.label("LEVEL EDITOR", 40, "black", Color.WHITE, 8, HORIZONTAL_ALIGNMENT_LEFT, Color(0.35, 0.75, 1, 0.6), 10), 34, 52, 400))
	_name = LineEdit.new()
	_name.text = map.name
	_name.placeholder_text = "Map name"
	_name.max_length = 32
	_name.position = Vector2(470, 24)
	_name.size = Vector2(620, 58)
	_name.add_theme_font_override("font", UI.font("extrabold"))
	_name.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/panel_flat.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 16)
	sb.content_margin_left = 20
	_name.add_theme_stylebox_override("normal", sb)
	_name.add_theme_stylebox_override("focus", sb)
	_name.text_changed.connect(func(t):
		map.name = t
		_mark())
	_root.add_child(_name)
	var save := GameButton.make("Save", _save, 200, 58)
	save.position = Vector2(1120, 24)
	var test := GameButton.make("Test Play", _test, 250, 58)
	test.position = Vector2(1336, 24)
	var back := GameButton.make("Back", _back, 250, 58)
	back.position = Vector2(1602, 24)
	for b in [save, test, back]:
		b.add_theme_font_size_override("font_size", 24)
		_root.add_child(b)

	# palette
	_root.add_child(UI.place(UI.label("ALIENS", 20, "extrabold", Color("#8fe9ff"), 6), 34, 124, 300))
	for i in TOOLS.size():
		var t: Array = TOOLS[i]
		var b := GameButton.make("", func(): _select_tool(i), 270, 76)
		b.position = Vector2(30, 150 + i * 86)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_root.add_child(b)
		if t[0] != "":
			var icon := TextureRect.new()
			icon.texture = load("res://assets/sprites/aliens/%s_%d_0.png" % [t[0], map.tint])
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(10, 8)
			icon.size = Vector2(70, 60)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(icon)
		var l1 := UI.label("%s  %s" % [str(i + 1) if i < 6 else "0", t[1].to_upper()], 22, "extrabold")
		l1.position = Vector2(92, 10)
		l1.size = Vector2(170, 30)
		b.add_child(l1)
		var l2 := UI.label(t[2], 16, "medium", Color("#a8bede"))
		l2.position = Vector2(92, 40)
		l2.size = Vector2(170, 24)
		b.add_child(l2)
		_tool_buttons.append(b)

	# grid
	_grid = EditorGrid.new()
	_grid.map = map
	_grid.tint = map.tint
	_grid.position = GRID_POS
	_grid.size = Vector2(_grid.cell.x * CustomMaps.MAX_COLS, _grid.cell.y * CustomMaps.MAX_ROWS)
	_grid.edited.connect(func():
		_mark()
		_update_count()
		$Preview.queue_redraw())
	_root.add_child(_grid)
	_count = UI.place(UI.label("", 22, "bold", Color("#cfe6ff"), 1), GRID_POS.x, GRID_POS.y + _grid.size.y + 22, 700)
	_root.add_child(_count)
	var help := "Left-click paints · Right-click erases · 1–6 pick an alien, 0 the eraser · Arrows + Space also paint · X erases"
	_root.add_child(UI.place(UI.label(help, 18, "medium", Color(0.8, 0.88, 1, 0.65), 0, HORIZONTAL_ALIGNMENT_RIGHT), GRID_POS.x + _grid.size.x, GRID_POS.y + _grid.size.y + 22, 900))

	# settings
	var sx := 1460.0
	var sy := 124.0
	_root.add_child(UI.place(UI.label("MAP SETTINGS", 20, "extrabold", Color("#8fe9ff"), 6), sx, sy, 400))
	var planets := CustomMaps.PLANETS.map(func(p): return p.capitalize())
	var musics := CustomMaps.MUSIC.map(func(m): return {"boss": "Boss Battle", "menu": "Main Theme"}.get(m, m.capitalize()))
	var rows := [
		["backdrop", "Backdrop", planets, CustomMaps.PLANETS.find(map.backdrop)],
		["music", "Music", musics, CustomMaps.MUSIC.find(map.music)],
		["tint", "Aliens", planets, map.tint],
		["speed", "March", SPEEDS.map(func(s): return s[0]), _closest(SPEEDS, map.speed)],
		["fire_rate", "Fire", FIRES.map(func(s): return s[0]), _closest(FIRES, map.fire_rate)],
		["bullet_speed", "Shots", SHOTS.map(func(s): return s[0]), _closest(SHOTS, map.bullet_speed)],
		["dive_chance", "Divers", DIVERS.map(func(s): return s[0]), _closest(DIVERS, map.dive_chance)],
		["saucer", "Saucer", ["Off", "On"], 1 if map.saucer else 0],
		["shields", "Shields", ["None", "1", "2", "3", "4"], map.shields],
		["boss", "Boss at End", ["No", "Yes"], 1 if map.boss else 0],
	]
	var focus_chain := []
	for i in rows.size():
		var r: Array = rows[i]
		var c := ChoiceButton.make_choice(r[1], r[2], maxi(0, r[3]), 430, 56)
		c.position = Vector2(sx, sy + 28 + i * 66)
		var key: String = r[0]
		c.changed.connect(func(idx): _set_option(key, idx))
		_root.add_child(c)
		_choices[key] = c
		focus_chain.append(c)
	var clear := GameButton.make("Clear Grid", _clear, 430, 56)
	clear.position = Vector2(sx, sy + 28 + rows.size() * 66 + 8)
	clear.add_theme_font_size_override("font_size", 24)
	_root.add_child(clear)
	focus_chain.append(clear)
	GameButton.link_vertical(focus_chain)
	GameButton.link_vertical(_tool_buttons)
	for b in _tool_buttons:
		b.focus_neighbor_right = b.get_path_to(_grid)
	for c2 in focus_chain:
		c2.focus_neighbor_left = c2.get_path_to(_grid)
	_grid.focus_neighbor_left = _grid.get_path_to(_tool_buttons[0])
	_grid.focus_neighbor_right = _grid.get_path_to(focus_chain[0])
	_grid.focus_neighbor_top = _grid.get_path_to(save)
	_select_tool(1, true)
	_grid.grab_focus()


func _set_option(key: String, idx: int) -> void:
	match key:
		"backdrop":
			map.backdrop = CustomMaps.PLANETS[idx]
		"music":
			map.music = CustomMaps.MUSIC[idx]
			Audio.play_music(load("res://assets/audio/music/%s.wav" % map.music))
		"tint":
			map.tint = idx
			_grid.tint = idx
			for i in 6:
				var icon: TextureRect = _tool_buttons[i].get_child(0)
				icon.texture = load("res://assets/sprites/aliens/%s_%d_0.png" % [TOOLS[i][0], idx])
		"speed":
			map.speed = SPEEDS[idx][1]
		"fire_rate":
			map.fire_rate = FIRES[idx][1]
		"bullet_speed":
			map.bullet_speed = SHOTS[idx][1]
		"dive_chance":
			map.dive_chance = DIVERS[idx][1]
		"saucer":
			map.saucer = idx == 1
		"shields":
			map.shields = idx
		"boss":
			map.boss = idx == 1
	_mark()
	_apply_look()


func _apply_look() -> void:
	var bd := CustomMaps.PLANETS.find(map.backdrop)
	$Background.texture = load("res://assets/backgrounds/%s.png" % map.backdrop)
	$Stars.setup(bd * 977 + 13)
	if not Audio._music.playing or not Audio._music_path.ends_with("/%s.wav" % map.music):
		Audio.play_music(load("res://assets/audio/music/%s.wav" % map.music))
	_grid.queue_redraw()
	$Preview.queue_redraw()


func _select_tool(i: int, quiet := false) -> void:
	_grid.tool = TOOLS[i][0]
	for j in _tool_buttons.size():
		_tool_buttons[j].self_modulate = Color(1.0, 0.85, 0.45) if j == i else Color.WHITE
		var l: Label = _tool_buttons[j].get_child(_tool_buttons[j].get_child_count() - 2)
		l.label_settings = UI.settings(22, "extrabold", Color("#ffd76b") if j == i else Color.WHITE)
	if not quiet:
		Audio.play("menu_move")
	_grid.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name.has_focus():
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_6:
			_select_tool(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_0:
			_select_tool(6)
			get_viewport().set_input_as_handled()
		elif k == KEY_S and event.ctrl_pressed:
			_save()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var cur := TOOLS.map(func(t): return t[0]).find(_grid.tool)
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_select_tool(posmod(cur - 1, TOOLS.size()))
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_select_tool(posmod(cur + 1, TOOLS.size()))
	if event.is_action_pressed("ui_cancel") and Dialog._stack.is_empty():
		get_viewport().set_input_as_handled()
		_back()


func _mark() -> void:
	dirty = true
	Global.lobby_memory["editor_dirty"] = true


func _update_count() -> void:
	var n := CustomMaps.count_aliens(map)
	_count.text = "%d aliens%s" % [n, "  ·  place at least one to play" if n == 0 else ""]


func _clear() -> void:
	Dialog.open("Clear the Grid?", ["Every alien on this map will be removed."], [
		["Clear", func():
			Dialog.close_top()
			for r in map.grid:
				r.fill("")
			_mark()
			_update_count()
			_grid.queue_redraw()
			$Preview.queue_redraw()],
		["Cancel", Dialog.close_top],
	])


func _save() -> bool:
	if map.name.strip_edges() == "":
		map.name = "Untitled Map"
		_name.text = map.name
	if CustomMaps.count_aliens(map) == 0:
		Global.toast("Place at least one alien first.")
		Audio.play("denied")
		return false
	var p := CustomMaps.save_map(map, path)
	if p == "":
		Global.toast("Couldn't save the map.")
		return false
	path = p
	dirty = false
	Global.lobby_memory["editor_dirty"] = false
	Global.editor_map = map.duplicate(true)
	Global.editor_path = path
	Global.toast("Saved \"%s\"" % map.name)
	Achievements.unlock("architect")
	return true


func _test() -> void:
	if CustomMaps.count_aliens(map) == 0:
		Global.toast("Place at least one alien first.")
		Audio.play("denied")
		return
	Global.editor_map = map.duplicate(true)
	Global.editor_path = path
	Global.start_game({"level": 0, "score": 0, "lives": 3, "bombs": 1, "difficulty": "normal", "custom": map.duplicate(true), "from_editor": true})


func _back() -> void:
	var leave := func():
		Global.editor_map = {}
		Global.editor_path = ""
		Global.lobby_memory["editor_dirty"] = false
		Global.goto_scene("res://scenes/maps.tscn")
	if not dirty:
		leave.call()
		return
	Dialog.open("Save Changes?", ["This map has changes that aren't saved."], [
		["Save", func():
			Dialog.close_top()
			if _save():
				leave.call()],
		["Don't Save", leave],
		["Cancel", Dialog.close_top],
	])


func _draw_preview() -> void:
	## shields and the player's ship under the grid, to judge the layout
	var ci: Node2D = $Preview
	var lv: LevelData = Global.levels[maxi(0, CustomMaps.PLANETS.find(map.backdrop))]
	var n: int = map.shields
	var area := Rect2(GRID_POS.x, 700, _grid.size.x, 300)
	for i in n:
		var cx := area.position.x + area.size.x * (i + 1) / (n + 1)
		var w := 200.0 * 0.6
		ci.draw_texture_rect(lv.bunker_texture, Rect2(cx - w / 2, 760, w, 110 * 0.6), false)
	UI.draw_sprite(ci, Global.ship_texture(int(Global.settings.color)), Vector2(area.get_center().x, 940), 0.7)
