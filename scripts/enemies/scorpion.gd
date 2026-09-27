class_name Scorpion
extends Enemy
## Canyon scorpion: patrols its ledge, raises its tail and stings when you're close.
## The whip flips it on its back (long stun). One bullet kills it.

enum S { PATROL, WINDUP, STING, RECOVER }

const CARAPACE := Color("#5a3420")
const CARAPACE_L := Color("#946034")
const LEG := Color("#2a1a10")
const STINGER := Color("#d8a040")

var state := S.PATROL
var _st := 0.0
var _flipped := 0.0


func _setup() -> void:
	size = Vector2(14, 7)
	hp = 1
	voice_die = "bug_die"
	loot = {"coins": [0, 1], "items": 0.15, "bandage": 0.05}


func _think(delta: float) -> void:
	_st += delta
	var d := to_hero()
	match state:
		S.PATROL:
			patrol(22.0, delta, 56.0)
			if hero_alive() and absf(d.y) < 20.0 and absf(d.x) < 26.0:
				facing = int(signf(d.x)) if d.x != 0.0 else facing
				_go(S.WINDUP)
				Audio.play_at("scorpion_hiss", global_position, -8.0, 0.1)
		S.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _st > 0.45:
				_go(S.STING)
		S.STING:
			strike(Rect2(4, -14, 16, 14))
			if _st > 0.18:
				_go(S.RECOVER)
		S.RECOVER:
			if _st > 0.6:
				_go(S.PATROL)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _on_pulled() -> void:
	_flipped = 2.4
	stun = 2.4
	state = S.PATROL


func _physics_process(delta: float) -> void:
	_flipped = maxf(0.0, _flipped - delta)
	super(delta)


func _hit_color() -> Color:
	return Color("#a8c060")


func blood_color() -> Color:
	return Gore.ICHOR


func _on_die() -> void:
	Gore.of(self).burst(global_position + Vector2(0, -4), 30, Vector2.UP, Gore.ICHOR, 6)


func _draw() -> void:
	begin_draw()
	var flip := _flipped > 0.0 and not dead
	if flip:
		draw_set_transform(Vector2(0, -7), PI, Vector2.ONE)
	var walk := t * 14.0 if absf(velocity.x) > 2.0 else 0.0
	# Legs: four pairs, alternating.
	for i in 4:
		var x := -4.0 + i * 3.0
		var ph := sin(walk + i * 1.6) * 1.5
		if flip:
			ph = sin(t * 30.0 + i) * 2.0
		elif dead:
			ph = sin(t * 18.0 + i) * 1.5 * maxf(0.0, 1.0 - _dead_t / 4.0)
		pline(Vector2(x, -3), Vector2(x - 2 + ph, 0), LEG)
	# Body segments.
	poly(PackedVector2Array([Vector2(-7, -3), Vector2(-4, -6), Vector2(3, -6), Vector2(6, -4), Vector2(6, -2), Vector2(-6, -1)]), CARAPACE)
	poly(PackedVector2Array([Vector2(-4, -6), Vector2(3, -6), Vector2(3, -5), Vector2(-4, -5)]), CARAPACE_L)
	# Pincers reach forward.
	var pinch := sin(t * 8.0) * 0.8
	poly(PackedVector2Array([Vector2(5, -4), Vector2(10, -6 - pinch), Vector2(12, -4), Vector2(9, -3)]), CARAPACE_L)
	poly(PackedVector2Array([Vector2(10, -6 - pinch), Vector2(13, -7), Vector2(12, -4)]), CARAPACE)
	# Tail: curls over the back; raises in windup, snaps forward on the sting.
	var curl := 0.0
	if state == S.WINDUP:
		curl = minf(1.0, _st / 0.45)
	elif state == S.STING:
		curl = -1.0
	var pts: Array[Vector2] = []
	var base := Vector2(-6, -3)
	var ang := -PI * 0.55 - curl * 0.4
	var p := base
	for i in 5:
		pts.append(p)
		p += Vector2(cos(ang), sin(ang)) * 2.6
		ang += 0.55 + curl * 0.15 + (0.6 if curl < 0 else 0.0)
	pts.append(p)
	for i in pts.size() - 1:
		pline(pts[i], pts[i + 1], CARAPACE if i % 2 else CARAPACE_L, 2.0)
	pcircle(pts[-1], 1.2, STINGER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
