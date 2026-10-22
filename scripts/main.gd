## Schedules up to two unresolved threats with separate response/recovery reservations.
## Main owns gameplay; resolved hazards run their harmless cosmetic aftermath independently.
extends Node2D

# RUN includes death and non-qualifying Game Over; pause remains a SceneTree concern.
enum GameState { TITLE, CONTROLS, OPTIONS, HIGH_SCORES, INITIALS_ENTRY, RUN }
var game_state: GameState = GameState.TITLE
var menu_selection: int = 0
var options_selection: int = 0
var selected_start_level: int = 1
var initials: String = ""
var initial_choice: int = 0
var initial_picker_active: bool = false
const INITIAL_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
# Session-only preference; touch browsers enable it on first startup.
@export var touch_controls_enabled: bool = false
var platform_initialized: bool = false
var audio_activated: bool = not OS.has_feature("web")
# Shared across fresh Main instances so saves load once and a failed write does not lose session data.
var records
var result_checked: bool = false
# Set before entering the tree by the shared start/restart path. Application startup keeps Title.
var start_in_run: bool = false
var play_start_cue: bool = false
var run_change_pending: bool = false

enum ThreatType { RED, BLUE, BARREL, SHURIKEN }
# Two-step requests, always START side then OPPOSITE. Every unlocked pool balances all four types.
# Order groups unlocks: first 2 at Level 4, first 4 at Level 7, all 8 at Level 10.
const ENCOUNTER_PATTERNS = [
	[ThreatType.RED, ThreatType.BLUE],
	[ThreatType.BARREL, ThreatType.SHURIKEN],
	[ThreatType.BLUE, ThreatType.RED],
	[ThreatType.SHURIKEN, ThreatType.BARREL],
	[ThreatType.RED, ThreatType.SHURIKEN],
	[ThreatType.BLUE, ThreatType.BARREL],
	[ThreatType.BARREL, ThreatType.RED],
	[ThreatType.SHURIKEN, ThreatType.BLUE],
]
const THREAT_SCENES = [preload("res://scenes/red_assassin.tscn"), preload("res://scenes/blue_assassin.tscn"), preload("res://scenes/barrel.tscn"), preload("res://scenes/shuriken.tscn")]
const THREAT_START_POSITION := Vector2(560, 300)
const BASE_APPROACH_SPEED: float = 60.0
const APPROACH_SPEED_PER_LEVEL: float = 5.0
# Preserve the teaching/mid-game curve through Level 14; later steps shorten recognition time.
# Larger late speeds reduced overlap in simulations by exhausting the same fair response slots.
const EARLY_APPROACH_SPEED_CAP: float = 100.0
const EXPERIENCED_APPROACH_SPEED: float = 105.0 # Level 15–19.
const ENDURANCE_APPROACH_SPEED: float = 110.0 # Level 20+; bounded, never an inevitable-death ramp.
# Barrel retains its slight speed premium over each Level's base speed.
const BARREL_SPEED_MULTIPLIER: float = 1.15
# Pacing never overrides the timing checks. Overlap is a Level 6 difficulty choice, not a safety exemption.
const OVERLAP_START_LEVEL: int = 6
const FAIRNESS_MARGIN: float = 0.10
const ASSASSIN_TURN_ALLOWANCE: float = 0.10
# Intended responses in ThreatType order: Kick, Punch, Jump, Duck.
const RESPONSE_DURATIONS = [0.40, 0.30, 0.82, 0.60]
# Player.Action order: NONE, PUNCH, KICK, DUCK, JUMP. Keep aligned with Player's fixed timings.
const PLAYER_ACTION_DURATIONS = [0.0, 0.30, 0.40, 0.60, 0.82]
const POINTS_PER_THREAT: int = 100
const HANDLED_THREATS_PER_LEVEL: int = 4
var high_score: int:
	get: return records.get_high_score() if records != null else 0
