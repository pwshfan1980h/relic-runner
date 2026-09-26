class_name ExitDoor
extends Node2D
## Carved stone doorway marking the end of a level.


func _ready() -> void:
	z_index = -2


func _draw() -> void:
	var stone := Color("#6a5a4a")
	var stone_d := Color("#3a3028")
	draw_rect(Rect2(-10, -30, 20, 30), Color("#0c0808"))
	draw_rect(Rect2(-13, -30, 3, 30), stone)
	draw_rect(Rect2(10, -30, 3, 30), stone_d)
	draw_rect(Rect2(-14, -34, 28, 4), stone)
	draw_rect(Rect2(-2, -33, 4, 2), Color("#c8a040"))
