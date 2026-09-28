class_name Menus
extends RefCounted
## Menu widgets shared by the title screen and the in-game overlays.


## A vertical list of options: mouse hover/click, W/S or arrows + ENTER/E/SPACE.
class List:
	extends Control
	signal chosen(index: int)
	var items: Array[String] = []
	var sel := 0
	var enabled: Array[bool] = []
	var size_px := 16
	var gap := 20
	var _labels: Array[Label] = []

	func setup(p_items: Array[String], pos: Vector2, width := 480.0) -> void:
		items = p_items
		position = pos
		size = Vector2(width, gap * items.size())
		process_mode = Node.PROCESS_MODE_ALWAYS
		for c in _labels:
			c.queue_free()
		_labels.clear()
		enabled.clear()
		for i in items.size():
			_labels.append(UI.label(self, items[i], Vector2(0, i * gap), size_px, UI.INK, width))
			enabled.append(true)
		sel = 0
		_refresh()

	func set_text(i: int, text: String) -> void:
		items[i] = text
		_labels[i].text = text

	func _refresh() -> void:
		for i in _labels.size():
			var on := i == sel
			_labels[i].label_settings = _labels[i].label_settings.duplicate()
			_labels[i].label_settings.font_color = UI.GOLD if on else (UI.INK if enabled[i] else UI.DIM)
			_labels[i].text = ("-  %s  -" % items[i]) if on else items[i]

	func _move(d: int) -> void:
		sel = posmod(sel + d, items.size())
		Audio.play("step_dirt", -10.0, 1.8)
		_refresh()

	func _pick() -> void:
		if not enabled[sel]:
			Audio.play("empty_click", -6.0)
			return
		Audio.play("whip_crack", -8.0, 1.2)
		chosen.emit(sel)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if event is InputEventMouseMotion:
			var m := get_local_mouse_position()
			var i := int(m.y / gap)
			if m.y >= 0 and i < items.size() and i != sel and absf(m.x - size.x / 2) < 110:
				sel = i
				_refresh()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var m := get_local_mouse_position()
			if m.y >= 0 and int(m.y / gap) < items.size() and absf(m.x - size.x / 2) < 110:
				sel = int(m.y / gap)
				get_viewport().set_input_as_handled()
				_pick()
		elif event is InputEventKey and event.pressed and not event.echo:
			match (event as InputEventKey).physical_keycode:
				KEY_W, KEY_UP:
					_move(-1)
				KEY_S, KEY_DOWN:
					_move(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
					get_viewport().set_input_as_handled()
					_pick()


## Controls and tips, as the player sees them.
class HowToPlay:
	extends Control
	signal closed
	const CONTROLS := [
		["A / D", "Walk   (hold SHIFT to run)"],
		["SPACE", "Jump. Running jumps go further; jump at a ledge to grab it"],
		["W / S", "Climb up / drop from a ledge.  Reel in / pay out the whip"],
		["RIGHT MOUSE", "Hold to raise the revolver and aim"],
		["LEFT MOUSE", "Fire. From the hip it's a quick-draw: slower, looser"],
		["R", "Whip at the cursor: swing on rings and branches, yank foes"],
		["Q", "Tap: lob a grenade.  Hold: aim along the arc, release to throw"],
		["X", "Reload (six rounds)"],
		["E", "Punch (press again to combo).  Talk, next to a friend"],
		["F", "Front kick: knocks foes off ledges, fells dead trees, cracks walls"],
		["C", "Crouch: rifle shots fly over you"],
		["TAB", "Satchel (loot)          ESC  Pause"],
	]
	const TIPS := [
		"Skids: let go of A/D at a run and you'll slide. Plan your stops.",
		"Grenades bounce and roll downhill. Mind the blast: it hurts you too.",
		"Every level hides three relic fragments. Tomas buys treasure and sells gear at camp.",
	]

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		size = Vector2(480, 270)
		UI.panel(self, Rect2(20, 12, 440, 246))
		UI.label(self, "HOW TO PLAY", Vector2(0, 18), 16, UI.GOLD)
		for i in CONTROLS.size():
			var y := 44 + i * 13
			UI.label(self, CONTROLS[i][0], Vector2(34, y), 8, UI.GOLD, 90, HORIZONTAL_ALIGNMENT_RIGHT)
			UI.label(self, CONTROLS[i][1], Vector2(134, y), 8, UI.INK, 320, HORIZONTAL_ALIGNMENT_LEFT)
		for i in TIPS.size():
			UI.label(self, TIPS[i], Vector2(30, 206 + i * 11), 8, UI.DIM, 420)
		UI.label(self, "ESC / CLICK TO GO BACK", Vector2(0, 243), 8, UI.DIM)

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		var close: bool = event is InputEventMouseButton and event.pressed
		close = close or event is InputEventKey and event.pressed and not event.echo \
				and (event as InputEventKey).physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_E]
		if close:
			get_viewport().set_input_as_handled()
			closed.emit()
			queue_free()


