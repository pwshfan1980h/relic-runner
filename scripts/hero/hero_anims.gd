class_name HeroAnims
extends RefCounted
## Keyframed poses for the adventurer, rotoscope style: a few strong keys per clip,
## Catmull-Rom between them, crossfades between clips. Channels are documented in HeroRig.
##
## Clip fields: len, loop, lock (0 none, 1 feet, 2 whole body), keys [[t, pose]],
## events [[t, name]] (footsteps etc.), hold (non-loop clips freeze on their last key).

const BASE := {
	"hx": 0.0, "hy": 0.0, "hr": 0.0, "torso": 3.0, "head": 0.0, "hat": 0.0,
	"ua_f": 6.0, "fa_f": -12.0, "ua_b": 8.0, "fa_b": -14.0,
	"th_f": -5.0, "sh_f": 5.0, "ft_f": 0.0, "th_b": 6.0, "sh_b": 4.0, "ft_b": 0.0,
}
const ARMS_F := ["ua_f", "fa_f"]
const ARMS_B := ["ua_b", "fa_b"]
const ARMS := ["ua_f", "fa_f", "ua_b", "fa_b"]

static var clips := {}


## Swaps near/far limbs: the second half of every gait cycle.
static func mirror(p: Dictionary) -> Dictionary:
	var out := p.duplicate()
	for a: String in ["ua", "fa", "th", "sh", "ft"]:
		var f := a + "_f"
		var b := a + "_b"
		if p.has(f) or p.has(b):
			out[f] = p.get(b, BASE[b])
			out[b] = p.get(f, BASE[f])
	return out


static func _gait(half: Array, period: float) -> Array:
	var keys: Array = []
	var n := half.size()
	for i in n:
		keys.append([period * 0.5 * i / n, half[i]])
	for i in n:
		keys.append([period * 0.5 + period * 0.5 * i / n, mirror(half[i])])
	keys.append([period, half[0]])
	return keys


static func _add(name: String, len: float, loop: bool, lock: int, keys: Array, events := []) -> void:
	# Fill every key from BASE so interpolation always has all channels.
	var full: Array = []
	for k in keys:
		var pose := BASE.duplicate()
		pose.merge(k[1], true)
		full.append([k[0], pose])
	clips[name] = {"len": len, "loop": loop, "lock": lock, "keys": full, "events": events}


