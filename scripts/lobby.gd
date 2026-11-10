extends Node2D
## Multiplayer lobby, laid out like Chess and Checkers: "Same Computer" or "Online".
## Same Computer: up to four players, each joins by pressing A on their own controller
## (one player may use the keyboard instead). Online: host a game or join one by address.
## Every player picks a ship colour; two players can't share a colour.

const SLOT_W := 360.0
const SLOT_H := 330.0

var tab := "local"
var _root: Control
var _content: Control
var _players_box: Control
var _tab_buttons: Array = []

# same computer
var local_slots: Array = [] # [{device: -1 keyboard / n controller, color}]
# shared choices
var _maps: Array = [] # [{name, data}]
var game_index := 0
var diff_index := 1
var _game_choice: ChoiceButton
var _diff_choice: ChoiceButton
var _start_btn: GameButton
# online
var _name_edit: LineEdit
var _addr_edit: LineEdit
var _color_choice: ChoiceButton
var _status: Label
var _last_status := ""

const DIFFS := ["easy", "normal", "hard"]


func _ready() -> void:
	$Stars.setup(4242)
	Audio.play_music(Audio.music("menu"))
	_root = $UI/Root
	_maps = CustomMaps.list()
	var mem: Dictionary = Global.lobby_memory
	tab = mem.get("tab", "local")
	local_slots = mem.get("local_slots", []).duplicate(true)
	game_index = mem.get("game_index", 0)
	diff_index = mem.get("diff_index", 1)
	if mem.has("map_path"):
		for i in _maps.size():
			if _maps[i].path == mem.map_path:
				game_index = i + 1
		mem.erase("map_path")
	game_index = clampi(game_index, 0, _maps.size())
	_root.add_child(UI.place(UI.label("MULTIPLAYER", 60, "black", Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.35, 0.75, 1, 0.6), 12), 960, 78))
	_root.add_child(UI.place(UI.label("Up to four pilots fighting side by side. Every pilot has their own ship, lives and score.", 22, "medium", Color("#bcd0ee"), 0, HORIZONTAL_ALIGNMENT_CENTER), 960, 132))
	var t1 := GameButton.make("Same Computer", func(): _switch("local"), 400, 60)
	var t2 := GameButton.make("Online", func(): _switch("online"), 400, 60)
	t1.position = Vector2(960 - 410, 168)
	t2.position = Vector2(960 + 10, 168)
	_root.add_child(t1)
	_root.add_child(t2)
	_tab_buttons = [t1, t2]
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.failed.connect(func(why): _show_error(why))
	Net.host_left.connect(func(): _show_error("The host closed the game."))
	Net.peer_left.connect(func(n): Global.toast("%s left." % n))
	_switch(tab, true)


func _remember() -> void:
	Global.lobby_memory = {"tab": tab, "local_slots": local_slots.duplicate(true), "game_index": game_index, "diff_index": diff_index}


func _switch(t: String, first := false) -> void:
	if t == tab and not first:
		return
	if t != tab and Net.active():
		Net.leave()
	tab = t
	_build()


func _clear_content() -> void:
	for c in _content.get_children():
		c.queue_free()
	_players_box = null
	_game_choice = null
	_diff_choice = null
	_start_btn = null
	_name_edit = null
	_addr_edit = null
	_status = null


func _build() -> void:
	_clear_content()
	for i in 2:
		var on: bool = (i == 0) == (tab == "local")
		_tab_buttons[i].add_theme_color_override("font_color", Color("#ffd76b") if on else Color(0.8, 0.85, 0.95, 0.7))
		_tab_buttons[i].add_theme_color_override("font_focus_color", Color("#ffd76b") if on else Color.WHITE)
	if tab == "local":
		_build_local()
	else:
		_build_online()
	_remember()


# ---------------------------------------------------------------- shared bits
func _game_options() -> Array:
	var opts := ["Campaign · 9 planets"]
	for m in _maps:
		opts.append("Custom · " + m.name)
	return opts


