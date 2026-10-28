class_name FxSystem
extends Node2D
## Explosions, sparks, smoke, debris and floating score text, drawn with the textures in assets/sprites/fx.

const TEX_GLOW := preload("res://assets/sprites/fx/glow.png")
const TEX_SPARK := preload("res://assets/sprites/fx/spark.png")
const TEX_SMOKE := preload("res://assets/sprites/fx/smoke.png")
const TEX_RING := preload("res://assets/sprites/fx/ring.png")
const TEX_DEBRIS := preload("res://assets/sprites/fx/debris.png")
const CAP := 2500

enum K { SPARK, GLOW, SMOKE, RING, DEBRIS, STREAK }


class P:
	var x: float
	var y: float
	var vx := 0.0
	var vy := 0.0
	var life := 0.6
	var max_life := 0.6
	var size := 4.0
	var grow := 0.0
	var color := Color.WHITE
	var kind := K.SPARK
	var drag := 0.9
	var rot := 0.0
	var vr := 0.0


class FloatText:
	var x: float
	var y: float
	var text: String
	var life: float
	var max_life: float
	var color: Color
	var size: int


var _list: Array[P] = []
var _texts: Array[FloatText] = []
var _normal: Node2D
var _add: Node2D
var _text_layer: Node2D
var _font: Font


func _ready() -> void:
	_font = UI.font("extrabold")
	_normal = Node2D.new()
	_add = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = m
	_text_layer = Node2D.new()
	add_child(_normal)
	add_child(_add)
	add_child(_text_layer)
	_normal.draw.connect(_draw_normal)
	_add.draw.connect(_draw_add)
	_text_layer.draw.connect(_draw_text)


func add(kind: K, x: float, y: float, opts := {}) -> void:
	if _list.size() >= CAP:
		_list.pop_front()
	var p := P.new()
	p.kind = kind
	p.x = x
	p.y = y
	p.vx = opts.get("vx", 0.0)
	p.vy = opts.get("vy", 0.0)
	p.life = opts.get("life", 0.6)
	p.max_life = p.life
	p.size = opts.get("size", 4.0)
	p.grow = opts.get("grow", 0.0)
	p.color = UI.hsl(opts.get("hue", 30.0), opts.get("sat", 100.0), opts.get("light", 60.0))
	p.drag = opts.get("drag", 0.9)
	p.vr = opts.get("vr", 0.0)
	_list.append(p)


func explosion(x: float, y: float, hue: float, scale := 1.0) -> void:
	add(K.RING, x, y, {"life": 0.45, "size": 10 * scale, "grow": 260 * scale, "hue": hue, "light": 75})
	add(K.GLOW, x, y, {"life": 0.3, "size": 70 * scale, "grow": -60, "hue": hue + 20, "light": 70})
	for i in int(26 * scale):
		var a := randf() * TAU
		var sp := randf_range(120, 520) * scale
		add(K.SPARK, x, y, {"vx": cos(a) * sp, "vy": sin(a) * sp, "life": randf_range(0.3, 0.8),
			"size": randf_range(2, 5) * sqrt(scale), "hue": hue + randf_range(-25, 25), "light": randf_range(55, 85), "drag": 0.04})
	for i in int(8 * scale):
		var a := randf() * TAU
		var sp := randf_range(40, 160) * scale
		add(K.SMOKE, x, y, {"vx": cos(a) * sp, "vy": sin(a) * sp, "life": randf_range(0.6, 1.2),
			"size": randf_range(14, 30) * scale, "grow": 30, "hue": hue, "sat": 20, "light": 30, "drag": 0.15})
	for i in int(6 * scale):
		var a := randf() * TAU
		var sp := randf_range(100, 300) * scale
		add(K.DEBRIS, x, y, {"vx": cos(a) * sp, "vy": sin(a) * sp, "life": randf_range(0.5, 1.0),
			"size": randf_range(3, 7), "hue": hue, "sat": 40, "light": 40, "drag": 0.3, "vr": randf_range(-10, 10)})


func hit(x: float, y: float, hue: float) -> void:
	for i in 8:
		var a := -PI / 2 + randf_range(-1.4, 1.4)
		var sp := randf_range(100, 300)
		add(K.SPARK, x, y, {"vx": cos(a) * sp, "vy": sin(a) * sp, "life": randf_range(0.15, 0.35),
			"size": randf_range(1.5, 3), "hue": hue, "light": 75, "drag": 0.05})
	add(K.GLOW, x, y, {"life": 0.12, "size": 26, "grow": -40, "hue": hue, "light": 80})


