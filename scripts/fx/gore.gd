class_name Gore
extends Node2D
## Blood (ported from Rocket Bus): bursts, sprays that follow severed parts, and stains
## that stay on floors and walls. One per level, created on demand. With gore switched
## off (menu option) nothing bleeds.

const BLOOD := Color("#b8101c")
const BLOOD_DARK := Color("#5a0610")
const ICHOR := Color("#8ab020")
const ICHOR_DARK := Color("#3a5010")
const MAX_STAINS := 500

var _stains: Array = []  # [pos, width, shade, color, on_wall(normal x or 0)]
var _sprays: Array[Dictionary] = []


static func enabled() -> bool:
	return GameState.gore_on


static func of(node: Node) -> Gore:
	var tree := node.get_tree()
	var existing := tree.get_first_node_in_group("gore")
	if existing:
		return existing
	var g := Gore.new()
	tree.current_scene.add_child(g)
	return g


func _ready() -> void:
	add_to_group("gore")
	z_index = 3


## A stump or wound that spurts for a while, dripping as it goes.
func spray(body: Node2D, local_pos: Vector2, dir: Vector2, duration := 1.6, color := BLOOD) -> void:
	if not enabled() or not is_instance_valid(body):
		return
	var p := CPUParticles2D.new()
	p.position = local_pos
	p.amount = 40
	p.lifetime = 0.7
	p.local_coords = false
	p.direction = dir
	p.spread = 22.0
	p.gravity = Vector2(0, 650)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = _ramp(color)
	body.add_child(p)
	p.emitting = true
	_sprays.append({"p": p, "t": duration, "drip": 0.0, "c": color})


## A one-off burst (a bullet wound, a limb tearing, a head coming off).
func burst(at: Vector2, amount := 24, dir := Vector2.UP, color := BLOOD, stains := 4) -> void:
	if not enabled():
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.8
	p.direction = dir
	p.spread = 55.0
	p.gravity = Vector2(0, 650)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color_ramp = _ramp(color)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	for i in stains:
		stain_below(at + Vector2(randf_range(-10, 10) + dir.x * randf_range(0, 30), 0), randf_range(2, 5), color)


## Blood that carries through the target and hits the wall behind it.
func wall_splat(from: Vector2, dir: Vector2, color := BLOOD) -> void:
	if not enabled():
		return
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * 70.0, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit and absf(hit.normal.x) > 0.5:
		for i in 3:
			_add_stain(hit.position + Vector2(0, randf_range(-5, 5)), randf_range(2, 4), color, signf(hit.normal.x))


## Leaves a stain on the ground under `at` (raycast down).
func stain_below(at: Vector2, width: float, color := BLOOD) -> void:
	if not enabled():
		return
	var q := PhysicsRayQueryParameters2D.create(at + Vector2(0, -4), at + Vector2(0, 300), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		_add_stain(hit.position, width, color, 0.0)


## Blast scorch on the floor below (not gore, so always shown).
func scorch(at: Vector2, width: float) -> void:
	var q := PhysicsRayQueryParameters2D.create(at + Vector2(0, -4), at + Vector2(0, 300), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		_add_stain(hit.position, width, Color(0.07, 0.05, 0.04, 0.8), 0.0)


func _add_stain(p: Vector2, width: float, color: Color, wall: float) -> void:
	_stains.append([p.round(), width, randf(), color, wall])
	if _stains.size() > MAX_STAINS:
		_stains.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	for s in _sprays:
		s.t -= delta
		var p: CPUParticles2D = s.p
		if not is_instance_valid(p):
			s.t = 0.0
			continue
		p.initial_velocity_max = 150.0 * clampf(s.t / 1.6, 0.25, 1.0)  # spurts weaken
		s.drip -= delta
		if s.drip <= 0.0:
			s.drip = 0.1
			stain_below(p.global_position + Vector2(randf_range(-6, 6), 0), randf_range(1.0, 2.5), s.c)
		if s.t <= 0.0:
			p.emitting = false
			get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	_sprays = _sprays.filter(func(s): return s.t > 0.0)


func _draw() -> void:
	for s in _stains:
		var p: Vector2 = s[0]
		var w: float = s[1]
		var col: Color = s[3]
		var dark := BLOOD_DARK if col == BLOOD else ICHOR_DARK
		var c := col.lerp(dark, s[2])
		var wall: float = s[4]
		if wall != 0.0:
			# Splash on a wall face, with a run dripping down.
			draw_rect(Rect2(p.x - (1.0 if wall > 0 else 0.0), p.y - w * 0.5, 1, w), c)
			draw_rect(Rect2(p.x - (1.0 if wall > 0 else 0.0), p.y, 1, 3 + s[2] * 6), dark)
		else:
			draw_rect(Rect2(p.x - w, p.y - 1, w * 2, 1), c)
			draw_rect(Rect2(p.x - w * 0.5, p.y - 2, w, 1), c)


static func _ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	var dark := BLOOD_DARK if color == BLOOD else ICHOR_DARK
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([color.lightened(0.15), color, Color(dark, 0.0)])
	return g
