class_name Ragdoll
extends Node2D
## A corpse made from a HeroRig's current pose (adapted from Rocket Bus): the rig's own
## polygons move onto physics bodies pinned at neck, shoulders, elbows, hips and knees,
## so the body falls exactly as it looked. Violent hits tear joints: limbs and heads
## come off, stumps spurt (see Gore). With gore off nothing tears and nothing bleeds.

const TEAR_SPEED := 300.0
const MAX_CORPSES := 12
const LIFETIME := 30.0

# part: [bones whose polygons it takes, parent part, collider size (along the bone), round]
const PARTS := {
	"torso": [["hips", "torso"], "", Vector2(6, 12), false],
	"head": [["head"], "torso", Vector2(5, 5), true],
	"ua_f": [["ua_f"], "torso", Vector2(2.4, 5), false],
	"fa_f": [["fa_f", "hand_f"], "ua_f", Vector2(2.2, 5.5), false],
	"ua_b": [["ua_b"], "torso", Vector2(2.4, 5), false],
	"fa_b": [["fa_b", "hand_b"], "ua_b", Vector2(2.2, 5.5), false],
	"th_f": [["th_f"], "torso", Vector2(3, 7), false],
	"sh_f": [["sh_f", "ft_f"], "th_f", Vector2(2.6, 8), false],
	"th_b": [["th_b"], "torso", Vector2(3, 7), false],
	"sh_b": [["sh_b", "ft_b"], "th_b", Vector2(2.6, 8), false],
}
var bodies := {}  # part -> RigidBody2D
var _joints := {}  # part -> PinJoint2D (to its parent)
var _age := 0.0
var _bonk := 0.0
var _voice := true


## Builds the corpse into `into` (the level). vel: the body's velocity; push: extra
## impulse from the killing blow, applied most to the part nearest `at`.
static func from_rig(rig: HeroRig, into: Node, vel: Vector2, push: Vector2, at: Vector2, tear: Array = []) -> Ragdoll:
	var r := Ragdoll.new()
	into.add_child(r)
	r._build(rig, vel, push, at)
	for p in tear:
		r.tear(p)
	# Keep the corpse count bounded: the oldest ones fade out.
	var all := into.get_tree().get_nodes_in_group("corpse")
	if all.size() > MAX_CORPSES:
		(all[0] as Ragdoll)._age = LIFETIME - 1.0
	return r


