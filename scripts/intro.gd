extends Control
## Ironite logo shown when the game starts. Any key, click or button skips it.

@onready var _logo: TextureRect = $Logo
@onready var _fade: ColorRect = $Fade
var _presents: Label
var _leaving := false


func _ready() -> void:
	_presents = UI.place(UI.label("PRESENTS", 26, "bold", Color(0.82, 0.93, 0.87, 1), 14, HORIZONTAL_ALIGNMENT_CENTER), 960, 680)
	_presents.modulate.a = 0.0
	add_child(_presents)
	move_child(_fade, -1)
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(_logo, "modulate:a", 1.0, 0.7)
	t.parallel().tween_property(_logo, "position:y", _logo.position.y - 12, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_presents, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.2)
	t.tween_callback(_leave)


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.45)
	t.tween_callback(Global.goto_menu)
