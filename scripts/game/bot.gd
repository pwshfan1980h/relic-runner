class_name Bot
extends Node
## Scripted play-throughs that prove every level can be finished with the real moveset,
## plus an enemy check in the arena. Run at REAL speed:
##   godot --headless --path . -- --bot [--map <id>]      (default: proving_grounds)
##   godot --headless --path . -- --bot --map arena        (enemy behaviour checks)
## Traversal runs in god mode (enemies can't end the run); the arena test does not.
## With `--shot <dir>` (needs a window) the game view is saved at every step.

const T := 16.0

var level: Level
var hero: Hero
var _steps: Array = []  # [name, tick: Callable(delta) -> bool (done), timeout]
var _i := -1
var _t := 0.0
var _fails := 0
var _log: Array[String] = []
var _mem := {}  # per-step scratch


func _ready() -> void:
	hero = level.hero
	var route := "_route_" + level.map_id
	if not has_method(route):
		push_error("no bot route for " + level.map_id)
		get_tree().quit(2)
		return
	hero.god = level.map_id != "arena"
	call(route)
	_next()


# --- Step builders -------------------------------------------------------------------

func _add(name: String, tick: Callable, timeout: float) -> void:
	_steps.append([name, tick, timeout])


func _inputs(d: Dictionary) -> void:
	for k in ["left", "right", "up", "down", "run", "jump", "whip", "shoot", "reload", "crouch", "punch", "kick"]:
		hero.bot_input[k] = d.get(k, false)
	hero.bot_input["aim"] = d.get("aim", hero.global_position + Vector2(200 * hero.facing, -20))
	for k in d:
		if (k as String).ends_with("!"):
			hero.bot_input[k] = d[k]


func x() -> float:
	return hero.global_position.x


func on_ground() -> bool:
	return hero.state == Hero.S.GROUND


## Walk (or run) until within `tol` of px.
func go(px: float, run := false, tol := 6.0) -> void:
	_add("go %d%s" % [px, " run" if run else ""], func(_d):
		var dir := signf(px - x())
		# Hop anything knee-high in the way.
		var hop := hero.is_on_wall() and on_ground() and absf(px - x()) > 12.0
		_inputs({"right": dir > 0, "left": dir < 0, "run": run, "jump!": hop})
		return absf(px - x()) < tol and hero.state == Hero.S.GROUND, 14.0)


## Run past px without stopping: for crumbling floors and timed gates.
func dash(px: float) -> void:
	_add("dash %d" % px, func(_d):
		if not _mem.has("dir"):
			_mem["dir"] = 1.0 if px > x() else -1.0
		var dir: float = _mem["dir"]
		_inputs({"right": dir > 0, "left": dir < 0, "run": true})
		return (x() - px) * dir >= 0.0, 8.0)


func halt() -> void:
	_add("halt", func(_d):
		_inputs({})
		return absf(hero.velocity.x) < 1.0 and on_ground(), 3.0)


## Walk into the wall ahead, jump, grab, climb.
func climb_wall(dir: int) -> void:
	_add("walk to wall", func(_d):
		_inputs({"right": dir > 0, "left": dir < 0, "aim": hero.global_position + Vector2(dir * 100, -30)})
		return hero.is_on_wall() and on_ground(), 8.0)
	_grab_and_climb(dir)


## Stand under an overhead lip (at px), face dir, jump up to it and climb.
func ledge_up(px: float, dir: int) -> void:
	go(px, false, 2.5)
	halt()
	_grab_and_climb(dir)


func _grab_and_climb(dir: int) -> void:
	_add("jump + grab", func(_d):
		var first: bool = not _mem.has("jumped")
		if first:
			_mem["y0"] = hero.global_position.y
		_mem["jumped"] = true
		_inputs({"right": dir > 0, "left": dir < 0, "jump!": first, "aim": hero.global_position + Vector2(dir * 100, -30)})
		# Low steps get hopped onto rather than grabbed; that counts too.
		return hero.state == Hero.S.HANG or (on_ground() and _t > 0.1 and hero.global_position.y < _mem["y0"] - 8.0), 1.5)
	_add("climb", func(_d):
		_inputs({"up": true, "aim": hero.global_position + Vector2(dir * 100, -30)})
		return on_ground(), 2.0)


