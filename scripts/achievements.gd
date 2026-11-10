extends Node
## Achievements: definitions (data/achievements.json), progress, unlock pop-ups, and a copy for the
## Ironite Launcher.
##
## Progress is saved in user://achievements.json. Every change is also written to
## %APPDATA%\Ironite\Achievements\solarsiege.json (with the medal icons beside it in solarsiege\), which is
## where Ironite Launcher looks for any Ironite game's achievements.

const DATA_PATH := "res://data/achievements.json"
const SAVE_PATH := "user://achievements.json"
const ICON_DIR := "res://assets/sprites/achievements/"
const GAME_ID := "solarsiege"
const POPUP_SECS := 3.6

signal unlocked(id: String)

var defs: Array = [] # [{id, cat, name, desc, target, hidden, icon}]
var categories := {} # cat -> [label, hue]
var by_id := {}
var state := {"unlocked": {}, "progress": {}, "items": {}} # id -> unix time / count / [items]

var _dirty := false
var _save_t := 0.0
var _queue: Array[String] = []
var _popup: Control
var _popup_t := 0.0
var _layer: CanvasLayer
var _icons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(d) == TYPE_DICTIONARY:
		defs = d.get("achievements", [])
		categories = d.get("categories", {})
	for a in defs:
		a.target = int(a.get("target", 1))
		by_id[a.id] = a
	_load()
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	## make sure the launcher has a current copy (new achievements, new icons) even before anything unlocks
	_export.call_deferred()


# ---------------------------------------------------------------- queries
func is_unlocked(id: String) -> bool:
	return state.unlocked.has(id)


func progress(id: String) -> int:
	if by_id.has(id) and by_id[id].target > 1 and state.items.has(id):
		return state.items[id].size()
	return int(state.progress.get(id, 0))


func unlocked_count() -> int:
	var n := 0
	for a in defs:
		if is_unlocked(a.id):
			n += 1
	return n


## Medal icons ship as plain PNG files (imported with "keep", so the launcher can be given the same files),
## and are turned into textures here.
func icon(id: String, locked := false) -> Texture2D:
	var name := id + ("_locked" if locked else "")
	if _icons.has(name):
		return _icons[name]
	var bytes := FileAccess.get_file_as_bytes(ICON_DIR + name + ".png")
	if bytes.is_empty():
		return icon("hidden") if name != "hidden" else null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	img.generate_mipmaps()
	_icons[name] = ImageTexture.create_from_image(img)
	return _icons[name]


# ---------------------------------------------------------------- changes
## Unlocks an achievement (no-op if it's already unlocked or unknown).
func unlock(id: String) -> void:
	if not by_id.has(id) or is_unlocked(id):
		return
	state.unlocked[id] = int(Time.get_unix_time_from_system())
	_dirty = true
	_save_now()
	_queue.append(id)
	unlocked.emit(id)


## Adds to a counter achievement ("Destroy 100 Wraiths"); unlocks it at its target.
func add(id: String, n := 1) -> void:
	if not by_id.has(id) or is_unlocked(id):
		return
	var v := int(state.progress.get(id, 0)) + n
	state.progress[id] = v
	_dirty = true
	if v >= by_id[id].target:
		unlock(id)


## Records one of a set ("Pick up every type of power-up"); unlocks when the set is complete.
func add_item(id: String, item: String) -> void:
	if not by_id.has(id) or is_unlocked(id):
		return
	var list: Array = state.items.get(id, [])
	if item in list:
		return
	list.append(item)
	state.items[id] = list
	state.progress[id] = list.size()
	_dirty = true
	if list.size() >= by_id[id].target:
		unlock(id)


func reset_all() -> void:
	state = {"unlocked": {}, "progress": {}, "items": {}}
	_dirty = true
	_save_now()


func flush() -> void:
	if _dirty:
		_save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush()


func _process(dt: float) -> void:
	## counters are saved every few seconds rather than on every kill
	_save_t += dt
	if _dirty and _save_t > 3.0:
		_save_now()
	_update_popup(dt)


# ---------------------------------------------------------------- saving
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	for k in ["unlocked", "progress", "items"]:
		if typeof(d.get(k)) == TYPE_DICTIONARY:
			state[k] = d[k]


func _save_now() -> void:
	_dirty = false
	_save_t = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))
		f.close()
	_export()


## Where Ironite games share achievements with the launcher. IRONITE_ACHIEVEMENTS_DIR overrides it (tests).
func export_dir() -> String:
	var o := OS.get_environment("IRONITE_ACHIEVEMENTS_DIR")
	if o != "":
		return o
	var appdata := OS.get_environment("APPDATA")
	if appdata == "":
		return ""
	return appdata.path_join("Ironite").path_join("Achievements")


