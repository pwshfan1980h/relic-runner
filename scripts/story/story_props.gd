class_name StoryProps
extends RefCounted
## Story things placed in maps:
##   N  Npc:      a cast member. Walk up and press E to talk (instead of punching).
##                Map "npcs" list, in reading order: [cast id, talk id, after id, reward].
##   !  Trigger:  plays a conversation once, the first time the hero passes.
##                Map "triggers" list, in reading order: talk ids.
##   *  Fragment: a hidden relic fragment (three per level; found ones stay found).
##   g  Supply:   an ammo crate: tops up grenades, once.


class Npc:
	extends Node2D
	var who := "hattie"
	var talk_id := ""
	var after_id := ""
	var reward := {}  # {"grenades": n, "gold": n, "heal": n}, given after the first talk
	var rig: HeroRig
	var _anim: HeroAnims.Animator
	var _near := false
	var _t := 0.0

	func _ready() -> void:
		add_to_group("npc")
		z_index = 3
		rig = UI.cast_rig(who)
		add_child(rig)
		_anim = HeroAnims.Animator.new()
		_anim.play("idle", 0.0)

	func _process(delta: float) -> void:
		_t += delta
		var hero := get_tree().get_first_node_in_group("hero") as Hero
		if hero:
			var d := hero.global_position - global_position
			_near = absf(d.x) < 26.0 and absf(d.y) < 20.0
			if absf(d.x) > 2.0:
				rig.facing = int(signf(d.x))
			if _near:
				rig.look_at_point(hero.global_position + Vector2(0, -24), 0.8)
		rig.apply(_anim.advance(delta), 1)
		if _near:
			rig.look_at_point(hero.global_position + Vector2(0, -24), 0.8)
		queue_redraw()

	func near() -> bool:
		return _near

	func talk() -> void:
		var first := not GameState.flags.has(talk_id)
		var lines := Story.talk(talk_id if first or after_id == "" else after_id)
		GameState.flags[talk_id] = true
		DialogueBox.play(get_tree(), lines, func(): _give(first))

	func _give(first: bool) -> void:
		if not first or reward.is_empty():
			return
		var hero := get_tree().get_first_node_in_group("hero") as Hero
		if hero == null:
			return
		if reward.has("grenades"):
			hero.add_grenades(reward["grenades"])
			Fx.float_text(hero.global_position + Vector2(0, -34), "+%d GRENADES" % reward["grenades"], Color("#b0d080"))
			Audio.play("grenade_pin", -4.0)
		if reward.has("gold"):
			GameState.add_gold(reward["gold"])
			Fx.float_text(hero.global_position + Vector2(0, -40), "+%d GOLD" % reward["gold"], Color("#ffd040"))
			Audio.play("coin_pickup", -4.0)
		if reward.has("heal"):
			hero.heal(reward["heal"])

	func _draw() -> void:
		if _near and not DialogueBox.active(get_tree()):
			var y := -40.0 + sin(_t * 4.0)
			var font := ThemeDB.fallback_font
			draw_rect(Rect2(-17, y - 8, 34, 11), Color(0.07, 0.04, 0.025, 0.85))
			draw_string(font, Vector2(-15, y + 1), "E  TALK", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.GOLD)


class Trigger:
	extends Node2D
	var talk_id := ""
	var _fired := false

	func _physics_process(_delta: float) -> void:
		if _fired or talk_id == "":
			return
		var hero := get_tree().get_first_node_in_group("hero") as Hero
		if hero == null or hero.state == Hero.S.DEAD:
			return
		var d := hero.global_position - global_position
		if absf(d.x) < 10.0 and absf(d.y) < 48.0:
			_fired = true
			DialogueBox.play(get_tree(), Story.talk(talk_id))


class Fragment:
	extends Area2D
	var map := ""
	var index := 0
	var _t := randf() * 5.0
	var _had := false
	var _light: PointLight2D

	func _ready() -> void:
		add_to_group("fragment")
		z_index = 4
		collision_layer = 0
		collision_mask = 2
		var s := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 7.0
		s.shape = c
		s.position = Vector2(0, -8)
		add_child(s)
		_had = GameState.has_fragment(map, index)
		_light = PointLight2D.new()
		_light.texture = Lights.radial(64)
		_light.color = Color("#ffc850")
		_light.energy = 0.3 if _had else 0.8
		_light.position = Vector2(0, -8)
		add_child(_light)
		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if not b is Hero:
			return
		var fresh := GameState.found_fragment(map, index)
		var n: int = (GameState.fragments.get(map, []) as Array).size()
		Audio.play("item_pickup", -2.0, 1.3)
		Audio.play("checkpoint", -8.0, 1.5)
		Fx.sparks(global_position + Vector2(0, -8), Vector2.UP, 12, Color("#ffe080"))
		if fresh:
			get_tree().call_group("hud", "banner_small", "RELIC FRAGMENT  %d / %d" % [n, Story.FRAGMENTS_PER_LEVEL])
		queue_free()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var y := -8.0 + sin(_t * 2.5) * 2.0
		var a := 0.45 if _had else 1.0
		# A wedge of a golden sun disc, turning slowly.
		var k := cos(_t * 1.6)
		var pts := PackedVector2Array([Vector2(0, y - 5), Vector2(4 * k, y + 3), Vector2(-4 * k, y + 3)])
		if absf(k) > 0.1:
			draw_colored_polygon(pts, Color(0.95, 0.72, 0.2, a))
		draw_line(Vector2(0, y - 5), Vector2(0, y + 3), Color(1.0, 0.92, 0.6, a), 1.0)
		if fmod(_t, 1.6) < 0.15:
			draw_line(Vector2(-4, y - 2), Vector2(4, y - 2), Color(1, 1, 0.9, a), 1.0)


class Supply:
	extends Area2D
	var amount := 2
	var _taken := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var s := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(14, 10)
		s.shape = r
		s.position = Vector2(0, -5)
		add_child(s)
		body_entered.connect(func(b):
			if b is Hero and not _taken:
				_taken = true
				(b as Hero).add_grenades(amount)
				Audio.play("grenade_pin", -4.0)
				Fx.float_text(global_position + Vector2(0, -16), "+%d GRENADES" % amount, Color("#b0d080"))
				queue_redraw())

	func _draw() -> void:
		draw_rect(Rect2(-7, -9, 14, 9), Color("#4e5a32") if not _taken else Color("#3a3a2a"))
		draw_rect(Rect2(-7, -9, 14, 2), Color("#6c7a46"))
		draw_rect(Rect2(-7, -9, 14, 9), Color("#22281a"), false, 1.0)
		if not _taken:
			draw_circle(Vector2(-3, -11), 2.0, Color("#3e4a2c"))
			draw_circle(Vector2(1, -11), 2.0, Color("#3e4a2c"))
			draw_circle(Vector2(4, -10), 2.0, Color("#4e5c34"))
		draw_string(ThemeDB.fallback_font, Vector2(-5, -2), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#d8d0a0"))
