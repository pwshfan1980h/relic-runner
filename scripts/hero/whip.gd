class_name Whip
extends Node2D
## The bullwhip: target picking (anchors / whippable actors / nothing), the throw,
## and a verlet rope that hangs between the hand and the tip. Drawn in world space.
## The swing physics itself lives in Hero; this node owns the look and the targeting.

signal latched(kind: int, target: Variant)  # kind: Kind.ANCHOR / Kind.ACTOR
signal cracked(at: Vector2)

enum Kind { NONE, ANCHOR, ACTOR, CRACK }
enum S { IDLE, THROW, HELD, PULL, RETRACT }

const RANGE := 200.0
var reach := RANGE  # grows with the Long Whip upgrade
const THROW_SPEED := 1500.0
const SEGMENTS := 16
const ASSIST_DEG := 16.0
const COLOR := Color("#3b2616")
const COLOR_L := Color("#6a4526")

var state := S.IDLE
var kind := Kind.NONE
var target: Variant = null  # anchor Node2D, actor Node2D, or crack point (Vector2)
var tip := Vector2.ZERO
var hand := Vector2.ZERO
var _throw_from := Vector2.ZERO
var _throw_to := Vector2.ZERO
var _throw_t := 0.0
var _throw_len := 0.1
var _retract_t := 0.0
var _pts: PackedVector2Array = []
var _prev: PackedVector2Array = []
var hero: CharacterBody2D


func _ready() -> void:
	reach = RANGE * (1.0 + 0.25 * GameState.up("whip"))
	top_level = true
	z_index = 9
	global_position = Vector2.ZERO


func active() -> bool:
	return state != S.IDLE


## A new throw may interrupt a retracting whip, so quick re-grabs never drop clicks.
func can_throw() -> bool:
	return state == S.IDLE or state == S.RETRACT


## Best target for a throw from `from` toward `aim`. Returns [kind, target, point].
func pick(from: Vector2, aim: Vector2) -> Array:
	var dir := (aim - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * reach, 1 | 4)
	if hero:
		q.exclude = [hero.get_rid()]
	var hit := space.intersect_ray(q)
	var ray_end: Vector2 = hit.position if hit else from + dir * reach
	if hit and hit.collider.is_in_group("whippable"):
		return [Kind.ACTOR, hit.collider, hit.position]
	# Aim assist: the anchor closest to the aim line inside a cone, with line of sight.
	var best: Node2D = null
	var best_score := INF
	for a in get_tree().get_nodes_in_group("whip_anchor"):
		var to: Vector2 = a.global_position - from
		var d := to.length()
		if d > reach or d < 12.0:
			continue
		var ang := absf(rad_to_deg(dir.angle_to(to)))
		# Near the cursor counts as aimed, however wide the angle.
		var near_cursor: bool = aim.distance_to(a.global_position) < 20.0
		if ang > ASSIST_DEG and not near_cursor:
			continue
		var los := PhysicsRayQueryParameters2D.create(from, a.global_position - to.normalized() * 3.0, 1)
		if space.intersect_ray(los):
			continue
		var score := ang + d * 0.02 - (30.0 if near_cursor else 0.0)
		if score < best_score:
			best_score = score
			best = a
	if best:
		return [Kind.ANCHOR, best, best.global_position]
	return [Kind.CRACK, null, ray_end]


func throw(from: Vector2, aim: Vector2) -> void:
	var p := pick(from, aim)
	kind = p[0]
	target = p[1] if kind != Kind.CRACK else p[2]
	_throw_from = from
	_throw_to = p[2]
	_throw_t = 0.0
	_throw_len = maxf(0.05, from.distance_to(_throw_to) / THROW_SPEED)
	state = S.THROW
	hand = from
	tip = from
	_reset_rope(from, from)
	Audio.play("whip_throw", -4.0, 1.0, 0.1)


func release() -> void:
	if state == S.HELD or state == S.PULL or state == S.THROW:
		state = S.RETRACT
		_retract_t = 0.0


