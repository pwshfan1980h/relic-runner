class_name ItemArt
extends RefCounted
## Procedural 12x12 item icons. Each kind has a shape template; the material picks a
## 3-tone palette, the seed varies proportions and engraving, gems add a coloured inset.
## A dark outline keeps them readable on any ground. Cached by seed.

const S := 12
const PALETTES := {
	"Tarnished Brass": ["#5a4a20", "#8a7430", "#b8a050"], "Chipped Clay": ["#5a3020", "#8a5030", "#b87850"],
	"Worn Copper": ["#4a2a18", "#8a5030", "#c88050"], "Cracked Bone": ["#6a6250", "#b0a888", "#e0d8c0"],
	"Dented Tin": ["#4a4a50", "#80808a", "#b0b0ba"], "Silver": ["#5a5a64", "#a0a0ac", "#e8e8f0"],
	"Carved Jade": ["#1a4a30", "#2e8050", "#6ac088"], "Polished Bronze": ["#5a3818", "#a06a30", "#e0a860"],
	"Turquoise": ["#1a5a5a", "#30a0a0", "#80e0d8"], "Gold": ["#7a5010", "#d0a020", "#fff080"],
	"Obsidian": ["#101014", "#2a2a36", "#6a6a80"], "Ivory": ["#8a8068", "#d8d0b0", "#fffaf0"],
	"Lapis": ["#10205a", "#2a48a8", "#6a8ae0"], "Sunstone": ["#8a3a08", "#e88a20", "#fff0a0"],
	"Starmetal": ["#2a2a50", "#7a7ac8", "#e0e0ff"], "Blood Gold": ["#5a1010", "#c04020", "#ffc060"],
	"Crystal": ["#406a80", "#90d0e8", "#ffffff"],
}
const GEM_COLORS := {"Ruby": "#e02030", "Emerald": "#20c050", "Sapphire": "#2050e0", "Topaz": "#f0a020",
		"Opal": "#e0e0f8", "Amethyst": "#a040e0"}
const OUTLINE := Color("#140c08")

static var _cache := {}


static func icon(item: Item) -> Texture2D:
	var key := "%s_%d" % [item.kind, item.seed]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = item.seed * 7919 + 13
	var pal: Array = PALETTES.get(item.material, ["#5a4a20", "#8a7430", "#b8a050"]).map(func(h): return Color(h))
	var gem := Color(GEM_COLORS.get(item.gem, "#e02030"))
	match item.kind:
		"gem":
			_gem(img, rng, gem)
		"idol":
			_idol(img, rng, pal, gem, item.rarity)
		"amulet":
			_amulet(img, rng, pal, gem)
		"dagger":
			_dagger(img, rng, pal, gem, item.rarity)
		"scroll":
			_scroll(img, rng)
		"skull":
			_skull(img, rng, pal, gem, item.rarity)
		"key":
			_key(img, rng, pal)
		"coin":
			_coin(img, pal)
		"bandage":
			_bandage(img)
		"grenade":
			_grenade(img)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < S and y < S:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, c)


## Shades a solid shape: light on the upper-left edge, dark on the lower-right.
static func _shade(img: Image, pal: Array) -> void:
	var base: Color = pal[1]
	var src := img.duplicate() as Image
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a == 0.0 or not src.get_pixel(x, y).is_equal_approx(base):
				continue
			var up_left := x == 0 or y == 0 or src.get_pixel(x - 1, y).a == 0.0 or src.get_pixel(x, y - 1).a == 0.0
			var down_right := x == S - 1 or y == S - 1 or src.get_pixel(x + 1, y).a == 0.0 or src.get_pixel(x, y + 1).a == 0.0
			if up_left:
				img.set_pixel(x, y, pal[2])
			elif down_right:
				img.set_pixel(x, y, pal[0])


static func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S and src.get_pixel(q.x, q.y).a > 0.0 \
						and src.get_pixel(q.x, q.y) != OUTLINE:
					img.set_pixel(x, y, OUTLINE)
					break


static func _gem(img: Image, rng: RandomNumberGenerator, gem: Color) -> void:
	var w := rng.randi_range(3, 5)
	var cx := 6
	for y in range(2, 10):
		var half := w - absi(y - 5) * w / 5
		for x in range(cx - half, cx + half):
			_px(img, x, y, gem)
	_shade(img, [gem.darkened(0.4), gem, gem.lightened(0.5)])
	_px(img, cx - 1, 4, Color.WHITE)


