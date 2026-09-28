class_name Grenade
extends RigidBody2D
## A stick-less "pineapple" grenade: a real rigid body that bounces off rock, rolls down
## slopes and knocks into crates. The fuse is lit on the throw. The blast hurts anything
## with line of sight inside RADIUS (the hero too), and shoves every loose physics body.
## Grenade.predict() runs the same integration the physics engine uses, so the aiming
## arc the hero sees is where the grenade will actually go (until its first bounce).

const FUSE := 2.2
const RADIUS := 60.0
const R := 2.5
const GRAVITY := 900.0
const TAP_SPEED := 235.0
const MAX_SPEED := 400.0
const LAYER := 32

var fuse := FUSE
var thrower: Node2D
var _t := 0.0
var _bonk := 0.0
var _done := false


static func make(at: Vector2, vel: Vector2, by: Node2D) -> Grenade:
	var g := Grenade.new()
	g.position = at
	g.linear_velocity = vel
	g.angular_velocity = signf(vel.x) * 14.0
	g.thrower = by
	return g


func _ready() -> void:
	add_to_group("grenade")
	collision_layer = LAYER
	collision_mask = 1 | 4 | LAYER
	mass = 0.4
	gravity_scale = 1.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 1.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 2
	z_index = 6
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.42
	mat.friction = 0.7
	physics_material_override = mat
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = R
	s.shape = c
	add_child(s)
	body_entered.connect(_on_body_entered)


func _on_body_entered(_b: Node) -> void:
	var speed := linear_velocity.length()
	if speed > 40.0 and _t - _bonk > 0.08:
		_bonk = _t
		Audio.play_at("grenade_bounce", global_position, lerpf(-14.0, -4.0, clampf(speed / 300.0, 0.0, 1.0)), 0.15)


func _physics_process(delta: float) -> void:
	_t += delta
	fuse -= delta
	# Rolling resistance: grit and dirt stop a grenade within a few body lengths.
	if get_contact_count() > 0:
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, 260.0 * delta)
		angular_velocity = move_toward(angular_velocity, 0.0, 60.0 * delta)
	# Ticks speed up as the fuse burns down.
	var rate := 0.5 if fuse > 1.0 else 0.2
	if fmod(fuse, rate) < delta:
		Audio.play_at("gate_tick", global_position, -14.0, 0.05)
	if fuse <= 0.0 and not _done:
		explode()
	queue_redraw()


func explode() -> void:
	_done = true
	var at := global_position
	Grenade.blast(self, at, RADIUS)
	queue_free()


## The blast, usable by anything that goes bang.
static func blast(from: Node, at: Vector2, radius: float) -> void:
	var tree := from.get_tree()
	var space := (from as Node2D).get_world_2d().direct_space_state
	Audio.play_at("explosion", at, 2.0, 0.08)
	Fx.add_shake(0.75)
	Fx.hitstop(0.05)
	Fx.explosion(at, radius)
	var level := tree.current_scene
	var light := PointLight2D.new()
	light.texture = Lights.radial(256)
	light.color = Color("#ffb050")
	light.energy = 2.4
	light.texture_scale = 1.6
	light.shadow_enabled = true
	light.global_position = at + Vector2(0, -6)
	level.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "energy", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)
	Gore.of(level).scorch(at, radius * 0.3)

	# Living things: damage falls off with distance; rock blocks the blast.
	var victims: Array = tree.get_nodes_in_group("enemy")
	var hero := tree.get_first_node_in_group("hero") as Hero
	if hero:
		victims.append(hero)
	for v: Node2D in victims:
		var centre := v.global_position + Vector2(0, -12)
		var d := centre.distance_to(at)
		if d > radius:
			continue
		var los := PhysicsRayQueryParameters2D.create(at + Vector2(0, -3), centre, 1)
		if space.intersect_ray(los):
			continue
		var dir := (centre - at).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var k := 1.0 - d / radius
		if v is Hero:
			(v as Hero).hurt(2 if k > 0.55 else 1, Vector2(dir.x * 220.0 * k + dir.x * 60.0, -200.0 * k - 60.0))
		elif v.has_method("take_hit"):
			var dmg := 4 if k > 0.6 else (2 if k > 0.3 else 1)
			v.take_hit(dmg, dir, centre - dir * 4.0, "explosion")

	# Props: cracked walls, kickable trees (their edge counts, so big ones still go).
	for b: Node2D in tree.get_nodes_in_group("blastable"):
		var p: Vector2 = b.blast_point(at)
		if p.distance_to(at) < radius * 0.8:
			b.take_hit(3, (p - at).normalized(), p, "explosion")

	# Loose physics bodies: crates, ragdoll parts, other grenades.
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 1.3
	params.shape = circle
	params.transform = Transform2D(0.0, at)
	params.collision_mask = 4 | 16 | LAYER
	var pushed := {}
	for hit in space.intersect_shape(params, 64):
		var b := hit.collider as RigidBody2D
		if b == null or b == from or pushed.has(b):
			continue
		pushed[b] = true
		var off := b.global_position - at
		var k := clampf(1.0 - off.length() / (radius * 1.3), 0.0, 1.0)
		var dir := (off + Vector2(0, -6)).normalized()
		b.apply_central_impulse(dir * 520.0 * k * b.mass)
		b.angular_velocity += randf_range(-25, 25) * k
		if b is Grenade and k > 0.2:
			# Sympathetic detonation, a beat later.
			(b as Grenade).fuse = minf((b as Grenade).fuse, 0.12)
	# Crumbling floors give way.
	for c in tree.get_nodes_in_group("crumble"):
		if (c as Node2D).global_position.distance_to(at) < radius * 0.8 and c.has_method("collapse"):
			c.collapse()


## Where a grenade thrown from `from` at `vel` flies: [points, impact point or INF].
static func predict(space: PhysicsDirectSpaceState2D, from: Vector2, vel: Vector2, exclude: Array, max_t := 2.0) -> Array:
	var pts := PackedVector2Array([from])
	var p := from
	var v := vel
	var dt := 1.0 / Engine.physics_ticks_per_second
	var t := 0.0
	while t < max_t:
		v.y += GRAVITY * dt
		var n := p + v * dt
		var q := PhysicsRayQueryParameters2D.create(p, n, 1 | 4)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit:
			pts.append(hit.position)
			return [pts, hit.position]
		p = n
		pts.append(p)
		t += dt
	return [pts, Vector2.INF]


## Launch velocity whose arc passes through `target`, flight time scaled by distance.
static func solve(from: Vector2, target: Vector2) -> Vector2:
	var d := target - from
	var t := clampf(d.length() / 230.0, 0.3, 1.15)
	var v := d / t - Vector2(0, GRAVITY) * t * 0.5
	return v.limit_length(MAX_SPEED)


func _draw() -> void:
	var blink := fuse < 0.8 and fmod(fuse, 0.16) < 0.08
	draw_circle(Vector2.ZERO, R, Color("#3e4a2c"))
	draw_circle(Vector2(-0.6, -0.6), R * 0.55, Color("#5c6a3e"))
	for i in 3:
		draw_line(Vector2(-R + 0.5, -1 + i), Vector2(R - 0.5, -1 + i), Color("#2a321e"), 1.0)
	draw_rect(Rect2(-1, -R - 1.5, 2, 1.5), Color("#8c8f99"))
	draw_rect(Rect2(-0.5, -R - 2.5, 1, 1), Color("#ff6a20") if blink else Color("#c0a060"))
