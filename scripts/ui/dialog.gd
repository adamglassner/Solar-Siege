class_name Dialog
extends CanvasLayer
## A modal box with a title, optional message lines and a column of choices.
## Works while the game is paused. Esc / B goes back.

static var _stack: Array = []

var on_back: Callable
var _prev_focus: Control
var _buttons: Array[GameButton] = []
var _root: Control


## items: Array of [label, Callable]. Returns the dialog (already added to the current scene).
static func open(title: String, message: Array, items: Array, width := 760.0, back := Callable()) -> Dialog:
	var d := Dialog.new()
	d.layer = next_layer()
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	d.on_back = back
	d._build(title, message, items, width)
	Engine.get_main_loop().current_scene.add_child(d)
	_stack.append(d)
	return d


## Layer for a new overlay so it always sits above any overlay already open.
static func next_layer() -> int:
	var top := 49
	for n in Engine.get_main_loop().current_scene.get_children():
		if n is CanvasLayer and n.layer >= 50 and not n.is_queued_for_deletion():
			top = maxi(top, n.layer)
	return top + 1


## Closes the most recently opened dialog.
static func close_top() -> void:
	while _stack.size() and not is_instance_valid(_stack.back()):
		_stack.pop_back()
	if _stack.size():
		_stack.back().close()


func _build(title: String, message: Array, items: Array, width: float) -> void:
	_prev_focus = Engine.get_main_loop().root.gui_get_focus_owner()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.04, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var h := 140.0 + message.size() * 40.0 + items.size() * 86.0
	var y := 540.0 - h / 2.0
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/ui/panel.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 44)
	panel.position = Vector2(960 - width / 2.0 - 30, y - 30)
	panel.size = Vector2(width + 60, h + 60)
	_root.add_child(panel)
	_root.add_child(UI.place(UI.label(title.to_upper(), 40, "black", Color.WHITE, 6, HORIZONTAL_ALIGNMENT_CENTER, Color(0.4, 0.78, 1, 0.55), 8), 960, y + 52))
	for i in message.size():
		_root.add_child(UI.place(UI.label(message[i], 24, "medium", Color("#c8d8f0"), 0, HORIZONTAL_ALIGNMENT_CENTER), 960, y + 104 + i * 40))
	var top := y + 110 + message.size() * 40.0
	for i in items.size():
		var b := GameButton.make(items[i][0], items[i][1], width - 120, 70)
		b.position = Vector2(960 - (width - 120) / 2.0, top + i * 86)
		_root.add_child(b)
		_buttons.append(b)
	GameButton.link_vertical(_buttons)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.16)


func _ready() -> void:
	if _buttons.size():
		_buttons[0].focus_quietly()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play("menu_back")
		if on_back.is_valid():
			on_back.call()
		else:
			close()


func close() -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	_stack.erase(self)
	if is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree() and _prev_focus.is_visible_in_tree():
		GameButton.quiet_until = Time.get_ticks_msec() + 50
		_prev_focus.grab_focus()
