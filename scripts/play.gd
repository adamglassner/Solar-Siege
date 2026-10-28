extends Node2D
## Gameplay: the alien formation, shields, power-ups, bonus saucer, the Pluto boss, HUD and banners.
## All graphics are textures from assets/; this script only moves things around and decides what happens.

const W := 1920.0
const H := 1080.0
const PLAYER_Y := 985.0
const BUNKER_Y := 830.0
const CELL := 5
const BUNKER_W := 200
const BUNKER_H := 110
const COL_W := 108.0

const ROW_H := {"cruiser": 124.0, "drone": 82.0, "crab": 82.0, "squid": 82.0, "beetle": 88.0, "wraith": 90.0}
const ALIEN_STATS := {
	"drone": [1, 10], "crab": [1, 20], "squid": [1, 30], "beetle": [2, 40], "wraith": [3, 60], "cruiser": [7, 150],
}
const ALIEN_SIZE := {
	"drone": Vector2(74, 58), "crab": Vector2(88, 60), "squid": Vector2(70, 66),
	"beetle": Vector2(90, 70), "wraith": Vector2(86, 74), "cruiser": Vector2(176, 100),
}
const ALIEN_BASE_HUE := {"drone": 120.0, "crab": 190.0, "squid": 310.0, "beetle": 30.0, "wraith": 270.0, "cruiser": 355.0}
const POWER_INFO := {
	"dual": ["DUAL LASERS", 190.0], "spread": ["TRIPLE SPREAD", 280.0], "speed": ["SPEED BOOST", 50.0],
	"shield": ["SHIELD", 210.0], "bomb": ["NOVA BOMB", 10.0], "rapid": ["RAPID FIRE", 130.0], "life": ["EXTRA SHIP", 330.0],
}

const TEX_PLAYER := preload("res://assets/sprites/player.png")
const TEX_LASER := preload("res://assets/sprites/projectiles/laser_player.png")
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


class Bullet:
	var pos: Vector2
	var vel: Vector2
	var size: Vector2
	var tex: Texture2D
	var enemy: bool
	var dmg := 1
	var hue: float
	var rot: float


class Bunker:
	var pos: Vector2
	var mask: PackedByteArray
	var image: Image
	var texture: ImageTexture
	var sprite: Sprite2D
	var dirty := false


# ---------------------------------------------------------------- state
var lv: LevelData
var level_index := 0
var diff := "normal"
var dm: Dictionary
var state := "intro" # intro | play | boss_warn | cleared | gameover | victory
var state_t := 0.0
var checkpoint := {}

var score := 0
var lives := 3
var bombs := 1
var hi_score := 0

var px := W / 2
var pvx := 0.0
var alive := true
var respawn_t := 0.0
var invuln := 0.0
var cooldown := 0.0
var weapon := "single"
var weapon_t := 0.0
var rapid_t := 0.0
var speed_t := 0.0
var shield_t := 0.0

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

var _plasma_cache := {}
var _alien_tex := {}
var _power_tex := {}
var _hud_power_tex := {}

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
	diff = start.difficulty
	dm = Global.DIFFICULTY[diff]
	score = start.score
	lives = start.lives
	bombs = start.bombs
	load_level(start.level)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and not get_tree().paused:
		if state in ["play", "intro", "boss_warn"] and not OS.has_feature("autotest"):
			pause()


func _exit_tree() -> void:
	Audio.saucer_stop()


# ---------------------------------------------------------------- level setup
func load_level(i: int) -> void:
	level_index = i
	lv = Global.levels[i]
	checkpoint = {"level": i, "score": score, "lives": lives, "bombs": bombs, "difficulty": diff}
	Global.save_game(checkpoint)
	$World/Background.texture = lv.background
	stars.setup(lv.planet.length() * 977 + 13)
	fx.clear()
	bullets.clear()
	powers.clear()
	jobs.clear()
	lasers.clear()
	_stop_saucer()
	saucer_t = lv.saucer_every * randf_range(0.6, 1.0)
	boss = null
	wave = null
	alive = true
	respawn_t = 0.0
	invuln = 0.0
	px = W / 2
	pvx = 0.0
	weapon = "single"
	weapon_t = 0.0
	rapid_t = 0.0
	speed_t = 0.0
	shield_t = 0.0
	_build_formation()
	_build_bunkers()
	state = "intro"
	state_t = 0.0
	Audio.play_music(lv.music)
	Audio.play("level_start")


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
		_plasma_cache[key] = load(path) if ResourceLoader.exists(path) else load("res://assets/sprites/projectiles/plasma_290_11.png")
	return _plasma_cache[key]


func _make_alien(kind: String, slot: Vector2, st := "formation") -> Alien:
	var a := Alien.new()
	var stats: Array = ALIEN_STATS[kind]
	var hp_bonus := int(level_index / 3) if kind == "cruiser" else 0
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
	total_aliens = aliens.size()
	form_dir = 1.0 if randf() < 0.5 else -1.0
	drop_left = 0.0
	for a in aliens:
		a.pos = Vector2(form_x, form_y) + a.slot


