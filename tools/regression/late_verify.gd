extends "res://scheduler_verify.gd"
func _initialize(): late_checks.call_deferred()
func late_checks():
	# [last Level of a tier, its base speed, next tier's base speed, next tier's gap]
	for band in [[14,100.0,105.0,0.2],[19,105.0,110.0,0.1],[29,110.0,110.0,0.0]]:
		for offset in [0,1]:
			var m=fresh(band[0]+offset)
			check(m.level==band[0]+offset and m.get_multiplier_half_units()==2,"late start Level x1")
			check(is_equal_approx(m.get_spawn_speed(0),band[1+offset]),"late tier boundary speed")
			if offset==1: check(is_equal_approx(m.get_spawn_gap(),band[3]),"late tier boundary gap")
			m.free()
			await process_frame
	for level_value in [15,20,30,40,50]:
		var m=fresh(level_value)
		check(m.level==level_value and m.get_multiplier_half_units()==2,"higher start x1")
		for kind in range(4):
			force_first(m,kind,-1)
			var expected: float=(105.0 if level_value==15 else 110.0)*(1.15 if kind==2 else (1.25 if kind==3 else 1.0))
			check(is_equal_approx(m.active_threats[0].actor.movement_speed,expected),"first spawn correct higher-start speed")
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
