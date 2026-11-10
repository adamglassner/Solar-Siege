class_name EditorGrid
extends Control
## The formation grid in the Level Editor. Left mouse paints, right mouse erases.
## With the keyboard or a controller: arrows move, Space / A places, X / Y erases.

signal edited

var map: Dictionary
var tool := "crab" # a kind, or "" for the eraser
var tint := 0
var cursor := Vector2i(6, 2)
var cell := Vector2(84, 84)
var _painting := 0 # 1 paint, -1 erase
var _tex := {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func tex_for(kind: String) -> Texture2D:
	var key := "%s_%d" % [kind, tint]
	if not _tex.has(key):
		_tex[key] = load("res://assets/sprites/aliens/%s_%d_0.png" % [kind, tint])
	return _tex[key]


func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / cell.x), 0, CustomMaps.MAX_COLS - 1), clampi(int(p.y / cell.y), 0, CustomMaps.MAX_ROWS - 1))


func put(c: Vector2i, kind: String) -> void:
	var row: Array = map.grid[c.y]
	_erase_at(row, c.x)
	if kind == "cruiser":
		var x := mini(c.x, CustomMaps.MAX_COLS - 2)
		_erase_at(row, x)
		_erase_at(row, x + 1)
		row[x] = "cruiser"
		row[x + 1] = CustomMaps.WIDE
	elif kind != "":
		row[c.x] = kind
	edited.emit()
	queue_redraw()


func _erase_at(row: Array, x: int) -> void:
	if row[x] == CustomMaps.WIDE and x > 0:
		row[x - 1] = ""
	elif row[x] == "cruiser" and x + 1 < row.size():
		row[x + 1] = ""
	row[x] = ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			grab_focus()
			_painting = 1 if event.button_index == MOUSE_BUTTON_LEFT else (-1 if event.button_index == MOUSE_BUTTON_RIGHT else 0)
			if _painting != 0:
				cursor = _cell_at(event.position)
				put(cursor, tool if _painting > 0 else "")
				Audio.play("menu_move")
		else:
			_painting = 0
		accept_event()
	elif event is InputEventMouseMotion:
		var c := _cell_at(event.position)
		if c != cursor:
			cursor = c
			if _painting != 0:
				put(cursor, tool if _painting > 0 else "")
			queue_redraw()
		accept_event()
	elif event.is_action_pressed("ui_left"):
		_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		_move(Vector2i(1, 0))
	elif event.is_action_pressed("ui_up"):
		_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_accept"):
		put(cursor, tool)
		Audio.play("menu_move")
		accept_event()
	elif (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_X, KEY_DELETE, KEY_BACKSPACE]) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		put(cursor, "")
		Audio.play("menu_back")
		accept_event()


func _move(d: Vector2i) -> void:
	var c := cursor + d
	if c.x < 0 or c.x >= CustomMaps.MAX_COLS or c.y < 0 or c.y >= CustomMaps.MAX_ROWS:
		return # let focus move to the panels at the edges
	cursor = c
	queue_redraw()
	accept_event()


func _draw() -> void:
	var cols := CustomMaps.MAX_COLS
	var rows := CustomMaps.MAX_ROWS
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, 0.55))
	for r in rows + 1:
		draw_line(Vector2(0, r * cell.y), Vector2(cols * cell.x, r * cell.y), Color(0.5, 0.75, 1, 0.18), 1.0)
	for c in cols + 1:
		draw_line(Vector2(c * cell.x, 0), Vector2(c * cell.x, rows * cell.y), Color(0.5, 0.75, 1, 0.18), 1.0)
	var mid := (cols - 1) / 2.0
	draw_line(Vector2((mid + 0.5) * cell.x, 0), Vector2((mid + 0.5) * cell.x, rows * cell.y), Color(1, 0.85, 0.4, 0.25), 2.0)
	for r in rows:
		for c in cols:
			var k := str(map.grid[r][c])
			if k in CustomMaps.KINDS:
				var w := 2 if k == "cruiser" else 1
				var center := Vector2((c + w / 2.0) * cell.x, (r + 0.5) * cell.y)
				var tex := tex_for(k)
				var s := tex.get_size() * 0.5
				var fit := minf((cell.x * w - 6) / s.x, (cell.y - 6) / s.y)
				draw_texture_rect(tex, Rect2(center - s * fit / 2, s * fit), false)
	if has_focus() or get_rect().has_point(get_local_mouse_position() + position):
		var w2 := 2 if tool == "cruiser" else 1
		var cx := mini(cursor.x, cols - w2)
		var rect := Rect2(Vector2(cx * cell.x, cursor.y * cell.y), Vector2(cell.x * w2, cell.y))
		draw_rect(rect, Color(1, 0.85, 0.4, 0.95) if tool != "" else Color(1, 0.4, 0.45, 0.95), false, 3.0)
		if tool != "":
			var tex2 := tex_for(tool)
			var s2 := tex2.get_size() * 0.5
			var fit2 := minf((rect.size.x - 6) / s2.x, (rect.size.y - 6) / s2.y)
			draw_texture_rect(tex2, Rect2(rect.get_center() - s2 * fit2 / 2, s2 * fit2), false, Color(1, 1, 1, 0.35))
