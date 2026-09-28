class_name Water
extends Node2D
## A body of water: one connected region of water cells with a single surface level.
## Each 16px column has its own top and bottom, so water under an overhanging rock is
## part of the same body (no false surface down there) and pools can have uneven floors.
## It owns:
##   - a spring-mesh surface (one spring every 4px, neighbours spread the motion), drawn
##     with a bright lip; anything crossing it splashes and makes waves
##   - the body: a shader that refracts and tints whatever is behind and inside the water
##     (the hero included), darker with depth, in flat bands to match the art
##   - buoyancy for loose physics bodies by density: crates float, grenades sink slowly,
##     corpses bob
## The hero and enemies ask Water.at(point) and handle swimming/drowning themselves.
## See docs/spikes/water.md.

const SPACING := 4.0
const K := 110.0  # spring stiffness
const DAMP := 9.0  # heavily damped: water settles, it doesn't trampoline
const SPREAD := 0.22
## Density per body kind (1 = neutral). Lower floats higher.
const DENSITY := {"crate": 0.55, "grenade": 2.6, "corpse": 0.92, "other": 1.2}

var rect := Rect2()  # world-space bounds; rect.position.y is the resting surface
## Tile column -> [top px, bottom px, open to the air]. Covered columns (under rock) have
## no waves and no surface of their own.
var cols := {}
const COL := 16.0
var _h := PackedFloat32Array()
var _v := PackedFloat32Array()
var _area: Area2D
var _inside := {}  # body -> was submerged last tick (for splashes)
var _lip: Node2D
var _deep: Node2D  # the underwater world, drawn behind swimmers
var _t := 0.0
var _max_wave := 3.0  # waves never taller than this (or than a third of the depth)

