extends "res://features_verify.gd"
func _initialize(): controls.call_deferred()
func state(m) -> Array:
	return [m.pattern_id,m.pattern_step,m.pattern_start_side,m.pending_type,m.pending_side,m.encounter_rng.state]
func menu_trace(seconds: float) -> Array:
	var m = menu_fixture(30)
	m.touch_controls_enabled = seconds > 1.0 # Compare hidden vs enabled overlay with menu dwell.
	m.selected_start_level = 20
	var rng_state: int = m.encounter_rng.state
	await create_timer(seconds,true).timeout
	check(m.encounter_rng.state == rng_state and m.pattern_id == -1,"menu wait consumes no pattern RNG")
	m.start_new_run()
	await process_frame
	await process_frame
	m = current_scene
	m.process_mode = Node.PROCESS_MODE_DISABLED
	var seen: Dictionary = {}
	var result: Array = []
	for frame in range(60000):
		for r in m.active_threats:
			if not seen.has(r.actor.get_instance_id()):
				seen[r.actor.get_instance_id()] = true
				result.append([r.type,r.actor.entry_side,r.pattern,r.pattern_step,r.lethal_at])
		if result.size() >= 200: m.pending_type = -1
		tick(m)
		if frame%600 == 0: await process_frame
		if m.player.is_dead or m.kills+m.dodges == 200: break
	check(not m.player.is_dead and m.kills+m.dodges == 200,"menu trace survives")
	m.free()
	await process_frame
	return result
func controls():
	root.child_entered_tree.connect(freeze_created)
	for boundary in [3,5,6,9,14,19]:
		for step in [0,1]:
			var m = fresh(boundary,310031)
			if boundary >= 4:
				m.clear_pattern()
				m.pattern_id = 1
				m.pattern_step = step
				m.pattern_start_side = -1
				m.pending_type = -1
				m.select_pending_threat()
			var before: Array = state(m)
			var records_before: Array = m.active_threats.duplicate(true)
			m.set_game_paused(true)
			var time_before: float = m.encounter_time
			await create_timer(0.05,true).timeout
			m._physics_process(10.0)
			check(state(m) == before and m.encounter_time == time_before,"pattern freezes during pause")
			m.set_game_paused(false)
			# Four real successes cross the Level boundary exactly as gameplay rewards do.
			for kind in range(4): m.award_successful_threat(kind)
			check(m.level == boundary+1 and state(m) == before,"Level-up preserves exact pending pattern and RNG")
			check(m.active_threats == records_before,"Level-up keeps active reservations immutable")
			var chance: float = 0.10 if m.level<6 else(0.15 if m.level<10 else(0.20 if m.level<15 else(0.22 if m.level<20 else 0.25)))
			check(m.get_pattern_start_chance() == chance,"Level-up future frequency tier")
			m.player.receive_hit()
			m._physics_process(DT)
			check(m.pattern_id == -1 and m.pattern_step == 0 and m.pattern_start_side == 0 and m.pending_type == -1,"death clears every pattern field")
			m.free()
			await process_frame
	var m = live(1)
	current_scene = m
	m.set_physics_process(false)
	m.player.receive_hit()
	m._physics_process(0.4)
	check(m.game_over_overlay.visible,"non-qualifying Game Over fixture")
	# Stale fields on the dead run must not survive scene replacement.
	m.pattern_id = 7
	m.pattern_step = 1
	m.pattern_start_side = -1
	m = await restarted(m,KEY_ENTER)
	check(not paused and m.level == 1 and m.pattern_id == -1 and m.pattern_step == 0 and m.pattern_start_side == 0,"Game Over restart removes stale pattern and returns fresh run")
	m.free()
	await process_frame
	var short_trace: Array = await menu_trace(0.2)
	var long_trace: Array = await menu_trace(2.0)
	check(short_trace == long_trace,"menu duration identical full pattern timeline")
	print("PATTERN_CONTROLS checks=",checks," failures=",failures," menu_encounters=",short_trace.size())
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)