var score: int = 0
var kills: int = 0
var dodges: int = 0
# Supplied before _ready() by Start/Restart; progression stays relative to the chosen run.
var run_start_level: int = 1
var level: int = 1
# Each record contains actor, type, absolute response times and pattern provenance for tracing.
# Only unresolved gameplay belongs here; at most two records keeps ownership explicit.
var active_threats: Array[Dictionary] = []
var encounter_time: float = 0.0
var next_spawn_at: float = 0.0
var pending_type: int = -1
var pending_side: int = 0
# The current pending slot belongs to this step; advance only when it is actually admitted.
# No parallel spawn queue: a pattern stores intent, while the existing fairness gate owns timing.
var pattern_id: int = -1
var pattern_step: int = 0
var pattern_start_side: int = 0
var encounter_rng := RandomNumberGenerator.new()

@onready var player = $Player
@onready var game_audio = $Audio
@onready var high_score_label: Label = $HUD/RunStats/HighScoreLabel
@onready var score_label: Label = $HUD/RunStats/ScoreLabel
@onready var kills_label: Label = $HUD/RunStats/KillsLabel
@onready var dodges_label: Label = $HUD/RunStats/DodgesLabel
@onready var level_label: Label = $HUD/RunStats/LevelLabel
@onready var multiplier_label: Label = $HUD/RunStats/MultiplierLabel
@onready var game_over_overlay: Control = $HUD/GameOverOverlay
@onready var pause_overlay: Control = $HUD/PauseOverlay
@onready var run_stats = $HUD/RunStats
@onready var title_overlay: Control = $HUD/TitleOverlay
@onready var title_high_score: Label = $HUD/TitleOverlay/HighScoreLabel
@onready var controls_overlay = $HUD/ControlsOverlay
@onready var touch_overlay = $HUD/TouchOverlay
@onready var options_overlay: Control = $HUD/OptionsOverlay
@onready var high_scores_overlay: Control = $HUD/HighScoresOverlay
@onready var initials_overlay: Control = $HUD/InitialsOverlay
@onready var web_platform = $WebPlatform
@onready var menu_pointer = $HUD/MenuPointer


## Randomise before entering the tree so tests can override the seed before the first spawn.
func _init() -> void:
	encounter_rng.randomize()


## Startup reads persistence but makes no gameplay RNG draws until a run is explicitly started.
func _ready() -> void:
	if not platform_initialized:
		touch_controls_enabled = touch_controls_enabled or web_platform.touch_browser
		platform_initialized = true
	web_platform.suspend_requested.connect(suspend_browser)
	web_platform.availability_changed.connect(game_audio.set_browser_suspended)
	menu_pointer.main = self
	game_audio.activated = audio_activated
	if records == null:
		records = preload("res://scripts/run_records.gd").new()
		records.load_records()
	records.controls.apply()
	controls_overlay.records = records
	controls_overlay.overlay_enabled = touch_controls_enabled
	controls_overlay.back_requested.connect(return_from_controls)
	controls_overlay.feedback.connect(game_audio.play_ui)
	controls_overlay.overlay_changed.connect(func(enabled: bool): touch_controls_enabled = enabled)
	Input.joy_connection_changed.connect(controller_connection_changed)
	player.died.connect(update_touch_controls)
	selected_start_level = clampi(selected_start_level, 1, records.highest_level)
	run_start_level = clampi(run_start_level, 1, records.highest_level)
	recalculate_level()
	update_hud()
	game_audio.apply_volumes(records.music_volume, records.sfx_volume)
	player.action_started.connect(game_audio.play_action)
	player.died.connect(game_audio.begin_death)
	if start_in_run:
		game_state = GameState.RUN
		game_audio.play_music("gameplay")
		if play_start_cue:
			game_audio.play_ui("menu_confirm")
		select_pending_threat()
		try_spawn_pending_threat()
	else:
		# Hidden Player must not receive menu arrow keys or accumulate committed actions.
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.hide()
		game_audio.play_music("title")
	update_menu()
	# Containers finish laying out title rows after _ready; pointer targets use their final rectangles.
	menu_pointer.refresh.call_deferred()
	if web_platform.unavailable: suspend_browser()
	game_audio.set_browser_suspended(web_platform.unavailable)


