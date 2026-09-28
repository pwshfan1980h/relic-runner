extends Node2D
## The opening "film": five letterboxed shots in the engine, like a 90s intro movie.
## Each shot is a little stage (sky, silhouettes, rigs) with a caption; the camera
## drifts for parallax; the last shot cracks the whip and slams the title.
## Any key or click skips to the title screen.

const SHOTS := [
	# [duration, builder method, caption]
	[3.2, "_shot_date", ""],
	[6.0, "_shot_letter", "A letter from Professor Ortiz, three weeks late:\n\"I have found the Sun Idol's trail. So has Crane. Come quickly.\""],
	[5.0, "_shot_crane", "Silas Crane: smuggler, thief, and the best-paid employer in Arizona."],
	[5.5, "_shot_temple", "Far to the south, something has guarded the Idol for a thousand years."],
	[5.5, "_shot_title", ""],
]

var _i := -1
var _t := 0.0
var _stage: Node2D
var _sky: SkyDome
var _caption: Label
var _fade: ColorRect
var _update := Callable()
var _leaving := false
var _anims: Array = []  # [rig, animator]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Audio.ambience("")
	Audio.music("music_intro", 0.5)
	var hud := CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	for y in [0.0, 240.0]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, y)
		bar.size = Vector2(480, 30)
		hud.add_child(bar)
	_caption = UI.label(hud, "", Vector2(20, 243), 8, Color("#e8d8b0"), 440)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.size.y = 26
	UI.label(hud, "ANY KEY TO SKIP", Vector2(380, 6), 8, Color(1, 1, 1, 0.3), 94, HORIZONTAL_ALIGNMENT_RIGHT)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_fade)
	_next()


func _next() -> void:
	_i += 1
	if _i >= SHOTS.size():
		_leave()
		return
	_t = 0.0
	if _stage:
		_stage.queue_free()
	if _sky:
		_sky.queue_free()
		_sky = null
	_anims.clear()
	_stage = Node2D.new()
	add_child(_stage)
	_update = Callable()
	call(SHOTS[_i][1])
	_caption.text = SHOTS[_i][2]
	_caption.visible_characters = 0


func _process(delta: float) -> void:
	_t += delta
	var dur: float = SHOTS[_i][0] if _i < SHOTS.size() else 1.0
	# Fade in and out of every shot; type the caption.
	_fade.color.a = clampf(maxf(1.0 - _t * 1.6, (_t - dur + 0.6) * 1.8), 0.0, 1.0)
	_caption.visible_characters = int(_t * 50.0)
	for a in _anims:
		(a[0] as HeroRig).apply((a[1] as HeroAnims.Animator).advance(delta), 1)
	if _update.is_valid():
		_update.call(_t, delta)
	if _t >= dur and not _leaving:
		_next()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file.call_deferred(GameState.TITLE)


# --- Shots ---------------------------------------------------------------------------

func _sky_at(biome: String, hour: float, speed := 0.0) -> SkyDome:
	_sky = SkyDome.new(biome, hour)
	_sky.speed = speed
	add_child(_sky)
	return _sky


func _rig(who: String, pos: Vector2, sc: float, facing: int, clip := "idle") -> HeroRig:
	var r := UI.cast_rig(who)
	r.size_scale = sc
	r.facing = facing
	r.position = pos
	_stage.add_child(r)
	var a := HeroAnims.Animator.new()
	a.play(clip, 0.0)
	_anims.append([r, a])
	return r