func _build_bunkers() -> void:
	for b in bunkers:
		b.sprite.queue_free()
	bunkers.clear()
	var src := lv.bunker_texture.get_image()
	if src.is_compressed():
		src.decompress()
	src.clear_mipmaps()
	src.convert(Image.FORMAT_RGBA8)
	var cols := BUNKER_W / CELL
	var rows := BUNKER_H / CELL
	for i in 4:
		var b := Bunker.new()
		var cx := W * (0.2 + i * 0.2)
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
				b.mask[i] = 0
				b.image.fill_rect(Rect2i(q * CELL * 2 - 1, r * CELL * 2 - 1, CELL * 2 + 2, CELL * 2 + 2), Color(0, 0, 0, 0))
				b.dirty = true


# ---------------------------------------------------------------- helpers
func schedule(delay: float, fn: Callable) -> void:
	jobs.append([delay, fn])


func add_shake(n: float) -> void:
	if Global.settings.shake:
		shake = maxf(shake, n)


func _formation_aliens() -> Array[Alien]:
	var out: Array[Alien] = []
	for a in aliens:
		if a.alive and a.state != "minion":
			out.append(a)
	return out


func add_score(n: int) -> void:
	score += n
	if score > hi_score:
		hi_score = score


func _overlap(a: Vector2, asz: Vector2, b: Vector2, bsz: Vector2) -> bool:
	return absf(a.x - b.x) * 2 < asz.x + bsz.x and absf(a.y - b.y) * 2 < asz.y + bsz.y


func pause() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	Audio.play("menu_select")
	var resume := func():
		Dialog.close_top()
		get_tree().paused = false
	Dialog.open("Paused", ["Planet %d: %s" % [level_index + 1, lv.planet]], [
		["Resume", resume],
		["Options", func(): OptionsMenu.open()],
		["Save & Quit", func():
			Global.save_game(checkpoint)
			Global.goto_menu()],
		["Quit to Menu", func():
			Dialog.open("Quit to Menu?", ["Progress on this planet will be lost.", "You can continue from the start of this planet."], [
				["Quit", Global.goto_menu],
				["Cancel", Dialog.close_top],
			])],
	], 760, resume)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in ["play", "intro", "boss_warn"]:
		get_viewport().set_input_as_handled()
		pause()


# ---------------------------------------------------------------- update
func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	time += dt
	state_t += dt
	shake = maxf(0.0, shake - dt * 40)
	flash_a = maxf(0.0, flash_a - dt * 2.2)
	stars.speed = 2.6 if speed_t > 0 else 1.0

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
			_update_player(dt, false)
			if state_t > 3.2:
				state = "play"
				state_t = 0
		"play":
			_update_player(dt, true)
			_update_formation(dt)
			_update_aliens(dt)
			_update_enemy_fire(dt)
			_update_saucer(dt)
			_update_boss(dt)
			_update_bullets(dt)
			_update_powers(dt)
			_update_wave(dt)
			_check_progress()
		"boss_warn":
			_update_player(dt, true)
			_update_bullets(dt)
			_update_powers(dt)
			_update_wave(dt)
			if state_t > 3.2:
				state = "play"
				state_t = 0
				_spawn_boss()
		"cleared":
			_update_player(dt, false)
			_update_powers(dt)
			bullets.assign(bullets.filter(func(b): return not b.enemy))
			_update_bullets(dt)
			if state_t > 3.6:
				add_score(clear_bonus)
				load_level(level_index + 1)
		"gameover", "victory":
			_update_bullets(dt)
			if state == "victory" and randf() < dt * 3:
				fx.explosion(randf_range(200, W - 200), randf_range(150, 600), randf_range(0, 360), randf_range(0.6, 1.4))
			if state_t > 1.5 and not end_shown:
				_show_end_menu()

	for b in bunkers:
		if b.dirty:
			b.texture.update(_with_mipmaps(b.image))
			b.dirty = false
	world.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0 else Vector2.ZERO
	flash_rect.color.a = flash_a * 0.7
	for n in [$World/Lasers, $World/Boss, $World/Actors, $World/Bullets, $World/Flames, $World/Player, $World/Shield, $World/Wave, hud, banner]:
		n.queue_redraw()


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)


func _animate(dt: float, rate: float) -> void:
	anim_t += dt
	if anim_t > rate:
		anim_t = 0
		anim_frame ^= 1


func _update_player(dt: float, can_fire: bool) -> void:
	invuln = maxf(0.0, invuln - dt)
	if weapon_t > 0:
		weapon_t = maxf(0.0, weapon_t - dt)
		if weapon_t == 0:
			weapon = "single"
	rapid_t = maxf(0.0, rapid_t - dt)
	speed_t = maxf(0.0, speed_t - dt)
	if shield_t > 0:
		shield_t = maxf(0.0, shield_t - dt)
		if shield_t == 0:
			Audio.play("menu_back")
	if not alive:
		if lives > 0:
			respawn_t -= dt
			if respawn_t <= 0:
				alive = true
				invuln = 2.5
				px = W / 2
				pvx = 0
		return
	var mx := 860.0 if speed_t > 0 else 540.0
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) < 0.3:
		dir = 0.0
	pvx += (dir * mx - pvx) * minf(1.0, dt * 14)
	px = clampf(px + pvx * dt, 70, W - 70)
	if speed_t > 0 and randf() < dt * 40:
		fx.add(FxSystem.K.STREAK, px + randf_range(-30, 30), PLAYER_Y + 40, {"vy": 300, "life": 0.4, "size": 3, "hue": 50, "light": 70, "drag": 1.0})
	cooldown -= dt
	if can_fire and Input.is_action_pressed("fire") and cooldown <= 0:
		_shoot()
	if can_fire and Input.is_action_just_pressed("bomb"):
		_detonate_bomb()


