extends Node2D
## Gameplay: the alien formation, shields, power-ups, bonus saucer, the Pluto boss, HUD and banners,
## for 1 to 4 pilots. Modes: "single", "local" (same computer, one controller each) and "online".
## Online, the host runs the battle and sends snapshots; guests draw them and send their controls.
## All graphics are textures from assets/; this script only moves things around and decides what happens.

const W := 1920.0
const H := 1080.0
const PLAYER_Y := 985.0
const BUNKER_Y := 830.0
const CELL := 5
const BUNKER_W := 200
const BUNKER_H := 110
const COL_W := 108.0
const SNAP_RATE := 1.0 / 30.0

const KINDS := ["drone", "crab", "squid", "beetle", "wraith", "cruiser"]
const ROW_H := {"cruiser": 124.0, "drone": 82.0, "crab": 82.0, "squid": 82.0, "beetle": 88.0, "wraith": 90.0}
const ALIEN_STATS := {
	"drone": [1, 10], "crab": [1, 20], "squid": [1, 30], "beetle": [2, 40], "wraith": [3, 60], "cruiser": [7, 150],
}
const ALIEN_SIZE := {
	"drone": Vector2(74, 58), "crab": Vector2(88, 60), "squid": Vector2(70, 66),
	"beetle": Vector2(90, 70), "wraith": Vector2(86, 74), "cruiser": Vector2(176, 100),
}
const ALIEN_BASE_HUE := {"drone": 120.0, "crab": 190.0, "squid": 310.0, "beetle": 30.0, "wraith": 270.0, "cruiser": 355.0}
const POWERS := ["dual", "spread", "speed", "shield", "bomb", "rapid", "life", "pierce", "homing", "wingman", "warp"]
const POWER_INFO := {
	"dual": ["DUAL LASERS", 190.0], "spread": ["TRIPLE SPREAD", 280.0], "speed": ["SPEED BOOST", 50.0],
	"shield": ["SHIELD", 210.0], "bomb": ["NOVA BOMB", 10.0], "rapid": ["RAPID FIRE", 130.0], "life": ["EXTRA SHIP", 330.0],
	"pierce": ["PIERCING LASER", 300.0], "homing": ["HOMING MISSILES", 30.0], "wingman": ["WINGMAN DRONE", 160.0],
	"warp": ["TIME WARP", 240.0],
}
## Timed power-ups each pilot can hold at once. Picking up one you already have adds its time again
## (up to POWER_CAP), and they all carry over to the next planet. Dying loses them.
const TIMED := ["dual", "spread", "rapid", "speed", "shield", "pierce", "homing", "wingman"]
const DURATION := {"dual": 15.0, "spread": 15.0, "rapid": 12.0, "speed": 12.0, "shield": 10.0, "pierce": 12.0, "homing": 14.0, "wingman": 16.0, "warp": 8.0}
const POWER_CAP := 60.0
const WARP_CAP := 24.0
## Time Warp slows every enemy (formation, divers, shots, saucer, boss) to this speed.
const WARP_SLOW := 0.45
const BULLET_TYPES := {"laser": 0, "pierce": -1, "missile": -2, "drone": -3}
const BOSS_STATES := ["enter", "fight", "dying"]
## The only achievements custom maps can earn; everything else needs the campaign.
const EDITOR_ACH := ["architect", "playtester", "boss_builder", "sharing_is_caring"]
const SCORE_ACH := [[10000, "five_figures"], [50000, "high_roller"], [100000, "legend"]]

const TEX_LASER := preload("res://assets/sprites/projectiles/laser_player.png")
const TEX_LASER_PIERCE := preload("res://assets/sprites/projectiles/laser_pierce.png")
const TEX_MISSILE := preload("res://assets/sprites/projectiles/missile.png")
const TEX_DRONE := preload("res://assets/sprites/wingman_drone.png")
const TEX_SAUCER := [preload("res://assets/sprites/saucer_0.png"), preload("res://assets/sprites/saucer_1.png")]
const TEX_SAUCER_FLASH := [preload("res://assets/sprites/saucer_flash_0.png"), preload("res://assets/sprites/saucer_flash_1.png")]
const TEX_BOSS := preload("res://assets/sprites/boss/boss.png")
const TEX_BOSS_ENRAGED := preload("res://assets/sprites/boss/boss_enraged.png")
const TEX_BOSS_FLASH := preload("res://assets/sprites/boss/boss_flash.png")
const TEX_EYE_CALM := preload("res://assets/sprites/boss/eye_calm.png")
const TEX_EYE_ENRAGED := preload("res://assets/sprites/boss/eye_enraged.png")
const TEX_PUPIL := preload("res://assets/sprites/boss/pupil.png")
const TEX_FLAME := preload("res://assets/sprites/fx/flame.png")
const TEX_SHIELD := preload("res://assets/sprites/fx/shield.png")
const TEX_SHOCKWAVE := preload("res://assets/sprites/fx/shockwave.png")
const TEX_BEAM := preload("res://assets/sprites/fx/laser_beam.png")
const TEX_WARN := preload("res://assets/sprites/fx/laser_warning.png")
const TEX_HUD_TOP := preload("res://assets/ui/hud_top.png")
const TEX_BAND := preload("res://assets/ui/banner_band.png")
const TEX_HUD_BOMB := preload("res://assets/sprites/hud/bomb.png")
const TEX_TIMER_TRACK := preload("res://assets/ui/timer_track.png")
const TEX_TIMER_FILL := preload("res://assets/ui/timer_fill.png")
const TEX_BOSSBAR_FRAME := preload("res://assets/ui/bossbar_frame.png")
const TEX_BOSSBAR_FILL := preload("res://assets/ui/bossbar_fill.png")
const TEX_PANEL := preload("res://assets/ui/panel_flat.png")


class Alien:
	var kind: String
	var hp: int
	var max_hp: int
	var score: int
	var slot: Vector2
	var pos: Vector2
	var size: Vector2
	var state := "formation" # formation | dive | return | minion
	var vel := Vector2.ZERO
	var t := 0.0
	var fired := false
	var flash := 0.0
	var tex: Array
	var flash_tex: Array
	var hue: float
	var alive := true
	var bomb_hit := -1
	var target := 0 # pilot a diver is chasing
	var rot := 0.0 # guests: tilt sent by the host


class Bullet:
	var pos: Vector2
	var vel: Vector2
	var size: Vector2
	var tex: Texture2D
	var enemy: bool
	var dmg := 1
	var hue: float
	var rot: float
	var r := 0 # plasma radius (0 = player laser, negative = other player shot types, see BULLET_TYPES)
	var owner := 0 # pilot who fired it (player shots)
	var kind := "plasma" # plasma | laser | pierce | missile | drone
	var pierced: Array = [] # aliens a piercing shot already went through
	var life := 3.0
	var hit := false # touched an enemy (for Sharpshooter)
	var kills := 0


class Bunker:
	var pos: Vector2
	var mask: PackedByteArray
	var image: Image
	var texture: ImageTexture
	var sprite: Sprite2D
	var dirty := false
	var sent := true


class Pilot:
	var idx := 0
	var name := "Pilot"
	var color := 0
	var input: PlayerInput
	var peer_id := 0
	var tex: Texture2D
	var x := W / 2
	var vx := 0.0
	var alive := true
	var respawn_t := 0.0
	var invuln := 0.0
	var cooldown := 0.0
	var timers := {} # power -> seconds left (see TIMED)
	var tmax := {} # power -> seconds right after the last pickup (for the HUD bar)
	var missile_cd := 0.0
	var drone_cd := 0.0
	var missile_side := 1.0
	var lives := 3
	var bombs := 1
	var score := 0
	var left := false # online: disconnected
	## achievement tracking
	var run_lost := 0 # ships lost this campaign
	var run_bombs := 0 # Nova Bombs used this campaign
	var planet_hit := false
	var planet_missed := false
	var planet_shots := 0
	var planet_pickups := 0
	var turtle := -2 # shield it has stayed under this planet (-2 not yet, -3 left cover)
	var boss_lost := false
	var score_tier := 0

	func t(k: String) -> float:
		return timers.get(k, 0.0)

	func lose_powers() -> void:
		timers.clear()
		tmax.clear()

	func playing() -> bool:
		return alive and not left

	func out() -> bool:
		return left or (not alive and lives <= 0)


# ---------------------------------------------------------------- state
var mode := "single" # single | local | online
var role := "" # online: host | guest
var my_idx := 0 # online guest: which pilot is me
var pilots: Array[Pilot] = []
var lv: LevelData
var level_index := 0
var custom_map := {}
var from_editor := false
var diff := "normal"
var dm: Dictionary
var state := "intro" # intro | play | boss_warn | cleared | gameover | victory
var state_t := 0.0
var checkpoint := {}
var start_info := {}

var hi_score := 0
var team_bonus := 0
var warp_t := 0.0 # clear bonuses (single player adds them to the pilot)

var aliens: Array[Alien] = []
var total_aliens := 1
var form_x := W / 2
var form_y := 0.0
var form_start_y := 130.0
var form_dir := 1.0
var drop_left := 0.0
var anim_t := 0.0
var anim_frame := 0
var bullets: Array[Bullet] = []
var powers: Array = [] # [kind, pos, vy, t]
var bunkers: Array[Bunker] = []
var saucer = null # {pos, dir, hp, flash}
var saucer_t := 0.0
var fire_acc := 0.0
var boss = null # Dictionary
var lasers: Array = [] # {x, t, warn, dur}
var jobs: Array = [] # [time_left, Callable]
var wave = null # {pos, r, id}
var wave_id := 0
var flash_a := 0.0
var shake := 0.0
var time := 0.0
var new_high := false
var clear_bonus := 0
var end_shown := false
var debug_god := false
var run := {} # this campaign: from_start, continued, retried, saucers_seen, saucers_killed
var planet_bunker_hit := false
var planet_close := false
var bunker_cells: Array = [] # solid cells per shield at the start of the planet

var _plasma_cache := {}
var _alien_tex := {}
var _power_tex := {}
var _hud_power_tex := {}
var _events: Array = []
var _snap_t := 0.0
var _bunker_t := 0.0
var _guest_bombs := 0
var _last_snap_ms := 0
var _paused_online: Dialog
var _card_style: StyleBoxTexture

@onready var world: Node2D = $World
@onready var stars: Starfield = $World/Stars
@onready var fx: FxSystem = $World/Fx
@onready var hud: Node2D = $HUD/Hud
@onready var banner: Node2D = $Banners/Banner
@onready var flash_rect: ColorRect = $Banners/Flash
@onready var end_menu: Control = $Banners/EndMenu


func _ready() -> void:
	for n in [$World/Lasers, $World/Bullets, $World/Flames, $World/Shield, $World/Wave]:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	$World/Lasers.draw.connect(_draw_lasers)
	$World/Boss.draw.connect(_draw_boss)
	$World/Actors.draw.connect(_draw_actors)
	$World/Bullets.draw.connect(_draw_bullets)
	$World/Flames.draw.connect(_draw_flames)
	$World/Player.draw.connect(_draw_player)
	$World/Shield.draw.connect(_draw_shield)
	$World/Wave.draw.connect(_draw_wave)
	hud.draw.connect(_draw_hud)
	banner.draw.connect(_draw_banners)
	for k in POWER_INFO:
		_power_tex[k] = load("res://assets/sprites/powerups/%s.png" % k)
		_hud_power_tex[k] = load("res://assets/sprites/hud/power_%s.png" % k)
	hi_score = Global.high_score()
	var start: Dictionary = Global.play_start
	if start.is_empty():
		start = {"level": 0, "score": 0, "lives": 3, "bombs": 1, "difficulty": "normal"}
	start_info = start.duplicate(true)
	mode = start.get("mode", "single")
	diff = start.get("difficulty", "normal")
	dm = Global.DIFFICULTY[diff]
	from_editor = start.get("from_editor", false)
	custom_map = start.get("custom", {})
	if not custom_map.is_empty():
		custom_map = CustomMaps.validate(custom_map)
	_make_pilots(start)
	_start_run(start)
	if mode == "online":
		role = "host" if Net.is_host() else "guest"
		Net.game_message.connect(_on_net_message)
		Net.peer_left.connect(_on_peer_left)
		Net.host_left.connect(_on_host_left)
	if role == "guest":
		_last_snap_ms = Time.get_ticks_msec()
		_guest_setup(start)
	else:
		load_level(start.get("level", 0))


func _make_pilots(start: Dictionary) -> void:
	pilots.clear()
	var list: Array = start.get("players", [])
	if mode == "single" or list.is_empty():
		var p := Pilot.new()
		p.name = Global.pilot_name()
		p.input = PlayerInput.any()
		p.color = 0
		p.lives = start.get("lives", dm.lives)
		p.bombs = start.get("bombs", 1)
		p.score = start.get("score", 0)
		var saved: Dictionary = start.get("powers", {})
		for k in saved:
			if k in TIMED:
				p.timers[k] = clampf(float(saved[k]), 0.0, POWER_CAP)
				p.tmax[k] = maxf(p.timers[k], DURATION[k])
		warp_t = clampf(float(start.get("warp", 0.0)), 0.0, WARP_CAP)
		list = []
		pilots.append(p)
	for i in list.size():
		var d: Dictionary = list[i]
		var p := Pilot.new()
		p.idx = i
		p.name = str(d.get("name", "Pilot %d" % (i + 1)))
		p.color = int(d.get("color", i))
		p.peer_id = int(d.get("id", 0))
		var inp := str(d.get("input", "any"))
		if inp.begins_with("pad:"):
			p.input = PlayerInput.pad(int(inp.substr(4)))
		elif inp == "kb":
			p.input = PlayerInput.keyboard()
		elif inp == "bot":
			p.input = PlayerInput.bot()
		elif mode == "online" and p.peer_id != Net.my_id:
			p.input = PlayerInput.remote()
		else:
			p.input = PlayerInput.any()
		if mode == "online" and p.peer_id == Net.my_id:
			my_idx = i
		p.lives = dm.lives
		p.bombs = 1
		pilots.append(p)
	for p in pilots:
		p.tex = Global.ship_texture(p.color)
	_place_pilots()


