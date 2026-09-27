class_name Hud
extends CanvasLayer
## Health (fedoras), the revolver cylinder, map title and a fading controls hint.

const INK := Color("#f4e4c0")
const SHADOW := Color("#1a0e08")

var _hero: Hero
var _draw_node: Control
var _title: Label
var _hint: Label
var _banner: Label
var _sign: Label
var _t := 0.0
var _spin := 0.0
var _smear := 0.0  # llama spit on the lens, fades
var _smear_seed := 0


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_draw_hud)
	add_child(_draw_node)
	_title = _label(Vector2(0, 30), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_hint = _label(Vector2(0, 252), 8, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.text = "WASD MOVE  SHIFT RUN  SPACE JUMP  C CROUCH  LMB SHOOT  RMB WHIP  E PUNCH  F KICK  R RELOAD  TAB LOOT"
	_banner = _label(Vector2(0, 110), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_sign = _label(Vector2(40, 214), 8, HORIZONTAL_ALIGNMENT_CENTER)
	_sign.size = Vector2(400, 30)
	_sign.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sign.label_settings.font_color = Color("#ffe0a0")


func _label(pos: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(480, 20)
	l.horizontal_alignment = align
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = INK
	ls.shadow_color = SHADOW
	ls.shadow_offset = Vector2(1, 1)
	l.label_settings = ls
	add_child(l)
	return l


func bind(hero: Hero, title: String) -> void:
	_hero = hero
	_title.text = title.to_upper()
	hero.ammo_changed.connect(func(_a, reloading): _spin = 1.0 if reloading else _spin)
	hero.health_changed.connect(func(_hp): _draw_node.queue_redraw())


func banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0


func smear() -> void:
	_smear = 1.0
	_smear_seed = randi()


func hint(text: String) -> void:
	_sign.text = text.to_upper()


func _process(delta: float) -> void:
	_t += delta
	_title.modulate.a = clampf(3.5 - _t, 0.0, 1.0)
	_hint.modulate.a = clampf(14.0 - _t, 0.0, 0.85)
	_spin = move_toward(_spin, 0.0, delta * 1.2)
	_smear = move_toward(_smear, 0.0, delta * 0.6)
	_draw_node.queue_redraw()


func _draw_hud() -> void:
	if _hero == null:
		return
	var n := _draw_node
	if _smear > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = _smear_seed
		for i in 5:
			var c := Vector2(rng.randf_range(120, 360), rng.randf_range(60, 200))
			var r := rng.randf_range(8, 22)
			n.draw_circle(c, r, Color(0.55, 0.7, 0.2, 0.35 * _smear))
			n.draw_circle(c + Vector2(r * 0.3, r * 0.6), r * 0.45, Color(0.7, 0.82, 0.3, 0.35 * _smear))
			n.draw_rect(Rect2(c + Vector2(-1, r * 0.8), Vector2(2, r * 0.9 * (1.0 - _smear * 0.5))), Color(0.55, 0.7, 0.2, 0.3 * _smear))
	# Health: one fedora per hit point.
	for i in Hero.MAX_HP:
		var x := 10 + i * 14
		var col := Color("#8a5a30") if i < _hero.hp else Color(0.3, 0.22, 0.18, 0.6)
		n.draw_rect(Rect2(x + 3, 8, 6, 4), col)
		n.draw_rect(Rect2(x, 12, 12, 2), col.darkened(0.2))
		n.draw_rect(Rect2(x + 3, 11, 6, 1), SHADOW)
	# Revolver cylinder: six chambers, spent ones dark. Spins while reloading.
	var c := Vector2(20, 250)
	n.draw_circle(c + Vector2(1, 1), 9.0, SHADOW)
	n.draw_circle(c, 9.0, Color("#5a5a64"))
	for i in 6:
		var a := TAU * i / 6.0 - PI / 2.0 + _spin * TAU
		var p := c + Vector2(cos(a), sin(a)) * 5.5
		var loaded := i < _hero.ammo
		n.draw_circle(p, 2.0, Color("#d8b050") if loaded else Color("#18181c"))
	n.draw_circle(c, 1.5, Color("#2c2c33"))
	# Gold carried (top right).
	var font := ThemeDB.fallback_font
	var gtext := "%d G" % GameState.gold
	var gw := font.get_string_size(gtext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	n.draw_circle(Vector2(468 - gw - 6, 11), 3.0, Color("#d0a020"))
	n.draw_string(font, Vector2(470 - gw, 15) + Vector2(1, 1), gtext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SHADOW)
	n.draw_string(font, Vector2(470 - gw, 15), gtext, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffd040"))
