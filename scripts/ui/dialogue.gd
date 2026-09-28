class_name DialogueBox
extends CanvasLayer
## Conversations: a letterboxed box at the bottom with the speaker's animated portrait
## (their own rig, framed close on head and shoulders), name tag, and typewriter text.
## The game pauses while it's open. E, SPACE, ENTER or a click advances (or finishes
## the line being typed). DialogueBox.play(tree, lines, done) from anywhere.

const CPS := 45.0  # characters per second
static var closed_at := -10000  # ticks msec: gameplay ignores the key that closed it

var _lines: Array = []
var _i := 0
var _done := Callable()
var _box: ColorRect
var _frame: ColorRect
var _view: SubViewport
var _rig: HeroRig
var _anim: HeroAnims.Animator
var _name: Label
var _text: Label
var _more: Label
var _typed := 0.0
var _t := 0.0
var _was_paused := false
var auto := false  # test bot: lines advance on their own
var at_top := false  # cutscenes: dock the box at the top, clear of the actors


static func play(tree: SceneTree, lines: Array, done := Callable(), at_top := false) -> DialogueBox:
	var d := DialogueBox.new()
	d.at_top = at_top
	d.auto = OS.get_cmdline_user_args().has("--bot")
	tree.current_scene.add_child(d)
	d._start(lines, done)
	return d


static func active(tree: SceneTree) -> bool:
	return tree.get_first_node_in_group("dialogue") != null


func _ready() -> void:
	add_to_group("dialogue")
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Letterbox bars slide the scene into "cutscene" framing.
	for y in [0.0, 252.0]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, y)
		bar.size = Vector2(480, 18)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	_box = UI.panel(self, Rect2(24, 22 if at_top else 186, 432, 62))
	# The portrait renders in its own little viewport: the rig's layered (z-indexed) parts
	# would escape a plain clip rect.
	_frame = ColorRect.new()
	_frame.color = Color("#2a1a10")
	_frame.position = Vector2(6, 6)
	_frame.size = Vector2(50, 50)
	_box.add_child(_frame)
	var svc := SubViewportContainer.new()
	svc.size = Vector2(50, 50)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(svc)
	_view = SubViewport.new()
	_view.size = Vector2i(50, 50)
	_view.transparent_bg = true
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	svc.add_child(_view)
	_name = UI.label(_box, "", Vector2(64, 5), 8, UI.GOLD, 360, HORIZONTAL_ALIGNMENT_LEFT)
	_text = UI.para(_box, "", Vector2(64, 17), 360)
	_more = UI.label(_box, "E / SPACE", Vector2(330, 49), 8, UI.DIM, 96, HORIZONTAL_ALIGNMENT_RIGHT)
	_anim = HeroAnims.Animator.new()
	_anim.play("idle", 0.0)


func _start(lines: Array, done: Callable) -> void:
	_lines = lines
	_done = done
	_was_paused = get_tree().paused
	get_tree().paused = true
	_i = -1
	_next()


func _next() -> void:
	_i += 1
	if _i >= _lines.size():
		closed_at = Time.get_ticks_msec()
		get_tree().paused = _was_paused
		queue_free()
		if _done.is_valid():
			_done.call()
		return
	var who: String = _lines[_i][0]
	var cast: Dictionary = Story.CAST.get(who, Story.CAST[""])
	_name.text = cast["name"]
	_name.label_settings.font_color = cast["color"]
	_text.text = _lines[_i][1]
	_text.label_settings.font_color = UI.INK if who != "" else Color("#d8c8a0")
	_text.visible_characters = 0
	_typed = 0.0
	if _rig:
		_rig.queue_free()
		_rig = null
	_frame.visible = who != ""
	var x := 64.0 if who != "" else 12.0
	_name.position.x = x
	_text.position.x = x
	_text.size.x = 424.0 - x
	if who != "":
		_rig = UI.cast_rig("rook" if who == "rook" else who)
		_rig.size_scale = 3.2
		_rig.facing = 1
		_rig.position = Vector2(23, 104)
		_view.add_child(_rig)
	Audio.play("item_drop", -16.0, 1.6)


func _process(delta: float) -> void:
	_t += delta
	var total: int = _text.text.length()
	if _typed < total:
		_typed = minf(total, _typed + delta * CPS)
		_text.visible_characters = int(_typed)
		if int(_typed * 0.5) != int((_typed - delta * CPS) * 0.5) and _lines[_i][0] != "":
			Audio.play("step_dirt", -26.0, 2.2, 0.3)  # soft chatter tick
	_more.visible = _typed >= total and fmod(_t, 0.8) < 0.55
	if _rig:
		var pose := _anim.advance(delta)
		# Talking: a little nod while the line types out.
		if _typed < total:
			pose["head"] = pose["head"] + sin(_t * 18.0) * 4.0
		_rig.apply(pose, 1)
	if auto and _typed >= total and fmod(_t, 0.35) < delta:
		_next()


func _input(event: InputEvent) -> void:
	var adv := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		adv = k in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		if k == KEY_ESCAPE:
			# Skip the whole conversation.
			_i = _lines.size() - 1
			adv = true
			_typed = _text.text.length()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		adv = true
	if not adv:
		return
	get_viewport().set_input_as_handled()
	if _typed < _text.text.length():
		_typed = _text.text.length()
		_text.visible_characters = -1
	else:
		_next()
