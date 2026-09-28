class_name Hero
extends CharacterBody2D
## The adventurer. Prince-of-Persia momentum on the ground (skids, pivots, running
## long jump, ledge hang/climb), a bullwhip grapple on R (swing on anchors, yank
## whippable actors), a revolver (hold right click to raise it and aim, left click fires;
## firing from the hip is a slower, looser quick-draw) and grenades on Q (tap to lob at
## 45 degrees, hold to aim along a predicted arc). The head follows the mouse; the body
## faces the mouse while aiming or standing, and the way it's going otherwise.

signal died
signal ammo_changed(ammo: int, reloading: bool)
signal health_changed(hp: int)
signal grenades_changed(n: int)

enum S { GROUND, AIR, HANG, CLIMB, SWING, ROLL, DEAD }

const WALK := 44.0
const RUN := 125.0
const ACCEL_WALK := 700.0
const ACCEL_RUN := 380.0
const SKID_DECEL := 360.0
const FAST := 85.0  # above this, stopping/turning means a skid
const GRAVITY := 900.0
const MAX_FALL := 430.0
const JUMP_V := 255.0
const LONG_JUMP_V := 215.0
const LONG_JUMP_X := 185.0
const AIR_ACCEL := 240.0
const HANG_H := 35.0  # feet-to-ledge-lip when hanging
const GRIP_H := 37.0  # feet-to-hand when swinging
const COYOTE := 0.08
const BUFFER := 0.12
const ROLL_FALL := 100.0
const HURT_FALL := 190.0
const PUMP := 260.0
const REEL := 80.0
const MAX_HP := 5
const SHOT_RANGE := 420.0
const SHOT_COOLDOWN := 0.22
const CROUCH_WALK := 24.0
const AIM_WALK := 34.0
const MAX_GRENADES := 5
const START_GRENADES := 3
const TAP_TIME := 0.18  # Q held longer than this shows the arc
const QUICK_SPREAD := 0.07  # radians of hip-fire wobble
const RAISE_HOLD := 0.9  # arm stays up this long after a hip shot
const STAND := Vector2(8, 28)
const CROUCHED := Vector2(8, 20)
# Melee hitboxes, facing right, relative to the feet: [rect, active from, active to, damage kind]
const MELEE := {
	"punch_a": [Rect2(3, -27, 12, 10), 0.03, 0.11, "punch"],
	"punch_b": [Rect2(3, -27, 13, 10), 0.05, 0.13, "punch"],
	"front_kick": [Rect2(3, -20, 16, 18), 0.13, 0.26, "kick"],
	"jump_kick": [Rect2(2, -18, 17, 16), 0.06, 0.3, "kick"],
}

var state := S.AIR
var facing := 1
var max_hp := MAX_HP  # plus the Lined Stetson upgrade
var max_grenades := MAX_GRENADES
var hp := MAX_HP
var ammo := 6
var rig: HeroRig
var anim: HeroAnims.Animator
var whip: Whip
var spawn := Vector2.ZERO
var bot_input := {}  # test bot overrides: action -> bool, "aim" -> Vector2
var whip_candidate: Array = []  # what the whip (R) would hit now (for the crosshair)

var _coyote := 0.0
var _buffer := 0.0
var _skidding := false
var _turn_after := false
var _turn_t := 0.0
var _peak_y := 0.0
var _long := false
var _grab_cd := 0.0
var _ledge := Vector2.ZERO
var _idle_t := 0.0
var _anchor: Node2D
var _rope_len := 0.0
var _swing_t := 0.0
var _reel_to := -1.0  # rope length being reeled toward (lifts a grounded hero off their feet)
var _aim_w := 1.0
var _recoil := 0.0
var _shot_cd := 0.0
var _reloading := false
var _dead_t := 0.0
var _invuln := 0.0
var god := false  # test bot: take no damage
var _killed_by_spikes := false
var _flash: PointLight2D
var _glow: PointLight2D  # just enough light to see yourself by in the dark
var _flash_e := 0.0
var _whip_arm := 0.0  # weight of the far arm tracking the whip tip
var crouching := false
var _shape: CollisionShape2D
var _melee := ""  # current melee move ("" = none)
var _melee_t := 0.0
var _melee_hit: Array = []  # instance ids already hit by this move
var _combo := false  # second punch queued
var _smear_prev := Vector2.INF  # last fist/boot point, for the motion smear
const SMEAR_TIPS := {"punch_a": ["hand_f", Vector2(0, 1), 3.0], "punch_b": ["hand_b", Vector2(0, 1), 3.0],
		"front_kick": ["ft_f", Vector2(4.2, 0.5), 4.5], "jump_kick": ["ft_f", Vector2(4.2, 0.5), 4.5]}
