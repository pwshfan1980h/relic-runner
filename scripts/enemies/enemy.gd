class_name Enemy
extends CharacterBody2D
## Shared enemy behaviour: gravity, hit points, hit flash, whip-pull stun, death
## tumble, contact damage and line-of-sight. Subclasses implement _think() and draw
## themselves in _draw() in facing-right local space (flipped by `facing`).

const GRAVITY := 900.0

@export var hp := 1
var facing := -1
var hero: Hero
var size := Vector2(12, 10)
var pullable := true
var stun := 0.0
var dead := false
var t := 0.0
var _flash := 0.0
var _dead_t := 0.0
var _home := Vector2.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 4.0
	add_to_group("enemy")
	add_to_group("whippable")
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	s.shape = r
	s.position = Vector2(0, -size.y / 2.0)
	add_child(s)
	z_index = 4
	_home = global_position
	hero = get_tree().get_first_node_in_group("hero") as Hero
	_setup()


func _setup() -> void:
	pass


func _think(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	t += delta
	_flash = maxf(0.0, _flash - delta)
	if not is_on_floor():
		velocity.y = minf(500.0, velocity.y + GRAVITY * delta)
	if dead:
		# Corpses stay a while (the gore is the point), then fade.
		_dead_t += delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		modulate.a = clampf(26.0 - _dead_t, 0.0, 1.0)
		if _dead_t > 26.0:
			queue_free()
		queue_redraw()
		return
	if stun > 0.0:
		stun -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		_think(delta)
	move_and_slide()
	if global_position.y > 4000.0:
		queue_free()
	queue_redraw()


# --- Reactions --------------------------------------------------------------------

## kind: "bullet", "punch", "kick", "whip", "spikes". Humans override headshots etc.
func take_hit(dmg: int, dir: Vector2, at: Vector2, kind := "bullet") -> void:
	if dead:
		return
	hp -= dmg
	_flash = 0.12
	match kind:
		"kick":
			# Kicks launch: off ledges, into spikes.
			velocity = Vector2(dir.x * 260.0 * knock_scale, -140.0 * knock_scale)
			stun = maxf(stun, 0.6)
		"punch":
			velocity.x += dir.x * 120.0 * knock_scale
			stun = maxf(stun, 0.25)
		_:
			velocity.x += dir.x * 50.0 * knock_scale
	bleed(at, dir, 10)
	Audio.play_at("hit_flesh", at, -4.0, 0.15)
	_on_hit()
	if hp <= 0:
		die(kind, dir, at)
	elif randf() < 0.5 and voice_hurt != "":
		Audio.voice(voice_hurt, global_position, -6.0)


## Blood (or ichor) from a wound, carrying onto the wall behind.
func bleed(at: Vector2, dir: Vector2, amount := 10) -> void:
	var col := blood_color()
	var gore := Gore.of(self)
	gore.burst(at, amount, (dir + Vector2(0, -0.4)).normalized(), col, 2)
	gore.wall_splat(at, dir, col)
	if not Gore.enabled():
		Fx.chips(at, -dir, 4, _hit_color())


func blood_color() -> Color:
	return Gore.BLOOD


func _hit_color() -> Color:
	return Color("#e0c090")


func _on_hit() -> void:
	pass


## The whip wraps around us: fly toward the hero and land stunned.
func whip_pull(to: Vector2) -> void:
	if dead:
		return
	if not pullable:
		_resist_whip()
		return
	var d := to - global_position
	velocity = Vector2(clampf(d.x * 2.6, -240.0, 240.0), -150.0)
	stun = 1.6
	_flash = 0.1
	_on_pulled()


func _resist_whip() -> void:
	Fx.sparks(global_position + Vector2(0, -size.y / 2), Vector2.UP, 4)
	Audio.play_at("ricochet", global_position, -8.0)


func _on_pulled() -> void:
	pass


var death_kind := "bullet"
var death_dir := Vector2.ZERO
var death_at := Vector2.ZERO
var voice_die := "human_die"
var voice_hurt := ""
var death_angle := PI  # how far the body tips over when it dies (drawn enemies)
var knock_scale := 1.0  # heavy enemies shrug off knockback


func die(kind := "bullet", dir := Vector2.ZERO, at := Vector2.INF) -> void:
	if dead:
		return
	dead = true
	stun = 0.0
	death_kind = kind
	death_dir = dir
	death_at = global_position + Vector2(0, -size.y / 2.0) if at == Vector2.INF else at
	collision_layer = 0
	remove_from_group("whippable")
	remove_from_group("enemy")
	add_to_group("corpse")
	velocity += Vector2(dir.x * 60.0, -80.0)
	if voice_die != "":
		Audio.voice(voice_die, global_position, 0.0)
	Fx.hitstop(0.05)
	Fx.add_shake(0.15)
	died.emit(self)
	_on_die()


signal died(enemy: Enemy)


func _on_die() -> void:
	pass


## Humans (rig-based enemies) die as ragdolls; the killing blow decides what tears.
func ragdoll_death(rig: HeroRig) -> void:
	var near := hero != null and hero.global_position.distance_to(global_position) < 48.0
	var push := death_dir * (120.0 if death_kind in ["bullet", "headshot"] else 260.0)
	if near:
		push *= 1.6
	var tear: Array = []
	if Gore.enabled():
		if death_kind == "headshot" and (near or randf() < 0.45):
			tear.append("head")
			Gore.of(self).burst(death_at, 40, death_dir)
		if death_kind == "kick" and randf() < 0.5 or near and randf() < 0.4:
			tear.append(["ua_f", "ua_b", "th_f", "th_b"].pick_random())
		if death_kind == "spikes":
			tear.append_array(["th_f", "th_b"].slice(0, 1 + randi() % 2))
	Ragdoll.from_rig(rig, get_parent(), velocity, push, death_at, tear)
	queue_free()


# --- Helpers ----------------------------------------------------------------------

func to_hero() -> Vector2:
	if hero == null:
		return Vector2.INF
	return hero.global_position - global_position


func hero_alive() -> bool:
	return hero != null and hero.state != Hero.S.DEAD


## Clear line of sight (rock only) from our eye to the hero's chest.
func sees_hero(max_dist: float, eye := Vector2(0, -8)) -> bool:
	if not hero_alive():
		return false
	var from := global_position + eye
	var to := hero.global_position + Vector2(0, -18)
	if from.distance_to(to) > max_dist:
		return false
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Hurts the hero if they're inside `rect` (relative to us, facing-flipped).
func strike(rect: Rect2, dmg := 1, push := Vector2(120, -120)) -> bool:
	if not hero_alive():
		return false
	var r := rect
	if facing < 0:
		r.position.x = -r.position.x - r.size.x
	r.position += global_position
	var hero_box := Rect2(hero.global_position + Vector2(-4, -28), Vector2(8, 28))
	if r.intersects(hero_box):
		hero.hurt(dmg, Vector2(push.x * facing, push.y))
		return true
	return false


## True if there's floor ahead and no wall: used to patrol ledges without falling off.
func can_walk(dir: int, ahead := 8.0) -> bool:
	var space := get_world_2d().direct_space_state
	var p := global_position
	var wall := PhysicsRayQueryParameters2D.create(p + Vector2(0, -4), p + Vector2(dir * (size.x / 2 + 3), -4), 1)
	if not space.intersect_ray(wall).is_empty():
		return false
	var floor_q := PhysicsRayQueryParameters2D.create(p + Vector2(dir * ahead, -2), p + Vector2(dir * ahead, 10), 1)
	return not space.intersect_ray(floor_q).is_empty()


func patrol(speed: float, delta: float, radius := 64.0) -> void:
	if not is_on_floor():
		return
	var off := global_position.x - _home.x
	if not can_walk(facing) or (off * facing > radius):
		facing = -facing
	velocity.x = move_toward(velocity.x, facing * speed, 400.0 * delta)


## Draw helpers: polygons in facing-right local space.
func poly(pts: PackedVector2Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * facing, p.y))
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	draw_colored_polygon(out, col)


func pline(a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	draw_line(Vector2(a.x * facing, a.y), Vector2(b.x * facing, b.y), col, w)


func pcircle(c: Vector2, r: float, col: Color) -> void:
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	draw_circle(Vector2(c.x * facing, c.y), r, col)


## Death tumble: rotate the drawing onto its back.
func begin_draw() -> void:
	if dead:
		# Rotate about the body centre, then settle onto the ground upside down.
		var a := minf(1.0, _dead_t * 4.0) * death_angle * facing
		var c := Vector2(0, -size.y / 2.0)
		draw_set_transform(c - c.rotated(a), a, Vector2.ONE)