func _start_run(start: Dictionary) -> void:
	run = (start.get("run", {}) as Dictionary).duplicate() if mode == "single" else {}
	if run.is_empty() or not run.has("from_start"):
		run = {"from_start": int(start.get("level", 0)) == 0, "continued": false, "retried": false, "saucers_seen": 0, "saucers_killed": 0}
	if start.get("continued", false):
		run.continued = true
	if start.get("retried", false):
		run.retried = true
	if mode == "single":
		pilots[0].run_lost = int(run.get("lost", 0))
		pilots[0].run_bombs = int(run.get("bombs", 0))
	if mode != "single":
		for p in pilots:
			if _ach_local_pilot(p):
				Achievements.add_item("all_colours", str(p.color))


# ---------------------------------------------------------------- achievements
func _ach_local_pilot(p: Pilot) -> bool:
	return mode != "online" or p.idx == my_idx


## Credits an achievement to a pilot: unlock (n = 0), add to a counter (n > 0) or add one of a set (item).
## Online, the host works it out for every pilot and sends guests theirs.
func _ach(p: Pilot, id: String, n := 0, item := "") -> void:
	if is_guest() or p == null:
		return
	if lv != null and lv.custom and not (id in EDITOR_ACH):
		return
	if _ach_local_pilot(p):
		_ach_apply(id, n, item)
	else:
		_ev(["ach", p.idx, id, n, item])


func _ach_apply(id: String, n: int, item: String) -> void:
	if item != "":
		Achievements.add_item(id, item)
	elif n > 0:
		Achievements.add(id, n)
	else:
		Achievements.unlock(id)


func _bunker_solid(b: Bunker) -> int:
	return b.mask.count(1)


func _place_pilots() -> void:
	var n := pilots.size()
	for p in pilots:
		p.x = W * (p.idx + 1) / (n + 1) if n > 1 else W / 2
		p.vx = 0


func multi() -> bool:
	return pilots.size() > 1


func is_guest() -> bool:
	return role == "guest"


func team_score() -> int:
	var s := 0
	for p in pilots:
		s += p.score
	return s


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and not get_tree().paused:
		if state in ["play", "intro", "boss_warn"] and mode != "online" and not OS.has_feature("autotest"):
			pause()


func _exit_tree() -> void:
	Audio.saucer_stop()


# ---------------------------------------------------------------- level setup
func _level_for(i: int) -> LevelData:
	if not custom_map.is_empty():
		return CustomMaps.to_level(custom_map)
	return Global.levels[i]


func _level_power() -> int:
	## How far into the campaign this level feels (custom maps count as mid-campaign).
	return 4 if lv.custom else level_index


func load_level(i: int) -> void:
	level_index = i
	lv = _level_for(i)
	if mode == "single" and not lv.custom:
		var p := pilots[0]
		var r := run.duplicate()
		r["lost"] = p.run_lost
		r["bombs"] = p.run_bombs
		checkpoint = {"level": i, "score": p.score, "lives": p.lives, "bombs": p.bombs, "difficulty": diff,
			"powers": p.timers.duplicate(), "warp": warp_t, "run": r}
		Global.save_game(checkpoint)
	_ev(["level", i])
	_setup_visuals()
	bullets.clear()
	powers.clear()
	jobs.clear()
	lasers.clear()
	_stop_saucer()
	saucer_t = lv.saucer_every * randf_range(0.6, 1.0)
	boss = null
	wave = null
	for p in pilots:
		p.alive = p.lives > 0 and not p.left
		p.respawn_t = 0.0
		p.invuln = 0.0
		## power-ups carry over to the next planet (only dying takes them away)
		if not p.alive:
			p.lose_powers()
	_place_pilots()
	_build_formation()
	planet_bunker_hit = false
	planet_close = false
	bunker_cells = bunkers.map(_bunker_solid)
	for p in pilots:
		p.planet_hit = false
		p.planet_missed = false
		p.planet_shots = 0
		p.planet_pickups = 0
		p.turtle = -2
	if not lv.custom and i == Global.levels.size() - 1:
		for p in pilots:
			if p.alive:
				_ach(p, "edge_of_darkness")
				if TIMED.filter(func(k): return p.t(k) > 0).size() >= 4:
					_ach(p, "inheritance")
	if lv.custom and mode == "online" and role == "host":
		for p in pilots:
			if p.idx != my_idx:
				var who := p
				schedule(2.0, func(): _ach(who, "sharing_is_caring"))
	state = "intro"
	state_t = 0.0
	_music(lv.music)
	sfx("level_start")


func _setup_visuals() -> void:
	$World/Background.texture = lv.background
	stars.setup(lv.planet.length() * 977 + 13)
	fx.clear()
	_build_bunkers()


func _alien_textures(kind: String) -> Array:
	var key := "%s_%d" % [kind, lv.alien_tint]
	if not _alien_tex.has(key):
		_alien_tex[key] = [
			[load("res://assets/sprites/aliens/%s_%d_0.png" % [kind, lv.alien_tint]), load("res://assets/sprites/aliens/%s_%d_1.png" % [kind, lv.alien_tint])],
			[load("res://assets/sprites/aliens/%s_flash_0.png" % kind), load("res://assets/sprites/aliens/%s_flash_1.png" % kind)],
		]
	return _alien_tex[key]


func _plasma(hue: float, r: int) -> Texture2D:
	var h := posmod(roundi(hue), 360)
	var key := "%d_%d" % [h, r]
	if not _plasma_cache.has(key):
		var path := "res://assets/sprites/projectiles/plasma_%s.png" % key
		if not ResourceLoader.exists(path):
			path = _nearest_plasma(h, r)
		_plasma_cache[key] = load(path)
	return _plasma_cache[key]


func _nearest_plasma(h: int, r: int) -> String:
	## Custom maps can mix any alien colours; use the closest exported shot colour.
	var best := "res://assets/sprites/projectiles/plasma_290_11.png"
	var best_d := 9999
	for f in ResourceLoader.list_directory("res://assets/sprites/projectiles"):
		if not f.begins_with("plasma_") or not f.ends_with(".png"):
			continue
		var parts := f.trim_suffix(".png").split("_")
		var fh := int(parts[1])
		var fr := int(parts[2])
		var d := mini(absi(fh - h), 360 - absi(fh - h)) + absi(fr - r) * 40
		if d < best_d:
			best_d = d
			best = "res://assets/sprites/projectiles/" + f
	return best


func _make_alien(kind: String, slot: Vector2, st := "formation") -> Alien:
	var a := Alien.new()
	var stats: Array = ALIEN_STATS[kind]
	var hp_bonus := int(_level_power() / 3) if kind == "cruiser" else 0
	if kind == "cruiser" and multi():
		hp_bonus += pilots.size() - 1
	a.kind = kind
	a.hp = stats[0] + hp_bonus
	a.max_hp = a.hp
	a.score = stats[1]
	a.slot = slot
	a.pos = Vector2(form_x, form_y) + slot
	a.size = ALIEN_SIZE[kind]
	a.state = st
	a.hue = ALIEN_BASE_HUE[kind] + lv.hue_shift
	var t := _alien_textures(kind)
	a.tex = t[0]
	a.flash_tex = t[1]
	return a


func _build_formation() -> void:
	aliens.clear()
	form_x = W / 2
	form_start_y = 130.0
	form_y = form_start_y - 700.0
	if lv.custom:
		_build_custom_formation()
	else:
		var y := 0.0
		var cols := lv.cols
		for kind in lv.rows:
			var rh: float = ROW_H[kind]
			y += rh / 2
			if kind == "cruiser":
				var n := ceili(cols / 2.0)
				for c in n:
					aliens.append(_make_alien(kind, Vector2((c - (n - 1) / 2.0) * COL_W * 2, y)))
			else:
				for c in cols:
					aliens.append(_make_alien(kind, Vector2((c - (cols - 1) / 2.0) * COL_W, y)))
			y += rh / 2
	total_aliens = maxi(1, aliens.size())
	form_dir = 1.0 if randf() < 0.5 else -1.0
	drop_left = 0.0
	for a in aliens:
		a.pos = Vector2(form_x, form_y) + a.slot


func _build_custom_formation() -> void:
	## Editor grid: keep empty rows and columns inside the used area so the shape stays as drawn.
	var g: Array = lv.grid
	var c0 := CustomMaps.MAX_COLS
	var c1 := -1
	var r0 := CustomMaps.MAX_ROWS
	var r1 := -1
	for r in g.size():
		for c in g[r].size():
			if str(g[r][c]) != "":
				c0 = mini(c0, c)
				c1 = maxi(c1, c)
				r0 = mini(r0, r)
				r1 = maxi(r1, r)
	if c1 < 0:
		return
	var mid := (c0 + c1) / 2.0
	var y := 0.0
	for r in range(r0, r1 + 1):
		var rh := 82.0
		for k in g[r]:
			if k in ROW_H:
				rh = maxf(rh, ROW_H[k])
		y += rh / 2
		for c in g[r].size():
			var k := str(g[r][c])
			if k in KINDS:
				var cx: float = c + (0.5 if k == "cruiser" else 0.0)
				aliens.append(_make_alien(k, Vector2((cx - mid) * COL_W, y)))
		y += rh / 2


func _build_bunkers() -> void:
	for b in bunkers:
		b.sprite.queue_free()
	bunkers.clear()
	var count := lv.shield_count if lv.custom else 4
	if count <= 0:
		return
	var src := lv.bunker_texture.get_image()
	if src.is_compressed():
		src.decompress()
	src.clear_mipmaps()
	src.convert(Image.FORMAT_RGBA8)
	var cols := BUNKER_W / CELL
	var rows := BUNKER_H / CELL
	for i in count:
		var b := Bunker.new()
		var cx := W * (i + 1) / (count + 1)
		b.pos = Vector2(cx - BUNKER_W / 2.0, BUNKER_Y - BUNKER_H / 2.0)
		b.image = src.duplicate()
		b.mask = PackedByteArray()
		b.mask.resize(cols * rows)
		for r in rows:
			for q in cols:
				var a := b.image.get_pixel(q * CELL * 2 + CELL, r * CELL * 2 + CELL).a
				b.mask[r * cols + q] = 1 if a > 0.5 else 0
		b.texture = ImageTexture.create_from_image(_with_mipmaps(b.image))
		b.sprite = Sprite2D.new()
		b.sprite.centered = false
		b.sprite.texture = b.texture
		b.sprite.scale = Vector2(0.5, 0.5)
		b.sprite.position = b.pos
		$World/Bunkers.add_child(b.sprite)
		bunkers.append(b)


func _with_mipmaps(img: Image) -> Image:
	var c := img.duplicate()
	c.generate_mipmaps()
	return c


# ---------------------------------------------------------------- bunker helpers
func _bunker_at(x: float, y: float) -> Array:
	for b in bunkers:
		if x < b.pos.x or x >= b.pos.x + BUNKER_W or y < b.pos.y or y >= b.pos.y + BUNKER_H:
			continue
		var q := int((x - b.pos.x) / CELL)
		var r := int((y - b.pos.y) / CELL)
		if b.mask[r * (BUNKER_W / CELL) + q]:
			return [b, q, r]
	return []


func _erode(b: Bunker, x: float, y: float, radius: float) -> void:
	var lx := x - b.pos.x
	var ly := y - b.pos.y
	var cols := BUNKER_W / CELL
	var rows := BUNKER_H / CELL
	var q0 := maxi(0, int((lx - radius * 1.2) / CELL) - 1)
	var q1 := mini(cols - 1, int((lx + radius * 1.2) / CELL) + 1)
	var r0 := maxi(0, int((ly - radius * 1.2) / CELL) - 1)
	var r1 := mini(rows - 1, int((ly + radius * 1.2) / CELL) + 1)
	for r in range(r0, r1 + 1):
		for q in range(q0, q1 + 1):
			var i := r * cols + q
			if not b.mask[i]:
				continue
			var d := Vector2(q * CELL + CELL / 2.0 - lx, r * CELL + CELL / 2.0 - ly).length()
			if d < radius * (0.6 + randf() * 0.6):
				_clear_cell(b, i)
				b.sent = false


func _clear_cell(b: Bunker, i: int) -> void:
	var cols := BUNKER_W / CELL
	var q := i % cols
	var r := i / cols
	b.mask[i] = 0
	planet_bunker_hit = true
	b.image.fill_rect(Rect2i(q * CELL * 2 - 1, r * CELL * 2 - 1, CELL * 2 + 2, CELL * 2 + 2), Color(0, 0, 0, 0))
	b.dirty = true


# ---------------------------------------------------------------- helpers, effects & sound (mirrored to online guests)
func schedule(delay: float, fn: Callable) -> void:
	jobs.append([delay, fn])


func _ev(e: Array) -> void:
	if role == "host":
		_events.append(e)


func sfx(name: String) -> void:
	Audio.play(name)
	_ev(["sfx", name])


func _music(stream: AudioStream) -> void:
	Audio.play_music(stream)
	_ev(["music", stream.resource_path if stream else ""])


func fx_explosion(x: float, y: float, hue: float, scale := 1.0) -> void:
	fx.explosion(x, y, hue, scale)
	_ev(["ex", x, y, hue, scale])


