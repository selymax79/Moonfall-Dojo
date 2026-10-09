## Schedules up to two unresolved threats with separate response/recovery reservations.
## Main owns gameplay; resolved hazards run their harmless cosmetic aftermath independently.
extends Node2D

enum ThreatType { RED, BLUE, BARREL, SHURIKEN }
const THREAT_SCENES = [preload("res://scenes/red_assassin.tscn"), preload("res://scenes/blue_assassin.tscn"), preload("res://scenes/barrel.tscn"), preload("res://scenes/shuriken.tscn")]
const THREAT_START_POSITION := Vector2(560, 300)
const BASE_APPROACH_SPEED: float = 60.0
const APPROACH_SPEED_PER_LEVEL: float = 5.0
# Speed plateaus at Level 9: a conservative cap with about 195 ms of theoretical Blue input opportunity.
# This is a tuning limit, not a mathematical impossibility boundary; attack timings stay fixed.
const MAX_APPROACH_SPEED: float = 100.0
# Pacing never overrides the timing checks. Overlap is a Level 6 difficulty choice, not a safety exemption.
const OVERLAP_START_LEVEL: int = 6
const FAIRNESS_MARGIN: float = 0.10
const ASSASSIN_TURN_ALLOWANCE: float = 0.10
# Intended responses in ThreatType order: Kick, Punch, Jump, Duck.
const RESPONSE_DURATIONS = [0.40, 0.30, 0.75, 0.60]
# Player.Action order: NONE, PUNCH, KICK, DUCK, JUMP. Keep aligned with Player's fixed timings.
const PLAYER_ACTION_DURATIONS = [0.0, 0.30, 0.40, 0.60, 0.75]
const POINTS_PER_THREAT: int = 100
const HANDLED_THREATS_PER_LEVEL: int = 4
const HIGH_SCORE_PATH: String = "user://high_score.cfg"
var high_score: int = 0
var score: int = 0
var kills: int = 0
var dodges: int = 0
# Supply before _ready() for a future higher-level start; progression stays relative to this run.
var run_start_level: int = 1
# Run-local testing offset: changes difficulty/multiplier without inventing handled threats.
var dev_level_boost: int = 0
var level: int = 1
# Each record contains actor, type, lethal_at, response_start and response_end (absolute run seconds).
# Only unresolved gameplay belongs here; at most two records keeps ownership explicit.
var active_threats: Array[Dictionary] = []
var encounter_time: float = 0.0
var next_spawn_at: float = 0.0
var pending_type: int = -1
var pending_side: int = 0
var encounter_rng := RandomNumberGenerator.new()

@onready var player = $Player
@onready var high_score_label: Label = $HUD/RunStats/HighScoreLabel
@onready var score_label: Label = $HUD/RunStats/ScoreLabel
@onready var kills_label: Label = $HUD/RunStats/KillsLabel
@onready var dodges_label: Label = $HUD/RunStats/DodgesLabel
@onready var level_label: Label = $HUD/RunStats/LevelLabel
@onready var multiplier_label: Label = $HUD/RunStats/MultiplierLabel


## Randomise before entering the tree so tests can override the seed before the first spawn.
func _init() -> void:
	encounter_rng.randomize()


## A fresh scene starts a fresh encounter without resetting any existing Player state.
func _ready() -> void:
	recalculate_level()
	load_high_score()
	update_hud()
	select_pending_threat()
	try_spawn_pending_threat()


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
	dodges_label.text = "Dodges %d" % dodges
	level_label.text = "Level %d" % level
	var half_units: int = get_multiplier_half_units()
	# Integer quotient and remainder display exact halves with one decimal place.
	@warning_ignore("integer_division")
	multiplier_label.text = "Multiplier x%d.%d" % [half_units / 2, (half_units % 2) * 5]


## Two half-units mean x1.0; each three effective run levels (including dev boosts) add a half-unit.
func get_multiplier_half_units() -> int:
	# Truncation intentionally counts only complete groups of three levels.
	@warning_ignore("integer_division")
	return 2 + (level - run_start_level) / 3


## Reward a gameplay success before releasing its unresolved record.
## Score first so a Level-boundary threat still earns the old multiplier; cosmetics never call this.
func award_successful_threat(threat_type: ThreatType) -> void:
	var half_units: int = get_multiplier_half_units()
	@warning_ignore("integer_division")
	score += (POINTS_PER_THREAT * half_units) / 2
	if score > high_score:
		high_score = score
		save_high_score()
	if threat_type == ThreatType.BARREL or threat_type == ThreatType.SHURIKEN:
		dodges += 1
	else:
		kills += 1
	recalculate_level()
	update_hud()


