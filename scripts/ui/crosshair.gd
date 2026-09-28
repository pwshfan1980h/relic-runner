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
	if hero == null:
		return
	var c := hero.whip_candidate
	var col := Color("#f4e4c0")
	if c.size() == 3 and c[0] == Whip.Kind.ACTOR:
		col = Color("#ffc040")
	var dark := Color(0, 0, 0, 0.6)
	# Grenade arc: dotted, with a ring where it first lands.
	if hero.arc.size() == 2:
		var pts: PackedVector2Array = hero.arc[0]
		for i in range(0, pts.size(), 4):
			var p := to_local(pts[i]).round()
			var a := 0.9 - 0.5 * float(i) / pts.size()
			draw_rect(Rect2(p + Vector2(1, 1), Vector2.ONE), Color(0, 0, 0, a * 0.6))
			draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.85, 0.5, a))
		var hit: Vector2 = hero.arc[1]
		if hit != Vector2.INF:
			draw_arc(to_local(hit), 5.0, 0.0, TAU, 12, Color(1.0, 0.5, 0.2, 0.9), 1.0)
			draw_arc(to_local(hit), Grenade.RADIUS * 0.5, 0.0, TAU, 32, Color(1.0, 0.5, 0.2, 0.25), 1.0)
	# Relaxed: a small ring. Aiming: the ring closes into a sight.
	var w := hero.aim_weight()
	var gap := lerpf(4.0, 2.0, w)
	var len := lerpf(1.0, 3.0, w)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = d * gap
		var b: Vector2 = d * (gap + len)
		draw_line(a + Vector2.ONE, b + Vector2.ONE, dark, 1.0)
		draw_line(a, b, Color(col, 0.55 + 0.45 * w), 1.0)
	if w > 0.5:
		draw_rect(Rect2(0, 0, 1, 1), col)
