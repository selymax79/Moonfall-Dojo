## Shuriken: flies at head height, so it must be Ducked. Shared passage and collision rules come
## from hazard.gd; this script spins the artwork and plays the harmless fall to the floor.
extends "res://scripts/hazard.gd"

# Cosmetic only: emitted when it settles on the floor, never another Dodge or damage event.
signal landed

# Main multiplies each Level's base speed by this. Flight height decides who can be hit:
# a standing body overlaps it, a fully crouched head clears it. Re-run press_window_verify.gd
# after changing either (threat_timing.gd reads both).
const SPEED_MULTIPLIER: float = 1.25
const FLIGHT_HEIGHT: float = 270.0
const FLOOR_HEIGHT: float = 300.0
# Artwork spin in radians per second; collision never rotates.
const SPIN_SPEED: float = 10.0
# Cosmetic aftermath lengths in seconds; they never delay the next threat.
const DEPARTURE_DURATION: float = 0.20
const FALL_DURATION: float = 0.75
const SETTLE_DURATION: float = 0.15

enum Phase { ACTIVE, DEPARTING, FALLING, SETTLED }
var phase: Phase = Phase.ACTIVE
var effect_elapsed: float = 0.0
var fall_start_y: float = FLIGHT_HEIGHT


## Main's active tick.
func advance_tick(delta: float) -> void:
	if phase == Phase.ACTIVE:
		travel(delta)


func travel(delta: float) -> void:
	position.x -= entry_side * movement_speed * delta
	visuals.rotation -= entry_side * SPIN_SPEED * delta


func begin_aftermath() -> void:
	phase = Phase.DEPARTING


## Cosmetic tick after handover. Unused time carries across phases so departure, fall and
## settle keep fixed durations. No Player reference or collision query exists here.
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
				# Ease downward without a physics body; the lowest tip meets the floor.
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
				landed.emit()
			Phase.SETTLED:
				set_physics_process(false)
				queue_free()
				return
