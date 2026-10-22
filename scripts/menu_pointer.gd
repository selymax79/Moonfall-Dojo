## Tap/click support for every menu: builds hit areas ("targets") for the current screen and
## turns a completed tap into the same command keyboard/controller input would give.
## Main remains the sole owner of menu state; this script owns only pointer gestures.
## Activation happens on release inside the original target; drags/cancels never activate it.
extends Control

var main
var targets: Array[Dictionary] = []
var held: Dictionary = {}
const INK := Color(0.95, 0.85, 0.65)
# On-screen initials keys: 12 columns x 3 rows (A-L, M-X, Y-Z + 0-9) between the letters and ERASE/SAVE.
const GRID_ORIGIN := Vector2(58, 128)
const GRID_PITCH := Vector2(44, 34)
const GRID_KEY_SIZE := Vector2(40, 30)


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
			# Keyboard-only players just type, so the grid appears only for touch or a moved cursor.
			if main.initials_grid_visible():
				for index in main.INITIAL_CHARACTERS.length():
					var column: int = index % main.INITIAL_GRID_COLUMNS
					@warning_ignore("integer_division")
					var row: int = index / main.INITIAL_GRID_COLUMNS
					add_target(Rect2(GRID_ORIGIN + Vector2(column, row) * GRID_PITCH, GRID_KEY_SIZE), "initial_key", index, main.INITIAL_CHARACTERS[index])
				add_target(Rect2(170, 236, 140, 32), "back", 0, "ERASE")
				add_target(Rect2(330, 236, 140, 32), "save", 0, "SAVE")
		main.GameState.CONTROLS:
			var menu = main.controls_overlay
			if not menu.listening:
				# Same rows the Controls view draws, so taps always land on what is shown.
				var first: int = menu.first_visible_row()
				for row in menu.VISIBLE_ROWS:
					var y: float = menu.ROW_TOP + row * menu.ROW_HEIGHT
					add_target(Rect2(18, y, 398, menu.ROW_HEIGHT), "key_binding", first + row)
					add_target(Rect2(416, y, 206, menu.ROW_HEIGHT), "pad_binding", first + row)
				add_target(Rect2(24, 304, 120, 36), "page", -menu.VISIBLE_ROWS, "PREVIOUS")
				add_target(Rect2(156, 304, 120, 36), "page", menu.VISIBLE_ROWS, "NEXT")
			add_target(Rect2(436, 304, 180, 36), "controls_back", 0, "CANCEL" if menu.listening else "BACK")
		main.GameState.RUN:
			if main.get_tree().paused:
				# Rows are the visible pause-menu labels; unlabeled targets draw no extra box.
				for index in 3:
					var row: Control = main.get_node("HUD/PauseOverlay/Options").get_child(index)
					add_target(row.get_global_rect(), ["resume", "pause_restart", "pause_quit"][index], index)
			elif main.game_over_overlay.visible:
				var rows: Control = main.get_node("HUD/GameOverOverlay/Options")
				add_target(rows.get_child(0).get_global_rect(), "restart")
				add_target(rows.get_child(1).get_global_rect(), "game_over_menu")
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
		"initial_key":
			main.initial_choice = target.value
			main.add_initial(main.INITIAL_CHARACTERS[target.value])
		"save": main.submit_initials()
		"key_binding", "pad_binding":
			main.controls_overlay.selection = target.value
			main.controls_overlay.device = "key" if target.command == "key_binding" else "pad"
			action("menu_accept")
		"page": main.controls_overlay.selection = clampi(main.controls_overlay.selection + target.value, 0, main.controls_overlay.ROW_COUNT - 1)
		"controls_back":
			# Escape is the existing remapping recovery/cancel path, independent of user bindings.
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.pressed = true
			main.controls_overlay.handle_input(event)
		"resume", "pause_restart", "pause_quit": main.choose_pause_option(target.value)
		"restart": main.choose_game_over_option(main.GameOverOption.TRY_AGAIN)
		"game_over_menu": main.choose_game_over_option(main.GameOverOption.MENU)
	main.update_menu()


func _draw() -> void:
	for target in targets:
		if target.label.is_empty(): continue
		var ink: Color = INK
		var fill := Color(0.035, 0.055, 0.09)
		# The controller cursor highlights its grid key; SAVE stays dim until three slots are filled.
		if target.command == "initial_key" and main.initial_cursor_active and target.value == main.initial_choice:
			fill = Color(0.30, 0.25, 0.14)
		elif target.command == "save" and main.initials.length() < 3:
			ink = Color(INK, 0.35)
		draw_rect(target.rect, fill)
		draw_rect(target.rect, ink, false)
		draw_string(ThemeDB.fallback_font, target.rect.position + Vector2(0, target.rect.size.y / 2 + 6), target.label, HORIZONTAL_ALIGNMENT_CENTER, target.rect.size.x, 18, ink)
