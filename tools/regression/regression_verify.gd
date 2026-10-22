extends "res://scheduler_verify.gd"

func _initialize() -> void:
	regression_run.call_deferred()

func regression_run() -> void:
	# Constants used by planning must continue to match the actual fixed-duration Player.
	var m = fresh()
	var p = m.player
	var durations: Array = [0.0,p.PUNCH_EXTENSION_DURATION+p.PUNCH_HOLD_DURATION+p.PUNCH_RECOVERY_DURATION,p.KICK_EXTENSION_DURATION+p.KICK_HOLD_DURATION+p.KICK_RECOVERY_DURATION,p.DUCK_CROUCH_DURATION+p.DUCK_HOLD_DURATION+p.DUCK_RECOVERY_DURATION,p.JUMP_DURATION]
	for index in range(5):
		check(is_equal_approx(durations[index],m.ThreatTiming.player_action_duration(index)),"planner action durations match Player")
		# Player timings are fixed by design; a change here invalidates every fairness measurement.
		check(is_equal_approx(durations[index],[0.0,0.30,0.40,0.60,0.82][index]),"Player action durations unchanged")
	check(p.JUMP_HEIGHT == 55 and p.DUCK_HEIGHT_SCALE == 0.45,"Jump and Duck geometry unchanged")
	press(p,KEY_DOWN)
	p.advance_tick(0.08)
	check(p.hurtbox.shape.size == Vector2(16,18) and p.visuals.position == Vector2.ZERO,"Duck geometry")
	press(p,KEY_Z)
	p.advance_tick(0.519)
	check(p.current_action == p.Action.DUCK,"Duck committed")
	p.advance_tick(0.001)
	check(p.current_action == p.Action.NONE,"Duck ends without buffered Punch")
	var held := InputEventKey.new()
	held.physical_keycode = KEY_DOWN
	held.pressed = true
	held.echo = true
	p._unhandled_input(held)
	check(p.current_action == p.Action.NONE,"held key cannot extend Duck")
	press(p,KEY_DOWN)
	check(p.current_action == p.Action.DUCK,"fresh Duck press works")
	m.free()
	await process_frame
	# Same-tick valid attack beats a lethal strike for either Assassin and side.
	for kind in [0,1]:
		for side in [-1,1]:
			for correct in [true,false]:
				m = fresh(9)
				force_first(m,kind,side)
				m.pending_type = -1
				var enemy = m.active_threats[0].actor
				enemy.position.x = 320+side*enemy.ATTACK_DISTANCE
				enemy.phase = enemy.Phase.STRIKE
				enemy.phase_elapsed = 0.14
				if kind == 1: enemy.crouch_elapsed = enemy.CROUCH_DURATION
				m.player.target_direction = side
				m.player.start_action(m.player.Action.KICK if (kind == 0) == correct else m.player.Action.PUNCH)
				m.player.advance_tick(0.09)
				m._physics_process(DT)
				check((m.kills == 1 and not m.player.is_dead) if correct else (m.kills == 0 and m.player.is_dead),"Assassin same-tick priority/correct response")
				m.free()
				await process_frame
	# A later array entry's valid Assassin attack must resolve before an earlier entry's damage pass.
	m = fresh(9)
	force_first(m,0,1)
	var red = m.active_threats[0].actor
	red.position.x = 358
	red.phase = red.Phase.STRIKE
	red.phase_elapsed = 0.14
	var distant = m.THREAT_SCENES[1].instantiate()
	distant.configure_entry(-1)
	distant.position = Vector2(80,300)
	m.add_child(distant)
	m.active_threats.push_front({"actor":distant,"type":1,"lethal_at":100.0,"response_start":99.7,"response_end":100.3})
	m.pending_type = -1
	m.player.target_direction = 1
	m.player.start_action(m.player.Action.KICK)
	m.player.advance_tick(0.09)
	m._physics_process(DT)
	check(m.kills == 1 and not m.player.is_dead and m.active_threats.size() == 1,"array order preserves Player priority")
	m.free()
	await process_frame
	# No reward or completion for a colliding hazard, even at its last overlapping horizontal position.
	for kind in [2,3]:
		for side in [-1,1]:
			m = fresh(9)
			force_first(m,kind,side)
			var hazard = m.active_threats[0].actor
			var radius: float = hazard.body_shape.shape.radius
			hazard.position.x = 320-side*(8+radius-0.2)+side*hazard.movement_speed*DT
			m._physics_process(DT)
			check(m.player.is_dead and m.dodges == 0 and m.score == 0 and not hazard.is_complete,"hazard collision before completion")
			m.free()
			await process_frame
	# Boundary scoring via real hazard passage; snapshots survive, cosmetics release capacity.
	for number in [4,12,24]:
		m = fresh()
		force_first(m,3,1)
		m.dodges = number-1
		m.level = 1+int((number-1)/4)
		var star = m.active_threats[0].actor
		star.position.x = 307
		m.pending_type = 3
		m.pending_side = -1
		var old_speed: float = star.movement_speed
		m._physics_process(DT)
		check(m.score == (150 if number == 24 else 100) and m.dodges == number,"old multiplier boundary award")
		check(m.level == 1+int(number/4),"boundary Level")
		check(m.get_multiplier_half_units() == (4 if number==24 else (3 if number==12 else 2)),"boundary next multiplier")
		check(m.active_threats.is_empty() and star.is_complete,"cosmetics release unresolved ownership")
		check(star.movement_speed == old_speed,"cosmetic speed snapshot")
		check(is_equal_approx(m.next_spawn_at-m.encounter_time,m.get_spawn_gap()),"new Level pacing after success")
		for frame in range(60):
			tick(m,false)
			if not m.active_threats.is_empty(): break
		check(m.active_threats[0].actor.movement_speed == m.get_spawn_speed(3),"next threat new Level speed")
		m.free()
		await process_frame
	# Fast pacing does not wait for Shuriken or Barrel cosmetics.
	for kind in [2,3]:
		m = fresh(10)
		force_first(m,kind,-1)
		var hazard = m.active_threats[0].actor
		hazard.position.x = 336
		m._physics_process(DT)
		for frame in range(23): tick(m,false)
		check(m.dodges == 1 and is_instance_valid(hazard) and hazard.is_complete and m.active_threats.size() == 1,"cosmetic coexists with next gameplay")
		var score_before: int = m.score
		hazard.position = Vector2(320,293 if kind==2 else 270)
		hazard.resolve_contact(m.player)
		check(not m.player.is_dead,"cosmetic harmless")
		for frame in range(60): tick(m,false)
		await process_frame
		check(not is_instance_valid(hazard) and m.score == score_before and m.dodges == 1,"cosmetic removed without duplicate score")
		m.free()
		await process_frame
	# Accepted emergent Duck/Jump interactions remain purely spatial.
	for kind in [0,1,2,3]:
		m = fresh(9)
		force_first(m,kind,1)
		m.pending_type = -1
		var actor = m.active_threats[0].actor
		if kind < 2:
			actor.position.x = 320+actor.ATTACK_DISTANCE
			actor.phase = actor.Phase.STRIKE
			actor.phase_elapsed = 0.16
			if kind == 1: actor.crouch_elapsed = actor.CROUCH_DURATION
		else: actor.position.x = 320
		m.player.start_action(m.player.Action.DUCK)
		m.player.advance_tick(0.30)
		m._physics_process(0.001)
		check(m.player.is_dead == (kind==1 or kind==2),"Duck evades Red/Shuriken, vulnerable Blue/Barrel")
		m.free()
		await process_frame
	# Persistence and run-relative multiplier remain intact.
	m = fresh(10)
	m.records.entries.assign([{"initials":"AAA","score":12345}])
	m.records.save_records()
	m.records.load_records()
	check(m.high_score == 12345,"High Score round trip")
	check(m.get_multiplier_half_units() == 2,"higher start x1")
	m.level = 13
	check(m.get_multiplier_half_units() == 3,"run-relative multiplier")
	m.free()
	await process_frame
	print("REGRESSION RESULT checks=%d failures=%d" % [checks,failures.size()])
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)