var grenades := START_GRENADES
var aiming := false  # right click held (arm raised)
var _raise_t := 0.0  # arm kept raised after a quick-draw shot
var _quick := false  # a hip shot waiting for the arm to come up
var _q_t := -1.0  # how long Q has been held (-1 = not held)
var _throw_cd := 0.0
var arc: Array = []  # predicted grenade arc while Q is held: [points, impact]
var _arc_vel := Vector2.ZERO


func _ready() -> void:
	add_to_group("hero")
	max_hp = MAX_HP + GameState.up("hat")
	max_grenades = MAX_GRENADES + GameState.up("bandolier")
	hp = max_hp
	grenades = START_GRENADES + GameState.up("bandolier")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	floor_max_angle = deg_to_rad(50)
	floor_constant_speed = true
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = STAND
	_shape.shape = rect
	_shape.position = Vector2(0, -STAND.y / 2.0)
	add_child(_shape)
	rig = HeroRig.new()
	rig.z_index = 5
	add_child(rig)
	anim = HeroAnims.Animator.new()
	anim.event.connect(_on_anim_event)
	whip = Whip.new()
	whip.hero = self
	add_child(whip)
	whip.latched.connect(_on_whip_latched)
	_flash = PointLight2D.new()
	_flash.texture = Lights.radial(96)
	_flash.color = Color("#ffd27a")
	_flash.energy = 0.0
	add_child(_flash)
	_glow = PointLight2D.new()
	_glow.texture = Lights.radial(128)
	_glow.color = Color("#c8b8a0")
	_glow.energy = 0.0
	_glow.position = Vector2(0, -16)
	add_child(_glow)
	spawn = global_position
	_peak_y = global_position.y
	anim.play("fall", 0.0)


# --- Input (overridable by the test bot) ---------------------------------------

func _held(action: String) -> bool:
	if bot_input.has(action):
		return bot_input[action]
	return Input.is_action_pressed(action)


func _pressed(action: String) -> bool:
	if Time.get_ticks_msec() - DialogueBox.closed_at < 250:
		return false  # the key that closed a conversation isn't also a punch
	if bot_input.has(action + "!"):
		var v: bool = bot_input[action + "!"]
		bot_input.erase(action + "!")
		return v
	return Input.is_action_just_pressed(action) and not bot_input.has(action)


func aim_point() -> Vector2:
	if bot_input.has("aim"):
		return bot_input["aim"]
	return get_global_mouse_position()


func _axis() -> float:
	return float(_held("right")) - float(_held("left"))


