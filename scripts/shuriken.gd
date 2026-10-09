## A head-height projectile. Main owns active movement and collision; only the artwork spins.
## After passage, local cosmetic states cannot damage, score or delay the next encounter.
extends Area2D

enum Phase { ACTIVE, DEPARTING, FALLING, SETTLED }
const PROJECTILE_SPEED_MULTIPLIER: float = 1.25
const FLIGHT_HEIGHT: float = 270.0
const FLOOR_HEIGHT: float = 300.0
const SPIN_SPEED: float = 10.0
const DEPARTURE_DURATION: float = 0.20
# A short deterministic drop lasts beyond the 0.85 s spawn delay, independent of gameplay.
const FALL_DURATION: float = 0.75
const SETTLE_DURATION: float = 0.15

# Main supplies the final speed once at spawn; cosmetics never change this snapshot.
var movement_speed: float = 75.0
var entry_side: int = 1
var is_complete: bool = false
var phase: Phase = Phase.ACTIVE
var effect_elapsed: float = 0.0
var fall_start_y: float = FLIGHT_HEIGHT

@onready var body_shape: CollisionShape2D = $BodyShape
@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	set_physics_process(false)


func configure_entry(side: int) -> void:
	assert(side == 1 or side == -1)
	entry_side = side


func advance_tick(delta: float) -> void:
	if phase == Phase.ACTIVE:
		travel(delta)


func travel(delta: float) -> void:
	position.x -= entry_side * movement_speed * delta
	visuals.rotation -= entry_side * SPIN_SPEED * delta


## Query the current hurtbox directly, including lowering, standing and jumping poses.
## Collision wins over completion; full horizontal passage is required even while ducked.
func resolve_contact(player: Node2D) -> void:
	if phase != Phase.ACTIVE or player.is_dead:
		return
	if body_shape.shape.collide(body_shape.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()
		return
	var separation: float = entry_side * (global_position.x - player.hurtbox.global_position.x)
	var passage_distance: float = body_shape.shape.radius + player.hurtbox.shape.size.x / 2.0
	if separation < -passage_distance:
		is_complete = true
		phase = Phase.DEPARTING
		# Main releases ownership this tick; defer our tick to avoid moving twice on handover.
		set_physics_process.call_deferred(true)


## Carry unused time across phases so departure, floor contact and cleanup have fixed durations.
## No player reference or collision query exists in this cosmetic lifecycle.
func _physics_process(delta: float) -> void:
	var remaining: float = delta
	while remaining > 0.0 and phase != Phase.ACTIVE:
		var duration: float = DEPARTURE_DURATION
		match phase:
			Phase.FALLING: duration = FALL_DURATION
			Phase.SETTLED: duration = SETTLE_DURATION
		var step: float = minf(remaining, duration - effect_elapsed)
		effect_elapsed += step
		remaining -= step
		match phase:
			Phase.DEPARTING:
				travel(step)
			Phase.FALLING:
				# Ease downward without a physics body; the visual's lowest tip meets the floor.
				var progress: float = effect_elapsed / FALL_DURATION
				position.y = lerpf(fall_start_y, FLOOR_HEIGHT - body_shape.shape.radius, progress * progress)
				visuals.rotation -= entry_side * SPIN_SPEED * step
		if effect_elapsed < duration and not is_equal_approx(effect_elapsed, duration):
			return
		effect_elapsed = 0.0
		match phase:
			Phase.DEPARTING:
				phase = Phase.FALLING
				fall_start_y = position.y
			Phase.FALLING:
				phase = Phase.SETTLED
				position.y = FLOOR_HEIGHT - body_shape.shape.radius
				visuals.rotation = 0.0
			Phase.SETTLED:
				set_physics_process(false)
				queue_free()
				return