## Run toward dir, jump when crossing takeoff; done on landing (climbs if it caught a ledge).
func long_jump(takeoff: float, dir: int, land_past: float) -> void:
	_add("long jump @%d" % takeoff, func(_d):
		var past := (x() - takeoff) * dir >= 0.0
		var jump: bool = past and not _mem.has("jumped") and on_ground()
		if jump:
			_mem["jumped"] = true
		_inputs({"right": dir > 0, "left": dir < 0, "run": true, "jump!": jump})
		return _mem.has("jumped") and ((on_ground() and (x() - land_past) * dir > 0.0) or hero.state == Hero.S.HANG), 4.0)
	_climb_if_hanging(dir)


func _climb_if_hanging(dir: int) -> void:
	_add("(climb if hanging)", func(_d):
		_inputs({"up": true, "right": dir > 0 and on_ground(), "left": dir < 0 and on_ground()})
		return on_ground(), 2.5)


## Latch an anchor (tile coords), pump toward dir, let go once past release_x moving fast.
func swing(ax: int, ay: int, dir: int, release_x: float) -> void:
	var a := Vector2(ax * T + T / 2.0, ay * T + T / 2.0)
	_add("whip anchor (%d,%d)" % [ax, ay], func(_d):
		var first: bool = not _mem.has("thrown")
		_mem["thrown"] = true
		_inputs({"aim": a, "whip!": first})
		return hero.state == Hero.S.SWING, 1.0)
	_add("swing", _pump(dir, release_x), 5.0)
	_release(dir)


## After the last release: drift toward dir until landing past land_x, or catch a ledge.
func land(dir: int, land_x: float) -> void:
	_add("land past %d" % land_x, func(_d):
		_inputs({"right": dir > 0, "left": dir < 0})
		return (on_ground() and (x() - land_x) * dir > 0.0) or hero.state == Hero.S.HANG, 3.0)
	_climb_if_hanging(dir)


## Chain to the next anchor straight from the air.
func swing_next(ax: int, ay: int, dir: int, release_x: float) -> void:
	_add("whip anchor (%d,%d) in the air" % [ax, ay], _air_whip(Vector2(ax * T + T / 2.0, ay * T + T / 2.0)), 1.0)
	_add("swing", _pump(dir, release_x), 5.0)
	_release(dir)


func reach_exit() -> void:
	_add("reach exit", func(_d):
		var dir := signf(level._exit_pos.x - x())
		_inputs({"right": dir > 0, "left": dir < 0, "run": absf(level._exit_pos.x - x()) > 40.0})
		return level._done, 20.0)


# --- Routes --------------------------------------------------------------------------

func _route_proving_grounds() -> void:
	go(90)
	go(14 * T - 40, true)
	halt()
	climb_wall(1)
	long_jump(28 * T - 14, 1, 33 * T)
	go(45 * T - 30, true)
	go(45 * T - 8)
	halt()
	swing(50, 9, 1, 50 * T + 40)
	swing_next(58, 9, 1, 58 * T + 40)
	swing_next(66, 9, 1, 66 * T + 40)
	land(1, 76 * T)
	_add("shoot the range", func(_d):
		var shoot := hero.ammo > 0 and hero._shot_cd <= 0.0
		_inputs({"aim": Vector2(90 * T + 8, 17 * T - 2), "shoot!": shoot})
		return hero.ammo == 0, 4.0)
	_add("reload", func(_d):
		_inputs({"reload!": not _mem.has("r")})
		_mem["r"] = true
		return hero.ammo == 6, 2.0)
	_add("dummies were hit", func(_d): return _dummy_hits() >= 2, 0.2)
	go(99 * T, true)
	climb_wall(1)
	reach_exit()


func _route_dry_gulch() -> void:
	climb_wall(1)
	go(29 * T, true)
	long_jump(31 * T - 10, 1, 36 * T)
	go(58 * T, true)
	go(61 * T - 10)
	halt()
	swing(67, 8, 1, 67 * T + 60)
	land(1, 75 * T)
	go(100 * T, true)
	climb_wall(1)
	climb_wall(1)
	go(119 * T, true)
	long_jump(122 * T - 10, 1, 127 * T)
	reach_exit()


