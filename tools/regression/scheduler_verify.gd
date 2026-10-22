extends SceneTree
const MAIN = preload("res://scenes/main.tscn")
const DT: float = 1.0/60.0
var checks: int = 0
var failures: Array[String] = []
var minimum_pair_margin: float = INF

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		if failures.size() < 25: print("FAIL ",label)

func fresh(start_level: int = 1, seed_value: int = 202018):
	var m = MAIN.instantiate()
	m.process_mode = Node.PROCESS_MODE_DISABLED
	m.run_start_level = start_level
	m.encounter_rng.seed = seed_value
	m.start_in_run = true
	m.records = preload("res://scripts/run_records.gd").new()
	m.records.highest_level = 1000000
	for slot in range(10): m.records.entries.append({"initials":"AAA","score":1000000000})
	root.add_child(m)
	return m

func force_first(m, kind: int, side: int) -> void:
	for record in m.active_threats: record.actor.free()
	m.active_threats.clear()
	m.clear_pattern()
	m.encounter_time = 0
	m.next_spawn_at = 0
	m.pending_type = kind
	m.pending_side = side
	m.try_spawn_pending_threat()

func press(player, key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	player._unhandled_input(event)

func planned_press(m, record: Dictionary) -> float:
	match record.type:
		0: return record.lethal_at - 0.09 - 0.08
		1: return record.lethal_at - 0.08 - 0.06
		2: return record.lethal_at + 17.0/record.actor.movement_speed - m.player.JUMP_DURATION/2.0
		3: return record.lethal_at + 12.0/record.actor.movement_speed - (0.0509090909+0.4918181818)/2
	return INF

func autopilot(m) -> void:
	if m.active_threats.is_empty() or m.player.is_dead: return
	var record: Dictionary = m.active_threats[0]
	var actor = record.actor
	if actor.has_meta("pressed"): return
	var due: float = planned_press(m,record)
	if record.type < 2 and m.encounter_time >= due-0.10 and m.player.current_action == m.player.Action.NONE:
		press(m.player,KEY_RIGHT if actor.entry_side == 1 else KEY_LEFT)
	if m.encounter_time + 0.0000001 >= due:
		check(m.player.current_action == m.player.Action.NONE,"response starts after prior commitment")
		press(m.player,[KEY_X,KEY_Z,KEY_UP,KEY_DOWN][record.type])
		actor.set_meta("pressed",true)

func tick(m, drive: bool = true) -> void:
	# Resolved cosmetics alone own their tick; disabled test scenes let us step them deterministically.
	for child in m.get_children():
		if child.has_method("resolve_contact") and child.is_complete and not child.is_queued_for_deletion():
			child._physics_process(DT)
	if drive: autopilot(m)
	var old_pending: int = m.pending_type
	var old_side: int = m.pending_side
	var old_rng: int = m.encounter_rng.state
	var old_ids: Array = m.active_threats.map(func(r): return r.actor.get_instance_id())
	m._physics_process(DT)
	check(m.active_threats.size() <= m.get_max_unresolved(),"configured unresolved cap")
	if old_rng == m.encounter_rng.state and not m.player.is_dead and m.active_threats.all(func(r): return old_ids.has(r.actor.get_instance_id())):
		check(old_pending == m.pending_type and old_side == m.pending_side,"waiting choice preserved")
	if m.active_threats.size() == 2:
		var first: Dictionary = m.active_threats[0]
		var second: Dictionary = m.active_threats[1]
		var turn: float = 0.10 if second.type < 2 else 0.0
		var gap: float = second.response_start-first.response_end-turn
		minimum_pair_margin = minf(minimum_pair_margin,gap)
		check(gap >= 0.10-0.000001,"pair recovery turn and margin")
		check(second.actor.movement_speed == second.actor.get_meta("snapshot",second.actor.movement_speed),"speed snapshot")

func run() -> void:
	print("USER DATA ",OS.get_user_data_dir())
	# Standing first-contact measurements test the scheduler formulas against actual threat geometry.
	for start_level in [1,5,9,1000]:
		for kind in range(4):
			for side in [-1,1]:
				var m = fresh(start_level)
				force_first(m,kind,side)
				m.pending_type = -1
				var forecast: float = m.active_threats[0].lethal_at
				for frame in range(350):
					tick(m,false)
					if m.player.is_dead: break
				check(m.player.is_dead and absf(m.encounter_time-forecast) <= DT+0.000001,"standing contact matches model")
				check(m.score == 0 and m.kills == 0 and m.dodges == 0,"lethal encounter no reward")
				if side == 1: print("CONTACT level=%d type=%d model=%.6f measured=%.6f" % [start_level,kind,forecast,m.encounter_time])
				m.free()
				await process_frame
	# All 16 ordered types x four side combinations x six representative levels.
	var pair_count: int = 0
	var overlap_count: int = 0
	for start_level in [1,5,6,9,10,1000]:
		for a in range(4):
			for b in range(4):
				for side_a in [-1,1]:
					for side_b in [-1,1]:
						var m = fresh(start_level)
						force_first(m,a,side_a)
						var first_id: int = m.active_threats[0].actor.get_instance_id()
						m.pending_type = b
						m.pending_side = side_b
						var saw_second: bool = false
						var overlap: bool = false
						for frame in range(900):
							tick(m)
							for record in m.active_threats:
								if record.actor.get_instance_id() != first_id:
									check(record.type == b and record.actor.entry_side == side_b,"pending pair spawned unchanged")
									saw_second = true
									m.pending_type = -1
								overlap = overlap or m.active_threats.size() == 2
							if m.player.is_dead or m.kills+m.dodges == 2: break
						check(not m.player.is_dead and m.kills+m.dodges == 2 and saw_second,"pair survives %d->%d sides=%d,%d level=%d" % [a,b,side_a,side_b,start_level])
						check(overlap == (start_level >= 6),"overlap unlock matches pacing")
						pair_count += 1
						if overlap: overlap_count += 1
						m.free()
						await process_frame
	print("PAIR MATRIX cases=%d overlap_cases=%d minimum_margin=%.6f failures=%d" % [pair_count,overlap_count,minimum_pair_margin,failures.size()])
	await targeted()
	var first: Array = await long_run(180020,4000)
	var repeated: Array = await long_run(180020,4000)
	var different: Array = await long_run(190020,1000)
	check(first == repeated,"identical seed produces identical type/side/spawn timings")
	check(first.slice(0,1000) != different,"different seed differs")
	print("DETERMINISM same_seed_equal=",first==repeated," different_seed_differs=",first.slice(0,1000)!=different)
	print("RESULT checks=%d failures=%d" % [checks,failures.size()])
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)

