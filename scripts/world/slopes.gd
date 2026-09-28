class_name Slopes
extends Node2D
## Inclines of any gradient. In a map row, a horizontal run of N "/" (rising to the
## right) or "\" (falling to the right) climbs one tile over N tiles: "/" is 45 degrees,
## "//" about 27, "///" 18, "////" 14. Stack runs row over row for longer hills. Each run
## is one collision triangle; it's drawn with the biome's interior rock texture and a
## pixel-stepped crust along the surface, and occludes light like the tiles do.

const T := 16
const CRUST := {
	"canyon": [Color("#ecc684"), Color("#d6a060"), Color("#b87c45"), Color("#5c3320")],
	"jungle": [Color("#86c24a"), Color("#4f9434"), Color("#2f6a28"), Color("#2c3a30")],
}

var runs: Array = []  # [x0, y, n, rising]
var biome := "canyon"
var _tex: Texture2D


## Finds the runs in `rows` and builds collision + occluders under `into`.
func build(rows: Array, p_biome: String) -> void:
	biome = p_biome
	for y in rows.size():
		var r: String = rows[y]
		var x := 0
		while x < r.length():
			var ch := r[x]
			if ch == "/" or ch == "\\":
				var n := 0
				while x + n < r.length() and r[x + n] == ch:
					n += 1
				runs.append([x, y, n, ch == "/"])
				x += n
			else:
				x += 1
	var atlas := load("res://assets/sprites/%s_tiles.png" % biome) as Texture2D
	var img := atlas.get_image().get_region(Rect2i(15 * T, 0, T, T))
	_tex = ImageTexture.create_from_image(img)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for run in runs:
		var tri := triangle(run)
		var cp := CollisionPolygon2D.new()
		cp.polygon = tri
		body.add_child(cp)
		var occ := LightOccluder2D.new()
		var op := OccluderPolygon2D.new()
		# Inset below the surface so the lit crust isn't in its own shadow.
		var inset := PackedVector2Array()
		for p in tri:
			inset.append(p)
		var hi := 1 if run[3] else 0
		inset[hi] = inset[hi] + Vector2(0, 5)
		inset[1 - hi] = inset[1 - hi] + Vector2(0, 5)
		op.polygon = inset
		occ.occluder = op
		add_child(occ)
	queue_redraw()


## Points: [left-surface, right-surface, bottom corner].
static func triangle(run: Array) -> PackedVector2Array:
	var x0: float = run[0] * T
	var x1: float = (run[0] + run[2]) * T
	var top: float = run[1] * T
	var bot: float = top + T
	if run[3]:
		return PackedVector2Array([Vector2(x0, bot), Vector2(x1, top), Vector2(x1, bot)])
	return PackedVector2Array([Vector2(x0, top), Vector2(x1, bot), Vector2(x0, bot)])


## Surface height of a run at world x (for props and tests).
static func surface_y(run: Array, x: float) -> float:
	var u := clampf((x - run[0] * T) / (run[2] * T), 0.0, 1.0)
	var top: float = run[1] * T
	return top + T * ((1.0 - u) if run[3] else u)


func _draw() -> void:
	var cr: Array = CRUST[biome]
	for run in runs:
		var tri := triangle(run)
		var uv := PackedVector2Array()
		for p in tri:
			uv.append(p / T)
		draw_colored_polygon(tri, Color.WHITE, uv, _tex)
		# Crust: one pixel column at a time so the edge steps like pixel art.
		for i in run[2] * T:
			var x: float = run[0] * T + i
			var sy := floorf(surface_y(run, x + 0.5))
			var depth := 2 + (1 if (i * 7 + run[1] * 3) % 5 == 0 else 0)
			for d in depth:
				draw_rect(Rect2(x, sy + d, 1, 1), cr[mini(d, 2)])
			draw_rect(Rect2(x, sy + depth, 1, 1), cr[3])
