extends "res://features_verify.gd"
const AFTERMATH = preload("res://scripts/combat_aftermath.gd")
func _initialize(): art_run.call_deferred()
func corpses(m) -> Array:
	var result := []
	for child in m.get_children():
		if child.get_script() == AFTERMATH: result.append(child)
	return result
func art_run():
	var m = fresh(10)
	var player = m.player
	var art = player.get_node("Art")
	player.start_action(player.Action.DUCK)
	player.advance_tick(0.08)
	player.receive_hit()
	art.update_pose()
	check(art.frame == 29,"crouched Player death starts in low collapse")
	var blue_image := Image.load_from_file(ProjectSettings.globalize_path("res://art/combat/blue.png"))
	var top: int = 100
	for y in range(56):
		for x in range(96):
			if blue_image.get_pixel(3*96+x,3*56+y).a > 0: top = mini(top,y-48)
	check(top == -24,"Blue impact pose preserves low silhouette")
	m.free()
	await process_frame
	m = fresh(10)
	player = m.player
	art = player.get_node("Art")
	for side in [-1,1]:
		for action in [player.Action.PUNCH,player.Action.KICK,player.Action.JUMP,player.Action.DUCK]:
			player.target_direction = side
			player.start_action(action)
			for frame_index in range(50):
				player.advance_tick(DT)
				var transform: Transform2D = player.hurtbox.global_transform
				var dimensions: Vector2 = player.hurtbox.shape.size
				var rng: int = m.encounter_rng.state
				art._physics_process(DT)
				check(transform == player.hurtbox.global_transform and dimensions == player.hurtbox.shape.size,"art cannot change hurtbox")
				check(m.encounter_rng.state == rng,"art consumes no encounter RNG")
				check(art.rotation == 0 and art.scale == Vector2.ONE,"no sprite rotation or fractional scaling")
				if action == player.Action.JUMP: check(art.position == Vector2.ZERO,"jump ground-shadow origin remains on floor")
	# Repeated real attack resolutions: corpses are cosmetic and never enter the unresolved list.
	for encounter in range(60):
		force_first(m,encounter%2,1 if encounter%4 < 2 else -1)
		m.pending_type = -1
		var before: int = m.kills
		for tick_index in range(400):
			tick(m)
			for corpse in corpses(m):
				corpse.set_physics_process(false)
				corpse._physics_process(DT)
			if m.kills > before: break
		check(m.kills == before+1 and not player.is_dead and m.active_threats.is_empty(),"corpse does not block scoring or scheduler")
		check(corpses(m).size() == 1,"one corpse per defeated enemy")
		var score: int = m.score
		for corpse in corpses(m): corpse._physics_process(0.5)
		await process_frame
		check(corpses(m).is_empty() and m.score == score,"corpse cleaned without further reward")
		player.advance_tick(1.0)
	m.free()
	await process_frame
	m = live()
	m.set_physics_process(false)
	var actor = m.active_threats[0].actor
	force_first(m,0,1)
	actor = m.active_threats[0].actor
	actor.receive_hit()
	m.active_threats.clear()
	await process_frame
	var corpse = corpses(m)[0]
	paused = true
	var before: float = corpse.elapsed
	await create_timer(0.25,true).timeout
	check(corpse.elapsed == before,"native pause freezes corpse timer")
	paused = false
	await create_timer(0.55,true).timeout
	check(corpses(m).is_empty(),"corpse resumes then removes itself")
	m.free()
	await create_timer(0.5,true).timeout
	print("COMBAT ART checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