static func build() -> void:
	if not clips.is_empty():
		return
	var stand := {}
	var crouch := {"th_f": -45.0, "sh_f": 85.0, "ft_f": 0.0, "th_b": -30.0, "sh_b": 72.0, "ft_b": 8.0,
			"torso": 26.0, "head": 6.0, "ua_b": 25.0, "fa_b": -35.0, "ua_f": 20.0, "fa_f": -30.0}

	_add("idle", 2.4, true, 1, [
		[0.0, stand],
		[1.2, {"torso": 5.0, "head": 2.0, "ua_b": 10.0, "fa_b": -18.0, "ua_f": 8.0, "fa_f": -16.0, "hy": -0.4}],
		[2.4, stand],
	])
	# Idle fidget: tugs the hat brim.
	_add("idle_hat", 1.6, false, 1, [
		[0.0, stand],
		[0.35, {"ua_f": -150.0, "fa_f": -60.0, "head": 8.0}],
		[0.6, {"ua_f": -150.0, "fa_f": -62.0, "head": 12.0, "hat": 8.0}],
		[1.0, {"ua_f": -145.0, "fa_f": -58.0, "head": 4.0, "hat": 0.0}],
		[1.6, stand],
	])

	var walk_a := {"th_f": -24.0, "sh_f": 6.0, "ft_f": -12.0, "th_b": 18.0, "sh_b": 12.0, "ft_b": 22.0,
			"ua_b": -24.0, "fa_b": -24.0, "ua_f": 22.0, "fa_f": -10.0, "torso": 5.0}
	var walk_b := {"th_f": -8.0, "sh_f": 8.0, "ft_f": 0.0, "th_b": -2.0, "sh_b": 42.0, "ft_b": 18.0,
			"ua_b": 0.0, "fa_b": -18.0, "ua_f": 0.0, "fa_f": -14.0, "torso": 5.0, "hy": -0.7}
	_add("walk", 0.6, true, 1, _gait([walk_a, walk_b], 0.6), [[0.0, "step"], [0.3, "step"]])

	var run_a := {"th_f": -34.0, "sh_f": 14.0, "ft_f": -8.0, "th_b": 30.0, "sh_b": 50.0, "ft_b": 40.0,
			"ua_b": -50.0, "fa_b": -80.0, "ua_f": 40.0, "fa_f": -50.0}
	var run_b := {"th_f": -16.0, "sh_f": 34.0, "ft_f": 0.0, "th_b": 8.0, "sh_b": 100.0, "ft_b": 40.0,
			"ua_b": -20.0, "fa_b": -85.0, "ua_f": 20.0, "fa_f": -60.0}
	var run_c := {"th_f": 4.0, "sh_f": 24.0, "ft_f": 10.0, "th_b": -28.0, "sh_b": 105.0, "ft_b": 20.0,
			"ua_b": 10.0, "fa_b": -70.0, "ua_f": -10.0, "fa_f": -70.0, "hy": -0.8}
	var run_d := {"th_f": 30.0, "sh_f": 14.0, "ft_f": 45.0, "th_b": -52.0, "sh_b": 60.0, "ft_b": 10.0,
			"ua_b": 40.0, "fa_b": -50.0, "ua_f": -40.0, "fa_f": -80.0, "hy": -2.6}
	for k in [run_a, run_b, run_c, run_d]:
		k["torso"] = 16.0
		k["head"] = -2.0
	_add("run", 0.4, true, 1, _gait([run_a, run_b, run_c, run_d], 0.4), [[0.0, "step"], [0.2, "step"]])

	# Prince of Persia skid: lean back, lead heel digs in. Held while sliding.
	_add("skid", 0.28, false, 1, [
		[0.0, run_a.merged({"torso": 12.0}, true)],
		[0.08, {"torso": -14.0, "head": -6.0, "th_f": -50.0, "sh_f": 6.0, "ft_f": -28.0, "th_b": 16.0, "sh_b": 80.0,
				"ft_b": 10.0, "ua_b": -70.0, "fa_b": -30.0, "ua_f": -40.0, "fa_f": -20.0}],
		[0.28, {"torso": -8.0, "head": -4.0, "th_f": -40.0, "sh_f": 10.0, "ft_f": -20.0, "th_b": 18.0, "sh_b": 70.0,
				"ft_b": 10.0, "ua_b": -50.0, "fa_b": -30.0, "ua_f": -30.0, "fa_f": -20.0}],
	])
	_add("skid_stop", 0.25, false, 1, [
		[0.0, {"torso": -8.0, "head": -4.0, "th_f": -40.0, "sh_f": 10.0, "ft_f": -20.0, "th_b": 18.0, "sh_b": 70.0,
				"ft_b": 10.0, "ua_b": -50.0, "fa_b": -30.0, "ua_f": -30.0, "fa_f": -20.0}],
		[0.12, {"torso": 8.0, "th_f": -14.0, "sh_f": 16.0, "th_b": 12.0, "sh_b": 20.0, "ua_b": 14.0}],
		[0.25, stand],
	])
	# After the skid the body flips; this is the push-off back into a run.
	_add("turn", 0.3, false, 1, [
		[0.0, {"torso": 22.0, "head": 4.0, "th_f": -20.0, "sh_f": 70.0, "ft_f": 0.0, "th_b": 34.0, "sh_b": 40.0,
				"ft_b": 20.0, "ua_b": -40.0, "fa_b": -60.0, "ua_f": 30.0, "fa_f": -40.0}],
		[0.15, {"torso": 20.0, "th_f": -40.0, "sh_f": 60.0, "ft_f": -5.0, "th_b": 40.0, "sh_b": 12.0, "ft_b": 40.0,
				"ua_b": -60.0, "fa_b": -60.0, "ua_f": 40.0, "fa_f": -50.0}],
		[0.3, run_a.merged({"torso": 16.0, "head": -2.0}, true)],
	])

	_add("jump", 0.3, false, 0, [
		[0.0, {"th_f": -20.0, "sh_f": 10.0, "ft_f": 30.0, "th_b": 12.0, "sh_b": 20.0, "ft_b": 35.0,
				"ua_b": -150.0, "fa_b": -10.0, "torso": 2.0, "head": -6.0}],
		[0.3, {"th_f": -55.0, "sh_f": 85.0, "ft_f": 20.0, "th_b": -30.0, "sh_b": 95.0, "ft_b": 30.0,
				"ua_b": -160.0, "fa_b": -5.0, "torso": 8.0, "head": -4.0}],
	])
	_add("long_jump", 0.45, false, 0, [
		[0.0, {"th_f": -60.0, "sh_f": 30.0, "ft_f": -10.0, "th_b": 40.0, "sh_b": 20.0, "ft_b": 50.0,
				"torso": 20.0, "head": -4.0, "ua_b": -70.0, "fa_b": -40.0, "ua_f": 30.0, "fa_f": -40.0}],
		[0.2, {"th_f": -75.0, "sh_f": 20.0, "ft_f": -20.0, "th_b": 55.0, "sh_b": 55.0, "ft_b": 40.0,
				"torso": 16.0, "head": -4.0, "ua_b": -110.0, "fa_b": -20.0, "ua_f": 50.0, "fa_f": -30.0}],
		[0.45, {"th_f": -50.0, "sh_f": 50.0, "ft_f": -10.0, "th_b": -10.0, "sh_b": 90.0, "ft_b": 20.0,
				"torso": 12.0, "head": 0.0, "ua_b": -60.0, "fa_b": -40.0, "ua_f": 20.0, "fa_f": -40.0}],
	])
	var fall_a := {"th_f": -25.0, "sh_f": 35.0, "ft_f": 20.0, "th_b": 10.0, "sh_b": 50.0, "ft_b": 30.0,
			"ua_b": -120.0, "fa_b": -30.0, "ua_f": -40.0, "fa_f": -40.0, "torso": -4.0, "head": 6.0}
	_add("fall", 0.5, true, 0, [
		[0.0, fall_a],
		[0.25, fall_a.merged({"th_f": -15.0, "sh_f": 45.0, "th_b": 20.0, "sh_b": 35.0, "ua_b": -100.0, "fa_b": -50.0,
				"torso": -2.0}, true)],
		[0.5, fall_a],
	])
	_add("land", 0.22, false, 1, [[0.0, crouch], [0.22, stand]])
	var tuck := {"th_f": -100.0, "sh_f": 130.0, "ft_f": 20.0, "th_b": -90.0, "sh_b": 135.0, "ft_b": 20.0,
			"torso": 50.0, "head": 60.0, "ua_b": -40.0, "fa_b": -90.0, "ua_f": -30.0, "fa_f": -90.0}
	_add("roll", 0.5, false, 2, [
		[0.0, crouch],
		[0.08, tuck.merged({"hr": 40.0}, true)],
		[0.2, tuck.merged({"hr": 150.0}, true)],
		[0.32, tuck.merged({"hr": 260.0}, true)],
		[0.44, tuck.merged({"hr": 350.0}, true)],
		[0.5, crouch.merged({"hr": 360.0}, true)],
	])

	# Ledge hang: both hands on the lip ~35px above the feet.
	var hang := {"ua_b": -168.0, "fa_b": 4.0, "ua_f": -160.0, "fa_f": 2.0, "torso": -3.0, "head": -12.0,
			"th_f": -4.0, "sh_f": 8.0, "ft_f": 25.0, "th_b": 6.0, "sh_b": 12.0, "ft_b": 30.0}
	_add("hang", 1.6, true, 0, [
		[0.0, hang],
		[0.8, hang.merged({"th_f": 4.0, "th_b": 12.0, "torso": -1.0}, true)],
		[1.6, hang],
	])
	# Climb: hips travel up over the lip. The final key is patched to the crouch height (see Hero).
	_add("climb", 0.7, false, 0, [
		[0.0, hang],
		[0.15, {"hx": 0.5, "hy": -6.0, "ua_b": -150.0, "fa_b": -100.0, "ua_f": -148.0, "fa_f": -100.0, "torso": 6.0,
				"head": -4.0, "th_f": -40.0, "sh_f": 60.0, "th_b": -10.0, "sh_b": 40.0}],
		[0.32, {"hx": 3.0, "hy": -18.0, "torso": 45.0, "head": 10.0, "ua_b": -30.0, "fa_b": -70.0, "ua_f": -25.0,
				"fa_f": -70.0, "th_f": -95.0, "sh_f": 115.0, "ft_f": 20.0, "th_b": 10.0, "sh_b": 70.0, "ft_b": 40.0}],
		[0.5, {"hx": 6.0, "hy": -28.0, "torso": 35.0, "head": 6.0, "ua_b": 10.0, "fa_b": -40.0, "ua_f": 12.0,
				"fa_f": -40.0, "th_f": -80.0, "sh_f": 120.0, "th_b": -40.0, "sh_b": 110.0, "ft_b": 10.0}],
		[0.7, crouch.merged({"hx": 8.0, "hy": -35.0}, true)],
	])

	# Whip swing: far hand grips the rope (aimed at the anchor in code), legs trail.
	var swing := {"ua_b": -175.0, "fa_b": 0.0, "torso": 0.0, "head": -6.0, "th_f": -20.0, "sh_f": 30.0,
			"ft_f": 20.0, "th_b": -8.0, "sh_b": 40.0, "ft_b": 30.0}
	_add("swing", 1.0, true, 0, [
		[0.0, swing],
		[0.5, swing.merged({"th_f": -10.0, "sh_f": 20.0, "th_b": 0.0, "sh_b": 30.0}, true)],
		[1.0, swing],
	])

	_add("hurt", 0.35, false, 1, [
		[0.0, {"torso": -22.0, "head": -20.0, "ua_b": -60.0, "fa_b": -30.0, "ua_f": -50.0, "fa_f": -20.0,
				"th_f": -30.0, "sh_f": 20.0, "th_b": 20.0, "sh_b": 30.0}],
		[0.35, stand],
	])
	_add("death", 1.2, false, 2, [
		[0.0, {"torso": -22.0, "head": -20.0, "ua_b": -60.0, "fa_b": -30.0, "ua_f": -50.0, "fa_f": -20.0,
				"th_f": -30.0, "sh_f": 20.0, "th_b": 20.0, "sh_b": 30.0}],
		[0.3, {"hr": -40.0, "torso": -30.0, "head": -30.0, "ua_b": -100.0, "ua_f": -120.0, "th_f": -40.0, "sh_f": 40.0}],
		[0.6, {"hr": -90.0, "torso": -10.0, "head": -95.0, "ua_b": -100.0, "fa_b": -20.0, "ua_f": -140.0, "fa_f": -10.0,
				"th_f": -20.0, "sh_f": 30.0, "th_b": 10.0, "sh_b": 20.0}],
		[1.2, {"hr": -90.0, "torso": -8.0, "head": -98.0, "ua_b": -95.0, "fa_b": -20.0, "ua_f": -150.0, "fa_f": -10.0,
				"th_f": -24.0, "sh_f": 36.0, "th_b": 8.0, "sh_b": 26.0}],
	])

	# Crouch: deep knee bend, torso folded forward so the head sits under bullet height.
	var crouch_pose := {"th_f": -85.0, "sh_f": 125.0, "ft_f": 0.0, "th_b": -55.0, "sh_b": 135.0, "ft_b": 30.0,
			"torso": 45.0, "head": 0.0, "ua_b": 30.0, "fa_b": -60.0, "ua_f": 10.0, "fa_f": -50.0}
	_add("crouch", 1.8, true, 1, [
		[0.0, crouch_pose],
		[0.9, crouch_pose.merged({"torso": 47.0, "hy": -0.3}, true)],
		[1.8, crouch_pose],
	])
	var cw_a := crouch_pose.merged({"th_f": -95.0, "sh_f": 115.0, "th_b": -45.0, "sh_b": 140.0}, true)
	var cw_b := crouch_pose.merged({"th_f": -75.0, "sh_f": 130.0, "th_b": -65.0, "sh_b": 120.0, "hy": -0.5}, true)
	_add("crouch_walk", 0.7, true, 1, _gait([cw_a, cw_b], 0.7), [[0.0, "step"], [0.35, "step"]])
	# Front kick: chamber the knee, snap the boot out, retract. Full body.
	_add("front_kick", 0.45, false, 1, [
		[0.0, stand],
		[0.1, {"th_f": -95.0, "sh_f": 105.0, "ft_f": 10.0, "torso": -4.0, "ua_b": 25.0, "fa_b": -60.0, "ua_f": -20.0, "fa_f": -60.0}],
		[0.18, {"th_f": -98.0, "sh_f": 4.0, "ft_f": -70.0, "torso": -14.0, "head": 2.0, "th_b": 8.0, "sh_b": 8.0,
				"ua_b": 35.0, "fa_b": -40.0, "ua_f": -35.0, "fa_f": -40.0}],
		[0.3, {"th_f": -80.0, "sh_f": 95.0, "ft_f": 10.0, "torso": -4.0, "ua_b": 20.0, "fa_b": -60.0, "ua_f": -20.0, "fa_f": -60.0}],
		[0.45, stand],
	])
	_add("jump_kick", 0.35, false, 0, [
		[0.0, {"th_f": -60.0, "sh_f": 90.0, "th_b": -20.0, "sh_b": 100.0, "torso": 5.0, "ua_b": -40.0}],
		[0.1, {"th_f": -85.0, "sh_f": 2.0, "ft_f": -60.0, "th_b": 25.0, "sh_b": 95.0, "ft_b": 30.0, "torso": -18.0,
				"ua_b": -80.0, "fa_b": -20.0}],
		[0.35, {"th_f": -80.0, "sh_f": 8.0, "ft_f": -55.0, "th_b": 25.0, "sh_b": 95.0, "ft_b": 30.0, "torso": -15.0,
				"ua_b": -70.0, "fa_b": -30.0}],
	])

	# Upper-body overlays (only the arm channels are used).
	# Enemy tells: fist cocked back / blade raised overhead, then the chop.
	_add("windup", 0.4, false, 0, [
		[0.0, {"ua_f": -30.0, "fa_f": -110.0, "ua_b": -20.0, "fa_b": -115.0}],
		[0.25, {"ua_f": 55.0, "fa_f": -130.0, "ua_b": -35.0, "fa_b": -110.0}],
		[0.4, {"ua_f": 58.0, "fa_f": -132.0, "ua_b": -35.0, "fa_b": -110.0}],
	])
	_add("raise_blade", 0.3, false, 0, [
		[0.0, {"ua_f": 0.0, "fa_f": -30.0, "ua_b": 10.0, "fa_b": -30.0}],
		[0.3, {"ua_f": -170.0, "fa_f": -40.0, "ua_b": -30.0, "fa_b": -80.0}],
	])
	_add("chop", 0.3, false, 0, [
		[0.0, {"ua_f": -170.0, "fa_f": -40.0, "ua_b": -30.0, "fa_b": -80.0}],
		[0.08, {"ua_f": -60.0, "fa_f": -5.0, "ua_b": 20.0, "fa_b": -60.0}],
		[0.3, {"ua_f": -20.0, "fa_f": -10.0, "ua_b": 10.0, "fa_b": -40.0}],
	])
	_add("barge", 0.5, true, 1, _gait([
		{"torso": 35.0, "head": -10.0, "th_f": -40.0, "sh_f": 20.0, "ft_f": -5.0, "th_b": 30.0, "sh_b": 60.0, "ft_b": 40.0,
				"ua_f": -10.0, "fa_f": -100.0, "ua_b": 20.0, "fa_b": -100.0},
		{"torso": 35.0, "head": -10.0, "th_f": 10.0, "sh_f": 30.0, "ft_f": 10.0, "th_b": -30.0, "sh_b": 100.0, "ft_b": 20.0,
				"ua_f": -10.0, "fa_f": -100.0, "ua_b": 20.0, "fa_b": -100.0, "hy": -1.5},
	], 0.5))

	# Punches: guard up, jab with the near fist, cross with the far fist.
	_add("punch_a", 0.22, false, 0, [
		[0.0, {"ua_f": -30.0, "fa_f": -120.0, "ua_b": -20.0, "fa_b": -115.0}],
		[0.06, {"ua_f": -88.0, "fa_f": -4.0, "ua_b": -22.0, "fa_b": -118.0}],
		[0.22, {"ua_f": -30.0, "fa_f": -120.0, "ua_b": -20.0, "fa_b": -115.0}],
	])
	_add("punch_b", 0.26, false, 0, [
		[0.0, {"ua_f": -30.0, "fa_f": -120.0, "ua_b": -20.0, "fa_b": -115.0}],
		[0.08, {"ua_f": -20.0, "fa_f": -125.0, "ua_b": -92.0, "fa_b": -2.0}],
		[0.26, {"ua_f": -30.0, "fa_f": -120.0, "ua_b": -20.0, "fa_b": -115.0}],
	])
	_add("reload", 0.9, false, 0, [
		[0.0, {"ua_f": -10.0, "fa_f": -100.0, "ua_b": -10.0, "fa_b": -110.0}],
		[0.2, {"ua_f": -5.0, "fa_f": -115.0, "ua_b": -20.0, "fa_b": -100.0}],
		[0.35, {"ua_f": -5.0, "fa_f": -112.0, "ua_b": -16.0, "fa_b": -92.0}],
		[0.5, {"ua_f": -5.0, "fa_f": -115.0, "ua_b": -20.0, "fa_b": -104.0}],
		[0.65, {"ua_f": -5.0, "fa_f": -112.0, "ua_b": -16.0, "fa_b": -92.0}],
		[0.9, {"ua_f": -10.0, "fa_f": -95.0, "ua_b": -10.0, "fa_b": -110.0}],
	], [[0.35, "shell"], [0.5, "shell"], [0.65, "shell"], [0.85, "spin"]])
	# Overhand grenade throw with the far arm; the gun hand stays low.
	_add("throw", 0.4, false, 0, [
		[0.0, {"ua_b": 150.0, "fa_b": -70.0, "ua_f": 20.0, "fa_f": -30.0}],
		[0.09, {"ua_b": -150.0, "fa_b": -20.0, "ua_f": 30.0, "fa_f": -30.0}],
		[0.2, {"ua_b": -60.0, "fa_b": -10.0, "ua_f": 20.0, "fa_f": -25.0}],
		[0.4, {"ua_b": 8.0, "fa_b": -14.0, "ua_f": 6.0, "fa_f": -12.0}],
	])
	_add("whip_pull", 0.35, false, 0, [
		[0.0, {"ua_b": -60.0, "fa_b": -10.0}],
		[0.12, {"ua_b": 45.0, "fa_b": -80.0}],
		[0.35, {"ua_b": 20.0, "fa_b": -40.0}],
	])


