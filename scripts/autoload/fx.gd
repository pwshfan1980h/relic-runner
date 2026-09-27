extends Node2D
## Cheap world-space effects: dust puffs, sparks, bullet tracers and screen shake.
## Everything is drawn here as flat squares/lines so it matches the 90s look.

const GRAVITY := 300.0

var shake := 0.0  # current trauma, decays; the camera reads offset()
var _parts: Array = []  # [pos, vel, life, max_life, size, color, grav]
var _lines: Array = []  # [a, b, life, max_life, color]
var _texts: Array = []  # [pos, text, life, color]


func _ready() -> void:
	z_index = 60


func clear() -> void:
	_parts.clear()
	_lines.clear()
	_texts.clear()
	shake = 0.0


## Freeze-frame on big hits: the world nearly stops for a moment.
func hitstop(seconds := 0.045) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func add_shake(amount: float) -> void:
	shake = minf(1.0, shake + amount)


func offset() -> Vector2:
	var s := shake * shake * 4.0
	return Vector2(randf_range(-s, s), randf_range(-s, s))


## Dust kicked up by feet. dir biases the throw (e.g. skid direction).
func puff(pos: Vector2, count := 4, color := Color("#b89868"), dir := Vector2.ZERO, spread := 30.0) -> void:
	for i in count:
		var v := dir + Vector2(randf_range(-spread, spread), randf_range(-spread * 0.8, -spread * 0.1))
		_parts.append([pos + Vector2(randf_range(-2, 2), 0), v, 0.0, randf_range(0.3, 0.55), randf_range(1.0, 2.5), color, -20.0])


func sparks(pos: Vector2, dir: Vector2, count := 6, color := Color("#ffe27a")) -> void:
	for i in count:
		var v := dir.rotated(randf_range(-0.9, 0.9)) * randf_range(60, 170)
		_parts.append([pos, v, 0.0, randf_range(0.12, 0.3), 1.0, color, GRAVITY])


func chips(pos: Vector2, dir: Vector2, count := 4, color := Color("#8a6a48")) -> void:
	for i in count:
		var v := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(40, 110) + Vector2(0, -40)
		_parts.append([pos, v, 0.0, randf_range(0.3, 0.6), 1.0, color, GRAVITY * 1.5])


func float_text(pos: Vector2, text: String, color := Color.WHITE) -> void:
	_texts.append([pos, text, 0.0, color])


func tracer(a: Vector2, b: Vector2, color := Color("#fff2b0")) -> void:
	_lines.append([a, b, 0.0, 0.07, color])


func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.2)
	for p in _parts:
		p[2] += delta
		p[1].y += p[6] * delta
		if p[6] < 0:
			p[1] *= 1.0 - 2.5 * delta
		p[0] += p[1] * delta
	_parts = _parts.filter(func(p): return p[2] < p[3])
	for l in _lines:
		l[2] += delta
	_lines = _lines.filter(func(l): return l[2] < l[3])
	for tx in _texts:
		tx[2] += delta
		tx[0].y -= 18.0 * delta
	_texts = _texts.filter(func(tx): return tx[2] < 1.4)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var t: float = p[2] / p[3]
		var c: Color = p[5]
		c.a *= 1.0 - t * t
		var s: float = p[4] * (1.0 + t if p[6] < 0 else 1.0)
		draw_rect(Rect2((p[0] as Vector2).round() - Vector2(s, s) * 0.5, Vector2(s, s)), c)
	var font := ThemeDB.fallback_font
	for tx in _texts:
		var c: Color = tx[3]
		c.a = clampf(1.4 - tx[2], 0.0, 1.0)
		var w := font.get_string_size(tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var p: Vector2 = (tx[0] as Vector2) - Vector2(w / 2.0, 0)
		draw_string(font, p.round() + Vector2(1, 1), tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, c.a * 0.8))
		draw_string(font, p.round(), tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
	for l in _lines:
		var c: Color = l[4]
		c.a *= 1.0 - l[2] / l[3]
		draw_line(l[0], l[1], c, 1.0)
