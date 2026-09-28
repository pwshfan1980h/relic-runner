extends SceneTree
## Prints where the striking fist/boot is during each melee move's active window,
## relative to its hitbox (facing right, feet at 0,0). Run:
##   godot --headless --path . -s tools/melee_check.gd

const TIPS := {"punch_a": ["hand_f", Vector2(0, 1)], "punch_b": ["hand_b", Vector2(0, 1)],
		"front_kick": ["ft_f", Vector2(4.2, 0.5)], "jump_kick": ["ft_f", Vector2(4.2, 0.5)]}


func _init() -> void:
	var rig := HeroRig.new()
	root.add_child(rig)
	for move in Hero.MELEE:
		var spec: Array = Hero.MELEE[move]
		var r: Rect2 = spec[0]
		var clip: Dictionary = HeroAnims.clips[move]
		var tip: Array = TIPS[move]
		var line := "%-10s rect=%s  tips:" % [move, r]
		var t: float = spec[1]
		while t <= spec[2] + 0.001:
			var pose := HeroAnims.BASE.duplicate()
			var p := HeroAnims.sample(clip, t)
			if move.begins_with("punch"):
				for ch in HeroAnims.ARMS:
					pose[ch] = p[ch]
			else:
				pose = p
			rig.apply(pose, HeroAnims.clips[move]["lock"] if not move.begins_with("punch") else 1)
			var at := rig.local_point(tip[0], tip[1])
			line += " %s%s" % [at.round(), "" if r.grow(1).has_point(at) else "!"]
			t += 0.03
		print(line)
	quit()