func _reset_rope(a: Vector2, b: Vector2) -> void:
	_pts.resize(SEGMENTS)
	_prev.resize(SEGMENTS)
	for i in SEGMENTS:
		_pts[i] = a.lerp(b, float(i) / (SEGMENTS - 1))
		_prev[i] = _pts[i]


func target_point() -> Vector2:
	if target is Vector2:
		return target
	# Check validity first: a whipped enemy can be freed (turned ragdoll) mid-pull.
	if is_instance_valid(target) and target is Node2D:
		return (target as Node2D).global_position
	return tip


## Called by Hero every physics tick with the current hand position.
func step(delta: float, hand_pos: Vector2) -> void:
	hand = hand_pos
	match state:
		S.IDLE:
			return
		S.THROW:
			_throw_t += delta
			var u := minf(1.0, _throw_t / _throw_len)
			# The tip leads in a slight arc (whips roll out, they don't fly straight).
			var arc := sin(u * PI) * 10.0
			var line := _throw_to - _throw_from
			tip = _throw_from.lerp(_throw_to, u) + line.orthogonal().normalized() * arc * (1.0 if line.x > 0 else -1.0)
			if kind == Kind.ANCHOR or kind == Kind.ACTOR:
				_throw_to = target_point()
			if u >= 1.0:
				tip = _throw_to
				match kind:
					Kind.ANCHOR:
						state = S.HELD
						Audio.play("whip_latch", -2.0, 1.0, 0.1)
						latched.emit(kind, target)
					Kind.ACTOR:
						state = S.PULL
						_retract_t = 0.0
						Audio.play("whip_crack", -2.0, 1.1, 0.1)
						latched.emit(kind, target)
					_:
						Audio.play("whip_crack", 0.0, 1.0, 0.12)
						Fx.sparks(tip, (tip - hand).normalized(), 4, Color("#fff4c8"))
						cracked.emit(tip)
						state = S.RETRACT
						_retract_t = 0.0
		S.HELD:
			tip = target_point()
		S.PULL:
			tip = target_point()
			_retract_t += delta
			if _retract_t > 0.3:
				state = S.RETRACT
				_retract_t = 0.0
		S.RETRACT:
			_retract_t += delta
			tip = tip.lerp(hand, minf(1.0, delta * 18.0))
			if _retract_t > 0.14 or tip.distance_to(hand) < 3.0:
				state = S.IDLE
				kind = Kind.NONE
				target = null
	_simulate(delta)
	queue_redraw()


func _simulate(delta: float) -> void:
	if _pts.size() != SEGMENTS:
		_reset_rope(hand, tip)
	var span := hand.distance_to(tip)
	# Held ropes hang a little slack; flying ropes are nearly taut.
	var slack := 1.04 if state == S.HELD else 1.0
	var seg := span * slack / (SEGMENTS - 1)
	var g := Vector2(0, 500.0 if state == S.HELD or state == S.RETRACT else 150.0) * delta * delta
	for i in range(1, SEGMENTS - 1):
		var p := _pts[i]
		var v := (p - _prev[i]) * 0.97
		_prev[i] = p
		_pts[i] = p + v + g
	for _k in 6:
		_pts[0] = hand
		_pts[SEGMENTS - 1] = tip
		for i in SEGMENTS - 1:
			var a := _pts[i]
			var b := _pts[i + 1]
			var d := b - a
			var l := d.length()
			if l < 0.0001:
				continue
			var diff := (l - seg) / l * 0.5
			if i > 0:
				_pts[i] = a + d * diff
			if i + 1 < SEGMENTS - 1:
				_pts[i + 1] = b - d * diff
	_pts[0] = hand
	_pts[SEGMENTS - 1] = tip


func _draw() -> void:
	if state == S.IDLE or _pts.size() < 2:
		return
	draw_polyline(_pts, COLOR, 1.0)
	# A lighter glint every few segments reads as braided leather.
	for i in range(1, SEGMENTS - 1, 3):
		draw_rect(Rect2(_pts[i].round(), Vector2.ONE), COLOR_L)
	if kind == Kind.CRACK and state == S.RETRACT and _retract_t < 0.05:
		draw_circle(tip, 2.0, Color("#fff4c8"))
