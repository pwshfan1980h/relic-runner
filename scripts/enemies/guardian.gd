class_name Guardian
extends Enemy
## Stone Idol Guardian (boss). Slow and armoured: bullets spark off it. When it raises
## its arms to slam, the glyph on its chest glows, and only then can it be hurt,
## by a shot to the glyph. The slam sends a shockwave along the floor.

signal defeated

enum S { WAKE, WALK, RAISE, SLAM, EXPOSED }

const STONE := Color("#6e6a5a")
const STONE_D := Color("#4a4638")
const STONE_L := Color("#8e8a74")
const MOSS := Color("#4f7a34")
const GLYPH := Color("#40e0c0")

var state := S.WAKE
var _st := 0.0
var _arms := 0.0  # 0 down .. 1 raised
var _glow := 0.0
var _wave_x := -1.0  # shockwave travel distance (px), < 0 = none
var _wave_hit := false
var _light: PointLight2D


func _setup() -> void:
	size = Vector2(22, 40)
	hp = 6
	pullable = false
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).shape.size = size
			(c as CollisionShape2D).position = Vector2(0, -size.y / 2.0)
	_light = PointLight2D.new()
	_light.texture = Lights.radial(128)
	_light.color = GLYPH
	_light.energy = 0.0
	_light.position = Vector2(0, -24)
	add_child(_light)


func vulnerable() -> bool:
	return state == S.RAISE and _st > 0.4 or state == S.EXPOSED


func _think(delta: float) -> void:
	_st += delta
	var d := to_hero()
	match state:
		S.WAKE:
			if sees_hero(260.0, Vector2(0, -30)):
				_go(S.WALK)
				Audio.play_at("stone_grind", global_position, 0.0)
				Fx.add_shake(0.3)
		S.WALK:
			if hero_alive() and absf(d.x) > 2.0:
				facing = int(signf(d.x))
			velocity.x = move_toward(velocity.x, facing * 16.0, 200.0 * delta)
			if hero_alive() and absf(d.x) < 60.0 and _st > 0.8:
				_go(S.RAISE)
				Audio.play_at("stone_grind", global_position, -4.0)
		S.RAISE:
			velocity.x = 0.0
			_arms = minf(1.0, _st / 0.9)
			if _st > 1.1:
				_go(S.SLAM)
				_arms = 0.0
				_wave_x = 0.0
				_wave_hit = false
				Fx.add_shake(0.7)
				Audio.play_at("slam", global_position, 2.0)
				Fx.puff(global_position + Vector2(facing * 14, 0), 10, Color("#8a8468"), Vector2.ZERO, 50.0)
		S.SLAM:
			if _st > 0.25:
				_go(S.EXPOSED)
		S.EXPOSED:
			if _st > 0.9:
				_go(S.WALK)
	# Shockwave rolls outward both ways along the floor.
	if _wave_x >= 0.0:
		_wave_x += 170.0 * delta
		if not _wave_hit and hero_alive() and hero.is_on_floor():
			var dx := absf(hero.global_position.x - global_position.x)
			var dy := absf(hero.global_position.y - global_position.y)
			if dy < 12.0 and absf(dx - _wave_x) < 10.0:
				_wave_hit = true
				hero.hurt(1, Vector2(signf(hero.global_position.x - global_position.x) * 140.0, -180.0))
		if _wave_x > 110.0:
			_wave_x = -1.0
	var want := 1.0 if vulnerable() else 0.0
	_glow = move_toward(_glow, want, delta * 5.0)
	_light.energy = _glow * 1.3


func _go(s: S) -> void:
	state = s
	_st = 0.0


func take_hit(dmg: int, dir: Vector2, at: Vector2) -> void:
	# Shots land on the edge of the collision box, so test the glyph's height band.
	var glyph_y := global_position.y - 24.0
	if vulnerable() and absf(at.y - glyph_y) < 6.0:
		Audio.play_at("glyph_hit", at, 0.0)
		super(dmg, dir, at)
	else:
		Fx.sparks(at, -dir, 5)
		Fx.chips(at, -dir, 3, STONE_L)
		Audio.play_at("ricochet", at, -4.0, 0.15)
		if state == S.WAKE:
			_go(S.WALK)


