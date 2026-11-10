extends Node2D
## Custom Maps: everything made in the Level Editor. Play a map solo or with friends,
## edit, copy or delete it, or start a new one. These maps are separate from the campaign.

var _maps: Array = []
var _sel := 0
var _root: Control
var _list: VBoxContainer
var _preview: Control
var _info: Label
var _title: Label
var _thumb: TextureRect
var _diff: ChoiceButton
var _action_buttons: Array = []
var _list_buttons: Array = []


func _ready() -> void:
	$Stars.setup(777)
	Audio.play_music(Audio.music("menu"))
	_root = $UI/Root
	_root.add_child(UI.place(UI.label("CUSTOM MAPS", 60, "black", Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.35, 0.75, 1, 0.6), 12), 960, 78))
	_root.add_child(UI.place(UI.label("Maps you build in the Level Editor. They're kept apart from the nine campaign planets.", 22, "medium", Color("#bcd0ee"), 0, HORIZONTAL_ALIGNMENT_CENTER), 960, 132))
	_build()


func _build() -> void:
	for c in _root.get_children():
		if c.has_meta("dyn"):
			c.queue_free()
	_maps = CustomMaps.list()
	_sel = clampi(_sel, 0, maxi(0, _maps.size() - 1))
	_list_buttons.clear()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(140, 190)
	scroll.size = Vector2(700, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("dyn", true)
	_root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.custom_minimum_size = Vector2(660, 0)
	scroll.add_child(_list)
	for i in _maps.size():
		var m: Dictionary = _maps[i]
		var b := GameButton.make(m.name, func(): _focus_actions(), 640, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 24)
		b.focus_entered.connect(func(): _select(i))
		_list.add_child(b)
		_list_buttons.append(b)
	if _maps.is_empty():
		var l := UI.label("No maps yet. Choose New Map to build your first one.", 24, "bold", Color(0.8, 0.86, 1, 0.7))
		l.custom_minimum_size = Vector2(640, 80)
		_list.add_child(l)
	var new_b := GameButton.make("New Map", _new_map, 340, 62)
	new_b.position = Vector2(140, 860)
	var folder := GameButton.make("Open Maps Folder", func(): OS.shell_open(CustomMaps.folder_path()), 340, 62)
	folder.position = Vector2(500, 860)
	var back := GameButton.make("Back", Global.goto_menu, 700, 62)
	back.position = Vector2(140, 940)
	for b in [new_b, folder, back]:
		b.add_theme_font_size_override("font_size", 24)
		b.set_meta("dyn", true)
		_root.add_child(b)
	# preview panel
	var px := 900.0
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/ui/panel_flat.png")
	for m2 in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m2, 16)
	panel.position = Vector2(px, 190)
	panel.size = Vector2(880, 812)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("dyn", true)
	_root.add_child(panel)
	_thumb = TextureRect.new()
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_thumb.position = Vector2(20, 20)
	_thumb.size = Vector2(840, 360)
	_thumb.clip_contents = true
	panel.add_child(_thumb)
	_preview = Control.new()
	_preview.position = _thumb.position
	_preview.size = _thumb.size
	_preview.draw.connect(_draw_preview)
	panel.add_child(_preview)
	_title = UI.label("", 32, "black", Color.WHITE, 2)
	_title.position = Vector2(24, 392)
	_title.size = Vector2(830, 44)
	panel.add_child(_title)
	_info = UI.label("", 21, "medium", Color("#c8d8f0"))
	_info.position = Vector2(24, 436)
	_info.size = Vector2(830, 30)
	panel.add_child(_info)
	_diff = ChoiceButton.make_choice("Difficulty", ["Easy", "Normal", "Hard"], 1, 400, 56)
	_diff.position = Vector2(px + 24, 190 + 488)
	_diff.set_meta("dyn", true)
	_root.add_child(_diff)
	_action_buttons = []
	var acts := [["Play Solo", _play_solo], ["Play with Friends", _play_friends], ["Edit", _edit], ["Duplicate", _duplicate], ["Delete", _delete]]
	for i in acts.size():
		var b := GameButton.make(acts[i][0], acts[i][1], 400, 56)
		b.position = Vector2(px + 24 + (i % 2) * 432, 190 + 488 + (i + 1) / 2 * 70) if i > 0 else Vector2(px + 456, 190 + 488)
		b.add_theme_font_size_override("font_size", 22)
		b.set_meta("dyn", true)
		_root.add_child(b)
		_action_buttons.append(b)
	var chain := _list_buttons.duplicate()
	chain.append_array([new_b, folder, back])
	GameButton.link_vertical(chain)
	var right := [_diff]
	right.append_array(_action_buttons)
	GameButton.link_vertical(right)
	for b in _list_buttons:
		b.focus_neighbor_right = b.get_path_to(_action_buttons[0])
	for b in right:
		b.focus_neighbor_left = b.get_path_to(_list_buttons[_sel] if _list_buttons.size() else new_b)
	_select(_sel)
	if _list_buttons.size():
		_list_buttons[_sel].focus_quietly()
	else:
		new_b.focus_quietly()