## Esc in a level: resume, controls, options, restart the level, quit to the title.
class Pause:
	extends CanvasLayer
	var _root: Control
	var _list: List
	var _opts: List

	func _ready() -> void:
		layer = 40
		process_mode = Node.PROCESS_MODE_ALWAYS
		_root = Control.new()
		_root.size = Vector2(480, 270)
		add_child(_root)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.55)
		shade.size = Vector2(480, 270)
		_root.add_child(shade)
		UI.label(_root, "PAUSED", Vector2(0, 44), 32, UI.GOLD)
		_list = List.new()
		_root.add_child(_list)
		_list.setup(["RESUME", "HOW TO PLAY", "OPTIONS", "RESTART CHAPTER", "QUIT TO TITLE"], Vector2(0, 96))
		_list.chosen.connect(_on_pick)
		_root.visible = false

	func toggle() -> void:
		if DialogueBox.active(get_tree()):
			return
		_root.visible = not _root.visible
		get_tree().paused = _root.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _root.visible else Input.MOUSE_MODE_HIDDEN
		if _root.visible:
			_list.sel = 0
			_list._refresh()
			Audio.play("item_drop", -8.0)

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("menu") and (_opts == null or not is_instance_valid(_opts)):
			get_viewport().set_input_as_handled()
			toggle()

	func _on_pick(i: int) -> void:
		match i:
			0:
				toggle()
			1:
				_list.visible = false
				var h := HowToPlay.new()
				add_child(h)
				h.closed.connect(func(): _list.visible = true)
			2:
				_options()
			3:
				get_tree().paused = false
				GameState.start_chapter()
			4:
				GameState.title()

	func _options() -> void:
		_list.visible = false
		_opts = Menus.options_list(_root, Vector2(0, 96))
		_opts.chosen.connect(func(k):
			if k == 3:
				_opts.queue_free()
				_list.visible = true)


## Gore / music / sound toggles (+ back). Shared by title and pause.
static func options_list(parent: Node, pos: Vector2) -> List:
	var l := List.new()
	parent.add_child(l)
	var texts := func() -> Array[String]:
		return ["GORE: %s" % ("ON" if GameState.gore_on else "OFF"), "MUSIC: %d%%" % roundi(GameState.music_vol * 100),
				"SOUND: %d%%" % roundi(GameState.sfx_vol * 100), "BACK"]
	l.setup(texts.call(), pos)
	l.chosen.connect(func(k):
		match k:
			0:
				GameState.gore_on = not GameState.gore_on
			1:
				GameState.music_vol = fposmod(GameState.music_vol + 0.25, 1.25)
			2:
				GameState.sfx_vol = fposmod(GameState.sfx_vol + 0.25, 1.25)
				Audio.play("gunshot", -6.0)
		GameState.save_settings()
		var t: Array[String] = texts.call()
		for j in 3:
			l.set_text(j, t[j])
		l._refresh())
	return l