func _build(rig: HeroRig, vel: Vector2, push: Vector2, at: Vector2) -> void:
	add_to_group("corpse")
	z_index = 5
	for part in PARTS:
		var spec: Array = PARTS[part]
		var bone: Node2D = rig.bones[spec[0][0]] if part != "torso" else rig.bones["torso"]
		var xf := bone.global_transform
		var yaxis := xf.y.normalized()
		var b := RigidBody2D.new()
		b.collision_layer = 16
		b.collision_mask = 1
		b.mass = 0.12 if part == "torso" else 0.04
		b.linear_damp = 0.3
		b.angular_damp = 1.5
		b.contact_monitor = true
		b.max_contacts_reported = 2
		var mat := PhysicsMaterial.new()
		mat.bounce = 0.15
		mat.friction = 0.9
		b.physics_material_override = mat
		b.global_transform = Transform2D(yaxis.angle() - PI / 2.0, xf.origin)
		add_child(b)
		var cs := CollisionShape2D.new()
		var size: Vector2 = spec[2]
		if spec[3]:
			var c := CircleShape2D.new()
			c.radius = size.x / 2.0
			cs.shape = c
			cs.position = Vector2(0, -2.4)
		else:
			var rect := RectangleShape2D.new()
			rect.size = size
			cs.shape = rect
			cs.position = Vector2(0, -size.y / 2.0 if part == "torso" else size.y / 2.0)
		b.add_child(cs)
		# Move the rig's own polygons (and the gun, the whip coil) onto the body.
		for bone_name: String in spec[0]:
			var src: Node2D = rig.bones[bone_name]
			for child in src.get_children():
				if child is Polygon2D or child == rig.gun or child == rig.whip_coil:
					child.reparent(b, true)
		bodies[part] = b
		b.linear_velocity = vel + Vector2(randf_range(-20, 20), randf_range(-30, 10))
		b.angular_velocity = randf_range(-6, 6)
		b.body_entered.connect(_on_hit.bind(part))
	# The hat always flies off.
	var hat := RigidBody2D.new()
	hat.collision_layer = 16
	hat.collision_mask = 1
	hat.mass = 0.02
	hat.global_transform = Transform2D(rig.bones["hat"].global_rotation, rig.bones["hat"].global_position)
	add_child(hat)
	var hcs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(7, 2)
	hcs.shape = hr
	hcs.position = Vector2(0, -4.5)
	hat.add_child(hcs)
	for child in rig.bones["hat"].get_children():
		if child is Polygon2D:
			child.reparent(hat, true)
	hat.linear_velocity = vel + push * 0.6 + Vector2(randf_range(-30, 30), -120)
	hat.angular_velocity = randf_range(-14, 14)
	bodies["hat"] = hat
	# Pins between parts.
	for part in PARTS:
		var parent: String = PARTS[part][1]
		if parent == "":
			continue
		var j := PinJoint2D.new()
		j.global_position = bodies[part].global_position
		# No angular limits: Godot's 2D pin limits go unstable (NaN) at these light masses.
		j.softness = 0.1
		add_child(j)
		j.node_a = j.get_path_to(bodies[parent])
		j.node_b = j.get_path_to(bodies[part])
		_joints[part] = j
	# The killing blow: strongest on the part nearest the hit.
	var nearest := "torso"
	var best := INF
	for part in PARTS:
		var d: float = (bodies[part] as Node2D).global_position.distance_to(at)
		if d < best:
			best = d
			nearest = part
	for part in PARTS:
		var k := 1.0 if part == nearest else 0.35
		(bodies[part] as RigidBody2D).apply_central_impulse(push * k * (bodies[part] as RigidBody2D).mass)
	rig.visible = false


## Rip a part (and everything below it) off: both ends spurt.
func tear(part: String) -> void:
	if not Gore.enabled() or not _joints.has(part):
		return
	var joint: PinJoint2D = _joints[part]
	_joints.erase(part)
	var at := joint.global_position
	joint.queue_free()
	var body: RigidBody2D = bodies[part]
	var parent: RigidBody2D = bodies[PARTS[part][1]]
	body.apply_central_impulse(Vector2(randf_range(-40, 40), randf_range(-110, -50)) * body.mass)
	body.angular_velocity += randf_range(-20, 20)
	var gore := Gore.of(self)
	gore.burst(at, 30, (body.global_position - parent.global_position).normalized())
	gore.spray(parent, parent.to_local(at), (at - parent.global_position).normalized(), 2.0)
	gore.spray(body, body.to_local(at), (at - body.global_position).normalized(), 1.0)
	for b: RigidBody2D in [parent, body]:
		var cap := Polygon2D.new()
		cap.color = Gore.BLOOD
		cap.z_index = 12
		var c: Vector2 = b.to_local(at)
		cap.polygon = PackedVector2Array([c + Vector2(-1, -1), c + Vector2(1, -1), c + Vector2(1, 1), c + Vector2(-1, 1)])
		b.add_child(cap)
	Audio.play_at("squelch", at, -4.0, 0.2)
	if part == "head":
		_voice = false
		body.angular_velocity = randf_range(-25, 25)


## Tear a random limb (not the head).
func tear_random() -> void:
	var limbs := _joints.keys().filter(func(p): return p != "head" and (PARTS[p][1] == "torso"))
	if not limbs.is_empty():
		tear(limbs.pick_random())


func _on_hit(_other: Node, part: String) -> void:
	var b: RigidBody2D = bodies.get(part)
	if b == null:
		return
	var speed := b.linear_velocity.length()
	if speed > TEAR_SPEED and _joints.has(part) and randf() < 0.5:
		tear(part)
	if speed > 110.0 and _age - _bonk > 0.3:
		_bonk = _age
		Audio.play_at("land", b.global_position, -14.0, 0.3)
		Gore.of(self).stain_below(b.global_position, randf_range(2, 4))


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		modulate.a = maxf(0.0, 1.0 - (_age - LIFETIME))
		if _age > LIFETIME + 1.0:
			queue_free()
