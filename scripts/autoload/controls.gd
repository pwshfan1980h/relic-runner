extends Node
## Registers the input map in code so it lives in one readable place.
## WASD move, Shift run, Space jump, left click revolver, right click whip, R reload.

const KEYS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"up": [KEY_W, KEY_UP],
	"down": [KEY_S, KEY_DOWN],
	"run": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"reload": [KEY_R],
	"restart": [KEY_BACKSPACE],
	"menu": [KEY_ESCAPE],
	"crouch": [KEY_C],
	"punch": [KEY_E],
	"kick": [KEY_F],
	"inventory": [KEY_TAB, KEY_I],
}
const MOUSE := {
	"shoot": MOUSE_BUTTON_LEFT,
	"whip": MOUSE_BUTTON_RIGHT,
}


func _ready() -> void:
	for action in KEYS:
		_ensure(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Ctrl also crouches on desktop; in a browser Ctrl+W would close the tab.
	if not OS.has_feature("web"):
		var ctrl := InputEventKey.new()
		ctrl.physical_keycode = KEY_CTRL
		InputMap.action_add_event("crouch", ctrl)
	for action in MOUSE:
		_ensure(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE[action]
		InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