## Behind the swimmers: a soft, blurred underwater world, painted procedurally from world
## coordinates so it never repeats: murky navy depths, brown rock and weed shapes, pale
## coral heads near the floor, faint light shafts from the surface.
const DEEP_SHADER := """
shader_type canvas_item;
uniform float time;
uniform float surface;
uniform float depth_px;
varying vec2 world;
void vertex() { world = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.1 + 7.0) * 0.3 + noise(p * 4.3 + 3.0) * 0.15; }
void fragment() {
	vec2 w = floor(world);
	float d = clamp((w.y - surface) / max(depth_px, 1.0), 0.0, 1.0);
	// Murky depths: dark blue, darker further down.
	vec3 col = mix(vec3(0.07, 0.16, 0.24), vec3(0.02, 0.05, 0.1), d);
	// Distant blue-black rock masses.
	float rock = fbm(w * vec2(0.018, 0.03));
	col = mix(col, vec3(0.03, 0.07, 0.12), smoothstep(0.5, 0.62, rock) * 0.8);
	// Brown rock and weed shapes, more of them toward the floor.
	float brown = fbm(w * vec2(0.035, 0.05) + 20.0);
	col = mix(col, vec3(0.2, 0.14, 0.09), smoothstep(0.55, 0.68, brown) * (0.35 + d * 0.5));
	float weed = noise(vec2(w.x * 0.22, w.y * 0.03 - time * 0.15 + sin(w.y * 0.08 + time) * 0.6));
	col = mix(col, vec3(0.12, 0.16, 0.08), smoothstep(0.72, 0.8, weed) * d * 0.7);
	// Pale coral heads on the bottom.
	float coral = fbm(w * 0.09 + 50.0);
	col = mix(col, vec3(0.78, 0.74, 0.64), smoothstep(0.66, 0.74, coral) * smoothstep(0.55, 0.95, d) * 0.55);
	// Light shafts from the surface, fading with depth.
	float shaft = noise(vec2(w.x * 0.04 + w.y * 0.02 + time * 0.1, 0.0));
	col += vec3(0.1, 0.15, 0.16) * smoothstep(0.6, 0.9, shaft) * (1.0 - d);
	// Banded, like the rest of the art.
	col = floor(col * 28.0 + 0.5) / 28.0;
	COLOR = vec4(col, 1.0);
}
"""

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 shallow : source_color = vec4(0.3, 0.55, 0.6, 1.0);
uniform vec4 deep : source_color = vec4(0.05, 0.14, 0.2, 1.0);
uniform float time;
uniform float depth_px;
void fragment() {
	// UV.y: 0 at the surface, 1 at the bottom. Refract in whole pixels: wobble sideways.
	vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
	float wob = floor(sin(SCREEN_UV.y / px.y * 0.18 + time * 3.0) * 1.6 + 0.5);
	vec3 behind = texture(screen_tex, SCREEN_UV + vec2(wob * px.x, 0.0)).rgb;
	float d = clamp(UV.y * depth_px / 90.0, 0.0, 1.0);
	d = floor(d * 4.0) / 4.0;  // banded
	vec3 tint = mix(shallow.rgb, deep.rgb, d);
	// Clear near the surface (the rock and the swimmer show through), murkier with depth.
	vec3 col = mix(behind * mix(vec3(1.0), tint * 1.8, 0.4), tint, 0.1 + d * 0.3);
	COLOR = vec4(col, 1.0);
}
"""


static func at(tree: SceneTree, p: Vector2) -> Water:
	for w in tree.get_nodes_in_group("water"):
		if (w as Water).contains(p):
			return w
	return null


## surface: resting surface y (px). p_cols: tile column -> [top px, bottom px, open].
func _init(surface := 0.0, p_cols := {}) -> void:
	cols = p_cols
	if cols.is_empty():
		return
	var xs: Array = cols.keys()
	xs.sort()
	var bottom := surface
	for c in cols.values():
		bottom = maxf(bottom, c[1])
	rect = Rect2(xs[0] * COL, surface, (xs[-1] + 1 - xs[0]) * COL, bottom - surface)


func contains(p: Vector2) -> bool:
	var c: Array = cols.get(int(floorf(p.x / COL)), [])
	if c.is_empty():
		return false
	var top: float = surface_y(p.x) if c[2] else c[0]
	return p.y >= top and p.y <= c[1]


## Open to the air at x (waves, splashes, breathing happen here).
func open_at(x: float) -> bool:
	var c: Array = cols.get(int(floorf(x / COL)), [])
	return not c.is_empty() and c[2]


## Resting depth at x: surface to the floor of that column.
func depth_at(x: float) -> float:
	var c: Array = cols.get(int(floorf(x / COL)), [])
	return 0.0 if c.is_empty() else c[1] - rect.position.y


func _ready() -> void:
	add_to_group("water")
	z_index = 30
	_max_wave = minf(3.0, rect.size.y / 3.0)
	var n := int(rect.size.x / SPACING) + 1
	_h.resize(n)
	_v.resize(n)
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("depth_px", rect.size.y)
	material = m
	_lip = Node2D.new()
	_lip.draw.connect(_draw_lip)
	add_child(_lip)
	_deep = Node2D.new()
	_deep.top_level = true
	_deep.z_index = -1
	var dsh := Shader.new()
	dsh.code = DEEP_SHADER
	var dm := ShaderMaterial.new()
	dm.shader = dsh
	dm.set_shader_parameter("surface", rect.position.y)
	dm.set_shader_parameter("depth_px", rect.size.y)
	_deep.material = dm
	_deep.draw.connect(_draw_deep)
	add_child(_deep)
	# Loose physics bodies (crates on actors, ragdoll parts, grenades).
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4 | 16 | 32
	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size + Vector2(0, 8)
	cs.shape = box
	cs.position = rect.get_center() - Vector2(0, 4)
	_area.add_child(cs)
	add_child(_area)


## Surface height at world x, waves included.
func surface_y(x: float) -> float:
	var f := clampf((x - rect.position.x) / SPACING, 0.0, _h.size() - 1.001)
	var i := int(f)
	return rect.position.y + lerpf(_h[i], _h[i + 1], f - i)


func depth() -> float:
	return rect.size.y


## Push the surface at x (downward speed positive): waves and a splash of droplets.
func splash(x: float, speed: float, big := true) -> void:
	var i := int(clampf((x - rect.position.x) / SPACING, 0, _h.size() - 1))
	speed = clampf(speed, -220.0, 220.0) * 0.3
	for k in range(-2, 3):
		var j := i + k
		if j >= 0 and j < _v.size():
			_v[j] += speed * (0.5 if k == 0 else 0.25)
	if big and absf(speed) > 20.0:
		var at := Vector2(x, rect.position.y)
		Fx.droplets(at, clampi(int(absf(speed) / 12.0), 2, 7))
		Audio.play_at("splash", at, lerpf(-12.0, 0.0, clampf(absf(speed) / 300.0, 0.0, 1.0)), 0.15)


func _physics_process(delta: float) -> void:
	_t += delta
	# Springs, then two passes of spreading to the neighbours.
	var n := _h.size()
	for i in n:
		_v[i] += (-K * _h[i] - DAMP * _v[i]) * delta
		_h[i] = clampf(_h[i] + _v[i] * delta, -_max_wave, _max_wave)
	for _p in 2:
		for i in n:
			if i > 0:
				_v[i - 1] += SPREAD * (_h[i] - _h[i - 1]) * delta * 60.0
			if i < n - 1:
				_v[i + 1] += SPREAD * (_h[i] - _h[i + 1]) * delta * 60.0
	# A gentle idle swell so still water still lives; covered stretches stay flat (the
	# rock holds them down, so waves stop there too).
	for i in n:
		if open_at(rect.position.x + i * SPACING + 0.5):
			_h[i] += sin(_t * 1.7 + i * 0.35) * 0.01
		else:
			_h[i] = 0.0
			_v[i] = 0.0
	_buoyancy(delta)
	_characters()
	(material as ShaderMaterial).set_shader_parameter("time", _t)
	(_deep.material as ShaderMaterial).set_shader_parameter("time", _t)
	_deep.queue_redraw()
	queue_redraw()
	_lip.queue_redraw()


func _buoyancy(delta: float) -> void:
	var g := 900.0
	var seen := {}
	for b in _area.get_overlapping_bodies():
		var rb := b as RigidBody2D
		if rb == null:
			continue
		seen[rb] = true
		var r := 4.0
		var kind := "other"
		if rb is Crate:
			r = Crate.SIZE / 2.0
			kind = "crate"
		elif rb is Grenade:
			r = Grenade.R
			kind = "grenade"
		elif rb.get_parent() is Ragdoll:
			r = 3.0
			kind = "corpse"
		var y := rb.global_position.y
		var sub := clampf((y + r - surface_y(rb.global_position.x)) / (2.0 * r), 0.0, 1.0)
		var was: bool = _inside.get(rb, false)
		if sub > 0.0 and not was:
			splash(rb.global_position.x, rb.linear_velocity.y * 0.6, rb.linear_velocity.y > 80.0)
		_inside[rb] = sub > 0.0
		if sub <= 0.0:
			continue
		# Archimedes: lift = weight / density, scaled by how much is under.
		var lift: float = g * rb.gravity_scale * rb.mass * sub / DENSITY[kind]
		rb.apply_central_force(Vector2(0, -lift))
		# Water drag (quadratic-ish), heavier than air by far.
		rb.linear_velocity *= exp(-5.0 * sub * delta)
		rb.angular_velocity *= exp(-4.0 * sub * delta)
	for b in _inside.keys():
		if not seen.has(b):
			_inside.erase(b)


## The hero and enemies make waves as they cross the surface.
func _characters() -> void:
	for c in get_tree().get_nodes_in_group("hero") + get_tree().get_nodes_in_group("enemy"):
		var body := c as CharacterBody2D
		var x := body.global_position.x
		if not open_at(x):
			_inside.erase(body)
			continue
		var feet_in := body.global_position.y > surface_y(x)
		var was: bool = _inside.get(body, false)
		if feet_in != was:
			splash(x, body.velocity.y * 0.5 if feet_in else -absf(body.velocity.y) * 0.3, absf(body.velocity.y) > 60.0)
		elif feet_in and absf(body.velocity.x) > 30.0 and body.global_position.y - 30.0 < surface_y(x):
			splash(x, 6.0, false)  # wake
		_inside[body] = feet_in


func _draw() -> void:
	# Column by column, from the (moving) surface or the rock above, down to that column's
	# floor. UV.y = depth below the one true surface, so the shading has no seams.
	var depth_px := maxf(1.0, rect.size.y)
	for tx in cols:
		var c: Array = cols[tx]
		var x0: float = tx * COL
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		if c[2]:
			for k in 5:
				var x := x0 + k * SPACING
				var y := roundf(surface_y(x))
				pts.append(Vector2(x, y))
				uvs.append(Vector2(0, (y - rect.position.y) / depth_px))
		else:
			pts.append(Vector2(x0, c[0]))
			uvs.append(Vector2(0, (c[0] - rect.position.y) / depth_px))
			pts.append(Vector2(x0 + COL, c[0]))
			uvs.append(Vector2(1, (c[0] - rect.position.y) / depth_px))
		pts.append(Vector2(x0 + COL, c[1]))
		uvs.append(Vector2(1, (c[1] - rect.position.y) / depth_px))
		pts.append(Vector2(x0, c[1]))
		uvs.append(Vector2(0, (c[1] - rect.position.y) / depth_px))
		draw_colored_polygon(pts, Color.WHITE, uvs)


func _draw_deep() -> void:
	for tx in cols:
		var c: Array = cols[tx]
		var top: float = rect.position.y if c[2] else c[0]
		_deep.draw_rect(Rect2(tx * COL, top, COL, c[1] - top), Color.WHITE)


func _draw_lip() -> void:
	var n := _h.size()
	for i in n - 1:
		var x := rect.position.x + i * SPACING
		if not open_at(x + 0.5):
			continue
		var y := roundf(rect.position.y + _h[i])
		var agitated := absf(_v[i]) > 12.0
		_lip.draw_rect(Rect2(x, y, SPACING, 1), Color(0.85, 0.95, 1.0, 0.9 if agitated else 0.55))
		if agitated:
			_lip.draw_rect(Rect2(x + 1, y - 1, 2, 1), Color(1, 1, 1, 0.8))
