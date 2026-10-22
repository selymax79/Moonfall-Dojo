extends "res://features_verify.gd"
func _initialize(): capture.call_deferred()
func capture():
	root.size = Vector2i(640,360)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute("res://polish_renders")
	for config in [["ready",0,0.0],["punch",1,0.08],["punch_recovery",1,0.22],["kick",2,0.12],["kick_recovery",2,0.31],["jump",4,0.41],["duck",3,0.15],["turn",0,0.05]]:
		var m = fresh()
		for r in m.active_threats: r.actor.free()
		m.active_threats.clear()
		if config[0] == "turn": m.player.target_direction = -1
		if config[1] != 0: m.player.start_action(config[1])
		m.player.advance_tick(config[2])
		m.player.get_node("Art").update_pose()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://polish_renders/"+config[0]+".png")
		m.free()
		await process_frame
	for kind in [0,1]:
		for side in [-1,1]:
			var m = fresh()
			force_first(m,kind,side)
			var target = m.active_threats[0].actor
			var captured: Dictionary = {}
			for tick_index in 500:
				target.advance_tick(DT,m.player.position.x,false)
				target.get_node("Art").update_pose()
				if not captured.has(target.phase) and target.phase_elapsed > 0.08:
					captured[target.phase] = true
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://polish_renders/enemy_%d_%d_%d.png"%[kind,side,target.phase])
				if captured.size() >= 4: break
			m.free()
			await process_frame
	var menu = menu_fixture()
	menu.game_state = menu.GameState.CONTROLS
	menu.update_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://polish_renders/controls.png")
	menu.free()
	await create_timer(0.3).timeout
	print("POLISH_RENDER complete")
	quit()
