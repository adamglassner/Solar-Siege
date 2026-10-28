class_name OptionsMenu
extends CanvasLayer
## Options overlay: volumes, fullscreen, screen shake, FPS counter, reset high score, controls list.

const CONTROLS := [
	["Move", "← →  or  A D"],
	["Fire", "Space  (or Z)"],
	["Nova Bomb", "B  or  Shift"],
	["Pause", "Esc  or  P"],
	["Gamepad", "Stick/D-pad, A fire, B bomb, Start pause"],
]

var _prev_focus: Control
var _rows: Array = []
var _root: Control


static func open() -> OptionsMenu:
	var o := OptionsMenu.new()
	o.layer = Dialog.next_layer()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.get_main_loop().current_scene.add_child(o)
	return o


func _ready() -> void:
	_prev_focus = get_viewport().gui_get_focus_owner()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.016, 0.063, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_root.add_child(UI.place(UI.label("OPTIONS", 64, "black", Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.35, 0.75, 1, 0.6), 12), 960, 130))
	_rows = [
		OptionRow.make_row("Master Volume", OptionRow.Kind.SLIDER, "master"),
		OptionRow.make_row("Music Volume", OptionRow.Kind.SLIDER, "music"),
		OptionRow.make_row("Sound Effects", OptionRow.Kind.SLIDER, "sfx"),
		OptionRow.make_row("Fullscreen", OptionRow.Kind.TOGGLE, "fullscreen"),
		OptionRow.make_row("Screen Shake", OptionRow.Kind.TOGGLE, "shake"),
		OptionRow.make_row("Show FPS", OptionRow.Kind.TOGGLE, "show_fps"),
		OptionRow.make_row("Reset High Score", OptionRow.Kind.ACTION, "", _confirm_reset),
		OptionRow.make_row("Back", OptionRow.Kind.ACTION, "", close),
	]
	for i in _rows.size():
		var r: OptionRow = _rows[i]
		r.position = Vector2(960 - 210 - 430, 220 + i * 80)
		_root.add_child(r)
	GameButton.link_vertical(_rows)
	# controls panel
	var px := 960.0 + 260.0
	var py := 220.0
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/ui/panel_flat.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 16)
	panel.position = Vector2(px - 2, py - 2)
	panel.size = Vector2(524, 474)
	_root.add_child(panel)
	_root.add_child(UI.place(UI.label("CONTROLS", 28, "extrabold", Color("#9fe6ff"), 6, HORIZONTAL_ALIGNMENT_CENTER), px + 260, py + 44, 520))
	for i in CONTROLS.size():
		var y := py + 110 + i * 72
		_root.add_child(UI.place(UI.label(CONTROLS[i][0], 22, "extrabold"), px + 30, y, 480))
		_root.add_child(UI.place(UI.label(CONTROLS[i][1], 20, "medium", Color("#b8c8e0")), px + 30, y + 28, 480))
	_root.add_child(UI.place(UI.label("Solar Siege v" + Global.version(), 18, "medium", Color(0.78, 0.86, 1, 0.5), 0, HORIZONTAL_ALIGNMENT_CENTER), 960, 1030))
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.16)
	_rows[0].focus_quietly()


func _confirm_reset() -> void:
	Dialog.open("Reset High Score?", ["This can't be undone."], [
		["Reset", func():
			Global.reset_high_score()
			Dialog.close_top()
			Global.toast("High score reset")],
		["Cancel", Dialog.close_top],
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play("menu_back")
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	queue_free()
	if is_instance_valid(_prev_focus) and _prev_focus.is_visible_in_tree():
		GameButton.quiet_until = Time.get_ticks_msec() + 50
		_prev_focus.grab_focus()