func fx_hit(x: float, y: float, hue: float) -> void:
	fx.hit(x, y, hue)
	_ev(["hit", x, y, hue])


func fx_dust(x: float, y: float, c: Color) -> void:
	fx.dust(x, y, c)
	_ev(["dust", x, y, c])


func fx_text(x: float, y: float, msg: String, c: Color, size := 26, life := 1.0) -> void:
	fx.text(x, y, msg, c, size, life)
	_ev(["txt", x, y, msg, c, size, life])


func fx_add(kind: int, x: float, y: float, opts: Dictionary) -> void:
	fx.add(kind, x, y, opts)
	_ev(["fx", kind, x, y, opts])


func set_flash(a: float) -> void:
	flash_a = maxf(flash_a, a)
	_ev(["flash", a])


func add_shake(n: float) -> void:
	if Global.settings.shake:
		shake = maxf(shake, n)
	_ev(["shake", n])


func _saucer_sound(on: bool) -> void:
	if on:
		Audio.saucer_start()
	else:
		Audio.saucer_stop()
	_ev(["saucer", on])


func _formation_aliens() -> Array[Alien]:
	var out: Array[Alien] = []
	for a in aliens:
		if a.alive and a.state != "minion":
			out.append(a)
	return out


func add_score(p: Pilot, n: int) -> void:
	p.score += n
	_score_ach(p)
	if mode == "single" and not lv.custom and p.score > hi_score:
		hi_score = p.score


func _score_ach(p: Pilot) -> void:
	while p.score_tier < SCORE_ACH.size() and p.score >= SCORE_ACH[p.score_tier][0]:
		_ach(p, SCORE_ACH[p.score_tier][1])
		p.score_tier += 1


func _overlap(a: Vector2, asz: Vector2, b: Vector2, bsz: Vector2) -> bool:
	return absf(a.x - b.x) * 2 < asz.x + bsz.x and absf(a.y - b.y) * 2 < asz.y + bsz.y


func _any_playing() -> bool:
	for p in pilots:
		if p.playing():
			return true
	return false


## A pilot for the aliens to aim at (random among those flying, or the nearest to x).
func _target(near_x := -1.0) -> Pilot:
	var live: Array[Pilot] = []
	for p in pilots:
		if p.playing():
			live.append(p)
	if live.is_empty():
		return pilots[0]
	if near_x >= 0:
		var best := live[0]
		for p in live:
			if absf(p.x - near_x) < absf(best.x - near_x):
				best = p
		return best
	return live.pick_random()


func _difficulty_scale() -> float:
	return 1.0 + 0.35 * (pilots.size() - 1)


func pause() -> void:
	if mode == "online":
		_online_menu()
		return
	if get_tree().paused:
		return
	get_tree().paused = true
	Audio.play("menu_select")
	var resume := func():
		Dialog.close_top()
		get_tree().paused = false
	var items := [["Resume", resume], ["Options", func(): OptionsMenu.open()]]
	if mode == "single" and not lv.custom:
		items.append(["Save & Quit", func():
			Global.save_game(checkpoint)
			Global.goto_menu()])
	if from_editor:
		items.append(["Back to Editor", func(): Global.goto_scene("res://scenes/editor.tscn")])
	items.append(["Quit to Menu", func():
		var lines := ["Progress on this planet will be lost.", "You can continue from the start of this planet."]
		if mode != "single" or lv.custom:
			lines = ["This game will end."]
		Dialog.open("Quit to Menu?", lines, [
			["Quit", Global.goto_menu],
			["Cancel", Dialog.close_top],
		])])
	var title := ("Planet %d: %s" % [level_index + 1, lv.planet]) if not lv.custom else lv.planet
	Dialog.open("Paused", [title], items, 760, resume)


func _online_menu() -> void:
	## Online games don't stop for one player: this menu sits over the running battle.
	if is_instance_valid(_paused_online):
		return
	Audio.play("menu_select")
	_paused_online = Dialog.open("Menu", ["The battle keeps going while this is open."], [
		["Resume", Dialog.close_top],
		["Options", func(): OptionsMenu.open()],
		["Leave Game", func():
			Dialog.open("Leave the Game?", ["Your squadron will carry on without you." if is_guest() else "The game ends for everyone."], [
				["Leave", Global.goto_menu],
				["Cancel", Dialog.close_top],
			])],
	], 760)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in ["play", "intro", "boss_warn", "cleared"]:
		get_viewport().set_input_as_handled()
		pause()


# ---------------------------------------------------------------- update
func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	time += dt
	shake = maxf(0.0, shake - dt * 40)
	flash_a = maxf(0.0, flash_a - dt * 2.2)
	var any_speed := false
	for p in pilots:
		any_speed = any_speed or p.t("speed") > 0
	stars.speed = (2.6 if any_speed else 1.0) * (0.35 if warp_t > 0 else 1.0)

	if is_guest():
		_guest_update(dt)
	else:
		_simulate(dt)
		if role == "host":
			_host_send(dt)

	for b in bunkers:
		if b.dirty:
			b.texture.update(_with_mipmaps(b.image))
			b.dirty = false
	world.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0 else Vector2.ZERO
	flash_rect.color.a = flash_a * 0.7
	for n in [$World/Lasers, $World/Boss, $World/Actors, $World/Bullets, $World/Flames, $World/Player, $World/Shield, $World/Wave, hud, banner]:
		n.queue_redraw()


func _simulate(dt: float) -> void:
	state_t += dt
	for j in jobs:
		j[0] -= dt
	var due := jobs.filter(func(j): return j[0] <= 0)
	jobs = jobs.filter(func(j): return j[0] > 0)
	for j in due:
		j[1].call()

	match state:
		"intro":
			form_y = lerpf(form_start_y - 700, form_start_y, _ease_out_cubic(clampf(state_t / 2.4, 0, 1)))
			for a in aliens:
				a.pos = Vector2(form_x, form_y) + a.slot
			_animate(dt, 0.5)
			_update_pilots(dt, false)
			if state_t > 3.2:
				state = "play"
				state_t = 0
		"play":
			_tick_warp(dt)
			var edt := dt * _enemy_speed()
			_update_pilots(dt, true)
			_update_formation(edt)
			_update_aliens(edt)
			_update_enemy_fire(edt)
			_update_saucer(edt)
			_update_boss(edt)
			_update_bullets(dt)
			_update_powers(dt)
			_update_wave(dt)
			_check_progress()
		"boss_warn":
			_tick_warp(dt)
			_update_pilots(dt, true)
			_update_bullets(dt)
			_update_powers(dt)
			_update_wave(dt)
			if state_t > 3.2:
				state = "play"
				state_t = 0
				_spawn_boss()
		"cleared":
			_update_pilots(dt, false)
			_update_powers(dt)
			bullets.assign(bullets.filter(func(b): return not b.enemy))
			_update_bullets(dt)
			if state_t > 3.6:
				_award_clear_bonus()
				load_level(level_index + 1)
		"gameover", "victory":
			_update_bullets(dt)
			if state == "victory" and randf() < dt * 3:
				fx_explosion(randf_range(200, W - 200), randf_range(150, 600), randf_range(0, 360), randf_range(0.6, 1.4))
			if state_t > 1.5 and not end_shown:
				_show_end_menu()


func _award_clear_bonus() -> void:
	## Every pilot still in the fight gets the bonus.
	for p in pilots:
		if not p.out():
			add_score(p, clear_bonus)
	clear_bonus = 0


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)


func _animate(dt: float, rate: float) -> void:
	anim_t += dt
	if anim_t > rate:
		anim_t = 0
		anim_frame ^= 1


func _update_pilots(dt: float, can_fire: bool) -> void:
	for p in pilots:
		_update_pilot(p, dt, can_fire)


func _enemy_speed() -> float:
	return WARP_SLOW if warp_t > 0 else 1.0


func _tick_warp(dt: float) -> void:
	if warp_t > 0:
		warp_t = maxf(0.0, warp_t - dt)
		if warp_t == 0:
			sfx("menu_back")


## Power-up timers only run while you're fighting, not during the planet banners.
func _tick_timers(p: Pilot, dt: float, fighting: bool) -> void:
	p.invuln = maxf(0.0, p.invuln - dt)
	if not fighting:
		return
	for k in p.timers.keys():
		var v: float = p.timers[k] - dt
		if v <= 0:
			p.timers.erase(k)
			p.tmax.erase(k)
			if k == "shield":
				sfx("menu_back")
		else:
			p.timers[k] = v


func _move_pilot(p: Pilot, dt: float) -> void:
	var mx := 860.0 if p.t("speed") > 0 else 540.0
	var dir := p.input.axis()
	p.vx += (dir * mx - p.vx) * minf(1.0, dt * 14)
	p.x = clampf(p.x + p.vx * dt, 70, W - 70)


func _update_pilot(p: Pilot, dt: float, can_fire: bool) -> void:
	if p.left:
		return
	_tick_timers(p, dt, can_fire)
	if not p.alive:
		if p.lives > 0:
			p.respawn_t -= dt
			if p.respawn_t <= 0:
				p.alive = true
				p.invuln = 2.5
				p.x = W * (p.idx + 1) / (pilots.size() + 1) if multi() else W / 2
				p.vx = 0
		return
	if p.input.source != PlayerInput.Source.REMOTE:
		_move_pilot(p, dt) # online guests move their own ship and send its position
	if state == "play" and p.turtle != -3:
		var under := -1
		for i in bunkers.size():
			if p.x >= bunkers[i].pos.x and p.x < bunkers[i].pos.x + BUNKER_W:
				under = i
		if under < 0 or (p.turtle >= 0 and p.turtle != under):
			p.turtle = -3
		elif p.turtle == -2:
			p.turtle = under
	if p.t("speed") > 0 and randf() < dt * 40:
		fx_add(FxSystem.K.STREAK, p.x + randf_range(-30, 30), PLAYER_Y + 40, {"vy": 300, "life": 0.4, "size": 3, "hue": 50, "light": 70, "drag": 1.0})
	p.cooldown -= dt
	var bomb := p.input.bomb_pressed()
	var firing := can_fire and p.input.fire()
	if firing and p.cooldown <= 0:
		_shoot(p)
	if p.t("homing") > 0:
		p.missile_cd -= dt
		if firing and p.missile_cd <= 0:
			_fire_missile(p)
	if p.t("wingman") > 0:
		p.drone_cd -= dt
		if firing and p.drone_cd <= 0:
			_fire_drone(p)
	if can_fire and bomb:
		_detonate_bomb(p)


func _player_bullet(p: Pilot, pos: Vector2, angle: float, kind: String, speed := 1400.0) -> Bullet:
	var b := Bullet.new()
	b.pos = pos
	b.vel = Vector2(sin(angle), -cos(angle)) * speed
	b.size = Vector2(8, 36)
	b.kind = kind
	b.r = BULLET_TYPES[kind]
	b.tex = {"laser": TEX_LASER, "pierce": TEX_LASER_PIERCE, "missile": TEX_MISSILE, "drone": TEX_LASER}[kind]
	b.enemy = false
	b.hue = 185
	b.rot = angle
	b.owner = p.idx
	if kind == "missile":
		b.size = Vector2(16, 30)
		b.dmg = 2
	elif kind == "drone":
		b.size = Vector2(6, 26)
	bullets.append(b)
	return b


## Weapons stack: Dual gives two parallel lasers, Triple Spread adds two angled ones,
## and with both you fire four. Piercing makes every laser go through aliens.
func _shoot(p: Pilot) -> void:
	p.cooldown = 0.14 if p.t("rapid") > 0 else 0.3
	p.planet_shots += 1
	if p.t("dual") > 0 and p.t("spread") > 0 and p.t("pierce") > 0:
		_ach(p, "four_barrels")
	var y := PLAYER_Y - 50
	var kind := "pierce" if p.t("pierce") > 0 else "laser"
	var dual := p.t("dual") > 0
	var spread := p.t("spread") > 0
	if dual:
		_player_bullet(p, Vector2(p.x - 22, y), 0.0, kind)
		_player_bullet(p, Vector2(p.x + 22, y), 0.0, kind)
	else:
		_player_bullet(p, Vector2(p.x, y), 0.0, kind)
	if spread:
		_player_bullet(p, Vector2(p.x - 14, y), -0.2, kind)
		_player_bullet(p, Vector2(p.x + 14, y), 0.2, kind)
	sfx("laser_spread" if spread else ("laser_dual" if dual else "laser"))
	fx_add(FxSystem.K.GLOW, p.x, y + 6, {"life": 0.08, "size": 30, "grow": -100, "hue": 300 if kind == "pierce" else 185, "light": 80})


func _fire_missile(p: Pilot) -> void:
	p.missile_cd = 0.7
	p.missile_side *= -1
	var b := _player_bullet(p, Vector2(p.x + 34 * p.missile_side, PLAYER_Y - 20), 0.35 * p.missile_side, "missile", 520.0)
	b.life = 3.0
	sfx("alien_shot")


func drone_pos(p: Pilot) -> Vector2:
	return Vector2(p.x - 92 + sin(time * 2.2 + p.idx) * 8, PLAYER_Y - 26 + sin(time * 3.1 + p.idx) * 6)


func _fire_drone(p: Pilot) -> void:
	p.drone_cd = 0.36
	var d := drone_pos(p)
	_player_bullet(p, d + Vector2(0, -24), 0.0, "drone")


