extends Node2D
## Chapter-intro cutscenes, staged in the game's own engine so they match it in every
## way: the live sky at the scene's hour, the biome's backdrop, the cast's own rigs and
## animations, the dialogue box, the pixel fonts, the music. Scripts are JSON in
## res://assets/cutscenes/<chapter>.json (format: tools/cutscene_schema.json), written by
## tools/gen_cutscenes.py with Claude Sonnet 5.5 or by hand. ESC skips.
##
## Step actions: wait (seconds), say (actor, text), caption (text, seconds), walk/run
## (actor to x), face (actor toward x), anim (actor plays clip `text` for seconds),
## sfx (sound `text`), shake (seconds), pan (camera drift to x over seconds).

const DIR := "res://assets/cutscenes/%s.json"
const GROUND_Y := 212.0
const SOUNDS := ["whip_crack", "gunshot", "rifle", "explosion", "splash", "jaguar_growl", "snake_hiss", "stone_grind",
		"slam", "intro_boom", "coin_pickup", "item_pickup", "checkpoint", "gate_rumble", "grenade_pin", "hit_wood", "land"]

var chapter := ""
var _data := {}
var _stage: Node2D
var _sky: SkyDome
var _actors := {}  # id -> [rig, animator]
var _walkers := {}  # id -> [target x, speed]
var _caption: Label
var _fade: ColorRect
var _pan := 0.0
var _pan_to := 0.0
var _pan_speed := 0.0
var _shot_t := 0.0
var _props: Array = []
var _setting := ""
var _leaving := false
var _ground: Node2D


static func path_for(map_id: String) -> String:
	return DIR % map_id


static func exists_for(map_id: String) -> bool:
	return FileAccess.file_exists(path_for(map_id))


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	HeroRig.wind = 30.0
	chapter = Story.CHAPTERS[GameState.chapter]["map"]
	var f := FileAccess.open(path_for(chapter), FileAccess.READ)
	if f == null:
		_finish()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("shots"):
		push_warning("cutscene %s: bad JSON" % chapter)
		_finish()
		return
	_data = parsed
	var hud := CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	for y in [0.0, 240.0]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, y)
		bar.size = Vector2(480, 30)
		hud.add_child(bar)
	_caption = UI.label(hud, "", Vector2(20, 244), 8, Color("#e8d8b0"), 440)
	UI.label(hud, "ESC TO SKIP", Vector2(380, 8), 8, Color(1, 1, 1, 0.35), 94, HORIZONTAL_ALIGNMENT_RIGHT)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_fade)
	Audio.music("music_" + GameState.MUSIC.get(chapter, "canyon"), 0.8)
	_run()


func _run() -> void:
	for shot in _data["shots"]:
		if _leaving:
			return
		_build(shot)
		await _fade_to(0.0)
		for step in shot.get("steps", []):
			if _leaving:
				return
			await _step(step)
		await _settle()
		await _fade_to(1.0)
	_finish()


func _fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, 0.5)
	await tw.finished


## Let walkers arrive before the shot ends.
func _settle() -> void:
	var t := 0.0
	while not _walkers.is_empty() and t < 4.0:
		t += await _frame()
	await get_tree().create_timer(0.6).timeout


func _frame() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _build(shot: Dictionary) -> void:
	if _stage:
		_stage.queue_free()
	if _sky:
		_sky.queue_free()
	_actors.clear()
	_walkers.clear()
	_pan = 0.0
	_pan_to = 0.0
	_caption.text = ""
	_setting = shot.get("setting", "desert_road")
	_props = shot.get("props", [])
	_sky = SkyDome.new(shot.get("biome", "canyon"), float(shot.get("hour", 17.0)))
	_sky.speed = 0.05
	add_child(_sky)
	_stage = Node2D.new()
	add_child(_stage)
	_ground = Node2D.new()
	_ground.draw.connect(_draw_set.bind(_ground))
	_stage.add_child(_ground)
	var dark := _setting in ["mine_tunnel", "temple_hall"]
	if dark or float(shot.get("hour", 17.0)) >= 20.0 or float(shot.get("hour", 17.0)) < 5.5:
		var mod := CanvasModulate.new()
		mod.color = Color(0.45, 0.42, 0.55) if not dark else Color(0.4, 0.34, 0.3)
		_stage.add_child(mod)
	if "campfire" in _props or "lanterns" in _props or dark:
		var l := PointLight2D.new()
		l.texture = Lights.radial(256)
		l.color = Color("#ffa050")
		l.energy = 1.1
		l.texture_scale = 1.6
		l.position = Vector2(240, GROUND_Y - 10)
		_stage.add_child(l)
	for a in shot.get("actors", []):
		_add_actor(a)