## Visibility and selection have no effect on gameplay clocks or RNG.
func update_menu() -> void:
	update_touch_controls()
	$Environment.set_active(game_state == GameState.RUN)
	title_overlay.visible = game_state == GameState.TITLE
	controls_overlay.visible = game_state == GameState.CONTROLS
	options_overlay.visible = game_state == GameState.OPTIONS
	high_scores_overlay.visible = game_state == GameState.HIGH_SCORES
	initials_overlay.visible = game_state == GameState.INITIALS_ENTRY
	run_stats.visible = game_state == GameState.RUN or game_state == GameState.INITIALS_ENTRY
	title_high_score.text = "High Score %06d" % high_score
	var choices: Array[String] = ["START GAME", "START LEVEL  %d" % selected_start_level, "HIGH SCORES", "CONTROLS", "OPTIONS"]
	for index in range(choices.size()):
		$HUD/TitleOverlay/MenuContainer.get_child(index).text = "> %s <" % choices[index] if menu_selection == index else choices[index]
	$HUD/TitleOverlay/UnlockHint.text = "Highest unlocked: %d  |  Left / Right adjusts Start Level" % records.highest_level
	var ranks := ""
	var names := ""
	var scores := ""
	for index in range(records.TABLE_SIZE):
		var entry: Dictionary = records.entries[index] if index < records.entries.size() else {"initials": "---", "score": 0}
		ranks += "%2d.\n" % (index + 1)
		names += "%s\n" % entry.initials
		scores += "%06d\n" % entry.score
	$HUD/HighScoresOverlay/Ranks.text = ranks.trim_suffix("\n")
	$HUD/HighScoresOverlay/Initials.text = names.trim_suffix("\n")
	$HUD/HighScoresOverlay/Scores.text = scores.trim_suffix("\n")
	$HUD/InitialsOverlay/InitialsLabel.text = " ".join((initials + "___").substr(0, 3).split(""))
	$HUD/OptionsOverlay/MusicVolume.text = ("> Music Volume  %d <" if options_selection == 0 else "Music Volume  %d") % records.music_volume
	$HUD/OptionsOverlay/SFXVolume.text = ("> SFX Volume  %d <" if options_selection == 1 else "SFX Volume  %d") % records.sfx_volume
	var accept_hint: String = records.controls.binding_text("menu_accept", "key") + " / " + records.controls.binding_text("menu_accept", "pad")
	var cancel_hint: String = records.controls.binding_text("menu_back", "key") + " / " + records.controls.binding_text("menu_back", "pad")
	$HUD/TitleOverlay/NavigationHint.text = "Directions to choose | %s to select" % accept_hint
	$HUD/TitleOverlay/UnlockHint.text = "Highest unlocked: %d | Menu Left / Right adjusts Start Level" % records.highest_level
	$HUD/OptionsOverlay/ReturnHint.text = "%s to return" % cancel_hint
	$HUD/HighScoresOverlay/ReturnHint.text = "%s to return to Title" % cancel_hint
	$HUD/InitialsOverlay/EntryHint.text = "Type A-Z / 0-9, or directions choose [%s]\nAccept adds / submits | Cancel erases" % INITIAL_CHARACTERS[initial_choice]
	$HUD/GameOverOverlay/RestartHint.text = (accept_hint + " TO RESTART").to_upper()
	$HUD/PauseOverlay/ResumeHint.text = (records.controls.binding_text("pause_game", "key") + " / " + records.controls.binding_text("pause_game", "pad") + " TO RESUME").to_upper()
	if touch_controls_enabled:
		$HUD/GameOverOverlay/RestartHint.text = "TAP HERE TO RESTART"
		$HUD/PauseOverlay/ResumeHint.text = "TAP HERE TO RESUME"
	controls_overlay.queue_redraw()
	# Pointer buttons replace hints only where they occupy the same space.
	$HUD/OptionsOverlay/ReturnHint.hide()
	$HUD/HighScoresOverlay/ReturnHint.hide()
	$HUD/InitialsOverlay/EntryHint.hide()
	menu_pointer.refresh()