## Missiles steer toward the nearest target.
func _steer_missile(b: Bullet, dt: float) -> void:
	var target := Vector2.INF
	var best := INF
	for a in aliens:
		if a.alive:
			var d := b.pos.distance_squared_to(a.pos)
			if d < best:
				best = d
				target = a.pos
	if saucer != null and b.pos.distance_squared_to(saucer.pos) < best:
		best = b.pos.distance_squared_to(saucer.pos)
		target = saucer.pos
	if boss != null and boss.state == "fight" and b.pos.distance_squared_to(Vector2(boss.x, boss.y)) < best:
		target = Vector2(boss.x, boss.y)
	var speed := minf(b.vel.length() + 900 * dt, 980.0)
	var ang := b.vel.angle()
	if target != Vector2.INF:
		var want := (target - b.pos).angle()
		ang = rotate_toward(ang, want, 5.5 * dt)
	b.vel = Vector2.from_angle(ang) * speed
	b.rot = ang + PI / 2
	if randf() < dt * 30:
		fx_add(FxSystem.K.SMOKE, b.pos.x, b.pos.y, {"life": 0.4, "size": 6, "grow": 14, "hue": 30, "sat": 30, "light": 55, "drag": 0.2})


func _detonate_bomb(p: Pilot) -> void:
	if p.bombs <= 0:
		if mode == "single" or p.idx == my_idx:
			Audio.play("denied")
		return
	p.bombs -= 1
	p.run_bombs += 1
	wave_id += 1
	wave = {"pos": Vector2(p.x, PLAYER_Y - 30), "r": 0.0, "id": wave_id, "owner": p.idx}
	set_flash(0.9)
	add_shake(26)
	sfx("bomb")
	for b in bullets:
		if b.enemy:
			fx_hit(b.pos.x, b.pos.y, b.hue)
	bullets.assign(bullets.filter(func(b): return not b.enemy))
	lasers.clear()


func _update_wave(dt: float) -> void:
	if wave == null:
		return
	wave.r += 2300 * dt
	var owner: Pilot = pilots[clampi(wave.owner, 0, pilots.size() - 1)]
	for a in aliens:
		if not a.alive or a.bomb_hit == wave.id:
			continue
		if a.pos.distance_to(wave.pos) < wave.r:
			a.bomb_hit = wave.id
			_damage_alien(a, 3, owner, "bomb")
			if not a.alive:
				wave["kills"] = int(wave.get("kills", 0)) + 1
				if wave.kills >= 10:
					_ach(owner, "nova")
	if saucer != null and saucer.pos.distance_to(wave.pos) < wave.r:
		_damage_saucer(3, owner)
	if boss != null and boss.state == "fight" and boss.bomb_hit != wave.id and Vector2(boss.x, boss.y).distance_to(wave.pos) < wave.r:
		boss.bomb_hit = wave.id
		_damage_boss(12, boss.x, boss.y + 60, owner)
	if wave != null and wave.r > 2400:
		wave = null


func _speed_factor() -> float:
	var left := _formation_aliens().size()
	var frac := 1.0 - float(left) / total_aliens
	var s: float = lv.speed * dm.speed * (1 + frac * 2.0)
	if left <= 3:
		s += 70
	if left == 1:
		s += 90
	return s


func _update_formation(dt: float) -> void:
	var fa: Array[Alien] = []
	for a in aliens:
		if a.alive and a.state == "formation":
			fa.append(a)
	var spd := _speed_factor()
	_animate(dt, clampf(30.0 / spd, 0.12, 0.6))
	if drop_left > 0:
		var d := minf(drop_left, 220 * dt)
		form_y += d
		drop_left -= d
	elif fa.size():
		form_x += form_dir * spd * dt
		var min_x := INF
		var max_x := -INF
		for a in fa:
			min_x = minf(min_x, form_x + a.slot.x - a.size.x / 2)
			max_x = maxf(max_x, form_x + a.slot.x + a.size.x / 2)
		if (form_dir > 0 and max_x > W - 50) or (form_dir < 0 and min_x < 50):
			form_x -= form_dir * (max_x - (W - 50) if form_dir > 0 else 50 - min_x)
			form_dir *= -1
			drop_left = 34
	var lowest := 0.0
	for a in fa:
		a.pos = Vector2(form_x, form_y) + a.slot
		lowest = maxf(lowest, a.pos.y + a.size.y / 2)
		if a.pos.y + a.size.y / 2 > BUNKER_Y - BUNKER_H / 2.0:
			for b in bunkers:
				if _overlap(a.pos, a.size, b.pos + Vector2(BUNKER_W, BUNKER_H) / 2, Vector2(BUNKER_W, BUNKER_H)):
					_erode(b, a.pos.x, a.pos.y, a.size.x * 0.55)
	if lowest > PLAYER_Y - 40 - 95 and _any_playing():
		planet_close = true # within a row of breaking through
	if lowest > PLAYER_Y - 40 and _any_playing():
		fx_text(W / 2, H / 2, "THEY BROKE THROUGH!", Color("#ff6b6b"), 54, 2)
		for p in pilots:
			if p.playing():
				_ach(p, "they_broke_through")
				_kill_pilot(p)
		form_y = form_start_y
		drop_left = 0


func _update_aliens(dt: float) -> void:
	var chance := lv.dive_chance * float(dm.speed) * dt * (1.0 + 0.25 * (pilots.size() - 1))
	if chance > 0 and randf() < chance and _any_playing():
		var cands := aliens.filter(func(a): return a.alive and a.state == "formation" and a.kind != "cruiser")
		if cands.size() > 2:
			var a: Alien = cands.pick_random()
			var tp := _target()
			a.state = "dive"
			a.t = 0
			a.target = tp.idx
			a.vel = Vector2((tp.x - a.pos.x) * 0.3, -160)
			a.fired = false
	for a in aliens:
		if not a.alive:
			continue
		a.flash = maxf(0.0, a.flash - dt)
		if a.state == "dive" or a.state == "minion":
			a.t += dt
			var tp: Pilot = pilots[clampi(a.target, 0, pilots.size() - 1)]
			if not tp.playing():
				tp = _target(a.pos.x)
				a.target = tp.idx
			var ax := clampf((tp.x - a.pos.x) * 2.2, -900, 900)
			a.vel.x = clampf(a.vel.x + ax * dt, -420, 420)
			a.vel.y = minf(a.vel.y + 520 * dt, 560 * float(dm.speed))
			a.pos += a.vel * dt
			if not a.fired and a.pos.y > 300 and a.pos.y < PLAYER_Y - 250:
				a.fired = true
				_alien_shoot(a, true)
			for p in pilots:
				if p.playing() and p.invuln <= 0 and a.alive and _overlap(a.pos, a.size * 0.7, Vector2(p.x, PLAYER_Y + 4), Vector2(70, 60)):
					_damage_alien(a, 99, p, "ram")
					_hit_pilot(p)
			var hit := _bunker_at(a.pos.x, a.pos.y + a.size.y / 3)
			if hit.size():
				_erode(hit[0], a.pos.x, a.pos.y, 30)
			if a.pos.y > H + 80:
				if a.state == "minion":
					a.alive = false
				else:
					a.state = "return"
					a.pos = Vector2(form_x + a.slot.x, -80)
		elif a.state == "return":
			var target := Vector2(form_x, form_y) + a.slot
			var d := a.pos.distance_to(target)
			var step := 420 * dt
			if d <= step:
				a.state = "formation"
				a.pos = target
			else:
				a.pos += (target - a.pos) / d * step
	aliens.assign(aliens.filter(func(a): return a.alive))


func _update_enemy_fire(dt: float) -> void:
	if not _any_playing():
		return
	var fa := aliens.filter(func(a): return a.alive and a.state == "formation")
	if fa.is_empty():
		return
	var frac := 1.0 - float(fa.size()) / total_aliens
	var rate := lv.fire_rate * float(dm.fire) * (1 + frac * 0.6) * _difficulty_scale()
	fire_acc += rate * dt
	var cap := 12 + _level_power() * 2 + 4 * (pilots.size() - 1)
	while fire_acc >= 1:
		fire_acc -= 1 + randf_range(-0.3, 0.3)
		if bullets.filter(func(b): return b.enemy).size() >= cap:
			continue
		var tx := _target().x
		var cols := {}
		for a in fa:
			var k := roundi(a.slot.x)
			if not cols.has(k) or a.slot.y > cols[k].slot.y:
				cols[k] = a
		var shooters: Array = cols.values()
		shooters.sort_custom(func(a, b): return absf(a.pos.x - tx) < absf(b.pos.x - tx))
		var shooter: Alien = shooters[0] if randf() < 0.45 else shooters.pick_random()
		var cruisers := fa.filter(func(c): return c.kind == "cruiser")
		if cruisers.size() and randf() < 0.18:
			_alien_shoot(cruisers.pick_random())
		else:
			_alien_shoot(shooter)


func _alien_shoot(a: Alien, from_dive := false) -> void:
	var bs := lv.bullet_speed * float(dm.bullet)
	var hue := a.hue + 20
	var shot := func(angle: float, speed: float, r: int, heavy := false):
		var b := Bullet.new()
		b.pos = Vector2(a.pos.x, a.pos.y + a.size.y / 2)
		b.vel = Vector2(sin(angle), cos(angle)) * speed
		b.size = Vector2(r * 1.4, r * 1.8)
		b.tex = _plasma(hue, r)
		b.r = r
		b.enemy = true
		b.hue = hue
		b.rot = -angle
		bullets.append(b)
		sfx("alien_shot_heavy" if heavy else "alien_shot")
	var aim := func() -> float:
		var tp := _target(a.pos.x)
		return clampf(atan2(tp.x - a.pos.x, PLAYER_Y - a.pos.y), -0.6, 0.6)
	match "squid" if from_dive else a.kind:
		"squid":
			shot.call(aim.call(), bs * 1.05, 9)
		"beetle":
			shot.call(0.0, bs * 0.85, 13, true)
		"wraith":
			for ang in [-0.25, 0.0, 0.25]:
				shot.call(ang, bs * 0.9, 9)
		"cruiser":
			for i in 3:
				schedule(i * 0.16, func():
					if a.alive:
						shot.call(aim.call(), bs * 1.1, 11, true))
		_:
			shot.call(0.0, bs, 9)


func _update_saucer(dt: float) -> void:
	if boss != null or (lv.custom and not lv.saucer_enabled):
		return
	if saucer == null:
		saucer_t -= dt
		if saucer_t <= 0 and _formation_aliens().size() > 3:
			var dir := 1.0 if randf() < 0.5 else -1.0
			saucer = {"pos": Vector2(-120 if dir > 0 else W + 120, 92), "dir": dir, "hp": 3, "flash": 0.0}
			run.saucers_seen = int(run.get("saucers_seen", 0)) + 1
			saucer_t = lv.saucer_every * randf_range(0.8, 1.25)
			_saucer_sound(true)
		return
	saucer.pos.x += saucer.dir * 250 * dt
	saucer.flash = maxf(0.0, saucer.flash - dt)
	if (saucer.dir > 0 and saucer.pos.x > W + 140) or (saucer.dir < 0 and saucer.pos.x < -140):
		_stop_saucer()


func _stop_saucer() -> void:
	if saucer != null:
		_saucer_sound(false)
	saucer = null


func _damage_saucer(dmg: int, p: Pilot) -> void:
	saucer.hp -= dmg
	saucer.flash = 0.08
	if saucer.hp > 0:
		sfx("hit_armor")
		fx_hit(saucer.pos.x, saucer.pos.y + 10, 310)
		return
	var pos: Vector2 = saucer.pos
	_stop_saucer()
	run.saucers_killed = int(run.get("saucers_killed", 0)) + 1
	_ach(p, "saucer_hunter", 1)
	var pts: float = [100, 150, 200, 300].pick_random() * (1 + _level_power() * 0.25)
	var val := roundi(pts / 10.0) * 10
	add_score(p, val)
	fx_explosion(pos.x, pos.y, 310, 1.8)
	fx_text(pos.x, pos.y, "+%d" % val, Color("#ff8ae6"), 36, 1.4)
	sfx("explode_big")
	add_shake(10)
	_drop_power(pos, true)


func _update_bullets(dt: float) -> void:
	var edt := dt * _enemy_speed()
	for b in bullets:
		if b.kind == "missile":
			_steer_missile(b, dt)
			b.life -= dt
		b.pos += b.vel * (edt if b.enemy else dt)
	var keep: Array[Bullet] = []
	for b in bullets:
		if b.pos.y < -60 or b.pos.y > H + 60 or b.pos.x < -60 or b.pos.x > W + 60 or b.life <= 0:
			_bullet_gone(b)
			continue
		var gone := false
		## homing missiles and wingman shots fly over your own bunkers
		for i in (0 if b.kind in ["missile", "drone"] else 3):
			var t := i / 3.0
			var x := b.pos.x - b.vel.x * (1.0 / 60.0) * t
			var y := b.pos.y - b.vel.y * (1.0 / 60.0) * t + (b.size.y / 2 if b.enemy else -b.size.y / 2)
			var hit := _bunker_at(x, y)
			if hit.size():
				_erode(hit[0], x, y, (20.0 if b.size.x > 16 else 15.0) if b.enemy else 10.0)
				fx_dust(x, y, lv.bunker_dust)
				sfx("bunker_hit")
				gone = true
				break
		if gone:
			_bullet_gone(b)
			continue
		if b.enemy:
			if state != "play" and state != "boss_warn":
				keep.append(b)
				continue
			var stopped := false
			for p in pilots:
				if not p.playing():
					continue
				if p.t("shield") > 0 and b.pos.distance_to(Vector2(p.x, PLAYER_Y)) < 78:
					p.planet_hit = true
					fx_hit(b.pos.x, b.pos.y, 210)
					sfx("shield_block")
					stopped = true
					break
				if p.invuln <= 0 and _overlap(b.pos, b.size, Vector2(p.x, PLAYER_Y + 6), Vector2(54, 54)):
					_hit_pilot(p)
					stopped = true
					break
			if stopped:
				continue
		else:
			var shooter: Pilot = pilots[clampi(b.owner, 0, pilots.size() - 1)]
			var consumed := false
			for a in aliens:
				if not a.alive or a in b.pierced:
					continue
				if _overlap(b.pos, b.size, a.pos, a.size * 0.82):
					b.hit = true
					_damage_alien(a, b.dmg, shooter, b.kind)
					if not a.alive:
						b.kills += 1
						if b.kind == "pierce" and b.kills >= 5:
							_ach(shooter, "kebab")
					fx_hit(b.pos.x, b.pos.y - 10, a.hue)
					if b.kind == "pierce":
						b.pierced.append(a) # keeps flying through
					else:
						consumed = true
						break
			if consumed:
				continue
			if saucer != null and not ("saucer" in b.pierced) and _overlap(b.pos, b.size, saucer.pos, Vector2(170, 56)):
				b.hit = true
				_damage_saucer(b.dmg, shooter)
				if b.kind != "pierce":
					continue
				b.pierced.append("saucer")
			if boss != null and boss.state == "fight":
				var dx: float = (b.pos.x - boss.x) / 230.0
				var dy: float = (b.pos.y - (boss.y - 10)) / 150.0
				if dx * dx + dy * dy < 1:
					b.hit = true
					_damage_boss(b.dmg, b.pos.x, b.pos.y, shooter)
					continue
		keep.append(b)
	bullets = keep


