## Run only in an isolated project copy named Moonfall Dojo Input Verification.
## Uses real viewport dispatch; physical hardware feel still requires manual testing.
extends SceneTree

const MAIN = preload("res://scenes/main.tscn")
const RECORDS = preload("res://scripts/run_records.gd")
var checks := 0
var failures: Array[String] = []
var renders := false


func _initialize() -> void:
	if ProjectSettings.get_setting("application/config/name") != "Moonfall Dojo Input Verification":
		push_error("Use an isolated verification project/save identity.")
		quit(2)
		return
	renders = "--renders" in OS.get_cmdline_user_args()
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func key(code: int, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	dispatch(event)


func tap(code: int) -> void:
	key(code)
	key(code, false)


func button(code: int, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.device = 0
	event.pressed = pressed
	dispatch(event)


func pad(code: int) -> void:
	button(code)
	button(code, false)


func axis(value: float, axis_index := 0) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis_index
	event.axis_value = value
	dispatch(event)


func touch(index: int, point: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	dispatch(event)


func shot(name: String) -> void:
	if not renders: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://input_renders/" + name + ".png")


func run() -> void:
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute("res://input_renders")
	# A separate invocation proves a saved binding survives process shutdown.
	if "--reload" in OS.get_cmdline_user_args():
		var loaded = RECORDS.new()
		loaded.load_records()
		check(loaded.controls.bindings.punch.key == KEY_C, "separate process restores binding")
		finish()
		return
	var records = RECORDS.new()
	records.controls.load_bindings(null)
	for action in records.controls.ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventJoypadButton: event.pressed = true
			check(event.is_action_pressed(action), "default action parity " + action)
	var baseline: Dictionary = records.controls.defaults()
	for invalid in [null, 42, {}, {"punch": "bad"}]:
		records.controls.load_bindings(invalid)
		check(records.controls.bindings == baseline, "invalid bindings fallback")
	var bad: Dictionary = baseline.duplicate(true)
	bad.punch.key = KEY_X
	records.controls.load_bindings(bad)
	check(records.controls.bindings == baseline, "saved conflicting binding fallback")
	bad = baseline.duplicate(true)
	bad.punch.pad = ["axis", 0, 0]
	records.controls.load_bindings(bad)
	check(records.controls.bindings == baseline, "invalid axis fallback")
	# All persistence fixtures use the guarded test identity, never the player's save.
	DirAccess.remove_absolute(RECORDS.SAVE_PATH)
	var missing = RECORDS.new()
	missing.load_records()
	check(missing.controls.bindings == baseline, "missing file defaults")
	var corrupt := FileAccess.open(RECORDS.SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("[broken\nnot config data")
	corrupt.close()
	missing.load_records()
	check(missing.controls.bindings == baseline, "malformed file defaults")
	records.save_records()
	for action in records.controls.ACTIONS:
		records.controls.load_bindings(null)
		records.controls.bindings[action] = {"key": KEY_F5, "pad": ["button", JOY_BUTTON_LEFT_SHOULDER]}
		records.controls.apply()
		var remapped_key := InputEventKey.new()
		remapped_key.physical_keycode = KEY_F5
		remapped_key.pressed = true
		check(remapped_key.is_action_pressed(action), "all actions keyboard remap " + action)
		var remapped_button := InputEventJoypadButton.new()
		remapped_button.button_index = JOY_BUTTON_LEFT_SHOULDER
		remapped_button.pressed = true
		check(remapped_button.is_action_pressed(action), "all actions controller remap " + action)
		if action == "menu_accept":
			check(remapped_button.is_action_pressed("restart_run"), "restart follows remapped accept")
		records.save_controls()
		missing.load_records()
		check(missing.controls.bindings == records.controls.bindings, "all remaps reload " + action)
	records.controls.load_bindings(null)
	records.save_controls()
	var previous_save := FileAccess.get_file_as_string(RECORDS.SAVE_PATH)
	check(DirAccess.make_dir_absolute(RECORDS.SAVE_PATH + ".tmp") == OK, "create write-failure fixture")
	records.controls.bindings.punch.key = KEY_C
	records.save_controls()
	check(records.last_save_error != OK and FileAccess.get_file_as_string(RECORDS.SAVE_PATH) == previous_save, "failed control save preserves previous file")
	DirAccess.remove_absolute(RECORDS.SAVE_PATH + ".tmp")
	records.controls.load_bindings(null)
	records.save_controls()
	check(records.last_save_error == OK, "save recovers after write failure")
	var m = MAIN.instantiate()
	m.records = records
	root.add_child(m)
	current_scene = m
	m.set_physics_process(false)
	check(not m.touch_overlay.visible, "touch hidden initially")
	pad(JOY_BUTTON_DPAD_DOWN)
	check(m.menu_selection == 1 and m.player.current_action == 0, "controller title no gameplay leakage")
	axis(0.9, 1)
	axis(0.8, 1)
	check(m.menu_selection == 2, "stick navigation once per tilt")
	axis(0.0, 1)
	pad(JOY_BUTTON_DPAD_DOWN)
	await shot("title_controller")
	pad(JOY_BUTTON_A)
	check(m.game_state == m.GameState.CONTROLS, "pad opens controls")
	var menu = m.controls_overlay
	menu.selection = 4
	pad(JOY_BUTTON_A)
	check(menu.listening, "waiting for keyboard capture")
	tap(KEY_X)
	check(menu.listening and records.controls.bindings.punch.key == KEY_Z, "conflict prevented")
	await shot("remap_conflict")
	tap(KEY_C)
	check(not menu.listening and records.controls.bindings.punch.key == KEY_C, "key remapped")
	var loaded = RECORDS.new()
	loaded.load_records()
	check(loaded.controls.bindings.punch.key == KEY_C, "binding persisted")
	pad(JOY_BUTTON_DPAD_RIGHT)
	pad(JOY_BUTTON_A)
	pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(records.controls.bindings.punch.pad == ["button", JOY_BUTTON_RIGHT_SHOULDER], "controller capture")
	pad(JOY_BUTTON_A)
	pad(JOY_BUTTON_BACK)
	check(not menu.listening, "View cancels capture")
	menu.selection = 0
	pad(JOY_BUTTON_A)
	axis(-0.9)
	axis(0)
	check(records.controls.bindings.turn_left.pad == ["axis", 0, -1], "stick rebind")
	menu.selection = 13
	pad(JOY_BUTTON_A)
	check(records.controls.bindings == baseline, "restore defaults")
	menu.selection = 14
	pad(JOY_BUTTON_A)
	check(m.touch_controls_enabled and not m.touch_overlay.visible, "overlay enabled only for run")
	await shot("controls_overlay_option")
	pad(JOY_BUTTON_B)
	check(m.game_state == m.GameState.TITLE, "controller cancel to title")
	m.menu_selection = 0
	button(JOY_BUTTON_A)
	await process_frame
	await process_frame
	m = current_scene
	m.set_physics_process(false)
	check(m.player.current_action == 0, "accept does not punch new run")
	button(JOY_BUTTON_A)
	check(m.player.current_action == 0, "held button across replacement discarded")
	button(JOY_BUTTON_A, false)
	# All three input paths reach the exact Player actions with unchanged committed durations.
	for source in 3:
		for index in 4:
			if source == 0: tap([KEY_Z, KEY_X, KEY_UP, KEY_DOWN][index])
			elif source == 1: pad([JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_X][index])
			else:
				var rect: Rect2 = m.touch_overlay.RECTS[[4, 5, 2, 3][index]]
				touch(0, rect.get_center())
				touch(0, rect.get_center(), false)
			check(m.player.current_action == [1, 2, 4, 3][index], "gameplay parity %d/%d" % [source, index])
			m.player.advance_tick(1.0)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = m.touch_overlay.RECTS[4].get_center()
	mouse.pressed = true
	dispatch(mouse)
	check(m.player.current_action == 1, "desktop mouse activates overlay")
	mouse = mouse.duplicate()
	mouse.pressed = false
	dispatch(mouse)
	m.player.advance_tick(1.0)
	mouse = mouse.duplicate()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.pressed = true
	dispatch(mouse)
	check(m.player.current_action == 0, "emulated mouse cannot duplicate touch")
	touch(0, m.touch_overlay.RECTS[0].get_center())
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(320, 200)
	dispatch(drag)
	check(m.touch_overlay.fingers.is_empty(), "sliding out releases pad without a new action")
	axis(-0.9)
	check(m.player.target_direction == -1, "stick turns left")
	axis(0.8)
	check(m.player.target_direction == 1, "stick reverses")
	axis(0)
	touch(0, m.touch_overlay.RECTS[0].get_center())
	touch(1, m.touch_overlay.RECTS[2].get_center())
	check(m.player.target_direction == -1 and m.player.current_action == 0, "one pad direction at a time")
	touch(2, m.touch_overlay.RECTS[4].get_center())
	check(m.player.current_action == 1, "simultaneous pad and attack")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(m.touch_overlay.fingers.is_empty(), "focus loss releases touch")
	touch(0, m.touch_overlay.RECTS[0].get_center())
	pad(JOY_BUTTON_START)
	check(paused and m.touch_overlay.fingers.is_empty() and m.touch_overlay.mode == 2, "pause releases touches")
	var elapsed: float = m.player.action_elapsed
	pad(JOY_BUTTON_Y)
	m._physics_process(1.0)
	check(m.player.action_elapsed == elapsed, "pause freezes action")
	await shot("paused_overlay")
	touch(3, m.touch_overlay.RECTS[6].get_center())
	touch(3, m.touch_overlay.RECTS[6].get_center(), false)
	check(not paused, "touch Pause resumes")
	m.player.advance_tick(1.0)
	axis(-0.9)
	pad(JOY_BUTTON_A)
	axis(-0.8)
	m.player.advance_tick(1.0)
	axis(-0.7)
	check(m.player.current_action == 0, "stick has no buffered action")
	axis(0)
	await shot("gameplay_overlay")
	m.touch_controls_enabled = false
	m.update_touch_controls()
	touch(0, m.touch_overlay.RECTS[4].get_center())
	check(m.player.current_action == 0 and m.touch_overlay.fingers.is_empty(), "hidden touch inert")
	m.touch_controls_enabled = true
	m.update_touch_controls()
	m.records.controls.bindings.punch.key = KEY_C
	m.records.controls.apply()
	m.records.save_controls()
	# Non-qualifying restart, then controller-only initials entry and return to Title.
	for index in 10: m.records.entries.append({"initials": "AAA", "score": 1000})
	m.player.receive_hit()
	m.player.advance_tick(0.4)
	m.show_run_result()
	await shot("game_over")
	pad(JOY_BUTTON_A)
	await process_frame
	await process_frame
	m = current_scene
	m.set_physics_process(false)
	check(not m.player.is_dead and m.score == 0, "controller Game Over restart")
	check(m.records.controls.bindings.punch.key == KEY_C, "non-default binding survives restart")
	tap(KEY_Z)
	check(m.player.current_action == 0, "old binding inactive after restart")
	tap(KEY_C)
	check(m.player.current_action == 1, "new binding active after restart")
	m.player.advance_tick(1.0)
	m.records.entries.clear()
	m.player.receive_hit()
	m.player.advance_tick(0.4)
	m.show_run_result()
	check(m.game_state == m.GameState.INITIALS_ENTRY and not m.touch_overlay.visible, "entry hides touch")
	pad(JOY_BUTTON_DPAD_UP)
	pad(JOY_BUTTON_A)
	pad(JOY_BUTTON_B)
	check(m.initials.is_empty(), "controller initials cancel erases")
	pad(JOY_BUTTON_DPAD_UP)
	pad(JOY_BUTTON_DPAD_DOWN)
	for index in 3: pad(JOY_BUTTON_A)
	await shot("initials_controller")
	pad(JOY_BUTTON_A)
	check(m.records.entries[0].initials == "BBB" and m.game_state == m.GameState.HIGH_SCORES, "controller initials saves once")
	pad(JOY_BUTTON_B)
	check(m.game_state == m.GameState.TITLE, "score table controller back")
	# Keep a non-default binding for the next process, with scores/audio/unlocks intact.
	m.records.controls.bindings.punch.key = KEY_C
	m.records.save_controls()
	loaded.load_records()
	check(loaded.entries == m.records.entries and loaded.music_volume == m.records.music_volume, "control save preserves records/audio")
	# Presses outside capture remain event based, including after a controller disconnect.
	m.records.controls.held["j0:a0"] = -1
	m.controller_connection_changed(0, false)
	check(not m.records.controls.held.has("j0:a0"), "disconnect forgets held axis")
	m.free()
	await process_frame
	# AudioServer frees finished playback voices on its own thread, after tree removal.
	await create_timer(0.3, true).timeout
	finish()


func finish() -> void:
	print("INPUT checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
