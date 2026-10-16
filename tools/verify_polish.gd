## Asset/pose checks only. Run in the isolated Input Verification project, never the real save.
## This verifies technical constraints, not human art or listening acceptance.
extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	if ProjectSettings.get_setting("application/config/name") != "Moonfall Dojo Input Verification":
		quit(2)
		return
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	for name in ["player", "red", "blue"]:
		var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://art/combat/"+name+".png"))
		check(atlas.get_size() == Vector2i(768,224), name+" retains atlas geometry")
		for frame in 32:
			var tile := atlas.get_region(Rect2i(frame%8*96,floori(frame/8.0)*56,96,56))
			var used := tile.get_used_rect()
			check(used.has_area() and used.position.y >= 6 and used.end.y <= 49, name+" vertical footprint "+str(frame))
			check(used.position.x >= 10 and used.end.x <= 76, name+" horizontal footprint "+str(frame))
		if name == "player":
			var punch := atlas.get_region(Rect2i(5*96,0,96,56))
			var kick := atlas.get_region(Rect2i(96,56,96,56))
			check(punch.get_used_rect().end.x <= 65, "active punch never exceeds x=25")
			check(kick.get_used_rect().end.x <= 76, "active kick never exceeds x=36")
			check(punch.get_pixel(64,24).a > 0, "punch knuckle inside existing active region")
			check(kick.get_pixel(75,16).a > 0, "kick sole inside existing active region")
	var bindings = load("res://scripts/control_bindings.gd").new()
	for pair in [["punch","Face Down"],["kick","Face Right"],["jump","Face Up"],["duck","Face Left"]]:
		check(bindings.binding_text(pair[0],"pad") == pair[1], "face-button wording "+pair[0])
	var main = load("res://scenes/main.tscn").instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.start_in_run = true
	main.records = load("res://scripts/run_records.gd").new()
	root.add_child(main)
	var player = main.player
	var art = player.get_node("Art")
	# Sample every millisecond in both directions: presentation must leave all gameplay state intact.
	for side in [-1,1]:
		for action in [player.Action.PUNCH,player.Action.KICK,player.Action.JUMP,player.Action.DUCK]:
			player.advance_tick(2.0)
			player.target_direction = side
			player.start_action(action)
			for tick in 850:
				player.advance_tick(0.001)
				var before: Array = [player.position, player.hurtbox.transform, player.hurtbox.shape.size,
					player.punch_shape.transform, player.kick_shape.transform, player.current_action,
					player.action_elapsed, main.encounter_rng.state, main.score]
				art.update_pose()
				check(before == [player.position, player.hurtbox.transform, player.hurtbox.shape.size,
					player.punch_shape.transform, player.kick_shape.transform, player.current_action,
					player.action_elapsed, main.encounter_rng.state, main.score], "read-only art")
				if player.current_action == player.Action.PUNCH and player.action_elapsed >= 0.06 and player.action_elapsed < 0.14:
					check(art.frame == 5, "punch active key pose")
				if player.current_action == player.Action.KICK and player.action_elapsed >= 0.08 and player.action_elapsed < 0.24:
					check(art.frame == 9, "kick active key pose")
	main.free()
	await create_timer(0.25).timeout
	print("POLISH checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
