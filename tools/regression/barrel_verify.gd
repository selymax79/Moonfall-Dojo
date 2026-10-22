extends "res://scheduler_verify.gd"
func _initialize(): targeted.call_deferred()
func targeted():
	for level_value in [1,5,9]:
		for side in [-1,1]:
			for face in [-1,1]:
				for timing in [-0.45,0.0,0.45,99.0]:
					var m = fresh(level_value)
					force_first(m,2,side)
					m.pending_type = -1
					var b = m.active_threats[0].actor
					m.player.target_direction = face
					var due: float = m.ThreatTiming.spawn_distance(2)/b.movement_speed-m.player.JUMP_DURATION/2.0+timing
					var pressed: bool = false
					while not m.player.is_dead and not b.is_complete:
						if not pressed and m.encounter_time >= due:
							press(m.player,KEY_UP)
							pressed = true
						m._physics_process(DT)
					check((m.dodges == 1 and m.score == 100 and m.kills == 0 and not m.player.is_dead) if timing == 0 else (m.player.is_dead and m.score == 0 and m.dodges == 0),"real spawn timing/side/facing outcome")
					if timing == 0:
						check(m.active_threats.is_empty(),"resolved Barrel releases ownership")
						var passed_x: float = b.position.x
						b._physics_process(0.2)
						check(b.phase == b.Phase.DEPARTING and is_equal_approx(absf(b.position.x-passed_x),b.movement_speed*0.2),"short rolling departure")
						m.player.advance_tick(1.0)
						b.position.x = 320
						b.resolve_contact(m.player)
						check(not m.player.is_dead,"departure harmless even on Player")
						b._physics_process(0.3)
						check(b.phase == b.Phase.EXPLODING,"explosion follows departure")
						b.resolve_contact(m.player)
						b._physics_process(0.4)
						check(b.is_queued_for_deletion() and m.score == 100 and m.dodges == 1 and not m.player.is_dead,"cleanup harmless and no duplicate rewards")
					m.free()
					await process_frame
	var m = fresh()
	force_first(m,2,1)
	m.pending_type = -1
	for record in m.active_threats: record.actor.free()
	m.active_threats.clear()
	var p = m.player
	for repeat in range(100):
		press(p,KEY_UP)
		p.advance_tick(0.41)
		check(is_equal_approx(p.visuals.position.y,-55),"unchanged apex")
		for key in [KEY_UP,KEY_Z,KEY_X,KEY_DOWN,KEY_LEFT]: press(p,key)
		p.advance_tick(0.41)
		check(p.current_action == p.Action.NONE and p.position == Vector2(320,300) and p.visuals.position == Vector2.ZERO and p.hurtbox.position == Vector2(0,-20) and p.hurtbox.shape.size == Vector2(16,40),"landing exact and no buffering/drift")
	for repeat in range(60):
		m.next_spawn_at = 0
		m.pending_type = 2
		m.pending_side = -1 if repeat%2 else 1
		m.try_spawn_pending_threat()
		check(m.active_threats.size() == 1,"one live Barrel")
		var b = m.active_threats[0].actor
		b.position.x = 320-b.entry_side*18
		m.pending_type = -1
		m._physics_process(DT)
		b._physics_process(0.9)
		await process_frame
		var remaining: int = 0
		for child in m.get_children():
			if child.get_script() == load("res://scripts/barrel.gd"): remaining+=1
		check(remaining == 0,"no accumulated Barrel nodes")
	check(m.dodges == 60 and m.kills == 0,"one reward per repeated Barrel")
	m.free()
	await process_frame
	await create_timer(0.25,true).timeout
	print("BARREL TARGETED checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
