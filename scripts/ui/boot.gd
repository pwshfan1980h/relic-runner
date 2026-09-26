extends Node2D
## Title card. Browsers only allow audio after a click/keypress, so we wait for one.
## `?autotest` in the web URL, or `-- --bot` on the command line, skips the wait.

const MAIN := "res://scenes/main.tscn"
const MENU := "res://scenes/menu.tscn"

var _t := 0.0
var _prompt: Label
var _rig: HeroRig
var _anim: HeroAnims.Animator
var _started := false


func _ready() -> void:
	var sky := Sprite2D.new()
	sky.texture = load("res://assets/sprites/canyon_sky.png")
	sky.centered = false
	add_child(sky)
	var mid := Sprite2D.new()
	mid.texture = load("res://assets/sprites/canyon_mid.png")
	mid.centered = false
	add_child(mid)
	var rock := Polygon2D.new()
	rock.polygon = PackedVector2Array([Vector2(300, 270), Vector2(318, 214), Vector2(360, 206), Vector2(410, 212), Vector2(430, 270)])
	rock.color = Color("#2a150d")
	add_child(rock)
	_rig = HeroRig.new()
	_rig.position = Vector2(362, 207)
	_rig.scale = Vector2(-2, 2)
	add_child(_rig)
	_anim = HeroAnims.Animator.new()
	_anim.play("idle", 0.0)
	_label("RELIC RUNNER", Vector2(0, 58), 32, Color("#f4e4c0"))
	_label("A 90s-STYLE WHIP & REVOLVER PLATFORMER", Vector2(0, 98), 8, Color("#5a2e22"))
	_prompt = _label("CLICK TO START", Vector2(0, 150), 8, Color("#f4e4c0"))
	var args := OS.get_cmdline_user_args()
	if args.has("--gallery"):
		add_child(Gallery.new())
		return
	var auto := args.has("--bot") or args.has("--shot") or args.has("--map")
	if OS.has_feature("web"):
		auto = auto or str(JavaScriptBridge.eval("location.search")).contains("autotest")
	if auto:
		get_tree().create_timer(0.3).timeout.connect(_start)


func _label(text: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(480, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = col
	ls.shadow_color = Color("#1a0e08") if col.v > 0.5 else Color(0, 0, 0, 0)
	ls.shadow_offset = Vector2(2, 2) if size > 16 else Vector2(1, 1)
	l.label_settings = ls
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	_prompt.visible = fmod(_t, 1.0) < 0.65
	_rig.apply(_anim.advance(delta), 1)


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	Audio.play("whip_crack", -4.0)
	var args := OS.get_cmdline_user_args()
	var direct := args.has("--bot") or args.has("--map")
	get_tree().change_scene_to_file.call_deferred(MAIN if direct else MENU)
