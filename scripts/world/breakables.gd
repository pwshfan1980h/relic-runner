class_name Breakables
extends RefCounted
## Things the hero opens up with their boots (or a grenade):
##   Toppler (Y): a dead tree / cracked pillar standing at a gap. Kick it and it falls
##                the way you kicked, pivoting on its base, and lands across the gap as
##                a bridge (crushing whatever it lands on). Punches only rock it.
##   Wall (%):    cracked rock. Three kicks or one grenade bring a column of it down.


class Toppler:
	extends AnimatableBody2D
	var height := 48.0
	var biome := "canyon"
	var fallen := false
	var _falling := false
	var _dir := 1
	var _ang := 0.0
	var _spin := 0.0
	var _wobble := 0.0
	var _shape: CollisionShape2D

	func _ready() -> void:
		add_to_group("toppler")
		add_to_group("blastable")
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = false
		z_index = -1
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(8, height)
		_shape.shape = r
		_shape.position = Vector2(0, -height / 2.0)
		add_child(_shape)

	func blast_point(from: Vector2) -> Vector2:
		return from.clamp(global_position + Vector2(-4, -height), global_position + Vector2(4, 0))

	func take_hit(_dmg: int, dir: Vector2, at: Vector2, kind := "bullet") -> void:
		if fallen or _falling:
			return
		if kind == "kick" or kind == "explosion":
			_falling = true
			_dir = 1 if dir.x >= 0.0 else -1
			_spin = 0.6
			Audio.play_at("stone_crumble" if biome == "jungle" else "hit_wood", at, 0.0)
			Fx.chips(global_position + Vector2(0, -4), Vector2(-_dir, -1).normalized(), 8, _col_d())
		else:
			_wobble = 1.0
			Fx.chips(at, -dir, 2, _col())
			Audio.play_at("hit_wood", at, -8.0)
			if kind == "punch":
				Fx.float_text(global_position + Vector2(0, -height - 6), "KICK IT!", Color("#ffd070"))

	func _physics_process(delta: float) -> void:
		_wobble = move_toward(_wobble, 0.0, delta * 3.0)
		if _falling:
			# A falling pole: angular acceleration grows as it tips (g * sin(angle)).
			_spin += (3.0 + 16.0 * sin(_ang)) * delta
			_ang = minf(PI / 2.0, _ang + _spin * delta)
			rotation = _ang * _dir
			if _ang >= PI / 2.0:
				_land()
		elif not fallen:
			rotation = sin(Time.get_ticks_msec() * 0.03) * 0.03 * _wobble
		queue_redraw()

	func _land() -> void:
		_falling = false
		fallen = true
		rotation = PI / 2.0 * _dir
		# Settle so the top of the log sits flush with the ground: walkable.
		position.y += 4.0
		Fx.add_shake(0.5)
		Audio.play_at("slam", global_position + Vector2(_dir * height / 2.0, 0), 0.0)
		var mid := global_position + Vector2(_dir * height / 2.0, -4)
		for i in 5:
			Fx.puff(global_position + Vector2(_dir * height * (i + 0.5) / 5.0, 0), 3, Color("#c8a070"))
		# Crush anything it came down on.
		for e in get_tree().get_nodes_in_group("enemy"):
			var p: Vector2 = (e as Node2D).global_position
			if absf(p.x - mid.x) < height / 2.0 and p.y - mid.y > -20.0 and p.y - mid.y < 24.0:
				e.take_hit(9, Vector2(_dir, 0), p + Vector2(0, -6), "kick")
		get_tree().call_group("hud", "banner_small", "A BRIDGE!")

	func _col() -> Color:
		return Color("#8c7a5e") if biome == "canyon" else Color("#6a7462")

	func _col_d() -> Color:
		return Color("#5e4c38") if biome == "canyon" else Color("#44503e")

	func _draw() -> void:
		var w := 8.0
		var h := height
		if biome == "canyon":
			# Sun-bleached dead tree: trunk with stubby branches and a split at the base.
			draw_rect(Rect2(-w / 2, -h, w, h), _col())
			draw_rect(Rect2(-w / 2, -h, 2, h), _col().lightened(0.2))
			draw_rect(Rect2(w / 2 - 2, -h, 2, h), _col_d())
			for i in int(h / 12):
				var y := -h + 6 + i * 12
				draw_line(Vector2(-w / 2 + 2, y), Vector2(w / 2 - 2, y + 3), _col_d(), 1.0)
			draw_line(Vector2(w / 2, -h * 0.7), Vector2(w / 2 + 6, -h * 0.7 - 5), _col(), 2.0)
			draw_line(Vector2(-w / 2, -h * 0.45), Vector2(-w / 2 - 5, -h * 0.45 - 6), _col(), 2.0)
		else:
			# Carved temple pillar with a glyph band.
			draw_rect(Rect2(-w / 2, -h, w, h), _col())
			draw_rect(Rect2(-w / 2, -h, 2, h), _col().lightened(0.15))
			draw_rect(Rect2(w / 2 - 2, -h, 2, h), _col_d())
			for i in int(h / 8):
				draw_line(Vector2(-w / 2, -h + i * 8), Vector2(w / 2, -h + i * 8), _col_d(), 1.0)
			draw_rect(Rect2(-2, -h * 0.6, 4, 4), Color("#c8a040"))
			draw_rect(Rect2(-w / 2 - 1, -h - 2, w + 2, 3), _col_d())
		if not fallen and not _falling:
			# The weak point: a crack at kicking height.
			draw_line(Vector2(-w / 2, -8), Vector2(0, -11), Color(0, 0, 0, 0.6), 1.0)
			draw_line(Vector2(0, -11), Vector2(w / 2, -9), Color(0, 0, 0, 0.6), 1.0)