## Chapter title over black at the start of a level; any key or 5s moves on.
class ChapterCard:
	extends CanvasLayer
	var chapter: Dictionary
	var _t := 0.0
	var _root: Control
	var _leaving := false

	func _ready() -> void:
		layer = 35
		process_mode = Node.PROCESS_MODE_ALWAYS
		_root = Control.new()
		_root.size = Vector2(480, 270)
		add_child(_root)
		var bg := ColorRect.new()
		bg.color = Color("#0a0604")
		bg.size = Vector2(480, 270)
		_root.add_child(bg)
		UI.label(_root, chapter["num"], Vector2(0, 76), 8, UI.GOLD)
		UI.label(_root, (chapter["title"] as String).to_upper(), Vector2(0, 86), 32, UI.INK)
		var rule := ColorRect.new()
		rule.color = UI.RULE
		rule.position = Vector2(200, 124)
		rule.size = Vector2(80, 1)
		_root.add_child(rule)
		var p := UI.para(_root, chapter["card"], Vector2(90, 136), 300, 8, Color("#d8c8a0"))
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.modulate.a = 0.0
		get_tree().paused = true
		Audio.play("intro_boom", -6.0)

	func _process(delta: float) -> void:
		_t += delta
		if _leaving:
			_root.modulate.a -= delta * 1.5
			if _root.modulate.a <= 0.0:
				queue_free()
			return
		_root.modulate.a = minf(1.0, _t * 1.5)
		if _t > 6.0:
			_leave()

	func _leave() -> void:
		if _leaving:
			return
		_leaving = true
		get_tree().paused = false

	func _input(event: InputEvent) -> void:
		if _t > 0.6 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
			get_viewport().set_input_as_handled()
			_leave()


## End of a chapter: how it went, then on to camp.
class Summary:
	extends CanvasLayer
	var map := ""
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		layer = 36
		process_mode = Node.PROCESS_MODE_ALWAYS
		var root := Control.new()
		root.size = Vector2(480, 270)
		add_child(root)
		UI.panel(root, Rect2(110, 46, 260, 178))
		UI.label(root, "CHAPTER COMPLETE", Vector2(0, 56), 16, UI.GOLD)
		var run := GameState.run
		var secs := int((Time.get_ticks_msec() - int(run.get("t0", 0))) / 1000.0)
		var frags: int = (GameState.fragments.get(map, []) as Array).size()
		var rows := [
			["TIME", "%d:%02d" % [secs / 60, secs % 60]],
			["FOES BESTED", str(run.get("kills", 0))],
			["GOLD FOUND", "%d g" % run.get("gold", 0)],
			["RELIC FRAGMENTS", "%d / %d" % [frags, Story.FRAGMENTS_PER_LEVEL]],
			["FALLS", str(run.get("deaths", 0))],
		]
		for i in rows.size():
			UI.label(root, rows[i][0], Vector2(130, 90 + i * 18), 8, UI.DIM, 110, HORIZONTAL_ALIGNMENT_LEFT)
			UI.label(root, rows[i][1], Vector2(240, 88 + i * 18), 16 if i == 3 else 8, UI.INK, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		UI.label(root, "PRESS E OR CLICK TO MAKE CAMP", Vector2(0, 204), 8, UI.GOLD)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if OS.get_cmdline_user_args().has("--bot"):
			get_tree().create_timer(0.5).timeout.connect(_go)

	func _process(delta: float) -> void:
		_t += delta

	func _input(event: InputEvent) -> void:
		if _t > 0.8 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
			get_viewport().set_input_as_handled()
			_go()

	func _go() -> void:
		if _done:
			return
		_done = true
		if OS.get_cmdline_user_args().has("--bot"):
			return  # the bot reports and quits on its own
		GameState.level_done()
