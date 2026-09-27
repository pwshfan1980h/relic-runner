class_name AttackDog
extends Enemy
## Attack dog (hunts in packs): barks as it chases, leaps to bite. Low to the ground:
## crouch-punches and kicks work well. A whip crack sends it off yelping.

enum S { PATROL, CHASE, LEAP, RECOVER, FLEE }

const COAT := Color("#2a2220")
const COAT_L := Color("#3e3430")
const TAN := Color("#a86a3a")
const COLLAR := Color("#8a1a1a")

var state := S.PATROL
var _st := 0.0
var _bark := 0.0
var _bit := false


func _setup() -> void:
	size = Vector2(16, 9)
	hp = 2
	voice_die = "dog_yelp"
	voice_hurt = "dog_yelp"
	death_angle = 0.0
	# Packs shouldn't move in lockstep.
	t = randf() * 3.0


func _think(delta: float) -> void:
	_st += delta
	_bark -= delta
	var d := to_hero()
	match state:
		S.PATROL:
			patrol(40.0, delta, 70.0)
			if sees_hero(220.0, Vector2(0, -6)) and absf(d.y) < 50.0:
				_go(S.CHASE)
		S.CHASE:
			if not hero_alive() or absf(d.x) > 300.0:
				_go(S.PATROL)
				return
			if absf(d.x) > 2.0:
				facing = int(signf(d.x))
			velocity.x = move_toward(velocity.x, facing * 170.0 if can_walk(facing, 12.0) else 0.0, 700.0 * delta)
			if _bark <= 0.0:
				_bark = randf_range(0.6, 1.2)
				Audio.voice("dog_bark", global_position, -6.0)
			if is_on_floor() and absf(d.x) < 46.0 and absf(d.y) < 30.0:
				velocity = Vector2(facing * 200.0, -170.0)
				_bit = false
				_go(S.LEAP)
		S.LEAP:
			if not _bit:
				_bit = strike(Rect2(0, -12, 18, 12), 1, Vector2(120, -100))
				if _bit:
					Audio.play_at("hit_flesh", global_position, -2.0)
			if is_on_floor() and _st > 0.1:
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _st > 0.45:
				_go(S.CHASE)
		S.FLEE:
			velocity.x = move_toward(velocity.x, facing * 150.0 if can_walk(facing, 12.0) else 0.0, 700.0 * delta)
			if _st > 1.2:
				_go(S.CHASE)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _on_pulled() -> void:
	# The crack stings: it turns tail and runs.
	stun = 0.1
	var d := to_hero()
	facing = -int(signf(d.x)) if d.x != 0.0 else -facing
	velocity = Vector2(facing * 80.0, -60.0)
	Audio.voice("dog_yelp", global_position, 0.0)
	_go(S.FLEE)


func _on_hit() -> void:
	if state == S.PATROL:
		_go(S.CHASE)


func _on_die() -> void:
	var gore := Gore.of(self)
	gore.burst(death_at, 24, (death_dir + Vector2.UP).normalized())
	for i in 4:
		get_tree().create_timer(0.3 + i * 0.3).timeout.connect(func():
			if is_instance_valid(self):
				gore.stain_below(global_position + Vector2(randf_range(-6, 6), -2), 2.0 + i))


func _draw() -> void:
	if dead:
		_draw_dead()
		return
	begin_draw()
	var run := absf(velocity.x) > 5.0 and is_on_floor()
	var gait := t * 22.0 if run else 0.0
	var air := not is_on_floor()
	var by := -6.0
	for i in 4:
		var front := i >= 2
		var far := i % 2 == 0
		var x := 5.0 if front else -5.0
		var ph := sin(gait + (0.0 if far else PI) + (0.0 if front else PI * 0.5))
		var foot := Vector2(x + ph * 3.0, 0)
		if air:
			foot = Vector2(x + (6.0 if front else -6.0), by + 3.0)
		pline(Vector2(x, by + 1.0), foot, COAT if far else COAT_L, 1.5)
		pline(foot + Vector2(0, -1), foot, TAN, 1.5)
	# Deep chest, tucked waist.
	poly(PackedVector2Array([Vector2(-8, by - 2), Vector2(-2, by - 2.5), Vector2(6, by - 3), Vector2(8, by - 1),
			Vector2(6, by + 2.5), Vector2(-2, by + 1), Vector2(-7, by + 1)]), COAT)
	poly(PackedVector2Array([Vector2(3, by + 0.5), Vector2(7, by - 0.5), Vector2(6, by + 2.5), Vector2(3, by + 1.8)]), TAN)
	# Head, snout, cropped ears, collar.
	var hy := by - 4.0 + (sin(t * 22.0) * 0.5 if run else 0.0)
	poly(PackedVector2Array([Vector2(7, hy), Vector2(10, hy - 1), Vector2(14, hy + 1), Vector2(13, hy + 2.5), Vector2(8, hy + 3)]), COAT)
	poly(PackedVector2Array([Vector2(11, hy + 1.5), Vector2(14, hy + 1), Vector2(13, hy + 2.5), Vector2(11, hy + 2.5)]), TAN)
	poly(PackedVector2Array([Vector2(8, hy), Vector2(8.5, hy - 3), Vector2(9.5, hy - 0.5)]), COAT)
	pline(Vector2(7, hy + 1), Vector2(7.5, hy + 3.5), COLLAR, 1.5)
	pcircle(Vector2(11.5, hy + 0.5), 0.4, Color("#e0c040"))
	if state == S.CHASE and fmod(t, 0.5) < 0.25 or state == S.LEAP:
		pline(Vector2(12, hy + 3), Vector2(14, hy + 3.5), Color("#c02030"))
	# Docked tail, up.
	pline(Vector2(-8, by - 1.5), Vector2(-10, by - 4), COAT, 1.5)


func _draw_dead() -> void:
	var by := -2.5
	for i in 4:
		var x := -5.0 + i * 3.4
		pline(Vector2(x, by), Vector2(x + (4.0 if i >= 2 else -4.0), by - 0.5), COAT_L, 1.5)
	poly(PackedVector2Array([Vector2(-8, by - 2.5), Vector2(6, by - 3), Vector2(8, by), Vector2(-7, by + 0.5)]), COAT)
	poly(PackedVector2Array([Vector2(8, by - 2), Vector2(13, by - 1), Vector2(13, by + 0.5), Vector2(8, by + 0.5)]), COAT)
	poly(PackedVector2Array([Vector2(10, by - 0.8), Vector2(13, by - 0.6), Vector2(13, by + 0.5), Vector2(10, by + 0.5)]), TAN)
	pline(Vector2(7, by - 2), Vector2(7, by), COLLAR, 1.5)