## Explicit destinations keep navigation separate from gameplay input and RNG.
func return_from_controls() -> void:
	game_state = GameState.TITLE
	game_audio.play_ui("menu_confirm")


func handle_menu_input(event: InputEvent) -> void:
	if game_state == GameState.INITIALS_ENTRY:
		handle_initials_input(event)
	elif game_state == GameState.CONTROLS:
		controls_overlay.handle_input(event)
	elif game_state == GameState.OPTIONS:
		handle_options_input(event)
	elif game_state != GameState.TITLE:
		if event.is_action_pressed("menu_back") or event.is_action_pressed("menu_accept"):
			game_state = GameState.TITLE
			game_audio.play_ui("menu_confirm")
			game_audio.play_music("title")
	elif event.is_action_pressed("menu_up"):
		menu_selection = posmod(menu_selection - 1, 5)
		game_audio.play_ui("menu_move")
	elif event.is_action_pressed("menu_down"):
		menu_selection = (menu_selection + 1) % 5
		game_audio.play_ui("menu_move")
	elif menu_selection == 1 and event.is_action_pressed("menu_left"):
		if selected_start_level > 1:
			game_audio.play_ui("menu_move")
		selected_start_level = maxi(1, selected_start_level - 1)
	elif menu_selection == 1 and event.is_action_pressed("menu_right"):
		# Check before adding so even an extreme edited integer cannot overflow the selector.
		if selected_start_level < records.highest_level:
			selected_start_level += 1
			game_audio.play_ui("menu_move")
	elif event.is_action_pressed("menu_accept"):
		if menu_selection >= 2:
			game_audio.play_ui("menu_confirm")
		match menu_selection:
			0, 1: start_new_run()
			2: game_state = GameState.HIGH_SCORES
			3: game_state = GameState.CONTROLS
			4: game_state = GameState.OPTIONS
	update_menu()


## Settings apply immediately and save only on an actual change; no gameplay input reaches Player.
func handle_options_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back") or event.is_action_pressed("menu_accept"):
		game_state = GameState.TITLE
		game_audio.play_ui("menu_confirm")
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("menu_down"):
		options_selection = 1 - options_selection
		game_audio.play_ui("menu_move")
	elif event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right"):
		var previous: int = records.music_volume if options_selection == 0 else records.sfx_volume
		var step: int = 5 if event.is_action_pressed("menu_right") else -5
		var amount: int = clampi(previous + step, 0, 100)
		if amount != previous:
			records.set_audio_volume(options_selection == 0, amount)
			game_audio.apply_volumes(records.music_volume, records.sfx_volume)
			game_audio.play_ui("menu_move")


## Direct typing remains available; menu directions activate the controller-friendly character picker.
## Accept adds the chosen character, then submits three slots. Typing cancels picker mode.
func handle_initials_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_accept") and initials.length() == 3:
		records.submit_score(initials, score)
		game_audio.play_ui("high_score")
		game_state = GameState.HIGH_SCORES
		update_hud()
	elif event.is_action_pressed("menu_accept") and initial_picker_active:
		initials += INITIAL_CHARACTERS[initial_choice]
		game_audio.play_ui("menu_move")
	elif event.is_action_pressed("menu_back"):
		initials = initials.left(maxi(0, initials.length() - 1))
		if initials.is_empty(): initial_picker_active = false
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("menu_right"):
		initial_choice = (initial_choice + 1) % INITIAL_CHARACTERS.length()
		initial_picker_active = true
	elif event.is_action_pressed("menu_down") or event.is_action_pressed("menu_left"):
		initial_choice = posmod(initial_choice - 1, INITIAL_CHARACTERS.length())
		initial_picker_active = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE:
			if not initials.is_empty():
				game_audio.play_ui("menu_move")
			initials = initials.left(maxi(0, initials.length() - 1))
		elif initials.length() < 3 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			# Navigation/function keys have unicode=0; reject them before constructing a character.
			var code: int = event.unicode
			if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
				initials += String.chr(code).to_upper()
				initial_picker_active = false
				game_audio.play_ui("menu_move")


