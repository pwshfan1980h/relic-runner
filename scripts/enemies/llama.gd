class_name AttackLlama
extends Enemy
## Attack llama (canyon). At range it lobs spit in an arc (a hit smears green across
## your view). Up close it turns its back and rear-kicks, hard. Whipping it makes it
## furious: it charges. Four hits to bring down, and it screams on the way.

enum S { GRAZE, SPIT, KICK_TURN, KICK, CHARGE, RECOVER }

const WOOL := Color("#e8dcc0")
const WOOL_D := Color("#c0b090")
const PATCH := Color("#8a5a34")
const LEG := Color("#b8a888")
const FACE := Color("#d8ccb0")

var state := S.GRAZE
var _st := 0.0
var _cool := 0.0
var _kicked := false
var _kick_dir := 1


func _setup() -> void:
	size = Vector2(16, 26)
	hp = 4
	voice_die = "llama_scream"
	voice_hurt = "llama_scream"
	death_angle = 0.0
	knock_scale = 0.6


func _think(delta: float) -> void:
	_st += delta
	_cool -= delta
	var d := to_hero()
	var seen := sees_hero(200.0, Vector2(0, -22))
	match state:
		S.GRAZE:
			patrol(12.0, delta, 30.0)
			if seen and absf(d.y) < 60.0:
				_face(d)
				if absf(d.x) < 34.0:
					_go(S.KICK_TURN)
				elif _cool <= 0.0:
					_go(S.SPIT)
		S.SPIT:
			velocity.x = 0.0
			_face(d)
			if _st > 0.55:
				_spit()
				_cool = 1.6
				_go(S.RECOVER)
		S.KICK_TURN:
			# Turns its back on you: the tell.
			velocity.x = 0.0
			_kick_dir = int(signf(d.x)) if d.x != 0.0 else facing
			facing = -_kick_dir
			if _st > 0.35:
				_kicked = false
				_go(S.KICK)
				Audio.play_at("whoosh_kick", global_position, -2.0)
		S.KICK:
			if not _kicked:
				# Hind legs lash out behind (toward the hero).
				facing = _kick_dir
				_kicked = strike(Rect2(-4, -16, 26, 16), 1, Vector2(300, -190))
				facing = -_kick_dir
				if _kicked:
					Audio.play_at("kick_hit", hero.global_position, 0.0)
			if _st > 0.3:
				_go(S.RECOVER)
		S.CHARGE:
			_face(d)
			velocity.x = facing * 150.0 if can_walk(facing, 14.0) else 0.0
			if strike(Rect2(0, -20, 14, 20), 1, Vector2(220, -150)) or _st > 1.2 or velocity.x == 0.0:
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _st > 0.8:
				_go(S.GRAZE)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _face(d: Vector2) -> void:
	if d != Vector2.INF and absf(d.x) > 2.0:
		facing = int(signf(d.x))


func _spit() -> void:
	var mouth := global_position + Vector2(facing * 10.0, -24.0)
	var d := hero.global_position + Vector2(0, -18) - mouth
	# Lob: pick a flight time from distance, solve for the launch velocity.
	var ft := clampf(absf(d.x) / 160.0, 0.35, 1.1)
	var v := Vector2(d.x / ft, d.y / ft - 0.5 * Spit.GRAVITY * ft)
	var s := Spit.new()
	s.velocity = v
	s.position = mouth
	get_parent().add_child(s)
	Audio.voice("llama_spit", mouth, -2.0)


## Whipped: now it's personal.
func _on_pulled() -> void:
	stun = 0.2
	velocity = Vector2(0, -40)
	Audio.voice("llama_scream", global_position, -4.0)
	_go(S.CHARGE)


func _on_hit() -> void:
	if state == S.GRAZE:
		_go(S.SPIT if _cool <= 0.0 else S.RECOVER)


func _on_die() -> void:
	var gore := Gore.of(self)
	gore.burst(death_at, 34, (death_dir + Vector2.UP).normalized())
	for i in 6:
		get_tree().create_timer(0.3 + i * 0.3).timeout.connect(func():
			if is_instance_valid(self):
				gore.stain_below(global_position + Vector2(randf_range(-10, 10), -2), 2.0 + i))


