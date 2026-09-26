class_name HeroRig
extends Node2D
## The adventurer, built from flat-shaded polygon parts hung on a bone hierarchy
## (Another World / Flashback style cut-out). Facing right, feet at (0, 0), ~32px tall.
##
## Pose channels (degrees / pixels), see HeroAnims:
##   hx hy hr   hip offset + hip rotation (hr spins the whole body: rolls, death)
##   torso      lean, + = forward            head  ABSOLUTE tilt, + = looking down
##   ua_* fa_*  upper/fore arm, - = forward  (f = near/gun arm, b = far/whip arm)
##   th_* sh_*  thigh (- = forward), shin (+ = knee bend)
##   ft_*       ABSOLUTE foot angle, 0 = flat, + = toe down
##   hat        hat tilt on the head (idle fidget)

const HIP_Y := -15.0

# Palette: dusty 90s adventure. Far-side parts get BACK_TINT for depth.
const HAT := Color("#6e4b2a")
const HAT_D := Color("#4a3019")
const BAND := Color("#231710")
const SKIN := Color("#e0a870")
const SKIN_D := Color("#b37a4c")
const HAIR := Color("#3a2616")
const JACKET := Color("#8a5429")
const JACKET_D := Color("#5e3719")
const JACKET_L := Color("#a8693a")
const SHIRT := Color("#e3d3a4")
const TROUSER := Color("#b99d6a")
const TROUSER_D := Color("#8a7148")
const BOOT := Color("#3a2519")
const BOOT_D := Color("#22160e")
const BELT := Color("#2b1b10")
const SATCHEL := Color("#7b6a42")
const STEEL := Color("#2c2c33")
const STEEL_L := Color("#8c8f99")
const GRIP := Color("#5a3a22")
const WHIP := Color("#3b2616")
const BACK_TINT := Color(0.66, 0.62, 0.62)

var bones := {}  # name -> Node2D
var hips: Node2D
var whip_coil: Node2D  # hidden while the whip is out
var gun: Node2D
var facing := 1:
	set(v):
		facing = 1 if v >= 0 else -1
		scale.x = facing

# Points used for ground locking: [bone, local point]. Feet first (used for "feet" mode).
var _feet_pts: Array = []
var _body_pts: Array = []


static var _climb_patched := false


func _init() -> void:
	_build()
	if not _climb_patched:
		_climb_patched = true
		_patch_climb()


## The climb clip ends in the landing crouch 35px up (the hang height). Patch its final
## hip height with the crouch's measured ground lock, so snapping onto the ledge and
## playing "land" is seamless.
func _patch_climb() -> void:
	HeroAnims.build()
	apply(HeroAnims.clips["land"]["keys"][0][1], 1)
	var drop := hips.position.y - HIP_Y
	var keys: Array = HeroAnims.clips["climb"]["keys"]
	keys[-1][1]["hy"] = -35.0 + drop
	apply(HeroAnims.BASE, 0)


func _bone(name: String, parent: Node2D, pos: Vector2) -> Node2D:
	var b := Node2D.new()
	b.name = name
	b.position = pos
	parent.add_child(b)
	bones[name] = b
	return b


func _poly(bone: Node2D, pts: PackedVector2Array, color: Color, z: int, tint := false) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color * BACK_TINT if tint else color
	p.color.a = 1.0
	p.z_index = z
	p.antialiased = false
	bone.add_child(p)
	return p


