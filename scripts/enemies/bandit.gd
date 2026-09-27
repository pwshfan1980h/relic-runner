class_name Bandit
extends Enemy
## Rifle bandit: the hero's own rig and animations, re-dressed. Patrols; on sight it
## stops, aims (a glint telegraphs the shot), fires three times, then reloads.
## The whip yanks it off its feet (and off ledges).

enum S { PATROL, AIM, COOLDOWN, RELOAD, LOST }

const SWAP := {
	HeroRig.HAT: Color("#26201e"), HeroRig.HAT_D: Color("#161212"), HeroRig.BAND: Color("#8a6a3a"),
	HeroRig.JACKET: Color("#4c4650"), HeroRig.JACKET_D: Color("#34303a"), HeroRig.JACKET_L: Color("#5e5864"),
	HeroRig.SHIRT: Color("#a82a20"), HeroRig.TROUSER: Color("#6a5238"), HeroRig.TROUSER_D: Color("#4e3c28"),
	HeroRig.SKIN: Color("#c8905c"), HeroRig.SKIN_D: Color("#9a6a40"), HeroRig.SATCHEL: Color("#8a6a2a"),
}
const SIGHT := 230.0
const AIM_TIME := 0.8

var rig: HeroRig
var anim: HeroAnims.Animator
var state := S.PATROL
var _st := 0.0
var _shots := 0
var _aim_at := Vector2.ZERO


func _setup() -> void:
	size = Vector2(8, 28)
	hp = 2
	voice_hurt = "human_pain"
	rig = HeroRig.new()
	rig.recolor(SWAP)
	rig.make_rifle()
	rig.whip_coil.visible = false
	add_child(rig)
	anim = HeroAnims.Animator.new()
	anim.play("idle", 0.0)


func _think(delta: float) -> void:
	_st += delta
	var seen := sees_hero(SIGHT, Vector2(0, -24))
	match state:
		S.PATROL:
			patrol(26.0, delta, 60.0)
			if seen:
				_go(S.AIM)
		S.AIM:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			_face_hero()
			if not seen:
				_go(S.LOST)
			elif _st > AIM_TIME:
				_fire()
				_shots += 1
				_go(S.RELOAD if _shots >= 3 else S.COOLDOWN)
		S.COOLDOWN:
			if _st > 0.7:
				_go(S.AIM if seen else S.LOST)
		S.RELOAD:
			if _st < 0.05:
				anim.play_overlay("reload")
				Audio.play_at("reload_open", global_position, -8.0)
			if _st > 1.6:
				_shots = 0
				_go(S.AIM if seen else S.LOST)
		S.LOST:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			if seen:
				_go(S.AIM)
			elif _st > 1.5:
				_go(S.PATROL)


func _go(s: S) -> void:
	state = s
	_st = 0.0


func _face_hero() -> void:
	var d := to_hero()
	if absf(d.x) > 2.0:
		facing = int(signf(d.x))


func _fire() -> void:
	var muzzle := rig.muzzle_global()
	# Chest height of a standing man: crouching under it dodges the shot.
	var target := hero.global_position + Vector2(randf_range(-3, 3), -24 + randf_range(-3, 3))
	var dir := (target - muzzle).normalized()
	var q := PhysicsRayQueryParameters2D.create(muzzle, muzzle + dir * 420.0, 1 | 2)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var end: Vector2 = hit.position if hit else muzzle + dir * 420.0
	Fx.tracer(muzzle, end, Color("#ffd8a0"))
	Fx.sparks(muzzle, dir, 3, Color("#fff0a0"))
	Audio.play_at("rifle", muzzle, -2.0, 0.08)
	if hit:
		if hit.collider is Hero:
			(hit.collider as Hero).hurt(1, Vector2(dir.x * 90.0, -60.0))
		else:
			Fx.sparks(end, hit.normal, 4)


func _on_pulled() -> void:
	anim.play("hurt", 0.03, 0.0, true)
	state = S.LOST
	_st = 0.0


func _on_hit() -> void:
	if not dead:
		anim.play("hurt", 0.03, 0.0, true)
		if state == S.PATROL:
			_face_hero()
			_go(S.AIM)


## Headshots (top 7px of the body) kill outright.
func take_hit(dmg: int, dir: Vector2, at: Vector2, kind := "bullet") -> void:
	if not dead and kind == "bullet" and at.y < global_position.y - size.y + 7.0:
		dmg = hp
		kind = "headshot"
	super(dmg, dir, at, kind)


func _on_die() -> void:
	ragdoll_death(rig)


func _physics_process(delta: float) -> void:
	super(delta)
	rig.modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	if dead:
		# Base class fades us; keep drawing the rig's death pose.
		rig.apply(anim.advance(delta), 2)
		return
	rig.facing = facing
	if stun <= 0.0 and not (anim.clip_name == "hurt" and not anim.finished()):
		if absf(velocity.x) > 5.0 and is_on_floor():
			anim.play("walk", 0.12)
			anim.speed = absf(velocity.x) / 44.0
		elif is_on_floor():
			anim.play("idle", 0.15)
			anim.speed = 1.0
		else:
			anim.play("fall", 0.15)
	var pose := anim.advance(delta)
	rig.apply(pose, HeroAnims.clips[anim.clip_name]["lock"])
	var aiming := state == S.AIM or state == S.COOLDOWN
	if aiming and hero != null:
		var aim := hero.global_position + Vector2(0, -18)
		# The rifle is shouldered: both hands on it.
		rig.aim_arm("f", aim, 1.0, -4.0)
		rig.aim_arm("b", aim, 1.0, -40.0)
		rig.look_at_point(aim, 0.8)


func _draw() -> void:
	# Muzzle glint just before the shot: the tell for the player to take cover.
	if state == S.AIM and _st > AIM_TIME - 0.3 and not dead:
		var m := to_local(rig.muzzle_global())
		var r := 2.0 + sin(_st * 40.0)
		draw_line(m + Vector2(-r, 0), m + Vector2(r, 0), Color("#fff4c0"), 1.0)
		draw_line(m + Vector2(0, -r), m + Vector2(0, r), Color("#fff4c0"), 1.0)