func _shoot() -> void:
	cooldown = 0.14 if rapid_t > 0 else 0.3
	var y := PLAYER_Y - 50
	var spawn := func(x: float, angle: float):
		var b := Bullet.new()
		b.pos = Vector2(x, y)
		b.vel = Vector2(sin(angle), -cos(angle)) * 1400.0
		b.size = Vector2(8, 36)
		b.tex = TEX_LASER
		b.enemy = false
		b.hue = 185
		b.rot = angle
		bullets.append(b)
	if weapon == "dual":
		spawn.call(px - 22, 0.0)
		spawn.call(px + 22, 0.0)
		Audio.play("laser_dual")
	elif weapon == "spread":
		spawn.call(px, 0.0)
		spawn.call(px - 14, -0.2)
		spawn.call(px + 14, 0.2)
		Audio.play("laser_spread")
	else:
		spawn.call(px, 0.0)
		Audio.play("laser")
	fx.add(FxSystem.K.GLOW, px, y + 6, {"life": 0.08, "size": 30, "grow": -100, "hue": 185, "light": 80})


func _detonate_bomb() -> void:
	if bombs <= 0:
		Audio.play("denied")
		return
	bombs -= 1
	wave_id += 1
	wave = {"pos": Vector2(px, PLAYER_Y - 30), "r": 0.0, "id": wave_id}
	flash_a = 0.9
	add_shake(26)
	Audio.play("bomb")
	for b in bullets:
		if b.enemy:
			fx.hit(b.pos.x, b.pos.y, b.hue)
	bullets.assign(bullets.filter(func(b): return not b.enemy))
	lasers.clear()


func _update_wave(dt: float) -> void:
	if wave == null:
		return
	wave.r += 2300 * dt
	for a in aliens:
		if not a.alive or a.bomb_hit == wave.id:
			continue
		if a.pos.distance_to(wave.pos) < wave.r:
			a.bomb_hit = wave.id
			_damage_alien(a, 3)
	if saucer != null and saucer.pos.distance_to(wave.pos) < wave.r:
		_damage_saucer(3)
	if boss != null and boss.state == "fight" and boss.bomb_hit != wave.id and Vector2(boss.x, boss.y).distance_to(wave.pos) < wave.r:
		boss.bomb_hit = wave.id
		_damage_boss(12, boss.x, boss.y + 60)
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
	if lowest > PLAYER_Y - 40 and alive:
		fx.text(W / 2, H / 2, "THEY BROKE THROUGH!", Color("#ff6b6b"), 54, 2)
		_kill_player()
		form_y = form_start_y
		drop_left = 0


func _update_aliens(dt: float) -> void:
	var chance := lv.dive_chance * float(dm.speed) * dt
	if chance > 0 and randf() < chance and alive:
		var cands := aliens.filter(func(a): return a.alive and a.state == "formation" and a.kind != "cruiser")
		if cands.size() > 2:
			var a: Alien = cands.pick_random()
			a.state = "dive"
			a.t = 0
			a.vel = Vector2((px - a.pos.x) * 0.3, -160)
			a.fired = false
	for a in aliens:
		if not a.alive:
			continue
		a.flash = maxf(0.0, a.flash - dt)
		if a.state == "dive" or a.state == "minion":
			a.t += dt
			var ax := clampf((px - a.pos.x) * 2.2, -900, 900)
			a.vel.x = clampf(a.vel.x + ax * dt, -420, 420)
			a.vel.y = minf(a.vel.y + 520 * dt, 560 * float(dm.speed))
			a.pos += a.vel * dt
			if not a.fired and a.pos.y > 300 and a.pos.y < PLAYER_Y - 250:
				a.fired = true
				_alien_shoot(a, true)
			if alive and invuln <= 0 and _overlap(a.pos, a.size * 0.7, Vector2(px, PLAYER_Y + 4), Vector2(70, 60)):
				_damage_alien(a, 99)
				_hit_player()
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
	if not alive:
		return
	var fa := aliens.filter(func(a): return a.alive and a.state == "formation")
	if fa.is_empty():
		return
	var frac := 1.0 - float(fa.size()) / total_aliens
	var rate := lv.fire_rate * float(dm.fire) * (1 + frac * 0.6)
	fire_acc += rate * dt
	var cap := 12 + level_index * 2
	while fire_acc >= 1:
		fire_acc -= 1 + randf_range(-0.3, 0.3)
		if bullets.filter(func(b): return b.enemy).size() >= cap:
			continue
		var cols := {}
		for a in fa:
			var k := roundi(a.slot.x)
			if not cols.has(k) or a.slot.y > cols[k].slot.y:
				cols[k] = a
		var shooters: Array = cols.values()
		shooters.sort_custom(func(a, b): return absf(a.pos.x - px) < absf(b.pos.x - px))
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
		b.enemy = true
		b.hue = hue
		b.rot = -angle
		bullets.append(b)
		Audio.play("alien_shot_heavy" if heavy else "alien_shot")
	var aim := func() -> float: return clampf(atan2(px - a.pos.x, PLAYER_Y - a.pos.y), -0.6, 0.6)
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
	if boss != null:
		return
	if saucer == null:
		saucer_t -= dt
		if saucer_t <= 0 and _formation_aliens().size() > 3:
			var dir := 1.0 if randf() < 0.5 else -1.0
			saucer = {"pos": Vector2(-120 if dir > 0 else W + 120, 92), "dir": dir, "hp": 3, "flash": 0.0}
			saucer_t = lv.saucer_every * randf_range(0.8, 1.25)
			Audio.saucer_start()
		return
	saucer.pos.x += saucer.dir * 250 * dt
	saucer.flash = maxf(0.0, saucer.flash - dt)
	if (saucer.dir > 0 and saucer.pos.x > W + 140) or (saucer.dir < 0 and saucer.pos.x < -140):
		_stop_saucer()


