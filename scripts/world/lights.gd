class_name Lights
extends RefCounted
## Shared light textures: radial falloff in a few hard bands for the 90s look.

static var _cache := {}


static func radial(size: int, bands := 6) -> Texture2D:
	var key := "%d_%d" % [size, bands]
	if _cache.has(key):
		return _cache[key]
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	for i in range(1, bands):
		var t := float(i) / bands
		g.add_point(t, Color(1, 1, 1, pow(1.0 - t, 1.6)))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	_cache[key] = tex
	return tex
