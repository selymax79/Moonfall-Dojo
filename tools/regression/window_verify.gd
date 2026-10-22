extends SceneTree
const P = preload("res://scenes/player.tscn")
const B = preload("res://scenes/barrel.tscn")
func _initialize(): run.call_deferred()
func trial(speed: float, radius: float, press_time: float, dt: float, side: int = 1, facing: int = 1) -> bool:
	var p = P.instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.position = Vector2(320,300)
	p.target_direction = facing
	var b = B.instantiate()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(b)
	b.configure_entry(side)
	b.movement_speed = speed
	b.position = Vector2(320+side*speed,300)
	b.body_shape.shape = b.body_shape.shape.duplicate()
	b.body_shape.shape.radius = radius
	b.body_shape.position.y = -radius
	var now: float = 0
	var pressed: bool = false
	while now < 1.8 and not p.is_dead and not b.is_complete:
		if not pressed and now+0.0000001 >= press_time:
			p.start_action(p.Action.JUMP)
			pressed = true
		p.advance_tick(dt)
		b.advance_tick(dt)
		b.resolve_contact(p)
		now += dt
	var ok: bool = b.is_complete and not p.is_dead
	p.free()
	b.free()
	return ok
func run():
	var sample = P.instantiate()
	print("DURATION ",sample.JUMP_DURATION)
	sample.free()
	for radius in [7.0,9.0]:
		for base in [60.0,80.0,100.0]:
			var speed: float = base*(1.15 if radius == 9 else 1.0)
			var lo: float = 0.0
			var mid: float = 1.0 - load("res://scripts/player.gd").JUMP_DURATION/2.0
			var hi: float = mid
			for i in range(14):
				var v: float = (lo+hi)/2
				if trial(speed,radius,v,0.001): hi=v
				else: lo=v
			var first: float = hi
			lo = mid
			hi = 1.1
			for i in range(14):
				var v: float = (lo+hi)/2
				if trial(speed,radius,v,0.001): lo=v
				else: hi=v
			print("WINDOW r=",radius," speed=",speed," first=",first," last=",lo," width_ms=",(lo-first)*1000)
			var first_tick: int = -1
			var last_tick: int = -1
			for tick in range(65):
				if trial(speed,radius,tick/60.0,1.0/60):
					if first_tick < 0: first_tick=tick
					last_tick=tick
			print("60HZ ",first_tick,"..",last_tick," width_ms=",(last_tick-first_tick)*1000.0/60)
	quit()
