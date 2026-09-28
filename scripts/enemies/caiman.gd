class_name Caiman
extends Enemy
## River caiman. Floats with only its eyes and snout above the surface, drifting. When
## you come near (swimming, or standing at the water's edge) it lunges, jaws wide, and
## then sinks back to wait. Too heavy for the whip; shoot it, grenade it, or keep away.

enum S { LURK, LUNGE, RECOVER }

const HIDE := Color("#3a4a2a")
const HIDE_D := Color("#26321c")
const BELLY := Color("#8a8a5a")
const MOUTH := Color("#8a3a30")

var state := S.LURK
var _st := 0.0
var _jaw := 0.0


func _setup() -> void:
	size = Vector2(26, 7)
	hp = 4
	aquatic = true
	pullable = false
	knock_scale = 0.3
	voice_die = ""
	loot = {"coins": [1, 4], "items": 0.4, "luck": 0.3}


func _think(delta: float) -> void:
	_st += delta
	if water == null:
		return
	var surf := water.surface_y(global_position.x)
	var d := to_hero()
	match state:
		S.LURK:
			_jaw = move_toward(_jaw, 0.0, delta * 4.0)
			# Float so the eyes just break the surface; drift near home.
			var want_y := surf + 5.0
			velocity.y = clampf((want_y - global_position.y) * 4.0, -60.0, 60.0)
			velocity.x = move_toward(velocity.x, (_home.x - global_position.x) * 0.3 + sin(t * 0.4) * 6.0, 40.0 * delta)
			if absf(d.x) > 2.0:
				facing = int(signf(d.x))
			if hero_alive() and absf(d.x) < 72.0 and d.y > -40.0 and d.y < 50.0 and _st > 1.2:
				Audio.play_at("snake_hiss", global_position, -2.0, 0.1)
				_go(S.LUNGE)
				var to := (hero.global_position + Vector2(0, -12) - global_position)
				velocity = to.normalized() * 230.0
				velocity.y = minf(velocity.y, -40.0)
		S.LUNGE:
			_jaw = minf(1.0, _jaw + delta * 8.0)
			velocity *= exp(-1.2 * delta)
			if strike(Rect2(4, -12, 20, 14), 2, Vector2(160, -140)):
				_jaw = 0.0
				Audio.play_at("kick_hit", global_position, -2.0, 0.2)
				_go(S.RECOVER)
			elif _st > 0.6:
				_go(S.RECOVER)
		S.RECOVER:
			_jaw = move_toward(_jaw, 0.0, delta * 3.0)
			velocity = velocity.move_toward(Vector2(0, 30), 200.0 * delta)
			if _st > 1.6:
				_go(S.LURK)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _draw() -> void:
	begin_draw()
	if dead:
		draw_set_transform(Vector2(0, -6), PI, Vector2.ONE)
	var sway := sin(t * 2.0) * 1.5
	# Tail, body with a ridged back, head, jaws.
	poly(PackedVector2Array([Vector2(-13, -4), Vector2(-24, -3 + sway), Vector2(-13, -2)]), HIDE_D)
	poly(PackedVector2Array([Vector2(-13, -6), Vector2(6, -7), Vector2(8, -2), Vector2(-13, -1)]), HIDE)
	poly(PackedVector2Array([Vector2(-13, -2), Vector2(8, -2), Vector2(8, -1), Vector2(-13, -1)]), BELLY)
	for i in 5:
		var x := -11.0 + i * 4.0
		poly(PackedVector2Array([Vector2(x, -6.5), Vector2(x + 1.5, -8), Vector2(x + 3, -6.5)]), HIDE_D)
	var open := _jaw * 0.6
	# Upper jaw (hinged at the back of the head) and lower jaw.
	if not dead:
		draw_set_transform(Vector2(6 * facing, -5), -open * facing, Vector2.ONE)
	poly(PackedVector2Array([Vector2(0, -2), Vector2(13, -1), Vector2(13, 0), Vector2(0, 1)]), HIDE)
	pcircle(Vector2(2, -2), 1.2, Color("#c8b030"))
	pcircle(Vector2(2.3, -2), 0.5, Color("#101010"))
	if _jaw > 0.1:
		for k in 4:
			pline(Vector2(4 + k * 2.5, 0), Vector2(4 + k * 2.5, 1), Color("#f0f0e0"))
	if not dead:
		draw_set_transform(Vector2(6 * facing, -4), open * 0.6 * facing, Vector2.ONE)
	poly(PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(11, 1.5), Vector2(0, 2)]), HIDE_D)
	if _jaw > 0.1:
		poly(PackedVector2Array([Vector2(1, -0.5), Vector2(10, -0.5), Vector2(10, 0), Vector2(1, 0)]), MOUTH)