# --- Main loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_buffer = BUFFER if _pressed("jump") else maxf(0.0, _buffer - delta)
	_grab_cd = maxf(0.0, _grab_cd - delta)
	_shot_cd = maxf(0.0, _shot_cd - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	_flash_e = move_toward(_flash_e, 0.0, delta * 30.0)
	_flash.energy = _flash_e
	_invuln = maxf(0.0, _invuln - delta)
	if state != S.DEAD:
		rig.visible = _invuln <= 0.0 or fmod(_invuln, 0.12) < 0.07
	match state:
		S.GROUND: _ground(delta)
		S.AIR: _air(delta)
		S.HANG: _hang(delta)
		S.CLIMB: _climb(delta)
		S.SWING: _swing(delta)
		S.ROLL: _roll(delta)
		S.DEAD: _dead(delta)
	_weapons()
	_melee_step(delta)
	_pose(delta)


func _ground(delta: float) -> void:
	var x := _axis()
	var running := _held("run") and not _arm_up()
	var vx := velocity.x
	_set_crouch(_held("crouch") and not _skidding or crouching and not _can_stand())
	if crouching:
		running = false
	if _melee == "front_kick":
		x = 0.0
	if _skidding:
		vx = move_toward(vx, 0.0, SKID_DECEL * delta)
		_turn_after = x != 0.0 and signf(x) != float(facing)
		if Engine.get_physics_frames() % 6 == 0:
			Fx.puff(global_position + Vector2(facing * 5, 0), 2, Color("#c8a070"), Vector2(facing * 30, 0), 12.0)
		if absf(vx) < 14.0:
			_skidding = false
			if _turn_after:
				_set_facing(-facing)
				vx = facing * 40.0
				_turn_t = 0.3
				anim.play("turn", 0.04)
			else:
				vx = 0.0
				anim.play("skid_stop", 0.06)
	elif absf(vx) > FAST and _turn_t <= 0.0 and (x == 0.0 or signf(x) != signf(vx)):
		_skidding = true
		_set_facing(int(signf(vx)))
		anim.play("skid", 0.06)
		Audio.play("skid_dirt", -6.0, 1.0, 0.1)
	else:
		var target := x * (CROUCH_WALK if crouching else (RUN if running else (AIM_WALK if _arm_up() else WALK)))
		# Hills: slower climbing, a little faster going down.
		if is_on_floor() and x != 0.0:
			var n := get_floor_normal()
			if absf(n.x) > 0.1:
				target *= 1.0 + 0.45 * n.x * signf(x)
		if _melee.begins_with("punch"):
			target *= 0.4
		var acc := ACCEL_RUN if running and absf(target) > absf(vx) else ACCEL_WALK
		vx = move_toward(vx, target, acc * delta)
	_turn_t = maxf(0.0, _turn_t - delta)
	velocity.x = vx
	velocity.y = 0.0

	# Facing: momentum while running/skidding; aiming (or standing) follows the mouse;
	# otherwise the hero faces where they're walking.
	if not _skidding and _turn_t <= 0.0:
		if absf(vx) > FAST:
			_set_facing(int(signf(vx)))
		elif _arm_up() or _q_t >= TAP_TIME or absf(vx) < 5.0 and x == 0.0:
			_face_mouse()
		elif x != 0.0:
			_set_facing(int(signf(x)))

	if _buffer > 0.0 and (not crouching or _can_stand()):
		_set_crouch(false)
		_jump()
		return
	move_and_slide()
	if not is_on_floor():
		_set_crouch(false)
		# Walked off an edge: a little coyote time before we count as falling.
		_coyote = COYOTE
		_enter_air(false)
		return
	_pick_ground_anim(delta)


func _pick_ground_anim(delta: float) -> void:
	var vx := velocity.x
	if _skidding or anim.clip_name == "turn" and not anim.finished():
		return
	if _melee == "front_kick":
		return
	if crouching:
		if absf(vx) > 3.0:
			anim.play("crouch_walk", 0.12)
			anim.speed = (1.0 if signf(vx) == float(facing) else -1.0) * clampf(absf(vx) / CROUCH_WALK, 0.3, 1.4)
		else:
			anim.play("crouch", 0.12)
		_idle_t = 0.0
		return
	var moving := absf(vx) > 5.0
	var one_shot := anim.clip_name in ["land", "skid_stop", "idle_hat", "hurt"] and not anim.finished()
	if absf(vx) > FAST:
		anim.play("run", 0.12)
		anim.speed = clampf(absf(vx) / RUN, 0.6, 1.3)
		_idle_t = 0.0
	elif moving:
		if not one_shot or anim.clip_name == "idle_hat":
			anim.play("walk", 0.12)
			# Walking away from the mouse = backpedalling.
			anim.speed = clampf(absf(vx) / WALK, 0.3, 1.6) * (1.0 if signf(vx) == float(facing) else -1.0)
		_idle_t = 0.0
	elif not one_shot:
		_idle_t += delta
		if _idle_t > 7.0:
			_idle_t = 0.0
			anim.play("idle_hat", 0.15)
		else:
			anim.play("idle", 0.15)
			anim.speed = 1.0
	else:
		anim.speed = 1.0


func _jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
	_skidding = false
	if absf(velocity.x) > 90.0:
		_long = true
		velocity = Vector2(signf(velocity.x) * LONG_JUMP_X, -LONG_JUMP_V)
		anim.play("long_jump", 0.06)
		Audio.play("jump", -4.0, 0.9, 0.05)
	else:
		_long = false
		velocity.y = -JUMP_V
		anim.play("jump", 0.06)
		Audio.play("jump", -6.0, 1.05, 0.05)
	Fx.puff(global_position, 4)
	_enter_air(true)
	move_and_slide()


func _enter_air(jumped: bool) -> void:
	state = S.AIR
	_peak_y = global_position.y
	if not jumped:
		_long = absf(velocity.x) > 90.0


func _air(delta: float) -> void:
	_coyote = maxf(0.0, _coyote - delta)
	if _buffer > 0.0 and _coyote > 0.0:
		_jump()
		return
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	var x := _axis()
	if x != 0.0:
		if velocity.x == 0.0 or signf(x) == signf(velocity.x):
			velocity.x = move_toward(velocity.x, x * maxf(WALK * 1.3, absf(velocity.x)), AIR_ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, AIR_ACCEL * 1.3 * delta)
	if absf(velocity.x) < 60.0 or _arm_up():
		_face_mouse()
	elif not _long:
		_set_facing(int(signf(velocity.x)))
	_peak_y = minf(_peak_y, global_position.y)

	if velocity.y > -40.0 and _grab_cd <= 0.0 and not _held("down"):
		var lip := _find_ledge()
		if lip != Vector2.INF:
			_grab(lip)
			return
	move_and_slide()
	if is_on_floor():
		_land()
		return
	if velocity.y > 90.0 and anim.clip_name != "fall" and (anim.finished() or not _long) and _melee != "jump_kick":
		anim.play("fall", 0.2)


func _land() -> void:
	var fall := global_position.y - _peak_y
	if _melee == "jump_kick":
		_melee = ""
	state = S.GROUND
	_long = false
	Fx.puff(global_position, 5 if fall > 40.0 else 3)
	if fall > HURT_FALL:
		hurt(1, Vector2.ZERO)
	if fall > ROLL_FALL and state != S.DEAD:
		state = S.ROLL
		anim.play("roll", 0.05, 0.0, true)
		Audio.play("roll", -4.0)
		Fx.add_shake(0.25)
		return
	if absf(velocity.x) > FAST:
		anim.play("run", 0.08)
	else:
		anim.play("land", 0.03, 0.0, true)
	Audio.play("land", -6.0 if fall < 40.0 else -2.0, 1.0, 0.1)


func _roll(delta: float) -> void:
	velocity.x = move_toward(velocity.x, facing * 60.0, 200.0 * delta)
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	move_and_slide()
	if anim.finished():
		state = S.GROUND if is_on_floor() else S.AIR
		if state == S.AIR:
			_enter_air(false)


# --- Ledges --------------------------------------------------------------------

## The lip of a ledge right in front of our hands, or Vector2.INF.
func _find_ledge() -> Vector2:
	var space := get_world_2d().direct_space_state
	var f := float(facing)
	var p := global_position
	var hand_y := p.y - HANG_H
	var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -HANG_H + 4), p + Vector2(f * 10, -HANG_H + 4), 1)
	var wall := space.intersect_ray(q)
	if not wall or absf(wall.normal.x) < 0.9:
		return Vector2.INF
	var wx: float = wall.position.x
	var down := PhysicsRayQueryParameters2D.create(Vector2(wx + f * 2, hand_y - 8), Vector2(wx + f * 2, hand_y + 6), 1)
	var top := space.intersect_ray(down)
	if not top or top.normal.y > -0.9:
		return Vector2.INF
	var lip_y: float = top.position.y
	if lip_y < hand_y - 7.0 or lip_y > hand_y + 6.0:
		return Vector2.INF
	return Vector2(wx, lip_y)


