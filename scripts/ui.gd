class_name UI
## Shared helpers: fonts, labels, colours and number formatting.

const FONT_FILES := {
	"medium": "res://assets/fonts/Inter-Medium.ttf",
	"bold": "res://assets/fonts/Inter-Bold.ttf",
	"extrabold": "res://assets/fonts/Inter-ExtraBold.ttf",
	"black": "res://assets/fonts/Inter-Black.ttf",
	"display": "res://assets/fonts/InterDisplay-Black.ttf",
}

static var _fonts := {}


## A font from assets/fonts with optional extra letter spacing (pixels).
static func font(weight := "bold", spacing := 0) -> Font:
	var key := "%s:%d" % [weight, spacing]
	if not _fonts.has(key):
		var base: Font = load(FONT_FILES.get(weight, FONT_FILES.bold))
		if spacing == 0:
			_fonts[key] = base
		else:
			var v := FontVariation.new()
			v.base_font = base
			v.spacing_glyph = spacing
			_fonts[key] = v
	return _fonts[key]


static func settings(size: int, weight := "bold", color := Color.WHITE, spacing := 0, glow := Color(0, 0, 0, 0), glow_size := 10) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font(weight, spacing)
	s.font_size = size
	s.font_color = color
	if glow.a > 0.0:
		s.shadow_color = glow
		s.shadow_size = glow_size
		s.shadow_offset = Vector2.ZERO
	return s


## A Label using the game fonts. Position it yourself; `align` is the horizontal alignment.
static func label(text: String, size: int, weight := "bold", color := Color.WHITE, spacing := 0,
		align := HORIZONTAL_ALIGNMENT_LEFT, glow := Color(0, 0, 0, 0), glow_size := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = settings(size, weight, color, spacing, glow, glow_size)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Places a label so that its text is centred on (x, y) (or left/right-anchored at x).
static func place(l: Label, x: float, y: float, width := 1600.0) -> Label:
	l.size = Vector2(width, l.label_settings.font_size * 1.6)
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			l.position = Vector2(x - width / 2.0, y - l.size.y / 2.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			l.position = Vector2(x - width, y - l.size.y / 2.0)
		_:
			l.position = Vector2(x, y - l.size.y / 2.0)
	return l


## CSS-style HSL colour (h in degrees, s and l in percent).
static func hsl(h: float, s: float, l: float, a := 1.0) -> Color:
	h = fposmod(h, 360.0) / 360.0
	s /= 100.0
	l /= 100.0
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	return Color(_hue(p, q, h + 1.0 / 3.0), _hue(p, q, h), _hue(p, q, h - 1.0 / 3.0), a)


static func _hue(p: float, q: float, t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 0.5:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p


static func format_score(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Draws a 2x-resolution sprite texture centred at pos (textures are authored at twice their on-screen size).
static func draw_sprite(ci: CanvasItem, tex: Texture2D, pos: Vector2, scale := 1.0, rot := 0.0, mod := Color.WHITE) -> void:
	var s := tex.get_size() * 0.5 * scale
	if rot == 0.0:
		ci.draw_texture_rect(tex, Rect2(pos - s / 2.0, s), false, mod)
	else:
		ci.draw_set_transform(pos, rot, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-s / 2.0, s), false, mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
