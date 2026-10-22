extends "res://scheduler_verify.gd"

func _initialize() -> void:
	pause_run.call_deferred()

func live(level_value: int = 1):
	var m = MAIN.instantiate()
	m.run_start_level = level_value
	m.encounter_rng.seed = 24680
	m.start_in_run = true
	m.records = preload("res://scripts/run_records.gd").new()
	m.records.highest_level = 1000000
	for slot in range(10): m.records.entries.append({"initials":"AAA","score":1000000000})
	root.add_child(m)
	return m

func key(code: int, echo: bool = false, down: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int, echo: bool = false) -> void:
	key(code,echo)
	key(code,false,false)

func node_state(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = node.get(property.name)
			if value is Object: continue
			result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	if node is Node2D: result["transform"] = node.transform
	if node is Polygon2D: result["polygon"] = node.polygon
	if node is CollisionShape2D:
		result["shape"] = node.shape.size if node.shape is RectangleShape2D else node.shape.radius
	for child in node.get_children():
		# Manual fast-forward can leave already-completed queue_free requests awaiting frame flush.
		if child.name != "HUD" and not child.is_queued_for_deletion(): result[str(child.name)] = node_state(child)
	return result

func snapshot(m) -> Dictionary:
	var result := node_state(m)
	result["rng_state"] = m.encounter_rng.state
	return result

func freeze_case(m, label: String, duration: float = 0.12) -> void:
	tap(KEY_P)
	check(paused and m.pause_overlay.visible,label+" P and overlay")
	var before := snapshot(m)
	await create_timer(duration,true).timeout
	check(before == snapshot(m),label+" exact frozen snapshot")
	# Even explicit calls into Main's always-processing tick cannot bypass the guard.
	m._physics_process(2.0)
	check(before == snapshot(m),label+" central simulation guard")
	tap(KEY_P,true)
	check(paused and m.pause_overlay.visible,label+" echo ignored")
	tap(KEY_P)
	check(not paused and not m.pause_overlay.visible,label+" resumed overlay")
	var clock_before: float = m.encounter_time
	await physics_frame
	await physics_frame
	check(m.encounter_time > clock_before and m.encounter_time-clock_before < 0.051,label+" resumed with physics delta only")
	print("FREEZE PASS ",label)
	m.free()
	await process_frame

func pause_run() -> void:
	print("USER DATA ",OS.get_user_data_dir())
	check(InputMap.has_action("pause_game"),"normal InputMap action")
	var m = live()
	for repeat in range(4):
		tap(KEY_P)
		check(paused and m.pause_overlay.visible,"repeated pause")
		tap(KEY_P)
		check(not paused and not m.pause_overlay.visible,"repeated resume")
	m.free()
	await process_frame
	for action in [1,2,3,4]:
		m = live()
		m.player.start_action(action)
		m.player.advance_tick(0.03)
		await freeze_case(m,"Player action %d" % action)
	m = live()
	m.player.target_direction = -1.0
	m.player.advance_tick(0.025)
	await freeze_case(m,"Player turn")
	m = live()
	m.player.receive_hit()
	m.player.advance_tick(0.1)
	await freeze_case(m,"Player death animation")
	for kind in [0,1]:
		for phase in [0,1,2]:
			m = live()
			force_first(m,kind,1)
			var actor = m.active_threats[0].actor
			if phase > 0:
				actor.phase = phase
				actor.phase_elapsed = 0.01
				actor.position.x = 320+actor.ATTACK_DISTANCE+(10 if phase == 1 else 0)
				actor.advance_tick(0.001,320,false)
			await freeze_case(m,"Assassin %d phase %d" % [kind,phase])
	for kind in [2,3]:
		for phase in range(3 if kind == 2 else 4):
			m = live()
			force_first(m,kind,-1)
			var actor = m.active_threats[0].actor
			if phase > 0:
				actor.position.x = 350
				m._physics_process(DT)
				check(actor.is_complete and m.dodges == 1,"cosmetic fixture production handover")
				actor._physics_process(0.03 if phase == 1 else (0.53 if kind == 2 else (0.23 if phase == 2 else 0.98)))
				check(actor.phase == phase,"cosmetic fixture phase")
			await freeze_case(m,"Hazard %d phase %d" % [kind,phase])
	# Paused presses and held-through-resume echoes never queue any gameplay input.
	m = live()
	tap(KEY_P)
	var idle := node_state(m.player)
	for code in [KEY_Z,KEY_X,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: tap(code)
	check(node_state(m.player) == idle,"all paused gameplay presses discarded")
	key(KEY_DOWN)
	tap(KEY_P)
	key(KEY_DOWN,true)
	await physics_frame
	await physics_frame
	check(m.player.current_action == 0 and m.player.target_direction == 1 and m.player.turn_progress == 1,"no buffered action or turn after resume including held echo")
	key(KEY_DOWN,false,false)
	tap(KEY_DOWN)
	check(m.player.current_action == m.player.Action.DUCK,"fresh gameplay input after resume works")
	m.free()
	await process_frame
	# Actual ten-second wall pause with exactly .23 gameplay seconds remaining.
	m = live()
	for record in m.active_threats: record.actor.free()
	m.active_threats.clear()
	m.next_spawn_at = m.encounter_time+0.23
	var pending: Array = [m.pending_type,m.pending_side]
	tap(KEY_P)
	var before := snapshot(m)
	var wall_start: int = Time.get_ticks_msec()
	await create_timer(10.0,true).timeout
	check(snapshot(m) == before,"ten second pause preserves all clocks reservations RNG and pending")
	check(is_equal_approx(m.next_spawn_at-m.encounter_time,0.23),".23 remaining after ten wall seconds")
	print("TEN SECOND PAUSE wall_ms=",Time.get_ticks_msec()-wall_start," remaining=",m.next_spawn_at-m.encounter_time)
	tap(KEY_P)
	await physics_frame
	await physics_frame
	check(m.active_threats.is_empty(),"no catch-up spawn on resume")
	for frame in range(20):
		await physics_frame
		if not m.active_threats.is_empty(): break
	check(m.active_threats.size() == 1 and m.active_threats[0].type == pending[0] and m.active_threats[0].actor.entry_side == pending[1],"same pending spawns after remaining gameplay gap")
	m.free()
	await process_frame
	m = live(6)
	m.set_physics_process(false)
	force_first(m,0,1)
	m.pending_type = 3
	m.pending_side = -1
	for frame in range(200):
		m._physics_process(DT)
		if m.active_threats.size() == 2: break
	check(m.active_threats.size() == 2 and not m.player.is_dead,"two unresolved fixture")
	m.set_physics_process(true)
	await freeze_case(m,"two unresolved with pending reservations")
	var baseline: Array = await deterministic_run(false)
	var inserted: Array = await deterministic_run(true)
	check(baseline == inserted,"inserted real pauses preserve complete seeded spawn timeline and results")
	print("PAUSE DETERMINISM spawned=",baseline.size()," identical=",baseline==inserted)
	print("PAUSE RESULT checks=",checks," failures=",failures.size())
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)

func deterministic_run(with_pauses: bool) -> Array:
	var m = live()
	m.set_physics_process(false)
	var timeline: Array = []
	var seen: Dictionary = {}
	for frame in range(100000):
		if with_pauses and frame in [50,500,1000,2000,4000,8000]:
			tap(KEY_P)
			var before := snapshot(m)
			await create_timer(0.06,true).timeout
			check(snapshot(m) == before,"deterministic run exact inserted freeze")
			tap(KEY_P)
		for record in m.active_threats:
			var identity: int = record.actor.get_instance_id()
			if not seen.has(identity):
				seen[identity] = true
				timeline.append([record.type,record.actor.entry_side,m.encounter_time,record.lethal_at,record.response_start,record.response_end,record.actor.movement_speed])
		tick(m)
		if m.kills+m.dodges >= 200 or m.player.is_dead: break
		if frame % 400 == 0: await process_frame
	check(not m.player.is_dead and m.kills+m.dodges == 200,"200 encounter pause regression survival")
	timeline.append([m.score,m.kills,m.dodges,m.level,m.encounter_rng.state])
	m.free()
	await process_frame
	return timeline