func _grab(lip: Vector2) -> void:
	state = S.HANG
	_ledge = lip
	velocity = Vector2.ZERO
	global_position = Vector2(lip.x - facing * 4.5, lip.y + HANG_H)
	anim.play("hang", 0.05)
	Audio.play("grab", -4.0, 1.0, 0.1)
	Fx.puff(lip, 2, Color("#c8a070"))


func _hang(_delta: float) -> void:
	var x := _axis()
	if _held("down") or (x != 0.0 and signf(x) != float(facing)):
		state = S.AIR
		_grab_cd = 0.3
		global_position.x -= facing * 1.0
		_enter_air(false)
		anim.play("fall", 0.1)
		return
	if (_held("up") or _buffer > 0.0) and _room_on_top():
		_buffer = 0.0
		state = S.CLIMB
		anim.play("climb", 0.04)
		Audio.play("climb", -4.0)


func _room_on_top() -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 26)
	params.shape = rect
	params.collision_mask = 1
	params.transform = Transform2D(0.0, Vector2(_ledge.x + facing * 8.0, _ledge.y - 14.0))
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _climb(_delta: float) -> void:
	if anim.finished():
		global_position += Vector2(facing * 8.0, -HANG_H)
		state = S.GROUND
		velocity = Vector2.ZERO
		anim.play("land", 0.0, 0.0, true)


# --- Whip swing --------------------------------------------------------------------

func _on_whip_latched(kind: int, target: Variant) -> void:
	if kind == Whip.Kind.ANCHOR and state != S.DEAD and state != S.HANG and state != S.CLIMB:
		_anchor = target
		_rope_len = clampf((global_position + Vector2(0, -GRIP_H)).distance_to(_anchor.global_position), 20.0, whip.reach)
		_reel_to = -1.0
		if state == S.GROUND:
			# Tarzan lift: reel the rope in a little so the hero leaves the ground.
			_reel_to = _rope_len - 12.0
		state = S.SWING
		_swing_t = 0.0
		_skidding = false
		anim.play("swing", 0.1)
	elif kind == Whip.Kind.ACTOR and is_instance_valid(target):
		anim.play_overlay("whip_pull")
		if target.has_method("whip_pull"):
			target.whip_pull(global_position + Vector2(0, -16))