func _bullet_gone(b: Bullet) -> void:
	## a laser that never touched an enemy is a miss (Sharpshooter)
	if not b.enemy and not b.hit and b.kind in ["laser", "pierce"] and state in ["play", "boss_warn"]:
		pilots[clampi(b.owner, 0, pilots.size() - 1)].planet_missed = true


func _damage_alien(a: Alien, dmg: int, p: Pilot, src := "") -> void:
	if not a.alive:
		return
	a.hp -= dmg
	a.flash = 0.09
	if a.hp > 0:
		sfx("hit_armor")
		return
	a.alive = false
	if a.state == "dive":
		_ach(p, "diver_down", 1)
	if a.state == "minion":
		_ach(p, "minion_massacre", 1)
	if a.kind == "cruiser":
		_ach(p, "cruiser_killer", 1)
	elif a.kind == "wraith":
		_ach(p, "ghostbuster", 1)
	if src == "missile":
		_ach(p, "fire_and_forget", 1)
	elif src == "drone":
		_ach(p, "wingman_of_the_year", 1)
	var big := a.kind == "cruiser"
	var mult := 1 + _level_power() * 0.1
	var pts := roundi(a.score * mult / 5.0) * 5
	add_score(p, pts)
	fx_explosion(a.pos.x, a.pos.y, a.hue, 1.8 if big else (1.15 if a.kind in ["beetle", "wraith"] else 0.9))
	var tc := UI.hsl(a.hue, 100, 80) if not multi() else Global.ship_color(p.color, 75)
	fx_text(a.pos.x, a.pos.y - 10, str(pts), tc, 32 if big else 22, 0.8)
	sfx("explode_big" if big else "explode_small")
	if big:
		add_shake(8)
	if a.state != "minion":
		_drop_power(a.pos, false, big)


func _drop_power(pos: Vector2, guaranteed: bool, big := false) -> void:
	if powers.size() >= 3 + pilots.size() - 1 and not guaranteed:
		return
	var chance := (0.5 if big else 0.075) * float(dm.drop)
	if not guaranteed and randf() > chance:
		return
	var opts := [["dual", 22], ["speed", 16], ["shield", 15], ["bomb", 13], ["rapid", 16]]
	if _level_power() >= 2:
		opts.append(["spread", 12])
	opts.append_array([["homing", 11], ["wingman", 10], ["warp", 8]])
	if _level_power() >= 1:
		opts.append(["pierce", 11])
	var anyone_down := false
	var min_lives := 99
	for p in pilots:
		if not p.left:
			min_lives = mini(min_lives, p.lives)
			anyone_down = anyone_down or p.out()
	if min_lives < 6:
		opts.append(["life", (12 if anyone_down else (6 if guaranteed else 3))])
	var total := 0.0
	for o in opts:
		total += o[1]
	var r := randf() * total
	var kind: String = opts.back()[0]
	for o in opts:
		r -= o[1]
		if r <= 0:
			kind = o[0]
			break
	powers.append([kind, pos, 170.0, 0.0])


func _update_powers(dt: float) -> void:
	for p in powers:
		p[3] += dt
		p[1].y += p[2] * dt
		p[1].x += sin(p[3] * 3) * 20 * dt
	var keep := []
	for pw in powers:
		if pw[1].y > H + 50:
			continue
		var taken := false
		for p in pilots:
			if p.playing() and _overlap(pw[1], Vector2(60, 60), Vector2(p.x, PLAYER_Y), Vector2(100, 80)):
				_collect(p, pw[0])
				taken = true
				break
		if not taken:
			keep.append(pw)
	powers = keep


func _collect(p: Pilot, k: String) -> void:
	var info: Array = POWER_INFO[k]
	var label: String = info[0]
	var stacked := false
	match k:
		"dual", "spread", "rapid", "speed", "shield", "pierce", "homing", "wingman":
			stacked = p.t(k) > 0
			p.timers[k] = minf(p.t(k) + DURATION[k], POWER_CAP)
			p.tmax[k] = p.timers[k]
			if k == "wingman" and not stacked:
				p.drone_cd = 0.0
		"warp":
			stacked = warp_t > 0
			warp_t = minf(warp_t + DURATION.warp, WARP_CAP)
			set_flash(0.25)
		"bomb":
			p.bombs = mini(3, p.bombs + 1)
		"life":
			## Co-op: an Extra Ship brings a downed wingmate back first.
			var revived: Pilot = null
			for q in pilots:
				if q != p and q.out() and not q.left:
					revived = q
					break
			if revived:
				_ach(p, "leave_no_one_behind")
				revived.lives = 1
				revived.respawn_t = 0.6
				label = "%s IS BACK!" % revived.name.to_upper()
			else:
				p.lives = mini(7, p.lives + 1)
	if stacked:
		label += "  +%ds" % int(DURATION[k])
	p.planet_pickups += 1
	_ach(p, "collector", 0, k)
	var active := TIMED.filter(func(t): return p.t(t) > 0).size()
	if active >= 5:
		_ach(p, "fully_loaded")
	if active >= TIMED.size():
		_ach(p, "arsenal")
	for t in TIMED:
		if p.t(t) >= POWER_CAP - 0.01:
			_ach(p, "hoarder")
	sfx(_pickup_sound(k))
	add_score(p, 50)
	fx_text(p.x, PLAYER_Y - 90, label, UI.hsl(info[1], 100, 72), 30, 1.3)
	fx_add(FxSystem.K.RING, p.x, PLAYER_Y, {"life": 0.5, "size": 20, "grow": 300, "hue": info[1], "light": 70})


func _pickup_sound(k: String) -> String:
	## the four newer power-ups reuse the closest-matching pickup sound files
	return "pu_" + {"pierce": "spread", "homing": "rapid", "wingman": "shield", "warp": "speed"}.get(k, k)


func _hit_pilot(p: Pilot) -> void:
	if not p.playing() or p.invuln > 0 or debug_god:
		return
	p.planet_hit = true
	if p.t("shield") > 0:
		sfx("shield_block")
		return
	_kill_pilot(p)


func _kill_pilot(p: Pilot) -> void:
	if not p.alive:
		return
	p.alive = false
	p.lives -= 1
	p.run_lost += 1
	p.planet_hit = true
	if boss != null:
		p.boss_lost = true
	if state == "play" and state_t < 3.0 and boss == null:
		_ach(p, "meant_to_do_that")
	fx_explosion(p.x, PLAYER_Y, Global.SHIP_COLORS[p.color][2] if multi() else 190.0, 2.2)
	fx_explosion(p.x, PLAYER_Y, 30, 1.2)
	sfx("player_hit")
	add_shake(22)
	set_flash(0.35)
	p.lose_powers()
	if multi() and p.lives <= 0:
		fx_text(p.x, PLAYER_Y - 120, "%s IS OUT" % p.name.to_upper(), Global.ship_color(p.color, 75), 30, 2.0)
	var all_out := true
	for q in pilots:
		all_out = all_out and q.out()
	if all_out:
		lasers.clear()
		schedule(1.6, _game_over)
	else:
		p.respawn_t = 1.5
		if not multi():
			lasers.clear()
			bullets.assign(bullets.filter(func(b): return not b.enemy or b.pos.y < PLAYER_Y - 400))


func _check_progress() -> void:
	if state != "play":
		return
	var remaining := 0
	for a in aliens:
		if a.alive and a.state != "minion":
			remaining += 1
	if remaining > 0:
		return
	if lv.boss:
		if boss == null:
			state = "boss_warn"
			state_t = 0
			sfx("boss_warn")
			_music(Audio.music("boss"))
			_stop_saucer()
		return
	if not _any_playing():
		return
	_level_cleared()


func _level_cleared() -> void:
	state = "cleared"
	state_t = 0
	var lives := 0
	for p in pilots:
		lives += maxi(p.lives, 0)
	clear_bonus = 1000 * (_level_power() + 1) + lives * 250
	_planet_achievements()
	_stop_saucer()
	sfx("level_clear")
	_music(null)
	if lv.custom or level_index + 1 >= Global.levels.size():
		_victory()


func _planet_achievements() -> void:
	var flying := pilots.filter(func(q): return not q.out())
	var all_down := bunkers.size() > 0
	for i in bunkers.size():
		if i < bunker_cells.size() and _bunker_solid(bunkers[i]) > bunker_cells[i] * 0.15:
			all_down = false
	for p in flying:
		if not lv.custom:
			match level_index:
				0:
					_ach(p, "first_contact")
					if p.planet_pickups == 0:
						_ach(p, "cheapskate")
				2:
					_ach(p, "homeworld")
				5:
					_ach(p, "ringside")
		if p.planet_shots > 0 and not p.planet_missed:
			_ach(p, "sharpshooter")
		if not p.planet_hit:
			_ach(p, "flawless_planet")
		if bunkers.size() > 0 and not planet_bunker_hit:
			_ach(p, "fortress")
		if all_down:
			_ach(p, "no_cover")
		if planet_close:
			_ach(p, "close_shave")
		if p.turtle >= 0:
			_ach(p, "turtle")
		if pilots.size() >= 4:
			_ach(p, "squadron")
		if pilots.size() >= 2 and flying.size() == 1:
			_ach(p, "last_one_standing")


func _campaign_achievements() -> void:
	if lv.custom:
		var mine := not str(custom_map.get("name", "")).begins_with("Example")
		for p in pilots:
			if not p.out():
				if mine:
					_ach(p, "playtester")
				if lv.boss:
					_ach(p, "boss_builder")
		return
	var clean: bool = run.get("from_start", false) and not run.get("retried", false)
	for p in pilots:
		if p.out():
			continue
		_ach(p, "sunrise")
		if diff == "hard":
			_ach(p, "veteran")
		if clean and p.run_lost == 0:
			_ach(p, "untouchable")
			if diff == "hard":
				_ach(p, "iron_pilot")
		if clean and not run.get("continued", false):
			_ach(p, "no_continues")
		if clean and p.run_bombs == 0:
			_ach(p, "pacifist_bomb")
		if clean and int(run.get("saucers_seen", 0)) > 0 and int(run.get("saucers_killed", 0)) >= int(run.saucers_seen):
			_ach(p, "clean_sweep")


# ---------------------------------------------------------------- boss
func _spawn_boss() -> void:
	var hp := roundi(180 * float(dm.boss_hp) * (1.0 + 0.6 * (pilots.size() - 1)))
	boss = {"x": W / 2, "y": -260.0, "hp": hp, "max_hp": hp, "t": 0.0, "phase": 1, "flash": 0.0, "state": "enter",
		"attack_t": 2.5, "attack_idx": 0, "dying_t": 0.0, "boom_t": 0.0, "eye": Vector2.ZERO, "bomb_hit": -1}


