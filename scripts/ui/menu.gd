extends Node2D
## Level select over the canyon backdrop. Click a level or press its number.

var _items: Array[Label] = []
var _hover := -1
var _options: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in ["canyon_sky", "canyon_mid"]:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % n)
		s.centered = false
		add_child(s)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.04, 0.02, 0.55)
	shade.size = Vector2(480, 270)
	add_child(shade)
	_label("RELIC RUNNER", Vector2(0, 18), 24, Color("#f4e4c0"), 480)
	_label("CHOOSE A TRIAL", Vector2(0, 50), 8, Color("#e8a848"), 480)
	for i in GameState.LEVELS.size():
		var map: Dictionary = Maps.ALL[GameState.LEVELS[i]]
		var biome: String = map["biome"]
		var l := _label("%d   %s" % [i + 1, (map["title"] as String).to_upper()], Vector2(150, 74 + i * 22), 16,
				Color("#f4e4c0"), 260)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label(biome.to_upper(), Vector2(340, 80 + i * 22), 8, Color("#e8a848") if biome == "canyon" else Color("#8cbc6a"), 100)
		_items.append(l)
	_options = _label("", Vector2(0, 232), 8, Color("#e8a848"), 480)
	_label("ESC IN A LEVEL RETURNS HERE   ·   BACKSPACE RESTARTS", Vector2(0, 246), 8, Color(1, 1, 1, 0.5), 480)
	_label("MUSIC: KEVIN MACLEOD (INCOMPETECH.COM) · CC BY 4.0", Vector2(0, 258), 8, Color(1, 1, 1, 0.35), 480)
	_refresh_options()
	Audio.ambience("amb_canyon_loop", -18.0)
	Audio.music("music_menu")


func _refresh_options() -> void:
	_options.text = "G  GORE: %s     M  MUSIC: %d%%     N  SOUND: %d%%" % [
			"ON" if GameState.gore_on else "OFF", roundi(GameState.music_vol * 100), roundi(GameState.sfx_vol * 100)]
	Audio.set_volumes(GameState.music_vol, GameState.sfx_vol)


func _label(text: String, pos: Vector2, size: int, col: Color, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = col
	ls.shadow_color = Color("#1a0e08")
	ls.shadow_offset = Vector2(1, 1)
	l.label_settings = ls
	add_child(l)
	return l


func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	_hover = -1
	for i in _items.size():
		var r := Rect2(_items[i].position - Vector2(8, 2), Vector2(300, 20))
		if r.has_point(m):
			_hover = i
		_items[i].modulate = Color("#ffd070") if i == _hover else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _hover >= 0:
		_pick(_hover)
	elif event is InputEventKey and event.pressed:
		var k: int = (event as InputEventKey).keycode
		if k >= KEY_1 and k < KEY_1 + _items.size():
			_pick(k - KEY_1)
		elif k == KEY_G:
			GameState.gore_on = not GameState.gore_on
			_refresh_options()
		elif k == KEY_M:
			GameState.music_vol = fposmod(GameState.music_vol + 0.25, 1.25)
			_refresh_options()
		elif k == KEY_N:
			GameState.sfx_vol = fposmod(GameState.sfx_vol + 0.25, 1.25)
			_refresh_options()
			Audio.play("gunshot", -6.0)


func _pick(i: int) -> void:
	Audio.play("whip_crack", -4.0)
	GameState.goto(i)