func _swing(delta: float) -> void:
	if not is_instance_valid(_anchor):
		_release_swing()
		return
	_swing_t += delta
	var a := _anchor.global_position
	var grip := global_position + Vector2(0, -GRIP_H)
	velocity.y += GRAVITY * delta
	var r := grip - a
	var tang := r.orthogonal().normalized()
	if tang.x < 0.0:
		tang = -tang
	var x := _axis()
	# Pumping only works on the downswing half, like kicking on a playground swing.
	if x != 0.0:
		velocity += tang * x * PUMP * delta
	if _held("up"):
		_rope_len = maxf(20.0, _rope_len - REEL * delta)
		_reel_to = -1.0
	elif _held("down"):
		_rope_len = minf(whip.reach, _rope_len + REEL * delta)
		_reel_to = -1.0
	elif _reel_to > 0.0:
		_rope_len = move_toward(_rope_len, _reel_to, 120.0 * delta)
	var next := grip + velocity * delta
	var d := next - a
	if d.length() > _rope_len:
		next = a + d.normalized() * _rope_len
		velocity = (next - grip) / delta
	velocity *= 1.0 - 0.15 * delta
	if absf(velocity.x) > 20.0:
		_set_facing(int(signf(velocity.x)))
	move_and_slide()
	if _pressed("whip") or _buffer > 0.0:
		_buffer = 0.0
		_release_swing(true)
		return
	if is_on_floor() and _swing_t > 0.25:
		_release_swing()
		state = S.GROUND
		anim.play("land", 0.05, 0.0, true)


func _release_swing(boost := false) -> void:
	whip.release()
	_anchor = null
	if boost:
		velocity *= 1.08
		velocity.y -= 60.0
		Audio.play("jump", -6.0, 1.1, 0.05)
	if state == S.SWING:
		_enter_air(true)
		_long = absf(velocity.x) > 90.0
		anim.play("long_jump" if _long else "jump", 0.1)


# --- Weapons -----------------------------------------------------------------------

func _can_act() -> bool:
	return state in [S.GROUND, S.AIR, S.SWING]


## Gun arm raised: aiming down the sights, or just fired from the hip.
func _arm_up() -> bool:
	return aiming or _raise_t > 0.0 or _quick


## 0..1: how far the gun arm is raised (the camera leans further out while aiming).
func aim_weight() -> float:
	return _aim_w


func add_grenades(n: int) -> void:
	grenades = mini(max_grenades, grenades + n)
	grenades_changed.emit(grenades)


func _weapons() -> void:
	whip_candidate = []
	if state == S.DEAD:
		return
	var delta := get_physics_process_delta_time()
	var hand_b := rig.point("hand_b", Vector2(0, 1))
	if _can_act() and whip.can_throw() and state != S.SWING:
		whip_candidate = whip.pick(hand_b, aim_point())
	if _can_act() and state != S.SWING and whip.can_throw() and _pressed("whip"):
		whip.throw(hand_b, aim_point())
		_whip_arm = 1.0
	whip.step(delta, hand_b)
	rig.whip_coil.visible = not whip.active()
	_grenade_input(delta)

	aiming = _held("ads") and _can_act() and state != S.SWING and not _reloading and _melee == "" and state != S.ROLL
	_raise_t = maxf(0.0, _raise_t - delta)

	# E next to a friendly face talks instead of punching.
	var npc := _npc_near() if state == S.GROUND else null
	if npc and _pressed("punch"):
		_set_facing(int(signf(npc.global_position.x - global_position.x)) if npc.global_position.x != global_position.x else facing)
		npc.talk()
	elif _can_act() and state != S.SWING:
		if _pressed("punch"):
			if _melee == "punch_a" and _melee_t > 0.06:
				_combo = true
			elif _melee == "":
				_start_melee("punch_a")
		if _pressed("kick") and _melee == "":
			_start_melee("jump_kick" if state == S.AIR else "front_kick")
	if _pressed("reload") and ammo < 6 and not _reloading:
		_start_reload()
	if _pressed("shoot") and _can_act() and not _reloading and state != S.ROLL and not _melee.ends_with("kick"):
		if ammo <= 0:
			Audio.play("empty_click", -4.0)
			_start_reload()
		elif _shot_cd <= 0.0:
			if _aim_w > 0.85:
				_shoot(0.0)
			else:
				# Quick-draw: the arm snaps up and the shot goes when it gets there.
				_quick = true
	if _quick:
		if _reloading or not _can_act() or ammo <= 0:
			_quick = false
		elif _aim_w > 0.85 and _shot_cd <= 0.0:
			_quick = false
			_shoot(QUICK_SPREAD)
	if _reloading and not anim.overlay_active():
		_reloading = false
		ammo = 6
		ammo_changed.emit(ammo, false)