static func circle(c: Vector2, r: float, n := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(c + Vector2(r, 0).rotated(TAU * i / n))
	return out


func _build() -> void:
	hips = _bone("hips", self, Vector2(0, HIP_Y))
	var torso := _bone("torso", hips, Vector2.ZERO)
	var head := _bone("head", torso, Vector2(0.4, -10.4))
	var hat := _bone("hat", head, Vector2.ZERO)
	for side in ["f", "b"]:
		var far: bool = side == "b"
		var z_arm := 8 if not far else -8
		var z_leg := 2 if not far else -4
		var ua := _bone("ua_" + side, torso, Vector2(0.9 if not far else -0.7, -9.0))
		var fa := _bone("fa_" + side, ua, Vector2(0, 5.0))
		var hand := _bone("hand_" + side, fa, Vector2(0, 4.4))
		var th := _bone("th_" + side, hips, Vector2(0.6 if not far else -0.6, 0))
		var sh := _bone("sh_" + side, th, Vector2(0, 7.0))
		var ft := _bone("ft_" + side, sh, Vector2(0, 6.5))
		# Arm: leather sleeve, rolled khaki cuff, bare forearm, fist.
		_poly(ua, PackedVector2Array([Vector2(-1.4, -0.8), Vector2(1.4, -0.8), Vector2(1.2, 5.3), Vector2(-1.1, 5.3)]), JACKET, z_arm, far)
		_poly(ua, PackedVector2Array([Vector2(-1.4, -0.8), Vector2(-0.2, -0.8), Vector2(-0.1, 5.3), Vector2(-1.1, 5.3)]), JACKET_D, z_arm, far)
		_poly(fa, PackedVector2Array([Vector2(-0.9, 0.2), Vector2(0.9, 0.2), Vector2(0.75, 4.5), Vector2(-0.75, 4.5)]), SKIN, z_arm, far)
		_poly(fa, PackedVector2Array([Vector2(-0.9, 0.2), Vector2(-0.1, 0.2), Vector2(-0.1, 4.5), Vector2(-0.75, 4.5)]), SKIN_D, z_arm, far)
		_poly(fa, PackedVector2Array([Vector2(-1.3, -0.4), Vector2(1.3, -0.4), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)]), SHIRT, z_arm, far)
		_poly(hand, circle(Vector2(0, 0.8), 1.15, 6), SKIN, z_arm + 1, far)
		# Leg: khaki trousers into knee boots.
		_poly(th, PackedVector2Array([Vector2(-1.8, -0.6), Vector2(1.8, -0.6), Vector2(1.4, 7.3), Vector2(-1.4, 7.3)]), TROUSER, z_leg, far)
		_poly(th, PackedVector2Array([Vector2(-1.8, -0.6), Vector2(-0.4, -0.6), Vector2(-0.3, 7.3), Vector2(-1.4, 7.3)]), TROUSER_D, z_leg, far)
		_poly(sh, PackedVector2Array([Vector2(-1.4, 0), Vector2(1.4, 0), Vector2(1.3, 3.2), Vector2(-1.3, 3.2)]), TROUSER, z_leg, far)
		_poly(sh, PackedVector2Array([Vector2(-1.45, 2.8), Vector2(1.45, 2.8), Vector2(1.35, 6.8), Vector2(-1.35, 6.8)]), BOOT, z_leg, far)
		_poly(sh, PackedVector2Array([Vector2(-1.5, 2.6), Vector2(1.5, 2.6), Vector2(1.5, 3.3), Vector2(-1.5, 3.3)]), BOOT_D, z_leg, far)
		_poly(ft, PackedVector2Array([Vector2(-1.5, -0.6), Vector2(1.4, -0.6), Vector2(1.9, 0.2), Vector2(3.9, 0.5), Vector2(4.2, 1.5), Vector2(-1.6, 1.5)]), BOOT, z_leg, far)
		_poly(ft, PackedVector2Array([Vector2(-1.6, 1.0), Vector2(4.2, 1.0), Vector2(4.2, 1.5), Vector2(-1.6, 1.5)]), BOOT_D, z_leg, far)
		_feet_pts.append([ft, Vector2(-1.6, 1.5)])
		_feet_pts.append([ft, Vector2(4.2, 1.5)])
		_body_pts.append([sh, Vector2(0, 0)])
		_body_pts.append([hand, Vector2(0, 1)])

	# Torso: leather jacket with a back tail, khaki shirt V, belt, satchel strap.
	_poly(torso, PackedVector2Array([Vector2(-2.6, 2.6), Vector2(-0.6, 1.2), Vector2(2.7, 1.2), Vector2(3.3, -6.0),
			Vector2(2.9, -9.6), Vector2(1.5, -10.6), Vector2(-1.8, -10.6), Vector2(-2.9, -9.2), Vector2(-3.0, -5.0)]), JACKET, 0)
	_poly(torso, PackedVector2Array([Vector2(-2.6, 2.6), Vector2(-0.6, 1.2), Vector2(-0.7, -10.6), Vector2(-1.8, -10.6),
			Vector2(-2.9, -9.2), Vector2(-3.0, -5.0)]), JACKET_D, 0)
	_poly(torso, PackedVector2Array([Vector2(2.4, -8.5), Vector2(3.3, -6.0), Vector2(2.9, -3.0), Vector2(2.5, -5.5)]), JACKET_L, 0)
	_poly(torso, PackedVector2Array([Vector2(0.6, -10.5), Vector2(2.5, -10.1), Vector2(1.7, -7.2)]), SHIRT, 0)
	_poly(torso, PackedVector2Array([Vector2(-2.7, 0.0), Vector2(2.8, 0.0), Vector2(2.8, 1.3), Vector2(-2.7, 1.3)]), BELT, 0)
	_poly(torso, PackedVector2Array([Vector2(2.3, -10.0), Vector2(2.9, -9.4), Vector2(-2.0, -0.4), Vector2(-2.6, -1.0)]), SATCHEL * Color(0.7, 0.7, 0.7), 0)
	# Satchel bag on the far hip and the coiled whip on the near hip.
	_poly(hips, PackedVector2Array([Vector2(-4.3, -1.5), Vector2(-1.4, -1.5), Vector2(-1.2, 3.0), Vector2(-4.1, 3.0)]), SATCHEL, -1)
	_poly(hips, PackedVector2Array([Vector2(-4.3, -1.5), Vector2(-1.4, -1.5), Vector2(-1.4, -0.4), Vector2(-4.3, -0.4)]), SATCHEL * Color(0.75, 0.75, 0.75), -1)
	whip_coil = Node2D.new()
	hips.add_child(whip_coil)
	_poly(whip_coil, circle(Vector2(1.6, 2.0), 1.9, 8), WHIP, 3)
	_poly(whip_coil, circle(Vector2(1.6, 2.0), 0.8, 6), TROUSER_D, 3)

	# Head: face with nose, stubble shade, hair under the hat, one eye.
	_poly(head, PackedVector2Array([Vector2(-0.9, 1.2), Vector2(1.0, 1.2), Vector2(1.0, -0.6), Vector2(-0.9, -0.6)]), SKIN_D, 1)
	_poly(head, circle(Vector2(0.3, -2.3), 2.35, 8), SKIN, 1)
	_poly(head, PackedVector2Array([Vector2(2.3, -2.6), Vector2(3.3, -1.6), Vector2(2.4, -1.2)]), SKIN, 1)
	_poly(head, PackedVector2Array([Vector2(-0.4, -0.6), Vector2(2.2, -0.9), Vector2(1.6, 0.0), Vector2(0.0, 0.1)]), SKIN_D, 1)
	_poly(head, PackedVector2Array([Vector2(-2.2, -4.2), Vector2(-0.8, -4.2), Vector2(-1.2, -1.2), Vector2(-2.0, -1.4)]), HAIR, 1)
	_poly(head, PackedVector2Array([Vector2(1.3, -3.2), Vector2(2.1, -3.2), Vector2(2.1, -2.5), Vector2(1.3, -2.5)]), BELT, 1)
	# Fedora: pinched crown, dark band, wide brim dipping at the front.
	_poly(hat, PackedVector2Array([Vector2(-2.3, -4.3), Vector2(2.5, -4.3), Vector2(2.2, -6.5), Vector2(1.2, -7.1),
			Vector2(0.2, -6.6), Vector2(-1.2, -7.0), Vector2(-2.1, -6.1)]), HAT, 2)
	_poly(hat, PackedVector2Array([Vector2(-2.3, -4.3), Vector2(-0.4, -4.3), Vector2(-0.6, -6.8), Vector2(-1.2, -7.0), Vector2(-2.1, -6.1)]), HAT_D, 2)
	_poly(hat, PackedVector2Array([Vector2(-2.3, -4.2), Vector2(2.5, -4.2), Vector2(2.45, -5.0), Vector2(-2.25, -5.0)]), BAND, 2)
	_poly(hat, PackedVector2Array([Vector2(-4.0, -3.7), Vector2(-3.8, -4.5), Vector2(4.2, -4.6), Vector2(4.7, -3.6), Vector2(3.6, -3.4)]), HAT_D, 2)
	_body_pts.append([hat, Vector2(0.6, -7.0)])
	_body_pts.append([head, Vector2(-2.0, -1.5)])
	_body_pts.append([torso, Vector2(-3.0, -5.0)])
	_body_pts.append([torso, Vector2(3.3, -6.0)])
	_body_pts.append([torso, Vector2(0.0, -10.6)])
	_body_pts.append([torso, Vector2(-2.6, 2.6)])

	# Revolver in the near hand; local +y runs along the forearm, so the barrel continues the arm.
	gun = Node2D.new()
	bones["hand_f"].add_child(gun)
	_poly(gun, PackedVector2Array([Vector2(-0.3, 0.6), Vector2(-2.6, -0.5), Vector2(-2.9, 0.6), Vector2(-0.5, 1.6)]), GRIP, 7)
	_poly(gun, PackedVector2Array([Vector2(-0.55, 0.4), Vector2(0.55, 0.4), Vector2(0.45, 5.4), Vector2(-0.45, 5.4)]), STEEL, 10)
	_poly(gun, PackedVector2Array([Vector2(-0.95, 0.8), Vector2(0.95, 0.8), Vector2(0.95, 2.4), Vector2(-0.95, 2.4)]), STEEL, 10)
	_poly(gun, PackedVector2Array([Vector2(0.2, 2.6), Vector2(0.5, 2.6), Vector2(0.45, 5.2), Vector2(0.2, 5.2)]), STEEL_L, 10)


