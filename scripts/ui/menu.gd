extends Node2D
## Title screen. A live dusk over the canyon (the sky keeps turning, stars come out),
## the hero on a rock, drifting dust, the logo, and the menu:
## CONTINUE (with a save) / NEW GAME / HOW TO PLAY / OPTIONS / CREDITS.

const CREDITS := [
	"RELIC RUNNER",
	"",
	"Design, code, art, sound and music: generated for Relic Runner",
	"(tools/gen_art.py, tools/gen_audio.py, tools/gen_music.py)",
	"Screams and animal voices: sourced clips, see CREDITS.md",
	"",
	"Made with Godot Engine",
]

var _sky: SkyDome
var _rig: HeroRig
var _anim: HeroAnims.Animator
var _list: Menus.List
var _opts: Menus.List
var _root: Control
var _t := 0.0
var _dust: Array = []
var _actions: Array[String] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_sky = SkyDome.new("canyon", 18.7)
	_sky.speed = 0.02
	add_child(_sky)
	var rock := Polygon2D.new()
	rock.polygon = PackedVector2Array([Vector2(292, 270), Vector2(312, 214), Vector2(356, 205), Vector2(410, 211), Vector2(436, 270)])
	rock.color = Color("#1a0e08")
	add_child(rock)
	var lip := Polygon2D.new()
	lip.polygon = PackedVector2Array([Vector2(312, 214), Vector2(356, 205), Vector2(410, 211), Vector2(408, 213), Vector2(356, 207), Vector2(313, 216)])
	lip.color = Color("#4a2a18")
	add_child(lip)
	_rig = HeroRig.new()
	_rig.size_scale = 2.0
	_rig.facing = -1
	_rig.position = Vector2(362, 207)
	add_child(_rig)
	_anim = HeroAnims.Animator.new()
	_anim.play("idle", 0.0)
	for i in 40:
		_dust.append([Vector2(randf() * 480, randf() * 270), randf_range(4, 14), randf()])
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_root = Control.new()
	_root.size = Vector2(480, 270)
	layer.add_child(_root)
	UI.label(_root, "RELIC RUNNER", Vector2(0, 26), 32, UI.INK, 480, HORIZONTAL_ALIGNMENT_CENTER, 4)
	UI.label(_root, "A  PULP  ADVENTURE  ·  1936", Vector2(0, 70), 8, UI.GOLD)
	var items: Array[String] = []
	if GameState.has_save():
		items.append("CONTINUE")
		_actions.append("continue")
	items.append_array(["NEW GAME", "HOW TO PLAY", "OPTIONS", "CREDITS"])
	_actions.append_array(["new", "help", "options", "credits"])
	_list = Menus.List.new()
	_root.add_child(_list)
	_list.setup(items, Vector2(20, 110), 200)
	_list.chosen.connect(_on_pick)
	UI.label(_root, "W/S  ENTER   ·   MOUSE", Vector2(20, 110 + items.size() * 20 + 6), 8, UI.DIM, 200)
	Audio.ambience("amb_canyon_loop", -18.0)
	Audio.music("music_title")


func _on_pick(i: int) -> void:
	match _actions[i]:
		"continue":
			GameState.continue_game()
		"new":
			GameState.new_game()
		"help":
			_list.visible = false
			var h := Menus.HowToPlay.new()
			_root.add_child(h)
			h.closed.connect(func(): _list.visible = true)
		"options":
			_list.visible = false
			_opts = Menus.options_list(_root, Vector2(20, 110))
			_opts.size.x = 200
			_opts.chosen.connect(func(k):
				if k == 3:
					_opts.queue_free()
					_list.visible = true)
		"credits":
			_list.visible = false
			var panel := UI.panel(_root, Rect2(60, 90, 360, 130))
			for j in CREDITS.size():
				UI.label(panel, CREDITS[j], Vector2(0, 10 + j * 13), 16 if j == 0 else 8, UI.GOLD if j == 0 else UI.INK, 360)
			# Any key or click closes it (after a beat, so the opening click doesn't).
			get_tree().create_timer(0.2).timeout.connect(func():
				_closer = func():
					panel.queue_free()
					_list.visible = true)


var _closer := Callable()


func _unhandled_input(event: InputEvent) -> void:
	if _closer.is_valid() and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		var c := _closer
		_closer = Callable()
		c.call()


func _process(delta: float) -> void:
	_t += delta
	_rig.apply(_anim.advance(delta), 1)
	# The hero looks out over the canyon, and now and then toward the menu.
	_rig.look_at_point(_rig.position + Vector2(-80, -40 + sin(_t * 0.4) * 20.0), 0.6)
	_sky.cam.x = _t * 4.0
	for d in _dust:
		d[0] += Vector2(-d[1], sin(_t + d[2] * 6.0) * 3.0) * delta
		if d[0].x < -4:
			d[0] = Vector2(484, randf() * 270)
	queue_redraw()


func _draw() -> void:
	for d in _dust:
		var a := 0.25 + 0.2 * sin(_t * 2.0 + d[2] * 10.0)
		draw_rect(Rect2((d[0] as Vector2).round(), Vector2.ONE), Color(1.0, 0.85, 0.6, a))