## Q: a tap lobs a grenade at 45 degrees the way the hero faces; holding shows the arc
## (through the cursor) and releasing throws along it.
func _grenade_input(delta: float) -> void:
	_throw_cd = maxf(0.0, _throw_cd - delta)
	var can := state in [S.GROUND, S.AIR] and _melee == "" and _throw_cd <= 0.0
	if _pressed("grenade") and can:
		if grenades <= 0:
			Audio.play("empty_click", -6.0, 1.4)
		else:
			_q_t = 0.0
			Audio.play("grenade_pin", -8.0, 1.0, 0.05)
	if _q_t < 0.0:
		arc = []
		return
	if not can and state != S.GROUND and state != S.AIR:
		_q_t = -1.0  # grabbed a ledge, died...: put it away
		arc = []
		return
	_q_t += delta
	var from := _throw_origin()
	if _q_t >= TAP_TIME:
		_arc_vel = Grenade.solve(from, aim_point())
		arc = Grenade.predict(get_world_2d().direct_space_state, from, _arc_vel, [get_rid()])
	if not _held("grenade"):
		var vel := _arc_vel if _q_t >= TAP_TIME else Vector2(facing, -1.0).normalized() * Grenade.TAP_SPEED + velocity * 0.4
		_throw_grenade(from, vel)
		_q_t = -1.0
		arc = []


func _throw_origin() -> Vector2:
	return global_position + Vector2(facing * 4.0, -30.0)


func _throw_grenade(from: Vector2, vel: Vector2) -> void:
	grenades -= 1
	grenades_changed.emit(grenades)
	_throw_cd = 0.45
	if absf(vel.x) > 1.0:
		_set_facing(int(signf(vel.x)))
	get_parent().add_child(Grenade.make(from, vel, self))
	anim.play_overlay("throw")
	Audio.play("throw_whoosh", -6.0, 1.0, 0.1)


## Aiming a grenade (Q held past a tap).
func holding_grenade() -> bool:
	return _q_t >= 0.0


func _npc_near() -> Node2D:
	for n in get_tree().get_nodes_in_group("npc"):
		if n.near():
			return n
	return null


func _start_reload() -> void:
	_reloading = true
	anim.play_overlay("reload", 1.4 if GameState.up("loader") > 0 else 1.0)
	Audio.play("reload_open", -6.0)
	ammo_changed.emit(ammo, true)


func _shoot(spread: float) -> void:
	ammo -= 1
	_shot_cd = SHOT_COOLDOWN
	_raise_t = RAISE_HOLD
	var muzzle := rig.muzzle_global()
	var aim := aim_point()
	var dir := (aim - muzzle).normalized()
	if muzzle.distance_to(aim) < 8.0 or dir == Vector2.ZERO:
		dir = (muzzle - rig.point("hand_f")).normalized()
	if spread > 0.0:
		dir = dir.rotated(randf_range(-spread, spread))
	# Cast from the shoulder: at point blank the muzzle is already inside the target.
	var q := PhysicsRayQueryParameters2D.create(rig.point("ua_f"), muzzle + dir * SHOT_RANGE, 1 | 4)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var end: Vector2 = hit.position if hit else muzzle + dir * SHOT_RANGE
	Fx.tracer(muzzle, end)
	Fx.sparks(muzzle, dir, 3, Color("#fff0a0"))
	Fx.add_shake(0.18)
	_recoil = 1.0
	_flash_e = 1.4
	_flash.global_position = muzzle
	Audio.play("gunshot", -2.0, 1.0, 0.06)
	if hit:
		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit(1, dir, end, "bullet")
		else:
			Fx.sparks(end, hit.normal, 5)
			Fx.chips(end, hit.normal, 3)
			Audio.play_at("ricochet", end, -6.0, 0.15)
	ammo_changed.emit(ammo, false)


# --- Crouch & melee ---------------------------------------------------------------

func _set_crouch(on: bool) -> void:
	if on == crouching:
		return
	crouching = on
	var size := CROUCHED if on else STAND
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = Vector2(0, -size.y / 2.0)


## Room to stand up here (no ceiling within standing height)?
func _can_stand() -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = STAND - Vector2(1, 1)
	params.shape = rect
	params.collision_mask = 1
	params.transform = Transform2D(0.0, global_position + Vector2(0, -STAND.y / 2.0 - 0.5))
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _start_melee(move: String) -> void:
	_smear_prev = Vector2.INF
	_melee = move
	_melee_t = 0.0
	_melee_hit.clear()
	_combo = false
	_face_mouse()
	if move.begins_with("punch"):
		anim.play_overlay(move)
	else:
		anim.play(move, 0.04, 0.0, true)
	Audio.play("whoosh_punch" if move.begins_with("punch") else "whoosh_kick", -6.0, 1.0, 0.1)


