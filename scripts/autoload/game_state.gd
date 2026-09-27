extends Node
## Level order and progression. Every level is open from the menu for playtesting.

const LEVELS := ["proving_grounds", "dry_gulch", "rattler_mesa", "bandit_mine", "canopy_run", "sunken_temple", "idol_chamber"]
const MAIN := "res://scenes/main.tscn"
const MENU := "res://scenes/menu.tscn"

var current := 0
var gore_on := true
var music_vol := 0.7
var sfx_vol := 1.0
## Level -> music track (assets/music/<name>.mp3, see CREDITS.md).
const MUSIC := {"proving_grounds": "canyon", "dry_gulch": "canyon", "rattler_mesa": "mesa", "bandit_mine": "mine",
		"canopy_run": "jungle", "sunken_temple": "temple", "idol_chamber": "temple", "arena": "canyon"}


func map_id() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--map")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return LEVELS[current]


func goto(i: int) -> void:
	current = clampi(i, 0, LEVELS.size() - 1)
	get_tree().change_scene_to_file.call_deferred(MAIN)


func next() -> void:
	if current + 1 < LEVELS.size():
		goto(current + 1)
	else:
		get_tree().change_scene_to_file.call_deferred(MENU)


func menu() -> void:
	get_tree().change_scene_to_file.call_deferred(MENU)
