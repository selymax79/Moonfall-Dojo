extends "res://features_verify.gd"
## Pause menu: Resume (P / Esc / Enter / tap), Restart (R / tap), Quit to Title (Q / tap).
## Game Over menu: Try Again (Enter / R / tap) or Return to Menu (Esc / Q / tap).
## Initials entry: typed on keyboards, on-screen key grid for touch and controller cursors.
func _initialize(): pause_menu_run.call_deferred()

## Injected pointer positions are window coordinates. The headless window is tiny, so map the
## 640x360 viewport point through the root's stretch transform before dispatching.
func pointer(at: Vector2, down: bool, mouse: bool) -> void:
	var event: InputEvent
	if mouse:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	else:
		event = InputEventScreenTouch.new()
	event.position = root.get_final_transform() * at
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click_target(m, command: String, mouse: bool, value: int = -1) -> void:
	for target in m.menu_pointer.targets:
		if target.command == command and (value < 0 or target.value == value):
			check(target.rect.size.x >= 40 and target.rect.size.y >= 24, "pointer target laid out " + command)
			pointer(target.rect.get_center(), true, mouse)
			pointer(target.rect.get_center(), false, mouse)
			return
	check(false, "missing pointer target %s %d" % [command, value])

func dead_fixture(qualifying: bool, scored: bool = true):
	var m = run_fixture()
	if qualifying: m.records.entries.clear()
	if scored: m.award_successful_threat(0)
	m.player.receive_hit()
	m._physics_process(0.4)
	return m

func row_text(m, index: int) -> String:
	return m.get_node("HUD/PauseOverlay/Options").get_child(index).text

func scene_changed(m) -> Node:
	var identity: int = m.get_instance_id()
	for frame in range(12):
		await process_frame
		if current_scene.get_instance_id() != identity: break
	check(current_scene.get_instance_id() != identity, "fresh scene")
	return current_scene

func run_fixture(start_level: int = 1):
	var m = live(start_level)
	m.selected_start_level = start_level # As the shared start path sets it for a real run.
	current_scene = m
	m.set_physics_process(false)
	return m

