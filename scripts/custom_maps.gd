class_name CustomMaps
## Maps made in the Level Editor. They live in their own folder in the user data
## (%APPDATA%\Solar Siege\maps\*.json on Windows) and never touch the nine built-in
## planets in data/levels.

const DIR := "user://maps"
const FORMAT := 1
const MAX_COLS := 13
const MAX_ROWS := 6
const KINDS := ["drone", "crab", "squid", "beetle", "wraith", "cruiser"]
const PLANETS := ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]
const MUSIC := ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto", "boss", "menu"]
## A cruiser takes two cells; the right-hand cell holds this marker.
const WIDE := "+"


static func blank(name := "New Map") -> Dictionary:
	var grid := []
	for r in MAX_ROWS:
		var row := []
		row.resize(MAX_COLS)
		row.fill("")
		grid.append(row)
	return {
		"format": FORMAT, "name": name, "backdrop": "mars", "music": "mars", "tint": 3,
		"grid": grid, "speed": 66.0, "fire_rate": 1.0, "bullet_speed": 420.0, "dive_chance": 0.03,
		"saucer": true, "saucer_every": 21.0, "shields": 4, "boss": false,
	}


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


static func folder_path() -> String:
	_ensure_dir()
	return ProjectSettings.globalize_path(DIR)


static func slug(name: String) -> String:
	var s := ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			s += ch
		elif s != "" and not s.ends_with("-"):
			s += "-"
	s = s.trim_suffix("-")
	return s if s != "" else "map"


## All saved maps, newest first: [{path, name, data}]
static func list() -> Array:
	_ensure_dir()
	var out := []
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".json"):
			continue
		var path := DIR + "/" + f
		var d := load_map(path)
		if d.is_empty():
			continue
		out.append({"path": path, "name": d.name, "data": d, "time": FileAccess.get_modified_time(path)})
	out.sort_custom(func(a, b): return a.time > b.time)
	return out


static func load_map(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return validate(d)


## Cleans up a map from a file or the network so the game can always play it.
static func validate(d) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("grid")) != TYPE_ARRAY:
		return {}
	var m := blank(str(d.get("name", "Custom Map")).substr(0, 32))
	for k in ["backdrop", "music"]:
		var v := str(d.get(k, m[k]))
		if v in (PLANETS if k == "backdrop" else MUSIC):
			m[k] = v
	m.tint = clampi(int(d.get("tint", m.tint)), 0, 8)
	m.speed = clampf(float(d.get("speed", m.speed)), 20.0, 160.0)
	m.fire_rate = clampf(float(d.get("fire_rate", m.fire_rate)), 0.0, 4.0)
	m.bullet_speed = clampf(float(d.get("bullet_speed", m.bullet_speed)), 200.0, 700.0)
	m.dive_chance = clampf(float(d.get("dive_chance", m.dive_chance)), 0.0, 0.3)
	m.saucer = bool(d.get("saucer", m.saucer))
	m.saucer_every = clampf(float(d.get("saucer_every", m.saucer_every)), 8.0, 60.0)
	m.shields = clampi(int(d.get("shields", m.shields)), 0, 4)
	m.boss = bool(d.get("boss", m.boss))
	var src: Array = d.grid
	for r in mini(src.size(), MAX_ROWS):
		if typeof(src[r]) != TYPE_ARRAY:
			continue
		for c in mini(src[r].size(), MAX_COLS):
			var k := str(src[r][c])
			if k in KINDS:
				if k == "cruiser" and (c + 1 >= MAX_COLS or str(src[r][c + 1]) != WIDE):
					continue
				m.grid[r][c] = k
				if k == "cruiser":
					m.grid[r][c + 1] = WIDE
	return m


static func count_aliens(m: Dictionary) -> int:
	var n := 0
	for row in m.grid:
		for k in row:
			if k in KINDS:
				n += 1
	return n


## Saves a map. Returns the file path ("" on failure). Pass the old path to overwrite it.
static func save_map(m: Dictionary, path := "") -> String:
	_ensure_dir()
	if path == "":
		var base := slug(m.name)
		path = "%s/%s.json" % [DIR, base]
		var i := 2
		while FileAccess.file_exists(path):
			path = "%s/%s-%d.json" % [DIR, base, i]
			i += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(m, "\t"))
	return path


static func delete_map(path: String) -> void:
	if path.begins_with(DIR) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Turns a custom map into a LevelData the game can play. The nine built-in
## LevelData resources are never modified.
static func to_level(m: Dictionary) -> LevelData:
	var lv := LevelData.new()
	lv.planet = m.name
	lv.tagline = "Custom Map"
	lv.fact = ""
	lv.custom = true
	lv.grid = m.grid.duplicate(true)
	lv.speed = m.speed
	lv.fire_rate = m.fire_rate
	lv.bullet_speed = m.bullet_speed
	lv.dive_chance = m.dive_chance
	lv.saucer_enabled = m.saucer
	lv.saucer_every = m.saucer_every
	lv.shield_count = m.shields
	lv.boss = m.boss
	lv.alien_tint = m.tint
	var base: LevelData = Global.levels[m.tint]
	lv.hue_shift = base.hue_shift
	var bd := PLANETS.find(m.backdrop)
	var bg_level: LevelData = Global.levels[maxi(bd, 0)]
	lv.background = bg_level.background
	lv.bunker_texture = bg_level.bunker_texture
	lv.bunker_dust = bg_level.bunker_dust
	lv.music = load("res://assets/audio/music/%s.wav" % m.music)
	return lv


## Two example maps so the editor has something to show the first time.
static func install_examples() -> void:
	_ensure_dir()
	if FileAccess.file_exists(DIR + "/.examples"):
		return
	var a := blank("Example - Checkerboard")
	a.backdrop = "neptune"
	a.music = "neptune"
	a.tint = 7
	var kinds := ["squid", "beetle", "crab", "crab", "drone", "drone"]
	for r in MAX_ROWS:
		for c in MAX_COLS:
			if (r + c) % 2 == 0:
				a.grid[r][c] = kinds[r]
	save_map(a)
	var b := blank("Example - Cruiser Wall")
	b.backdrop = "saturn"
	b.music = "boss"
	b.tint = 5
	b.speed = 54.0
	b.shields = 2
	b.boss = true
	for c in range(0, 12, 2):
		b.grid[0][c] = "cruiser"
		b.grid[0][c + 1] = WIDE
	for c in range(1, 12):
		b.grid[2][c] = "wraith"
		b.grid[3][c] = "squid"
	save_map(b)
	var f := FileAccess.open(DIR + "/.examples", FileAccess.WRITE)
	if f:
		f.store_string("1")