func _add_game_choices(x: float, y: float, editable := true) -> float:
	_game_choice = ChoiceButton.make_choice("Game", _game_options(), game_index, 760)
	_game_choice.position = Vector2(x, y)
	_game_choice.read_only = not editable
	_game_choice.changed.connect(func(i):
		game_index = i
		_remember()
		_push_lobby())
	_content.add_child(_game_choice)
	_diff_choice = ChoiceButton.make_choice("Difficulty", ["Easy", "Normal", "Hard"], diff_index, 760)
	_diff_choice.position = Vector2(x, y + 74)
	_diff_choice.read_only = not editable
	_diff_choice.changed.connect(func(i):
		diff_index = i
		_remember()
		_push_lobby())
	_content.add_child(_diff_choice)
	return y + 148


func _chosen_map() -> Dictionary:
	return _maps[game_index - 1].data if game_index > 0 and game_index <= _maps.size() else {}


func _start_dict(m: String, players: Array) -> Dictionary:
	return {"mode": m, "players": players, "level": 0, "difficulty": DIFFS[diff_index], "custom": _chosen_map()}


func _focus_list(buttons: Array) -> void:
	var list := buttons.filter(func(b): return b != null and is_instance_valid(b))
	list.append_array(_tab_buttons)
	GameButton.link_vertical(list)


# ---------------------------------------------------------------- same computer
func _build_local() -> void:
	_players_box = Control.new()
	_players_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_players_box)
	_refresh_local_slots()
	var y := 640.0
	var kb := GameButton.make("Join with Keyboard", _toggle_keyboard, 480, 56)
	kb.position = Vector2(960 - 240, 590)
	_content.add_child(kb)
	y = _add_game_choices(960 - 380, 664)
	_start_btn = GameButton.make("Start Game", _start_local, 370, 64)
	_start_btn.position = Vector2(960 - 380, y + 6)
	_content.add_child(_start_btn)
	var back := GameButton.make("Back", _back, 370, 64)
	back.position = Vector2(960 + 10, y + 6)
	_content.add_child(back)
	_focus_list([kb, _game_choice, _diff_choice, _start_btn, back])
	_content.add_child(UI.place(UI.label("Each player presses  A  on their own controller to join  ·  LB / RB changes your colour  ·  B leaves",
		20, "bold", Color(0.82, 0.9, 1, 0.75), 1, HORIZONTAL_ALIGNMENT_CENTER), 960, 1046))
	_start_btn.focus_quietly()


func _refresh_local_slots() -> void:
	if _players_box == null:
		return
	for c in _players_box.get_children():
		c.queue_free()
	var x0 := 960 - (4 * SLOT_W + 3 * 24) / 2.0
	for i in 4:
		var x := x0 + i * (SLOT_W + 24)
		var card := NinePatchRect.new()
		card.texture = load("res://assets/ui/panel_flat.png")
		for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
			card.set(m, 16)
		card.position = Vector2(x, 248)
		card.size = Vector2(SLOT_W, SLOT_H)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_players_box.add_child(card)
		if i < local_slots.size():
			var s: Dictionary = local_slots[i]
			var col := Global.ship_color(s.color, 72)
			card.self_modulate = Color(1, 1, 1, 1)
			var ship := TextureRect.new()
			ship.texture = Global.ship_texture(s.color)
			ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ship.position = Vector2(SLOT_W / 2 - 90, 34)
			ship.size = Vector2(180, 160)
			ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(ship)
			var name_l := UI.label("PLAYER %d" % (i + 1), 30, "black", col, 4, HORIZONTAL_ALIGNMENT_CENTER)
			name_l.size = Vector2(SLOT_W, 40)
			name_l.position = Vector2(0, 202)
			card.add_child(name_l)
			var dev := UI.label("Keyboard" if s.device < 0 else "Controller %d" % (s.device + 1), 20, "medium", Color("#bcd0ee"), 0, HORIZONTAL_ALIGNMENT_CENTER)
			dev.size = Vector2(SLOT_W, 30)
			dev.position = Vector2(0, 240)
			card.add_child(dev)
			var colr := UI.label("‹  %s  ›" % Global.SHIP_COLORS[s.color][1].to_upper(), 22, "extrabold", col, 3, HORIZONTAL_ALIGNMENT_CENTER)
			colr.size = Vector2(SLOT_W, 34)
			colr.position = Vector2(0, 278)
			card.add_child(colr)
			var arrows := Control.new() # clickable halves to change colour with the mouse
			arrows.position = Vector2(0, 270)
			arrows.size = Vector2(SLOT_W, 50)
			arrows.mouse_filter = Control.MOUSE_FILTER_STOP
			arrows.gui_input.connect(func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					_cycle_color(i, -1 if e.position.x < SLOT_W / 2 else 1))
			card.add_child(arrows)
		else:
			card.self_modulate = Color(1, 1, 1, 0.45)
			var l := UI.label("PRESS  A\nTO JOIN", 30, "black", Color(0.8, 0.88, 1, 0.55 + 0.25 * float(i == local_slots.size())), 6, HORIZONTAL_ALIGNMENT_CENTER)
			l.size = Vector2(SLOT_W, SLOT_H)
			card.add_child(l)
	_update_start()


