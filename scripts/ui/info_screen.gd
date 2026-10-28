class_name InfoScreen
extends CanvasLayer
## Full-screen scrolling text page used for Credits and the Changelog.
## Up/Down (or the mouse wheel) scroll, Esc / B / Back closes.

var _title := ""
var _bbcode := ""
var _show_logo := false
var _prev_focus: Control
var _scroll: ScrollContainer
var _root: Control


static func open_credits() -> InfoScreen:
	var v := Global.version()
	var gold := "#ffd76b"
	var dim := "#9fb4d4"
	var t := ""
	t += "[center][font_size=46][b]SOLAR SIEGE[/b][/font_size]\n"
	t += "[color=%s]Version %s[/color]\n\n" % [dim, v]
	t += "[font_size=30]A game by [b]Ironite[/b][/font_size]\n\n\n"
	for row in [
		["Game Design", "Ironite"],
		["Programming", "Ironite"],
		["Art & Visual Effects", "Ironite"],
		["Sound Effects & Music", "Ironite"],
		["Level Design & Balancing", "Ironite"],
		["Testing", "Ironite"],
	]:
		t += "[color=%s][font_size=20]%s[/font_size][/color]\n[font_size=30][b]%s[/b][/font_size]\n\n" % [gold, row[0].to_upper(), row[1]]
	t += "\n[color=%s][font_size=20]BUILT WITH[/font_size][/color]\n" % gold
	t += "[b]Godot Engine[/b] 4.7.2\n[color=%s][font_size=20]MIT licence · © Juan Linietsky, Ariel Manzur and contributors · godotengine.org[/font_size][/color]\n\n" % dim
	t += "[color=%s][font_size=20]TYPEFACE[/font_size][/color]\n" % gold
	t += "[b]Inter[/b] by Rasmus Andersson\n[color=%s][font_size=20]SIL Open Font License 1.1[/font_size][/color]\n\n" % dim
	t += "[color=%s][font_size=20]INSTALLER[/font_size][/color]\n" % gold
	t += "[b]NSIS[/b] (Nullsoft Scriptable Install System)\n[color=%s][font_size=20]zlib licence[/font_size][/color]\n\n\n" % dim
	t += "[font_size=30][b]Thank you for playing![/b][/font_size]\n\n"
	t += "[color=%s]© 2026 Ironite. All rights reserved.[/color][/center]" % dim
	return _open("Credits", t, true)


static func open_changelog() -> InfoScreen:
	return _open("Changelog", _changelog_bbcode(), false)


static func _open(title: String, bbcode: String, logo: bool) -> InfoScreen:
	var s := InfoScreen.new()
	s._title = title
	s._bbcode = bbcode
	s._show_logo = logo
	s.layer = Dialog.next_layer()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.get_main_loop().current_scene.add_child(s)
	return s


## Turns CHANGELOG.md into formatted text for the in-game page.
static func _changelog_bbcode() -> String:
	var f := FileAccess.open("res://CHANGELOG.md", FileAccess.READ)
	if f == null:
		return "[center]The changelog could not be found.[/center]"
	var lines := f.get_as_text().split("\n")
	var out := ""
	var started := false
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var link := RegEx.create_from_string("\\[([^\\]]+)\\]\\([^)]+\\)")
	var code := RegEx.create_from_string("`([^`]+)`")
	for raw in lines:
		var line := raw.strip_edges(false, true)
		if line.begins_with("## "):
			started = true
			var h := line.substr(3).replace("[", "").replace("]", "")
			out += "\n[font_size=38][b][color=#8fe9ff]Version %s[/color][/b][/font_size]\n" % h
			continue
		if not started:
			continue
		line = bold.sub(line, "[b]$1[/b]", true)
		line = link.sub(line, "$1", true)
		line = code.sub(line, "[color=#ffd76b]$1[/color]", true)
		if line.begins_with("### "):
			out += "\n[font_size=26][b][color=#ffd76b]%s[/color][/b][/font_size]\n" % line.substr(4).to_upper()
		elif line.begins_with("- "):
			out += "[indent]•  %s[/indent]\n" % line.substr(2)
		elif line == "---":
			out += "\n"
		elif line != "":
			out += line + "\n"
	return out


func _ready() -> void:
	_prev_focus = get_viewport().gui_get_focus_owner()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.016, 0.063, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_root.add_child(UI.place(UI.label(_title.to_upper(), 64, "black", Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, Color(0.35, 0.75, 1, 0.6), 12), 960, 100))
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/ui/panel_flat.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		panel.set(m, 16)
	panel.position = Vector2(960 - 600, 170)
	panel.size = Vector2(1200, 760)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(960 - 570, 190)
	_scroll.size = Vector2(1140, 720)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1110, 0)
	box.add_theme_constant_override("separation", 24)
	_scroll.add_child(box)
	if _show_logo:
		var logo := TextureRect.new()
		logo.texture = load("res://assets/ui/ironite_logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(1110, 170)
		box.add_child(logo)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(1110, 0)
	rt.add_theme_font_override("normal_font", UI.font("medium"))
	rt.add_theme_font_override("bold_font", UI.font("extrabold"))
	rt.add_theme_font_size_override("normal_font_size", 24)
	rt.add_theme_font_size_override("bold_font_size", 24)
	rt.add_theme_color_override("default_color", Color("#dfe9ff"))
	rt.add_theme_constant_override("line_separation", 6)
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.text = _bbcode
	box.add_child(rt)
	var back := GameButton.make("Back", close, 420, 64)
	back.position = Vector2(960 - 210, 962)
	_root.add_child(back)
	GameButton.link_vertical([back])
	_root.add_child(UI.place(UI.label("↑ ↓  or mouse wheel to scroll", 18, "medium", Color(0.78, 0.86, 1, 0.5), 0, HORIZONTAL_ALIGNMENT_CENTER), 960, 1050))
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.16)
	back.focus_quietly()


func _process(dt: float) -> void:
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.3:
		_scroll.scroll_vertical += int(dir * 900 * dt)


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