func pause_menu_run():
	root.child_entered_tree.connect(freeze_created)
	# Each resume route closes the menu without touching the run.
	for code in [KEY_P,KEY_ESCAPE,KEY_ENTER]:
		var m = run_fixture()
		var identity: int = m.get_instance_id()
		tap(KEY_P)
		check(paused and m.pause_overlay.visible and m.pause_selection == 0 and row_text(m,0) == "> RESUME <", "pause opens on Resume")
		tap(code)
		await process_frame
		check(not paused and not m.pause_overlay.visible and current_scene.get_instance_id() == identity, "resume key %d" % code)
		m.free()
		await process_frame
	# Up/Down wrap through the rows; reopening always starts on Resume.
	var m = run_fixture()
	tap(KEY_P)
	tap(KEY_DOWN)
	check(m.pause_selection == 1 and row_text(m,1) == "> RESTART - R <" and row_text(m,0) == "RESUME", "Down selects Restart")
	tap(KEY_UP)
	tap(KEY_UP)
	check(m.pause_selection == 2 and row_text(m,2) == "> QUIT TO MENU - Q <", "Up wraps to Quit")
	tap(KEY_P)
	tap(KEY_P)
	check(paused and m.pause_selection == 0, "reopened menu starts on Resume")
	tap(KEY_Z)
	tap(KEY_X)
	check(m.player.current_action == 0 and paused, "gameplay keys inert in pause menu")
	tap(KEY_P)
	m.free()
	await process_frame
	# R restarts at the same start Level; selecting Restart with Enter is equivalent.
	for use_shortcut in [true,false]:
		m = run_fixture(5)
		m.records.entries.clear()
		m.award_successful_threat(0)
		tap(KEY_P)
		if use_shortcut:
			tap(KEY_R)
		else:
			tap(KEY_DOWN)
			tap(KEY_ENTER)
		m = await scene_changed(m)
		check(m.game_state == m.GameState.RUN and not paused and m.run_start_level == 5 and m.level == 5 and m.score == 0, "pause Restart gives fresh run at same start")
		check(m.records.entries.is_empty(), "abandoned run never enters high scores")
		m.free()
		await process_frame
	# Q quits to a fresh Title scene that keeps records and the chosen Start Level.
	for use_shortcut in [true,false]:
		m = run_fixture(4)
		var records = m.records
		m.records.entries.clear()
		for index in range(4): m.award_successful_threat(index)
		tap(KEY_P)
		if use_shortcut:
			tap(KEY_Q)
		else:
			tap(KEY_UP)
			tap(KEY_ENTER)
		m = await scene_changed(m)
		check(m.game_state == m.GameState.TITLE and not paused and m.title_overlay.visible and not m.player.visible, "pause Quit shows Title")
		check(m.records == records and m.selected_start_level == 4 and m.active_threats.is_empty() and m.pending_type == -1, "Title keeps records and start Level, no gameplay")
		check(records.entries.is_empty() and records.highest_level == 1000000, "quit submits no score, unlocks kept")
		m.free()
		await process_frame
	# Pointer rows (desktop click and touch tap) activate their own option on release.
	for mouse in [true,false]:
		for command in ["resume","pause_restart","pause_quit"]:
			m = run_fixture()
			tap(KEY_P)
			click_target(m, command, mouse)
			var label: String = ("click " if mouse else "tap ") + command
			if command == "resume":
				check(not paused and current_scene == m, label)
			else:
				m = await scene_changed(m)
				check(not paused and m.game_state == (m.GameState.RUN if command == "pause_restart" else m.GameState.TITLE), label)
			m.free()
			await process_frame
	# Dragging off a row before release cancels it.
	m = run_fixture()
	tap(KEY_P)
	var row: Rect2 = m.menu_pointer.targets[1].rect
	pointer(row.get_center(), true, false)
	var drag := InputEventScreenDrag.new()
	drag.position = root.get_final_transform() * Vector2(320, 300)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	pointer(Vector2(320, 300), false, false)
	await process_frame
	check(paused and current_scene == m and not m.run_change_pending, "drag-off cancels Restart")
	tap(KEY_P)
	m.free()
	await process_frame
	# Paused during death: Restart and Quit still work; Resume returns to Game Over.
	for code in [KEY_R,KEY_Q]:
		m = run_fixture()
		m.player.receive_hit()
		m._physics_process(0.4)
		check(m.game_over_overlay.visible, "dead fixture Game Over")
		tap(KEY_P)
		check(paused and not m.game_over_overlay.visible, "pause hides Game Over")
		tap(code)
		m = await scene_changed(m)
		check(not paused and m.game_state == (m.GameState.RUN if code == KEY_R else m.GameState.TITLE) and not m.player.is_dead, "dead pause option %d" % code)
		m.free()
		await process_frame
	# Unpaused, R and Q are not gameplay shortcuts.
	m = run_fixture()
	var identity: int = m.get_instance_id()
	tap(KEY_R)
	tap(KEY_Q)
	await process_frame
	check(current_scene.get_instance_id() == identity and not paused and not m.run_change_pending, "R/Q inert outside pause menu")
	m.free()
	await process_frame
	await game_over_menu_checks()
	await initials_checks()
	print("RUN_MENUS checks=",checks," failures=",failures)
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)