## Decide once after the death animation. Qualifying runs freeze into an input-only entry screen.
func show_run_result() -> void:
	if result_checked:
		return
	result_checked = true
	game_audio.play_game_over()
	if records.qualifies(score):
		game_state = GameState.INITIALS_ENTRY
		for child in get_children():
			if child is Node2D:
				child.process_mode = Node.PROCESS_MODE_DISABLED
				child.hide()
		update_menu()
	else:
		game_over_overlay.show()
		menu_pointer.refresh()


## Presentation only: fixed status slots, eight-digit minimum scores, no truncation of larger values.
func update_hud() -> void:
	high_score_label.text = "HI %08d" % high_score
	score_label.text = "SCORE %08d" % score
	kills_label.text = "KILLS %d" % kills
	dodges_label.text = "DODGES %d" % dodges
	level_label.text = "LEVEL %d" % level
	var half_units: int = get_multiplier_half_units()
	# Integer quotient and remainder display exact halves with one decimal place.
	@warning_ignore("integer_division")
	multiplier_label.text = "x%d.%d" % [half_units / 2, (half_units % 2) * 5]
	run_stats.fit_values()


## Two half-units mean x1.0; each three Levels survived in this run add a half-unit.
func get_multiplier_half_units() -> int:
	# Truncation intentionally counts only complete groups of three levels.
	@warning_ignore("integer_division")
	return 2 + (level - run_start_level) / 3


## Reward a gameplay success before releasing its unresolved record.
## Score first so a Level-boundary threat still earns the old multiplier; cosmetics never call this.
func award_successful_threat(threat_type: ThreatType) -> void:
	var previous_level: int = level
	var half_units: int = get_multiplier_half_units()
	@warning_ignore("integer_division")
	score += (POINTS_PER_THREAT * half_units) / 2
	if threat_type == ThreatType.BARREL or threat_type == ThreatType.SHURIKEN:
		dodges += 1
	else:
		kills += 1
	recalculate_level()
	if level > previous_level:
		game_audio.play_level_up()
	records.unlock_level(level)
	update_hud()


## Level is always earned: the chosen start plus one per four handled threats (kills + dodges).
func recalculate_level() -> void:
	var handled_threats: int = kills + dodges
	@warning_ignore("integer_division")
	level = run_start_level + handled_threats / HANDLED_THREATS_PER_LEVEL


## Main always processes controls; Player and threat nodes are pausable and receive no paused input.
## Fresh presses prevent a held P key from repeatedly toggling pause.
func _input(event: InputEvent) -> void:
	if web_platform.portrait:
		get_viewport().set_input_as_handled()
		return
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch or event is InputEventMouseButton):
		audio_activated = true
		game_audio.activate()
	if menu_pointer.handle_pointer(event):
		get_viewport().set_input_as_handled()
		return
	if touch_overlay.handle_pointer(event):
		get_viewport().set_input_as_handled()
		return
	# Godot can synthesize mouse events from a touch. Only the pointer adapters own these;
	# forwarding an unrelated move/release into menu refresh would cancel the original tap.
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return
	# Filter at the viewport entry point, before either Main or Player sees physical repeats.
	if not records.controls.fresh(event) or run_change_pending:
		get_viewport().set_input_as_handled()


func controller_connection_changed(device: int, _connected: bool) -> void:
	records.controls.forget_device(device)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		touch_overlay.release_all()
		menu_pointer.held.clear()
		if OS.has_feature("web"): suspend_browser()