## Samples a clip at time t (Catmull-Rom per channel).
static func sample(clip: Dictionary, t: float) -> Dictionary:
	var keys: Array = clip["keys"]
	var n := keys.size()
	if clip["loop"]:
		t = fposmod(t, clip["len"])
	else:
		t = clampf(t, 0.0, clip["len"])
	var i := 0
	while i < n - 2 and t >= keys[i + 1][0]:
		i += 1
	var k1: Array = keys[i]
	var k2: Array = keys[mini(i + 1, n - 1)]
	var span: float = k2[0] - k1[0]
	var u := 0.0 if span <= 0.0 else clampf((t - k1[0]) / span, 0.0, 1.0)
	var k0: Array = keys[i - 1] if i > 0 else (keys[n - 2] if clip["loop"] else k1)
	var k3: Array = keys[i + 2] if i + 2 < n else (keys[1] if clip["loop"] else k2)
	var out := {}
	for ch in BASE:
		var p0: float = k0[1][ch]
		var p1: float = k1[1][ch]
		var p2: float = k2[1][ch]
		var p3: float = k3[1][ch]
		# Hip spin wraps (rolls): don't let the tangent see a 360 jump.
		if ch == "hr" and clip["loop"]:
			p0 = p1
			p3 = p2
		out[ch] = _catmull(p0, p1, p2, p3, u)
	return out