func _update_start() -> void:
	if _start_btn == null:
		return
	var n := local_slots.size() if tab == "local" else Net.players.size()
	var can := n >= 2 and (tab == "local" or Net.is_host())
	_start_btn.locked = not can
	_start_btn.add_theme_color_override("font_color", Color.WHITE if can else Color(0.78, 0.82, 0.9, 0.45))


func _taken(color: int, except := -1) -> bool:
	for i in local_slots.size():
		if i != except and local_slots[i].color == color:
			return true
	return false


func _first_free_color(start := 0) -> int:
	for k in Global.SHIP_COLORS.size():
		var c := (start + k) % Global.SHIP_COLORS.size()
		if not _taken(c):
			return c
	return 0


func _slot_of(device: int) -> int:
	for i in local_slots.size():
		if local_slots[i].device == device:
			return i
	return -1


func _join_local(device: int) -> void:
	if _slot_of(device) >= 0:
		return
	if local_slots.size() >= 4:
		Global.toast("All four ships are taken.")
		Audio.play("denied")
		return
	local_slots.append({"device": device, "color": _first_free_color(local_slots.size())})
	Audio.play("pu_shield")
	_refresh_local_slots()
	_remember()


func _leave_local(i: int) -> void:
	local_slots.remove_at(i)
	Audio.play("menu_back")
	_refresh_local_slots()
	_remember()


func _toggle_keyboard() -> void:
	var i := _slot_of(-1)
	if i >= 0:
		_leave_local(i)
	else:
		_join_local(-1)


func _cycle_color(i: int, dir: int) -> void:
	if i >= local_slots.size():
		return
	var c: int = local_slots[i].color
	for k in Global.SHIP_COLORS.size():
		c = posmod(c + dir, Global.SHIP_COLORS.size())
		if not _taken(c, i):
			break
	local_slots[i].color = c
	Audio.play("menu_move")
	_refresh_local_slots()
	_remember()


func _start_local() -> void:
	if local_slots.size() < 2:
		Global.toast("At least two players need to join. Press A on each controller.")
		return
	var players := []
	for i in local_slots.size():
		var s: Dictionary = local_slots[i]
		players.append({"name": "Player %d" % (i + 1), "color": s.color, "input": "kb" if s.device < 0 else "pad:%d" % s.device})
	var start := _start_dict("local", players)
	_remember()
	if start.custom.is_empty():
		Global.start_with_story(start, "multi")
	else:
		Global.start_game(start)