func _stop_saucer() -> void:
	if saucer != null:
		Audio.saucer_stop()
	saucer = null


func _damage_saucer(dmg: int) -> void:
	saucer.hp -= dmg
	saucer.flash = 0.08
	if saucer.hp > 0:
		Audio.play("hit_armor")
		fx.hit(saucer.pos.x, saucer.pos.y + 10, 310)
		return
	var p: Vector2 = saucer.pos
	_stop_saucer()
	var pts: float = [100, 150, 200, 300].pick_random() * (1 + level_index * 0.25)
	var val := roundi(pts / 10.0) * 10
	add_score(val)
	fx.explosion(p.x, p.y, 310, 1.8)
	fx.text(p.x, p.y, "+%d" % val, Color("#ff8ae6"), 36, 1.4)
	Audio.play("explode_big")
	add_shake(10)
	_drop_power(p, true)


func _update_bullets(dt: float) -> void:
	for b in bullets:
		b.pos += b.vel * dt
	var keep: Array[Bullet] = []
	for b in bullets:
		if b.pos.y < -60 or b.pos.y > H + 60 or b.pos.x < -60 or b.pos.x > W + 60:
			continue
		var gone := false
		for i in 3:
			var t := i / 3.0
			var x := b.pos.x - b.vel.x * (1.0 / 60.0) * t
			var y := b.pos.y - b.vel.y * (1.0 / 60.0) * t + (b.size.y / 2 if b.enemy else -b.size.y / 2)
			var hit := _bunker_at(x, y)
			if hit.size():
				_erode(hit[0], x, y, (20.0 if b.size.x > 16 else 15.0) if b.enemy else 10.0)
				fx.dust(x, y, lv.bunker_dust)
				Audio.play("bunker_hit")
				gone = true
				break
		if gone:
			continue
		if b.enemy:
			if state != "play" and state != "boss_warn":
				keep.append(b)
				continue
			if alive and shield_t > 0 and b.pos.distance_to(Vector2(px, PLAYER_Y)) < 78:
				fx.hit(b.pos.x, b.pos.y, 210)
				Audio.play("shield_block")
				continue
			if alive and invuln <= 0 and _overlap(b.pos, b.size, Vector2(px, PLAYER_Y + 6), Vector2(54, 54)):
				_hit_player()
				continue
		else:
			var consumed := false
			for a in aliens:
				if not a.alive:
					continue
				if _overlap(b.pos, b.size, a.pos, a.size * 0.82):
					_damage_alien(a, b.dmg)
					fx.hit(b.pos.x, b.pos.y - 10, a.hue)
					consumed = true
					break
			if consumed:
				continue
			if saucer != null and _overlap(b.pos, b.size, saucer.pos, Vector2(170, 56)):
				_damage_saucer(b.dmg)
				continue
			if boss != null and boss.state == "fight":
				var dx: float = (b.pos.x - boss.x) / 230.0
				var dy: float = (b.pos.y - (boss.y - 10)) / 150.0
				if dx * dx + dy * dy < 1:
					_damage_boss(b.dmg, b.pos.x, b.pos.y)
					continue
		keep.append(b)
	bullets = keep


func _damage_alien(a: Alien, dmg: int) -> void:
	if not a.alive:
		return
	a.hp -= dmg
	a.flash = 0.09
	if a.hp > 0:
		Audio.play("hit_armor")
		return
	a.alive = false
	var big := a.kind == "cruiser"
	var mult := 1 + level_index * 0.1
	var pts := roundi(a.score * mult / 5.0) * 5
	add_score(pts)
	fx.explosion(a.pos.x, a.pos.y, a.hue, 1.8 if big else (1.15 if a.kind in ["beetle", "wraith"] else 0.9))
	fx.text(a.pos.x, a.pos.y - 10, str(pts), UI.hsl(a.hue, 100, 80), 32 if big else 22, 0.8)
	Audio.play("explode_big" if big else "explode_small")
	if big:
		add_shake(8)
	if a.state != "minion":
		_drop_power(a.pos, false, big)


