class_name WhipAnchor
extends Node2D
## Something the whip can wrap around: an iron ring on a spike (canyon) or a gnarled
## branch (jungle). Hero/Whip find these through the "whip_anchor" group.

var style := "ring"
var chain := 8.0  # px of chain drawn above the ring
var highlight := 0.0  # set by the crosshair when this is the current whip target


func _ready() -> void:
	add_to_group("whip_anchor")
	z_index = 3


func _process(delta: float) -> void:
	highlight = move_toward(highlight, 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var iron := Color("#4a4a52")
	var iron_l := Color("#9a9aa4")
	if style == "branch":
		var bark := Color("#3a2a1a")
		draw_line(Vector2(-10, -4), Vector2(6, 1), bark, 3.0)
		draw_line(Vector2(6, 1), Vector2(12, -2), bark, 2.0)
		draw_rect(Rect2(-2, -1, 2, 1), Color("#6a8a3a"))
		draw_rect(Rect2(8, -3, 2, 1), Color("#6a8a3a"))
	else:
		# Iron ring on a chain from the rock above (spike where it meets the rock).
		var y := -2.0
		while y > -chain:
			draw_rect(Rect2(-0.5 if int(y) % 4 == 0 else -1.0, y - 2, 1 if int(y) % 4 == 0 else 2, 2), iron)
			y -= 2.0
		draw_rect(Rect2(-2, -chain - 1, 4, 3), iron_l)
		draw_arc(Vector2(0, 1), 3.0, 0, TAU, 10, iron, 1.0)
		draw_rect(Rect2(-3, 0, 1, 1), iron_l)
	if highlight > 0.0:
		draw_arc(Vector2.ZERO, 7.0, 0, TAU, 12, Color(1.0, 0.9, 0.5, highlight), 1.0)
