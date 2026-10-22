extends "res://pattern_verify.gd"
func _initialize(): render_patterns.call_deferred()
func render_patterns():
	DirAccess.make_dir_recursive_absolute("res://pattern_renders")
	root.size = Vector2i(640,360)
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	for config in [[5,0,-1],[6,1,1],[10,4,-1],[20,7,1]]:
		var m = fixed(config[0],31)
		for r in m.active_threats: r.actor.free()
		m.active_threats.clear()
		m.cancel_pending_spawn()
		m.pattern_id = config[1]
		m.pattern_start_side = config[2]
		m.select_pending_threat()
		m.next_spawn_at = 0
		m.try_spawn_pending_threat()
		var first: int = m.active_threats[0].actor.get_instance_id()
		var second: bool = false
		var delay: float = 0.0
		var capture: int = 0
		for frame in range(900):
			if fairness_wait(m): delay += DT
			tick(m)
			for r in m.active_threats:
				if r.actor.get_instance_id() != first:
					if not second: print("RENDER_TRACE level=",config[0]," second_at=",m.encounter_time," delayed=",delay," unresolved=",m.active_threats.size())
					second = true
					m.pending_type = -1
			for art in m.find_children("Art","Node2D",true,false): art.update_pose()
			if frame%3 == 0: await process_frame
			if (m.active_threats.size() == 2 and capture == 0) or frame in [100,160,240,330]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://pattern_renders/level_%d_%03d.png"%[config[0],frame])
				capture += 1
			if m.player.is_dead or m.kills+m.dodges == 2: break
		check(second and not m.player.is_dead and m.kills+m.dodges == 2,"rendered pattern survives")
		m.free()
		await process_frame
	print("PATTERN_RENDER failures=",failures)
	await create_timer(0.25,true).timeout
	quit(0 if failures.is_empty() else 1)