## Local muzzle point on the gun node.
const MUZZLE := Vector2(0, 5.6)


func muzzle_global() -> Vector2:
	return gun.to_global(MUZZLE)


func point(bone: String, local := Vector2.ZERO) -> Vector2:
	return (bones[bone] as Node2D).to_global(local)


## Applies a pose. lock: 0 none, 1 feet on the ground, 2 any body part on the ground.
func apply(pose: Dictionary, lock := 0) -> void:
	hips.position = Vector2(pose.get("hx", 0.0), HIP_Y)
	hips.rotation_degrees = pose.get("hr", 0.0)
	var torso: float = pose.get("torso", 0.0)
	bones["torso"].rotation_degrees = torso
	bones["head"].rotation_degrees = pose.get("head", 0.0) - torso
	bones["hat"].rotation_degrees = pose.get("hat", 0.0)
	for s in ["f", "b"]:
		bones["ua_" + s].rotation_degrees = pose.get("ua_" + s, 0.0)
		bones["fa_" + s].rotation_degrees = pose.get("fa_" + s, 0.0)
		var th: float = pose.get("th_" + s, 0.0)
		var sh: float = pose.get("sh_" + s, 0.0)
		bones["th_" + s].rotation_degrees = th
		bones["sh_" + s].rotation_degrees = sh
		bones["ft_" + s].rotation_degrees = pose.get("ft_" + s, 0.0) - th - sh
	if lock > 0:
		# Sink half a pixel so soles sit on the ground line instead of above it.
		hips.position.y -= lowest(lock == 2) - 0.5
	hips.position.y += pose.get("hy", 0.0)