func _drop_power(pos: Vector2, guaranteed: bool, big := false) -> void:
	if powers.size() >= 3 and not guaranteed:
		return
	var chance := (0.5 if big else 0.075) * float(dm.drop)
	if not guaranteed and randf() > chance:
		return
	var opts := [["dual", 22], ["speed", 16], ["shield", 15], ["bomb", 13], ["rapid", 16]]
	if level_index >= 2:
		opts.append(["spread", 12])
	if lives < 6:
		opts.append(["life", 6 if guaranteed else 3])
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
	for p in powers:
		if p[1].y > H + 50:
			continue
		if alive and _overlap(p[1], Vector2(60, 60), Vector2(px, PLAYER_Y), Vector2(100, 80)):
			_collect(p[0])
			continue
		keep.append(p)
	powers = keep


func _collect(k: String) -> void:
	var info: Array = POWER_INFO[k]
	match k:
		"dual":
			weapon = "dual"
			weapon_t = 15
		"spread":
			weapon = "spread"
			weapon_t = 15
		"rapid":
			rapid_t = 12
		"speed":
			speed_t = 12
		"shield":
			shield_t = 10
		"bomb":
			bombs = mini(3, bombs + 1)
		"life":
			lives = mini(7, lives + 1)
	Audio.play("pu_" + k)
	add_score(50)
	fx.text(px, PLAYER_Y - 90, info[0], UI.hsl(info[1], 100, 72), 30, 1.3)
	fx.add(FxSystem.K.RING, px, PLAYER_Y, {"life": 0.5, "size": 20, "grow": 300, "hue": info[1], "light": 70})


func _hit_player() -> void:
	if not alive or invuln > 0 or debug_god:
		return
	if shield_t > 0:
		Audio.play("shield_block")
		return
	_kill_player()


func _kill_player() -> void:
	if not alive:
		return
	alive = false
	lives -= 1
	fx.explosion(px, PLAYER_Y, 190, 2.2)
	fx.explosion(px, PLAYER_Y, 30, 1.2)
	Audio.play("player_hit")
	add_shake(22)
	flash_a = maxf(flash_a, 0.35)
	weapon = "single"
	weapon_t = 0
	rapid_t = 0
	speed_t = 0
	shield_t = 0
	lasers.clear()
	if lives <= 0:
		schedule(1.6, _game_over)
	else:
		respawn_t = 1.5
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
			Audio.play("boss_warn")
			Audio.play_music(Audio.music("boss"))
			_stop_saucer()
		return
	if not alive:
		return
	_level_cleared()


func _level_cleared() -> void:
	state = "cleared"
	state_t = 0
	clear_bonus = 1000 * (level_index + 1) + lives * 250
	_stop_saucer()
	Audio.play("level_clear")
	Audio.play_music(null)
	if level_index + 1 >= Global.levels.size():
		_victory()


# ---------------------------------------------------------------- boss
func _spawn_boss() -> void:
	var hp := roundi(180 * float(dm.boss_hp))
	boss = {"x": W / 2, "y": -260.0, "hp": hp, "max_hp": hp, "t": 0.0, "phase": 1, "flash": 0.0, "state": "enter",
		"attack_t": 2.5, "attack_idx": 0, "dying_t": 0.0, "boom_t": 0.0, "eye": Vector2.ZERO, "bomb_hit": -1}


func _update_boss(dt: float) -> void:
	if boss == null:
		return
	var b: Dictionary = boss
	b.t += dt
	b.flash = maxf(0.0, b.flash - dt)
	var target := Vector2(clampf((px - b.x) / 18.0, -22, 22), clampf((PLAYER_Y - b.y) / 60.0, 4, 14))
	b.eye += (target - b.eye) * dt * 6
	for l in lasers:
		l.t += dt
	lasers = lasers.filter(func(l): return l.t < l.warn + l.dur)
	for l in lasers:
		if l.t >= l.warn and alive and invuln <= 0 and absf(l.x - px) < 58:
			if shield_t > 0:
				if randf() < dt * 10:
					Audio.play("shield_block")
			else:
				_hit_player()
		if l.t >= l.warn:
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
			fx.text(W / 2, 520, "EREBUS, THE VOID SOVEREIGN", Color("#d6a0ff"), 46, 2.4)
		return
	if b.state == "dying":
		b.dying_t += dt
		b.boom_t -= dt
		b.x += sin(b.dying_t * 40) * 2
		if b.boom_t <= 0:
			b.boom_t = 0.11
			fx.explosion(b.x + randf_range(-220, 220), b.y + randf_range(-120, 120), randf_range(260, 360), randf_range(0.8, 1.6))
			Audio.play("explode_big")
			add_shake(10)
		if b.dying_t > 3.2:
			fx.explosion(b.x, b.y, 300, 5)
			fx.explosion(b.x, b.y, 40, 3.5)
			Audio.play("explode_huge")
			flash_a = 1.0
			add_shake(40)
			add_score(10000)
			fx.text(b.x, b.y, "+10,000", Color("#ffe36b"), 56, 2.5)
			boss = null
			lasers.clear()
			bullets.assign(bullets.filter(func(q): return not q.enemy))
			schedule(2.2, _level_cleared)
		return
	var sp := 0.75 if b.phase == 2 else 0.45
	b.x = W / 2 + sin(b.t * sp) * 560
	b.y = 270 + sin(b.t * sp * 2.1) * (50 if b.phase == 2 else 25)
	b.attack_t -= dt
	if b.attack_t <= 0 and alive:
		var attacks := ["radial", "aimed", "lasers", "minions", "spiral"]
		var atk: String = attacks[b.attack_idx % attacks.size()]
		b.attack_idx += 1
		_boss_attack(atk)
		b.attack_t = (1.7 if b.phase == 2 else 2.6) / sqrt(float(dm.fire))


