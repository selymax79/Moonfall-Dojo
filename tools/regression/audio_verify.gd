extends "res://features_verify.gd"
const AUDIO_SPY = preload("res://audio_spy.gd")
func _initialize(): audio_run.call_deferred()
func audio_fixture(run_mode: bool = true, start_level: int = 1):
	var m = MAIN.instantiate()
	m.get_node("Audio").set_script(AUDIO_SPY)
	m.start_in_run = run_mode
	m.run_start_level = start_level
	m.selected_start_level = start_level
	m.records = Records.new()
	m.records.highest_level = 1000000
	for slot in range(10): m.records.entries.append({"initials":"AAA","score":1000000000})
	m.encounter_rng.seed = 2626
	root.add_child(m)
	m.set_physics_process(false)
	current_scene = m
	return m
func audio_run():
	root.child_entered_tree.connect(freeze_created)
	var m = audio_fixture(false)
	var a = m.game_audio
	check(AudioServer.get_bus_count() == 3,"Master Music SFX only")
	check(a.get_child_count() == 9 and a.music.bus == "Music","fixed voices and Music route")
	for voice in a.get_children():
		if voice != a.music: check(voice.bus == "SFX","all cues route SFX")
	check(a.music_starts == ["title"] and a.music.playing,"one title start")
	for row in [2,3,4]:
		m.menu_selection = row
		tap(KEY_ENTER)
		await create_timer(0.08,true).timeout
		tap(KEY_ESCAPE)
	check(a.music_starts == ["title"],"submenus preserve music")
	check(a.count("menu_confirm") == 6,"confirm once per destination/back")
	tap(KEY_DOWN)
	check(a.count("menu_move") == 1,"menu move once")
	m.menu_selection = 4
	tap(KEY_ENTER)
	check(m.get_node("HUD/OptionsOverlay/MusicVolume").text == "> Music Volume  70 <","options defaults")
	var rng_state: int = m.encounter_rng.state
	for index in range(30): tap(KEY_LEFT)
	check(m.records.music_volume == 0 and AudioServer.is_bus_mute(1),"music zero muted")
	for index in range(30): tap(KEY_RIGHT)
	check(m.records.music_volume == 100 and is_zero_approx(AudioServer.get_bus_volume_db(1)) and not AudioServer.is_bus_mute(1),"music100 reference")
	tap(KEY_DOWN)
	for index in range(30): tap(KEY_LEFT)
	check(m.records.sfx_volume == 0 and AudioServer.is_bus_mute(2),"SFX zero muted")
	for index in range(30): tap(KEY_RIGHT)
	check(m.records.sfx_volume == 100 and is_zero_approx(AudioServer.get_bus_volume_db(2)),"SFX100 reference")
	var reopened = Records.new()
	reopened.load_records()
	check(reopened.music_volume == 100 and reopened.sfx_volume == 100 and reopened.entries == m.records.entries and reopened.highest_level == 1000000,"settings preserve records")
	check(m.encounter_rng.state == rng_state and m.encounter_time == 0 and m.player.current_action == 0,"options no RNG physics input leak")
	m.free()
	await process_frame
	m = audio_fixture()
	a = m.game_audio
	check(a.current_music == "gameplay" and a.music_starts == ["gameplay"],"initial run track")
	# Accepted Player actions each trigger once; rejected committed/echo/release inputs do not.
	for pair in [[KEY_Z,"punch"],[KEY_X,"kick"],[KEY_UP,"jump"],[KEY_DOWN,"duck"]]:
		var before: int = a.count(pair[1])
		tap(pair[0])
		tap(pair[0],true)
		tap(pair[0])
		check(a.count(pair[1]) == before+1,"accepted action single cue "+pair[1])
		m.player.advance_tick(1.0)
	# Exact live playhead freeze, with an always-playing UI tone.
	tap(KEY_Z)
	await create_timer(0.03,true).timeout
	tap(KEY_P)
	await process_frame
	var music_at: float = a.music.get_playback_position()
	var punch_at: float = a.get_node("Player").get_playback_position()
	check(a.music.stream_paused and a.get_node("Player").stream_paused,"native gameplay voices paused")
	check(a.get_node("UI").playing and not a.get_node("UI").stream_paused,"pause cue remains audible")
	await create_timer(0.4,true).timeout
	var settled_music: float = a.music.get_playback_position()
	var settled_punch: float = a.get_node("Player").get_playback_position()
	check(settled_music-music_at >= 0 and settled_music-music_at < 0.025 and settled_punch-punch_at >= 0 and settled_punch-punch_at < 0.025,"pause drains at most one native mixer buffer")
	await create_timer(0.4,true).timeout
	check(is_equal_approx(a.music.get_playback_position(),settled_music) and is_equal_approx(a.get_node("Player").get_playback_position(),settled_punch),"settled paused playheads remain exact")
	print("PAUSE buffer_tail_ms=", (settled_music-music_at)*1000.0, " then no drift")
	check(a.music_starts == ["gameplay"],"pause does not restart loop")
	tap(KEY_P)
	await create_timer(0.12,true).timeout
	check(a.music.get_playback_position() > music_at and a.music_starts == ["gameplay"],"resume continues playhead")
	m.free()
	await process_frame
	# Each threat uses natural attack/lifecycle transitions; victory sounds require real spatial hits.
	for kind in range(4):
		for side in [-1,1]:
			m = audio_fixture()
			a = m.game_audio
			force_first(m,kind,side)
			a.events.clear()
			if kind < 2:
				for frame in range(400):
					tick(m)
					if m.kills == 1 or m.player.is_dead: break
				check(not m.player.is_dead and m.kills == 1,"audio real Assassin success")
				check(a.count("red_attack" if kind == 0 else "blue_attack") == 1,"one strike cue")
				check(a.count("red_defeated" if kind == 0 else "blue_defeated") == 1,"one real defeat cue")
			else:
				var actor = m.active_threats[0].actor
				m.pending_type = -1
				check(a.hazard_owners.has(actor.get_instance_id()),"hazard assigned loop")
				for frame in range(450):
					tick(m)
					if actor.is_complete: break
				check(not m.player.is_dead and m.dodges == 1,"audio real hazard passage")
				check(not a.hazard_owners.has(actor.get_instance_id()),"loop stops at resolution")
				var ledger := [m.score,m.kills,m.dodges]
				for frame in range(100):
					if actor.is_queued_for_deletion(): break
					actor._physics_process(DT)
				check(a.count("barrel_explosion" if kind == 2 else "shuriken_impact") == 1,"one cosmetic transition sound")
				check([m.score,m.kills,m.dodges] == ledger,"cosmetic sound no extra reward")
			m.free()
			await process_frame
	# Natural lethal hits: death priority immediate, sting once after the same death duration.
	for kind in range(4):
		m = audio_fixture()
		a = m.game_audio
		force_first(m,kind,1)
		for frame in range(400):
			m._physics_process(DT)
			if m.player.is_dead: break
		check(a.count("player_death") == 1 and not a.music.playing and a.hazard_owners == [0,0],"death stops music/loops immediately")
		for frame in range(90): m._physics_process(DT)
		check(a.count("game_over") == 1,"Game Over sting exactly once")
		m.free()
		await process_frame
	m = audio_fixture()
	a = m.game_audio
	for index in range(4): m.award_successful_threat(index)
	check(a.count("level_up") == 1,"earned Level cue at four")
	m.records.entries.clear()
	m.player.receive_hit()
	m._physics_process(0.4)
	for character in ["a","b","c"]: type_character(character)
	tap(KEY_ENTER)
	check(a.count("high_score") == 1 and m.game_state == m.GameState.HIGH_SCORES,"initials confirmation audio once")
	tap(KEY_ENTER)
	check(a.current_music == "title" and a.music_starts == ["gameplay","title"],"return Title restarts title music")
	m.free()
	await process_frame
	# Repeated higher-level Game Over restarts have one music player, no orphan nodes.
	m = audio_fixture(true,7)
	await process_frame
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for index in range(16):
		m.player.receive_hit()
		m._physics_process(0.4)
		m = await restarted(m,KEY_ENTER)
		check(not paused and m.level == 7 and m.game_audio.current_music == "gameplay" and m.game_audio.get_child_count() == 9,"restart fixed voices same start7")
		check(root.get_child_count() == 1,"no old run audio nodes")
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_before,"no accumulating orphans")
	m.free()
	await create_timer(0.25,true).timeout
	print("AUDIO checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