func _melee_step(delta: float) -> void:
	if _melee == "":
		return
	if state not in [S.GROUND, S.AIR]:
		_melee = ""
		return
	_melee_t += delta
	var spec: Array = MELEE[_melee]
	# Air-cutting smear along the real path of the fist/boot, from just before the
	# hit window until just after.
	var tip: Array = SMEAR_TIPS[_melee]
	var at := rig.point(tip[0], tip[1])
	if _melee_t >= spec[1] - 0.05 and _melee_t <= spec[2] + 0.02:
		if _smear_prev != Vector2.INF:
			Fx.smear(_smear_prev, at, tip[2])
		_smear_prev = at
	else:
		_smear_prev = Vector2.INF
	var len: float = HeroAnims.clips[_melee]["len"]
	if _melee_t >= spec[1] and _melee_t <= spec[2]:
		var r: Rect2 = spec[0]
		if crouching:
			r.position.y += 14.0  # crouched punches reach critters on the ground
		_melee_hits(r, spec[3])
	if _melee_t >= len:
		if _melee == "punch_a" and _combo:
			_start_melee("punch_b")
		else:
			_melee = ""


func _melee_hits(r: Rect2, kind: String) -> void:
	if facing < 0:
		r.position.x = -r.position.x - r.size.x
	var params := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	params.shape = rect
	params.collision_mask = 4 | 1  # actors, plus kickable props (toppler, cracked walls)
	params.transform = Transform2D(0.0, global_position + r.get_center())
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 8):
		var c: Object = hit.collider
		if c == null or c.get_instance_id() in _melee_hit or not c.has_method("take_hit"):
			continue
		_melee_hit.append(c.get_instance_id())
		var at := global_position + r.get_center() + Vector2(facing * r.size.x * 0.3, 0)
		c.take_hit(1, Vector2(facing, 0), at, kind)
		Audio.play_at("kick_hit" if kind == "kick" else "punch_hit", at, -2.0, 0.12)
		Fx.add_shake(0.12 if kind == "punch" else 0.25)
		Fx.impact(at, Vector2(facing, 0), 0.8 if kind == "punch" else 1.3)
		Fx.hitstop(0.03 if kind == "punch" else 0.06)


# --- Damage ------------------------------------------------------------------------

func hurt(dmg: int, push: Vector2) -> void:
	if state == S.DEAD or _invuln > 0.0 or god:
		return
	_invuln = 1.0
	hp -= dmg
	Gore.of(self).burst(global_position + Vector2(0, -18), 12, (push + Vector2(0, -40)).normalized())
	if hp > 0:
		Audio.voice("human_pain", global_position, -4.0)
	health_changed.emit(hp)
	Fx.add_shake(0.4)
	Audio.play("hurt", -2.0, 1.0, 0.1)
	if hp <= 0:
		_die()
		return
	velocity += push
	if state == S.HANG or state == S.CLIMB:
		state = S.AIR
		_grab_cd = 0.4
		_enter_air(false)
	if state == S.GROUND:
		if push.y < 0.0:
			_enter_air(false)
		else:
			anim.play("hurt", 0.03, 0.0, true)


func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	health_changed.emit(hp)


## Spikes, bottomless drops: straight to death regardless of hit points.
func kill() -> void:
	if state == S.DEAD or god:
		return
	hp = 0
	_killed_by_spikes = true
	health_changed.emit(hp)
	Audio.play("hurt", 0.0)
	Fx.add_shake(0.5)
	_die()


func _die() -> void:
	state = S.DEAD
	_dead_t = 0.0
	whip.release()
	_anchor = null
	anim.play("death", 0.05)
	_spawn_corpse()
	Audio.voice("human_die", global_position, 0.0)
	died.emit()


## The hero's body goes ragdoll: a copy of the rig in the current pose, so the real
## rig stays intact (hidden) for the respawn.
func _spawn_corpse() -> void:
	var body := HeroRig.new()
	get_parent().add_child(body)
	body.global_transform = rig.global_transform
	body.facing = facing
	body.rotation = rig.rotation
	body.apply(anim.pose, 0)
	body.bones["ua_f"].rotation = rig.bones["ua_f"].rotation
	body.bones["fa_f"].rotation = rig.bones["fa_f"].rotation
	var tear: Array = []
	if _killed_by_spikes and Gore.enabled():
		tear = ["th_f", "th_b"].slice(0, 1 + randi() % 2)
	Ragdoll.from_rig(body, get_parent(), velocity + Vector2(0, -60), Vector2(-facing * 60.0, -40.0), global_position + Vector2(0, -16), tear)
	body.queue_free()
	rig.visible = false
	Gore.of(self).burst(global_position + Vector2(0, -16), 30, Vector2.UP)


