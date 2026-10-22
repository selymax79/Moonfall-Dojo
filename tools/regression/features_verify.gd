extends "res://pause_verify.gd"
const Records = preload("res://scripts/run_records.gd")
func _initialize():
	feature_run.call_deferred()
func freeze_created(node: Node):
	if node.has_method("start_new_run") and node.start_in_run:
		node.ready.connect(func(): node.set_physics_process(false), CONNECT_ONE_SHOT)
func menu_fixture(unlocked: int = 10):
	var m = MAIN.instantiate()
	m.records = Records.new()
	m.records.highest_level = unlocked
	m.encounter_rng.seed = 120025
	root.add_child(m)
	current_scene = m
	return m
func type_character(character: String, echo: bool = false):
	var event := InputEventKey.new()
	event.physical_keycode = character.to_upper().unicode_at(0)
	event.keycode = event.physical_keycode
	event.unicode = character.unicode_at(0)
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func restarted(m, code: int):
	var identity: int = m.get_instance_id()
	tap(code)
	for frame in range(12):
		await process_frame
		if current_scene.get_instance_id() != identity: break
	check(current_scene.get_instance_id() != identity, "fresh scene")
	return current_scene
func feature_run():
	root.child_entered_tree.connect(freeze_created)
	var m = menu_fixture()
	check(m.game_state == m.GameState.TITLE and m.selected_start_level == 1 and m.high_score == 0, "startup defaults")
	check(m.active_threats.is_empty() and m.pending_type == -1 and not m.player.visible, "title no gameplay")
	var initial_rng: int = m.encounter_rng.state
	for index in range(5):
		check(m.menu_selection == index, "five title rows")
		if index >= 2:
			tap(KEY_ENTER)
			var expected: int = [m.GameState.HIGH_SCORES,m.GameState.CONTROLS,m.GameState.OPTIONS][index-2]
			check(m.game_state == expected, "menu destination")
			var before := snapshot(m)
			for code in [KEY_LEFT,KEY_RIGHT,KEY_Z,KEY_X,KEY_P]: tap(code)
			await create_timer(0.15,true).timeout
			check(snapshot(m) == before and not paused, "menus frozen no gameplay leakage")
			tap(KEY_ESCAPE)
			check(m.game_state == m.GameState.TITLE and m.menu_selection == index, "Esc title retains row")
			tap(KEY_ENTER)
			if index == 3:
				tap(KEY_ESCAPE) # Controls now opens capture on Accept.
			else:
				tap(KEY_ENTER)
			check(m.game_state == m.GameState.TITLE, "menu back")
		tap(KEY_DOWN)
	check(m.encounter_rng.state == initial_rng and m.encounter_time == 0, "menu RNG clocks idle")
	tap(KEY_DOWN)
	tap(KEY_LEFT)
	check(m.selected_start_level == 1, "selector lower clamp")
	for index in range(20): tap(KEY_RIGHT)
	check(m.selected_start_level == 10, "selector upper clamp")
	for index in range(3): tap(KEY_LEFT)
	m = await restarted(m,KEY_ENTER)
	check(m.game_state == m.GameState.RUN and m.run_start_level == 7 and m.level == 7 and m.get_multiplier_half_units() == 2, "Start Level row starts Level7 x1")
	check(m.score == 0 and m.kills == 0 and m.dodges == 0, "higher start counters")
	check(m.get_spawn_gap() == 0.45 and m.get_max_unresolved() == 2, "Level7 scheduler")
	var first_kind: int = m.active_threats[0].type
	check(is_equal_approx(m.active_threats[0].actor.movement_speed, 90.0*[1.0,1.0,1.15,1.25][first_kind]*m.ThreatTiming.spawn_distance(first_kind)/240.0), "Level7 initial speed")
	m.records.entries.clear()
	for index in range(10): m.records.entries.append({"initials":"OLD","score":1000000})
	# The removed development shortcuts must stay inert, playing or paused.
	check(not InputMap.has_action("dev_restart") and not InputMap.has_action("dev_level_up"), "no development actions")
	var identity: int = m.get_instance_id()
	for pause_toggle in [false,true]:
		if pause_toggle: tap(KEY_P)
		tap(KEY_F2)
		tap(KEY_F4)
		await process_frame
		check(current_scene.get_instance_id() == identity and m.level == 7 and paused == pause_toggle and not m.run_change_pending, "F2/F4 inert")
	tap(KEY_P)
	for action in [1,2,3,4]:
		m.player.start_action(action)
		tap(KEY_ENTER)
		check(current_scene.get_instance_id() == identity and not m.run_change_pending, "Enter no restart during actions")
		m.player.advance_tick(1.0)
	m.player.receive_hit()
	m._physics_process(0.39)
	tap(KEY_ENTER)
	m._physics_process(0.011)
	tap(KEY_ENTER,true)
	await process_frame
	check(current_scene == m and m.game_over_overlay.visible, "nonqualifying no buffered or echoed restart")
	tap(KEY_P)
	tap(KEY_ENTER)
	await process_frame
	check(current_scene == m and not paused and m.game_over_overlay.visible and m.pending_type == -1, "dead paused Enter resumes Game Over without restarting")
	m = await restarted(m,KEY_ENTER)
	check(m.run_start_level == 7 and m.level == 7 and m.get_multiplier_half_units() == 2 and not paused, "Game Over Enter same higher start")
	m.free()
	await process_frame
	# Qualification follows real deaths from every type/side, not a synthetic Game Over toggle.
	for kind in range(4):
		for side in [-1,1]:
			m = live()
			current_scene = m
			m.set_physics_process(false)
			m.records.entries.clear()
			m.award_successful_threat(kind)
			force_first(m,kind,side)
			for frame in range(400):
				m._physics_process(DT)
				if m.player.is_dead: break
			check(m.player.is_dead and m.pending_type == -1 and m.next_spawn_at == -1, "all lethal threats cancel pending")
			m._physics_process(0.399)
			check(m.game_state == m.GameState.RUN and not m.initials_overlay.visible, "entry waits death animation")
			tap(KEY_ENTER)
			m._physics_process(0.002)
			check(m.game_state == m.GameState.INITIALS_ENTRY and m.initials_overlay.visible and m.run_stats.visible, "qualifying Game Over")
			var before := snapshot(m)
			for code in [KEY_ENTER,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ESCAPE]: tap(code)
			await create_timer(0.06,true).timeout
			m._physics_process(10.0)
			check(snapshot(m) == before and not paused and m.score == 100, "entry input timers rewards isolation")
			type_character("!")
			type_character("a",true)
			check(m.initials == "", "invalid/echo initial rejected")
			type_character("p")
			check(m.initials == "P" and not paused, "P types instead of pausing")
			tap(KEY_BACKSPACE)
			type_character("z")
			type_character("x")
			tap(KEY_ENTER)
			check(m.game_state == m.GameState.INITIALS_ENTRY, "two initials cannot confirm")
			type_character("7")
			type_character("9")
			check(m.initials == "ZX7", "uppercase capped at3 and Z/X no actions")
			tap(KEY_ENTER)
			check(m.game_state == m.GameState.HIGH_SCORES and m.high_scores_overlay.visible and not m.initials_overlay.visible, "confirmation shows table")
			check(m.records.entries == [{"initials":"ZX7","score":100}] and m.high_score == 100, "exactly one confirmed record")
			tap(KEY_ENTER,true)
			check(m.game_state == m.GameState.HIGH_SCORES and m.records.entries.size() == 1, "held confirmation no duplicate or skipped table")
			var reopened = Records.new()
			reopened.load_records()
			check(reopened.entries == m.records.entries, "confirmed record saved")
			tap(KEY_ENTER)
			check(m.game_state == m.GameState.TITLE and m.title_high_score.text == "High Score 000100" and not m.player.visible, "leaderboard to Title")
			tap(KEY_ENTER)
			for frame in range(3): await process_frame
			m = current_scene
			check(m.score == 0 and m.player.current_action == 0 and m.high_score == 100, "no initials input into next run")
			m.free()
			await process_frame
	# Earned unlocks persist promptly, before any score is confirmed.
	m = live()
	m.set_physics_process(false)
	m.records.entries.clear()
	m.records.highest_level = 1
	m.records.save_records()
	for index in range(8):
		m.award_successful_threat(index%4)
		var expected: int = 1+int((index+1)/4)
		check(m.records.highest_level == expected and m.level == expected, "real progression unlocks Level")
		var reopened = Records.new()
		reopened.load_records()
		check(reopened.highest_level == expected, "unlock promptly persisted")
	check(m.level == 3 and m.records.highest_level == 3 and m.high_score == 0, "Level 3 unlock record awaits confirmation")
	m.free()
	await process_frame
	m = live(10)
	m.set_physics_process(false)
	m.records.highest_level = 10
	check(m.level == 10 and m.get_multiplier_half_units() == 2, "Level10 starts x1")
	for index in range(24):
		m.award_successful_threat(index%4)
		if index == 11: check(m.score == 1200 and m.level == 13 and m.get_multiplier_half_units() == 3, "#12 x1 then Level13 x1.5")
	check(m.score == 3000 and m.level == 16 and m.get_multiplier_half_units() == 4 and m.records.highest_level == 16, "#24 x1.5 then Level16 x2")
	m.records.entries.clear()
	m.records.submit_score("NEW",m.score)
	m.free()
	await process_frame
	# Actual load path, default selection stays1 despite a higher saved unlock.
	m = MAIN.instantiate()
	root.add_child(m)
	current_scene = m
	check(m.records.highest_level == 16 and m.selected_start_level == 1 and m.high_score == 3000, "new application instance loads records defaults selection1")
	m.free()
	await process_frame
	print("FEATURES checks=",checks," failures=",failures)
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)