func _route_rattler_mesa() -> void:
	var right_lip := 10 * T - 7.0  # stand here facing right to grab a right-hand shelf's end
	var left_lip := 22 * T + 7.0   # stand here facing left to grab a left-hand shelf's end
	ledge_up(right_lip, 1)          # -> 43
	ledge_up(left_lip, -1)          # -> 40
	ledge_up(right_lip, 1)          # -> 37 (crumbling middle)
	dash(19 * T)
	ledge_up(left_lip, -1)          # -> 34
	ledge_up(6 * T - 7.0, 1)        # -> 31, via its crumbling end
	dash(12 * T)
	ledge_up(left_lip, -1)          # -> 28
	ledge_up(right_lip, 1)          # -> 25
	ledge_up(left_lip, -1)          # -> 22
	ledge_up(right_lip, 1)          # -> 19
	ledge_up(13 * T + 7.0, -1)      # -> 16, the left summit shelf
	go(11 * T)
	halt()
	swing(16, 4, 1, 17 * T + 20)
	land(1, 20 * T)
	reach_exit()


func _route_bandit_mine() -> void:
	go(26 * T, true)
	go(28 * T - 10)
	halt()
	swing(31, 7, 1, 31 * T + 50)
	land(1, 36 * T)
	go(52 * T, true)
	climb_wall(1)
	go(69 * T, true)
	go(70 * T - 10)
	halt()
	swing(75, 7, 1, 75 * T + 60)
	land(1, 81 * T)
	go(88 * T, true)
	dash(106 * T)
	climb_wall(1)
	reach_exit()


func _route_canopy_run() -> void:
	go(15 * T - 10)
	halt()
	swing(20, 3, 1, 20 * T + 60)
	land(1, 25 * T)
	go(35 * T - 10)
	halt()
	swing(40, 3, 1, 40 * T + 70)
	land(1, 47 * T)
	go(57 * T - 10)
	halt()
	swing(62, 3, 1, 62 * T + 70)
	land(1, 69 * T)
	go(100 * T, true)
	go(118 * T, true)
	for i in 5:
		climb_wall(1)  # four ruined steps, then the 2-tile lip onto the platform
	go(141 * T - 10)
	halt()
	swing(145, 3, 1, 145 * T + 30)
	swing_next(149, 3, 1, 149 * T + 50)
	land(1, 152 * T)
	reach_exit()


func _route_sunken_temple() -> void:
	go(10 * T, true)
	long_jump(14 * T - 10, 1, 18 * T)
	long_jump(26 * T - 10, 1, 31 * T)
	go(38 * T, true)
	dash(51 * T)
	go(62 * T, true)
	dash(82 * T)
	go(102 * T, true)
	go(104 * T - 10)
	halt()
	swing(108, 7, 1, 108 * T + 40)
	swing_next(114, 7, 1, 114 * T + 60)
	land(1, 119 * T)
	reach_exit()


func _route_idol_chamber() -> void:
	go(12 * T, true)
	_add("defeat the Guardian", func(_d):
		var g := _first_enemy(Guardian) as Guardian
		if g == null:
			return true
		var d := g.global_position.x - x()
		var want := {"aim": g.global_position + Vector2(0, -24)}
		if absf(d) > 90.0:
			want["right" if d > 0 else "left"] = true
			if hero.is_on_wall() and on_ground():
				want["jump!"] = true  # hop the low pillars
		elif absf(d) < 50.0:
			want["left" if d > 0 else "right"] = true
		if g.vulnerable() and hero.ammo > 0 and hero._shot_cd <= 0.0:
			want["shoot!"] = true
		if hero.ammo == 0:
			want["reload!"] = true
		_inputs(want)
		return false, 60.0)
	go(56 * T, true)
	go(58 * T - 10)
	halt()
	swing(61, 6, 1, 61 * T + 30)
	swing_next(66, 6, 1, 66 * T + 50)
	land(1, 69 * T)
	reach_exit()