func _on_die() -> void:
	Fx.add_shake(1.0)
	Audio.play_at("stone_crumble", global_position, 2.0)
	for i in 6:
		Fx.chips(global_position + Vector2(randf_range(-10, 10), randf_range(-38, -4)), Vector2.UP, 6, STONE_L)
	_light.energy = 0.0
	defeated.emit()


func _hit_color() -> Color:
	return GLYPH


func _draw() -> void:
	if dead:
		# Crumbles: slabs slump down and fade (base class handles the fade).
		var sink := minf(1.0, _dead_t * 1.5)
		for i in 5:
			var y := -8.0 * i * (1.0 - sink) - 4.0
			poly(PackedVector2Array([Vector2(-10 + i, y - 6), Vector2(10 - i, y - 6), Vector2(11 - i, y), Vector2(-11 + i, y)]), STONE if i % 2 else STONE_D)
		return
	var step := sin(t * 4.0) * 1.0 if absf(velocity.x) > 2.0 else 0.0
	# Legs: stubby blocks.
	poly(PackedVector2Array([Vector2(-9, -12), Vector2(-2, -12), Vector2(-2 + step, 0), Vector2(-10 + step, 0)]), STONE_D)
	poly(PackedVector2Array([Vector2(2, -12), Vector2(9, -12), Vector2(10 - step, 0), Vector2(2 - step, 0)]), STONE)
	# Torso slab with carved bands and moss.
	poly(PackedVector2Array([Vector2(-11, -34), Vector2(11, -34), Vector2(10, -11), Vector2(-10, -11)]), STONE)
	poly(PackedVector2Array([Vector2(-11, -34), Vector2(-4, -34), Vector2(-4, -11), Vector2(-10, -11)]), STONE_D)
	poly(PackedVector2Array([Vector2(-10, -16), Vector2(10, -16), Vector2(10, -14), Vector2(-10, -14)]), STONE_D)
	poly(PackedVector2Array([Vector2(-11, -34), Vector2(-3, -34), Vector2(-6, -31), Vector2(-11, -30)]), MOSS)
	# Chest glyph: dull when armoured, blazing when exposed.
	var gc := STONE_D.lerp(GLYPH, _glow)
	poly(PackedVector2Array([Vector2(0, -29), Vector2(4, -24), Vector2(0, -19), Vector2(-4, -24)]), gc)
	if _glow > 0.5:
		poly(PackedVector2Array([Vector2(0, -27), Vector2(2, -24), Vector2(0, -21), Vector2(-2, -24)]), Color("#e8fff8"))
	# Head: flat-topped idol mask with slit eyes.
	poly(PackedVector2Array([Vector2(-8, -44), Vector2(8, -44), Vector2(9, -34), Vector2(-9, -34)]), STONE_L)
	poly(PackedVector2Array([Vector2(-10, -46), Vector2(10, -46), Vector2(10, -44), Vector2(-10, -44)]), STONE_D)
	var eye := GLYPH.lerp(Color("#ff6040"), 1.0 - _glow) if state != S.WAKE else STONE_D
	poly(PackedVector2Array([Vector2(1, -40), Vector2(6, -40), Vector2(6, -39), Vector2(1, -39)]), eye)
	poly(PackedVector2Array([Vector2(-6, -40), Vector2(-2, -40), Vector2(-2, -39), Vector2(-6, -39)]), eye)
	# Arms: hang at the sides, swing overhead during the raise.
	for side: float in [-1.0, 1.0]:
		var a := lerpf(0.15, -2.9, _arms) * side * -1.0
		var sh := Vector2(12.0 * side, -32)
		var hand := sh + Vector2(0, 16).rotated(a)
		pline(sh, hand, STONE_D if side < 0 else STONE, 5.0)
		poly(PackedVector2Array([hand + Vector2(-3, -2), hand + Vector2(3, -2), hand + Vector2(3, 3), hand + Vector2(-3, 3)]), STONE_L)
	# Shockwave: a travelling ridge of dust on both sides.
	if _wave_x >= 0.0:
		for sx: float in [-1.0, 1.0]:
			var x := sx * _wave_x * facing
			var h := 6.0 * (1.0 - _wave_x / 110.0)
			poly(PackedVector2Array([Vector2(x - 4, 0), Vector2(x, -h), Vector2(x + 4, 0)]), Color("#b8a878"))
