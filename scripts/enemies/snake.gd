class_name Rattlesnake
extends Enemy
## Coiled rattlesnake. Rattles when you come near, then lunges. It doesn't chase;
## it guards its spot (usually a pit). The whip yanks it out, stunned and stretched out.

enum S { COILED, RATTLE, STRIKE, RECOVER }

const BODY := Color("#8a7a4a")
const BODY_D := Color("#5a4a2a")
const DIAMOND := Color("#3a2a18")
const BELLY := Color("#c8b888")

var state := S.COILED
var _st := 0.0
var _rattle_cd := 0.0
var _lunge := 0.0  # 0..1 head extension


func _setup() -> void:
	size = Vector2(14, 8)
	hp = 1
	voice_die = "bug_die"
	death_angle = 0.0


func _think(delta: float) -> void:
	_st += delta
	_rattle_cd -= delta
	var d := to_hero()
	var near := hero_alive() and absf(d.y) < 28.0
	match state:
		S.COILED:
			_lunge = move_toward(_lunge, 0.0, delta * 4.0)
			if near and absf(d.x) < 72.0:
				facing = int(signf(d.x)) if d.x != 0.0 else facing
				_go(S.RATTLE)
		S.RATTLE:
			if _rattle_cd <= 0.0:
				Audio.play_at("rattle", global_position, -6.0, 0.05)
				_rattle_cd = 0.45
			if near:
				facing = int(signf(d.x)) if d.x != 0.0 else facing
			if not near or absf(d.x) > 90.0:
				_go(S.COILED)
			elif absf(d.x) < 38.0 and _st > 0.35:
				_go(S.STRIKE)
				Audio.play_at("snake_hiss", global_position, -4.0, 0.1)
		S.STRIKE:
			_lunge = minf(1.0, _st / 0.12)
			strike(Rect2(0, -12, 12 + _lunge * 22.0, 12))
			if _st > 0.22:
				_go(S.RECOVER)
		S.RECOVER:
			_lunge = move_toward(_lunge, 0.0, delta * 3.0)
			if _st > 0.9:
				_go(S.RATTLE)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _on_pulled() -> void:
	state = S.RECOVER
	_st = -1.0
	_lunge = 0.0


func _on_die() -> void:
	Audio.play_at("snake_hiss", global_position, -2.0, 0.1)
	Gore.of(self).burst(global_position + Vector2(0, -3), 26, Vector2.UP, Gore.BLOOD, 5)


func _draw() -> void:
	begin_draw()
	if dead:
		# Cut in two: the halves slide apart and writhe, slowing down.
		var gap := minf(6.0, _dead_t * 30.0)
		var life := maxf(0.0, 1.0 - _dead_t / 5.0)
		for i in 9:
			var x := -12.0 + i * 3.0 + (gap if i >= 5 else -gap * 0.3)
			var y := -2.0 + sin(t * 14.0 + i) * 1.2 * life
			pcircle(Vector2(x, y), 2.0, BODY if i % 2 else BODY_D)
		pcircle(Vector2(14 + gap, -2), 2.4, BODY)
		pcircle(Vector2(3.0 - gap * 0.3, -2), 1.6, Gore.BLOOD)
		pcircle(Vector2(3.0 + gap, -2), 1.6, Gore.BLOOD)
		return
	if stun > 0.0:
		# Stretched out, limp, wriggling.
		for i in 9:
			var x := -12.0 + i * 3.0
			var y := -2.0 + sin(t * 12.0 + i) * (1.0 if stun > 0.0 else 0.0)
			pcircle(Vector2(x, y), 2.0, BODY if i % 2 else BODY_D)
		pcircle(Vector2(14, -2), 2.4, BODY)
		return
	# Coil: two stacked rings of body.
	for i in 10:
		var a := TAU * i / 10.0
		pcircle(Vector2(cos(a) * 5.0, -2.5 + sin(a) * 1.6), 2.2, BODY_D if i % 3 == 0 else BODY)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		pcircle(Vector2(cos(a) * 3.2 - 0.5, -5.0 + sin(a) * 1.2), 2.0, DIAMOND if i % 2 == 0 else BODY)
	# Rattle: shakes while rattling.
	var sh := sin(t * 60.0) * 1.0 if state == S.RATTLE else 0.0
	pcircle(Vector2(-6 + sh * 0.3, -8 + sh), 1.2, BELLY)
	pcircle(Vector2(-6.5 + sh * 0.3, -9.5 + sh), 1.0, BELLY)
	# Neck and head rise from the coil; lunge throws them forward.
	var rise := 1.0 if state == S.RATTLE or state == S.STRIKE else 0.6
	var head := Vector2(4 + _lunge * 22.0, -9.0 * rise - 2.0 + _lunge * 5.0)
	var neck := Vector2(2 + _lunge * 10.0, -6.0 * rise)
	pline(Vector2(1, -4), neck, BODY, 3.0)
	pline(neck, head, BODY, 2.6)
	poly(PackedVector2Array([head + Vector2(-1, -2), head + Vector2(3, -1.5), head + Vector2(4, 0), head + Vector2(-1, 1.5)]), BODY_D)
	pcircle(head + Vector2(1.5, -1), 0.5, Color("#f0e060"))
	if state == S.RATTLE and fmod(t, 0.3) < 0.15:
		pline(head + Vector2(4, 0), head + Vector2(6, 0.5), Color("#c02020"))