func _boss_shot(angle: float, speed: float, r := 11, hue := 300.0) -> void:
	if boss == null:
		return
	var b := Bullet.new()
	b.pos = Vector2(boss.x, boss.y + 60)
	b.vel = Vector2(sin(angle), cos(angle)) * speed
	b.size = Vector2(r * 1.4, r * 1.8)
	b.tex = _plasma(hue, r)
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
					Audio.play("alien_shot_heavy"))
		"aimed":
			for i in (6 if p2 else 4):
				schedule(i * 0.2, func():
					if boss == null:
						return
					var ang := atan2(px - boss.x, PLAYER_Y - boss.y - 60)
					for o in [-0.18, 0.0, 0.18]:
						_boss_shot(ang + o, bs * 1.5, 10, 330)
					Audio.play("alien_shot"))
		"lasers":
			var xs := [px, clampf(px + [-1, 1].pick_random() * randf_range(250, 450), 80, W - 80)]
			if p2:
				xs.append(randf_range(100, W - 100))
			for x in xs:
				lasers.append({"x": x, "t": 0.0, "warn": 0.85 if p2 else 1.1, "dur": 1.1})
			Audio.play("boss_laser_charge")
			schedule(0.85 if p2 else 1.1, func():
				if boss != null:
					Audio.play("boss_laser")
					add_shake(8))
		"minions":
			var n := 4 if p2 else 3
			for i in n:
				var m := _make_alien("squid" if i % 2 else "drone", Vector2.ZERO, "minion")
				m.pos = Vector2(boss.x + (i - (n - 1) / 2.0) * 120, boss.y + 80)
				m.vel = Vector2((i - (n - 1) / 2.0) * 150, -120)
				aliens.append(m)
			fx.explosion(boss.x, boss.y + 80, 280, 1)
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
						Audio.play("alien_shot"))


func _damage_boss(dmg: int, x: float, y: float) -> void:
	var b: Dictionary = boss
	if b.state != "fight":
		return
	b.hp -= dmg
	b.flash = 0.06
	add_score(10 * dmg)
	fx.hit(x, y, 300)
	Audio.play("hit_armor")
	if b.phase == 1 and b.hp <= b.max_hp / 2.0:
		b.phase = 2
		b.attack_t = 1.2
		fx.text(W / 2, 560, "EREBUS IS ENRAGED!", Color("#ff5a7a"), 52, 2)
		Audio.play("boss_warn")
		add_shake(16)
		flash_a = 0.4
	if b.hp <= 0:
		b.hp = 0
		b.state = "dying"
		b.dying_t = 0.0
		b.boom_t = 0.0
		lasers.clear()
		bullets.assign(bullets.filter(func(q): return not q.enemy))
		aliens.assign(aliens.filter(func(a): return a.state != "minion"))
		Audio.play_music(null)


# ---------------------------------------------------------------- endings
func _game_over() -> void:
	state = "gameover"
	state_t = 0
	end_shown = false
	_stop_saucer()
	new_high = Global.submit_score(score)
	Audio.play_music(null)
	Audio.play("game_over")


func _victory() -> void:
	state = "victory"
	state_t = 0
	end_shown = false
	add_score(clear_bonus)
	clear_bonus = 0
	new_high = Global.submit_score(score)
	Global.clear_game()
	Audio.play("victory")


func _show_end_menu() -> void:
	end_shown = true
	var items := []
	var y := 640.0
	if state == "gameover":
		items.append(["Retry Planet", func():
			var start := checkpoint.duplicate()
			start.lives = Global.DIFFICULTY[diff].lives
			Global.start_game(start)])
	else:
		y = 760.0
	items.append(["Main Menu", Global.goto_menu])
	var buttons := []
	for i in items.size():
		var b := GameButton.make(items[i][0], items[i][1], 520, 70)
		b.position = Vector2(960 - 260, y + i * 86)
		end_menu.add_child(b)
		buttons.append(b)
	GameButton.link_vertical(buttons)
	buttons[0].focus_quietly()


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
		var rot := clampf(-a.vel.x / 900.0, -0.5, 0.5) if a.state in ["dive", "minion"] else 0.0
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
		UI.draw_sprite(ci, b.tex, b.pos, 1.0, b.rot)


