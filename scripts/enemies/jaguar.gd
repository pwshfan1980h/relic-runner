class_name Jaguar
extends Enemy
## Jungle jaguar: prowls, crouches (tail twitching) when it sees you, then pounces.
## Three bullets to bring down. A whip crack on it scares it off for a moment.

enum S { PROWL, CROUCH, POUNCE, RECOVER, FLEE }

const FUR := Color("#c8902e")
const FUR_D := Color("#8a5a1c")
const SPOT := Color("#3a2410")
const BELLY := Color("#e8c890")

var state := S.PROWL
var _st := 0.0
var _hit_this_pounce := false


func _setup() -> void:
	size = Vector2(22, 11)
	hp = 3


func _think(delta: float) -> void:
	_st += delta
	var d := to_hero()
	match state:
		S.PROWL:
			patrol(34.0, delta, 90.0)
			if sees_hero(150.0, Vector2(0, -8)) and absf(d.y) < 48.0:
				facing = int(signf(d.x)) if d.x != 0.0 else facing
				_go(S.CROUCH)
				Audio.play_at("jaguar_growl", global_position, -2.0, 0.1)
		S.CROUCH:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if d != Vector2.INF and absf(d.x) > 2.0:
				facing = int(signf(d.x))
			if _st > 0.55:
				var dist := clampf(absf(d.x), 40.0, 150.0)
				velocity = Vector2(facing * dist * 1.55, -230.0)
				_hit_this_pounce = false
				_go(S.POUNCE)
				Audio.play_at("jaguar_roar", global_position, 0.0, 0.1)
		S.POUNCE:
			if not _hit_this_pounce:
				_hit_this_pounce = strike(Rect2(-4, -14, 22, 14), 1, Vector2(160, -140))
			if is_on_floor() and _st > 0.1:
				_go(S.RECOVER)
				Fx.puff(global_position, 4, Color("#6a8a4a"))
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _st > 0.8:
				_go(S.PROWL)
		S.FLEE:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, facing * 110.0, 600.0 * delta)
				if not can_walk(facing, 12.0):
					velocity.x = 0.0
			if _st > 1.6:
				_go(S.PROWL)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _on_pulled() -> void:
	# Too heavy to haul in: a crack across the nose sends it running instead.
	stun = 0.15
	velocity = Vector2(0, -60)
	var d := to_hero()
	facing = -int(signf(d.x)) if d.x != 0.0 else -facing
	_go(S.FLEE)
	Audio.play_at("jaguar_growl", global_position, 0.0, 0.1)


func _on_hit() -> void:
	if state == S.PROWL:
		var d := to_hero()
		facing = int(signf(d.x)) if d.x != 0.0 else facing
		_go(S.CROUCH)


func _hit_color() -> Color:
	return Color("#e0b060")


func _draw() -> void:
	begin_draw()
	var moving := absf(velocity.x) > 5.0 and is_on_floor()
	var gait := t * (18.0 if absf(velocity.x) > 60.0 else 10.0) if moving else 0.0
	var crouch := 0.0
	if state == S.CROUCH:
		crouch = minf(1.0, _st / 0.3) * 3.0
	var air := state == S.POUNCE and not is_on_floor()
	var by := -7.0 + crouch
	# Legs: far pair darker, drawn first. In the air they stretch fore and aft.
	for i in 4:
		var front := i >= 2
		var far := i % 2 == 0
		var x := 6.0 if front else -6.0
		var ph := sin(gait + (0.0 if far else PI) + (0.0 if front else PI * 0.5))
		var foot := Vector2(x + ph * 3.0, 0)
		if air:
			foot = Vector2(x + (7.0 if front else -7.0), by + 3.0)
		pline(Vector2(x, by + 1.0), foot, FUR_D if far else FUR, 2.0)
	# Body.
	poly(PackedVector2Array([Vector2(-10, by - 2), Vector2(-4, by - 4), Vector2(6, by - 4), Vector2(10, by - 2),
			Vector2(9, by + 2), Vector2(-9, by + 2)]), FUR)
	poly(PackedVector2Array([Vector2(-8, by + 1), Vector2(8, by + 1), Vector2(7, by + 2.5), Vector2(-7, by + 2.5)]), BELLY)
	for sx: float in [-6.0, -2.0, 2.0, 5.0]:
		pcircle(Vector2(sx, by - 2.0 + fmod(sx, 2.0)), 0.8, SPOT)
	# Head, ears, eye.
	var hy := by - 3.0 + crouch * 0.5
	poly(PackedVector2Array([Vector2(9, hy - 1), Vector2(13, hy - 2), Vector2(15, hy + 1), Vector2(13, hy + 3), Vector2(9, hy + 2)]), FUR)
	poly(PackedVector2Array([Vector2(10, hy - 1), Vector2(10.5, hy - 3), Vector2(11.5, hy - 1.5)]), FUR_D)
	pcircle(Vector2(13, hy), 0.5, Color("#f0e040"))
	# Tail: long, curving; twitches in the crouch.
	var twitch := sin(t * 20.0) * 2.0 if state == S.CROUCH else sin(t * 3.0)
	var p := Vector2(-10, by - 1)
	for i in 5:
		var q := p + Vector2(-2.6, -0.5 + i * 0.4 + twitch * 0.3)
		pline(p, q, FUR if i < 4 else SPOT, 1.5)
		p = q
