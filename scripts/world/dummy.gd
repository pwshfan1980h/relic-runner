class_name Dummy
extends StaticBody2D
## Straw practice dummy hanging from a post on a short rope. Shots and whip cracks
## set it swinging (a damped pendulum) and knock straw loose.

var hits := 0
var _ang := 0.0
var _vel := 0.0
var _body: CollisionShape2D


func _ready() -> void:
	add_to_group("whippable")
	collision_layer = 4
	collision_mask = 0
	_body = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(9, 12)
	_body.shape = r
	add_child(_body)
	_physics_process(0.0)


func _physics_process(delta: float) -> void:
	_vel += -sin(_ang) * 90.0 * delta
	_vel *= 1.0 - 1.2 * delta
	_ang += _vel * delta
	_body.position = _center()
	_body.rotation = _ang
	queue_redraw()


func _center() -> Vector2:
	return Vector2(0, -25) + Vector2(0, 11).rotated(_ang)


func take_hit(_dmg: int, dir: Vector2, at: Vector2) -> void:
	hits += 1
	_vel += dir.x * 4.0
	Fx.chips(at, -dir, 5, Color("#d8c070"))
	Audio.play_at("hit_straw", at, -4.0)


func whip_pull(to: Vector2) -> void:
	_vel += signf(to.x - global_position.x) * 6.0
	Fx.chips(global_position + _center(), Vector2.UP, 4, Color("#d8c070"))
	Audio.play_at("hit_straw", global_position, -6.0)


func _draw() -> void:
	var wood := Color("#5a3a1c")
	draw_rect(Rect2(-9, -28, 2, 28), wood)
	draw_rect(Rect2(-9, -29, 11, 2), wood)
	var c := _center()
	draw_line(Vector2(0, -27), c + Vector2(0, -6).rotated(_ang), Color("#3b2616"), 1.0)
	var xf := Transform2D(_ang, c)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-4, -6), Vector2(4, -6), Vector2(5, 6), Vector2(-5, 6)]), Color("#c8a860"))
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-4, -6), Vector2(0, -6), Vector2(0, 6), Vector2(-5, 6)]), Color("#a88a48"))
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]), Color("#8a2a1a"))
