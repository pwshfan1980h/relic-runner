class_name Brawler
extends Enemy
## Melee humans on the hero's rig.
##   "brute":   a big, bald bruiser. Chases, telegraphs a two-punch combo, then a
##              shoulder barge. The whip only staggers him, bullets barely move him:
##              kicks, ledges and spikes are the answer.
##   "machete": a bandit with a blade. Closes fast, raises it (the tell), chops.

enum S { PATROL, CHASE, WINDUP, ATTACK, BARGE, RECOVER }

const BRUTE_SWAP := {
	HeroRig.JACKET: Color("#3a2820"), HeroRig.JACKET_D: Color("#281a14"), HeroRig.JACKET_L: Color("#4e3628"),
	HeroRig.SHIRT: Color("#c8905c"), HeroRig.TROUSER: Color("#4a4038"), HeroRig.TROUSER_D: Color("#342c26"),
	HeroRig.SKIN: Color("#c8905c"), HeroRig.SKIN_D: Color("#9a6a40"), HeroRig.SATCHEL: Color("#5a4028"),
}
const MACHETE_SWAP := {
	HeroRig.HAT: Color("#a89a70"), HeroRig.HAT_D: Color("#7a6e50"), HeroRig.BAND: Color("#5a2a1a"),
	HeroRig.JACKET: Color("#e0d6c0"), HeroRig.JACKET_D: Color("#b0a690"), HeroRig.JACKET_L: Color("#f0e8d8"),
	HeroRig.SHIRT: Color("#a82a20"), HeroRig.TROUSER: Color("#5a5a6a"), HeroRig.TROUSER_D: Color("#42424e"),
	HeroRig.SKIN: Color("#b88050"), HeroRig.SKIN_D: Color("#8a5a34"),
}

var style := "brute"
var rig: HeroRig
var anim: HeroAnims.Animator
var state := S.PATROL
var _st := 0.0
var _combo := 0  # brute: punches thrown in this combo
var _struck := false
var _speed := 60.0
var _reach := 18.0


func _setup() -> void:
	var brute := style == "brute"
	size = Vector2(10, 36) if brute else Vector2(8, 28)
	hp = 5 if brute else 2
	pullable = not brute
	knock_scale = 0.4 if brute else 1.0
	_speed = 58.0 if brute else 72.0
	_reach = 20.0 if brute else 22.0
	voice_hurt = "human_pain"
	loot = {"coins": [4, 9], "items": 0.8, "luck": 0.35, "bandage": 0.3} if brute else {"coins": [2, 5], "items": 0.4, "bandage": 0.2}
	rig = HeroRig.new()
	if brute:
		rig.size_scale = 1.3
		rig.recolor(BRUTE_SWAP)
		rig.make_brute_head()
		rig.gun.visible = false
	else:
		rig.recolor(MACHETE_SWAP)
		rig.make_machete()
	rig.whip_coil.visible = false
	add_child(rig)
	rig.facing = facing
	anim = HeroAnims.Animator.new()
	anim.play("idle", 0.0)


