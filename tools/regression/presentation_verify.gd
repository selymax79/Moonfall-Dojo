extends "res://features_verify.gd"

func _initialize():
	presentation_run.call_deferred()

func trace(cosmetic_seed_value: int, cosmetic_rate: float) -> Array:
	var m = fresh(10, 272727)
	var environment = m.get_node("Environment")
	environment.set_physics_process(false)
	environment.cosmetic_rng.seed = cosmetic_seed_value
	var seen := {}
	var result := []
	for frame in range(50000):
		environment._physics_process(DT * cosmetic_rate)
		tick(m)
		for record in m.active_threats:
			var identity: int = record.actor.get_instance_id()
			if not seen.has(identity):
				seen[identity] = true
				result.append([record.type, record.actor.entry_side, record.lethal_at, record.response_start, record.response_end, record.actor.movement_speed])
		if m.player.is_dead or m.kills + m.dodges >= 200: break
		if frame % 60 == 0: await process_frame
	check(not m.player.is_dead and m.kills + m.dodges == 200, "200 successful encounters with independent ambience")
	result.append([m.score, m.kills, m.dodges, m.level, m.encounter_rng.state])
	print("COSMETIC TRACE seed=",cosmetic_seed_value," rate=",cosmetic_rate," encounters=",result.size()-1," ambient_time=",environment.ambient_time)
	m.free()
	await process_frame
	return result

func presentation_run():
	var m = fresh()
	var environment = m.get_node("Environment")
	environment.set_physics_process(false)
	check(m.run_stats.position == Vector2(0,308) and m.run_stats.size == Vector2(640,52), "fixed HUD geometry")
	check(m.player.position == Vector2(320,300), "unchanged player feet")
	for value in [0, 12450, 9876543210, 9223372036854775807]:
		m.score = value
		m.high_score = value
		m.kills = value
		m.dodges = value
		m.level = maxi(1,value)
		m.update_hud()
		for label in m.run_stats.get_children():
			if label is Label:
				var font: Font = label.get_theme_font("font")
				var size_value: int = label.get_theme_font_size("font_size")
				check(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x <= label.size.x, "full value fits "+str(label.name))
				check(Rect2(Vector2.ZERO,m.run_stats.size).encloses(label.get_rect()), "label contained in panel")
		check(m.score_label.text == "SCORE %08d" % value, "score formatting full integer")
		check(m.multiplier_label.text.ends_with(".0") or m.multiplier_label.text.ends_with(".5"), "multiplier half-units formatting")
	var original_nodes: int = environment.find_children("*","",true,false).size()
	var bat_directions := {}
	var door_kinds := {}
	var door_panels := {}
	var bat_events: int = 0
	var door_events: int = 0
	for frame in range(36000):
		var old_bat: float = environment.bat_elapsed
		var old_door: float = environment.door_elapsed
		environment._physics_process(DT)
		if old_bat < 0 and environment.bat_elapsed >= 0:
			bat_events += 1
			bat_directions[environment.bat_direction] = true
		if old_door < 0 and environment.door_elapsed >= 0:
			door_events += 1
			door_kinds[environment.door_is_dog] = true
			door_panels[environment.door_index] = true
	check(bat_events > 5 and bat_events < 25 and door_events > 5 and door_events < 25, "infrequent events in ten simulated minutes")
	check(bat_directions.size() == 2 and door_kinds.size() == 2 and door_panels.size() == 2, "both directions figures and panels")
	check(environment.find_children("*","",true,false).size() == original_nodes, "no cosmetic node accumulation")
	print("AMBIENCE 600s bat_events=",bat_events," door_events=",door_events," nodes=",original_nodes)
	m.free()
	await process_frame
	m = menu_fixture()
	environment = m.get_node("Environment")
	check(not environment.visible and not environment.is_physics_processing(), "menu ambience hidden stopped")
	m.free()
	await process_frame
	var first: Array = await trace(123,1.0)
	var second: Array = await trace(987654,9.0)
	check(first == second, "gameplay trace identical despite different cosmetic RNG and elapsed time")
	print("PRESENTATION RESULT checks=",checks," failures=",failures)
	await create_timer(0.5,true).timeout
	quit(0 if failures.is_empty() else 1)