func _update_boss(dt: float) -> void:
	if boss == null:
		return
	var b: Dictionary = boss
	b.t += dt
	b.flash = maxf(0.0, b.flash - dt)
	var watch := _target(b.x)
	var target := Vector2(clampf((watch.x - b.x) / 18.0, -22, 22), clampf((PLAYER_Y - b.y) / 60.0, 4, 14))
	b.eye += (target - b.eye) * dt * 6
	for l in lasers:
		l.t += dt
	lasers = lasers.filter(func(l): return l.t < l.warn + l.dur)
	for l in lasers:
		if l.t >= l.warn:
			for p in pilots:
				if p.playing() and p.invuln <= 0 and absf(l.x - p.x) < 58:
					if p.t("shield") > 0:
						p.planet_hit = true
						if randf() < dt * 10:
							sfx("shield_block")
					else:
						_hit_pilot(p)
			var y := BUNKER_Y - BUNKER_H / 2.0
			while y < BUNKER_Y + BUNKER_H / 2.0:
				var h := _bunker_at(l.x, y)
				if h.size():
					_erode(h[0], l.x, y, 26)
				y += 12
	if b.state == "enter":
		b.y = lerpf(-260, 270, _ease_out_cubic(clampf(b.t / 3.0, 0, 1)))
		if b.t > 3:
			b.state = "fight"
			b.t = 0.0
			b["fight_at"] = time
			for p in pilots:
				p.boss_lost = false
			fx_text(W / 2, 520, "EREBUS, THE VOID SOVEREIGN", Color("#d6a0ff"), 46, 2.4)
		return
	if b.state == "dying":
		b.dying_t += dt
		b.boom_t -= dt
		b.x += sin(b.dying_t * 40) * 2
		if b.boom_t <= 0:
			b.boom_t = 0.11
			fx_explosion(b.x + randf_range(-220, 220), b.y + randf_range(-120, 120), randf_range(260, 360), randf_range(0.8, 1.6))
			sfx("explode_big")
			add_shake(10)
		if b.dying_t > 3.2:
			fx_explosion(b.x, b.y, 300, 5)
			fx_explosion(b.x, b.y, 40, 3.5)
			sfx("explode_huge")
			set_flash(1.0)
			add_shake(40)
			## everyone still in the fight shares the kill
			var share := 10000 / maxi(1, pilots.filter(func(q): return not q.out()).size())
			for p in pilots:
				if not p.out():
					add_score(p, share)
			fx_text(b.x, b.y, "+10,000", Color("#ffe36b"), 56, 2.5)
			boss = null
			lasers.clear()
			bullets.assign(bullets.filter(func(q): return not q.enemy))
			schedule(2.2, _level_cleared)
		return
	var sp := 0.75 if b.phase == 2 else 0.45
	b.x = W / 2 + sin(b.t * sp) * 560
	b.y = 270 + sin(b.t * sp * 2.1) * (50 if b.phase == 2 else 25)
	b.attack_t -= dt
	if b.attack_t <= 0 and _any_playing():
		var attacks := ["radial", "aimed", "lasers", "minions", "spiral"]
		var atk: String = attacks[b.attack_idx % attacks.size()]
		b.attack_idx += 1
		_boss_attack(atk)
		b.attack_t = (1.7 if b.phase == 2 else 2.6) / sqrt(float(dm.fire)) / sqrt(_difficulty_scale())


func _boss_shot(angle: float, speed: float, r := 11, hue := 300.0) -> void:
	if boss == null:
		return
	var b := Bullet.new()
	b.pos = Vector2(boss.x, boss.y + 60)
	b.vel = Vector2(sin(angle), cos(angle)) * speed
	b.size = Vector2(r * 1.4, r * 1.8)
	b.tex = _plasma(hue, r)
	b.r = r
	b.enemy = true
	b.hue = hue
	b.rot = -angle
	bullets.append(b)


func _boss_attack(kind: String) -> void:
	var p2: bool = boss.phase == 2
	var bs := 300.0 * float(dm.bullet)
	match kind:
		"radial":
			var n := 22 if p2 else 16
			for k in (2 if p2 else 1):
				schedule(k * 0.35, func():
					if boss == null:
						return
					for i in n:
						_boss_shot(float(i) / n * TAU + k * 0.15, bs, 11, 290)
					sfx("alien_shot_heavy"))
		"aimed":
			for i in (6 if p2 else 4):
				schedule(i * 0.2, func():
					if boss == null:
						return
					var tp := _target()
					var ang := atan2(tp.x - boss.x, PLAYER_Y - boss.y - 60)
					for o in [-0.18, 0.0, 0.18]:
						_boss_shot(ang + o, bs * 1.5, 10, 330)
					sfx("alien_shot"))
		"lasers":
			var tp := _target()
			var xs := [tp.x, clampf(tp.x + [-1, 1].pick_random() * randf_range(250, 450), 80, W - 80)]
			if p2:
				xs.append(randf_range(100, W - 100))
			if multi():
				var other := _target()
				if other != tp:
					xs.append(other.x)
			for x in xs:
				lasers.append({"x": x, "t": 0.0, "warn": 0.85 if p2 else 1.1, "dur": 1.1})
			sfx("boss_laser_charge")
			schedule(0.85 if p2 else 1.1, func():
				if boss != null:
					sfx("boss_laser")
					add_shake(8))
		"minions":
			var n := (4 if p2 else 3) + (pilots.size() - 1)
			for i in n:
				var m := _make_alien("squid" if i % 2 else "drone", Vector2.ZERO, "minion")
				m.pos = Vector2(boss.x + (i - (n - 1) / 2.0) * 120, boss.y + 80)
				m.vel = Vector2((i - (n - 1) / 2.0) * 150, -120)
				m.target = _target().idx
				aliens.append(m)
			fx_explosion(boss.x, boss.y + 80, 280, 1)
		"spiral":
			var n := 34 if p2 else 24
			for i in n:
				schedule(i * 0.07, func():
					if boss == null:
						return
					var a: float = i * 0.45 + boss.t
					_boss_shot(a, bs * 0.9, 9, 270)
					_boss_shot(a + PI, bs * 0.9, 9, 270)
					if i % 3 == 0:
						sfx("alien_shot"))


func _damage_boss(dmg: int, x: float, y: float, p: Pilot) -> void:
	var b: Dictionary = boss
	if b.state != "fight":
		return
	b.hp -= dmg
	b.flash = 0.06
	add_score(p, 10 * dmg)
	fx_hit(x, y, 300)
	sfx("hit_armor")
	if b.phase == 1 and b.hp <= b.max_hp / 2.0:
		b.phase = 2
		b["enraged_at"] = time
		b.attack_t = 1.2
		fx_text(W / 2, 560, "EREBUS IS ENRAGED!", Color("#ff5a7a"), 52, 2)
		sfx("boss_warn")
		add_shake(16)
		set_flash(0.4)
	if b.hp <= 0:
		b.hp = 0
		for q in pilots:
			if q.out():
				continue
			if not q.boss_lost:
				_ach(q, "eye_to_eye")
			if time - float(b.get("fight_at", time)) <= 60.0:
				_ach(q, "speedrun")
			if b.has("enraged_at") and time - float(b.enraged_at) <= 20.0:
				_ach(q, "calm_before")
			if warp_t > 0:
				_ach(q, "bullet_time")
			if mode == "online":
				_ach(q, "team_player")
		b.state = "dying"
		b.dying_t = 0.0
		b.boom_t = 0.0
		lasers.clear()
		bullets.assign(bullets.filter(func(q): return not q.enemy))
		aliens.assign(aliens.filter(func(a): return a.state != "minion"))
		_music(null)


# ---------------------------------------------------------------- endings
func _game_over() -> void:
	state = "gameover"
	state_t = 0
	end_shown = false
	_stop_saucer()
	if mode == "single" and not lv.custom:
		var had_best := Global.high_score() > 0
		new_high = Global.submit_score(pilots[0].score)
		if new_high and had_best:
			_ach(pilots[0], "personal_best")
	_music(null)
	sfx("game_over")


func _victory() -> void:
	state = "victory"
	state_t = 0
	end_shown = false
	_award_clear_bonus()
	_campaign_achievements()
	if mode == "single" and not lv.custom:
		var had_best := Global.high_score() > 0
		new_high = Global.submit_score(pilots[0].score)
		if new_high and had_best:
			_ach(pilots[0], "personal_best")
		Global.clear_game()
	sfx("victory")


func _restart_start(level: int) -> Dictionary:
	var s := start_info.duplicate(true)
	s.level = level
	if mode == "single":
		s.lives = Global.DIFFICULTY[diff].lives
		s.score = checkpoint.get("score", 0) if not lv.custom else 0
		s.bombs = checkpoint.get("bombs", 1) if not lv.custom else 1
		s.powers = checkpoint.get("powers", {}) if not lv.custom else {}
		s.warp = checkpoint.get("warp", 0.0) if not lv.custom else 0.0
		s.run = checkpoint.get("run", {})
	s.erase("continued")
	s["retried"] = true
	return s


func _show_end_menu() -> void:
	end_shown = true
	for c in end_menu.get_children():
		c.queue_free()
	var items := []
	var y := 700.0 if multi() else 640.0
	var again := "Retry Map" if lv.custom else ("Retry Planet" if state == "gameover" else "")
	if is_guest():
		items.append(["Leave Game", Global.goto_menu])
	else:
		if again != "":
			items.append([again, func():
				var s := _restart_start(level_index)
				if role == "host":
					Net.start_game(s)
				Global.start_game(s)])
		if from_editor:
			items.append(["Back to Editor", func(): Global.goto_scene("res://scenes/editor.tscn")])
		if role == "host":
			items.append(["Back to Lobby", func():
				Net.back_to_lobby()
				Global.lobby_memory["tab"] = "online"
				Global.goto_scene("res://scenes/lobby.tscn")])
		items.append(["Main Menu", Global.goto_menu])
	if state == "victory":
		y = 820.0 if multi() else 780.0
	var buttons := []
	for i in items.size():
		var b := GameButton.make(items[i][0], items[i][1], 520, 66)
		b.position = Vector2(960 - 260, y + i * 80)
		end_menu.add_child(b)
		buttons.append(b)
	GameButton.link_vertical(buttons)
	buttons[0].focus_quietly()


# ---------------------------------------------------------------- online: host side
func _host_send(dt: float) -> void:
	_snap_t += dt
	_bunker_t += dt
	if _snap_t < SNAP_RATE:
		return
	_snap_t = 0.0
	if _bunker_t > 0.1:
		_bunker_t = 0.0
		for i in bunkers.size():
			if not bunkers[i].sent:
				bunkers[i].sent = true
				_events.append(["bunk", i, bunkers[i].mask])
	if _events.size():
		Net.send_all({"t": "ev", "e": _events})
		_events = []
	Net.send_all(_snapshot(), false)


func _snapshot() -> Dictionary:
	var pf := PackedFloat32Array()
	for p in pilots:
		pf.append_array([p.x, p.vx, 1.0 if p.alive else 0.0, p.invuln, p.lives, p.bombs, p.score, 1.0 if p.left else 0.0])
		for k in TIMED:
			pf.append(p.t(k))
	var af := PackedFloat32Array()
	for a in aliens:
		if a.alive:
			var rot := clampf(-a.vel.x / 900.0, -0.5, 0.5) if a.state in ["dive", "minion"] else 0.0
			af.append_array([KINDS.find(a.kind), a.pos.x, a.pos.y, a.flash, rot, a.hp, a.max_hp])
	var bf := PackedFloat32Array()
	for b in bullets:
		bf.append_array([b.pos.x, b.pos.y, b.vel.x, b.vel.y, b.rot, b.hue, b.r])
	var wf := PackedFloat32Array()
	for pw in powers:
		wf.append_array([POWERS.find(pw[0]), pw[1].x, pw[1].y, pw[3]])
	var s := {"t": "s", "st": state, "stt": state_t, "af": anim_frame, "cb": clear_bonus, "p": pf, "a": af, "b": bf, "w": wf, "wp": warp_t}
	if saucer != null:
		s.sc = PackedFloat32Array([saucer.pos.x, saucer.pos.y, saucer.flash])
	if boss != null:
		s.bo = PackedFloat32Array([boss.x, boss.y, boss.hp, boss.max_hp, boss.phase, boss.flash, boss.t, BOSS_STATES.find(boss.state), boss.eye.x, boss.eye.y])
	if lasers.size():
		var lf := PackedFloat32Array()
		for l in lasers:
			lf.append_array([l.x, l.t, l.warn, l.dur])
		s.la = lf
	if wave != null:
		s.wv = PackedFloat32Array([wave.pos.x, wave.pos.y, wave.r])
	return s


func _on_net_message(m: Dictionary, from: int) -> void:
	if role == "host" and m.t == "in":
		for p in pilots:
			if p.peer_id == from:
				p.input.remote_axis = float(m.get("a", 0.0))
				p.input.remote_fire = bool(m.get("f", false))
				p.input.remote_bombs = int(m.get("b", 0))
				if p.alive:
					p.x = clampf(float(m.get("x", p.x)), 70, W - 70)
	elif is_guest():
		if m.t == "s":
			_apply_snapshot(m)
		elif m.t == "ev":
			for e in m.e:
				_apply_event(e)


func _on_peer_left(name: String) -> void:
	for p in pilots:
		if not p.left and p.peer_id != 0 and p.peer_id != Net.my_id and not _peer_present(p.peer_id):
			p.left = true
			p.alive = false
			if role == "host":
				fx_text(W / 2, 420, "%s LEFT THE GAME" % name.to_upper(), Global.ship_color(p.color, 75), 36, 2.5)
	var all_out := true
	for q in pilots:
		all_out = all_out and q.out()
	if all_out and role == "host" and state not in ["gameover", "victory"]:
		schedule(1.0, _game_over)


func _peer_present(id: int) -> bool:
	for p in Net.players:
		if p.id == id:
			return true
	return false


func _on_host_left() -> void:
	Global.goto_menu()
	Global.toast("The host left the game.", 3.0)


# ---------------------------------------------------------------- online: guest side
func _guest_setup(start: Dictionary) -> void:
	level_index = start.get("level", 0)
	lv = _level_for(level_index)
	_setup_visuals()
	state = "intro"
	state_t = 0.0


func _guest_update(dt: float) -> void:
	state_t += dt
	var me := pilots[my_idx]
	me.invuln = maxf(0.0, me.invuln - dt)
	if me.playing():
		_move_pilot(me, dt)
	if me.input.bomb_pressed():
		_guest_bombs += 1
	Net.send_host({"t": "in", "x": me.x, "a": me.input.axis(), "f": me.input.fire(), "b": _guest_bombs}, false)
	var edt := dt * _enemy_speed()
	for b in bullets:
		b.pos += b.vel * (edt if b.enemy else dt)
	if state == "intro":
		_animate(dt, 0.5)
	if state in ["gameover", "victory"] and state_t > 1.5 and not end_shown:
		_show_end_menu()
	if Time.get_ticks_msec() - _last_snap_ms > 12000 and Net.active():
		_on_host_left()