func _add_actor(a: Dictionary) -> void:
	var id: String = a.get("id", "rook")
	var rig := UI.cast_rig(id)
	if id == "brute":
		rig.size_scale = 1.25
	rig.size_scale *= 2.0
	rig.facing = int(a.get("facing", 1))
	rig.position = Vector2(float(a.get("x", 240)), GROUND_Y)
	_stage.add_child(rig)
	var an := HeroAnims.Animator.new()
	var clip: String = a.get("clip", "idle")
	an.play(clip if HeroAnims.clips.has(clip) else "idle", 0.0)
	_actors[id] = [rig, an]


func _step(s: Dictionary) -> void:
	var who: String = s.get("actor", "")
	var text: String = s.get("text", "")
	var secs: float = clampf(float(s.get("seconds", 1.0)), 0.0, 8.0)
	match s.get("action", "wait"):
		"wait":
			await get_tree().create_timer(secs).timeout
		"say":
			if text == "":
				return
			var lines := [["" if who == "" or not Story.CAST.has(who) else who, text]]
			var box := DialogueBox.play(get_tree(), lines, Callable(), true)
			while is_instance_valid(box):
				await get_tree().process_frame
		"caption":
			_caption.text = text
			_caption.visible_characters = 0
			var t := 0.0
			while t < maxf(secs, 1.5) and not _leaving:
				t += await _frame()
				_caption.visible_characters = int(t * 50.0)
		"walk", "run":
			if _actors.has(who):
				_walkers[who] = [float(s.get("x", 240)), 88.0 if s["action"] == "walk" else 250.0]
				(_actors[who][1] as HeroAnims.Animator).play(s["action"], 0.1)
		"face":
			if _actors.has(who):
				var r: HeroRig = _actors[who][0]
				r.facing = 1 if float(s.get("x", 240)) >= r.position.x else -1
		"anim":
			if _actors.has(who) and HeroAnims.clips.has(text):
				var an: HeroAnims.Animator = _actors[who][1]
				an.play(text, 0.1, 0.0, true)
				await get_tree().create_timer(maxf(secs, 0.3)).timeout
				an.play("idle", 0.2)
		"sfx":
			if text in SOUNDS:
				Audio.play(text, -4.0)
		"shake":
			Fx.add_shake(clampf(secs, 0.2, 1.0))
		"pan":
			_pan_to = clampf(float(s.get("x", 0.0)), -400.0, 400.0)
			_pan_speed = absf(_pan_to - _pan) / maxf(secs, 0.1)


func _process(delta: float) -> void:
	_shot_t += delta
	for id in _actors:
		var r: HeroRig = _actors[id][0]
		var an: HeroAnims.Animator = _actors[id][1]
		if _walkers.has(id):
			var goal: float = _walkers[id][0]
			var spd: float = _walkers[id][1]
			var d := goal - r.position.x
			r.facing = 1 if d > 0.0 else -1
			r.motion = Vector2(signf(d) * spd * 0.5, 0)
			r.position.x = move_toward(r.position.x, goal, spd * 0.5 * delta)
			if absf(d) < 1.0:
				_walkers.erase(id)
				an.play("idle", 0.15)
				r.motion = Vector2.ZERO
		r.apply(an.advance(delta), 1)
	if is_instance_valid(_ground):
		_ground.queue_redraw()
	_pan = move_toward(_pan, _pan_to, _pan_speed * delta)
	if _stage:
		_stage.position.x = -_pan + Fx.offset().x
	if _sky:
		_sky.cam.x = _pan + _shot_t * 4.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	for d in get_tree().get_nodes_in_group("dialogue"):
		d.queue_free()
	get_tree().change_scene_to_file.call_deferred(GameState.MAIN)


# --- The set: ground and props, flat-shaded like the rest of the game ----------------

func _draw_set(n: Node2D) -> void:
	var dark := Color("#1e100a") if _setting.begins_with("mesa") or _setting in ["desert_road", "mine_mouth", "campfire"] \
			else Color("#0c160e")
	if _setting in ["mine_tunnel", "temple_hall"]:
		dark = Color("#1a120c") if _setting == "mine_tunnel" else Color("#161c16")
		# A ceiling and back wall close in.
		n.draw_rect(Rect2(-400, 0, 1280, 60), dark)
		n.draw_rect(Rect2(-400, 60, 1280, GROUND_Y - 60), dark.lightened(0.12))
		for i in 12:
			n.draw_rect(Rect2(-380 + i * 110, 60, 8, GROUND_Y - 60), dark.lightened(0.05))
	var top := GROUND_Y
	var pts := PackedVector2Array([Vector2(-400, 300)])
	for i in 33:
		var x := -400.0 + i * 40.0
		var y := top + (sin(i * 1.7) * 3.0 if _setting != "mesa_top" else 0.0)
		if _setting == "mesa_foot" and x > 300:
			y -= minf(80.0, (x - 300) * 0.5)
		pts.append(Vector2(x, y))
	pts.append(Vector2(880, 300))
	n.draw_colored_polygon(pts, dark)
	n.draw_polyline(pts.slice(1, pts.size() - 1), dark.lightened(0.25), 1.0)
	if _setting == "mine_mouth":
		# The adit: a timber-framed black hole in the hillside.
		n.draw_colored_polygon(PackedVector2Array([Vector2(360, top), Vector2(372, top - 150), Vector2(700, top - 170), Vector2(700, top)]), dark.lightened(0.08))
		n.draw_rect(Rect2(392, top - 52, 44, 52), Color("#050303"))
		n.draw_rect(Rect2(388, top - 56, 52, 5), Color("#5a3a1c"))
		n.draw_rect(Rect2(388, top - 52, 5, 52), Color("#5a3a1c"))
		n.draw_rect(Rect2(435, top - 52, 5, 52), Color("#5a3a1c"))
	if _setting == "jungle_river":
		n.draw_rect(Rect2(-400, GROUND_Y + 14, 1280, 60), Color("#1a3a44"))
		n.draw_line(Vector2(-400, GROUND_Y + 14), Vector2(880, GROUND_Y + 14), Color("#8ab8c0"), 1.0)
	for p in _props:
		_prop(n, p)


