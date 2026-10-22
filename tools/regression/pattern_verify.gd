extends "res://scheduler_verify.gd"

func _initialize() -> void:
	patterns.call_deferred()

func fixed(level_value: int, seed_value: int):
	var m = MAIN.instantiate()
	m.set_script(load("res://fixed_main.gd"))
	m.process_mode = Node.PROCESS_MODE_DISABLED
	m.run_start_level = level_value
	m.encounter_rng.seed = seed_value
	m.start_in_run = true
	m.records = preload("res://scripts/run_records.gd").new()
	m.records.highest_level = 1000000
	for slot in range(10): m.records.entries.append({"initials":"AAA","score":1000000000})
	root.add_child(m)
	return m

func fingerprint(m) -> Array:
	return [m.pending_type,m.pending_side,m.pattern_id,m.pattern_step,m.pattern_start_side,m.encounter_rng.state]

func fairness_wait(m) -> bool:
	if m.pending_type < 0 or m.encounter_time < m.next_spawn_at or m.active_threats.size() >= m.get_max_unresolved(): return false
	return m.plan_pending_press().is_empty()

func sample(level_value: int, seed_value: int, count: int) -> Array:
	var m = fixed(level_value,seed_value)
	var oracle = load("res://pattern_oracle.gd").new()
	oracle.rng.seed = seed_value
	var seen: Dictionary = {}
	var trace: Array = []
	var types: Array = [0,0,0,0]
	var sides: Array = [0,0]
	var pattern_steps: int = 0
	var starts: int = 0
	var completed: int = 0
	var random_count: int = 0
	var repeats: Array = [0,0]
	var overlap: int = 0
	var frames: int = 0
	var wait_time: float = 0
	var waits: Array = []
	var pattern_counts: Dictionary = {}
	for frame in range(count*600):
		for r in m.active_threats:
			var id: int = r.actor.get_instance_id()
			if seen.has(id): continue
			seen[id] = true
			var actual: Array = [r.type,r.actor.entry_side,r.pattern,r.pattern_step]
			check(actual == oracle.pick(level_value),"fixed-level independent RNG oracle")
			if r.pattern >= 0:
				pattern_steps += 1
				if r.pattern_step == 0: starts += 1
				else: completed += 1
				var key: String = "%d:%d:%d" % [r.pattern,r.pattern_step,r.actor.entry_side]
				pattern_counts[key] = pattern_counts.get(key,0)+1
				if wait_time > 0: waits.append(wait_time)
			else: random_count += 1
			wait_time = 0
			if not trace.is_empty():
				if trace[-1][0] == r.type: repeats[0] += 1
				if trace[-1][1] == r.actor.entry_side: repeats[1] += 1
			types[r.type] += 1
			sides[0 if r.actor.entry_side == -1 else 1] += 1
			trace.append(actual+[snappedf(m.encounter_time,0.000001)])
		if trace.size() >= count: m.pending_type = -1
		var before: Array = fingerprint(m)
		m.select_pending_threat() if m.pending_type >= 0 else null
		check(before == fingerprint(m),"selection cannot reroll occupied slot")
		var old_ids: Array = m.active_threats.map(func(r): return r.actor.get_instance_id())
		if fairness_wait(m): wait_time += DT
		tick(m)
		if m.active_threats.all(func(r): return old_ids.has(r.actor.get_instance_id())) and not m.player.is_dead:
			check(before == fingerprint(m),"entire waiting pattern state and RNG retained")
		frames += 1
		if m.active_threats.size() == 2: overlap += 1
		if frame%600 == 0: await process_frame
		if m.player.is_dead or m.kills+m.dodges == count: break
	check(not m.player.is_dead and m.kills+m.dodges == count,"fixed-level full survival and no starvation")
	check(random_count > pattern_steps,"random threats majority")
	check(repeats[0] > 0 and repeats[1] > 0,"types and sides may repeat")
	check(starts-completed <= 1,"no skipped pattern steps")
	var total_wait: float = 0
	for w in waits: total_wait += w
	print("PATTERN_STATS ",JSON.stringify({"level":level_value,"n":count,"steps":pattern_steps,"starts":starts,"completed":completed,"start_rate":float(starts)/maxi(1,starts+random_count),"share":float(pattern_steps)/count,"types":types,"sides":sides,"repeats":repeats,"overlap":float(overlap)/frames,"delayed_pattern_steps":waits.size(),"wait_mean":total_wait/maxi(1,waits.size()),"wait_max":waits.max() if not waits.is_empty() else 0,"coverage":pattern_counts}))
	m.free()
	await process_frame
	return trace

func patterns() -> void:
	for lv in [1,5,6,8,10,15,20,30]:
		await sample(lv,310031,2000)
	var a: Array = await sample(20,311031,300)
	var b: Array = await sample(20,311031,300)
	check(a == b,"pattern trace deterministic repeat")
	for lv in [4,6,7,10,20,30]:
		var pool: int = 2 if lv < 7 else (4 if lv < 10 else 8)
		for pid in range(pool):
			for side in [-1,1]:
				var m = fixed(lv,31)
				for r in m.active_threats: r.actor.free()
				m.active_threats.clear()
				m.cancel_pending_spawn()
				m.pattern_id = pid
				m.pattern_start_side = side
				m.select_pending_threat()
				m.next_spawn_at = 0
				m.try_spawn_pending_threat()
				var first: int = m.active_threats[0].actor.get_instance_id()
				var second_seen: bool = false
				for frame in range(900):
					tick(m)
					for r in m.active_threats:
						if r.actor.get_instance_id() != first:
							check(r.pattern == pid and r.pattern_step == 1 and r.actor.entry_side == -side,"targeted mirrored second step retained")
							second_seen = true
							m.pending_type = -1
					if m.player.is_dead or m.kills+m.dodges == 2: break
				check(second_seen and not m.player.is_dead and m.kills+m.dodges == 2,"every unlocked pattern mirrored survival")
				m.free()
				await process_frame
	print("PATTERNS_RESULT checks=",checks," failures=",failures," minimum_margin=",minimum_pair_margin)
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)