func _apply_snapshot(s: Dictionary) -> void:
	_last_snap_ms = Time.get_ticks_msec()
	if s.st != state:
		state = s.st
		end_shown = state in ["gameover", "victory"] and end_shown
	state_t = s.stt
	anim_frame = s.af
	clear_bonus = s.cb
	var pf: PackedFloat32Array = s.p
	var stride := 8 + TIMED.size()
	warp_t = s.get("wp", 0.0)
	for i in mini(pilots.size(), pf.size() / stride):
		var p := pilots[i]
		var o := i * stride
		var was_alive := p.alive
		p.alive = pf[o + 2] > 0.5
		if i != my_idx or not p.alive or not was_alive:
			p.x = pf[o]
			p.vx = pf[o + 1]
		p.invuln = pf[o + 3]
		p.lives = int(pf[o + 4])
		p.bombs = int(pf[o + 5])
		p.score = int(pf[o + 6])
		for j in TIMED.size():
			var k: String = TIMED[j]
			var v := pf[o + 8 + j]
			if v > 0:
				if v > p.t(k) + 0.5:
					p.tmax[k] = v
				p.timers[k] = v
				p.tmax[k] = maxf(p.tmax.get(k, v), v)
			else:
				p.timers.erase(k)
				p.tmax.erase(k)
		p.left = pf[o + 7] > 0.5
	aliens.clear()
	var af: PackedFloat32Array = s.a
	for i in af.size() / 7:
		var o := i * 7
		var a := _make_alien(KINDS[clampi(int(af[o]), 0, 5)], Vector2.ZERO)
		a.pos = Vector2(af[o + 1], af[o + 2])
		a.flash = af[o + 3]
		a.rot = af[o + 4]
		a.hp = int(af[o + 5])
		a.max_hp = int(af[o + 6])
		aliens.append(a)
	bullets.clear()
	var bf: PackedFloat32Array = s.b
	for i in bf.size() / 7:
		var o := i * 7
		var b := Bullet.new()
		b.pos = Vector2(bf[o], bf[o + 1])
		b.vel = Vector2(bf[o + 2], bf[o + 3])
		b.rot = bf[o + 4]
		b.hue = bf[o + 5]
		b.r = int(bf[o + 6])
		b.enemy = b.r > 0
		b.kind = "plasma"
		for kk in BULLET_TYPES:
			if BULLET_TYPES[kk] == b.r:
				b.kind = kk
		b.tex = _plasma(b.hue, b.r) if b.enemy else {"laser": TEX_LASER, "pierce": TEX_LASER_PIERCE, "missile": TEX_MISSILE, "drone": TEX_LASER}[b.kind]
		bullets.append(b)
	powers.clear()
	var wf: PackedFloat32Array = s.w
	for i in wf.size() / 4:
		var o := i * 4
		powers.append([POWERS[clampi(int(wf[o]), 0, POWERS.size() - 1)], Vector2(wf[o + 1], wf[o + 2]), 0.0, wf[o + 3]])
	saucer = null
	if s.has("sc"):
		saucer = {"pos": Vector2(s.sc[0], s.sc[1]), "flash": s.sc[2]}
	boss = null
	if s.has("bo"):
		var bo: PackedFloat32Array = s.bo
		boss = {"x": bo[0], "y": bo[1], "hp": bo[2], "max_hp": bo[3], "phase": int(bo[4]), "flash": bo[5], "t": bo[6],
			"state": BOSS_STATES[clampi(int(bo[7]), 0, 2)], "eye": Vector2(bo[8], bo[9])}
	lasers.clear()
	if s.has("la"):
		var lf: PackedFloat32Array = s.la
		for i in lf.size() / 4:
			lasers.append({"x": lf[i * 4], "t": lf[i * 4 + 1], "warn": lf[i * 4 + 2], "dur": lf[i * 4 + 3]})
	wave = null
	if s.has("wv"):
		wave = {"pos": Vector2(s.wv[0], s.wv[1]), "r": s.wv[2]}


func _apply_event(e: Array) -> void:
	match e[0]:
		"sfx":
			Audio.play(e[1])
		"music":
			Audio.play_music(load(e[1]) if e[1] != "" else null)
		"saucer":
			if e[1]:
				Audio.saucer_start()
			else:
				Audio.saucer_stop()
		"ex":
			fx.explosion(e[1], e[2], e[3], e[4])
		"hit":
			fx.hit(e[1], e[2], e[3])
		"dust":
			fx.dust(e[1], e[2], e[3])
		"txt":
			fx.text(e[1], e[2], e[3], e[4], e[5], e[6])
		"fx":
			fx.add(e[1], e[2], e[3], e[4])
		"flash":
			flash_a = maxf(flash_a, e[1])
		"shake":
			if Global.settings.shake:
				shake = maxf(shake, e[1])
		"level":
			if level_index != e[1] or lv == null:
				level_index = e[1]
				lv = _level_for(level_index)
				_setup_visuals()
			end_shown = false
			for c in end_menu.get_children():
				c.queue_free()
		"ach":
			if int(e[1]) == my_idx:
				_ach_apply(e[2], int(e[3]), str(e[4]))
		"bunk":
			if e[1] < bunkers.size():
				var b := bunkers[e[1]]
				var m: PackedByteArray = e[2]
				for i in mini(m.size(), b.mask.size()):
					if b.mask[i] and not m[i]:
						_clear_cell(b, i)


# ---------------------------------------------------------------- drawing
func _draw_lasers() -> void:
	var ci: CanvasItem = $World/Lasers
	var by: float = boss.y + 60 if boss != null else 0.0
	for l in lasers:
		if l.t < l.warn:
			var a := 0.3 + 0.5 * absf(sin(l.t * 20))
			var y := by
			while y < H:
				ci.draw_texture_rect(TEX_WARN, Rect2(l.x - 4, y, 8, 30), false, Color(1, 1, 1, a))
				y += 30
		else:
			var k: float = (l.t - l.warn) / l.dur
			var w := 56.0 * (k / 0.1 if k < 0.1 else ((1 - k) / 0.15 if k > 0.85 else 1.0))
			ci.draw_texture_rect(TEX_BEAM, Rect2(l.x - w, by, w * 2, H - by), false)


func _draw_boss() -> void:
	if boss == null:
		return
	var ci: CanvasItem = $World/Boss
	var b: Dictionary = boss
	var tex := TEX_BOSS_FLASH if b.flash > 0 else (TEX_BOSS_ENRAGED if b.phase == 2 else TEX_BOSS)
	UI.draw_sprite(ci, tex, Vector2(b.x, b.y), 1.0, sin(b.t * 0.9) * 0.03)
	var e: Vector2 = Vector2(b.x, b.y - 8) + b.eye
	UI.draw_sprite(ci, TEX_EYE_ENRAGED if b.phase == 2 else TEX_EYE_CALM, e)
	var pupil := 8.0 + sin(b.t * 3) * 2
	var ps := Vector2(pupil * 2 + 4, 52)
	ci.draw_texture_rect(TEX_PUPIL, Rect2(e + Vector2(b.eye.x * 0.3, b.eye.y * 0.2) - ps / 2, ps), false)


func _draw_actors() -> void:
	var ci: CanvasItem = $World/Actors
	for a in aliens:
		if not a.alive:
			continue
		var rot := a.rot
		if not is_guest():
			rot = clampf(-a.vel.x / 900.0, -0.5, 0.5) if a.state in ["dive", "minion"] else 0.0
		UI.draw_sprite(ci, a.flash_tex[anim_frame] if a.flash > 0 else a.tex[anim_frame], a.pos, 1.0, rot)
		if a.max_hp > 1 and a.hp < a.max_hp:
			var w := a.size.x * 0.6
			var top := a.pos + Vector2(-w / 2, -a.size.y / 2 - 12)
			ci.draw_texture_rect(TEX_TIMER_TRACK, Rect2(top, Vector2(w, 5)), false, Color(0, 0, 0, 0.5))
			ci.draw_texture_rect(TEX_TIMER_FILL, Rect2(top, Vector2(w * a.hp / a.max_hp, 5)), false, UI.hsl(a.hue, 100, 65))
	if saucer != null:
		var f := int(time * 8) % 2
		UI.draw_sprite(ci, TEX_SAUCER_FLASH[f] if saucer.flash > 0 else TEX_SAUCER[f], saucer.pos + Vector2(0, sin(time * 4) * 4))
	for p in powers:
		UI.draw_sprite(ci, _power_tex[p[0]], p[1], 1 + sin(p[3] * 6) * 0.06, sin(p[3] * 2) * 0.2)


func _draw_bullets() -> void:
	var ci: CanvasItem = $World/Bullets
	for b in bullets:
		UI.draw_sprite(ci, b.tex, b.pos, 0.7 if b.kind == "drone" else 1.0, b.rot)


func _blinking(p: Pilot) -> bool:
	return p.invuln > 0 and int(time * 14) % 2 == 0


func _draw_flames() -> void:
	var ci: CanvasItem = $World/Flames
	for p in pilots:
		if not p.playing() or _blinking(p):
			continue
		var ln := (60.0 if p.t("speed") > 0 else 34.0) + randf() * 10
		var c := UI.hsl(45 if p.t("speed") > 0 else 195, 100, 65)
		if multi() and p.t("speed") <= 0:
			c = Global.ship_color(p.color, 65)
		for s in [-7.0, 7.0]:
			ci.draw_texture_rect(TEX_FLAME, Rect2(p.x + s - 5, PLAYER_Y + 40, 10, ln * 1.05), false, c.lerp(Color.WHITE, 0.2))


func _draw_player() -> void:
	var ci: CanvasItem = $World/Player
	for p in pilots:
		if not p.playing() or _blinking(p):
			continue
		UI.draw_sprite(ci, p.tex, Vector2(p.x, PLAYER_Y), 1.0, clampf(p.vx / 4000.0, -0.14, 0.14))
		if p.t("wingman") > 0:
			var fade_d := (0.45 if int(time * 10) % 2 else 1.0) if p.t("wingman") < 2 else 1.0
			UI.draw_sprite(ci, TEX_DRONE, drone_pos(p), 1.0, clampf(p.vx / 6000.0, -0.1, 0.1), Color(1, 1, 1, fade_d))
		if multi():
			_txt(ci, p.name, p.x, PLAYER_Y + 76, 16, "extrabold", Global.ship_color(p.color, 78), HORIZONTAL_ALIGNMENT_CENTER, 1)


func _draw_shield() -> void:
	for p in pilots:
		if not p.playing() or p.t("shield") <= 0 or _blinking(p):
			continue
		var fade := (0.4 if int(time * 10) % 2 else 1.0) if p.t("shield") < 2 else 1.0
		var r := 76 + sin(time * 6) * 3
		UI.draw_sprite($World/Shield, TEX_SHIELD, Vector2(p.x, PLAYER_Y), r / 76.0, time * 0.8, Color(1, 1, 1, fade))


func _draw_wave() -> void:
	if wave == null:
		return
	var k: float = 1.0 - wave.r / 2400.0
	var r: float = wave.r * 512.0 / 472.0
	$World/Wave.draw_texture_rect(TEX_SHOCKWAVE, Rect2(wave.pos.x - r, wave.pos.y - r, r * 2, r * 2), false, Color(1, 1, 1, k))


# ---------------------------------------------------------------- text helpers
func _txt(ci: CanvasItem, s: String, x: float, y: float, size: int, weight := "bold", color := Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, spacing := 0, glow := Color(0, 0, 0, 0), glow_size := 12) -> void:
	var f := UI.font(weight, spacing)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var px_ := x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		px_ = x - w / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		px_ = x - w
	var pos := Vector2(px_, y + size * 0.36)
	if glow.a > 0:
		var g := glow
		g.a *= 0.18
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, glow_size * 2, g)
		g.a = glow.a * 0.35
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, glow_size, g)
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _level_title() -> String:
	if lv.custom:
		return "CUSTOM MAP  ·  %s" % lv.planet.to_upper()
	return "PLANET %d/9  ·  %s" % [level_index + 1, lv.planet.to_upper()]


func _actives(p: Pilot) -> Array:
	var actives := []
	for k in TIMED:
		if p.t(k) > 0:
			actives.append([k, p.t(k), maxf(p.tmax.get(k, DURATION[k]), 0.1)])
	return actives