class Wall:
	extends StaticBody2D
	var rows := 1
	var biome := "canyon"
	var hp := 3
	var _shake := 0.0
	var _tex: Texture2D

	func _ready() -> void:
		add_to_group("blastable")
		hp = 2 if GameState.up("boots") > 0 else 3
		collision_layer = 1
		collision_mask = 0
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16 * rows)
		s.shape = r
		s.position = Vector2(8, 8 * rows)
		add_child(s)
		var occ := LightOccluder2D.new()
		var op := OccluderPolygon2D.new()
		op.polygon = PackedVector2Array([Vector2(2, 2), Vector2(14, 2), Vector2(14, 16 * rows - 2), Vector2(2, 16 * rows - 2)])
		occ.occluder = op
		add_child(occ)
		_tex = load("res://assets/sprites/%s_tiles.png" % biome)

	## Centre, for blasts.
	func blast_point(from: Vector2) -> Vector2:
		var r := Rect2(global_position, Vector2(16, 16 * rows))
		return from.clamp(r.position, r.end)

	func take_hit(_dmg: int, dir: Vector2, at: Vector2, kind := "bullet") -> void:
		if hp <= 0:
			return
		match kind:
			"explosion":
				hp = 0
			"kick":
				hp -= 1
			_:
				Fx.sparks(at, -dir, 3)
				if kind == "punch":
					Fx.float_text(global_position + Vector2(8, -6), "KICK IT!", Color("#ffd070"))
				return
		_shake = 0.25
		Fx.chips(at, -dir, 6, Color("#8a6a48"))
		Audio.play_at("stone_crumble", at, -4.0 if hp > 0 else 0.0)
		if hp <= 0:
			_break(dir)

	func _break(dir: Vector2) -> void:
		Fx.add_shake(0.4)
		for i in rows * 3:
			var p := global_position + Vector2(randf_range(2, 14), randf_range(2, 16 * rows - 2))
			Fx.chips(p, Vector2(dir.x, -0.6).normalized(), 5, Color("#8a6a48"))
			Fx.puff(p, 3, Color("#b89868"))
		queue_free()

	func _process(delta: float) -> void:
		_shake = maxf(0.0, _shake - delta)
		queue_redraw()

	func _draw() -> void:
		var o := Vector2(randf_range(-1, 1), 0) if _shake > 0.0 else Vector2.ZERO
		for i in rows:
			draw_texture_rect_region(_tex, Rect2(o + Vector2(0, i * 16), Vector2(16, 16)), Rect2(Vector2(15 * 16, 0), Vector2(16, 16)), Color(0.9, 0.85, 0.8))
			# Crack pattern: gets worse as it takes kicks.
			var c := Color(0, 0, 0, 0.55)
			var y := i * 16.0
			draw_line(o + Vector2(3, y + 2), o + Vector2(8, y + 8), c)
			draw_line(o + Vector2(8, y + 8), o + Vector2(6, y + 14), c)
			draw_line(o + Vector2(8, y + 8), o + Vector2(13, y + 6), c)
			if hp < 3:
				draw_line(o + Vector2(2, y + 11), o + Vector2(8, y + 8), c)
			if hp < 2:
				draw_line(o + Vector2(13, y + 6), o + Vector2(14, y + 13), c)
				draw_rect(Rect2(o + Vector2(7, y + 7), Vector2(2, 2)), Color(0, 0, 0, 0.7))
