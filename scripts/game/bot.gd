class_name Bot
extends Node
## Scripted play-through of the Proving Grounds that checks the moveset works.
## Run at REAL speed:  godot --headless --path . -- --bot
## Each step holds inputs until its condition is met (or times out = FAIL).

var level: Level
var hero: Hero
var _steps: Array = []
var _i := -1
var _t := 0.0
var _fails := 0
var _log: Array[String] = []


func _ready() -> void:
	hero = level.hero
	var T := Level.T
	var anchors := get_tree().get_nodes_in_group("whip_anchor")
	anchors.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var A: Array = anchors.map(func(a): return a.global_position)
	_steps = [
		["settle", {}, func(): return hero.state == Hero.S.GROUND, 2.0],
		["walk right", {"right": true}, func(): return hero.global_position.x > 90.0, 2.0],
		["run to ledge wall", {"right": true, "run": true}, func(): return hero.global_position.x > 14 * T - 40, 3.0],
		["skid stop", {}, func(): return absf(hero.velocity.x) < 1.0 and hero.state == Hero.S.GROUND, 2.0],
		["walk to wall", {"right": true}, func(): return hero.is_on_wall(), 2.0],
		["jump + grab ledge", {"jump!": true}, func(): return hero.state == Hero.S.HANG, 1.5],
		["climb up", {"up": true}, func(): return hero.state == Hero.S.GROUND and hero.global_position.y <= 18 * T + 1, 2.0],
		["run to gap", {"right": true, "run": true}, func(): return hero.global_position.x > 28 * T - 14, 3.0],
		["long jump gap", {"right": true, "run": true, "jump!": true}, func(): return hero.state == Hero.S.GROUND and hero.global_position.x > 33 * T and hero.global_position.y <= 18 * T + 1, 2.0],
		["run to chasm", {"right": true, "run": true}, func(): return hero.global_position.x > 45 * T - 30, 3.0],
		["stop at edge", {}, func(): return absf(hero.velocity.x) < 1.0, 2.0],
		["whip anchor 1", {"aim": A[0], "whip!": true}, func(): return hero.state == Hero.S.SWING, 1.0],
		["swing 1", {"aim": A[1], "right": true}, func(): return hero.velocity.x > 60.0 and hero.global_position.x > A[0].x + 30, 3.0],
		["release + whip 2", {"aim": A[1], "jump!": true}, func(): return hero.state == Hero.S.AIR, 0.5],
		["latch anchor 2", {"aim": A[1], "whip!": true}, func(): return hero.state == Hero.S.SWING, 1.0],
		["swing 2", {"aim": A[2], "right": true}, func(): return hero.velocity.x > 60.0 and hero.global_position.x > A[1].x + 30, 3.0],
		["release + whip 3", {"aim": A[2], "jump!": true}, func(): return hero.state == Hero.S.AIR, 0.5],
		["latch anchor 3", {"aim": A[2], "whip!": true}, func(): return hero.state == Hero.S.SWING, 1.0],
		["swing 3", {"aim": A[2] + Vector2(200, 0), "right": true}, func(): return hero.velocity.x > 80.0 and hero.global_position.x > A[2].x + 40, 3.0],
		["release to landing", {"jump!": true, "right": true}, func(): return hero.state == Hero.S.HANG or hero.state == Hero.S.GROUND and hero.global_position.x > 76 * T, 2.5],
		["(climb if hanging)", {"up": true}, func(): return hero.state == Hero.S.GROUND and hero.global_position.x > 76 * T, 2.0],
		["shoot dummy", {"aim": Vector2(86 * T + 8, 17 * T - 2), "shoot!": true}, func(): return hero.ammo == 5, 0.5],
		["shoot x5", {"aim": Vector2(90 * T + 8, 17 * T - 2), "shoot!": true}, _shoot_until_empty, 3.0],
		["reload", {"reload!": true}, func(): return hero.ammo == 6, 2.0],
		["whip crate", {"aim": Vector2(82 * T + 8, 17 * T + 10), "whip!": true}, func(): return hero.anim.overlay_name == "whip_pull", 1.0],
		["walk to cave", {"right": true, "run": true}, func(): return hero.global_position.x > 99 * T, 4.0],
		["climb boulder", {"right": true}, func(): return hero.is_on_wall(), 1.5],
		["jump + grab boulder", {"jump!": true}, func(): return hero.state == Hero.S.HANG, 1.5],
		["climb boulder top", {"up": true}, func(): return hero.state == Hero.S.GROUND and hero.global_position.y <= 15 * T + 1, 2.0],
		["reach exit", {"right": true, "run": true}, func(): return level._done, 5.0],
		["dummies were hit", {}, func(): return _dummy_hits() >= 2, 0.2],
	]
	_next()


func _dummy_hits() -> int:
	var n := 0
	for c in level.get_children():
		if c is Dummy:
			n += (c as Dummy).hits
	return n


func _shoot_until_empty() -> bool:
	if hero.ammo > 0 and hero._shot_cd <= 0.0:
		hero.bot_input["shoot!"] = true
	return hero.ammo == 0


## With `--shot <dir>` (needs a window, not --headless) saves the game view at every step.
func _shot(label: String) -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i < 0 or i + 1 >= args.size():
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(args[i + 1].path_join("%02d_%s.png" % [_i, label.replace(" ", "_").replace("(", "").replace(")", "")]))


func _next() -> void:
	_i += 1
	_t = 0.0
	hero.bot_input = {}
	if _i >= _steps.size():
		_finish()
		return
	var inputs: Dictionary = _steps[_i][1]
	for k in ["left", "right", "up", "down", "run", "jump", "whip", "shoot", "reload"]:
		hero.bot_input[k] = inputs.get(k, false)
	for k in inputs:
		hero.bot_input[k] = inputs[k]
	if not inputs.has("aim"):
		hero.bot_input["aim"] = hero.global_position + Vector2(200, -20)


func _physics_process(delta: float) -> void:
	if _i < 0 or _i >= _steps.size():
		return
	_t += delta
	var step: Array = _steps[_i]
	if not step[1].has("aim"):
		hero.bot_input["aim"] = hero.global_position + Vector2(200 * hero.facing, -20)
	if (step[2] as Callable).call():
		_log.append("PASS %-22s %.2fs  pos=%s" % [step[0], _t, hero.global_position.round()])
		_shot(step[0])
		_next()
	elif _t > step[3]:
		_fails += 1
		_log.append("FAIL %-22s pos=%s vel=%s state=%s anim=%s" % [step[0], hero.global_position.round(), hero.velocity.round(),
				Hero.S.keys()[hero.state], hero.anim.clip_name])
		_finish()


func _finish() -> void:
	for l in _log:
		print(l)
	print("BOT %s: %d/%d steps" % ["OK" if _fails == 0 else "FAILED", _log.size() - _fails, _steps.size()])
	_i = _steps.size()
	get_tree().quit(1 if _fails else 0)
