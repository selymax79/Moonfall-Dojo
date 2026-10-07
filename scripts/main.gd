## Runs one random Assassin encounter at a time, with Player-first combat resolution.
## Both actors share this scene's coordinate space; their scripts do not tick themselves.
extends Node2D

const ASSASSIN_SCENES = [preload("res://scenes/red_assassin.tscn"), preload("res://scenes/blue_assassin.tscn")]
const ASSASSIN_START_POSITION := Vector2(560, 300)
# A brief breathing space after a kill; negative means no spawn is pending.
const NEXT_SPAWN_DELAY: float = 0.85
var spawn_countdown: float = -1.0
var active_assassin = null
var encounter_rng := RandomNumberGenerator.new()

@onready var player = $Player


## Randomise before entering the tree so tests can override the seed before the first spawn.
func _init() -> void:
	encounter_rng.randomize()


## A fresh scene starts a fresh encounter without resetting any existing Player state.
func _ready() -> void:
	spawn_assassin()


## Temporary development convenience: reload the whole scene, even during actions or death.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


## Both scenes use the same small combat convention; only scene selection differs.
func spawn_assassin() -> void:
	if player.is_dead or is_instance_valid(active_assassin):
		return
	active_assassin = ASSASSIN_SCENES[encounter_rng.randi_range(0, 1)].instantiate()
	active_assassin.position = ASSASSIN_START_POSITION
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
		# The flag is immediate; queue_free() happens later. Start counting on the next tick.
		active_assassin = null
		spawn_countdown = NEXT_SPAWN_DELAY
		return
	active_assassin.resolve_attack(player)
	if player.is_dead:
		spawn_countdown = -1.0