func _export() -> void:
	var dir := export_dir()
	if dir == "":
		return
	var icons := dir.path_join(GAME_ID)
	if DirAccess.make_dir_recursive_absolute(icons) != OK and not DirAccess.dir_exists_absolute(icons):
		return
	## copy the medal icons once per game version
	var marker := icons.path_join("version.txt")
	if not FileAccess.file_exists(marker) or FileAccess.get_file_as_string(marker).strip_edges() != Global.version():
		for a in defs:
			for suffix in ["", "_locked"]:
				_copy_icon(a.id + suffix, icons)
		_copy_icon("hidden", icons)
		var m := FileAccess.open(marker, FileAccess.WRITE)
		if m:
			m.store_string(Global.version())
	var list := []
	for a in defs:
		list.append({
			"id": a.id, "name": a.name, "description": a.desc, "category": categories.get(a.cat, [a.cat])[0],
			"hidden": a.get("hidden", false), "unlocked": is_unlocked(a.id), "unlocked_at": int(state.unlocked.get(a.id, 0)),
			"progress": mini(progress(a.id), a.target), "target": a.target,
			"icon": GAME_ID + "/" + a.id + ".png", "icon_locked": GAME_ID + "/" + a.id + "_locked.png",
		})
	var out := {"schema": 1, "game": GAME_ID, "title": "Solar Siege", "version": Global.version(),
		"updated": int(Time.get_unix_time_from_system()), "icon_hidden": GAME_ID + "/hidden.png", "achievements": list}
	## write to a temp file and swap it in, so the launcher never reads half a file
	var path := dir.path_join(GAME_ID + ".json")
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	DirAccess.rename_absolute(path + ".tmp", path)


## The original PNGs ship inside the game (see include_filter in export_presets.cfg), so they're copied as-is.
func _copy_icon(name: String, dir: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(ICON_DIR + name + ".png")
	if bytes.is_empty():
		return
	var f := FileAccess.open(dir.path_join(name + ".png"), FileAccess.WRITE)
	if f:
		f.store_buffer(bytes)


# ---------------------------------------------------------------- unlock pop-up
func _update_popup(dt: float) -> void:
	if _popup == null:
		if _queue.is_empty():
			return
		_show_popup(_queue.pop_front())
		return
	_popup_t += dt
	## shorter when more are waiting, so a burst of unlocks doesn't take a minute to show
	var secs := POPUP_SECS if _queue.is_empty() else (2.2 if _queue.size() < 4 else 1.4)
	var x_in := 1920.0 - 40.0 - _popup.size.x
	var k := 1.0
	if _popup_t < 0.3:
		k = 1.0 - pow(1.0 - _popup_t / 0.3, 3)
	elif _popup_t > secs - 0.3:
		k = clampf((secs - _popup_t) / 0.3, 0, 1)
	_popup.position.x = lerpf(1960.0, x_in, k)
	if _popup_t >= secs:
		_popup.queue_free()
		_popup = null


func _show_popup(id: String) -> void:
	var a: Dictionary = by_id[id]
	var hue: float = categories.get(a.cat, ["", 45.0])[1]
	var p := NinePatchRect.new()
	p.texture = load("res://assets/ui/panel_flat.png")
	for m in ["patch_margin_left", "patch_margin_top", "patch_margin_right", "patch_margin_bottom"]:
		p.set(m, 16)
	p.size = Vector2(560, 124)
	p.position = Vector2(1960, 132) # below the in-game top bar and pilot cards
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate = Color(1, 1, 1, 0.97)
	var ic := TextureRect.new()
	ic.texture = icon(id)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(14, 12)
	ic.size = Vector2(100, 100)
	p.add_child(ic)
	var head := UI.label("ACHIEVEMENT UNLOCKED", 17, "extrabold", UI.hsl(hue, 100, 72), 4)
	head.position = Vector2(132, 22)
	p.add_child(head)
	var name := UI.label(a.name, 32, "black", Color.WHITE, 1)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2.ZERO
	name.position = Vector2(130, 48)
	name.size = Vector2(410, 44)
	p.add_child(name)
	var desc := UI.label(a.desc, 16, "medium", Color(0.82, 0.88, 1, 0.85))
	desc.clip_text = true
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.custom_minimum_size = Vector2.ZERO
	desc.position = Vector2(132, 88)
	desc.size = Vector2(410, 24)
	p.add_child(desc)
	_layer.add_child(p)
	_popup = p
	_popup_t = 0.0
	Audio.play("pu_life")
