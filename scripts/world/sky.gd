class_name SkyDome
extends CanvasLayer
## Real-time sky: the clock runs while you play, so a level that starts in the late
## afternoon plays out through a sunset into night. The sky is a shader (smooth
## gradient, sun and glow, moon, sun-lit cloud streaks, stars); in front of it the
## backdrop silhouettes scroll with parallax and are tinted by the same light, each
## fading toward the horizon colour with distance so the whole picture holds together.
## The level reads light() for its CanvasModulate so the playfield dims with the sky.
## Lives on its own canvas layer, so the playfield's ambient never double-darkens it.

const W := 480.0
const H := 270.0
const HORIZON := 172.0
const LAYERS := {
	"canyon": [["canyon_far", 0.06, 0.55], ["canyon_mid", 0.2, 0.3], ["canyon_near", 0.45, 0.1]],
	"jungle": [["jungle_far", 0.06, 0.5], ["jungle_mid", 0.22, 0.25], ["jungle_near", 0.5, 0.08]],
}
## Hour -> [zenith, horizon, playfield light]. Wraps at 24.
const KEYS := [
	[0.0, Color("#070b1c"), Color("#1a2140"), Color(0.2, 0.22, 0.36)],
	[4.8, Color("#0e1430"), Color("#2c2848"), Color(0.24, 0.24, 0.38)],
	[5.8, Color("#2a3464"), Color("#c07068"), Color(0.5, 0.42, 0.5)],
	[6.6, Color("#4a70a8"), Color("#f0b080"), Color(0.8, 0.68, 0.62)],
	[8.0, Color("#4f86c4"), Color("#e8d8b8"), Color(0.98, 0.93, 0.86)],
	[12.0, Color("#4a88d0"), Color("#c4dcec"), Color(1.0, 0.98, 0.94)],
	[16.0, Color("#5486c4"), Color("#e8d6b0"), Color(1.0, 0.94, 0.84)],
	[17.4, Color("#6474ac"), Color("#f8c070"), Color(1.0, 0.8, 0.6)],
	[18.4, Color("#48477e"), Color("#f88c4c"), Color(0.9, 0.6, 0.5)],
	[19.2, Color("#262652"), Color("#c0504c"), Color(0.6, 0.42, 0.48)],
	[20.1, Color("#12173a"), Color("#46304e"), Color(0.32, 0.3, 0.44)],
	[21.4, Color("#070b1c"), Color("#1a2140"), Color(0.2, 0.22, 0.36)],
	[24.0, Color("#070b1c"), Color("#1a2140"), Color(0.2, 0.22, 0.36)],
]
const BIOME_TINT := {"canyon": Color(1, 1, 1), "jungle": Color(0.82, 1.0, 0.86)}

var hour := 16.0
var speed := 1.0 / 60.0  # in-game hours per real second (one hour a minute)
var biome := "canyon"
var cam := Vector2.ZERO
var base_y := 0.0  # camera height where the backdrop sits at rest (the start)
var _rect: ColorRect
var _mat: ShaderMaterial
var _layers: Array = []  # [Sprite2D, scroll factor, fog amount]
var _t := 0.0
var _zenith := Color.BLACK
var _horizon := Color.BLACK
var _light := Color.WHITE

const SKY_SHADER := """
shader_type canvas_item;
uniform vec4 zenith : source_color;
uniform vec4 horizon : source_color;
uniform vec4 sun_col : source_color;
uniform vec2 sun_pos;
uniform float sun_vis;
uniform vec2 moon_pos;
uniform float moon_vis;
uniform float stars;
uniform float scroll;
uniform float time;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = floor(UV * vec2(480.0, 270.0));
	float t = clamp(px.y / 172.0, 0.0, 1.0);
	vec3 col = mix(zenith.rgb, horizon.rgb, pow(t, 1.7));
	// Sun: soft wide glow, a bright disc; the glow warms the horizon near it.
	float d = distance(px, sun_pos);
	col += sun_col.rgb * (exp(-d / 55.0) * 0.55 + exp(-d / 14.0) * 0.4) * sun_vis;
	if (d < 9.0) col = mix(col, vec3(1.0, 0.97, 0.86) * 0.4 + sun_col.rgb * 0.7, sun_vis);
	// Moon: small, cool, with a dim halo.
	float m = distance(px, moon_pos);
	col += vec3(0.5, 0.55, 0.7) * exp(-m / 18.0) * 0.25 * moon_vis;
	if (m < 5.0) col = mix(col, vec3(0.88, 0.9, 0.96), moon_vis);
	// Stars, twinkling, drifting a touch with the camera.
	vec2 sp = px + vec2(floor(scroll * 0.02), 0.0);
	float h = hash(sp);
	if (h > 0.9965 && px.y < 160.0) {
		float tw = 0.6 + 0.4 * sin(time * (2.0 + h * 40.0) + h * 90.0);
		col = mix(col, vec3(1.0, 0.96, 0.9), stars * tw * (1.0 - t * 0.7));
	}
	// Cloud streaks: long and thin, lit by the sun from the horizon side.
	float cy = px.y / 170.0;
	float band = smoothstep(0.1, 0.35, cy) * smoothstep(0.95, 0.6, cy);
	vec2 cp = vec2((px.x + scroll * 0.04) * 0.012 + time * 0.004, px.y * 0.09);
	float c = noise(cp) * 0.65 + noise(cp * 2.3) * 0.35;
	c = smoothstep(0.58, 0.8, c) * band;
	vec3 lit = mix(horizon.rgb * 1.1, sun_col.rgb, 0.45 * sun_vis + 0.1);
	col = mix(col, mix(zenith.rgb * 0.8, lit, 0.35 + 0.65 * (1.0 - cy)), c * 0.75);
	// Gentle posterise: retro banding without noisy dither.
	col = floor(col * 40.0 + 0.5) / 40.0;
	COLOR = vec4(col, 1.0);
}
"""