func dust(x: float, y: float, c: Color) -> void:
	for i in 7:
		var a := randf() * TAU
		var sp := randf_range(30, 160)
		add(K.DEBRIS, x, y, {"vx": cos(a) * sp, "vy": sin(a) * sp, "life": randf_range(0.3, 0.6),
			"size": randf_range(2, 4), "drag": 0.2, "vr": randf_range(-8, 8)})
		_list.back().color = c


func text(x: float, y: float, msg: String, color := Color.WHITE, size := 26, life := 1.0) -> void:
	var t := FloatText.new()
	t.x = x
	t.y = y
	t.text = msg
	t.life = life
	t.max_life = life
	t.color = color
	t.size = size
	_texts.append(t)


func clear() -> void:
	_list.clear()
	_texts.clear()


func _process(dt: float) -> void:
	dt = minf(dt, 1.0 / 30.0)
	var keep: Array[P] = []
	for p in _list:
		p.life -= dt
		if p.life <= 0:
			continue
		var d := pow(p.drag, dt)
		p.vx *= d
		p.vy *= d
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.size = maxf(0.0, p.size + p.grow * dt)
		p.rot += p.vr * dt
		if p.kind == K.DEBRIS:
			p.vy += 220 * dt
		keep.append(p)
	_list = keep
	var tk: Array[FloatText] = []
	for t in _texts:
		t.life -= dt
		t.y -= 50 * dt
		if t.life > 0:
			tk.append(t)
	_texts = tk
	_normal.queue_redraw()
	_add.queue_redraw()
	_text_layer.queue_redraw()


func _draw_normal() -> void:
	for p in _list:
		var k := maxf(0.0, p.life / p.max_life)
		if p.kind == K.SMOKE:
			var c := p.color
			c.a = 0.45 * k
			_normal.draw_texture_rect(TEX_SMOKE, Rect2(p.x - p.size * 1.3, p.y - p.size * 1.3, p.size * 2.6, p.size * 2.6), false, c)
		elif p.kind == K.DEBRIS:
			var c := p.color
			c.a = k
			_normal.draw_set_transform(Vector2(p.x, p.y), p.rot, Vector2.ONE)
			_normal.draw_texture_rect(TEX_DEBRIS, Rect2(-p.size / 2, -p.size / 3, p.size, p.size * 0.66), false, c)
	_normal.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_add() -> void:
	for p in _list:
		var k := maxf(0.0, p.life / p.max_life)
		var c := p.color
		match p.kind:
			K.SPARK:
				var sp := Vector2(p.vx, p.vy)
				var spd := sp.length()
				var ln := minf(18.0, spd * 0.03) + 2.0
				var w := (p.size * k + 0.5) * 1.4
				c.a = k
				_add.draw_set_transform(Vector2(p.x, p.y), sp.angle() if spd > 0.01 else 0.0, Vector2.ONE)
				_add.draw_texture_rect(TEX_SPARK, Rect2(-ln, -w / 2, ln + w * 0.5, w), false, c)
			K.GLOW:
				var r := maxf(1.0, p.size)
				c = c.lerp(Color.WHITE, 0.35)
				c.a = k
				_add.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				_add.draw_texture_rect(TEX_GLOW, Rect2(p.x - r, p.y - r, r * 2, r * 2), false, c)
			K.RING:
				var r2 := p.size * 128.0 / 116.0
				c.a = k * 0.8
				_add.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				_add.draw_texture_rect(TEX_RING, Rect2(p.x - r2, p.y - r2, r2 * 2, r2 * 2), false, c)
			K.STREAK:
				c.a = k * 0.7
				_add.draw_set_transform(Vector2(p.x, p.y + p.size * 2.5), PI / 2, Vector2.ONE)
				_add.draw_texture_rect(TEX_SPARK, Rect2(-p.size * 2.5, -p.size / 2, p.size * 5, p.size), false, c)
	_add.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_text() -> void:
	for t in _texts:
		var k := t.life / t.max_life
		var a := minf(1.0, k * 2.0)
		var sz := _font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.size)
		var pos := Vector2(t.x - sz.x / 2.0, t.y + t.size * 0.36)
		var glow := t.color
		glow.a = 0.35 * a
		_text_layer.draw_string_outline(_font, pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.size, 8, glow)
		var c := t.color
		c.a = a
		_text_layer.draw_string(_font, pos, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.size, c)
