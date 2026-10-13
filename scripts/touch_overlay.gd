## Discrete four-way pad plus attacks. Emits ordinary action events, never calls Player.
extends Control

const FONT = preload("res://art/ui/dojo_font.tres")
const ACTIONS = ["turn_left", "turn_right", "jump", "duck", "punch", "kick", "pause_game"]
const LABELS = ["<", ">", "^", "v", "PUNCH", "KICK", "PAUSE"]
# Above the HUD and below the main approach corridor; centre combat stays uncovered.
const RECTS = [Rect2(12, 246, 34, 28), Rect2(80, 246, 34, 28), Rect2(46, 218, 34, 28), Rect2(46, 274, 34, 28), Rect2(504, 252, 56, 46), Rect2(570, 252, 56, 46), Rect2(566, 12, 62, 28)]
var fingers: Dictionary = {}
var mode := 0 # 0 hidden, 1 playing, 2 paused/dead (Pause only).


func set_mode(value: int) -> void:
	if mode == value: return
	release_all()
	mode = value
	visible = mode != 0
	queue_redraw()


func send_action(index: int, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = ACTIONS[index]
	event.pressed = pressed
	Input.parse_input_event(event)


func release_all() -> void:
	var previous := fingers.values()
	fingers.clear()
	for index in previous: send_action(index, false)
	queue_redraw()


func _exit_tree() -> void:
	release_all()


## One pointer owns the pad; attacks can use other fingers. Sliding never queues a new action.
func handle_pointer(event: InputEvent) -> bool:
	if mode == 0: return false
	var pointer: int
	var position: Vector2
	var pressed: bool
	if event is InputEventScreenTouch:
		pointer = event.index
		position = event.position
		pressed = event.pressed and not event.canceled
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pointer = -1
		position = event.position
		pressed = event.pressed
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		pointer = event.index if event is InputEventScreenDrag else -1
		if fingers.has(pointer) and not RECTS[fingers[pointer]].has_point(event.position):
			var old: int = fingers[pointer]
			fingers.erase(pointer)
			send_action(old, false)
			queue_redraw()
		return fingers.has(pointer)
	else: return false
	if not pressed:
		if not fingers.has(pointer): return false
		var old: int = fingers[pointer]
		fingers.erase(pointer)
		send_action(old, false)
		queue_redraw()
		return true
	if fingers.has(pointer): return true
	for index in RECTS.size():
		if mode == 2 and index != 6: continue
		if not RECTS[index].has_point(position): continue
		for held_index in fingers.values():
			if held_index == index or (index < 4 and held_index < 4): return true
		fingers[pointer] = index
		send_action(index, true)
		queue_redraw()
		return true
	return false


func _draw() -> void:
	if mode == 0: return
	if mode == 1:
		draw_rect(Rect2(46, 246, 34, 28), Color(0.025, 0.045, 0.07, 0.70))
	for index in RECTS.size():
		if mode == 2 and index != 6: continue
		var rect: Rect2 = RECTS[index]
		draw_rect(rect, Color(0.25, 0.30, 0.36, 0.85) if index in fingers.values() else Color(0.025, 0.045, 0.07, 0.70))
		draw_rect(rect, Color(0.8, 0.72, 0.52, 0.75), false, 1)
		if index < 4:
			var triangle := PackedVector2Array()
			for point in [Vector2(0, -6), Vector2(-5, 4), Vector2(5, 4)]:
				triangle.append(rect.get_center() + point.rotated([-PI / 2, PI / 2, 0, PI][index]))
			draw_colored_polygon(triangle, Color(0.95, 0.85, 0.65))
		else:
			draw_string(FONT, rect.position + Vector2(0, rect.size.y / 2 + 4), LABELS[index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color(0.95, 0.85, 0.65))
