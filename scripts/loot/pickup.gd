class_name Pickup
extends Node2D
## Loot on the ground: bursts out of a fallen enemy, bounces, glints, drifts to the
## hero when close, and is collected by walking over it. Hover the mouse over it to
## read its name (in its rarity colour).

const GRAVITY := 600.0
const MAGNET := 36.0
const GRAB := 9.0

var item: Item
var velocity := Vector2.ZERO
var _t := 0.0
var _tex: Texture2D
var _resting := false
var _hover := false


## Scatter a loot table's worth of pickups from `at`.
## table: {"coins": [min, max], "items": chance, "item_rolls": n, "bandage": chance, "luck": 0..1, "min_rarity": n}
static func drop(into: Node, at: Vector2, table: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pieces: Array[Item] = []
	var coins: Array = table.get("coins", [0, 0])
	for i in rng.randi_range(coins[0], coins[1]):
		pieces.append(_simple("coin", "Gold Coin", "Gold", rng.randi_range(1, 3)))
	for i in table.get("item_rolls", 1):
		if rng.randf() < table.get("items", 0.0):
			pieces.append(Item.generate(rng.randi(), table.get("luck", 0.0), table.get("min_rarity", 0)))
	if rng.randf() < table.get("bandage", 0.0):
		pieces.append(_simple("bandage", "Field Bandage", "", 0))
	for it in pieces:
		var p := Pickup.new()
		p.item = it
		p.position = at
		p.velocity = Vector2(rng.randf_range(-70, 70), rng.randf_range(-190, -110))
		into.add_child.call_deferred(p)


static func _simple(kind: String, name: String, material: String, value: int) -> Item:
	var it := Item.new()
	it.kind = kind
	it.name = name
	it.material = material
	it.value = value
	it.seed = 1 if kind == "coin" else 2
	return it


func _ready() -> void:
	add_to_group("loot")
	z_index = 6
	_tex = ItemArt.icon(item)


func _physics_process(delta: float) -> void:
	_t += delta
	var hero := get_tree().get_first_node_in_group("hero") as Hero
	var to_hero := Vector2.INF
	if hero and hero.state != Hero.S.DEAD:
		to_hero = hero.global_position + Vector2(0, -10) - global_position
	# Magnet: once it's settled (or close), slide into the hero's pockets.
	if _t > 0.35 and to_hero.length() < MAGNET:
		global_position += to_hero.normalized() * minf(to_hero.length(), 140.0 * delta)
		if to_hero.length() < GRAB:
			_collect(hero)
		queue_redraw()
		return
	if not _resting:
		velocity.y += GRAVITY * delta
		var next := global_position + velocity * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, next + Vector2(0, 5) * signf(velocity.y), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if hit:
			if absf(hit.normal.y) > 0.5:
				global_position = hit.position + hit.normal * 5.0
				velocity = Vector2(velocity.x * 0.5, -velocity.y * 0.3)
				if absf(velocity.y) < 30.0 and hit.normal.y < 0.0:
					_resting = true
					Audio.play_at("coin_drop" if item.kind == "coin" else "item_drop", global_position, -12.0, 0.2)
			else:
				velocity.x = -velocity.x * 0.4
		else:
			global_position = next
	# Hover: the mouse is over the icon.
	var mouse := get_global_mouse_position()
	var h := mouse.distance_to(global_position) < 8.0
	if h != _hover:
		_hover = h
	queue_redraw()
	if _t > 90.0:
		queue_free()


func _collect(hero: Hero) -> void:
	match item.kind:
		"coin":
			GameState.add_gold(item.value)
			Audio.play("coin_pickup", -8.0, 1.0, 0.1)
		"bandage":
			hero.heal(1)
			Audio.play("item_pickup", -6.0)
		_:
			GameState.add_item(item)
			Audio.play("item_pickup", -4.0, 1.0 + item.rarity * 0.08)
	Fx.float_text(global_position + Vector2(0, -8), item.name if item.kind != "coin" else "+%d" % item.value, item.color() if item.kind != "coin" else Color("#ffd040"))
	queue_free()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 1.0 if _resting else 0.0
	draw_texture(_tex, Vector2(-6, -6 + bob).round())
	# Glint: rarer things sparkle more often.
	var every: float = [2.4, 1.8, 1.2, 0.6][item.rarity]
	var g := fmod(_t, every)
	if g < 0.18 and item.kind != "bandage":
		var c: Color = item.color() if item.rarity > 0 else Color.WHITE
		var s := 1.0 + (g / 0.18) * 2.0
		draw_line(Vector2(3 - s, -4 + bob), Vector2(3 + s, -4 + bob), c, 1.0)
		draw_line(Vector2(3, -4 - s + bob), Vector2(3, -4 + s + bob), c, 1.0)
	if _hover:
		var font := ThemeDB.fallback_font
		var text := item.name + ("" if item.kind in ["coin", "bandage"] else "  (%s)" % Item.RARITY_NAMES[item.rarity])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var pos := Vector2(-w / 2.0, -12).round()
		draw_rect(Rect2(pos + Vector2(-2, -8), Vector2(w + 4, 11)), Color(0.05, 0.03, 0.02, 0.8))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, item.color() if item.kind != "coin" else Color("#ffd040"))
