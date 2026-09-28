class_name UI
extends RefCounted
## Shared look for menus, cards and dialogue: warm parchment ink on dark leather,
## a one-pixel drop shadow, and panels with a brass rule.

const INK := Color("#f4e4c0")
const DIM := Color("#a89878")
const GOLD := Color("#ffc850")
const SHADOW := Color("#140a06")
const PANEL := Color(0.07, 0.04, 0.025, 0.9)
const RULE := Color("#8a6a30")

## Pixel fonts (SIL OFL, see assets/fonts): Tiny5 for body text at 8px, Pixelify Sans for
## titles at 16/32px. Both render crisp only at multiples of 8, so stick to 8, 16 and 32.
static var body: FontFile
static var display: FontFile


## Loads both fonts un-smoothed and makes Tiny5 the default everywhere (labels without a
## font, and every draw_string that uses ThemeDB.fallback_font).
static func setup_fonts() -> void:
	body = _pixel_font("res://assets/fonts/Tiny5-Regular.ttf")
	display = _pixel_font("res://assets/fonts/PixelifySans.ttf")
	ThemeDB.fallback_font = body
	ThemeDB.fallback_font_size = 8


static func _pixel_font(path: String) -> FontFile:
	var f := load(path) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	return f


## The right face for a size: display for headings, body for everything else.
static func font_for(size: int) -> FontFile:
	return display if size >= 16 else body


static func label(parent: Node, text: String, pos: Vector2, size := 8, color := INK, width := 480.0,
		align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, size + 6)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = font_for(size)
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = SHADOW
	ls.shadow_offset = Vector2(2, 2) if size >= 16 else Vector2(1, 1)
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = SHADOW
	l.label_settings = ls
	parent.add_child(l)
	return l


## Word-wrapped paragraph.
static func para(parent: Node, text: String, pos: Vector2, width: float, size := 8, color := INK) -> Label:
	# Wrap must be on before the label is sized or enters the tree, or it grows to one long line.
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	l.position = pos
	l.size = Vector2(width, 120)
	l.custom_minimum_size = Vector2(width, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = font_for(size)
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = SHADOW
	ls.shadow_offset = Vector2(1, 1)
	l.label_settings = ls
	parent.add_child(l)
	l.size = Vector2(width, 120)
	return l


## A dark panel with a brass rule top and bottom.
static func panel(parent: Node, rect: Rect2) -> ColorRect:
	var p := ColorRect.new()
	p.color = PANEL
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	for y in [0.0, rect.size.y - 1.0]:
		var r := ColorRect.new()
		r.color = RULE
		r.position = Vector2(0, y)
		r.size = Vector2(rect.size.x, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(r)
	return p


## A cast member's rig (for portraits and NPCs), dressed from Story.CAST.
static func cast_rig(id: String) -> HeroRig:
	var rig := HeroRig.new()
	if id in ["bandit", "bandit2"]:
		rig.recolor(Bandit.SWAP)
		rig.make_rifle()
		rig.facing = 1
		return rig
	if id == "brute":
		rig.recolor(Brawler.BRUTE_SWAP)
		rig.make_brute_head()
		rig.facing = 1
		return rig
	var c: Dictionary = Story.CAST.get(id, {})
	if c.has("swap"):
		rig.recolor(c["swap"])
	if not c.get("hat", true):
		rig.bones["hat"].visible = false
	rig.size_scale = c.get("scale", 1.0)
	rig.facing = 1
	return rig
