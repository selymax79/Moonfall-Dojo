extends "res://scheduler_verify.gd"
func _initialize(): late_checks.call_deferred()
func late_checks():
	# [Level, base speed, spawn gap, assassin wind-up]: 105 at 15-19, then +1 per Level from 110 at
	# Level 20 to the 140 ceiling at 50; wind-up shortens 0.01 per Level from 40 to 0.25 at 49.
	for row in [[14,100.0,0.35,0.35],[15,105.0,0.20,0.35],[19,105.0,0.20,0.35],[20,110.0,0.10,0.35],[21,111.0,0.10,0.35],
			[29,119.0,0.10,0.35],[30,120.0,0.0,0.35],[39,129.0,0.0,0.35],[40,130.0,0.0,0.34],[48,138.0,0.0,0.26],
			[49,139.0,0.0,0.25],[50,140.0,0.0,0.25],[60,140.0,0.0,0.25],[1000,140.0,0.0,0.25]]:
		var m=fresh(row[0])
		check(m.level==row[0] and m.get_multiplier_half_units()==2,"late start Level x1")
		check(is_equal_approx(m.get_spawn_speed(0),row[1]),"late speed curve Level %d" % row[0])
		check(is_equal_approx(m.get_spawn_gap(),row[2]),"late gap band Level %d" % row[0])
		check(is_equal_approx(m.get_windup_duration(),row[3]),"late wind-up Level %d" % row[0])
		m.free()
		await process_frame
	for level_value in [15,20,30,40,50]:
		var m=fresh(level_value)
		check(m.level==level_value and m.get_multiplier_half_units()==2,"higher start x1")
		var base: float=105.0 if level_value==15 else minf(110.0+(level_value-20),140.0)
		for kind in range(4):
			force_first(m,kind,-1)
			var expected: float=base*(1.15 if kind==2 else (1.25 if kind==3 else 1.0))
			check(is_equal_approx(m.active_threats[0].actor.movement_speed,expected),"first spawn correct higher-start speed")
			if kind<2: check(is_equal_approx(m.active_threats[0].actor.windup_duration,m.get_windup_duration()),"assassin receives Level wind-up")
		m.free()
		await process_frame
	var pairs: int=0
	for level_value in [15,20,30,40,50]:
		for a in range(4):
			for b in range(4):
				for sa in [-1,1]:
					for sb in [-1,1]:
						var m=fresh(level_value)
						force_first(m,a,sa)
						var first_id: int=m.active_threats[0].actor.get_instance_id()
						m.pending_type=b
						m.pending_side=sb
						var appeared: bool=false
						for frame in range(900):
							tick(m)
							for record in m.active_threats:
								if record.actor.get_instance_id()!=first_id:
									appeared=true
									check(record.type==b and record.actor.entry_side==sb,"late pending retains type/side")
									m.pending_type=-1
							if m.player.is_dead or m.kills+m.dodges==2: break
						check(appeared and not m.player.is_dead and m.kills+m.dodges==2,"late pair survivable without starvation")
						pairs+=1
						m.free()
						await process_frame
	await create_timer(0.25).timeout
	print("LATE pairs=",pairs," checks=",checks," failures=",failures," minimum_margin=",minimum_pair_margin)
	quit(0 if failures.is_empty() else 1)
