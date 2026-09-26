class_name Crate
extends RigidBody2D
## A wooden supply crate. Real rigid-body physics; the whip yanks it toward the hero,
## bullets knock it about.

const SIZE := 12.0


func _ready() -> void:
	add_to_group("whippable")
	collision_layer = 4
	collision_mask = 1 | 4
	mass = 2.0
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(SIZE, SIZE)
	s.shape = r
	add_child(s)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.8
	mat.bounce = 0.1
	physics_material_override = mat


func whip_pull(to: Vector2) -> void:
	var d := to - global_position
	apply_central_impulse(Vector2(d.x * 1.6, -120.0 - absf(d.y) * 0.8).limit_length(420.0) * mass * 0.5)
	Audio.play_at("hit_wood", global_position, -6.0)


func take_hit(_dmg: int, dir: Vector2, at: Vector2) -> void:
	apply_impulse(dir * 90.0, at - global_position)
	Fx.chips(at, -dir, 4, Color("#a07040"))
	Audio.play_at("hit_wood", at, -4.0)


func _draw() -> void:
	var h := SIZE / 2.0
	draw_rect(Rect2(-h, -h, SIZE, SIZE), Color("#8a5a30"))
	draw_rect(Rect2(-h, -h, SIZE, 2), Color("#b07a44"))
	draw_rect(Rect2(-h, h - 2, SIZE, 2), Color("#5a3a1c"))
	draw_line(Vector2(-h + 1, -h + 1), Vector2(h - 1, h - 1), Color("#5a3a1c"), 1.0)
	draw_rect(Rect2(-h, -h, SIZE, SIZE), Color("#3a2410"), false, 1.0)
