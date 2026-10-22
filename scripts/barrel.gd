## Barrel: rolls along the floor, so it must be Jumped. Shared passage and collision rules come
## from hazard.gd; this script rolls the artwork and plays the harmless roll-on and explosion.
extends "res://scripts/hazard.gd"

# Cosmetic only: emitted when the explosion starts, after the Dodge was already awarded.
signal exploded

# Main multiplies each Level's base speed by this. A faster Barrel crosses the Player sooner,
# which widens the Jump window; re-run press_window_verify.gd after changing it.
const SPEED_MULTIPLIER: float = 1.15
# Cosmetic aftermath lengths in seconds; they never delay the next threat.
const DEPARTURE_DURATION: float = 0.50
const EXPLOSION_DURATION: float = 0.40

enum Phase { ACTIVE, DEPARTING, EXPLODING }
var phase: Phase = Phase.ACTIVE
var effect_elapsed: float = 0.0


## Main's active tick. Only the artwork rotates (distance / radius); collision never rotates.
func advance_tick(delta: float) -> void:
	if is_complete:
		return
	roll(delta)


func roll(delta: float) -> void:
	var travel: float = -entry_side * movement_speed * delta
	position.x += travel
	visuals.rotation += travel / body_shape.shape.radius


func begin_aftermath() -> void:
	phase = Phase.DEPARTING


## Cosmetic tick after handover: roll on briefly, then explode and free itself.
func _physics_process(delta: float) -> void:
	var remaining: float = delta
	if phase == Phase.DEPARTING:
		var step: float = minf(remaining, DEPARTURE_DURATION - effect_elapsed)
		roll(step)
		effect_elapsed += step
		remaining -= step
		if effect_elapsed < DEPARTURE_DURATION and not is_equal_approx(effect_elapsed, DEPARTURE_DURATION):
			return
		phase = Phase.EXPLODING
		effect_elapsed = 0.0
		visuals.hide()
		exploded.emit()
	if phase == Phase.EXPLODING:
		effect_elapsed = minf(effect_elapsed + remaining, EXPLOSION_DURATION)
		queue_redraw()
		if effect_elapsed >= EXPLOSION_DURATION or is_equal_approx(effect_elapsed, EXPLOSION_DURATION):
			queue_free()