## Rig-local y of the lowest contact point (0 = feet on the ground).
func lowest(whole_body := false) -> float:
	var y := -INF
	for p in _feet_pts:
		y = maxf(y, _rig_local(p).y)
	if whole_body:
		for p in _body_pts:
			y = maxf(y, _rig_local(p).y + 1.0)
	return y


func _rig_local(p: Array) -> Vector2:
	# Walk the parent chain by hand; global transforms may be stale mid-frame.
	var node: Node2D = p[0]
	var v: Vector2 = p[1]
	while node != self:
		v = node.transform * v
		node = node.get_parent()
	return v


## Rig-local position of a bone point (unaffected by facing flip).
func local_point(bone: String, local := Vector2.ZERO) -> Vector2:
	return _rig_local([bones[bone], local])


## Rotates an arm so it points at a global target. weight blends from the animated pose.
## bend is the forearm angle to use while aiming (recoil kicks it).
func aim_arm(side: String, target: Vector2, weight: float, bend := 0.0) -> void:
	if weight <= 0.0:
		return
	var ua: Node2D = bones["ua_" + side]
	# Torso transform built from the rig down (global transforms may be stale mid-frame).
	var torso_xf := get_global_transform() * hips.transform * (bones["torso"] as Node2D).transform
	var d := torso_xf.affine_inverse() * target - ua.position
	ua.rotation = lerp_angle(ua.rotation, d.angle() - PI / 2.0, weight)
	var fa: Node2D = bones["fa_" + side]
	fa.rotation = lerp_angle(fa.rotation, deg_to_rad(bend), weight)


## Absolute head tilt toward a global point, clamped to a natural range.
func look_at_point(target: Vector2, weight: float) -> void:
	var head: Node2D = bones["head"]
	var d := _rig_local_from_global(target) - _rig_local([head, Vector2(0.5, -2.5)])
	if d.x < 2.0:
		return
	var a := clampf(rad_to_deg(d.angle()), -35.0, 30.0) * 0.7
	var torso_deg: float = bones["torso"].rotation_degrees + hips.rotation_degrees
	head.rotation_degrees = lerpf(head.rotation_degrees, a - torso_deg, weight)


func _rig_local_from_global(g: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * g