## Enemy checks: each type must hurt the hero, react to the whip, and die to the revolver.
func _route_arena() -> void:
	for spec in [["scorpion", 22.0, 3.0], ["snake", 30.0, 3.0], ["bandit", 130.0, 4.0],
			["jaguar", 110.0, 5.0], ["brute", 70.0, 6.0], ["machete", 70.0, 5.0], ["dog", 90.0, 4.0], ["llama", 110.0, 5.0],
			["guardian", 56.0, 8.0]]:
		_arena_checks(spec[0], spec[1], spec[2])
	_melee_checks()


## Crouch and melee: punches, kicks and ducking under bandit fire.
func _melee_checks() -> void:
	_spawn_step("punch: scorpion", "scorpion", 14.0)
	_add("crouch-punch kills a scorpion", func(_d):
		hero._invuln = 5.0
		var e := _arena_enemy()
		var n: int = _mem.get("n", 0)
		var want := {"aim": hero.global_position + Vector2(100, -10), "crouch": true}
		if hero._melee == "" and n < 4 and hero.crouching:
			want["punch!"] = true
			_mem["n"] = n + 1
		_inputs(want)
		return not is_instance_valid(e) or e.dead, 2.0)
	_spawn_step("kick: bandit", "bandit", 14.0)
	_add("front kick launches a bandit", func(_d):
		hero._invuln = 5.0
		var e := _arena_enemy()
		# Step into range, then kick (keep pressing until the kick starts).
		if hero._melee == "front_kick":
			_mem["k"] = true
		var close := absf(e.global_position.x - x()) < 16.0
		_inputs({"aim": hero.global_position + Vector2(100, -20), "right": not close and not _mem.has("k"),
				"kick!": close and not _mem.has("k")})
		return not is_instance_valid(e) or e.dead or e.velocity.x > 150.0, 3.0)
	_add("finish the bandit", func(_d):
		var e := _arena_enemy()
		if not is_instance_valid(e) or e.dead:
			return true
		hero._invuln = 5.0
		var shoot := hero.ammo > 0 and hero._shot_cd <= 0.0
		_inputs({"aim": e.global_position + Vector2(0, -14), "shoot!": shoot, "reload!": hero.ammo == 0})
		return false, 5.0)
	_spawn_step("llama up close", "llama", 20.0)
	_add("llama rear-kicks up close", func(_d):
		_inputs({"aim": hero.global_position + Vector2(100, -20)})
		return hero.hp < Hero.MAX_HP, 3.0)
	_add("finish the llama", func(_d):
		var e := _arena_enemy()
		if e == null or e.dead:
			return true
		hero._invuln = 5.0
		var shoot := hero.ammo > 0 and hero._shot_cd <= 0.0
		_inputs({"aim": e.global_position + Vector2(0, -12), "shoot!": shoot, "reload!": hero.ammo == 0})
		return false, 8.0)
	_add("item generator: 200 names + icons", func(_d):
		for i in 200:
			var it := Item.generate(i * 7919 + 1)
			if it.name == "" or ItemArt.icon(it) == null:
				return false
		return true, 2.0)
	_spawn_step("loot: brute", "brute", 60.0)
	_add("killed brute drops loot", func(_d):
		var e := _arena_enemy()
		if e and not e.dead:
			_mem["g0"] = GameState.loot_value()
			e.die("bullet", Vector2.RIGHT, e.global_position + Vector2(0, -20))
		return get_tree().get_nodes_in_group("loot").size() > 0, 1.0)
	_add("walk over loot to collect it", func(_d):
		var near: Node2D = null
		for p in get_tree().get_nodes_in_group("loot"):
			if near == null or (p as Node2D).global_position.distance_to(hero.global_position) < near.global_position.distance_to(hero.global_position):
				near = p
		if near:
			var dir := signf(near.global_position.x - x())
			_inputs({"right": dir > 0, "left": dir < 0, "aim": hero.global_position + Vector2(100, -20)})
		return GameState.loot_value() > _mem.get("g0", 0) and get_tree().get_nodes_in_group("loot").is_empty(), 8.0)
	_spawn_step("crouch: bandit", "bandit", 130.0)
	_add("crouching dodges bandit fire", func(_d):
		var e := _arena_enemy() as Bandit
		_inputs({"crouch": true, "aim": hero.global_position + Vector2(100, -10)})
		if hero.hp < Hero.MAX_HP:
			_t = 99.0  # hit: fail now
			return false
		return e._shots >= 2 and hero.hp == Hero.MAX_HP, 5.0)


