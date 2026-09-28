extends Node2D
## First scene. Browsers only allow audio after a click or key press, so on the web we
## wait for one over a black screen, then roll the intro. Desktop goes straight to it.
## `-- --bot`, `-- --map <id>` or `?autotest` go straight into a level;
## `-- --gallery` renders the art gallery; `-- --title` skips to the title screen.

var _prompt: Label
var _t := 0.0
var _started := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--gallery"):
		add_child(Gallery.new())
		return
	var direct := args.has("--bot") or args.has("--map")
	if OS.has_feature("web"):
		direct = direct or str(JavaScriptBridge.eval("location.search")).contains("autotest")
	if direct:
		get_tree().change_scene_to_file.call_deferred(GameState.MAIN)
		return
	if args.has("--title"):
		get_tree().change_scene_to_file.call_deferred(GameState.TITLE)
		return
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(480, 270)
	add_child(bg)
	if not OS.has_feature("web"):
		_start()
		return
	_prompt = UI.label(self, "CLICK TO BEGIN", Vector2(0, 128), 8, UI.INK)


func _process(delta: float) -> void:
	_t += delta
	if _prompt:
		_prompt.visible = fmod(_t, 1.0) < 0.65


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	get_tree().change_scene_to_file.call_deferred(GameState.INTRO)