func _dead(delta: float) -> void:
	_dead_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	move_and_slide()
	if _dead_t > 2.2:
		respawn()


signal respawned


func respawn() -> void:
	global_position = spawn
	rig.visible = true
	_killed_by_spikes = false
	_invuln = 1.0
	_skidding = false
	whip.release()
	velocity = Vector2.ZERO
	hp = max_hp
	ammo = 6
	_reloading = false
	_quick = false
	_q_t = -1.0
	grenades = maxi(grenades, START_GRENADES + GameState.up("bandolier"))
	grenades_changed.emit(grenades)
	health_changed.emit(hp)
	ammo_changed.emit(ammo, false)
	_enter_air(false)
	anim.play("fall", 0.0)
	respawned.emit()


# --- Pose --------------------------------------------------------------------------

func set_glow(w: float) -> void:
	_glow.energy = 0.45 * w


func _set_facing(f: int) -> void:
	if f == 0:
		return
	facing = f
	rig.facing = f


func _face_mouse() -> void:
	var dx := aim_point().x - global_position.x
	if absf(dx) > 4.0:
		_set_facing(int(signf(dx)))


func _on_anim_event(e: String) -> void:
	match e:
		"step":
			if state == S.GROUND:
				var fast := absf(velocity.x) > FAST
				Audio.play("step_dirt", -12.0 if not fast else -8.0, 1.0, 0.15)
				if fast:
					Fx.puff(global_position + Vector2(-facing * 3, 0), 2, Color("#c8a070"), Vector2(-facing * 20, 0), 10.0)
		"shell":
			Audio.play("reload_shell", -8.0, 1.0, 0.1)
		"spin":
			Audio.play("reload_spin", -6.0)


func _pose(delta: float) -> void:
	var pose := anim.advance(delta)
	var lock: int = HeroAnims.clips[anim.clip_name]["lock"]
	rig.apply(pose, lock)
	rig.motion = velocity
	# Swinging: the whole body hangs from the gripping hand and follows the rope.
	var grip := Vector2(0, -GRIP_H)
	var want := 0.0
	if state == S.SWING and is_instance_valid(_anchor):
		var to := _anchor.global_position - (global_position + grip)
		want = clampf(to.angle() + PI / 2.0, -1.3, 1.3)
	rig.rotation = lerp_angle(rig.rotation, want, minf(1.0, delta * 20.0))
	rig.position = grip - grip.rotated(rig.rotation)

	var aim := aim_point()
	var raise := _arm_up() and state in [S.GROUND, S.AIR, S.SWING] and not _reloading \
			and anim.clip_name != "hurt" and _melee == ""
	# Snapping the gun up is quick; lowering it is lazier.
	_aim_w = move_toward(_aim_w, 1.0 if raise else 0.0, delta * (9.0 if raise else 4.0))
	rig.aim_arm("f", aim, smoothstep(0.0, 1.0, _aim_w), -6.0 - _recoil * 50.0)
	(rig.bones["ua_f"] as Node2D).rotation -= _recoil * 0.35 * _aim_w
	if state in [S.GROUND, S.AIR, S.SWING]:
		rig.look_at_point(aim, 0.8)
	rig.grenade.visible = holding_grenade()
	if holding_grenade():
		# Wind up behind the shoulder, ready to throw.
		var w := clampf(_q_t / TAP_TIME, 0.0, 1.0)
		(rig.bones["ua_b"] as Node2D).rotation = lerp_angle((rig.bones["ua_b"] as Node2D).rotation, deg_to_rad(150.0), w)
		(rig.bones["fa_b"] as Node2D).rotation = lerp_angle((rig.bones["fa_b"] as Node2D).rotation, deg_to_rad(-70.0), w)
		return
	# Far arm: follows the whip tip while it's out, grips the rope when swinging.
	if state == S.SWING and is_instance_valid(_anchor):
		rig.aim_arm("b", _anchor.global_position, 1.0, 0.0)
	elif whip.active() and not anim.overlay_name == "whip_pull":
		_whip_arm = 1.0
		rig.aim_arm("b", whip.tip, 1.0, -10.0)
	else:
		_whip_arm = move_toward(_whip_arm, 0.0, delta * 6.0)
		if _whip_arm > 0.0:
			rig.aim_arm("b", whip.tip, _whip_arm, -10.0)