static func _catmull(p0: float, p1: float, p2: float, p3: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * (2.0 * p1 + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)


## Plays clips on the body plus an optional upper-body overlay, with crossfades.
class Animator:
	extends RefCounted

	signal event(name: String)

	var clip_name := ""
	var time := 0.0
	var speed := 1.0
	var pose := {}
	var _from := {}
	var _blend := 0.0
	var _blend_len := 0.0
	var overlay_name := ""
	var overlay_time := 0.0
	var _overlay_w := 0.0
	var overlay_speed := 1.0

	func _init() -> void:
		HeroAnims.build()
		pose = HeroAnims.BASE.duplicate()

	func clip() -> Dictionary:
		return HeroAnims.clips[clip_name]

	func play(name: String, blend := 0.1, from_time := 0.0, restart := false) -> void:
		if name == clip_name and not restart:
			return
		_from = pose.duplicate()
		clip_name = name
		time = from_time
		speed = 1.0  # a backpedal leaves speed negative; never carry it into the next clip
		_blend = 0.0
		_blend_len = blend

	func finished() -> bool:
		var c := clip()
		return not c["loop"] and time >= c["len"]

	func play_overlay(name: String, spd := 1.0) -> void:
		overlay_name = name
		overlay_time = 0.0
		overlay_speed = spd

	func overlay_active() -> bool:
		return overlay_name != ""

	func advance(delta: float) -> Dictionary:
		var c := clip()
		var prev := time
		time += delta * speed
		_fire(c, prev, time)
		var p := HeroAnims.sample(c, time)
		if _blend < _blend_len:
			_blend += delta
			var w := smoothstep(0.0, 1.0, _blend / _blend_len)
			for ch in p:
				var a: float = _from.get(ch, p[ch])
				if ch == "hr":
					a = p[ch] + wrapf(a - p[ch], -180.0, 180.0)
				p[ch] = lerpf(a, p[ch], w)
		# Upper-body overlay fades in/out over 0.08s.
		if overlay_name != "":
			var oc: Dictionary = HeroAnims.clips[overlay_name]
			var prev_o := overlay_time
			overlay_time += delta * overlay_speed
			_fire(oc, prev_o, overlay_time)
			if overlay_time >= oc["len"]:
				overlay_name = ""
			else:
				_overlay_w = minf(1.0, _overlay_w + delta / 0.08)
				var op := HeroAnims.sample(oc, overlay_time)
				for ch in HeroAnims.ARMS:
					p[ch] = lerpf(p[ch], op[ch], _overlay_w)
		if overlay_name == "":
			_overlay_w = 0.0
		pose = p
		return p

	func _fire(c: Dictionary, a: float, b: float) -> void:
		if b <= a:
			return
		var len: float = c["len"]
		for e in c["events"]:
			var et: float = e[0]
			if c["loop"]:
				var cycles := floorf(a / len)
				for k in 2:
					var at := (cycles + k) * len + et
					if at > a and at <= b:
						event.emit(e[1])
			elif et > a and et <= b:
				event.emit(e[1])
