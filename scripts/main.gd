## The game's coordinator. One Main instance is one screen session: Title and its menus, or a run.
## It owns the state machine (GameState), menu/pause/Game Over input, the fair threat scheduler,
## scoring and Level progression, and the per-tick combat order. Starting, restarting or quitting
## a run replaces this node with a fresh instance (replace_scene), so no reset list is needed.
## Pure timing maths lives in threat_timing.gd; records/settings in run_records.gd.
extends Node2D

# RUN includes death and non-qualifying Game Over; pause remains a SceneTree concern.
enum GameState { TITLE, CONTROLS, OPTIONS, HIGH_SCORES, INITIALS_ENTRY, RUN }
var game_state: GameState = GameState.TITLE
var menu_selection: int = 0
var options_selection: int = 0
# Pause menu rows, top to bottom. Each pause opens with Resume selected so Enter simply resumes.
# " - R" style suffixes name fixed keyboard shortcuts and are hidden on touchscreens.
enum PauseOption { RESUME, RESTART, QUIT }
const PAUSE_OPTION_TEXT = ["RESUME", "RESTART - R", "QUIT TO MENU - Q"]
var pause_selection: PauseOption = PauseOption.RESUME
# Shown after a non-qualifying run; Try Again is preselected so Enter restarts as before.
enum GameOverOption { TRY_AGAIN, MENU }
const GAME_OVER_OPTION_TEXT = ["TRY AGAIN - R", "RETURN TO MENU - Q"]
var game_over_selection: GameOverOption = GameOverOption.TRY_AGAIN
var selected_start_level: int = 1
var initials: String = ""
# Cursor on the on-screen key grid (MenuPointer draws it in rows of INITIAL_GRID_COLUMNS).
var initial_choice: int = 0
# True once directions move the grid cursor; Accept then adds that key. Typing turns it off.
var initial_cursor_active: bool = false
const INITIAL_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const INITIAL_GRID_COLUMNS: int = 12
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

const ThreatTiming = preload("res://scripts/threat_timing.gd")
const ThreatType = ThreatTiming.ThreatType
const THREAT_SCENES = [preload("res://scenes/red_assassin.tscn"), preload("res://scenes/blue_assassin.tscn"), preload("res://scenes/barrel.tscn"), preload("res://scenes/shuriken.tscn")]

# ============================================================================================
# TUNING. Difficulty, pacing and scoring knobs. Pacing and scoring values are free to change.
# Speed, wind-up and fairness values feed the fairness check: after changing them, re-run
# press_window_verify.gd, scheduler_verify.gd and late_verify.gd, and compare pacing_measure.gd.
# More knobs: get_spawn_gap() and get_pattern_start_chance() below; Player timings in player.gd.
# ============================================================================================