func long_run(seed_value: int, count: int) -> Array:
	var m = fresh(1,seed_value)
	var expected = load("res://pattern_oracle.gd").new()
	expected.rng.seed = seed_value
	var next_choice: Array = expected.pick(1)
	var recorded: Dictionary = {}
	var timeline: Array = []
	var combinations: Dictionary = {}
	var previous_type: int = -1
	var previous_side: int = 0
	var type_repeats: int = 0
	var side_repeats: int = 0
	var expected_score: int = 0
	var expected_kills: int = 0
	var expected_dodges: int = 0
	var accounted: Dictionary = {}
	var seen_rows: Array[Dictionary] = []
	var overlap_ticks: int = 0
	for frame in range(count*600):
		for record in m.active_threats:
			var actor = record.actor
			var id: int = actor.get_instance_id()
			if not recorded.has(id):
				recorded[id] = true
				var kind: int = next_choice[0]
				var side: int = next_choice[1]
				next_choice = expected.pick(m.level)
				check(record.type == kind and actor.entry_side == side,"long-run exact RNG sequence")
				var stamp: Array = [kind,side,snappedf(m.encounter_time,0.000001),actor.movement_speed]
				timeline.append(stamp)
				combinations[str(kind)+":"+str(side)] = true
				if previous_type == kind: type_repeats += 1
				if previous_side == side: side_repeats += 1
				previous_type = kind
				previous_side = side
				actor.set_meta("snapshot",actor.movement_speed)
				seen_rows.append({"id":id,"type":kind,"row":record})
		if timeline.size() >= count:
			m.pending_type = -1
		var old_handled: int = m.kills+m.dodges
		var old_multiplier: int = m.get_multiplier_half_units()
		tick(m)
		if m.active_threats.size() == 2: overlap_ticks += 1
		for history in seen_rows:
			if not accounted.has(history.id) and not m.active_threats.has(history.row):
				accounted[history.id] = true
				expected_score += 50*old_multiplier
				if history.type < 2: expected_kills += 1
				else: expected_dodges += 1
		if m.kills+m.dodges != old_handled:
			check(m.score == expected_score and m.kills == expected_kills and m.dodges == expected_dodges,"long-run score and counters")
			check(m.level == 1+int((m.kills+m.dodges)/4),"long-run progression")
			# Only unresolved history is needed; bound test bookkeeping too.
			seen_rows = seen_rows.filter(func(entry): return not accounted.has(entry.id))
			await process_frame
		if m.player.is_dead:
			check(false,"long-run player died seed=%d handled=%d" % [seed_value,m.kills+m.dodges])
			break
		if m.kills+m.dodges >= count: break
	check(m.kills+m.dodges == count,"long run completes without deadlock")
	check(combinations.size() == 8 and type_repeats>0 and side_repeats>0,"long-run vocabulary and repeats")
	print("LONG RUN seed=%d handled=%d score=%d level=%d overlap_ticks=%d combinations=%d type_repeats=%d side_repeats=%d" % [seed_value,m.kills+m.dodges,m.score,m.level,overlap_ticks,combinations.size(),type_repeats,side_repeats])
	m.free()
	await process_frame
	return timeline

