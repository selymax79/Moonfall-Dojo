## Named InputMap bindings and fresh physical presses; persistence belongs to RunRecords.
extends RefCounted

const ACTIONS = ["turn_left", "turn_right", "jump", "duck", "punch", "kick", "pause_game", "menu_up", "menu_down", "menu_left", "menu_right", "menu_accept", "menu_back"]
const LABELS = ["Turn Left", "Turn Right", "Jump", "Duck", "Punch", "Kick", "Pause", "Menu Up", "Menu Down", "Menu Left", "Menu Right", "Menu Accept", "Menu Cancel"]
const KEYS = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_Z, KEY_X, KEY_P, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_ESCAPE]
const BUTTONS = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_Y, JOY_BUTTON_X, JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_B]
const AXES = {0: [0, -1], 1: [0, 1], 7: [1, -1], 8: [1, 1], 9: [0, -1], 10: [0, 1]}
var bindings: Dictionary = {}
# Kept across Main replacement: a held stick/button cannot become a new run's first action.
var held: Dictionary = {}


func _init() -> void:
	bindings = defaults()


func defaults() -> Dictionary:
	var result := {}
	for index in ACTIONS.size():
		result[ACTIONS[index]] = {"key": int(KEYS[index]), "pad": ["button", int(BUTTONS[index])]}
		if AXES.has(index):
			result[ACTIONS[index]].pad = ["direction", int(BUTTONS[index]), AXES[index][0], AXES[index][1]]
	return result


## Validate the complete mapping before applying it. Bad/conflicting data restores all defaults.
func load_bindings(value: Variant) -> void:
	bindings = defaults()
	if value is Dictionary and value.size() == ACTIONS.size():
		var valid := true
		for action in ACTIONS:
			if not value.has(action) or not valid_binding(value[action]):
				valid = false
			elif action != "menu_back" and value[action].key == KEY_ESCAPE:
				valid = false # Esc remains the keyboard recovery route out of Controls.
		if valid:
			var previous := bindings
			bindings = value.duplicate(true)
			for action in ACTIONS:
				for device in ["key", "pad"]:
					if not conflict(action, device, bindings[action][device]).is_empty():
						valid = false
			if not valid:
				bindings = previous
	apply()


func valid_binding(value: Variant) -> bool:
	if not value is Dictionary or not value.has("key") or not value.has("pad"):
		return false
	var key: Variant = value.key
	if not key is int or key <= 0 or key > KEY_LAUNCHF or key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return false
	if OS.find_keycode_from_string(OS.get_keycode_string(key)) != key: return false
	var pad: Variant = value.pad
	if not pad is Array or pad.size() < 2 or not pad[1] is int:
		return false
	if pad[0] == "button":
		return pad.size() == 2 and pad[1] >= 0 and pad[1] < JOY_BUTTON_MAX and pad[1] != JOY_BUTTON_BACK
	if pad[0] == "axis":
		return pad.size() == 3 and pad[1] in [0, 1] and pad[2] is int and pad[2] in [-1, 1]
	if pad[0] == "direction":
		return pad.size() == 4 and pad[1] >= 0 and pad[1] < JOY_BUTTON_MAX and pad[1] != JOY_BUTTON_BACK and pad[2] is int and pad[2] in [0, 1] and pad[3] is int and pad[3] in [-1, 1]
	return false


func pad_tokens(spec: Array) -> Array:
	if spec[0] == "button": return ["b%d" % spec[1]]
	if spec[0] == "axis": return ["a%d:%d" % [spec[1], spec[2]]]
	return ["b%d" % spec[1], "a%d:%d" % [spec[2], spec[3]]]


## Gameplay and menus are separate contexts; sharing between them is intentional.
func conflict(action: String, device: String, candidate: Variant) -> String:
	for other in ACTIONS:
		if other == action or other.begins_with("menu_") != action.begins_with("menu_"): continue
		if device == "key" and bindings[other].key == candidate: return other
		if device == "pad":
			for token in pad_tokens(candidate):
				if token in pad_tokens(bindings[other].pad): return other
	return ""


func apply() -> void:
	for action in ACTIONS:
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, 0.6)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action].key
		InputMap.action_add_event(action, key)
		var spec: Array = bindings[action].pad
		if spec[0] in ["button", "direction"]:
			var button := InputEventJoypadButton.new()
			button.device = -1
			button.button_index = spec[1]
			InputMap.action_add_event(action, button)
		if spec[0] in ["axis", "direction"]:
			var axis := InputEventJoypadMotion.new()
			axis.device = -1
			axis.axis = spec[1] if spec[0] == "axis" else spec[2]
			axis.axis_value = spec[2] if spec[0] == "axis" else spec[3]
			InputMap.action_add_event(action, axis)


## Axis hysteresis suppresses repeat/jitter events until the stick returns near neutral.
func fresh(event: InputEvent) -> bool:
	var token := ""
	var pressed := event.is_pressed()
	if event is InputEventKey:
		token = "k%d" % (event.physical_keycode if event.physical_keycode else event.keycode)
	elif event is InputEventJoypadButton:
		token = "j%d:b%d" % [event.device, event.button_index]
	elif event is InputEventJoypadMotion:
		token = "j%d:a%d" % [event.device, event.axis]
		if absf(event.axis_value) < 0.3:
			held.erase(token)
			return false
		if absf(event.axis_value) < 0.6: return false
		var direction := signf(event.axis_value)
		if held.get(token, 0) == direction: return false
		held[token] = direction
		return true
	else:
		return not event.is_echo()
	if not pressed:
		held.erase(token)
		return false
	if held.has(token) or event.is_echo(): return false
	held[token] = true
	return true


func forget_device(device: int) -> void:
	for token in held.keys():
		if token.begins_with("j%d:" % device): held.erase(token)


func binding_text(action: String, device: String) -> String:
	if device == "key": return OS.get_keycode_string(bindings[action].key)
	var spec: Array = bindings[action].pad
	if spec[0] == "axis": return "Stick %s" % (["Left", "Right"] if spec[1] == 0 else ["Up", "Down"])[0 if spec[2] < 0 else 1]
	var names := {0: "Face Down", 1: "Face Right", 2: "Face Left", 3: "Face Up", 6: "Start", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"}
	return names.get(spec[1], "Button %d" % spec[1]) + (" / Stick" if spec[0] == "direction" else "")
