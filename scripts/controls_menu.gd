## Compact seven-row scrolling view. Main owns navigation/state; this view edits bindings only.
extends Control

signal back_requested
signal overlay_changed(enabled: bool)
signal feedback(cue: String)
var records
var selection := 0
var device := "key"
var listening := false
var overlay_enabled := false
var message := ""
const FONT = preload("res://art/ui/dojo_font.tres")
const INK = Color(0.95, 0.85, 0.65)


func handle_input(event: InputEvent) -> void:
	var cancel_capture: bool = (event is InputEventKey and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK)
	if listening:
		if cancel_capture:
			listening = false
			message = "Binding unchanged"
			feedback.emit("menu_confirm")
		else:
			capture(event)
	elif event.is_action_pressed("menu_back") or cancel_capture:
		back_requested.emit()
	elif event.is_action_pressed("menu_up"):
		selection = posmod(selection - 1, 16)
		feedback.emit("menu_move")
	elif event.is_action_pressed("menu_down"):
		selection = (selection + 1) % 16
		feedback.emit("menu_move")
	elif event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right"):
		device = "pad" if device == "key" else "key"
		feedback.emit("menu_move")
	elif event.is_action_pressed("menu_accept"):
		if selection != 15: feedback.emit("menu_confirm")
		match selection:
			13:
				records.controls.load_bindings(null)
				records.save_controls()
				message = "Defaults restored" if records.last_save_error == OK else "Defaults active; save failed"
			14:
				overlay_enabled = not overlay_enabled
				overlay_changed.emit(overlay_enabled)
			15: back_requested.emit()
			_:
				listening = true
				message = ""
	queue_redraw()


func capture(event: InputEvent) -> void:
	var candidate: Variant = null
	if device == "key" and event is InputEventKey and event.pressed:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed: return
		candidate = int(event.physical_keycode if event.physical_keycode else event.keycode)
		if candidate in [KEY_F2, KEY_F4, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			message = "Reserved key; choose another"
			return
	elif device == "pad" and event is InputEventJoypadButton and event.pressed:
		candidate = ["button", int(event.button_index)]
	elif device == "pad" and event is InputEventJoypadMotion and event.axis in [0, 1] and absf(event.axis_value) >= 0.6:
		candidate = ["axis", int(event.axis), int(signf(event.axis_value))]
	if candidate == null: return
	var action: String = records.controls.ACTIONS[selection]
	var proposed: Dictionary = records.controls.bindings[action].duplicate(true)
	proposed[device] = candidate
	if not records.controls.valid_binding(proposed):
		message = "Unsupported input; choose another"
		return
	var other: String = records.controls.conflict(action, device, candidate)
	if not other.is_empty():
		message = "Already used: " + records.controls.LABELS[records.controls.ACTIONS.find(other)]
		return
	records.controls.bindings[action][device] = candidate
	records.controls.apply()
	records.save_controls()
	listening = false
	message = "Binding saved" if records.last_save_error == OK else "Binding active; save failed"
	feedback.emit("menu_confirm")


func line(text: String, y: float, size: int = 16, x: float = 24) -> void:
	# The HUD bitmap font contains uppercase only; menu body uses the existing menu fallback.
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, 616 - x, size, INK)


func _draw() -> void:
	if records == null: return
	draw_rect(Rect2(12, 16, 616, 332), Color(0.02, 0.035, 0.065, 0.97))
	draw_string(FONT, Vector2(24, 45), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, 592, 16, INK)
	line("ACTION", 71, 14)
	line("KEYBOARD", 71, 14, 250)
	line("GAMEPAD", 71, 14, 430)
	var first: int = clampi(selection - 3, 0, 9)
	for row in 7:
		var index := first + row
		var y := 98 + row * 25
		if index == selection: draw_rect(Rect2(18, y - 13, 604, 23), Color(0.18, 0.22, 0.28))
		if index < 13:
			var action: String = records.controls.ACTIONS[index]
			line(records.controls.LABELS[index], y)
			line(records.controls.binding_text(action, "key"), y, 16, 250)
			line(records.controls.binding_text(action, "pad"), y, 16, 430)
		else:
			line(["Restore ALL defaults", "Touch overlay: " + ("ON" if overlay_enabled else "OFF"), "Back to Title"][index - 13], y)
	line("%d / 16   EDIT: %s" % [selection + 1, "KEYBOARD" if device == "key" else "GAMEPAD"], 279, 14)
	if listening:
		line("WAITING: press a " + ("key" if device == "key" else "button / tilt stick"), 301, 14)
		line(message if not message.is_empty() else "Esc / gamepad View cancels", 324, 14)
	else:
		line("Menu Up/Down: row   Left/Right: device   Accept: edit", 301, 14)
		# Direct page/back buttons occupy the footer; keyboard/pad navigation remains unchanged.
		line(message, 279, 14, 300)
