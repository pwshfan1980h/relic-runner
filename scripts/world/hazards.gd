class_name Hazards
extends RefCounted
## Prince of Persia furniture: spikes, crumbling floors, gates + pressure plates,
## checkpoints, hanging lanterns and hint signs. Each is a small inner class so the
## level builder can place them from map characters.


## Spike pit: touching it is death.
class Spikes:
	extends Area2D
	var biome := "canyon"

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2 | 4
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 6)
		s.shape = r
		s.position = Vector2(0, -3)
		add_child(s)
		body_entered.connect(func(b):
			Audio.play_at("spike_hit", global_position, -2.0)
			Gore.of(self).burst(b.global_position + Vector2(0, -4), 30, Vector2.UP)
			if b is Hero:
				(b as Hero).kill()
			elif b is Enemy:
				(b as Enemy).die("spikes", Vector2.DOWN, b.global_position))

	func _draw() -> void:
		var metal := Color("#9a9aa4") if biome == "canyon" else Color("#8a8a70")
		var dark := Color("#3a3a44")
		for i in 4:
			var x := -8.0 + i * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 2, -7), Vector2(x + 4, 0)]), metal)
			draw_line(Vector2(x + 2, -7), Vector2(x + 3.5, 0), dark, 1.0)


## A floor tile that cracks, shakes and drops when stood on, then resets.
class Crumble:
	extends StaticBody2D
	var biome := "canyon"
	var _t := -1.0  # time since triggered (-1 = intact)
	var _fall := 0.0
	var _shape: CollisionShape2D
	var _tex: Texture2D

	func _ready() -> void:
		collision_layer = 1
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16)
		_shape.shape = r
		_shape.position = Vector2(8, 8)
		add_child(_shape)
		_tex = load("res://assets/sprites/%s_tiles.png" % biome)

	func _physics_process(delta: float) -> void:
		var hero := get_tree().get_first_node_in_group("hero") as Hero
		if _t < 0.0:
			var feet := hero.global_position - global_position if hero else Vector2.INF
			if hero and hero.is_on_floor() and absf(feet.y) < 2.0 and feet.x > -3.0 and feet.x < 19.0:
				_t = 0.0
				Audio.play_at("crumble_crack", global_position, -4.0)
		elif _t < 0.5:
			_t += delta
		elif _t < 5.0:
			if _shape.disabled == false:
				_shape.set_deferred("disabled", true)
				Fx.chips(global_position + Vector2(8, 8), Vector2.DOWN, 6, Color("#8a6a48"))
			_t += delta
			_fall += delta
		else:
			reset()
		queue_redraw()

	func reset() -> void:
		_t = -1.0
		_fall = 0.0
		_shape.set_deferred("disabled", false)

	func _draw() -> void:
		if _fall > 1.5:
			return
		var shake := Vector2(randf_range(-1, 1), 0) if _t >= 0.0 and _t < 0.5 else Vector2.ZERO
		var drop := Vector2(0, 0.5 * 900.0 * _fall * _fall)
		# Mask 5 (up + down neighbours absent) reads as a standalone slab.
		draw_texture_rect_region(_tex, Rect2(shake + drop, Vector2(16, 16)), Rect2(Vector2(10 * 16, 0), Vector2(16, 16)))
		# Cracks so it looks suspect even when intact.
		var c := Color(0, 0, 0, 0.45)
		draw_line(shake + drop + Vector2(3, 3), shake + drop + Vector2(7, 9), c)
		draw_line(shake + drop + Vector2(7, 9), shake + drop + Vector2(12, 7), c)


## Portcullis. Opened by pressure plates (timed) or by a trigger (the boss dying).
class Gate:
	extends StaticBody2D
	var height := 48.0
	var open_time := 7.0
	var _open := 0.0  # 0 closed .. 1 open
	var _timer := 0.0
	var _latched := false
	var _shape: CollisionShape2D
	var _tick := 0.0

	func _ready() -> void:
		add_to_group("gate")
		collision_layer = 1
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(6, height)
		_shape.shape = r
		_shape.position = Vector2(8, height / 2.0)
		add_child(_shape)
		z_index = 1

	func trigger(latch := false) -> void:
		if _timer <= 0.0 and _open < 0.5:
			Audio.play_at("gate_rumble", global_position, -2.0)
		_timer = open_time
		_latched = _latched or latch

	func _physics_process(delta: float) -> void:
		if _latched:
			_timer = open_time
		if _timer > 0.0:
			_timer -= delta
			_open = move_toward(_open, 1.0, delta * 2.5)
			_tick -= delta
			if _tick <= 0.0 and not _latched:
				_tick = 0.5 if _timer > 2.0 else 0.25
				Audio.play_at("gate_tick", global_position, -8.0)
		else:
			_open = move_toward(_open, 0.0, delta * 0.9)
		# Solid unless (nearly) fully raised.
		_shape.disabled = _open > 0.8
		queue_redraw()

	func _draw() -> void:
		var h := height * (1.0 - _open * 0.92)
		var iron := Color("#3a3a42")
		var iron_l := Color("#7a7a86")
		draw_rect(Rect2(2, -2, 12, 3), Color("#2a2a30"))
		for x: float in [5.0, 8.0, 11.0]:
			draw_rect(Rect2(x - 0.5, 0, 1.5, h), iron)
			draw_rect(Rect2(x - 0.5, h - 3, 1.5, 3), iron_l)
		for y in range(6, int(h), 10):
			draw_rect(Rect2(4, y, 8, 1), iron)