# Two-step patterns, always START side then OPPOSITE. Every unlocked pool balances all four types.
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
# Base threat speed (logical px/s) by Level: +5 per Level from 60 to 100 (Level 9), held to
# Level 14, 105 for Levels 15-19, then +1 per Level from 110 at Level 20 to MAX at Level 50.
# Barrel and Shuriken multiply it (barrel.gd / shuriken.gd SPEED_MULTIPLIER). The curve was tuned
# for threats appearing TUNED_APPROACH_DISTANCE from the Player; they now enter from just off
# screen, so get_spawn_speed() scales each type by its longer travel, keeping the time from
# appearing to reaching the Player as tuned.
const TUNED_APPROACH_DISTANCE: float = 240.0
const BASE_APPROACH_SPEED: float = 60.0
const APPROACH_SPEED_PER_LEVEL: float = 5.0
const EARLY_APPROACH_SPEED_CAP: float = 100.0
const EXPERIENCED_APPROACH_SPEED: float = 105.0 # Level 15–19.
const ENDURANCE_APPROACH_SPEED: float = 110.0 # Level 20.
const LATE_SPEED_PER_LEVEL: float = 1.0
# The hardest speed. Raising it extends the difficulty climb past Level 50.
const MAX_APPROACH_SPEED: float = 140.0
# Assassin telegraph: from LATE_WINDUP_START_LEVEL it shortens by WINDUP_REDUCTION_PER_LEVEL per
# Level down to MIN_WINDUP_DURATION (about human reaction time). Recognition pressure only:
# strike timing and the press window are unchanged (assassin.gd DEFAULT_WINDUP_DURATION is 0.35).
const LATE_WINDUP_START_LEVEL: int = 40
const WINDUP_REDUCTION_PER_LEVEL: float = 0.01
const MIN_WINDUP_DURATION: float = 0.25
# From this Level two threats may be unresolved at once (always still subject to fairness).
const OVERLAP_START_LEVEL: int = 6
# Fairness check (see plan_pending_press). Lower values pack threats closer together.
# Reaction allowance: time to notice the next threat and react, between finishing one planned
# response and the next planned press. Generous when two threats first overlap, tightening
# with Level so the climb continues; it never drops below the late value.
const REACTION_ALLOWANCE_EARLY: float = 0.60 # at OVERLAP_START_LEVEL and below
const REACTION_ALLOWANCE_LATE: float = 0.25 # from REACTION_TIGHTEST_LEVEL on (about human reaction time)
const REACTION_TIGHTEST_LEVEL: int = 50 # matches the speed curve, so both keep climbing to Level 50
# Reserved before every assassin, in case the Player must turn round.
const ASSASSIN_TURN_ALLOWANCE: float = 0.10
# Human timing slack guaranteed per planned press: pressing up to this late (or anywhere in a
# narrower window) still leaves every later planned response possible.
const RESPONSE_TOLERANCE: float = 0.10
# Safety, not tuning: each press window is trimmed by one 60 Hz physics tick at both ends so
# tick rounding can never push a planned press outside the geometry that makes it succeed.
const PRESS_WINDOW_INSET: float = 1.0 / 60.0
# Scoring and progression. The multiplier rises x0.5 every 3 Levels survived (see
# get_multiplier_half_units); AGENTS.md fixes these rules, so change them deliberately.
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
# Unresolved threats only (at most two). Each record: actor, type, lethal_at (first possible
# contact), response_start/press_latest (planned press interval), response_end (planned press
# interval plus the full action) and pattern/pattern_step (diagnostic provenance). Times are
# absolute encounter_time seconds.
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
	if play_start_cue:
		game_audio.play_ui("menu_confirm")
	if start_in_run:
		game_state = GameState.RUN
		game_audio.play_music("gameplay")
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


## Redraws every overlay for the current state. Visibility and text only: no gameplay clock,
## spawn or RNG draw happens here. Called after any menu input or state change.
func update_menu() -> void:
	update_touch_controls()
	$Environment.set_active(game_state == GameState.RUN)
	title_overlay.visible = game_state == GameState.TITLE
	controls_overlay.visible = game_state == GameState.CONTROLS
	options_overlay.visible = game_state == GameState.OPTIONS
	high_scores_overlay.visible = game_state == GameState.HIGH_SCORES
	initials_overlay.visible = game_state == GameState.INITIALS_ENTRY
	run_stats.visible = game_state == GameState.RUN or game_state == GameState.INITIALS_ENTRY
	update_title_menu()
	update_high_score_table()
	update_initials_view()
	$HUD/OptionsOverlay/MusicVolume.text = ("> Music Volume  %d <" if options_selection == 0 else "Music Volume  %d") % records.music_volume
	$HUD/OptionsOverlay/SFXVolume.text = ("> SFX Volume  %d <" if options_selection == 1 else "SFX Volume  %d") % records.sfx_volume
	update_run_menu_hints()
	update_option_rows()
	controls_overlay.queue_redraw()
	menu_pointer.refresh()


## Title rows, in order. Index 1 is the Start Level selector.
func title_choices() -> Array[String]:
	return ["START GAME", "START LEVEL  %d" % selected_start_level, "HIGH SCORES", "CONTROLS", "OPTIONS"]


