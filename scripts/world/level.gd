class_name Level
extends Node2D
## Builds a playable level from a Maps entry: autotiled rock with collision and light
## occluders, cave back walls, parallax backdrop, props, lighting zones, camera, HUD.

signal cleared

const T := 16
const BACKDROP := {
	"canyon": [["canyon_sky", 0.05], ["canyon_mid", 0.25], ["canyon_near", 0.5]],
	"jungle": [["jungle_sky", 0.05], ["jungle_mid", 0.25], ["jungle_near", 0.5]],
}

var map_id := "proving_grounds"
var map: Dictionary
var rows: Array = []
var w := 0
var h := 0
var hero: Hero
var cam: Camera2D
var hud: Hud
var tiles: TileMapLayer
var _ambient: CanvasModulate
var _dark_px: Array[Rect2] = []
var _look := Vector2.ZERO
var _exit_pos := Vector2.INF
var _done := false


func _ready() -> void:
	map_id = GameState.map_id()
	build(map_id)


func build(id: String) -> void:
	map = Maps.ALL[id]
	rows = map["rows"]
	h = rows.size()
	for r in rows:
		w = maxi(w, (r as String).length())
	for r in map.get("dark", []):
		var rect: Rect2i = r
		_dark_px.append(Rect2(rect.position * T, rect.size * T))
	_backdrop(map["biome"])
	_tiles(map["biome"])
	_entities()
	_ambient = CanvasModulate.new()
	_ambient.color = map["ambient"]
	add_child(_ambient)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = w * T
	cam.limit_top = -T * 6
	cam.limit_bottom = h * T
	add_child(cam)
	cam.global_position = hero.global_position
	cam.make_current()
	var cross := Crosshair.new()
	cross.hero = hero
	add_child(cross)
	hud = Hud.new()
	add_child(hud)
	hud.bind(hero, map["title"])
	Audio.ambience("amb_%s_loop" % map["biome"], -16.0)
	Audio.music("music_" + GameState.MUSIC.get(map_id, "canyon"))
	if OS.get_cmdline_user_args().has("--bot"):
		var bot := Bot.new()
		bot.level = self
		add_child(bot)


func cell(x: int, y: int) -> String:
	if x < 0 or x >= w or y >= h:
		return "#"
	if y < 0:
		return "."
	var r: String = rows[y]
	return r[x] if x < r.length() else "."


func solid(x: int, y: int) -> bool:
	return cell(x, y) == "#"


func _mask(x: int, y: int) -> int:
	return int(solid(x, y - 1)) | int(solid(x + 1, y)) << 1 | int(solid(x, y + 1)) << 2 | int(solid(x - 1, y)) << 3


func _tileset(biome: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_occlusion_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/sprites/%s_tiles.png" % biome)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var half := T / 2.0
	var sq := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for m in 16:
		# Occluders are inset on exposed faces: the inside of an occluder is in shadow,
		# so a full square would leave every lit floor surface dark.
		var occ := OccluderPolygon2D.new()
		var x0 := -half + (0.0 if m & 8 else 3.0)
		var x1 := half - (0.0 if m & 2 else 3.0)
		var y0 := -half + (0.0 if m & 1 else 4.0)
		var y1 := half - (0.0 if m & 4 else 3.0)
		occ.polygon = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
		for v in 2:
			var c := Vector2i(m, v)
			src.create_tile(c)
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, sq)
			if m != 15:
				td.set_occluder_polygons_count(0, 1)
				td.set_occluder_polygon(0, 0, occ)
	return ts


func _tiles(biome: String) -> void:
	var ts := _tileset(biome)
	# Back wall inside caves: interior rock, darkened, no collision.
	var back := TileMapLayer.new()
	back.tile_set = ts
	back.collision_enabled = false
	back.occlusion_enabled = false
	back.modulate = Color(0.38, 0.32, 0.34)
	back.z_index = -1
	add_child(back)
	tiles = TileMapLayer.new()
	tiles.tile_set = ts
	add_child(tiles)
	for y in range(-1, h + 2):
		for x in range(-2, w + 2):
			var v := (x * 7 + y * 13) & 1
			if solid(x, y):
				tiles.set_cell(Vector2i(x, y), 0, Vector2i(_mask(x, y), v))
			elif _in_dark(Vector2(x * T + 8, y * T + 8)):
				back.set_cell(Vector2i(x, y), 0, Vector2i(15, v))


func _backdrop(biome: String) -> void:
	var i := 0
	for layer in BACKDROP[biome]:
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(layer[1], 0.0)
		p.repeat_size = Vector2(480, 0)
		p.repeat_times = 3
		p.z_index = -20 + i
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % layer[0])
		s.centered = false
		s.light_mask = 0  # the sky isn't lit by torches or muzzle flashes
		p.add_child(s)
		add_child(p)
		i += 1


