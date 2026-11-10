class_name AchievementsScreen
extends CanvasLayer
## The Achievements page: every medal by category, with progress for the counting ones.
## Up/Down (or the mouse wheel) scroll, Esc / B / Back closes. Secret achievements stay hidden until unlocked.

var _prev_focus: Control
var _scroll: ScrollContainer
var _root: Control


static func open() -> AchievementsScreen:
	var s := AchievementsScreen.new()
	s.layer = Dialog.next_layer()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.get_main_loop().current_scene.add_child(s)
	return s


func _ready() -> void:
	_prev_focus = get_viewport().gui_get_focus_owner()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.016, 0.063, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_root.add_child(UI.place(UI.label("ACHIEVEMENTS", 64, "black", Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.35, 0.75, 1, 0.6), 12), 960, 84))

	var total := Achievements.defs.size()
	var got := Achievements.unlocked_count()
	_root.add_child(UI.place(UI.label("%d of %d unlocked" % [got, total], 24, "extrabold", Color("#ffd76b"), 2, HORIZONTAL_ALIGNMENT_CENTER), 960, 150))
	var track := TextureRect.new()
	track.texture = load("res://assets/ui/timer_track.png")
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.position = Vector2(960 - 300, 172)
	track.size = Vector2(600, 10)
	_root.add_child(track)
	var fill := TextureRect.new()
	fill.texture = load("res://assets/ui/timer_fill.png")
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.modulate = Color("#ffd76b")
	fill.position = track.position
	fill.size = Vector2(600.0 * got / maxi(1, total), 10)
	_root.add_child(fill)

	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/ui/panel_flat.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 16)
	panel.position = Vector2(960 - 760, 200)
	panel.size = Vector2(1520, 740)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(960 - 735, 216)
	_scroll.size = Vector2(1480, 708)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1450, 0)
	box.add_theme_constant_override("separation", 10)
	_scroll.add_child(box)

	for cat in Achievements.categories:
		var list := Achievements.defs.filter(func(a): return a.cat == cat)
		if list.is_empty():
			continue
		var info: Array = Achievements.categories[cat]
		var n := list.filter(func(a): return Achievements.is_unlocked(a.id)).size()
		var head := UI.label("%s   %d / %d" % [str(info[0]).to_upper(), n, list.size()], 26, "extrabold", UI.hsl(float(info[1]), 100, 72), 5)
		head.custom_minimum_size = Vector2(1450, 48)
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 12)
		box.add_child(grid)
		for a in list:
			grid.add_child(_card(a))

	var back := GameButton.make("Back", close, 420, 64)
	back.position = Vector2(960 - 210, 962)
	_root.add_child(back)
	GameButton.link_vertical([back])
	_root.add_child(UI.place(UI.label("↑ ↓  or mouse wheel to scroll", 18, "medium", Color(0.78, 0.86, 1, 0.5), 0, HORIZONTAL_ALIGNMENT_CENTER), 960, 1050))
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.16)
	back.focus_quietly()


func _card(a: Dictionary) -> Control:
	var got := Achievements.is_unlocked(a.id)
	var secret: bool = a.get("hidden", false) and not got
	var c := NinePatchRect.new()
	c.texture = load("res://assets/ui/panel_flat.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		c.set(m, 16)
	c.custom_minimum_size = Vector2(718, 118)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	if not got:
		c.modulate = Color(1, 1, 1, 0.78)
	var ic := TextureRect.new()
	ic.texture = Achievements.icon("hidden") if secret else Achievements.icon(a.id, not got)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(12, 10)
	ic.size = Vector2(98, 98)
	c.add_child(ic)
	var name := UI.label("Secret Achievement" if secret else a.name, 27, "extrabold", Color.WHITE if got else Color(0.85, 0.9, 1))
	name.position = Vector2(126, 14)
	name.size = Vector2(450, 38)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(name)
	var desc := UI.label("Keep playing to discover this one." if secret else a.desc, 18, "medium", Color(0.8, 0.86, 1, 0.85))
	desc.position = Vector2(127, 52)
	desc.size = Vector2(570, 50)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(desc)
	if got:
		var when := Time.get_datetime_dict_from_unix_time(int(Achievements.state.unlocked[a.id]))
		var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var stamp := UI.label("✓  %s %d, %d" % [months[when.month - 1], when.day, when.year], 16, "extrabold", Color("#7dffb0"), 1, HORIZONTAL_ALIGNMENT_RIGHT)
		stamp.position = Vector2(500, 20)
		stamp.size = Vector2(200, 24)
		c.add_child(stamp)
	elif int(a.target) > 1 and not secret:
		var v := mini(Achievements.progress(a.id), int(a.target))
		var count := UI.label("%d / %d" % [v, a.target], 16, "extrabold", Color("#ffd76b"), 1, HORIZONTAL_ALIGNMENT_RIGHT)
		count.position = Vector2(500, 20)
		count.size = Vector2(200, 24)
		c.add_child(count)
		var tr := TextureRect.new()
		tr.texture = load("res://assets/ui/timer_track.png")
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2(127, 100)
		tr.size = Vector2(570, 6)
		c.add_child(tr)
		var fl := TextureRect.new()
		fl.texture = load("res://assets/ui/timer_fill.png")
		fl.stretch_mode = TextureRect.STRETCH_SCALE
		fl.modulate = Color("#ffd76b")
		fl.position = tr.position
		fl.size = Vector2(570.0 * v / float(a.target), 6)
		c.add_child(fl)
	return c


func _process(dt: float) -> void:
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.3:
		_scroll.scroll_vertical += int(dir * 1100 * dt)


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