func update_title_menu() -> void:
	title_high_score.text = "High Score %06d" % high_score
	var choices: Array[String] = title_choices()
	for index in range(choices.size()):
		$HUD/TitleOverlay/MenuContainer.get_child(index).text = "> %s <" % choices[index] if menu_selection == index else choices[index]
	$HUD/TitleOverlay/NavigationHint.text = "Directions to choose | %s to select" % binding_hint("menu_accept")
	$HUD/TitleOverlay/UnlockHint.text = "Highest unlocked: %d | Menu Left / Right adjusts Start Level" % records.highest_level


## Ten rows; empty slots show placeholders that are never saved.
func update_high_score_table() -> void:
	var ranks := ""
	var names := ""
	var scores := ""
	for index in range(records.TABLE_SIZE):
		var entry: Dictionary = records.entries[index] if index < records.entries.size() else {"initials": "---", "score": 0}
		ranks += "%2d.
" % (index + 1)
		names += "%s
" % entry.initials
		scores += "%06d
" % entry.score
	$HUD/HighScoresOverlay/Ranks.text = ranks.trim_suffix("
")
	$HUD/HighScoresOverlay/Initials.text = names.trim_suffix("
")
	$HUD/HighScoresOverlay/Scores.text = scores.trim_suffix("
")


## The three letter slots plus a hint matched to how the Player is entering them.
func update_initials_view() -> void:
	$HUD/InitialsOverlay/InitialsLabel.text = " ".join((initials + "___").substr(0, 3).split(""))
	var entry_hint: Label = $HUD/InitialsOverlay/EntryHint
	if touch_controls_enabled:
		entry_hint.text = "Tap your three initials, then SAVE"
	elif initials_grid_visible():
		entry_hint.text = "Directions pick  •  %s adds  •  %s erases  •  or just type" % [binding_hint("menu_accept"), binding_hint("menu_back")]
	else:
		entry_hint.text = "Type your initials  •  Backspace erases  •  %s saves" % records.controls.binding_text("menu_accept", "key")
	# Without the key grid, keep the hint directly under the letters.
	entry_hint.position.y = 276.0 if initials_grid_visible() else 132.0


## Pause and Game Over hint lines follow the current key bindings; touchscreens just say tap.
func update_run_menu_hints() -> void:
	if touch_controls_enabled:
		$HUD/GameOverOverlay/RestartHint.text = "TAP AN OPTION"
		$HUD/PauseOverlay/ResumeHint.text = "TAP AN OPTION"
		return
	# Pause, Esc (fixed), Cancel and Accept all resume; list each distinct key once.
	var resume_keys: Array[String] = []
	for key_name in [records.controls.binding_text("pause_game", "key"), "Escape",
			records.controls.binding_text("menu_back", "key"), records.controls.binding_text("menu_accept", "key")]:
		if not key_name.to_upper() in resume_keys: resume_keys.append(key_name.to_upper())
	$HUD/PauseOverlay/ResumeHint.text = " / ".join(resume_keys) + ": RESUME"
	$HUD/GameOverOverlay/RestartHint.text = records.controls.binding_text("menu_accept", "key").to_upper() + ": SELECT"


## "Key / Pad" names for a menu action, e.g. "Enter / Face Down".
func binding_hint(action: String) -> String:
	return records.controls.binding_text(action, "key") + " / " + records.controls.binding_text(action, "pad")


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
		menu_selection = posmod(menu_selection - 1, title_choices().size())
		game_audio.play_ui("menu_move")
	elif event.is_action_pressed("menu_down"):
		menu_selection = (menu_selection + 1) % title_choices().size()
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


## Keyboards type directly. Touchscreens tap the on-screen key grid (MenuPointer), and controllers
## move a cursor over that grid with directions, then Accept adds the key. Accept saves three slots.
func handle_initials_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_accept") and initials.length() == 3:
		submit_initials()
	elif event.is_action_pressed("menu_accept") and initial_cursor_active:
		add_initial(INITIAL_CHARACTERS[initial_choice])
		initial_cursor_active = true
	elif event.is_action_pressed("menu_back"):
		erase_initial()
		if initials.is_empty(): initial_cursor_active = false
	elif event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right"):
		var step: int = -1 if event.is_action_pressed("menu_left") else 1
		initial_choice = posmod(initial_choice + step, INITIAL_CHARACTERS.length())
		initial_cursor_active = true
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("menu_down"):
		var row_step: int = -INITIAL_GRID_COLUMNS if event.is_action_pressed("menu_up") else INITIAL_GRID_COLUMNS
		initial_choice = posmod(initial_choice + row_step, INITIAL_CHARACTERS.length())
		initial_cursor_active = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE:
			erase_initial()
		elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			# Navigation/function keys have unicode=0; reject them before constructing a character.
			var code: int = event.unicode
			if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
				add_initial(String.chr(code).to_upper())


## Shared by typing, the controller cursor and grid taps. A fourth character is ignored.
func add_initial(character: String) -> void:
	if initials.length() >= 3:
		return
	initials += character
	initial_cursor_active = false
	game_audio.play_ui("menu_move")


func erase_initial() -> void:
	if not initials.is_empty():
		game_audio.play_ui("menu_move")
	initials = initials.left(maxi(0, initials.length() - 1))


## Saves once three slots are filled, then shows the table. Fewer characters do nothing.
func submit_initials() -> void:
	if game_state != GameState.INITIALS_ENTRY or initials.length() != 3:
		return
	records.submit_score(initials, score)
	game_audio.play_ui("high_score")
	game_state = GameState.HIGH_SCORES
	update_hud()


## The key grid appears for touch, and for controller/arrow-key users once they press a direction.
func initials_grid_visible() -> bool:
	return touch_controls_enabled or initial_cursor_active


## Decide once after the death animation. Only a Top 10 score opens initials entry; any other
## run goes straight to the Try Again / Return to Menu choice.
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
		game_over_selection = GameOverOption.TRY_AGAIN
		update_option_rows()
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
func award_successful_threat(threat_type: int) -> void:
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
	var mode = touch_overlay.Mode.HIDDEN
	if touch_controls_enabled and game_state == GameState.RUN and not run_change_pending:
		mode = touch_overlay.Mode.PAUSE_ONLY if get_tree().paused or player.is_dead else touch_overlay.Mode.PLAYING
	touch_overlay.set_mode(mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if game_state != GameState.RUN:
		get_viewport().set_input_as_handled()
		handle_menu_input(event)
		return
	if get_tree().paused:
		get_viewport().set_input_as_handled()
		handle_pause_input(event)
		return
	if event.is_action_pressed("pause_game") or shortcut_key(event) == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		set_game_paused(true)
	elif game_over_overlay.visible:
		get_viewport().set_input_as_handled()
		handle_game_over_input(event)


## While paused, Main owns all input. Menu actions follow remapping; R and Q are fixed shortcuts.
## Pause, Esc and Back all resume, so every route into the pause menu also leaves it.
## Esc is a fixed key rather than the Back action: a controller's Back button doubles as Kick,
## so binding pause to Back would pause on every kick. Esc can never be a gameplay binding.
func handle_pause_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") or event.is_action_pressed("menu_back") or shortcut_key(event) == KEY_ESCAPE:
		choose_pause_option(PauseOption.RESUME)
	elif event.is_action_pressed("menu_accept"):
		choose_pause_option(pause_selection)
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("menu_down"):
		pause_selection = step_selection(event, pause_selection, PAUSE_OPTION_TEXT.size()) as PauseOption
		update_option_rows()
	elif shortcut_key(event) == KEY_R:
		choose_pause_option(PauseOption.RESTART)
	elif shortcut_key(event) == KEY_Q:
		choose_pause_option(PauseOption.QUIT)


## Non-qualifying Game Over: Accept, R or a tap tries again; Q, controller Back or a tap returns
## to Title. P and Esc still open the pause menu here; they are handled before this.
func handle_game_over_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_accept"):
		choose_game_over_option(game_over_selection)
	elif event.is_action_pressed("menu_back"):
		choose_game_over_option(GameOverOption.MENU)
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("menu_down"):
		game_over_selection = step_selection(event, game_over_selection, GAME_OVER_OPTION_TEXT.size()) as GameOverOption
		update_option_rows()
	elif shortcut_key(event) == KEY_R:
		choose_game_over_option(GameOverOption.TRY_AGAIN)
	elif shortcut_key(event) == KEY_Q:
		choose_game_over_option(GameOverOption.MENU)


## Up/Down move a run-menu cursor with wraparound; returns the new row index.
func step_selection(event: InputEvent, selection: int, count: int) -> int:
	var step: int = -1 if event.is_action_pressed("menu_up") else 1
	game_audio.play_ui("menu_move")
	return posmod(selection + step, count)


## Fixed Esc/R/Q shortcuts. Prefer the layout-aware keycode so they match the printed key;
## injected test events may set only the physical code.
func shortcut_key(event: InputEvent) -> Key:
	if not (event is InputEventKey and event.pressed):
		return KEY_NONE
	return event.keycode if event.keycode != KEY_NONE else event.physical_keycode


## Shared by keys, controller and pointer. Restart and Quit abandon the run: its score is not
## offered for the high-score table, while Levels already unlocked stay saved.
func choose_pause_option(option: PauseOption) -> void:
	match option:
		PauseOption.RESUME: set_game_paused(false)
		PauseOption.RESTART: start_new_run()
		PauseOption.QUIT: quit_to_title()


func choose_game_over_option(option: GameOverOption) -> void:
	match option:
		GameOverOption.TRY_AGAIN: start_new_run()
		GameOverOption.MENU: quit_to_title()


## Draws the pause and Game Over rows with a "> <" cursor on the selected one.
func update_option_rows() -> void:
	set_option_rows($HUD/PauseOverlay/Options, PAUSE_OPTION_TEXT, pause_selection)
	set_option_rows($HUD/GameOverOverlay/Options, GAME_OVER_OPTION_TEXT, game_over_selection)


func set_option_rows(rows: Control, texts: Array, selection: int) -> void:
	for index in texts.size():
		var text: String = texts[index]
		if touch_controls_enabled:
			text = text.get_slice(" - ", 0) # Keyboard shortcut letters mean nothing on a touchscreen.
		rows.get_child(index).text = "> %s <" % text if index == selection else text


## Start Game, Game Over Try Again and pause-menu Restart all replace the scene,
## avoiding a second list of reset rules.
func start_new_run() -> void:
	request_scene_change(true)


## Quit to Title also uses a fresh Main, so no actor, clock or audio from the abandoned run survives.
func quit_to_title() -> void:
	request_scene_change(false)


func request_scene_change(into_run: bool) -> void:
	if run_change_pending:
		return
	run_change_pending = true
	update_touch_controls()
	# Replace outside input dispatch; multiple presses in one frame cannot create duplicate scenes.
	replace_scene.call_deferred(into_run)


func replace_scene(into_run: bool) -> void:
	var tree := get_tree()
	var next_scene = load(scene_file_path).instantiate()
	next_scene.start_in_run = into_run
	next_scene.play_start_cue = true
	next_scene.records = records
	next_scene.touch_controls_enabled = touch_controls_enabled
	next_scene.platform_initialized = platform_initialized
	next_scene.audio_activated = audio_activated
	if into_run:
		next_scene.run_start_level = run_start_level if game_state == GameState.RUN else selected_start_level
		next_scene.selected_start_level = next_scene.run_start_level
		if game_state != GameState.RUN:
			# Menu dwell/navigation must preserve an injected seed and the exact initial RNG state.
			next_scene.encounter_rng.seed = encounter_rng.seed
			next_scene.encounter_rng.state = encounter_rng.state
	else:
		# Title keeps the Start Level this run used, so Start Game repeats it.
		next_scene.selected_start_level = selected_start_level
	# Configure before _ready(): an ordinary scene reload could not carry records or the start mode.
	set_game_paused(false)
	game_audio.stop_all()
	tree.root.remove_child(self)
	tree.root.add_child(next_scene)
	tree.current_scene = next_scene
	queue_free()


## SceneTree freezes pausable actors (including cosmetic aftermath); HUD remains responsive.
func set_game_paused(paused: bool) -> void:
	var changed: bool = get_tree().paused != paused
	get_tree().paused = paused
	if changed:
		game_audio.set_game_paused(paused)
		pause_selection = PauseOption.RESUME
		update_option_rows()
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


## TUNING: chance that a free choice starts a two-step pattern instead of a random threat.
## Patterns pick only WHAT comes next; the fairness check still decides WHEN. Safe to change.
func get_pattern_start_chance() -> float:
	if level < 4: return 0.0
	if level < 6: return 0.10
	if level < 10: return 0.15
	if level < 15: return 0.20
	if level < 20: return 0.22
	return 0.25 # About 40% of threats are patterned; ordinary random threats remain the majority.


## How many ENCOUNTER_PATTERNS are unlocked at the current Level (they unlock in list order).
func get_pattern_pool_size() -> int:
	if level < 4: return 0
	if level < 7: return 2
	if level < 10: return 4
	return ENCOUNTER_PATTERNS.size()


func clear_pattern() -> void:
	pattern_id = -1
	pattern_step = 0
	pattern_start_side = 0


## TUNING: minimum breathing time after a spawn or resolution before the next admission.
## Pure pacing on top of the fairness check (zero is still fair). Safe to change.
func get_spawn_gap() -> float:
	if level <= 3: return 0.85
	if level <= 6: return 0.65
	if level <= 9: return 0.45
	if level <= 14: return 0.35
	if level <= 19: return 0.20
	if level <= 29: return 0.10
	# No added breathing gap at mastery Levels; reservations/capacity still gate every admission.
	return 0.0


## One threat at a time until OVERLAP_START_LEVEL, then two. Three would need a new fairness proof.
func get_max_unresolved() -> int:
	return 1 if level < OVERLAP_START_LEVEL else 2


func is_assassin(threat_type: int) -> bool:
	return threat_type == ThreatType.RED or threat_type == ThreatType.BLUE


## The Level's base speed from the curve above (before type multipliers and entry scaling).
func get_base_speed() -> float:
	if level >= 20:
		return minf(ENDURANCE_APPROACH_SPEED + LATE_SPEED_PER_LEVEL * (level - 20), MAX_APPROACH_SPEED)
	if level >= 15:
		return EXPERIENCED_APPROACH_SPEED
	return minf(BASE_APPROACH_SPEED + APPROACH_SPEED_PER_LEVEL * (level - 1), EARLY_APPROACH_SPEED_CAP)


## Actual on-screen speed for a new threat of this type. Pending choices have no speed yet:
## a Level-up before spawn must affect the new actor.
func get_spawn_speed(threat_type: int) -> float:
	var speed: float = get_base_speed() * ThreatTiming.spawn_distance(threat_type) / TUNED_APPROACH_DISTANCE
	if threat_type == ThreatType.BARREL:
		return speed * ThreatTiming.BarrelScript.SPEED_MULTIPLIER
	if threat_type == ThreatType.SHURIKEN:
		return speed * ThreatTiming.ShurikenScript.SPEED_MULTIPLIER
	return speed


## Assassin telegraph length for the current Level.
func get_windup_duration() -> float:
	var default_windup: float = ThreatTiming.AssassinScript.DEFAULT_WINDUP_DURATION
	if level < LATE_WINDUP_START_LEVEL:
		return default_windup
	var steps: int = level - LATE_WINDUP_START_LEVEL + 1
	return maxf(MIN_WINDUP_DURATION, default_windup - WINDUP_REDUCTION_PER_LEVEL * steps)


## Shrinks linearly from REACTION_ALLOWANCE_EARLY at OVERLAP_START_LEVEL to REACTION_ALLOWANCE_LATE.
func get_reaction_allowance() -> float:
	var span: float = REACTION_TIGHTEST_LEVEL - OVERLAP_START_LEVEL
	var progress: float = clampf((level - OVERLAP_START_LEVEL) / span, 0.0, 1.0)
	return lerpf(REACTION_ALLOWANCE_EARLY, REACTION_ALLOWANCE_LATE, progress)


## The fairness check. Plans one press time for the pending threat so that, together with every
## admitted threat's planned press, the whole sequence stays survivable:
## - the press lies inside the threat's geometric press window (trimmed by one tick at each end);
## - it comes after every earlier planned response has fully recovered, plus a turn for assassins
##   and the Level's reaction allowance (get_reaction_allowance);
## - pressing up to RESPONSE_TOLERANCE late (or anywhere in a narrower window) keeps it valid.
## Returns {"press_at", "press_latest"} as absolute encounter times, or an empty Dictionary when
## admitting the threat now could leave no survivable response. (Not a Vector2: its 32-bit
## floats would round long-run absolute times.)
func plan_pending_press() -> Dictionary:
	var ready_at: float = encounter_time + maxf(0.0, ThreatTiming.player_action_duration(player.current_action) - player.action_elapsed)
	for record in active_threats:
		# A dodged/retrying Assassin invalidates its original first-strike forecast. Wait for resolution.
		if encounter_time >= record.lethal_at:
			return {}
		ready_at = maxf(ready_at, record.response_end)
	var window: Vector2 = ThreatTiming.press_window(pending_type, get_spawn_speed(pending_type))
	var earliest: float = encounter_time + window.x + PRESS_WINDOW_INSET
	var latest: float = encounter_time + window.y - PRESS_WINDOW_INSET
	# A narrow window (a slow Level 1 Shuriken) offers its whole width rather than the full tolerance.
	var tolerance: float = clampf(window.y - window.x - 2.0 * PRESS_WINDOW_INSET, 0.0, RESPONSE_TOLERANCE)
	# Reserve a full turn for either Assassin side; same-side pairs may not need it.
	var turn_time: float = ASSASSIN_TURN_ALLOWANCE if is_assassin(pending_type) else 0.0
	var press_at: float = maxf(earliest, ready_at + turn_time + get_reaction_allowance())
	# When the tolerance is the whole window, both sides are mathematically equal; the epsilon
	# stops float rounding from blocking that threat forever (which would stall all spawning).
	if press_at + tolerance > latest + 0.000001:
		return {}
	return {"press_at": press_at, "press_latest": minf(press_at + tolerance, latest)}


## Admits the pending choice once pacing, capacity and the fairness check allow it. Each record
## keeps its planned press interval (response_start .. response_end includes the tolerance and
## the full committed action), which later admissions must not overlap.
func try_spawn_pending_threat() -> void:
	if game_state != GameState.RUN or player.is_dead or pending_type < 0 or encounter_time < next_spawn_at:
		return
	if active_threats.size() >= get_max_unresolved():
		return
	var plan: Dictionary = plan_pending_press()
	if plan.is_empty():
		return
	var speed: float = get_spawn_speed(pending_type)
	var lethal_at: float = encounter_time + ThreatTiming.lethal_lead(pending_type, speed)
	var actor = THREAT_SCENES[pending_type].instantiate()
	# Main is always-processing for controls; actors must not inherit that exception.
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.configure_entry(pending_side)
	actor.movement_speed = speed
	if is_assassin(pending_type):
		actor.windup_duration = get_windup_duration()
	actor.position = Vector2(player.position.x + pending_side * ThreatTiming.spawn_distance(pending_type), ThreatTiming.FLOOR_Y)
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
		"response_start": plan.press_at, "press_latest": plan.press_latest,
		"response_end": plan.press_latest + ThreatTiming.response_duration(pending_type),
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
	award_successful_threat(record.type)
	active_threats.erase(record)
	# Use the new Level's pacing after progression. Already approaching actors keep their reservations.
	next_spawn_at = encounter_time + get_spawn_gap()


func cancel_pending_spawn() -> void:
	clear_pattern()
	pending_type = -1
	pending_side = 0
	next_spawn_at = -1.0


## The per-tick combat order: Player animates, threats move, Player attacks resolve, then
## threat attacks/collisions, then completed hazards are rewarded, and finally a new threat may
## be admitted. Separate passes mean a valid Player attack always wins a same-tick clash.
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
