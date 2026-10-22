## Isolated native regression for the shared pointer menus and browser lifecycle/audio adapters.
## Browser policy, storage and rendering also require a served Web test; this cannot prove them.
extends SceneTree

var checks := 0
var failures: Array[String] = []
var main


func _initialize() -> void:
	if ProjectSettings.get_setting("application/config/name") != "Moonfall Dojo Input Verification":
		quit(2)
		return
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)


func pointer(point: Vector2, pressed: bool, index := 0, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap(command: String, value := 0) -> void:
	for target in main.menu_pointer.targets:
		if target.command == command and target.value == value:
			check(target.rect.size.x > 0 and target.rect.size.y > 0, "laid out target " + command)
			pointer(target.rect.get_center(), true)
			pointer(target.rect.get_center(), false)
			return
	check(false, "missing target " + command)


func run() -> void:
	root.size = Vector2i(640, 360)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	main = load("res://scenes/main.tscn").instantiate()
	main.records = load("res://scripts/run_records.gd").new()
	main.records.highest_level = 7
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	check(not main.touch_controls_enabled, "native overlay defaults off")
	var rng_before: int = main.encounter_rng.state
	tap("level", 1)
	check(main.selected_start_level == 2, "direct level increase")
	tap("level", -1)
	check(main.selected_start_level == 1, "direct level decrease")
	tap("title", 4)
	check(main.game_state == main.GameState.OPTIONS, "tap options")
	var volume: int = main.records.music_volume
	tap("volume_down", 0)
	check(main.records.music_volume == volume - 5, "tap volume decrease")
	tap("volume_up", 0)
	tap("back")
	tap("title", 2)
	check(main.game_state == main.GameState.HIGH_SCORES, "tap scores")
	tap("back")
	tap("title", 3)
	tap("key_binding", 4)
	check(main.controls_overlay.listening and main.controls_overlay.selection == 4, "direct binding selection")
	tap("controls_back")
	check(not main.controls_overlay.listening and main.game_state == main.GameState.CONTROLS, "touch cancels capture")
	tap("page", 7)
	tap("key_binding", 14)
	check(main.touch_controls_enabled, "touch toggles existing overlay preference")
	tap("controls_back")
	check(main.game_state == main.GameState.TITLE and main.encounter_rng.state == rng_before, "menus preserve gameplay RNG")
	# Cancelled gestures and drags must never start a run.
	var row: Control = main.get_node("HUD/TitleOverlay/MenuContainer").get_child(0)
	pointer(row.get_global_rect().get_center(), true)
	pointer(row.get_global_rect().get_center(), false, 0, true)
	check(not main.run_change_pending, "canceled tap is inert")
	pointer(row.get_global_rect().get_center(), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(0, 0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	pointer(row.get_global_rect().get_center(), false)
	check(not main.run_change_pending, "drag out cancels menu tap")
	tap("title", 0)
	await process_frame
	await process_frame
	main = current_scene
	check(main.start_in_run and main.touch_overlay.mode == 1, "tap Start uses normal scene replacement")
	pointer(main.touch_overlay.RECTS[0].get_center(), true)
	main.suspend_browser()
	check(paused and main.touch_overlay.fingers.is_empty(), "browser suspension pauses and releases")
	var clock_before: float = main.encounter_time
	main._physics_process(0.5)
	check(main.encounter_time == clock_before, "suspended simulation frozen")
	tap("resume")
	check(not paused, "explicit direct resume")
	main.player.is_dead = true
	main.player.death_elapsed = main.player.DEATH_DURATION
	main.game_over_overlay.show()
	main.menu_pointer.refresh()
	tap("restart")
	await process_frame
	await process_frame
	main = current_scene
	check(not main.player.is_dead and main.score == 0, "direct Game Over restart")
	main.game_state = main.GameState.INITIALS_ENTRY
	main.score = 999999
	main.update_menu()
	tap("initial_key", 0)
	tap("initial_key", 1)
	tap("back")
	tap("initial_key", 0)
	tap("initial_key", 0)
	check(main.initials == "AAA", "touch initials grid add erase")
	tap("save")
	check(main.game_state == main.GameState.HIGH_SCORES and main.records.entries[0].initials == "AAA", "touch submits qualifying score")
	# Audio gate tests use the real fixed voice pool, without pretending to test browser permission.
	main.game_audio.stop_all()
	main.game_audio.activated = false
	main.game_audio.play_music("title")
	main.game_audio.play_ui("menu_move")
	check(not main.game_audio.music.playing and not main.game_audio.get_node("UI").playing, "pre-gesture silence")
	main.game_audio.activate()
	check(main.game_audio.music.playing, "one activation starts requested music")
	main.game_audio.set_browser_suspended(true)
	check(main.game_audio.music.stream_paused, "background menu audio paused")
	main.game_audio.set_browser_suspended(false)
	check(not main.game_audio.music.stream_paused, "foreground menu audio resumes")
	check(main.game_audio.get_child_count() == 9, "bounded audio voices")
	main.queue_free()
	await create_timer(0.25).timeout
	print("WEB_ADAPTER checks=", checks, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