func _spawn_step(name: String, kind: String, dist: float) -> void:
	_add(name, func(_d):
		_inputs({"aim": hero.global_position + Vector2(100, -20)})
		hero.hp = Hero.MAX_HP
		hero._invuln = 0.0
		hero.global_position = hero.spawn
		hero.velocity = Vector2.ZERO
		var e := _make(kind)
		e.position = hero.spawn + Vector2(dist, 0)
		level.add_child(e)
		_mem["e"] = e
		return true, 1.0)


func _arena_checks(kind: String, dist: float, hurt_time: float) -> void:
	_add("%s: spawn" % kind, func(_d):
		_inputs({})
		hero.hp = Hero.MAX_HP
		hero._invuln = 0.0
		hero.global_position = hero.spawn
		hero.velocity = Vector2.ZERO
		var e := _make(kind)
		e.position = hero.spawn + Vector2(dist, 0)
		level.add_child(e)
		_mem["e"] = e
		return true, 1.0)
	_add("%s: attacks the hero" % kind, func(_d):
		_inputs({"aim": hero.global_position + Vector2(100, -20)})
		return hero.hp < Hero.MAX_HP, hurt_time)
	if kind == "guardian":
		_add("guardian: armour turns bullets", func(_d):
			var g := _arena_enemy() as Guardian
			hero._invuln = 5.0
			if not _mem.has("hp0"):
				_mem["hp0"] = g.hp
				_mem["ammo0"] = hero.ammo
			var shoot: bool = not g.vulnerable() and hero._shot_cd <= 0.0 and hero.ammo > 0
			_inputs({"aim": g.global_position + Vector2(0, -10), "shoot!": shoot})
			return hero.ammo <= _mem["ammo0"] - 2 and g.hp == _mem["hp0"], 4.0)
	_add("%s: whip" % kind, func(_d):
		var e := _arena_enemy()
		hero._invuln = 5.0
		var first: bool = not _mem.has("w")
		_mem["w"] = true
		_inputs({"aim": e.global_position + Vector2(0, -e.size.y / 2.0), "whip!": first})
		if e is Jaguar:
			return (e as Jaguar).state == Jaguar.S.FLEE
		if e is AttackDog:
			return (e as AttackDog).state == AttackDog.S.FLEE
		if e is AttackLlama:
			# The charge can end the same frame it rams the hero: remember seeing it.
			if (e as AttackLlama).state == AttackLlama.S.CHARGE:
				_mem["charged"] = true
			return _mem.has("charged")
		if e is Brawler and (e as Brawler).style == "brute":
			return e.stun > 0.0 and absf(e.velocity.x) < 60.0  # staggered, not dragged
		if e is Guardian:
			return _t > 0.6 and e.stun <= 0.0 and not e.dead
		return e.stun > 0.0, 1.5)
	_add("%s: dies to the revolver" % kind, func(_d):
		var e = _mem.get("e")
		if not is_instance_valid(e) or (e as Enemy).dead:
			return true
		hero._invuln = 5.0
		var en := e as Enemy
		var aim := en.global_position + Vector2(0, -en.size.y / 2.0)
		var ok := true
		if en is Guardian:
			aim = en.global_position + Vector2(0, -24)
			ok = (en as Guardian).vulnerable()
		var want := {"aim": aim}
		if ok and hero.ammo > 0 and hero._shot_cd <= 0.0:
			want["shoot!"] = true
		if hero.ammo == 0:
			want["reload!"] = true
		_inputs(want)
		return false, 30.0)
	_add("%s: aftermath" % kind, func(_d):
		_inputs({"aim": hero.global_position + Vector2(100, -20)})
		if _t > 0.8 and OS.get_cmdline_user_args().has("--debug-ragdoll"):
			for r in get_tree().get_nodes_in_group("corpse"):
				if r is Ragdoll:
					for k in (r as Ragdoll).bodies:
						print("  ragdoll ", k, " ", ((r as Ragdoll).bodies[k] as Node2D).global_position.round(), " vis=", (r as Node2D).is_visible_in_tree(), " kids=", ((r as Ragdoll).bodies[k] as Node).get_child_count())
		return _t > 0.8, 2.0)


