class_name GameButton
extends Button
## Menu button: focus follows the mouse, plays menu sounds, and can show a "COMING SOON" style badge.

## Buttons that look greyed out but can still be selected (they run `action` after a "denied" sound).
var locked := false
var action: Callable
static var quiet_until := 0


static func make(label: String, act: Callable, width := 620.0, height := 74.0) -> GameButton:
	var b := GameButton.new()
	b.text = label.to_upper()
	b.action = act
	b.custom_minimum_size = Vector2(width, height)
	b.size = b.custom_minimum_size
	return b


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseMotion and e.relative.length() > 0.0 and not has_focus():
			grab_focus())
	focus_entered.connect(_on_focus)
	pressed.connect(_on_pressed)
	if locked:
		add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 0.45))
		add_theme_color_override("font_focus_color", Color(0.78, 0.82, 0.9, 0.55))
		add_theme_color_override("font_hover_color", Color(0.78, 0.82, 0.9, 0.55))
		add_theme_color_override("font_pressed_color", Color(0.78, 0.82, 0.9, 0.55))


## Focus without the "move" blip (used when a menu first appears).
func focus_quietly() -> void:
	quiet_until = Time.get_ticks_msec() + 50
	grab_focus()


func _on_focus() -> void:
	if Time.get_ticks_msec() > quiet_until:
		Audio.play("menu_move")


func _on_pressed() -> void:
	if locked:
		Audio.play("denied")
	else:
		Audio.play("menu_select")
	if action.is_valid():
		action.call()


## Adds a pill badge (e.g. COMING SOON) on the right and shifts the label left.
func add_badge(text_: String) -> void:
	var badge := NinePatchRect.new()
	badge.texture = load("res://assets/ui/badge.png")
	badge.patch_margin_left = 18
	badge.patch_margin_right = 18
	badge.patch_margin_top = 16
	badge.patch_margin_bottom = 16
	badge.size = Vector2(194, 36)
	badge.position = Vector2(size.x - 194 - 16, (size.y - 36) / 2.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	var l := UI.label(text_, 17, "extrabold", Color("#ffcf6b"), 2, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = badge.size
	badge.add_child(l)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("h_separation", 0)
	add_theme_stylebox_override("normal", _shifted("normal"))
	add_theme_stylebox_override("hover", _shifted("hover"))
	add_theme_stylebox_override("focus", _shifted("focus"))
	add_theme_stylebox_override("pressed", _shifted("pressed"))


func _shifted(style: String) -> StyleBox:
	var sb: StyleBox = get_theme_stylebox(style).duplicate()
	sb.content_margin_left = 96
	return sb


## Wires up/down focus so the list wraps around.
static func link_vertical(buttons: Array) -> void:
	var n := buttons.size()
	for i in n:
		var b: Control = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + n) % n])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % n])
		b.focus_neighbor_left = NodePath(".")
		b.focus_neighbor_right = NodePath(".")