const LAYER_SHADER := """
shader_type canvas_item;
uniform vec4 light : source_color;
uniform vec4 fog : source_color;
uniform float fog_amt;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(mix(t.rgb * light.rgb, fog.rgb, fog_amt), t.a);
}
"""


func _init(p_biome := "canyon", p_hour := 16.0) -> void:
	biome = p_biome
	hour = p_hour
	layer = -10


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.size = Vector2(W, H)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SKY_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	var lsh := Shader.new()
	lsh.code = LAYER_SHADER
	for spec in LAYERS[biome]:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % spec[0])
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_rect = Rect2(0, 0, W, H)
		var m := ShaderMaterial.new()
		m.shader = lsh
		s.material = m
		add_child(s)
		_layers.append([s, spec[1], spec[2]])
	_update()


## Playfield light for the current hour (the level multiplies its biome tint in).
func light() -> Color:
	return _light


## Is the sun down? (0 = full day, 1 = full night)
func night() -> float:
	return clampf(1.0 - (_light.v - 0.2) / 0.6, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	hour = fposmod(hour + delta * speed, 24.0)
	_update()


func _update() -> void:
	var k0: Array = KEYS[0]
	var k1: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			k0 = KEYS[i]
			k1 = KEYS[i + 1]
			break
	var u := smoothstep(0.0, 1.0, (hour - k0[0]) / maxf(0.001, k1[0] - k0[0]))
	var tint: Color = BIOME_TINT[biome]
	_zenith = (k0[1] as Color).lerp(k1[1], u) * tint
	_horizon = (k0[2] as Color).lerp(k1[2], u) * tint
	_light = (k0[3] as Color).lerp(k1[3], u)
	# Sun from sunrise (6) to sunset (19); moon the rest of the night.
	var sun_e := sin(PI * (hour - 6.0) / 13.0)
	var sun_x := lerpf(60.0, 420.0, clampf((hour - 6.0) / 13.0, 0.0, 1.0))
	var sun_y := HORIZON + 8.0 - sun_e * 150.0
	var low := clampf(1.0 - sun_e * 2.2, 0.0, 1.0)
	var sun_col := Color(1.0, 0.95, 0.8).lerp(Color(1.0, 0.45, 0.2), low)
	var mh := fposmod(hour - 19.0, 24.0)
	var moon_e := sin(PI * mh / 11.0) if mh < 11.0 else -1.0
	# Climbing lifts the view: the backdrop sinks a little (never lifts off the bottom).
	var parallax_y := clampf((base_y - cam.y) * 0.05, 0.0, 40.0)
	_mat.set_shader_parameter("zenith", _zenith)
	_mat.set_shader_parameter("horizon", _horizon)
	_mat.set_shader_parameter("sun_col", sun_col)
	_mat.set_shader_parameter("sun_pos", Vector2(sun_x, sun_y + parallax_y * 0.3))
	_mat.set_shader_parameter("sun_vis", clampf(sun_e * 6.0 + 0.4, 0.0, 1.0))
	_mat.set_shader_parameter("moon_pos", Vector2(lerpf(420.0, 80.0, mh / 11.0), HORIZON - moon_e * 120.0))
	_mat.set_shader_parameter("moon_vis", clampf(moon_e * 5.0, 0.0, 1.0))
	_mat.set_shader_parameter("stars", clampf(-sun_e * 4.0 - 0.2, 0.0, 1.0))
	_mat.set_shader_parameter("scroll", cam.x)
	_mat.set_shader_parameter("time", _t)
	# Silhouettes: lit by the sky, the farther ones more lost in the haze.
	var sil_light := _light.lerp(Color(1, 1, 1), 0.15)
	for l in _layers:
		var s: Sprite2D = l[0]
		s.region_rect = Rect2(roundf(cam.x * l[1]), 0, W, H)
		s.position.y = roundf(parallax_y * l[1] * 2.0)
		var m := s.material as ShaderMaterial
		m.set_shader_parameter("light", sil_light)
		m.set_shader_parameter("fog", _horizon.lerp(_zenith, 0.2))
		m.set_shader_parameter("fog_amt", l[2])