func targeted() -> void:
	for start_level in [1,3,4,5,6,7,9,10,1000]:
		var m = fresh(start_level)
		check(is_equal_approx(m.get_spawn_gap(),0.85 if start_level<=3 else (0.65 if start_level<=6 else (0.45 if start_level<=9 else (0.35 if start_level<15 else (0.20 if start_level<20 else (0.10 if start_level<30 else 0.0)))))),"gap bands")
		check(m.get_max_unresolved() == (1 if start_level<6 else 2),"capacity bands")
		m.free()
		await process_frame
	# A blocked pending choice is held even at high Level; no random draws or swaps.
	var m = fresh(9)
	force_first(m,2,1)
	m.pending_type = 3
	m.pending_side = -1
	var state_before: int = m.encounter_rng.state
	for frame in range(65): tick(m,false)
	check(m.active_threats.size() == 1 and m.pending_type == 3 and m.pending_side == -1 and m.encounter_rng.state == state_before,"unsafe choice waits without reroll")
	m.free()
	await process_frame
	# An overdue Assassin forecast blocks future admissions instead of promising a retry's timing.
	m = fresh(9)
	force_first(m,0,1)
	m.encounter_time = m.active_threats[0].lethal_at+0.01
	m.next_spawn_at = 0
	state_before = m.encounter_rng.state
	m.try_spawn_pending_threat()
	check(m.active_threats.size() == 1 and m.encounter_rng.state == state_before,"overdue forecast waits")
	m.free()
	await process_frame
	# Pending speed uses the current Level, not its selection Level.
	m = fresh(3)
	force_first(m,0,1)
	var existing = m.active_threats[0].actor
	var snapshot: float = existing.movement_speed
	m.level = 9
	check(existing.movement_speed == snapshot,"existing speed on Level change")
	m.active_threats.clear()
	existing.free()
	m.pending_type = 3
	m.pending_side = -1
	m.next_spawn_at = 0
	m.try_spawn_pending_threat()
	check(m.active_threats[0].actor.movement_speed == 125,"pending uses new Level speed")
	m.free()
	await process_frame
	# Death cancels all admissions and freezes score, including pending hazards.
	m = fresh(9)
	force_first(m,3,1)
	m.active_threats[0].actor.position.x = 320
	tick(m,false)
	check(m.player.is_dead and m.pending_type == -1 and m.next_spawn_at == -1 and m.score == 0,"death cancels pending and lethal earns nothing")
	var unresolved: int = m.active_threats.size()
	for frame in range(300): tick(m,false)
	check(m.active_threats.size() == unresolved and m.score == 0 and m.dodges == 0,"no post-death spawns/rewards")
	m.free()
	await process_frame
	print("TARGETED fairness/pacing/death checks complete")
