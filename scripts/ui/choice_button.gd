class_name ChoiceButton
extends GameButton
## A button that shows "LABEL   ‹ value ›". Left/Right (or clicking the arrows) changes the value.

signal changed(index: int)

var caption := ""
var options: Array = []
var index := 0
var read_only := false
var _value: Label
var _left: Label
var _right: Label
var _click_ms := 0
var _split := 0.0


static func make_choice(caption_: String, options_: Array, index_ := 0, width := 620.0, height := 62.0) -> ChoiceButton:
	var b := ChoiceButton.new()
	b.caption = caption_.to_upper()
	b.text = b.caption
	b.options = options_
	b.index = clampi(index_, 0, maxi(0, options_.size() - 1))
	b.custom_minimum_size = Vector2(width, height)
	b.size = b.custom_minimum_size
	return b


func _ready() -> void:
	super._ready()
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_size_override("font_size", 24)
	for s in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb: StyleBox = get_theme_stylebox(s).duplicate()
		sb.content_margin_left = 28
		add_theme_stylebox_override(s, sb)
	## the value area starts right after the caption, so long captions never overlap it
	var f := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var cap_w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var split := maxf(size.x * 0.42, 28 + cap_w + 18)
	var vfs := 24 if size.x - split > 260 else 20
	_value = UI.label("", vfs, "bold", Color("#9fe6ff"), 0, HORIZONTAL_ALIGNMENT_CENTER)
	_value.size = Vector2(size.x - split - 80, size.y)
	_value.position = Vector2(split + 40, 0)
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value.clip_text = true
	add_child(_value)
	_left = UI.label("‹", 34, "bold", Color("#9fe6ff"), 0, HORIZONTAL_ALIGNMENT_CENTER)
	_left.size = Vector2(40, size.y)
	_left.position = Vector2(split, -3)
	add_child(_left)
	_right = UI.label("›", 34, "bold", Color("#9fe6ff"), 0, HORIZONTAL_ALIGNMENT_CENTER)
	_right.size = Vector2(40, size.y)
	_right.position = Vector2(size.x - 50, -3)
	add_child(_right)
	_split = split
	refresh()


func set_options(opts: Array, idx := -1) -> void:
	options = opts
	if idx >= 0:
		index = idx
	index = clampi(index, 0, maxi(0, options.size() - 1))
	refresh()


func current() -> String:
	return str(options[index]) if index < options.size() else ""


func refresh() -> void:
	if _value == null:
		return
	_value.text = current()
	_left.visible = not read_only
	_right.visible = not read_only


func step(dir: int) -> void:
	if read_only or options.size() < 2:
		Audio.play("denied")
		return
	index = posmod(index + dir, options.size())
	refresh()
	Audio.play("menu_move")
	changed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		step(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_ms = Time.get_ticks_msec()
		step(-1 if event.position.x < (_split + size.x) / 2.0 else 1)
		accept_event()


func _on_pressed() -> void:
	if Time.get_ticks_msec() - _click_ms > 150:
		step(1)