func _prop(n: Node2D, p: String) -> void:
	var g := GROUND_Y
	var sil := Color("#140a06")
	match p:
		"campfire":
			var c := Vector2(240, g)
			for k in 3:
				var h := 10.0 + sin(_shot_t * (11.0 + k * 3.0)) * 3.0 - k * 3.0
				var col: Color = [Color("#e04a10"), Color("#ff9a20"), Color("#ffe080")][k]
				n.draw_colored_polygon(PackedVector2Array([c + Vector2(-6 + k * 2, 0), c + Vector2(6 - k * 2, 0), c + Vector2(sin(_shot_t * 9.0 + k) * 2.0, -h)]), col)
		"mules":
			for m in [Vector2(400, g), Vector2(440, g)]:
				n.draw_rect(Rect2(m + Vector2(-18, -24), Vector2(36, 14)), sil)
				n.draw_rect(Rect2(m + Vector2(-24, -30), Vector2(10, 12)), sil)
				for lx in [-16, -8, 8, 16]:
					n.draw_rect(Rect2(m + Vector2(lx, -10), Vector2(2, 10)), sil)
		"signpost":
			n.draw_rect(Rect2(60, g - 30, 3, 30), Color("#5a3a1c"))
			n.draw_rect(Rect2(44, g - 36, 34, 12), Color("#8a5a30"))
		"lanterns":
			for x in [120.0, 260.0, 380.0]:
				n.draw_line(Vector2(x, 40), Vector2(x, 120), Color("#3b2616"), 1.0)
				n.draw_rect(Rect2(x - 3, 120, 6, 8), Color("#ffe090"))
		"tents":
			n.draw_colored_polygon(PackedVector2Array([Vector2(330, g), Vector2(370, g - 36), Vector2(410, g)]), Color("#a89a70"))
		"crates":
			for x in [300.0, 324.0]:
				n.draw_rect(Rect2(x, g - 22, 22, 22), Color("#8a5a30"))
				n.draw_rect(Rect2(x, g - 22, 22, 22), Color("#3a2410"), false, 1.0)
		"ruins", "watchtower":
			var w := 60.0 if p == "ruins" else 40.0
			var h := 90.0 if p == "ruins" else 150.0
			n.draw_rect(Rect2(380, g - h, w, h), Color("#2a342c") if p == "ruins" else sil)
			for y in range(int(g - h), int(g), 14):
				n.draw_line(Vector2(380, y), Vector2(380 + w, y), Color(0, 0, 0, 0.3), 1.0)
		"idol":
			var c := Vector2(240, g - 40)
			n.draw_rect(Rect2(c.x - 14, g - 26, 28, 26), Color("#3a3a2a"))
			n.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 14), c + Vector2(8, 14), c + Vector2(5, -6), c + Vector2(-5, -6)]), Color("#e0b030"))
			n.draw_circle(c + Vector2(0, -10), 5.0, Color("#f0c840"))
		"boat":
			n.draw_colored_polygon(PackedVector2Array([Vector2(300, g + 10), Vector2(380, g + 10), Vector2(370, g + 22), Vector2(310, g + 22)]), Color("#5a3a1c"))
		"dead_tree":
			n.draw_rect(Rect2(90, g - 70, 6, 70), Color("#8c7a5e"))
			n.draw_line(Vector2(96, g - 50), Vector2(108, g - 62), Color("#8c7a5e"), 2.0)
		"mine_cart":
			n.draw_rect(Rect2(330, g - 18, 30, 14), Color("#4a4a52"))
			n.draw_circle(Vector2(336, g - 3), 3.0, Color("#2a2a30"))
			n.draw_circle(Vector2(354, g - 3), 3.0, Color("#2a2a30"))