func _make(kind: String) -> Enemy:
	match kind:
		"dog":
			return AttackDog.new()
		"llama":
			return AttackLlama.new()
		"brute", "machete":
			var b := Brawler.new()
			b.style = kind
			return b
		"scorpion":
			return Scorpion.new()
		"snake":
			return Rattlesnake.new()
		"bandit":
			return Bandit.new()
		"jaguar":
			return Jaguar.new()
	return Guardian.new()


func _arena_enemy() -> Enemy:
	# The enemy spawned by this check's "spawn" step (carried across steps).
	return _carried as Enemy if is_instance_valid(_carried) else null


# --- Shared ticks --------------------------------------------------------------------

func _air_whip(a: Vector2) -> Callable:
	return func(_d):
		var first: bool = not _mem.has("thrown")
		_mem["thrown"] = true
		_inputs({"aim": a, "whip!": first})
		return hero.state == Hero.S.SWING


func _pump(dir: int, release_x: float) -> Callable:
	return func(_d):
		_inputs({"right": dir > 0, "left": dir < 0, "aim": hero.global_position + Vector2(dir * 150, -40)})
		return (x() - release_x) * dir > 0.0 and hero.velocity.x * dir > 60.0


func _release(dir: int) -> void:
	_add("let go", func(_d):
		var first: bool = not _mem.has("released")
		_mem["released"] = true
		_inputs({"jump!": first, "right": dir > 0, "left": dir < 0})
		return hero.state == Hero.S.AIR, 0.5)


func _first_enemy(cls: Variant) -> Node:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_of(e, cls):
			return e
	return null


func _dummy_hits() -> int:
	var n := 0
	for c in level.get_children():
		if c is Dummy:
			n += (c as Dummy).hits
	return n


# --- Runner --------------------------------------------------------------------------

var _carried: Variant = null  # the arena enemy, kept across steps


func _next() -> void:
	_i += 1
	_t = 0.0
	if _mem.has("e"):
		_carried = _mem["e"]
	_mem = {"e": _carried}
	if _i >= _steps.size():
		_finish()


func _physics_process(delta: float) -> void:
	if _i < 0 or _i >= _steps.size():
		return
	_t += delta
	var step: Array = _steps[_i]
	if (step[1] as Callable).call(delta):
		_log.append("PASS %-34s %5.2fs  tile=%s" % [step[0], _t, (hero.global_position / T).snapped(Vector2(0.1, 0.1))])
		_shot(step[0])
		_next()
	elif _t > step[2]:
		_fails += 1
		_log.append("FAIL %-34s melee=%s crouch=%s tile=%s vel=%s state=%s anim=%s" % [step[0], hero._melee, hero.crouching,
				(hero.global_position / T).snapped(Vector2(0.1, 0.1)), hero.velocity.round(), Hero.S.keys()[hero.state],
				hero.anim.clip_name])
		_shot("FAIL_" + str(step[0]))
		_finish()


func _shot(label: String) -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i < 0 or i + 1 >= args.size():
		return
	var safe := label.replace(" ", "_").replace("(", "").replace(")", "").replace(":", "").replace("@", "").replace(",", "_")
	get_viewport().get_texture().get_image().save_png(args[i + 1].path_join("%s_%02d_%s.png" % [level.map_id, _i, safe]))


func _finish() -> void:
	for l in _log:
		print(l)
	print("BOT %s %s: %d/%d steps" % [level.map_id, "OK" if _fails == 0 else "FAILED", _log.size() - _fails, _steps.size()])
	_i = _steps.size()
	get_tree().quit(1 if _fails else 0)