func _draw() -> void:
	if dead:
		_draw_dead()
		return
	begin_draw()
	var walking := absf(velocity.x) > 3.0
	var gait := t * (16.0 if state == S.CHARGE else 8.0) if walking else 0.0
	var by := -14.0
	var kick := state == S.KICK and _st < 0.2
	# Legs: long and knobbly. In the kick, the hind pair lashes backward.
	for i in 4:
		var front := i >= 2
		var far := i % 2 == 0
		var x := 5.0 if front else -5.0
		var ph := sin(gait + (0.0 if far else PI) + (0.0 if front else PI * 0.5))
		var foot := Vector2(x + ph * 3.0, 0)
		if kick and not front:
			foot = Vector2(x - 12.0, by + 6.0)
		pline(Vector2(x, by + 3.0), Vector2((x + foot.x) * 0.5, by + 8.0), WOOL_D if far else WOOL, 2.0)
		pline(Vector2((x + foot.x) * 0.5, by + 8.0), foot, LEG, 1.5)
	# Woolly barrel body with a patch.
	poly(PackedVector2Array([Vector2(-9, by - 2), Vector2(-4, by - 5), Vector2(5, by - 5), Vector2(9, by - 2),
			Vector2(8, by + 4), Vector2(-8, by + 4)]), WOOL)
	poly(PackedVector2Array([Vector2(-6, by - 4), Vector2(0, by - 4.5), Vector2(-1, by + 1), Vector2(-6, by + 2)]), PATCH)
	pline(Vector2(-9, by - 2), Vector2(-11, by), WOOL_D, 2.0)
	# Tall neck; head tips back to wind up a spit.
	var back := minf(1.0, _st / 0.4) if state == S.SPIT else 0.0
	var graze := 1.0 if state == S.GRAZE and not walking and fmod(t, 6.0) < 2.5 else 0.0
	var neck_top := Vector2(8.0 - back * 3.0, by - 13.0 + graze * 11.0)
	pline(Vector2(6, by - 3), neck_top, WOOL, 3.5)
	var h := neck_top
	poly(PackedVector2Array([h + Vector2(-2, -2), h + Vector2(3, -2), h + Vector2(5, 0), h + Vector2(4, 2), h + Vector2(-1, 2)]), FACE)
	# Banana ears, laid back when angry.
	var angry := state in [S.CHARGE, S.KICK_TURN, S.KICK, S.SPIT]
	var ear := Vector2(-2.0, -3.0) if angry else Vector2(0.5, -4.0)
	pline(h + Vector2(-1, -2), h + Vector2(-1, -2) + ear, WOOL_D, 1.2)
	pline(h + Vector2(1, -2), h + Vector2(1, -2) + ear, WOOL, 1.2)
	pcircle(h + Vector2(1.5, -0.5), 0.5, Color("#1a1410"))
	if state == S.SPIT and back > 0.6:
		pcircle(h + Vector2(4.5, 1), 1.2, Color("#9ab830"))  # cheeks full


func _draw_dead() -> void:
	var by := -4.0
	for i in 4:
		var x := -6.0 + i * 4.0
		pline(Vector2(x, by), Vector2(x + (7.0 if i >= 2 else -7.0), by - 1.0), LEG, 1.5)
	poly(PackedVector2Array([Vector2(-9, by - 4), Vector2(8, by - 4.5), Vector2(10, by), Vector2(-9, by + 1)]), WOOL)
	poly(PackedVector2Array([Vector2(-6, by - 3.5), Vector2(0, by - 4), Vector2(-1, by), Vector2(-6, by + 0.5)]), PATCH)
	pline(Vector2(8, by - 2), Vector2(18, by - 1), WOOL, 3.0)
	poly(PackedVector2Array([Vector2(18, by - 3), Vector2(23, by - 2), Vector2(23, by + 0.5), Vector2(18, by + 0.5)]), FACE)
	pline(Vector2(20, by - 1.5), Vector2(21, by - 1.5), Color("#1a1410"))


## A gob of spit on a ballistic arc. Hits the hero (1 damage, a green smear on screen)
## or splats on rock.
class Spit:
	extends Node2D
	const GRAVITY := 500.0
	var velocity := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		z_index = 8

	func _physics_process(delta: float) -> void:
		_t += delta
		velocity.y += GRAVITY * delta
		var next := global_position + velocity * delta
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, next, 1 | 2)
		var hit := space.intersect_ray(q)
		if hit:
			if hit.collider is Hero:
				(hit.collider as Hero).hurt(1, Vector2(signf(velocity.x) * 60.0, -40.0))
				var hud := get_tree().get_first_node_in_group("hud")
				if hud:
					hud.smear()
			Gore.of(self).burst(hit.position, 10, hit.normal, Gore.ICHOR, 1)
			Audio.play_at("splat", hit.position, -6.0, 0.2)
			queue_free()
			return
		global_position = next
		queue_redraw()
		if _t > 3.0:
			queue_free()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 1.6, Color("#b8d050"))
		draw_circle(-velocity.normalized() * 2.0, 1.0, Color(0.72, 0.82, 0.3, 0.6))