func game_over_menu_checks() -> void:
	# A score outside the Top 10 skips initials and offers Try Again (preselected) or Return to Menu.
	var m = dead_fixture(false)
	check(m.game_state == m.GameState.RUN and m.game_over_overlay.visible and not m.initials_overlay.visible, "non-qualifying score bypasses initials")
	var rows: Control = m.get_node("HUD/GameOverOverlay/Options")
	check(m.game_over_selection == 0 and rows.get_child(0).text == "> TRY AGAIN - R <" and rows.get_child(1).text == "RETURN TO MENU - Q", "Game Over opens on Try Again")
	tap(KEY_DOWN)
	check(m.game_over_selection == 1 and rows.get_child(1).text == "> RETURN TO MENU - Q <", "Down selects Return to Menu")
	tap(KEY_DOWN)
	check(m.game_over_selection == 0, "Game Over rows wrap")
	tap(KEY_P)
	check(paused and not m.game_over_overlay.visible and m.pause_overlay.visible, "Pause still available at Game Over")
	tap(KEY_P)
	check(not paused and m.game_over_overlay.visible, "resume returns to Game Over menu")
	tap(KEY_Z)
	check(current_scene == m and not m.run_change_pending, "gameplay key inert at Game Over")
	m.free()
	await process_frame
	# Every route: keys, Enter on each row, and taps.
	# A zero score is void: even an empty table goes straight to the Game Over menu.
	m = dead_fixture(true, false)
	check(m.score == 0 and m.records.entries.is_empty() and m.game_over_overlay.visible and m.game_state == m.GameState.RUN, "zero score never qualifies")
	m.free()
	await process_frame
	# Esc pauses during play and at Game Over, then resumes; the run is untouched.
	for at_game_over in [false,true]:
		m = dead_fixture(false) if at_game_over else run_fixture()
		tap(KEY_ESCAPE)
		check(paused and m.pause_overlay.visible and current_scene == m, "Esc pauses (Game Over %s)" % at_game_over)
		tap(KEY_ESCAPE)
		check(not paused and current_scene == m and m.game_over_overlay.visible == at_game_over, "Esc resumes (Game Over %s)" % at_game_over)
		m.free()
		await process_frame
	var routes: Array = [[KEY_R,"RUN"],[KEY_Q,"TITLE"],[JOY_BUTTON_B,"TITLE"],[KEY_ENTER,"RUN"],["down_enter","TITLE"],["tap_restart","RUN"],["tap_game_over_menu","TITLE"]]
	for route in routes:
		m = dead_fixture(false)
		var records = m.records
		var entries_before: Array = records.entries.duplicate(true)
		if route[0] is int and route[1] == "TITLE" and route[0] == JOY_BUTTON_B:
			var press := InputEventJoypadButton.new()
			press.button_index = JOY_BUTTON_B
			press.pressed = true
			Input.parse_input_event(press)
			press = press.duplicate()
			press.pressed = false
			Input.parse_input_event(press)
			Input.flush_buffered_events()
		elif route[0] is int:
			tap(route[0])
		elif route[0] == "down_enter":
			tap(KEY_DOWN)
			tap(KEY_ENTER)
		else:
			click_target(m, route[0].trim_prefix("tap_"), false)
		m = await scene_changed(m)
		var expected = m.GameState.RUN if route[1] == "RUN" else m.GameState.TITLE
		check(m.game_state == expected and not paused and not m.player.is_dead and m.score == 0, "Game Over route %s" % str(route[0]))
		check(m.records == records and records.entries == entries_before, "Game Over route keeps records unchanged")
		if route[1] == "TITLE":
			check(m.title_overlay.visible and m.selected_start_level == 1, "Return to Menu shows Title with start Level kept")
		m.free()
		await process_frame

func initials_checks() -> void:
	# Keyboard: no key grid, just type and press Enter.
	var m = dead_fixture(true)
	check(m.game_state == m.GameState.INITIALS_ENTRY and not m.initials_grid_visible() and m.menu_pointer.targets.is_empty(), "keyboard initials show no grid")
	check(m.get_node("HUD/InitialsOverlay/EntryHint").visible and m.get_node("HUD/InitialsOverlay/EntryHint").text.begins_with("Type"), "keyboard hint says type")
	type_character("m")
	type_character("d")
	tap(KEY_ENTER)
	check(m.game_state == m.GameState.INITIALS_ENTRY, "two letters cannot save")
	type_character("9")
	type_character("x")
	check(m.initials == "MD9", "fourth typed letter ignored")
	tap(KEY_ENTER)
	check(m.game_state == m.GameState.HIGH_SCORES and m.records.entries[0].initials == "MD9", "typed initials saved")
	m.free()
	await process_frame
	# Arrow keys reveal the grid cursor; typing hides it again.
	m = dead_fixture(true)
	tap(KEY_DOWN)
	check(m.initials_grid_visible() and m.initial_choice == m.INITIAL_GRID_COLUMNS and m.menu_pointer.targets.size() == 38, "arrow reveals grid on row two")
	tap(KEY_ENTER)
	check(m.initials == "M" and m.initials_grid_visible(), "Accept adds grid key and keeps cursor")
	type_character("q")
	check(m.initials == "MQ" and not m.initials_grid_visible(), "typing hides grid")
	m.free()
	await process_frame
	# Touch: tap the on-screen keys, ERASE and SAVE.
	m = dead_fixture(true)
	m.touch_controls_enabled = true
	m.update_menu()
	check(m.menu_pointer.targets.size() == 38 and m.get_node("HUD/InitialsOverlay/EntryHint").text.begins_with("Tap"), "touch shows 36 keys plus ERASE and SAVE")
	click_target(m, "save", false)
	check(m.game_state == m.GameState.INITIALS_ENTRY, "SAVE inert before three letters")
	for index in [25, 0]: click_target(m, "initial_key", false, index)
	click_target(m, "back", false)
	for index in [16, 35, 27]: click_target(m, "initial_key", false, index)
	check(m.initials == "ZQ9", "touch keys erase and fourth key ignored")
	click_target(m, "save", false)
	check(m.game_state == m.GameState.HIGH_SCORES and m.records.entries[0] == {"initials":"ZQ9","score":100}, "touch SAVE stores score once")
	m.free()
	await process_frame