func _select(i: int) -> void:
	_sel = i
	var has := i < _maps.size()
	for b in _action_buttons:
		b.visible = has
	_diff.visible = has
	if not has:
		_title.text = ""
		_info.text = ""
		_thumb.texture = null
		_preview.queue_redraw()
		return
	var m: Dictionary = _maps[i].data
	_thumb.texture = load("res://assets/backgrounds/%s.png" % m.backdrop)
	_title.text = m.name
	var bits := ["%d aliens" % CustomMaps.count_aliens(m), "%d shield%s" % [m.shields, "" if m.shields == 1 else "s"]]
	if m.saucer:
		bits.append("bonus saucer")
	if m.boss:
		bits.append("boss: Erebus")
	_info.text = "  ·  ".join(bits)
	_preview.queue_redraw()


func _draw_preview() -> void:
	if _sel >= _maps.size():
		return
	var m: Dictionary = _maps[_sel].data
	_preview.draw_rect(Rect2(Vector2.ZERO, _preview.size), Color(0, 0.01, 0.05, 0.35))
	var cell := Vector2(54, 48)
	var origin := Vector2((_preview.size.x - cell.x * CustomMaps.MAX_COLS) / 2, 40)
	for r in CustomMaps.MAX_ROWS:
		for c in CustomMaps.MAX_COLS:
			var k := str(m.grid[r][c])
			if k in CustomMaps.KINDS:
				var w := 2 if k == "cruiser" else 1
				var tex: Texture2D = load("res://assets/sprites/aliens/%s_%d_0.png" % [k, m.tint])
				var s := tex.get_size() * 0.5
				var fit := minf((cell.x * w - 4) / s.x, (cell.y - 4) / s.y)
				var center := origin + Vector2((c + w / 2.0) * cell.x, (r + 0.5) * cell.y)
				_preview.draw_texture_rect(tex, Rect2(center - s * fit / 2, s * fit), false)


func _focus_actions() -> void:
	if _action_buttons.size() and _action_buttons[0].visible:
		_action_buttons[0].grab_focus()


func _current() -> Dictionary:
	return _maps[_sel] if _sel < _maps.size() else {}


func _play_solo() -> void:
	var m := _current()
	if m.is_empty():
		return
	var d: String = ["easy", "normal", "hard"][_diff.index]
	Global.start_game({"level": 0, "score": 0, "lives": Global.DIFFICULTY[d].lives, "bombs": 1, "difficulty": d, "custom": m.data})


func _play_friends() -> void:
	var m := _current()
	if m.is_empty():
		return
	Global.lobby_memory["map_path"] = m.path
	Global.lobby_memory["diff_index"] = _diff.index
	Global.goto_scene("res://scenes/lobby.tscn")


func _edit() -> void:
	var m := _current()
	if m.is_empty():
		return
	Global.editor_map = m.data.duplicate(true)
	Global.editor_path = m.path
	Global.lobby_memory["editor_dirty"] = false
	Global.goto_scene("res://scenes/editor.tscn")


func _new_map() -> void:
	Global.editor_map = CustomMaps.blank("My Map %d" % (_maps.size() + 1))
	Global.editor_path = ""
	Global.lobby_memory["editor_dirty"] = false
	Global.goto_scene("res://scenes/editor.tscn")


func _duplicate() -> void:
	var m := _current()
	if m.is_empty():
		return
	var copy: Dictionary = m.data.duplicate(true)
	copy.name = (m.name + " Copy").substr(0, 32)
	CustomMaps.save_map(copy)
	Global.toast("Made a copy of \"%s\"" % m.name)
	_sel = 0
	_build()


func _delete() -> void:
	var m := _current()
	if m.is_empty():
		return
	Dialog.open("Delete Map?", ["\"%s\" will be deleted for good." % m.name], [
		["Delete", func():
			Dialog.close_top()
			CustomMaps.delete_map(m.path)
			_build()],
		["Cancel", Dialog.close_top],
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play("menu_back")
		Global.goto_menu()