func _think(delta: float) -> void:
	_st += delta
	var d := to_hero()
	var seen := sees_hero(210.0, Vector2(0, -size.y + 6))
	match state:
		S.PATROL:
			patrol(24.0, delta, 60.0)
			if seen and absf(d.y) < 40.0:
				_go(S.CHASE)
				Audio.voice("human_pain", global_position, -8.0)
		S.CHASE:
			_face(d)
			if not hero_alive() or absf(d.y) > 60.0 or absf(d.x) > 260.0:
				_go(S.PATROL)
			elif absf(d.x) < _reach:
				velocity.x = 0.0
				_go(S.WINDUP)
				anim.play_overlay("windup" if style == "brute" else "raise_blade")
			else:
				var dir := facing
				velocity.x = move_toward(velocity.x, dir * _speed if can_walk(dir) else 0.0, 500.0 * delta)
		S.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _st > (0.42 if style == "brute" else 0.32):
				_go(S.ATTACK)
				_struck = false
				anim.play_overlay("punch_a" if style == "brute" and _combo == 0 else ("punch_b" if style == "brute" else "chop"))
				Audio.play_at("whoosh_punch" if style == "brute" else "whoosh_kick", global_position, -4.0, 0.1)
		S.ATTACK:
			if not _struck and _st > 0.04:
				var push := Vector2(200, -120) if style == "brute" else Vector2(120, -80)
				_struck = strike(Rect2(2, -size.y + 2, _reach + 4, size.y - 6), 1, push)
				if _struck:
					Audio.play_at("punch_hit" if style == "brute" else "hit_flesh", hero.global_position, 0.0)
			if _st > 0.22:
				_combo += 1
				if style == "brute" and _combo == 1 and absf(d.x) < _reach + 10.0:
					_go(S.WINDUP)
					anim.play_overlay("windup")
				elif style == "brute" and _combo >= 1:
					_combo = 0
					_go(S.BARGE)
					anim.play("barge", 0.08)
					Audio.voice("human_pain", global_position, -4.0)
				else:
					_combo = 0
					_go(S.RECOVER)
		S.BARGE:
			var dir := facing
			velocity.x = dir * 170.0 if can_walk(dir, 14.0) else 0.0
			if not _struck:
				_struck = strike(Rect2(0, -size.y + 4, 16, size.y - 4), 1, Vector2(260, -160))
			if _st > 0.6 or velocity.x == 0.0:
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _st > 0.7:
				_go(S.CHASE if seen else S.PATROL)


func _go(s: S) -> void:
	state = s
	_st = 0.0
	if s == S.BARGE:
		_struck = false


func _face(d: Vector2) -> void:
	if d != Vector2.INF and absf(d.x) > 2.0:
		facing = int(signf(d.x))


## The brute won't be dragged: the whip just staggers him.
func _resist_whip() -> void:
	stun = 0.3
	_flash = 0.1
	anim.play("hurt", 0.03, 0.0, true)
	Audio.voice("human_pain", global_position, -4.0)


func _on_pulled() -> void:
	anim.play("hurt", 0.03, 0.0, true)
	state = S.RECOVER
	_st = 0.0


func _on_hit() -> void:
	if not dead:
		anim.play("hurt", 0.03, 0.0, true)
		if state == S.PATROL:
			_go(S.CHASE)


## Headshots kill outright (the brute has a thick skull: they count double instead).
func take_hit(dmg: int, dir: Vector2, at: Vector2, kind := "bullet") -> void:
	if not dead and kind == "bullet" and at.y < global_position.y - size.y + 8.0:
		dmg = 2 if style == "brute" else hp
		kind = "headshot"
	super(dmg, dir, at, kind)


func _on_die() -> void:
	ragdoll_death(rig)


func _physics_process(delta: float) -> void:
	super(delta)
	if dead or not is_instance_valid(rig):
		return
	rig.modulate = Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	rig.facing = facing
	var busy := anim.clip_name == "hurt" and not anim.finished() or state == S.BARGE
	if not busy:
		if absf(velocity.x) > 50.0 and is_on_floor():
			anim.play("run", 0.12)
			anim.speed = absf(velocity.x) / 125.0 * 1.3
		elif absf(velocity.x) > 5.0 and is_on_floor():
			anim.play("walk", 0.12)
			anim.speed = absf(velocity.x) / 44.0
		elif is_on_floor():
			anim.play("idle", 0.15)
			anim.speed = 1.0
		else:
			anim.play("fall", 0.15)
	rig.apply(anim.advance(delta), HeroAnims.clips[anim.clip_name]["lock"])
	if state == S.CHASE or state == S.WINDUP:
		rig.look_at_point(hero.global_position + Vector2(0, -20), 0.8)
