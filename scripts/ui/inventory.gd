class_name InventoryScreen
extends CanvasLayer
## Tab / I: the loot you're carrying, as plain text. Grouped by rarity (rarest first),
## names in rarity colours, with counts and values. Pauses the game while open.

var _panel: ColorRect
var _text: RichTextLabel


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color(0.06, 0.035, 0.02, 0.92)
	_panel.position = Vector2(40, 22)
	_panel.size = Vector2(400, 226)
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.position = Vector2(52, 30)
	_text.size = Vector2(376, 212)
	_text.add_theme_font_size_override("normal_font_size", 8)
	_text.add_theme_font_size_override("bold_font_size", 8)
	_text.add_theme_color_override("default_color", Color("#f4e4c0"))
	_text.scroll_active = true
	add_child(_text)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_HIDDEN
	if visible:
		_refresh()
		Audio.play("item_drop", -8.0)


func _refresh() -> void:
	var lines: PackedStringArray = []
	lines.append("[b]SATCHEL[/b]                                   [color=#ffd040]%d GOLD[/color]   ·   HAUL WORTH %dg" % [GameState.gold, GameState.loot_value()])
	lines.append("")
	if GameState.inventory.is_empty():
		lines.append("[color=#a09070]Nothing yet. Enemies drop loot; walk over it to pick it up.[/color]")
	for rarity in [3, 2, 1, 0]:
		var group := GameState.inventory.filter(func(e): return e["rarity"] == rarity)
		if group.is_empty():
			continue
		var col: String = Item.RARITY_COLORS[rarity].to_html(false)
		lines.append("[color=#%s]— %s —[/color]" % [col, Item.RARITY_NAMES[rarity].to_upper()])
		group.sort_custom(func(a, b): return a["value"] > b["value"])
		for e in group:
			var count := "" if e["count"] == 1 else "  x%d" % e["count"]
			lines.append("  [color=#%s]%s[/color]%s   [color=#a09070]%s · %dg[/color]" % [col, e["name"], count, e["kind"], e["value"]])
		lines.append("")
	lines.append("[color=#806850]TAB / I TO CLOSE[/color]")
	_text.text = "\n".join(lines)