func _draw_flames() -> void:
	if not alive or (invuln > 0 and int(time * 14) % 2 == 0):
		return
	var ci: CanvasItem = $World/Flames
	var ln := (60.0 if speed_t > 0 else 34.0) + randf() * 10
	var c := UI.hsl(45 if speed_t > 0 else 195, 100, 65)
	for s in [-7.0, 7.0]:
		ci.draw_texture_rect(TEX_FLAME, Rect2(px + s - 5, PLAYER_Y + 40, 10, ln * 1.05), false, c.lerp(Color.WHITE, 0.2))


func _draw_player() -> void:
	if not alive or (invuln > 0 and int(time * 14) % 2 == 0):
		return
	UI.draw_sprite($World/Player, TEX_PLAYER, Vector2(px, PLAYER_Y), 1.0, clampf(pvx / 4000.0, -0.14, 0.14))


func _draw_shield() -> void:
	if not alive or shield_t <= 0 or (invuln > 0 and int(time * 14) % 2 == 0):
		return
	var fade := (0.4 if int(time * 10) % 2 else 1.0) if shield_t < 2 else 1.0
	var r := 76 + sin(time * 6) * 3
	UI.draw_sprite($World/Shield, TEX_SHIELD, Vector2(px, PLAYER_Y), r / 76.0, time * 0.8, Color(1, 1, 1, fade))


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


