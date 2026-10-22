extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures.append(label)
func run():
	# Load the freshly generated atlas directly, without depending on an editor import cache.
	var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://art/combat/barrel.png"))
	var texture := ImageTexture.create_from_image(atlas)
	texture.take_over_path("res://art/combat/barrel.png")
	check(atlas.get_size() == Vector2i(160,20),"eight native frames")
	for frame in range(8):
		var centre := Vector2.ZERO
		var count: int = 0
		for y in range(20):
			for x in range(20):
				if atlas.get_pixel(frame*20+x,y).is_equal_approx(Color("e4b571")):
					centre+=Vector2(x+0.5-10,y+0.5-10)
					count+=1
		check(count > 0,"visible off-centre plug")
		if count > 0: check((centre/count).distance_to(Vector2(0,-4).rotated(frame*PI/4)) < 0.6,"clockwise authored pose")
	var main = load("res://scenes/main.tscn").instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.start_in_run = true
	main.records = load("res://scripts/run_records.gd").new()
	root.add_child(main)
	for r in main.active_threats: r.actor.free()
	main.active_threats.clear()
	main.pending_type = -1
	main.get_node("Environment").set_physics_process(false)
	root.size = Vector2i(640,360)
	root.content_scale_size = Vector2i(640,360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	for side in [-1,1]:
		var b = load("res://scenes/barrel.tscn").instantiate()
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.configure_entry(side)
		b.position = Vector2(320+side*90,300)
		b.movement_speed=69
		main.add_child(b)
		var art = b.get_node("Art")
		for step in range(9):
			art.update_pose()
			check(art.frame == posmod(-side*step,8),"side-correct full rolling cycle")
			check(is_zero_approx(b.body_shape.global_rotation) and b.body_shape.shape.radius == 9,"stable collision")
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://renders/orientation_%d_%d.png"%[side,step])
			b.roll(9*PI/4/69)
		b.free()
	main.free()
	await create_timer(0.25).timeout
	print("ORIENTATION checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
