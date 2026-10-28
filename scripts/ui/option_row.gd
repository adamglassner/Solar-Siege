class_name OptionRow
extends GameButton
## One row of the Options screen: a volume slider, an ON/OFF toggle or a plain action.

enum Kind { SLIDER, TOGGLE, ACTION }

var kind := Kind.ACTION
var key := ""
var _value_label: Label
var _fill: TextureRect
var _grab: TextureRect
const SLIDER_W := 240.0


static func make_row(label_: String, kind_: Kind, key_: String, act := Callable()) -> OptionRow:
	var r := OptionRow.new()
	r.text = label_.to_upper()
	r.kind = kind_
	r.key = key_
	r.action = act
	r.custom_minimum_size = Vector2(860, 66)
	r.size = r.custom_minimum_size
	return r


func _ready() -> void:
	super._ready()
	if kind == Kind.ACTION:
		return
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("h_separation", 0)
	for s in ["normal", "hover", "focus", "pressed"]:
		var sb: StyleBox = get_theme_stylebox(s).duplicate()
		sb.content_margin_left = 32
		add_theme_stylebox_override(s, sb)
	_value_label = UI.label("", 26, "bold", Color("#9fe6ff"), 0, HORIZONTAL_ALIGNMENT_RIGHT)
	_value_label.size = Vector2(300, size.y)
	_value_label.position = Vector2(size.x - 32 - 300, 0)
	add_child(_value_label)
	if kind == Kind.SLIDER:
		_value_label.label_settings = UI.settings(24, "bold", Color("#cfe6ff"))
		_value_label.position.x = size.x - 30 - 300
		var sx := size.x - 300
		var track := NinePatchRect.new()
		track.texture = load("res://assets/ui/slider_track.png")
		track.patch_margin_left = 5
		track.patch_margin_right = 5
		track.position = Vector2(sx, size.y / 2 - 5)
		track.size = Vector2(SLIDER_W, 10)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(track)
		_fill = TextureRect.new()
		_fill.texture = load("res://assets/ui/slider_fill.png")
		_fill.stretch_mode = TextureRect.STRETCH_KEEP
		_fill.clip_contents = true
		_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fill.position = track.position
		_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fill)
		_grab = TextureRect.new()
		_grab.texture = load("res://assets/ui/slider_grabber.png")
		_grab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_grab)
		_value_label.size.x = 60
		_value_label.position.x = size.x - 30 - 60 + 0
		_value_label.position.x = size.x - 26 - 60
	_refresh()


func _refresh() -> void:
	var s: Dictionary = Global.settings
	if kind == Kind.SLIDER:
		var v: float = s[key]
		_fill.size = Vector2(maxf(10.0, SLIDER_W * v), 10)
		_grab.position = Vector2(size.x - 300 + SLIDER_W * v - 22, size.y / 2 - 22)
		_value_label.text = "%d%%" % roundi(v * 100)
	elif kind == Kind.TOGGLE:
		var on_off := "ON" if s[key] else "OFF"
		_value_label.text = ("‹  %s  ›" % on_off) if has_focus() else on_off


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		if is_node_ready() and kind == Kind.TOGGLE:
			_refresh()


func adjust(dir: int) -> void:
	var s: Dictionary = Global.settings
	if kind == Kind.SLIDER:
		s[key] = clampf(roundf((s[key] + dir * 0.1) * 10.0) / 10.0, 0.0, 1.0)
	elif kind == Kind.TOGGLE:
		s[key] = not s[key]
		if key == "fullscreen":
			Global.apply_fullscreen()
	Global.save_settings()
	Audio.play("menu_move")
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if kind == Kind.ACTION:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		adjust(-1)
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		adjust(1)
		accept_event()
	elif kind == Kind.SLIDER and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var sx := size.x - 300
		if event.position.x >= sx - 10:
			Global.settings[key] = clampf((event.position.x - sx) / SLIDER_W, 0.0, 1.0)
			Global.save_settings()
			Audio.play("menu_move")
			_refresh()
			accept_event()


func _on_pressed() -> void:
	if kind == Kind.ACTION:
		super._on_pressed()
	else:
		adjust(1)