func _draw_hud() -> void:
	var ci := hud
	ci.draw_texture_rect(TEX_HUD_TOP, Rect2(0, 0, W, 70), false)
	if not multi():
		_txt(ci, _level_title(), W / 2, 34, 24, "extrabold", Color("#dfe9ff"), HORIZONTAL_ALIGNMENT_CENTER, 5)
	if multi():
		_draw_hud_multi(ci)
	else:
		_draw_hud_single(ci)
	if warp_t > 0:
		var wa := 0.55 + 0.45 * absf(sin(time * 3))
		UI.draw_sprite(ci, _hud_power_tex["warp"], Vector2(W / 2 - 110, H - 40), 0.8, 0.0, Color(1, 1, 1, wa))
		_txt(ci, "TIME WARP  %ds" % ceili(warp_t), W / 2 - 84, H - 40, 22, "extrabold", UI.hsl(240, 100, 80, wa), HORIZONTAL_ALIGNMENT_LEFT, 4)
	if boss != null and boss.state != "enter":
		var bw := 900.0
		var bx := W / 2 - bw / 2
		var by := 64.0
		_txt(ci, "EREBUS, THE VOID SOVEREIGN", W / 2, by + 6, 18, "extrabold", Color("#e0b8ff"), HORIZONTAL_ALIGNMENT_CENTER, 4)
		ci.draw_texture_rect(TEX_BOSSBAR_FRAME, Rect2(bx - 2, by + 18, bw + 4, 26), false)
		var fw := maxf(0.0, (bw - 6) * float(boss.hp) / boss.max_hp)
		if fw > 0:
			ci.draw_texture_rect_region(TEX_BOSSBAR_FILL, Rect2(bx + 3, by + 23, fw, 16), Rect2(0, 0, fw, 16))
	if state == "intro" and level_index == 0 and not lv.custom and not multi():
		_txt(ci, "←  →  MOVE     ·     SPACE  FIRE     ·     B  NOVA BOMB     ·     ESC  PAUSE", W / 2, H - 28, 20, "bold",
			Color(0.82, 0.9, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 2)


func _draw_hud_single(ci: CanvasItem) -> void:
	var p := pilots[0]
	_txt(ci, "SCORE", 36, 26, 16, "extrabold", Color("#8fc8ff"), HORIZONTAL_ALIGNMENT_LEFT, 4)
	_txt(ci, UI.format_score(p.score), 36, 54, 32, "extrabold", Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 0, Color(0.4, 0.78, 1, 0.6), 8)
	if not lv.custom:
		_txt(ci, "HIGH", 300, 26, 16, "extrabold", Color("#ffd76b"), HORIZONTAL_ALIGNMENT_LEFT, 4)
		_txt(ci, UI.format_score(hi_score), 300, 54, 26, "bold", Color("#ffe9a8"))
	for i in mini(p.lives, 7):
		UI.draw_sprite(ci, p.tex, Vector2(W - 52 - i * 46, 38), 0.36)
	for i in p.bombs:
		UI.draw_sprite(ci, TEX_HUD_BOMB, Vector2(W - 52 - i * 40, 88))
	if p.bombs > 0:
		_txt(ci, "B", W - 52 - p.bombs * 40 + 8, 89, 18, "extrabold", Color("#ffb08a"), HORIZONTAL_ALIGNMENT_CENTER)
	var actives := _actives(p)
	for i in actives.size():
		var k: String = actives[i][0]
		var x := 36.0
		var y := H - 60 - i * 58
		var info: Array = POWER_INFO[k]
		UI.draw_sprite(ci, _hud_power_tex[k], Vector2(x + 20, y))
		_txt(ci, info[0], x + 52, y - 9, 16, "extrabold", UI.hsl(info[1], 100, 80), HORIZONTAL_ALIGNMENT_LEFT, 2)
		_txt(ci, "%ds" % ceili(actives[i][1]), x + 222, y + 9, 15, "extrabold", Color(1, 1, 1, 0.85))
		ci.draw_texture_rect(TEX_TIMER_TRACK, Rect2(x + 52, y + 6, 160, 6), false)
		ci.draw_texture_rect(TEX_TIMER_FILL, Rect2(x + 52, y + 6, 160 * actives[i][1] / actives[i][2], 6), false, UI.hsl(info[1], 100, 65))


func _draw_hud_multi(ci: CanvasItem) -> void:
	_txt(ci, "TEAM SCORE", 36, 22, 15, "extrabold", Color("#8fc8ff"), HORIZONTAL_ALIGNMENT_LEFT, 4)
	_txt(ci, UI.format_score(team_score()), 36, 48, 30, "extrabold", Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 0, Color(0.4, 0.78, 1, 0.6), 8)
	## one card per pilot across the top bar
	var n := pilots.size()
	var gap := 14.0
	var cw := minf(390.0, (1610.0 - gap * (n - 1)) / n)
	var x0 := 1900.0 - n * cw - (n - 1) * gap
	for p in pilots:
		var x := x0 + p.idx * (cw + gap)
		var y := 6.0
		var col := Global.ship_color(p.color, 72)
		if _card_style == null:
			_card_style = StyleBoxTexture.new()
			_card_style.texture = TEX_PANEL
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_card_style.set_texture_margin(side, 16)
			_card_style.modulate_color = Color(1, 1, 1, 0.75)
		ci.draw_style_box(_card_style, Rect2(x, y, cw, 58))
		ci.draw_rect(Rect2(x + 2, y + 2, 5, 54), col)
		UI.draw_sprite(ci, p.tex, Vector2(x + 34, y + 29), 0.34, 0.0, Color(1, 1, 1, 0.35) if p.out() else Color.WHITE)
		var me := mode == "online" and p.idx == my_idx
		_txt(ci, p.name + ("  (YOU)" if me else ""), x + 64, y + 16, 16, "extrabold", col, HORIZONTAL_ALIGNMENT_LEFT, 1)
		_txt(ci, UI.format_score(p.score), x + cw - 12, y + 16, 18, "extrabold", Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		if p.left:
			_txt(ci, "LEFT THE GAME", x + 64, y + 41, 14, "bold", Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_LEFT, 2)
			continue
		if p.out():
			_txt(ci, "OUT · Extra Ship revives", x + 64, y + 41, 14, "bold", Color("#ff9aa8"))
			continue
		for i in mini(p.lives, 5):
			UI.draw_sprite(ci, p.tex, Vector2(x + 72 + i * 20, y + 42), 0.15)
		for i in p.bombs:
			UI.draw_sprite(ci, TEX_HUD_BOMB, Vector2(x + 178 + i * 22, y + 42), 0.56)
		## active power-ups: small icons with a draining ring of time on the right of the card
		var acts := _actives(p)
		for i in acts.size():
			var k: String = acts[i][0]
			var ix := x + cw - 18 - i * 26
			if ix < x + 236:
				break
			UI.draw_sprite(ci, _hud_power_tex[k], Vector2(ix, y + 41), 0.52)
			ci.draw_texture_rect(TEX_TIMER_FILL, Rect2(ix - 10, y + 54, 20 * acts[i][1] / acts[i][2], 3), false, UI.hsl(POWER_INFO[k][1], 100, 65))


func _draw_banners() -> void:
	var ci := banner
	var t := state_t
	if warp_t > 0 and state in ["play", "boss_warn"]:
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.35, 0.3, 1.0, 0.07 * minf(1.0, warp_t)))
	if state == "intro":
		var a := t / 0.4 if t < 0.4 else (maxf(0.0, 1 - (t - 2.7) / 0.5) if t > 2.7 else 1.0)
		var y := H / 2 - 40
		ci.draw_texture_rect(TEX_BAND, Rect2(0, y - 130, W, 260), false, Color(1, 1, 1, a))
		if lv.custom:
			_txt(ci, "CUSTOM MAP", W / 2, y - 70, 24, "extrabold", Color(0.62, 0.82, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 10)
			_txt(ci, lv.planet.to_upper(), W / 2, y, 80, "display", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 12, Color(0.47, 0.78, 1, 0.9 * a), 16)
			_txt(ci, "%d aliens%s" % [total_aliens, "  ·  Boss at the end" if lv.boss else ""], W / 2, y + 68, 28, "bold", Color(0.88, 0.93, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 2)
		else:
			_txt(ci, "PLANET %d OF 9" % (level_index + 1), W / 2, y - 70, 24, "extrabold", Color(0.62, 0.82, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 10)
			_txt(ci, lv.planet.to_upper(), W / 2, y, 104, "display", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 22, Color(0.47, 0.78, 1, 0.9 * a), 16)
			_txt(ci, lv.tagline, W / 2, y + 68, 30, "bold", Color(0.88, 0.93, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 3)
			_txt(ci, lv.fact, W / 2, y + 112, 22, "medium", Color(0.78, 0.84, 0.94, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER)
		if multi():
			var n := pilots.size()
			for p in pilots:
				var px := W / 2 + (p.idx - (n - 1) / 2.0) * 280
				_txt(ci, p.name, px, y + 170, 22, "extrabold", Global.ship_color(p.color, 75) * Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 2)
	elif state == "boss_warn":
		ci.draw_rect(Rect2(0, 0, W, H), Color(1, 0, 0.16, 0.08 + 0.08 * sin(t * 12)))
		if int(t * 4) % 2 == 0:
			_txt(ci, "WARNING", W / 2, H / 2 - 50, 120, "display", Color("#ff4060"), HORIZONTAL_ALIGNMENT_CENTER, 30, Color(1, 0, 0.19, 0.9), 18)
		_txt(ci, "A MASSIVE SIGNAL IS APPROACHING", W / 2, H / 2 + 50, 32, "extrabold", Color("#ffb0c0"), HORIZONTAL_ALIGNMENT_CENTER, 8)
	elif state == "cleared" and not lv.custom and level_index + 1 < Global.levels.size():
		var a := minf(1.0, t * 3)
		_txt(ci, "%s LIBERATED" % lv.planet.to_upper(), W / 2, H / 2 - 50, 84, "display", Color(0.92, 1, 0.95, a), HORIZONTAL_ALIGNMENT_CENTER, 12, Color(0.47, 1, 0.7, 0.9 * a), 16)
		if t > 0.6:
			var label := "CLEAR BONUS  +" + UI.format_score(clear_bonus) + ("  EACH" if multi() else "")
			_txt(ci, label, W / 2, H / 2 + 40, 34, "extrabold", Color(1, 0.89, 0.42, a), HORIZONTAL_ALIGNMENT_CENTER, 4)
		if t > 1.4:
			_txt(ci, "Next: " + Global.levels[level_index + 1].planet, W / 2, H / 2 + 100, 28, "bold", Color(0.74, 0.85, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
	elif state == "gameover":
		var a := minf(1.0, t * 1.5)
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0, 0.024, 0.78 * a))
		_txt(ci, "GAME OVER", W / 2, 300, 130, "display", Color(1, 0.42, 0.48, a), HORIZONTAL_ALIGNMENT_CENTER, 20, Color(1, 0.13, 0.25, 0.9 * a), 18)
		if multi():
			_txt(ci, "TEAM SCORE  " + UI.format_score(team_score()), W / 2, 430, 40, "extrabold", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6)
			_draw_scoreboard(ci, 500, a)
		else:
			_txt(ci, "SCORE  " + UI.format_score(pilots[0].score), W / 2, 470, 40, "extrabold", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6)
			if new_high:
				_txt(ci, "NEW HIGH SCORE!", W / 2, 540, 32, "extrabold", Color(1, 0.89, 0.42, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(1, 0.69, 0, 0.8 * a))
		if is_guest() and end_shown:
			_txt(ci, "Waiting for the host to choose what's next…", W / 2, 660, 24, "bold", Color(0.78, 0.86, 1, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER)
	elif state == "victory":
		var a := minf(1.0, t * 0.8)
		ci.draw_rect(Rect2(0, 0, W, H), Color(0, 0.024, 0.08, 0.72 * a))
		var title := "MAP COMPLETE" if lv.custom else "VICTORY"
		_txt(ci, title, W / 2, 230, 140 if not lv.custom else 110, "display", Color(1, 0.96, 0.82, a), HORIZONTAL_ALIGNMENT_CENTER, 26, Color(1, 0.75, 0.25, 0.9 * a), 20)
		var lines: Array = Story.victory_lines(multi()) if not lv.custom else ["%s cleared." % lv.planet]
		for i in lines.size():
			_txt(ci, lines[i], W / 2, 340 + i * 40, 28, "bold", Color(0.88, 0.93, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
		var sy := 360 + lines.size() * 40
		if multi():
			_txt(ci, "TEAM SCORE  " + UI.format_score(team_score()), W / 2, sy + 40, 44, "black", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0.47, 0.78, 1, 0.8 * a))
			_draw_scoreboard(ci, sy + 100, a)
		else:
			_txt(ci, "FINAL SCORE  " + UI.format_score(pilots[0].score), W / 2, sy + 40, 48, "black", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0.47, 0.78, 1, 0.8 * a))
			_txt(ci, "%s difficulty" % Global.DIFFICULTY[diff].label, W / 2, sy + 100, 24, "bold", Color(0.66, 0.77, 0.91, a), HORIZONTAL_ALIGNMENT_CENTER)
			if new_high:
				_txt(ci, "NEW HIGH SCORE!", W / 2, sy + 150, 34, "extrabold", Color(1, 0.89, 0.42, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(1, 0.69, 0, 0.8 * a))
		if is_guest() and end_shown:
			_txt(ci, "Waiting for the host to choose what's next…", W / 2, 1000, 24, "bold", Color(0.78, 0.86, 1, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_scoreboard(ci: CanvasItem, y: float, a: float) -> void:
	var order := pilots.duplicate()
	order.sort_custom(func(p, q): return p.score > q.score)
	var n := order.size()
	for i in n:
		var p: Pilot = order[i]
		var x := W / 2 + (i - (n - 1) / 2.0) * 300
		UI.draw_sprite(ci, p.tex, Vector2(x, y + 40), 0.5, 0.0, Color(1, 1, 1, a))
		_txt(ci, p.name, x, y + 100, 24, "extrabold", Global.ship_color(p.color, 75) * Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 1)
		_txt(ci, UI.format_score(p.score), x, y + 132, 26, "bold", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
		if i == 0 and n > 1 and p.score > 0:
			_txt(ci, "TOP GUN", x, y - 6, 16, "extrabold", Color(1, 0.85, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, 4)


# ---------------------------------------------------------------- test hooks (used by tools/autotest.gd only)
func debug_clear_wave() -> void:
	for a in aliens:
		if a.state != "minion":
			a.alive = false
	aliens.assign(aliens.filter(func(a): return a.alive))


func debug_damage_boss(n: int) -> void:
	if boss != null and boss.state == "fight":
		_damage_boss(n, boss.x, boss.y, pilots[0])


func debug_give(k: String, who := 0) -> void:
	_collect(pilots[who], k)


func debug_jump(level: int) -> void:
	load_level(level)


func debug_kill(who: int) -> void:
	debug_god = false
	pilots[who].invuln = 0
	pilots[who].timers.erase("shield")
	_kill_pilot(pilots[who])