static func _idol(img: Image, rng: RandomNumberGenerator, pal: Array, gem: Color, rarity: int) -> void:
	var hw := rng.randi_range(2, 3)
	_rect(img, 6 - hw, 1, hw * 2, 4, pal[1])  # head
	_rect(img, 3, 5, 6, 5, pal[1])  # body
	_rect(img, 2, 10, 8, 2, pal[1])  # plinth
	if rng.randf() < 0.5:
		_rect(img, 2, 6, 1, 3, pal[1])  # arms
		_rect(img, 9, 6, 1, 3, pal[1])
	_shade(img, pal)
	var eye: Color = gem if rarity >= 1 else pal[0]
	_px(img, 5, 3, eye)
	_px(img, 7, 3, eye)
	_rect(img, 5, 7, 2, 1, pal[0])


static func _amulet(img: Image, rng: RandomNumberGenerator, pal: Array, gem: Color) -> void:
	for x in range(2, 10):  # chain, hanging down to the pendant
		_px(img, x, 3 - absi(x - 6) / 2, pal[0])
	var r := rng.randi_range(3, 4)
	for y in S:
		for x in S:
			if Vector2(x - 5.5, y - 7.0).length() < r:
				_px(img, x, y, pal[1])
	_shade(img, pal)
	_rect(img, 5, 6, 2, 2, gem)
	_px(img, 5, 6, gem.lightened(0.5))


static func _dagger(img: Image, rng: RandomNumberGenerator, pal: Array, gem: Color, rarity: int) -> void:
	var steel: Color = Color("#c0c4cc") if rng.randf() < 0.7 else pal[2]
	for i in 7:  # blade, diagonal
		_px(img, 3 + i, 8 - i, steel)
		_px(img, 4 + i, 8 - i, steel.darkened(0.25))
	_px(img, 10, 1, steel)
	_rect(img, 1, 7, 4, 1, pal[1])  # guard
	_rect(img, 3, 5, 1, 4, pal[1])
	_px(img, 1, 10, pal[0])  # grip
	_px(img, 2, 9, pal[0])
	_px(img, 0, 11, gem if rarity >= 1 else pal[2])  # pommel


static func _scroll(img: Image, rng: RandomNumberGenerator) -> void:
	var paper := Color("#e0d0a0")
	_rect(img, 2, 2, 8, 8, paper)
	_rect(img, 1, 1, 10, 1, Color("#8a5a30"))
	_rect(img, 1, 10, 10, 1, Color("#8a5a30"))
	for i in rng.randi_range(2, 4):  # map lines / glyphs
		var y := rng.randi_range(3, 8)
		_rect(img, rng.randi_range(3, 5), y, rng.randi_range(2, 4), 1, Color("#a03020") if i == 0 else Color("#6a5030"))


static func _skull(img: Image, _rng: RandomNumberGenerator, pal: Array, gem: Color, rarity: int) -> void:
	for y in range(1, 8):
		for x in range(2, 10):
			if Vector2(x - 5.5, y - 4.5).length() < 4.2:
				_px(img, x, y, pal[1])
	_rect(img, 4, 8, 4, 3, pal[1])  # jaw
	_shade(img, pal)
	var socket: Color = gem if rarity >= 2 else OUTLINE
	_rect(img, 3, 4, 2, 2, socket)
	_rect(img, 7, 4, 2, 2, socket)
	_px(img, 5, 9, pal[0])
	_px(img, 6, 9, pal[0])


static func _key(img: Image, rng: RandomNumberGenerator, pal: Array) -> void:
	for y in S:
		for x in S:
			var d := Vector2(x - 3.5, y - 3.5).length()
			if d < 3.0 and d > 1.4:
				_px(img, x, y, pal[1])
	for i in 6:
		_px(img, 5 + i, 5 + i, pal[1])
	for t in rng.randi_range(1, 2):
		_px(img, 8 + t, 10 - t, pal[1])
		_px(img, 9 + t, 11 - t, pal[1])
	_shade(img, pal)


static func _coin(img: Image, pal: Array) -> void:
	for y in S:
		for x in S:
			if Vector2(x - 5.5, y - 5.5).length() < 3.6:
				_px(img, x, y, pal[1])
	_shade(img, pal)
	_px(img, 5, 5, pal[2])
	_px(img, 6, 6, pal[0])


static func _bandage(img: Image) -> void:
	_rect(img, 2, 4, 8, 4, Color("#f0ece0"))
	_rect(img, 2, 7, 8, 1, Color("#c8c0b0"))
	_rect(img, 5, 3, 2, 6, Color("#d03030"))
	_rect(img, 4, 5, 4, 2, Color("#d03030"))


static func _grenade(img: Image) -> void:
	for y in range(3, 11):
		for x in range(3, 10):
			var d := Vector2(x - 6, y - 7).length()
			if d < 3.6:
				_px(img, x, y, Color("#5c6a3e") if x + y < 12 else Color("#3e4a2c"))
	_rect(img, 5, 1, 3, 2, Color("#8c8f99"))
	_rect(img, 8, 1, 2, 1, Color("#c0c4cc"))
	_rect(img, 4, 6, 5, 1, Color("#2a321e"))
