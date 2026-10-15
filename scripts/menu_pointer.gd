## Direct pointer targets for the existing menus. Main remains the sole menu state owner.
## Activation happens on release inside the original target; drags/cancels never activate it.
extends Control

var main
var targets: Array[Dictionary] = []
var held: Dictionary = {}
const INK := Color(0.95, 0.85, 0.65)


func add_target(rect: Rect2, command: String, value: int = 0, label: String = "") -> void:
	targets.append({"rect": rect, "command": command, "value": value, "label": label})


func refresh() -> void:
	held.clear()
	targets.clear()
	if main == null: return
	match main.game_state:
		main.GameState.TITLE:
			# Arrows precede the overlapping Start Level row in hit-test order.
			add_target(Rect2(120, 158, 50, 32), "level", -1, "-")
			add_target(Rect2(470, 158, 50, 32), "level", 1, "+")
			for index in 5:
				var row: Control = main.get_node("HUD/TitleOverlay/MenuContainer").get_child(index)
				add_target(row.get_global_rect(), "title", index)
		main.GameState.OPTIONS:
			for index in 2:
				add_target(Rect2(104, 125 + index * 48, 48, 36), "volume_down", index, "-")
				add_target(Rect2(488, 125 + index * 48, 48, 36), "volume_up", index, "+")
			add_target(Rect2(224, 304, 192, 40), "back", 0, "BACK")
		main.GameState.HIGH_SCORES:
			add_target(Rect2(224, 312, 192, 36), "back", 0, "BACK TO TITLE")
		main.GameState.INITIALS_ENTRY:
			add_target(Rect2(108, 265, 64, 38), "previous", 0, "<")
			add_target(Rect2(180, 265, 64, 38), "next", 0, ">")
			add_target(Rect2(252, 265, 100, 38), "back", 0, "ERASE")
			var label: String = "SAVE" if main.initials.length() == 3 else "ADD " + main.INITIAL_CHARACTERS[main.initial_choice]
			add_target(Rect2(360, 265, 172, 38), "initial", 0, label)
		main.GameState.CONTROLS:
			var menu = main.controls_overlay
			if not menu.listening:
				var first: int = clampi(menu.selection - 3, 0, 9)
				for row in 7:
					add_target(Rect2(18, 85 + row * 25, 398, 25), "key_binding", first + row)
					add_target(Rect2(416, 85 + row * 25, 206, 25), "pad_binding", first + row)
				add_target(Rect2(24, 304, 120, 36), "page", -7, "PREVIOUS")
				add_target(Rect2(156, 304, 120, 36), "page", 7, "NEXT")
			add_target(Rect2(436, 304, 180, 36), "controls_back", 0, "CANCEL" if menu.listening else "BACK")
		main.GameState.RUN:
			if main.get_tree().paused:
				add_target(Rect2(182, 151, 276, 80), "resume")
			elif main.game_over_overlay.visible:
				add_target(Rect2(182, 151, 276, 80), "restart")
	queue_redraw()


func handle_pointer(event: InputEvent) -> bool:
	var pointer: int
	var point: Vector2
	var pressed: bool
	if event is InputEventScreenTouch:
		pointer = event.index
		point = event.position
		pressed = event.pressed
		if event.canceled:
			held.erase(pointer)
			return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pointer = -1
		point = event.position
		pressed = event.pressed
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		pointer = event.index if event is InputEventScreenDrag else -1
		if held.has(pointer) and not held[pointer].rect.has_point(event.position): held.erase(pointer)
		return false
	else: return false
	if not pressed:
		if not held.has(pointer): return false
		var target: Dictionary = held[pointer]
		held.erase(pointer)
		if target.rect.has_point(point): activate(target)
		return true
	if held.has(pointer): return true
	for target in targets:
		if target.rect.has_point(point):
			held[pointer] = target
			return true
	return false


func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	main.handle_menu_input(event)


func activate(target: Dictionary) -> void:
	match target.command:
		"title":
			main.menu_selection = target.value
			action("menu_accept")
		"level":
			main.menu_selection = 1
			action("menu_left" if target.value < 0 else "menu_right")
		"volume_down", "volume_up":
			main.options_selection = target.value
			action("menu_left" if target.command == "volume_down" else "menu_right")
		"back": action("menu_back")
		"previous": action("menu_left")
		"next": action("menu_right")
		"initial":
			main.initial_picker_active = true
			action("menu_accept")
		"key_binding", "pad_binding":
			main.controls_overlay.selection = target.value
			main.controls_overlay.device = "key" if target.command == "key_binding" else "pad"
			action("menu_accept")
		"page": main.controls_overlay.selection = clampi(main.controls_overlay.selection + target.value, 0, 15)
		"controls_back":
			# Escape is the existing remapping recovery/cancel path, independent of user bindings.
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.pressed = true
			main.controls_overlay.handle_input(event)
		"resume": main.set_game_paused(false)
		"restart": main.start_new_run()
	main.update_menu()


func _draw() -> void:
	for target in targets:
		if target.label.is_empty(): continue
		draw_rect(target.rect, Color(0.035, 0.055, 0.09))
		draw_rect(target.rect, INK, false)
		draw_string(ThemeDB.fallback_font, target.rect.position + Vector2(0, target.rect.size.y / 2 + 6), target.label, HORIZONTAL_ALIGNMENT_CENTER, target.rect.size.x, 18, INK)