func _ground(pts: Array, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.color = col
	_stage.add_child(p)
	return p


func _shot_date() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0a0604")
	bg.size = Vector2(480, 270)
	_stage.add_child(bg)
	var l := UI.label(_stage, "ARIZONA, 1936", Vector2(0, 118), 16, UI.INK)
	l.modulate.a = 0.0
	Audio.play("intro_boom", -4.0)
	_update = func(t, _d): l.modulate.a = clampf(t - 0.3, 0.0, 1.0) * clampf(3.0 - t, 0.0, 1.0)


func _shot_letter() -> void:
	var sky := _sky_at("canyon", 18.1, 0.12)
	_ground([Vector2(0, 270), Vector2(0, 214), Vector2(140, 206), Vector2(300, 212), Vector2(480, 204), Vector2(480, 270)], Color("#1e100a"))
	var hero := _rig("rook", Vector2(-20, 210), 2.0, 1, "walk")
	var anim: HeroAnims.Animator = _anims[0][1]
	_update = func(t, _d):
		sky.cam.x = t * 30.0
		if hero.position.x < 190.0:
			hero.position.x += _d * 44.0 * 2.0 * 0.5
			hero.position.y = 210.0 - (hero.position.x / 140.0) * 4.0 if hero.position.x < 140.0 else 206.0
		elif anim.clip_name == "walk":
			anim.play("idle_hat", 0.2)


func _shot_crane() -> void:
	var sky := _sky_at("canyon", 21.4, 0.0)
	_ground([Vector2(0, 270), Vector2(0, 200), Vector2(160, 190), Vector2(330, 196), Vector2(480, 186), Vector2(480, 270)], Color("#0c0a10"))
	var crane := _rig("crane", Vector2(240, 193), 2.2, -1)
	var goons: Array[HeroRig] = []
	for x in [180.0, 300.0, 350.0]:
		var g := _rig("bandit", Vector2(x, 192), 2.0, -1)
		g.recolor(Bandit.SWAP)
		g.make_rifle()
		goons.append(g)
	var glint := Node2D.new()
	_stage.add_child(glint)
	_update = func(t, _d):
		sky.cam.x = -t * 12.0
		for g in goons:
			g.aim_arm("f", g.position + Vector2(-100, -10), 1.0, -4.0)
			g.aim_arm("b", g.position + Vector2(-100, -10), 1.0, -40.0)
		crane.look_at_point(crane.position + Vector2(-60, -50), 1.0)
		if absf(t - 3.2) < 0.03:
			Audio.play("rifle", -10.0, 0.8)
			Fx.sparks(goons[0].muzzle_global(), Vector2.LEFT, 8, Color("#fff0a0"))


func _shot_temple() -> void:
	var sky := _sky_at("jungle", 6.0, 0.25)
	# The Guardian's face in the temple wall: stone, then two eyes kindling.
	var face := _ground([Vector2(170, 230), Vector2(190, 110), Vector2(290, 110), Vector2(310, 230)], Color("#2a342c"))
	_ground([Vector2(0, 270), Vector2(0, 226), Vector2(480, 222), Vector2(480, 270)], Color("#0a140c"))
	var brow := _ground([Vector2(196, 150), Vector2(284, 150), Vector2(280, 158), Vector2(200, 158)], Color("#1e2620"))
	# Carved stone: block courses, a broad nose, a grim mouth, moss on the crown.
	for y in [126.0, 142.0, 182.0, 206.0]:
		_ground([Vector2(186 - (y - 110) * 0.1, y), Vector2(294 + (y - 110) * 0.1, y), Vector2(294 + (y - 110) * 0.1, y + 1), Vector2(186 - (y - 110) * 0.1, y + 1)], Color("#1e2620")).reparent(face)
	_ground([Vector2(234, 172), Vector2(246, 172), Vector2(250, 192), Vector2(230, 192)], Color("#36423a")).reparent(face)
	_ground([Vector2(214, 200), Vector2(266, 200), Vector2(262, 206), Vector2(218, 206)], Color("#141a16")).reparent(face)
	_ground([Vector2(190, 110), Vector2(290, 110), Vector2(286, 116), Vector2(240, 120), Vector2(194, 116)], Color("#3e5a32")).reparent(face)
	var eyes: Array[Polygon2D] = []
	for x in [214.0, 252.0]:
		var e := _ground([Vector2(x, 166), Vector2(x + 16, 166), Vector2(x + 14, 172), Vector2(x + 2, 172)], Color(1.0, 0.6, 0.1, 0.0))
		eyes.append(e)
	var light := PointLight2D.new()
	light.texture = Lights.radial(256)
	light.color = Color("#ff9030")
	light.energy = 0.0
	light.position = Vector2(240, 168)
	_stage.add_child(light)
	var mod := CanvasModulate.new()
	mod.color = Color(0.5, 0.55, 0.52)
	_stage.add_child(mod)
	_update = func(t, _d):
		sky.cam.x = t * 8.0
		var k := clampf((t - 2.0) / 1.5, 0.0, 1.0)
		for e in eyes:
			e.color.a = k
		light.energy = k * 1.4
		if absf(t - 2.0) < 0.03:
			Audio.play("stone_grind", -2.0, 0.7)
		face.position.y = sin(t * 30.0) * 0.6 * k * float(t < 3.6)
		brow.position.y = face.position.y


func _shot_title() -> void:
	var sky := _sky_at("canyon", 19.0, 0.1)
	_ground([Vector2(300, 270), Vector2(318, 214), Vector2(360, 206), Vector2(410, 212), Vector2(430, 270)], Color("#1a0e08"))
	var hero := _rig("rook", Vector2(362, 207), 2.0, -1)
	var whip := Line2D.new()
	whip.width = 1.0
	whip.default_color = Whip.COLOR
	_stage.add_child(whip)
	var title := UI.label(_stage, "RELIC RUNNER", Vector2(0, 70), 32, UI.INK, 480, HORIZONTAL_ALIGNMENT_CENTER, 4)
	title.modulate.a = 0.0
	_update = func(t, _d):
		sky.cam.x = t * 6.0
		# The whip unrolls toward the title and cracks on the beat.
		var u := clampf((t - 1.2) / 0.35, 0.0, 1.0)
		var hand := hero.point("hand_b", Vector2(0, 1))
		if u > 0.0 and u < 1.0:
			hero.aim_arm("b", Vector2(240, 90), 1.0, -10.0)
			whip.clear_points()
			for i in 12:
				var k := float(i) / 11.0 * u
				whip.add_point(hand.lerp(Vector2(240, 96), k) + Vector2(0, sin(k * PI) * 16.0))
		elif u >= 1.0 and title.modulate.a == 0.0:
			whip.clear_points()
			title.modulate.a = 1.0
			Audio.play("whip_crack", 2.0)
			Audio.play("intro_boom", -2.0)
			Fx.add_shake(0.6)
			Fx.sparks(Vector2(240, 96), Vector2.UP, 16, Color("#fff4c8"))
		title.position = Vector2(0, 70) + Fx.offset()
