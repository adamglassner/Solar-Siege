class_name Starfield
extends Node2D
## Parallax starfield drawn over the planet backdrop (assets/sprites/fx/star.png).

const STAR := preload("res://assets/sprites/fx/star.png")
const W := 1920.0
const H := 1080.0

var speed := 1.0
var _stars: Array[Vector4] = [] # x, y, depth, twinkle phase
var _t := 0.0


func setup(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_stars.clear()
	for i in 220:
		_stars.append(Vector4(rng.randf() * W, rng.randf() * H, 0.2 + rng.randf() * 0.8, rng.randf() * TAU))


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	if _stars.is_empty():
		setup(1)


func _process(dt: float) -> void:
	_t += dt
	for i in _stars.size():
		var s := _stars[i]
		s.y += (12.0 + s.z * s.z * 90.0) * dt * speed
		if s.y > H + 4:
			s.y = -4
			s.x = randf() * W
		_stars[i] = s
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		var a := (0.35 + 0.65 * s.z) * (0.75 + 0.25 * sin(_t * 3.0 + s.w))
		var r := 0.6 + s.z * 1.6
		var c := Color(0.86, 0.92, 1.0, a)
		if s.z > 0.85 and speed > 1.5:
			draw_texture_rect(STAR, Rect2(s.x - r, s.y - r * 7, r * 2, r * 8), false, c)
		else:
			draw_texture_rect(STAR, Rect2(s.x - r * 1.6, s.y - r * 1.6, r * 3.2, r * 3.2), false, c)
