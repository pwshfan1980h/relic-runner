class_name Gallery
extends Node
## Renders animation contact sheets / frame strips of the hero rig at true game
## resolution (1x), upscaled with nearest-neighbour. Needs a real renderer (not --headless):
##   godot --path . -- --gallery <out_dir> [--frames]
## Writes <out_dir>/sheet.png (every clip, 6 samples) and with --frames, per-clip
## frame strips <clip>.png (12 fps) for the art bible.

const CELL := Vector2i(56, 56)
const SCALE := 4
const SAMPLES := 6
const FPS := 12.0
const BG := Color("#2a1c14")
const FLOOR := Color("#5c3320")

var out_dir := "user://gallery"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--gallery")
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	HeroAnims.build()
	await _sheet()
	if args.has("--frames"):
		for name in HeroAnims.clips:
			await _strip(name)
	print("gallery written to ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = size
	vp.add_child(bg)
	return vp


func _cell_rig(vp: SubViewport, origin: Vector2, pose: Dictionary, lock: int) -> void:
	var fl := ColorRect.new()
	fl.color = FLOOR
	fl.position = origin + Vector2(-CELL.x / 2.0 + 2, 0)
	fl.size = Vector2(CELL.x - 4, 2)
	vp.add_child(fl)
	var rig := HeroRig.new()
	rig.position = origin
	vp.add_child(rig)
	rig.apply(pose, lock)


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	vp.queue_free()


func _sheet() -> void:
	var names: Array = HeroAnims.clips.keys()
	var vp := _viewport(Vector2i(CELL.x * SAMPLES, CELL.y * names.size()))
	for r in names.size():
		var c: Dictionary = HeroAnims.clips[names[r]]
		for s in SAMPLES:
			var t: float = c["len"] * s / (SAMPLES - (0 if c["loop"] else 1))
			var origin := Vector2(CELL.x * s + CELL.x / 2.0, CELL.y * r + CELL.y - 8)
			_cell_rig(vp, origin, HeroAnims.sample(c, t), c["lock"])
	await _save(vp, out_dir.path_join("sheet.png"))
	var f := FileAccess.open(out_dir.path_join("sheet.txt"), FileAccess.WRITE)
	f.store_string("\n".join(names))


func _strip(name: String) -> void:
	var c: Dictionary = HeroAnims.clips[name]
	var n := maxi(2, int(ceil(c["len"] * FPS)) + (0 if c["loop"] else 1))
	var vp := _viewport(Vector2i(CELL.x * n, CELL.y))
	for k in n:
		var t := minf(k / FPS, c["len"])
		_cell_rig(vp, Vector2(CELL.x * k + CELL.x / 2.0, CELL.y - 8), HeroAnims.sample(c, t), c["lock"])
	await _save(vp, out_dir.path_join(name + ".png"))
