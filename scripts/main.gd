## Runs one random Assassin encounter at a time, with Player-first combat resolution.
## Both actors share this scene's coordinate space; their scripts do not tick themselves.
extends Node2D

const ASSASSIN_SCENES = [preload("res://scenes/red_assassin.tscn"), preload("res://scenes/blue_assassin.tscn")]
const ASSASSIN_START_POSITION := Vector2(560, 300)
const BASE_APPROACH_SPEED: float = 60.0
const APPROACH_SPEED_PER_LEVEL: float = 5.0
# Speed plateaus at Level 9: a conservative cap with about 195 ms of theoretical Blue input opportunity.
# This is a tuning limit, not a mathematical impossibility boundary; attack timings stay fixed.
const MAX_APPROACH_SPEED: float = 100.0
# A brief breathing space after a kill; negative means no spawn is pending.
const NEXT_SPAWN_DELAY: float = 0.85
const POINTS_PER_KILL: int = 100
const HANDLED_THREATS_PER_LEVEL: int = 4
const HIGH_SCORE_PATH: String = "user://high_score.cfg"
var high_score: int = 0
var score: int = 0
var kills: int = 0
# Supply before _ready() for a future higher-level start; progression stays relative to this run.
var run_start_level: int = 1
var level: int = 1
var spawn_countdown: float = -1.0
var active_assassin = null
var encounter_rng := RandomNumberGenerator.new()

@onready var player = $Player
@onready var high_score_label: Label = $HUD/RunStats/HighScoreLabel
@onready var score_label: Label = $HUD/RunStats/ScoreLabel
@onready var kills_label: Label = $HUD/RunStats/KillsLabel
@onready var level_label: Label = $HUD/RunStats/LevelLabel
@onready var multiplier_label: Label = $HUD/RunStats/MultiplierLabel


## Randomise before entering the tree so tests can override the seed before the first spawn.
func _init() -> void:
	encounter_rng.randomize()


## A fresh scene starts a fresh encounter without resetting any existing Player state.
func _ready() -> void:
	level = run_start_level
	load_high_score()
	update_hud()
	spawn_assassin()


## Load each fresh scene, including F2 reloads. Missing or invalid data leaves a zero record.
func load_high_score() -> void:
	high_score = 0
	var save_data := ConfigFile.new()
	if save_data.load(HIGH_SCORE_PATH) != OK:
		return
	# Do not coerce strings, floats or booleans into scores from malformed save data.
	var saved_score: Variant = save_data.get_value("scores", "high_score", 0)
	if typeof(saved_score) == TYPE_INT and saved_score >= 0:
		high_score = saved_score


## Save a new record immediately; a failed write must not interrupt the current run.
func save_high_score() -> void:
	var save_data := ConfigFile.new()
	save_data.set_value("scores", "high_score", high_score)
	var error: Error = save_data.save(HIGH_SCORE_PATH)
	if error != OK:
		push_warning("Could not save High Score to %s: %s" % [HIGH_SCORE_PATH, error_string(error)])


## Presentation reads the record and run counters; padding expands naturally beyond six digits.
func update_hud() -> void:
	high_score_label.text = "High Score %06d" % high_score
	score_label.text = "Score %06d" % score
	kills_label.text = "Kills %d" % kills
	level_label.text = "Level %d" % level
	var half_units: int = get_multiplier_half_units()
	# Integer quotient and remainder display exact halves with one decimal place.
	@warning_ignore("integer_division")
	multiplier_label.text = "Multiplier x%d.%d" % [half_units / 2, (half_units % 2) * 5]


## Two half-units mean x1.0; each three completed run levels add another half-unit.
func get_multiplier_half_units() -> int:
	# Truncation intentionally counts only complete groups of three levels.
	@warning_ignore("integer_division")
	return 2 + (level - run_start_level) / 3


## Temporary development convenience: reload the whole scene, even during actions or death.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


## Choose type and entry side independently; repeated types and sides are valid encounters.
func spawn_assassin() -> void:
	if player.is_dead or is_instance_valid(active_assassin):
		return
	active_assassin = ASSASSIN_SCENES[encounter_rng.randi_range(0, 1)].instantiate()
	# Keep this second draw unconditional so seeded runs always consume type, then side.
	var entry_side: int = 1 if encounter_rng.randi_range(0, 1) == 0 else -1
	active_assassin.configure_entry(entry_side)
	# Snapshot this level's speed at spawn; later level changes never modify an existing enemy.
	active_assassin.movement_speed = minf(BASE_APPROACH_SPEED + APPROACH_SPEED_PER_LEVEL * (level - 1), MAX_APPROACH_SPEED)
	active_assassin.position = ASSASSIN_START_POSITION
	# Reflect the authored right spawn around Player: x=560 becomes x=80 at Player x=320.
	active_assassin.position.x = player.position.x + entry_side * (ASSASSIN_START_POSITION.x - player.position.x)
	add_child(active_assassin)
	spawn_countdown = -1.0


## Godot calls this at the fixed physics rate. Update both poses before testing their shapes.
func _physics_process(delta: float) -> void:
	player.advance_tick(delta)
	# Death cancels spawning but still lets the surviving enemy finish its existing recovery.
	if player.is_dead:
		spawn_countdown = -1.0
		if is_instance_valid(active_assassin):
			active_assassin.advance_tick(delta, player.position.x, true)
		return
	if not is_instance_valid(active_assassin):
		if spawn_countdown >= 0.0:
			spawn_countdown = maxf(0.0, spawn_countdown - delta)
			if is_zero_approx(spawn_countdown):
				spawn_assassin()
		# A newly spawned enemy starts moving on the following tick.
		return
	active_assassin.advance_tick(delta, player.position.x, false)
	# Player hits always resolve first, including simultaneous valid strikes.
	player.resolve_attack(active_assassin)
	if active_assassin.is_dead:
		# Award once here before clearing the reference, independently of deferred node removal.
		# Score before advancing Level: the completion kill uses the old multiplier.
		var half_units: int = get_multiplier_half_units()
		@warning_ignore("integer_division")
		score += (POINTS_PER_KILL * half_units) / 2
		# Observe the awarded score before progression; equality never rewrites the record.
		if score > high_score:
			high_score = score
			save_high_score()
		kills += 1
		# Kills are all handled threats for now; future dodges can contribute to this total.
		@warning_ignore("integer_division")
		level = run_start_level + kills / HANDLED_THREATS_PER_LEVEL
		update_hud()
		# The flag is immediate; queue_free() happens later. Start counting on the next tick.
		active_assassin = null
		spawn_countdown = NEXT_SPAWN_DELAY
		return
	active_assassin.resolve_attack(player)
	if player.is_dead:
		spawn_countdown = -1.0
