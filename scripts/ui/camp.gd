extends Node2D
## Camp between chapters: night, a campfire, Tomás and his mules. Sell the treasure
## you've carried out, spend gold on upgrades, read the journal pages your relic
## fragments have unlocked, then set out. After the last chapter, the epilogue plays
## here instead and the game returns to the title.

const CAMP_LINES := [
	"Rattler Mesa, eh? The rattlers there are not a figure of speech.",
	"The Esperanza mine... my uncle dug silver there. He said it hums at night.",
	"Six days on a steamer. My mules will never forgive you.",
	"The temple swallows men whole. Buy something that keeps you alive, eh?",
	"The Guardian. Itzel says it has no heart to shoot. Shoot the glyph, then.",
]

var _sky: SkyDome
var _root: Control
var _list: Menus.List
var _gold: Label
var _info: Label
var _fire: PointLight2D
var _t := 0.0
var _rigs: Array = []  # [rig, animator]
var _upgrade_ids: Array = []
var _mode := "main"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	HeroRig.wind = 12.0  # a breeze for coats and hats
	var next_biome := "canyon"
	if not GameState.campaign_over():
		next_biome = Maps.get_map(Story.CHAPTERS[GameState.chapter]["map"])["biome"]
	_sky = SkyDome.new(next_biome, 22.0)
	_sky.speed = 0.0
	add_child(_sky)
	var mod := CanvasModulate.new()
	mod.color = Color(0.35, 0.33, 0.45)
	add_child(mod)
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(0, 270), Vector2(0, 214), Vector2(480, 210), Vector2(480, 270)])
	ground.color = Color("#2a1810")
	add_child(ground)
	_fire = PointLight2D.new()
	_fire.texture = Lights.radial(256)
	_fire.color = Color("#ff9a40")
	_fire.texture_scale = 1.4
	_fire.position = Vector2(340, 200)
	add_child(_fire)
	_add_rig("rook", Vector2(310, 212), 1)
	_add_rig("tomas", Vector2(375, 211), -1)
	Audio.ambience("amb_%s_loop" % next_biome, -18.0)
	Audio.music("music_camp")
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_root = Control.new()
	_root.size = Vector2(480, 270)
	layer.add_child(_root)
	if GameState.campaign_over():
		_ending()
		return
	UI.label(_root, "CAMP", Vector2(20, 18), 16, UI.GOLD, 200, HORIZONTAL_ALIGNMENT_LEFT)
	var nxt: Dictionary = Story.CHAPTERS[GameState.chapter]
	UI.label(_root, "NEXT:  %s  ·  %s" % [nxt["num"], (nxt["title"] as String).to_upper()], Vector2(20, 38), 8, UI.DIM, 300, HORIZONTAL_ALIGNMENT_LEFT)
	_gold = UI.label(_root, "", Vector2(260, 18), 8, UI.GOLD, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	_info = UI.para(_root, "", Vector2(20, 200), 250, 8, Color("#d8c8a0"))
	_list = Menus.List.new()
	_root.add_child(_list)
	_list.size_px = 8
	_list.gap = 14
	_list.chosen.connect(_on_pick)
	_main()
	var line: String = CAMP_LINES[clampi(GameState.chapter - 1, 0, CAMP_LINES.size() - 1)]
	if not OS.get_cmdline_user_args().has("--bot"):
		get_tree().create_timer(0.6).timeout.connect(func(): DialogueBox.play(get_tree(), [["tomas", line]]))


func _add_rig(who: String, pos: Vector2, facing: int) -> void:
	var r := UI.cast_rig(who)
	r.size_scale = 1.6 * Story.CAST[who].get("scale", 1.0)
	r.facing = facing
	r.position = pos
	add_child(r)
	var a := HeroAnims.Animator.new()
	a.play("idle", randf())
	_rigs.append([r, a])


func _refresh_gold() -> void:
	_gold.text = "%d GOLD   ·   TREASURE WORTH %dg   ·   %d FRAGMENTS" % [GameState.gold, GameState.loot_value() - GameState.gold, GameState.fragment_total()]


func _main() -> void:
	_mode = "main"
	_refresh_gold()
	var worth := GameState.loot_value() - GameState.gold
	var items: Array[String] = ["SELL TREASURE  (%dg)" % worth, "OUTFITTER", "JOURNAL", "SET OUT"]
	_list.setup(items, Vector2(20, 64), 220)
	_list.enabled[0] = worth > 0
	_list._refresh()
	_info.text = "Tomás trades gold for gear. Treasure you carry sells here."


func _on_pick(i: int) -> void:
	match _mode:
		"main":
			match i:
				0:
					var v := GameState.sell_all()
					Audio.play("coin_pickup", -2.0, 0.9)
					_info.text = "Tomás weighs every piece twice and pays %d gold. \"A pleasure.\"" % v
					_main()
				1:
					_shop()
				2:
					_journal()
				3:
					GameState.start_chapter()
		"shop":
			if i >= _upgrade_ids.size():
				_main()
				return
			var id: String = _upgrade_ids[i]
			if GameState.buy(id):
				Audio.play("item_pickup", -2.0)
				_info.text = "%s: %s." % [GameState.UPGRADES[id]["name"], GameState.UPGRADES[id]["desc"]]
			else:
				Audio.play("empty_click", -4.0)
				_info.text = "\"Come back when your pockets are heavier, amigo.\""
			var keep := i
			_shop()
			_list.sel = keep
			_list._refresh()
		"journal":
			_info.position.y = 200
			_info.size.x = 250
			_main()


func _shop() -> void:
	_mode = "shop"
	_refresh_gold()
	_upgrade_ids = GameState.UPGRADES.keys()
	var items: Array[String] = []
	for id in _upgrade_ids:
		var u: Dictionary = GameState.UPGRADES[id]
		var lvl := GameState.up(id)
		var costs: Array = u["costs"]
		var price := "SOLD OUT" if lvl >= costs.size() else "%dg" % costs[lvl]
		items.append("%s  %s  ·  %s" % [u["name"].to_upper(), "*".repeat(lvl) + "-".repeat(costs.size() - lvl), price])
	items.append("BACK")
	_list.setup(items, Vector2(20, 64), 300)
	for k in _upgrade_ids.size():
		var costs: Array = GameState.UPGRADES[_upgrade_ids[k]]["costs"]
		var lvl := GameState.up(_upgrade_ids[k])
		_list.enabled[k] = lvl < costs.size() and GameState.gold >= costs[lvl]
	_list._refresh()
	_info.text = "Pick an upgrade. Stars are levels you already own."


func _journal() -> void:
	_mode = "journal"
	var n := GameState.fragment_total()
	var lines: Array[String] = []
	for page in Story.LORE:
		lines.append(("\"%s\"" % page[1]) if n >= page[0] else "(Find %d relic fragments to read this page.)" % page[0])
	_list.setup(["BACK"], Vector2(20, 64), 220)
	_info.text = "\n\n".join(lines)
	_info.position.y = 90
	_info.size.x = 440


func _ending() -> void:
	Audio.music("music_title")
	var lines: Array = Story.EPILOGUE.duplicate()
	var total := GameState.fragment_total()
	var need := Story.CHAPTERS.size() * Story.FRAGMENTS_PER_LEVEL
	if total >= need:
		lines.append(["", "Rook fits the last fragment into place. The Sun Disc is whole, and on its back is a map to a second temple, far to the north..."])
	DialogueBox.play(get_tree(), lines, func():
		UI.label(_root, "THE END", Vector2(0, 90), 32, UI.INK, 480, HORIZONTAL_ALIGNMENT_CENTER, 4)
		UI.label(_root, "RELIC FRAGMENTS  %d / %d" % [total, need], Vector2(0, 136), 8, UI.GOLD)
		UI.label(_root, "THANK YOU FOR PLAYING", Vector2(0, 156), 8, UI.DIM)
		get_tree().create_timer(6.0).timeout.connect(GameState.title))


func _process(delta: float) -> void:
	_t += delta
	_fire.energy = 1.2 + 0.15 * sin(_t * 13.0) + 0.1 * sin(_t * 7.3)
	for r in _rigs:
		(r[0] as HeroRig).apply((r[1] as HeroAnims.Animator).advance(delta), 1)
	queue_redraw()


func _draw() -> void:
	# The fire: stones, logs and flickering flame.
	var c := Vector2(340, 212)
	for i in 6:
		draw_rect(Rect2(c + Vector2(-10 + i * 3.5, -2), Vector2(3, 2)), Color("#5a4a3a"))
	draw_line(c + Vector2(-7, -1), c + Vector2(7, -5), Color("#3a2414"), 2.0)
	draw_line(c + Vector2(-7, -5), c + Vector2(7, -1), Color("#3a2414"), 2.0)
	for k in 3:
		var h := 9.0 + sin(_t * (11.0 + k * 3.0)) * 3.0 - k * 2.5
		var w := 5.0 - k * 1.5
		var col: Color = [Color("#e04a10"), Color("#ff9a20"), Color("#ffe080")][k]
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -2), c + Vector2(w, -2), c + Vector2(sin(_t * 9.0 + k) * 1.5, -2 - h)]), col)
	# Two mules, in silhouette, dozing.
	for m in [Vector2(430, 211), Vector2(456, 212)]:
		draw_rect(Rect2(m + Vector2(-9, -12), Vector2(18, 7)), Color("#140c0a"))
		draw_rect(Rect2(m + Vector2(-12, -15), Vector2(5, 6)), Color("#140c0a"))
		draw_rect(Rect2(m + Vector2(-12, -18), Vector2(1, 3)), Color("#140c0a"))
		for lx in [-8, -4, 4, 8]:
			draw_rect(Rect2(m + Vector2(lx, -5), Vector2(1, 5)), Color("#140c0a"))