## Floor plate that opens every gate in the level.
class Plate:
	extends Area2D
	var _down := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2 | 4
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 4)
		s.shape = r
		s.position = Vector2(0, -2)
		add_child(s)
		body_entered.connect(func(_b):
			Audio.play_at("plate_click", global_position, -2.0)
			for g in get_tree().get_nodes_in_group("gate"):
				(g as Gate).trigger())

	func _physics_process(delta: float) -> void:
		_down = move_toward(_down, 1.0 if has_overlapping_bodies() else 0.0, delta * 10.0)
		queue_redraw()

	func _draw() -> void:
		var y := -2.0 + _down * 1.5
		draw_rect(Rect2(-7, y, 14, 2), Color("#8a7a5a"))
		draw_rect(Rect2(-7, y, 14, 1), Color("#b8a878"))


## Touch to move the respawn point here.
class Checkpoint:
	extends Area2D
	var lit := false
	var _t := 0.0
	var _light: PointLight2D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(12, 24)
		s.shape = r
		s.position = Vector2(0, -12)
		add_child(s)
		_light = PointLight2D.new()
		_light.texture = Lights.radial(128)
		_light.color = Color("#ffb060")
		_light.energy = 0.0
		_light.position = Vector2(0, -6)
		add_child(_light)
		body_entered.connect(func(b):
			if b is Hero and not lit:
				lit = true
				(b as Hero).spawn = global_position
				Audio.play("checkpoint", -4.0))

	func _process(delta: float) -> void:
		_t += delta
		_light.energy = (0.9 + 0.1 * sin(_t * 11.0)) if lit else 0.0
		queue_redraw()

	func _draw() -> void:
		# A ring of stones; lights into a campfire.
		for i in 5:
			draw_rect(Rect2(-7 + i * 3, -2, 2, 2), Color("#6a5a4a"))
		draw_line(Vector2(-4, -1), Vector2(4, -4), Color("#4a2e1a"), 1.0)
		draw_line(Vector2(-4, -4), Vector2(4, -1), Color("#4a2e1a"), 1.0)
		if lit:
			var h := 5.0 + sin(_t * 15.0) * 1.5
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -2), Vector2(3, -2), Vector2(sin(_t * 9.0), -2 - h)]), Color("#ff7a20"))
			draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -2), Vector2(1.5, -2), Vector2(sin(_t * 12.0) * 0.5, -2 - h * 0.6)]), Color("#ffe080"))


## Lantern hanging on a rope; sways, casts shadows.
class Lantern:
	extends Node2D
	var rope := 20.0
	var _t := randf() * 10.0
	var _light: PointLight2D

	func _ready() -> void:
		z_index = 2
		_light = PointLight2D.new()
		_light.texture = Lights.radial(256)
		_light.color = Color("#ffc070")
		_light.energy = 1.0
		_light.texture_scale = 2.2
		_light.shadow_enabled = true
		_light.shadow_color = Color(0, 0, 0, 0.8)
		add_child(_light)

	func _process(delta: float) -> void:
		_t += delta
		_light.position = _tip()
		_light.energy = 0.95 + 0.05 * sin(_t * 17.0)
		queue_redraw()

	func _tip() -> Vector2:
		return Vector2(0, rope).rotated(sin(_t * 1.3) * 0.12)

	func _draw() -> void:
		var tip := _tip()
		draw_line(Vector2.ZERO, tip, Color("#3b2616"), 1.0)
		draw_rect(Rect2(tip + Vector2(-2, 0), Vector2(4, 5)), Color("#2a2a30"))
		draw_rect(Rect2(tip + Vector2(-1, 1), Vector2(2, 3)), Color("#ffe090"))


## Wooden signpost; the HUD shows its text while the hero stands near.
class Sign:
	extends Node2D
	var text := ""

	func _ready() -> void:
		add_to_group("sign")
		z_index = -1

	func _draw() -> void:
		draw_rect(Rect2(-1, -14, 2, 14), Color("#5a3a1c"))
		draw_rect(Rect2(-7, -18, 14, 8), Color("#8a5a30"))
		draw_rect(Rect2(-7, -18, 14, 1), Color("#b07a44"))
		draw_rect(Rect2(-5, -15, 10, 1), Color("#3a2410"))
		draw_rect(Rect2(-5, -13, 7, 1), Color("#3a2410"))
