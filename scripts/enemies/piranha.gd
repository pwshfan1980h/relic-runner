class_name Piranha
extends Enemy
## Jungle river piranha. Mills about its home water; when you're in the same water and
## close, it darts at you, nips, and wheels away. Place a few together for a school.
## Pulled out by the whip, it flops on the bank until it suffocates. One hit kills it.

enum S { MILL, DART, RETREAT }

const BODY := Color("#7a8a8a")
const BODY_L := Color("#a8b8b4")
const BELLY := Color("#c8402a")
const FIN := Color("#4a5656")

var state := S.MILL
var _st := 0.0
var _phase := randf() * TAU


func _setup() -> void:
	size = Vector2(8, 5)
	hp = 1
	aquatic = true
	voice_die = ""
	loot = {"coins": [0, 1], "items": 0.05, "grenade": 0.0}
	z_index = 29


func _think(delta: float) -> void:
	_st += delta
	if water == null:
		return
	var d := to_hero()
	var hero_in := hero_alive() and hero.water == water
	match state:
		S.MILL:
			# Lazy loops around home.
			var goal := _home + Vector2(cos(t * 0.8 + _phase) * 20.0, -6.0 + sin(t * 1.3 + _phase) * 5.0)
			velocity = velocity.move_toward((goal - global_position) * 1.5, 120.0 * delta)
			if absf(velocity.x) > 4.0:
				facing = int(signf(velocity.x))
			if hero_in and d.length() < 100.0:
				_go(S.DART)
		S.DART:
			var target := hero.global_position + Vector2(0, -14)
			var to := target - global_position
			velocity = velocity.move_toward(to.normalized() * 115.0, 500.0 * delta)
			facing = int(signf(to.x)) if absf(to.x) > 1.0 else facing
			if to.length() < 9.0:
				strike(Rect2(-6, -8, 14, 10), 1, Vector2(40, -20))
				Audio.play_at("punch_hit", global_position, -10.0, 0.3)
				_go(S.RETREAT)
			elif not hero_in or _st > 3.0:
				_go(S.MILL)
		S.RETREAT:
			velocity = velocity.move_toward(Vector2(-facing * 90.0, -20.0), 400.0 * delta)
			if _st > 0.7:
				_go(S.DART if hero_in else S.MILL)
	# Keep under the surface.
	var surf := water.surface_y(global_position.x)
	if global_position.y < surf + 6.0:
		velocity.y = maxf(velocity.y, 30.0)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func blood_color() -> Color:
	return Gore.BLOOD


func _on_die() -> void:
	Gore.of(self).burst(global_position + Vector2(0, -3), 10, Vector2.UP)


func _draw() -> void:
	begin_draw()
	if dead:
		# Belly up.
		draw_set_transform(Vector2(0, -5), PI, Vector2.ONE)
	var wag := sin(t * (22.0 if state == S.DART else 9.0)) * 1.5
	poly(PackedVector2Array([Vector2(-4, -3), Vector2(-1, -5), Vector2(3, -5), Vector2(5, -3), Vector2(3, -1), Vector2(-1, -1)]), BODY)
	poly(PackedVector2Array([Vector2(-1, -5), Vector2(3, -5), Vector2(4, -4), Vector2(-2, -4)]), BODY_L)
	poly(PackedVector2Array([Vector2(-1, -2), Vector2(3, -2), Vector2(3, -1), Vector2(-1, -1)]), BELLY)
	poly(PackedVector2Array([Vector2(-4, -3), Vector2(-7, -5 + wag), Vector2(-7, -1 + wag)]), FIN)
	poly(PackedVector2Array([Vector2(0, -5), Vector2(2, -7), Vector2(2, -5)]), FIN)
	pline(Vector2(4, -2), Vector2(5, -2), Color("#f0f0e0"))
	pcircle(Vector2(3, -4), 0.6, Color("#101010"))
