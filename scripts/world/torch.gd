class_name Torch
extends Node2D
## Wall torch: flickering flame and a shadow-casting light.

var _light: PointLight2D
var _t := randf() * 10.0


func _ready() -> void:
	z_index = 2
	_light = PointLight2D.new()
	_light.texture = Lights.radial(256)
	_light.color = Color("#ffb060")
	_light.energy = 1.1
	_light.shadow_enabled = true
	_light.shadow_color = Color(0, 0, 0, 0.85)
	_light.position = Vector2(0, -10)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var f := 0.9 + 0.08 * sin(_t * 13.0) + 0.06 * sin(_t * 23.7) + randf() * 0.04
	_light.energy = 1.1 * f
	_light.texture_scale = 0.95 + 0.05 * f
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-1, -8, 2, 8), Color("#4a2e1a"))
	draw_rect(Rect2(-2, -9, 4, 2), Color("#2a1a10"))
	var h := 4.0 + sin(_t * 17.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -9), Vector2(2, -9), Vector2(sin(_t * 9.0), -9 - h * 1.6)]), Color("#ff7a20"))
	draw_colored_polygon(PackedVector2Array([Vector2(-1, -9), Vector2(1, -9), Vector2(sin(_t * 11.0) * 0.5, -9 - h)]), Color("#ffe080"))