## Browser suspension never catches up gameplay on return. Resume is an explicit player action.
func suspend_browser() -> void:
	if not is_node_ready(): return
	touch_overlay.release_all()
	menu_pointer.held.clear()
	records.controls.held.clear()
	if game_state == GameState.RUN: set_game_paused(true)


func update_touch_controls() -> void:
	var mode := 0
	if touch_controls_enabled and game_state == GameState.RUN and not run_change_pending:
		mode = 2 if get_tree().paused or player.is_dead else 1
	touch_overlay.set_mode(mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if game_state != GameState.RUN:
		get_viewport().set_input_as_handled()
		handle_menu_input(event)
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		set_game_paused(not get_tree().paused)
	elif event.is_action_pressed("restart_run") and game_over_overlay.visible and not get_tree().paused:
		get_viewport().set_input_as_handled()
		start_new_run()


## Start Game and Game Over restart both replace the scene, avoiding a second list of reset rules.
func start_new_run() -> void:
	if run_change_pending:
		return
	run_change_pending = true
	update_touch_controls()
	# Replace outside input dispatch; multiple presses in one frame cannot create duplicate runs.
	replace_with_run.call_deferred()


func replace_with_run() -> void:
	var tree := get_tree()
	var next_run = load(scene_file_path).instantiate()
	next_run.start_in_run = true
	next_run.play_start_cue = true
	next_run.records = records
	next_run.touch_controls_enabled = touch_controls_enabled
	next_run.platform_initialized = platform_initialized
	next_run.audio_activated = audio_activated
	next_run.run_start_level = run_start_level if game_state == GameState.RUN else selected_start_level
	next_run.selected_start_level = next_run.run_start_level
	if game_state != GameState.RUN:
		# Menu dwell/navigation must preserve an injected seed and the exact initial RNG state.
		next_run.encounter_rng.seed = encounter_rng.seed
		next_run.encounter_rng.state = encounter_rng.state
	# Configure before _ready(): ordinary scene reload would return to Title instead of a run.
	set_game_paused(false)
	game_audio.stop_all()
	tree.root.remove_child(self)
	tree.root.add_child(next_run)
	tree.current_scene = next_run
	queue_free()


## SceneTree freezes pausable actors (including cosmetic aftermath); HUD remains responsive.
func set_game_paused(paused: bool) -> void:
	var changed: bool = get_tree().paused != paused
	get_tree().paused = paused
	if changed:
		game_audio.set_game_paused(paused)
	pause_overlay.visible = paused
	update_touch_controls()
	# The two centred messages share space; restore Game Over immediately when resuming.
	game_over_overlay.visible = not paused and player.is_dead and player.death_elapsed >= player.DEATH_DURATION
	menu_pointer.refresh()


## Only an empty pending slot can select. Retries, pause and menus never consume these draws.
## Levels 1–3 retain type/side draws. Later: start roll, then pattern ID/orientation OR random type/side.
## Continuing a selected pattern needs no RNG, even if its next step waits through a Level change.
func select_pending_threat() -> void:
	if pending_type >= 0:
		return
	if pattern_id >= 0 and pattern_step >= ENCOUNTER_PATTERNS[pattern_id].size():
		clear_pattern()
	if pattern_id < 0 and level >= 4:
		if encounter_rng.randf() < get_pattern_start_chance():
			pattern_id = encounter_rng.randi_range(0, get_pattern_pool_size() - 1)
			pattern_start_side = 1 if encounter_rng.randi_range(0, 1) == 0 else -1
	if pattern_id >= 0:
		pending_type = ENCOUNTER_PATTERNS[pattern_id][pattern_step]
		pending_side = pattern_start_side if pattern_step == 0 else -pattern_start_side
		return
	pending_type = encounter_rng.randi_range(0, 3)
	pending_side = 1 if encounter_rng.randi_range(0, 1) == 0 else -1


func get_pattern_start_chance() -> float:
	if level < 4: return 0.0
	if level < 6: return 0.10
	if level < 10: return 0.15
	if level < 15: return 0.20
	if level < 20: return 0.22
	return 0.25 # About 40% of threats are patterned; ordinary random threats remain the majority.


func get_pattern_pool_size() -> int:
	if level < 4: return 0
	if level < 7: return 2
	if level < 10: return 4
	return ENCOUNTER_PATTERNS.size()


func clear_pattern() -> void:
	pattern_id = -1
	pattern_step = 0
	pattern_start_side = 0


func get_spawn_gap() -> float:
	if level <= 3: return 0.85
	if level <= 6: return 0.65
	if level <= 9: return 0.45
	if level <= 14: return 0.35
	if level <= 19: return 0.20
	if level <= 29: return 0.10
	# No added breathing gap at mastery Levels; reservations/capacity still gate every admission.
	return 0.0


func get_max_unresolved() -> int:
	return 1 if level < OVERLAP_START_LEVEL else 2


func is_assassin(threat_type: int) -> bool:
	return threat_type == ThreatType.RED or threat_type == ThreatType.BLUE


## Pending choices have no speed yet: a Level-up before spawn must affect the new actor.
func get_spawn_speed(threat_type: int) -> float:
	var base_speed: float = minf(BASE_APPROACH_SPEED + APPROACH_SPEED_PER_LEVEL * (level - 1), EARLY_APPROACH_SPEED_CAP)
	if level >= 20:
		base_speed = ENDURANCE_APPROACH_SPEED
	elif level >= 15:
		base_speed = EXPERIENCED_APPROACH_SPEED
	if threat_type == ThreatType.BARREL:
		return base_speed * BARREL_SPEED_MULTIPLIER
	return base_speed * 1.25 if threat_type == ThreatType.SHURIKEN else base_speed


## First possible contact with standing Player, derived from the existing mirrored geometry.
## Assassin travel includes the moving 0.35 s telegraph; add only the final weapon travel.
func get_lethal_lead(threat_type: int, speed: float) -> float:
	match threat_type:
		ThreatType.RED: return 202.0 / speed + 0.09 # 38 px stop; blade reaches Player 90 ms into strike.
		ThreatType.BLUE: return 210.0 / speed + 0.08 # 30 px stop; fist reaches Player 80 ms into strike.
		ThreatType.BARREL: return 223.0 / speed # 240 px separation minus 8 px Player half-width and radius 9.
		ThreatType.SHURIKEN: return 228.0 / speed # Radius 4; speed already includes the projectile multiplier.
	return 0.0


## Reserve [first contact - response duration, first contact + response duration].
## It contains a valid intended response and its full recovery, not a promise that every press in it wins.
## A new reservation must follow every existing recovery, actual Player availability, turn and margin.
func try_spawn_pending_threat() -> void:
	if game_state != GameState.RUN or player.is_dead or pending_type < 0 or encounter_time < next_spawn_at:
		return
	if active_threats.size() >= get_max_unresolved():
		return
	var ready_at: float = encounter_time + maxf(0.0, PLAYER_ACTION_DURATIONS[player.current_action] - player.action_elapsed)
	for record in active_threats:
		# A dodged/retrying Assassin invalidates its original first-strike forecast. Wait for resolution.
		if encounter_time >= record.lethal_at:
			return
		ready_at = maxf(ready_at, record.response_end)
	var speed: float = get_spawn_speed(pending_type)
	var lethal_at: float = encounter_time + get_lethal_lead(pending_type, speed)
	var duration: float = RESPONSE_DURATIONS[pending_type]
	var turn_time: float = ASSASSIN_TURN_ALLOWANCE if is_assassin(pending_type) else 0.0
	# Reserve a full turn for either Assassin side; this also covers facing changes during hazards.
	if lethal_at - duration < ready_at + turn_time + FAIRNESS_MARGIN:
		return
	var actor = THREAT_SCENES[pending_type].instantiate()
	# Main is always-processing for controls; actors must not inherit that exception.
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.configure_entry(pending_side)
	actor.movement_speed = speed
	actor.position = THREAT_START_POSITION
	actor.position.x = player.position.x + pending_side * (THREAT_START_POSITION.x - player.position.x)
	if pending_type == ThreatType.SHURIKEN:
		actor.position.y = actor.FLIGHT_HEIGHT
	add_child(actor)
	# Signals are presentation hooks only; no audio callback changes reservations or collision.
	if is_assassin(pending_type):
		actor.attack_started.connect(game_audio.play_attack.bind(pending_type))
	else:
		game_audio.start_hazard(actor.get_instance_id(), pending_type)
		actor.tree_exiting.connect(game_audio.stop_hazard.bind(actor.get_instance_id()))
		if pending_type == ThreatType.BARREL:
			actor.exploded.connect(game_audio.play_impact.bind("barrel_explosion"))
		else:
			actor.landed.connect(game_audio.play_impact.bind("shuriken_impact"))
	active_threats.append({"actor": actor, "type": pending_type, "lethal_at": lethal_at,
		"response_start": lethal_at - duration, "response_end": lethal_at + duration,
		"pattern": pattern_id, "pattern_step": pattern_step if pattern_id >= 0 else -1})
	next_spawn_at = encounter_time + get_spawn_gap()
	if pattern_id >= 0:
		pattern_step += 1
	pending_type = -1 # Admission consumes the slot; only now may selection advance.
	select_pending_threat()


## Release gameplay ownership immediately; harmless hazard animation remains owned by its node.
func finish_threat(record: Dictionary) -> void:
	if is_assassin(record.type):
		game_audio.play_defeat(record.type)
	else:
		# A resolved hazard no longer needs an approach cue; its impact has its own later signal.
		game_audio.stop_hazard(record.actor.get_instance_id())
	award_successful_threat(record.type as ThreatType)
	active_threats.erase(record)
	# Use the new Level's pacing after progression. Already approaching actors keep their reservations.
	next_spawn_at = encounter_time + get_spawn_gap()


func cancel_pending_spawn() -> void:
	clear_pattern()
	pending_type = -1
	pending_side = 0
	next_spawn_at = -1.0


## All actors move first, then Player attacks, then lethal checks, then surviving hazard rewards.
## Separate passes preserve Player-first Assassin priority regardless of the array's encounter order.
func _physics_process(delta: float) -> void:
	# Main handles menus and pause; simulation exists only in an unpaused run with no restart pending.
	if game_state != GameState.RUN or run_change_pending or get_tree().paused:
		return
	encounter_time += delta
	player.advance_tick(delta)
	if player.is_dead:
		cancel_pending_spawn()
		# Use Player's gameplay clock: pausing the fall also delays Game Over and its restart input.
		if player.death_elapsed >= player.DEATH_DURATION:
			show_run_result()
			if game_state != GameState.RUN:
				return
		# Preserve Assassin recovery after death; active hazards freeze and cosmetics remain independent.
		for record in active_threats:
			if is_assassin(record.type):
				record.actor.advance_tick(delta, player.position.x, true)
		return
	for record in active_threats:
		if is_assassin(record.type):
			record.actor.advance_tick(delta, player.position.x, false)
		else:
			record.actor.advance_tick(delta)
	# Iterate a shallow copy because successful attacks remove records immediately.
	for record in active_threats.duplicate():
		if is_assassin(record.type):
			player.resolve_attack(record.actor)
			if record.actor.is_dead:
				finish_threat(record)
	for record in active_threats:
		if is_assassin(record.type):
			record.actor.resolve_attack(player)
		else:
			record.actor.resolve_contact(player)
		if player.is_dead:
			cancel_pending_spawn()
			return
	for record in active_threats.duplicate():
		if not is_assassin(record.type) and record.actor.is_complete:
			finish_threat(record)
	# Spawning is last: a new actor first moves on the following physics tick.
	try_spawn_pending_threat()