## Earned progression and development boosts share one formula, so real successes retain the boost.
func recalculate_level() -> void:
	var handled_threats: int = kills + dodges
	@warning_ignore("integer_division")
	level = run_start_level + handled_threats / HANDLED_THREATS_PER_LEVEL + dev_level_boost


## Development controls bypass Player's action lock and remain available on the dead HUD.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("dev_level_up") and not event.is_echo():
		get_viewport().set_input_as_handled()
		var previous_gap: float = get_spawn_gap()
		dev_level_boost += 1
		recalculate_level()
		# Preserve elapsed gap time when crossing a pacing band. Only this admission gate changes;
		# actor reservations, pending selection and fairness checks remain untouched.
		if not player.is_dead and next_spawn_at > encounter_time:
			next_spawn_at = maxf(encounter_time, next_spawn_at + get_spawn_gap() - previous_gap)
		update_hud()


## Exactly two draws per selection, including the pending choice: type, then side; never reroll waits.
func select_pending_threat() -> void:
	pending_type = encounter_rng.randi_range(0, 3)
	pending_side = 1 if encounter_rng.randi_range(0, 1) == 0 else -1


func get_spawn_gap() -> float:
	if level <= 3: return 0.85
	if level <= 6: return 0.65
	if level <= 9: return 0.45
	return 0.35


func get_max_unresolved() -> int:
	return 1 if level < OVERLAP_START_LEVEL else 2


func is_assassin(threat_type: int) -> bool:
	return threat_type == ThreatType.RED or threat_type == ThreatType.BLUE


## Pending choices have no speed yet: a Level-up before spawn must affect the new actor.
func get_spawn_speed(threat_type: int) -> float:
	var base_speed: float = minf(BASE_APPROACH_SPEED + APPROACH_SPEED_PER_LEVEL * (level - 1), MAX_APPROACH_SPEED)
	return base_speed * 1.25 if threat_type == ThreatType.SHURIKEN else base_speed


## First possible contact with standing Player, derived from the existing mirrored geometry.
## Assassin travel includes the moving 0.35 s telegraph; add only the final weapon travel.
func get_lethal_lead(threat_type: int, speed: float) -> float:
	match threat_type:
		ThreatType.RED: return 202.0 / speed + 0.09 # 38 px stop; blade reaches Player 90 ms into strike.
		ThreatType.BLUE: return 210.0 / speed + 0.08 # 30 px stop; fist reaches Player 80 ms into strike.
		ThreatType.BARREL: return 225.0 / speed # 240 px separation minus 8 px Player half-width and radius 7.
		ThreatType.SHURIKEN: return 228.0 / speed # Radius 4; speed already includes the projectile multiplier.
	return 0.0


## Reserve [first contact - response duration, first contact + response duration].
## It contains a valid intended response and its full recovery, not a promise that every press in it wins.
## A new reservation must follow every existing recovery, actual Player availability, turn and margin.
func try_spawn_pending_threat() -> void:
	if player.is_dead or pending_type < 0 or encounter_time < next_spawn_at:
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
	actor.configure_entry(pending_side)
	actor.movement_speed = speed
	actor.position = THREAT_START_POSITION
	actor.position.x = player.position.x + pending_side * (THREAT_START_POSITION.x - player.position.x)
	if pending_type == ThreatType.SHURIKEN:
		actor.position.y = actor.FLIGHT_HEIGHT
	add_child(actor)
	active_threats.append({"actor": actor, "type": pending_type, "lethal_at": lethal_at,
		"response_start": lethal_at - duration, "response_end": lethal_at + duration})
	next_spawn_at = encounter_time + get_spawn_gap()
	select_pending_threat()


## Release gameplay ownership immediately; harmless hazard animation remains owned by its node.
func finish_threat(record: Dictionary) -> void:
	award_successful_threat(record.type as ThreatType)
	active_threats.erase(record)
	# Use the new Level's pacing after progression. Already approaching actors keep their reservations.
	next_spawn_at = encounter_time + get_spawn_gap()


func cancel_pending_spawn() -> void:
	pending_type = -1
	pending_side = 0
	next_spawn_at = -1.0


## All actors move first, then Player attacks, then lethal checks, then surviving hazard rewards.
## Separate passes preserve Player-first Assassin priority regardless of the array's encounter order.
func _physics_process(delta: float) -> void:
	encounter_time += delta
	player.advance_tick(delta)
	if player.is_dead:
		cancel_pending_spawn()
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