func _entities() -> void:
	# The hero first: enemies look them up when they enter the tree.
	for y in h:
		for x in w:
			if cell(x, y) == "P":
				hero = Hero.new()
				hero.position = Vector2(x * T + T / 2.0, (y + 1) * T)
				add_child(hero)
				hero.spawn = hero.position
	if hero == null:
		push_error("map %s has no P" % map_id)
		return
	var biome: String = map["biome"]
	var signs: Array = map.get("signs", [])
	var sign_i := 0
	for y in h:
		for x in w:
			var ch := cell(x, y)
			var base := Vector2(x * T + T / 2.0, (y + 1) * T)
			var node: Node2D = null
			match ch:
				"o":
					var a := WhipAnchor.new()
					a.position = Vector2(base.x, y * T + T / 2.0)
					a.style = "branch" if biome == "jungle" else "ring"
					a.chain = _chain_len(x, y)
					node = a
				"T":
					node = Torch.new()
					node.position = Vector2(base.x, y * T + 14)
				"C":
					node = Crate.new()
					node.position = base - Vector2(0, Crate.SIZE / 2.0)
				"D":
					node = Dummy.new()
				"E":
					_exit_pos = base
					node = ExitDoor.new()
				"^":
					var sp := Hazards.Spikes.new()
					sp.biome = biome
					node = sp
				"c":
					var cr := Hazards.Crumble.new()
					cr.biome = biome
					cr.position = Vector2(x * T, y * T)
					add_child(cr)
					hero.respawned.connect(cr.reset)
				"|":
					if cell(x, y - 1) != "|":
						var g := Hazards.Gate.new()
						var n := 0
						while cell(x, y + n) == "|":
							n += 1
						g.height = n * T
						g.position = Vector2(x * T, y * T)
						add_child(g)
				"_":
					node = Hazards.Plate.new()
				"K":
					node = Hazards.Checkpoint.new()
				"L":
					# Hangs from the rock above, ~3 tiles down so its light reaches the floor.
					var l := Hazards.Lantern.new()
					var up := _chain_len(x, y)
					l.rope = up + 56.0
					l.position = Vector2(base.x, y * T + T / 2.0 - up)
					node = l
				"?":
					var sg := Hazards.Sign.new()
					sg.text = signs[sign_i] if sign_i < signs.size() else ""
					sign_i += 1
					node = sg
				"s":
					node = Scorpion.new()
				"r":
					node = Rattlesnake.new()
				"B":
					node = Bandit.new()
				"J":
					node = Jaguar.new()
				"b", "m":
					var br := Brawler.new()
					br.style = "brute" if ch == "b" else "machete"
					node = br
				"G":
					var gd := Guardian.new()
					gd.defeated.connect(_on_boss_defeated)
					node = gd
			if node:
				if node.position == Vector2.ZERO:
					node.position = base
				add_child(node)


func _on_boss_defeated() -> void:
	hud.banner("THE GUARDIAN FALLS")
	for g in get_tree().get_nodes_in_group("gate"):
		(g as Hazards.Gate).trigger(true)


## Anchors hang on a chain from the rock above, or from off the top of the screen.
func _chain_len(x: int, y: int) -> float:
	for k in range(1, 12):
		if solid(x, y - k):
			return k * T - T / 2.0
		if y - k < 0:
			break
	return (y + 7) * T


func _in_dark(p: Vector2) -> bool:
	for r in _dark_px:
		if r.has_point(p):
			return true
	return false


func _physics_process(delta: float) -> void:
	if hero == null:
		return
	# Camera: follow with a lead toward where the hero is looking (the mouse).
	var aim := hero.aim_point() - hero.global_position
	_look = _look.lerp(Vector2(clampf(aim.x * 0.25, -70, 70), clampf(aim.y * 0.2, -40, 40)), minf(1.0, delta * 4.0))
	var target := hero.global_position + Vector2(0, -24) + _look
	cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-7.0 * delta))
	cam.offset = Fx.offset()
	# Lighting: caves dim the ambient so torches and muzzle flashes carry the scene.
	var want: Color = map["dark_ambient"] if _in_dark(hero.global_position + Vector2(0, -16)) else map["ambient"]
	_ambient.color = _ambient.color.lerp(want, minf(1.0, delta * 3.0))
	if not _done and _exit_pos != Vector2.INF and hero.global_position.distance_to(_exit_pos) < 10.0 \
			and hero.state != Hero.S.DEAD:
		_done = true
		Audio.play("level_clear", -4.0)
		hud.banner("TRIAL COMPLETE")
		cleared.emit()
		if not OS.get_cmdline_user_args().has("--bot"):
			get_tree().create_timer(2.5).timeout.connect(GameState.next)
	# Signposts: show their hint while the hero stands near one.
	var hint := ""
	for sg in get_tree().get_nodes_in_group("sign"):
		if (sg as Node2D).global_position.distance_to(hero.global_position) < 28.0:
			hint = (sg as Hazards.Sign).text
	hud.hint(hint)
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("menu"):
		GameState.menu()
