extends "res://scheduler_verify.gd"
## Pacing measurement, not a pass/fail suite (beyond survival): at each fixed Level, an idealised
## intended-response autopilot handles 400 threats. Reports threats per second, the mean gap
## between spawns and the share of time with two unresolved threats. Compare runs before and
## after any difficulty or scheduler change; automated pacing is not a substitute for playtesting.
const LEVELS = [1, 5, 6, 10, 15, 20, 25, 30, 40, 50, 60]
const HANDLED: int = 400

func _initialize() -> void:
	measure.call_deferred()

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

func measure() -> void:
	for level_value in LEVELS:
		var m = fixed(level_value, 300030)
		var seen: Dictionary = {}
		var spawn_times: Array[float] = []
		var frames: int = 0
		var overlap: int = 0
		for frame in range(HANDLED * 600):
			for record in m.active_threats:
				var id: int = record.actor.get_instance_id()
				if not seen.has(id):
					seen[id] = true
					spawn_times.append(m.encounter_time)
			if spawn_times.size() >= HANDLED: m.pending_type = -1
			tick(m)
			frames += 1
			if m.active_threats.size() == 2: overlap += 1
			if frame % 600 == 0: await process_frame
			if m.player.is_dead or m.kills + m.dodges == HANDLED: break
		check(not m.player.is_dead and m.kills + m.dodges == HANDLED, "pacing run survives level %d" % level_value)
		var span: float = spawn_times[-1] - spawn_times[0]
		print("PACING level=%d speed=%.1f mean_spawn_gap=%.3f threats_per_s=%.3f overlap=%.1f%%" % [level_value, m.get_spawn_speed(0), span / (spawn_times.size() - 1), (spawn_times.size() - 1) / span, 100.0 * overlap / frames])
		m.free()
		await process_frame
	print("PACING_RESULT checks=", checks, " failures=", failures)
	await create_timer(0.25, true).timeout
	quit(0 if failures.is_empty() else 1)
