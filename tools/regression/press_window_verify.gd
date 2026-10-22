extends "res://scheduler_verify.gd"
## Proves ThreatTiming against the real game. The fair scheduler plans presses inside these
## windows, so they must hold for every speed and wind-up the curve can produce:
## 1. its mirrored geometry constants match the actual scenes;
## 2. a press on every 60 Hz tick inside each trimmed window wins, for all threats, both sides;
## 3. the windows are not vacuous: clearly early or late presses still fail.
const LEVELS = [1, 2, 5, 9, 10, 15, 20, 30, 40, 45, 49, 50, 60, 1000]
const KEYS = [KEY_X, KEY_Z, KEY_UP, KEY_DOWN]

func _initialize() -> void:
	windows.call_deferred()

## Simulates one isolated threat with a single intended press; true when it is handled safely.
func attempt(level_value: int, kind: int, side: int, press_time: float) -> bool:
	var m = fresh(level_value)
	force_first(m, kind, side)
	m.pending_type = -1
	# Face the threat already; turning is the scheduler's separate allowance.
	m.player.target_direction = float(side)
	m.player.turn_progress = float(side)
	m.player.visuals.scale.x = float(side)
	var pressed: bool = false
	for frame in range(900):
		if not pressed and m.encounter_time + 0.0000001 >= press_time:
			press(m.player, KEYS[kind])
			pressed = true
		m._physics_process(DT)
		if m.player.is_dead or m.kills + m.dodges == 1: break
	var won: bool = pressed and not m.player.is_dead and m.kills + m.dodges == 1
	m.free()
	return won

func geometry_checks() -> void:
	var T = load("res://scripts/threat_timing.gd")
	var m = fresh(1)
	var p = m.player
	check(p.hurtbox.shape.size == Vector2(2.0 * T.PLAYER_HALF_WIDTH, T.PLAYER_HEIGHT) and is_equal_approx(p.global_position.y, T.FLOOR_Y), "Player hurtbox and floor match")
	check(is_equal_approx(p.kick_shape.position.x + p.kick_shape.shape.size.x / 2.0, T.KICK_REACH), "kick reach matches scene")
	check(is_equal_approx(p.punch_shape.position.x + p.punch_shape.shape.size.x / 2.0, T.PUNCH_REACH), "punch reach matches scene")
	for kind in range(4):
		for side in [-1, 1]:
			force_first(m, kind, side)
			var actor = m.active_threats[0].actor
			check(is_equal_approx(absf(actor.position.x - p.position.x), T.SPAWN_DISTANCE), "spawn distance matches")
			if kind < 2:
				check(is_equal_approx(actor.get_node("Hurtbox").shape.size.x, 2.0 * T.ASSASSIN_HALF_WIDTH), "assassin width matches")
			elif kind == 2:
				check(is_equal_approx(actor.body_shape.shape.radius, T.BARREL_RADIUS) and is_equal_approx(actor.body_shape.global_position.y, T.FLOOR_Y - T.BARREL_RADIUS), "Barrel radius and rolling height match")
			else:
				check(is_equal_approx(actor.body_shape.shape.radius, T.SHURIKEN_RADIUS) and is_equal_approx(actor.body_shape.global_position.y, actor.FLIGHT_HEIGHT), "Shuriken radius and flight height match")
	m.free()
	await process_frame
	# Shorter late wind-ups must still finish Blue's crouch before it enters Kick range,
	# otherwise a Kick could defeat Blue and the threat language would blur.
	for level_value in LEVELS:
		m = fresh(level_value)
		var speed: float = m.get_spawn_speed(1)
		var crouched_at_distance: float = T.BlueScript.ATTACK_DISTANCE + speed * (m.get_windup_duration() - T.BlueScript.CROUCH_DURATION)
		check(crouched_at_distance >= T.KICK_REACH + T.ASSASSIN_HALF_WIDTH, "Blue crouches before Kick range at Level %d" % level_value)
		m.free()
		await process_frame

func windows() -> void:
	await geometry_checks()
	var T = load("res://scripts/threat_timing.gd")
	var presses: int = 0
	for level_value in LEVELS:
		var probe = fresh(level_value)
		for kind in range(4):
			var speed: float = probe.get_spawn_speed(kind)
			var window: Vector2 = T.press_window(kind, speed)
			var first: float = window.x + probe.PRESS_WINDOW_INSET
			var last: float = window.y - probe.PRESS_WINDOW_INSET
			check(last >= first, "window survives tick trimming level %d type %d" % [level_value, kind])
			for side in [-1, 1]:
				# Every tick boundary inside the trimmed window, plus both exact ends.
				var times: Array[float] = [first, last]
				var t: float = ceilf(first / DT) * DT
				while t <= last:
					times.append(t)
					t += DT
				for press_time in times:
					presses += 1
					check(attempt(level_value, kind, side, press_time), "press inside window wins level %d type %d side %d t=%.4f" % [level_value, kind, side, press_time])
				check(not attempt(level_value, kind, side, window.x - 0.25), "clearly early press fails level %d type %d" % [level_value, kind])
				check(not attempt(level_value, kind, side, window.y + 0.15), "clearly late press fails level %d type %d" % [level_value, kind])
				await process_frame
			if level_value in [1, 20, 50]:
				print("WINDOW level=%d type=%d speed=%.2f press=%.3f..%.3f width=%.0fms lethal=%.3f" % [level_value, kind, speed, window.x, window.y, (window.y - window.x) * 1000.0, T.lethal_lead(kind, speed)])
		probe.free()
		await process_frame
	print("PRESS_WINDOWS presses=", presses, " checks=", checks, " failures=", failures)
	await create_timer(0.25, true).timeout
	quit(0 if failures.is_empty() else 1)
