class_name Crosshair
extends Node2D
## Revolver sight at the mouse. Highlights whatever a right click would grab:
## anchors get a gold ring, whippable actors turn the sight gold.

var hero: Hero


func _ready() -> void:
	z_index = 100
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if hero == null:
		return
	global_position = hero.aim_point().round()
	var c := hero.whip_candidate
	if c.size() == 3 and c[0] == Whip.Kind.ANCHOR and is_instance_valid(c[1]):
		(c[1] as WhipAnchor).highlight = 1.0
	queue_redraw()


func _draw() -> void:
	var c := hero.whip_candidate if hero else []
	var col := Color("#f4e4c0")
	if c.size() == 3 and c[0] == Whip.Kind.ACTOR:
		col = Color("#ffc040")
	var dark := Color(0, 0, 0, 0.6)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = d * 2.0
		var b: Vector2 = d * 5.0
		draw_line(a + Vector2.ONE, b + Vector2.ONE, dark, 1.0)
		draw_line(a, b, col, 1.0)
	draw_rect(Rect2(0, 0, 1, 1), col)