func _draw_hud() -> void:
	var ci := hud
	ci.draw_texture_rect(TEX_HUD_TOP, Rect2(0, 0, W, 70), false)
	_txt(ci, "SCORE", 36, 26, 16, "extrabold", Color("#8fc8ff"), HORIZONTAL_ALIGNMENT_LEFT, 4)
	_txt(ci, UI.format_score(score), 36, 54, 32, "extrabold", Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 0, Color(0.4, 0.78, 1, 0.6), 8)
	_txt(ci, "HIGH", 300, 26, 16, "extrabold", Color("#ffd76b"), HORIZONTAL_ALIGNMENT_LEFT, 4)
	_txt(ci, UI.format_score(hi_score), 300, 54, 26, "bold", Color("#ffe9a8"))
	_txt(ci, "PLANET %d/9  ·  %s" % [level_index + 1, lv.planet.to_upper()], W / 2, 34, 24, "extrabold", Color("#dfe9ff"), HORIZONTAL_ALIGNMENT_CENTER, 5)
	for i in mini(lives, 7):
		UI.draw_sprite(ci, TEX_PLAYER, Vector2(W - 52 - i * 46, 38), 0.36)
	for i in bombs:
		UI.draw_sprite(ci, TEX_HUD_BOMB, Vector2(W - 52 - i * 40, 88))
	if bombs > 0:
		_txt(ci, "B", W - 52 - bombs * 40 + 8, 89, 18, "extrabold", Color("#ffb08a"), HORIZONTAL_ALIGNMENT_CENTER)
	var actives := []
	if weapon_t > 0:
		actives.append(["spread" if weapon == "spread" else "dual", weapon_t, 15.0])
	if rapid_t > 0:
		actives.append(["rapid", rapid_t, 12.0])
	if speed_t > 0:
		actives.append(["speed", speed_t, 12.0])
	if shield_t > 0:
		actives.append(["shield", shield_t, 10.0])
	for i in actives.size():
		var k: String = actives[i][0]
		var x := 36.0
		var y := H - 60 - i * 58
		var info: Array = POWER_INFO[k]
		UI.draw_sprite(ci, _hud_power_tex[k], Vector2(x + 20, y))
		_txt(ci, info[0], x + 52, y - 9, 16, "extrabold", UI.hsl(info[1], 100, 80), HORIZONTAL_ALIGNMENT_LEFT, 2)
		ci.draw_texture_rect(TEX_TIMER_TRACK, Rect2(x + 52, y + 6, 160, 6), false)
		ci.draw_texture_rect(TEX_TIMER_FILL, Rect2(x + 52, y + 6, 160 * actives[i][1] / actives[i][2], 6), false, UI.hsl(info[1], 100, 65))
	if boss != null and boss.state != "enter":
		var bw := 900.0
		var bx := W / 2 - bw / 2
		var by := 64.0
		_txt(ci, "EREBUS, THE VOID SOVEREIGN", W / 2, by + 6, 18, "extrabold", Color("#e0b8ff"), HORIZONTAL_ALIGNMENT_CENTER, 4)
		ci.draw_texture_rect(TEX_BOSSBAR_FRAME, Rect2(bx - 2, by + 18, bw + 4, 26), false)
		var fw := maxf(0.0, (bw - 6) * float(boss.hp) / boss.max_hp)
		if fw > 0:
			ci.draw_texture_rect_region(TEX_BOSSBAR_FILL, Rect2(bx + 3, by + 23, fw, 16), Rect2(0, 0, fw, 16))
	if level_index == 0 and state == "intro":
		_txt(ci, "←  →  MOVE     ·     SPACE  FIRE     ·     B  NOVA BOMB     ·     ESC  PAUSE", W / 2, H - 28, 20, "bold",
			Color(0.82, 0.9, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 2)


func _draw_banners() -> void:
	var ci := banner
	var t := state_t
	if state == "intro":
		var a := t / 0.4 if t < 0.4 else (maxf(0.0, 1 - (t - 2.7) / 0.5) if t > 2.7 else 1.0)
		var y := H / 2 - 40
		ci.draw_texture_rect(TEX_BAND, Rect2(0, y - 130, W, 260), false, Color(1, 1, 1, a))
		_txt(ci, "PLANET %d OF 9" % (level_index + 1), W / 2, y - 70, 24, "extrabold", Color(0.62, 0.82, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 10)
		_txt(ci, lv.planet.to_upper(), W / 2, y, 104, "display", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 22, Color(0.47, 0.78, 1, 0.9 * a), 16)
		_txt(ci, lv.tagline, W / 2, y + 68, 30, "bold", Color(0.88, 0.93, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 3)
		_txt(ci, lv.fact, W / 2, y + 112, 22, "medium", Color(0.78, 0.84, 0.94, 0.8 * a), HORIZONTAL_ALIGNMENT_CENTER)
	elif state == "boss_warn":
		ci.draw_rect(Rect2(0, 0, W, H), Color(1, 0, 0.16, 0.08 + 0.08 * sin(t * 12)))
		if int(t * 4) % 2 == 0:
			_txt(ci, "WARNING", W / 2, H / 2 - 50, 120, "display", Color("#ff4060"), HORIZONTAL_ALIGNMENT_CENTER, 30, Color(1, 0, 0.19, 0.9), 18)
		_txt(ci, "A MASSIVE SIGNAL IS APPROACHING", W / 2, H / 2 + 50, 32, "extrabold", Color("#ffb0c0"), HORIZONTAL_ALIGNMENT_CENTER, 8)
	elif state == "cleared" and level_index + 1 < Global.levels.size():
		var a := minf(1.0, t * 3)
		_txt(ci, "%s LIBERATED" % lv.planet.to_upper(), W / 2, H / 2 - 50, 84, "display", Color(0.92, 1, 0.95, a), HORIZONTAL_ALIGNMENT_CENTER, 12, Color(0.47, 1, 0.7, 0.9 * a), 16)
		if t > 0.6:
			_txt(ci, "CLEAR BONUS  +" + UI.format_score(clear_bonus), W / 2, H / 2 + 40, 34, "extrabold", Color(1, 0.89, 0.42, a), HORIZONTAL_ALIGNMENT_CENTER, 4)
		if t > 1.4:
			_txt(ci, "Next: " + Global.levels[level_index + 1].planet, W / 2, H / 2 + 100, 28, "bold", Color(0.74, 0.85, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
	elif state == "gameover":
		var a := minf(1.0, t * 1.5)
		ci.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0, 0.024, 0.78 * a))
		_txt(ci, "GAME OVER", W / 2, 330, 130, "display", Color(1, 0.42, 0.48, a), HORIZONTAL_ALIGNMENT_CENTER, 20, Color(1, 0.13, 0.25, 0.9 * a), 18)
		_txt(ci, "SCORE  " + UI.format_score(score), W / 2, 470, 40, "extrabold", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6)
		if new_high:
			_txt(ci, "NEW HIGH SCORE!", W / 2, 540, 32, "extrabold", Color(1, 0.89, 0.42, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(1, 0.69, 0, 0.8 * a))
	elif state == "victory":
		var a := minf(1.0, t * 0.8)
		ci.draw_rect(Rect2(0, 0, W, H), Color(0, 0.024, 0.08, 0.72 * a))
		_txt(ci, "VICTORY", W / 2, 300, 150, "display", Color(1, 0.96, 0.82, a), HORIZONTAL_ALIGNMENT_CENTER, 26, Color(1, 0.75, 0.25, 0.9 * a), 20)
		_txt(ci, "The solar system is safe. Every world, from Mercury to Pluto, is free.", W / 2, 420, 30, "bold", Color(0.88, 0.93, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
		_txt(ci, "FINAL SCORE  " + UI.format_score(score), W / 2, 520, 48, "black", Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0.47, 0.78, 1, 0.8 * a))
		_txt(ci, "%s difficulty" % Global.DIFFICULTY[diff].label, W / 2, 580, 24, "bold", Color(0.66, 0.77, 0.91, a), HORIZONTAL_ALIGNMENT_CENTER)
		if new_high:
			_txt(ci, "NEW HIGH SCORE!", W / 2, 650, 34, "extrabold", Color(1, 0.89, 0.42, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(1, 0.69, 0, 0.8 * a))


# ---------------------------------------------------------------- test hooks (used by tools/autotest.gd only)
func debug_clear_wave() -> void:
	for a in aliens:
		if a.state != "minion":
			a.alive = false
	aliens.assign(aliens.filter(func(a): return a.alive))


func debug_damage_boss(n: int) -> void:
	if boss != null and boss.state == "fight":
		_damage_boss(n, boss.x, boss.y)


func debug_give(k: String) -> void:
	_collect(k)


func debug_jump(level: int) -> void:
	load_level(level)