func _input(event: InputEvent) -> void:
	if tab != "local" or Dialog._stack.size() > 0:
		return
	if event is InputEventJoypadButton and event.pressed:
		var dev: int = event.device
		var slot := _slot_of(dev)
		if slot < 0 and event.button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_join_local(dev)
		elif slot >= 0 and event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			_leave_local(slot)
		elif slot >= 0 and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_cycle_color(slot, -1)
		elif slot >= 0 and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_cycle_color(slot, 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var slot := _slot_of(-1)
		if slot >= 0 and event.physical_keycode == KEY_Q:
			_cycle_color(slot, -1)
		elif slot >= 0 and event.physical_keycode == KEY_E:
			_cycle_color(slot, 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play("menu_back")
		_back()


func _back() -> void:
	Net.leave()
	_remember()
	Global.goto_menu()


# ---------------------------------------------------------------- online
func _build_online() -> void:
	var lx := 160.0
	var col_w := 760.0
	var rx := 1000.0
	var y := 262.0
	_content.add_child(UI.place(UI.label("YOUR PILOT", 24, "extrabold", Color("#8fe9ff"), 6), lx, y, 400))
	_name_edit = _line_edit(Global.pilot_name(), "Your name")
	_name_edit.position = Vector2(lx, y + 30)
	_name_edit.size = Vector2(col_w, 58)
	_name_edit.editable = not Net.active()
	_name_edit.text_changed.connect(func(t):
		Global.settings.name = t
		Global.save_settings())
	_content.add_child(_name_edit)
	var names := Global.SHIP_COLORS.map(func(c): return c[1])
	_color_choice = ChoiceButton.make_choice("Ship Colour", names, _my_color(), col_w)
	_color_choice.position = Vector2(lx, y + 104)
	_color_choice.changed.connect(func(i):
		Global.settings.color = i
		Global.save_settings()
		if Net.active():
			Net.set_my_color(i)
		_refresh_online_players())
	_content.add_child(_color_choice)
	var buttons := [_color_choice]
	y += 196
	if not Net.active():
		var host := GameButton.make("Host a Game", _host, col_w, 64)
		host.position = Vector2(lx, y)
		_content.add_child(host)
		_content.add_child(UI.place(UI.label("HOST'S ADDRESS", 20, "extrabold", Color("#8fe9ff"), 6), lx, y + 104, 400))
		_addr_edit = _line_edit(str(Global.settings.last_host), "e.g. 192.168.1.20")
		_addr_edit.position = Vector2(lx, y + 130)
		_addr_edit.size = Vector2(col_w, 58)
		_addr_edit.text_submitted.connect(func(_t): _join())
		_content.add_child(_addr_edit)
		var join := GameButton.make("Join a Game", _join, col_w, 64)
		join.position = Vector2(lx, y + 202)
		_content.add_child(join)
		var back := GameButton.make("Back", _back, col_w, 64)
		back.position = Vector2(lx, y + 286)
		_content.add_child(back)
		buttons.append_array([host, join, back])
		var help := "Play friends over the internet or on your home network. One of you hosts; the others choose Join a Game and type the host's address.\n\nHosting over the internet? Forward UDP port %d on your router to this computer. If Windows asks about the firewall the first time you host, choose Allow." % Net.PORT
		var hl := UI.label(help, 22, "medium", Color("#c8d8f0"))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		hl.position = Vector2(rx, 290)
		hl.size = Vector2(760, 400)
		_content.add_child(hl)
		_focus_list(buttons)
		host.focus_quietly()
	else:
		if Net.is_host():
			var ips := Net.local_ips()
			var addr_text := "Give your friends this address:  " + ("   or   ".join(ips) if ips.size() else "(no network found)")
			_content.add_child(UI.place(UI.label(addr_text, 26, "extrabold", Color("#ffd76b")), lx, y + 6, 1700))
			_content.add_child(UI.place(UI.label("They choose Online → Join a Game and type it in. Port %d (UDP)." % Net.PORT, 20, "medium", Color("#bcd0ee")), lx, y + 42, 1600))
			var yy := _add_game_choices(lx, y + 80, true)
			_start_btn = GameButton.make("Start Game", _start_online, 370, 64)
			_start_btn.position = Vector2(lx, yy + 6)
			_content.add_child(_start_btn)
			var cancel := GameButton.make("Stop Hosting", _stop_online, 370, 64)
			cancel.position = Vector2(lx + 390, yy + 6)
			_content.add_child(cancel)
			buttons.append_array([_game_choice, _diff_choice, _start_btn, cancel])
			_focus_list(buttons)
			_start_btn.focus_quietly()
		else:
			_status = UI.place(UI.label("Connecting…", 26, "extrabold", Color("#ffd76b")), lx, y + 6, 1600)
			_content.add_child(_status)
			var yy := _add_game_choices(lx, y + 80, false)
			var leave := GameButton.make("Leave", _stop_online, 370, 64)
			leave.position = Vector2(lx, yy + 6)
			_content.add_child(leave)
			buttons.append_array([_game_choice, _diff_choice, leave])
			_focus_list(buttons)
			leave.focus_quietly()
		_players_box = Control.new()
		_players_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(_players_box)
		_refresh_online_players()


func _line_edit(value: String, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = placeholder
	e.max_length = 40
	e.add_theme_font_override("font", UI.font("bold"))
	e.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/panel_flat.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 16)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("read_only", sb)
	e.add_theme_color_override("font_uneditable_color", Color(0.85, 0.9, 1, 0.75))
	var sf: StyleBoxTexture = sb.duplicate()
	sf.texture = load("res://assets/ui/button_focus.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sf.set_texture_margin(side, 44)
		sf.set_expand_margin(side, 30)
	e.add_theme_stylebox_override("focus", sf)
	e.add_theme_color_override("font_placeholder_color", Color(0.8, 0.86, 1, 0.4))
	return e


func _my_color() -> int:
	return clampi(int(Global.settings.color), 0, Global.SHIP_COLORS.size() - 1)


func _host() -> void:
	Global.settings.name = _name_edit.text
	Global.save_settings()
	var err := Net.host(Global.pilot_name(), _my_color())
	if err != "":
		_show_error(err)
		return
	_push_lobby()
	_build()


func _join() -> void:
	var addr := _addr_edit.text.strip_edges()
	Global.settings.name = _name_edit.text
	Global.settings.last_host = addr
	Global.save_settings()
	var err := Net.join(Global.pilot_name(), _my_color(), addr)
	if err != "":
		_show_error(err)
		return
	_build()


func _stop_online() -> void:
	Net.leave()
	_build()


func _push_lobby() -> void:
	if Net.is_host():
		Net.set_lobby("campaign" if game_index == 0 else "custom", _chosen_map(), DIFFS[diff_index])


func _on_lobby_changed() -> void:
	if tab != "online":
		return
	if not Net.active() and _players_box != null:
		_build() # disconnected
		return
	if Net.role == "guest":
		## mirror the host's choices
		if _game_choice:
			var opts := [("Custom · " + str(Net.lobby.map.get("name", ""))) if Net.lobby.kind == "custom" else "Campaign · 9 planets"]
			_game_choice.set_options(opts, 0)
		if _diff_choice:
			_diff_choice.set_options(["Easy", "Normal", "Hard"], DIFFS.find(Net.lobby.difficulty))
		if _status:
			_status.text = "Connected. Waiting for the host to start the game…" if Net.my_id > 1 else "Connecting…"
		for p in Net.players:
			if p.id == Net.my_id and _color_choice and _color_choice.index != p.color:
				_color_choice.set_options(_color_choice.options, p.color)
	_refresh_online_players()


func _refresh_online_players() -> void:
	if _players_box == null or tab != "online":
		return
	for c in _players_box.get_children():
		c.queue_free()
	var x := 1000.0
	var y := 470.0
	_players_box.add_child(UI.place(UI.label("PILOTS  %d / 4" % Net.players.size(), 24, "extrabold", Color("#8fe9ff"), 6), x, y - 10, 600))
	for i in 4:
		var row := NinePatchRect.new()
		row.texture = load("res://assets/ui/panel_flat.png")
		for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
			row.set(m, 16)
		row.position = Vector2(x, y + 24 + i * 96)
		row.size = Vector2(760, 84)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_players_box.add_child(row)
		if i < Net.players.size():
			var p: Dictionary = Net.players[i]
			var ship := TextureRect.new()
			ship.texture = Global.ship_texture(int(p.color))
			ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ship.position = Vector2(16, 6)
			ship.size = Vector2(90, 72)
			row.add_child(ship)
			var tag := "  (host)" if p.id == 1 else ""
			if p.id == Net.my_id:
				tag += "  (you)"
			var l := UI.label(str(p.name) + tag, 28, "extrabold", Global.ship_color(int(p.color), 75))
			l.position = Vector2(124, 0)
			l.size = Vector2(600, 84)
			row.add_child(l)
		else:
			row.self_modulate = Color(1, 1, 1, 0.4)
			var l := UI.label("Waiting for a pilot…", 22, "medium", Color(0.8, 0.86, 1, 0.5))
			l.position = Vector2(124, 0)
			l.size = Vector2(600, 84)
			row.add_child(l)
	_update_start()


func _start_online() -> void:
	if not Net.is_host():
		return
	if Net.players.size() < 2:
		Global.toast("Waiting for at least one friend to join.")
		return
	var players := []
	for p in Net.players:
		players.append({"id": p.id, "name": p.name, "color": p.color})
	var start := _start_dict("online", players)
	_remember()
	if start.custom.is_empty():
		Net.start_story(start)
		Global.start_with_story(start, "online")
	else:
		Net.start_game(start)
		Global.start_game(start)


func _show_error(why: String) -> void:
	if not is_inside_tree():
		return
	Dialog.open("Online Game", UI.wrap(why, 64), [["OK", Dialog.close_top]], 1100)
	if tab == "online":
		_build()
