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


static func label(parent: Node, text: String, pos: Vector2, size := 8, color := INK, width := 480.0,
		align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, size + 6)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
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
	var c: Dictionary = Story.CAST.get(id, {})
	if c.has("swap"):
		rig.recolor(c["swap"])
	if not c.get("hat", true):
		rig.bones["hat"].visible = false
	rig.size_scale = c.get("scale", 1.0)
	rig.facing = 1
	return rig
