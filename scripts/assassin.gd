## Shared behaviour for both assassins: approach from either side, telegraph (wind-up), strike,
## recover, then retry until defeated. Red and Blue extend this and supply only what differs:
## where they stop (ATTACK_DISTANCE), which shape is their weapon, and how they pose each tick.
## Main advances every assassin and resolves Player attacks first; there is no independent tick.
extends Area2D

## Emitted when STRIKE begins; Main uses it only for the danger sound.
signal attack_started

# Phase lengths in seconds. Tuning these changes when the weapon is live, so threat_timing.gd
# (BLADE/FIST_CONTACT_DELAY) and press_window_verify.gd must be re-checked afterwards.
const DEFAULT_WINDUP_DURATION: float = 0.35
const STRIKE_DURATION: float = 0.20
const RECOVERY_DURATION: float = 0.25
const RETRY_DELAY: float = 0.40
# Standing hurtbox (16 x 40) with feet at the actor's origin.
const BODY_SIZE := Vector2(16, 40)

enum Phase { APPROACH, WINDUP, STRIKE, RECOVERY, WAIT }

# Main supplies these before adding the scene; standalone instances keep Level 1 values.
var movement_speed: float = 60.0
# The visible telegraph. Main shortens it at high Levels for recognition pressure only: the
# assassin keeps full speed through it, so strike timing and the Player's window are unchanged.
var windup_duration: float = DEFAULT_WINDUP_DURATION
# +1 enters from the right (the authored pose); -1 mirrors the whole actor to enter from the left.
var entry_side: int = 1
var phase: Phase = Phase.APPROACH
var phase_elapsed: float = 0.0
var is_dead: bool = false


## Configure before entering the tree. Mirroring the root reflects every visual and collision
## child together, so local weapon animation also mirrors in world space.
func configure_entry(side: int) -> void:
	assert(side == 1 or side == -1)
	entry_side = side
	scale = Vector2(entry_side, 1.0)


## Advance movement and the attack clock, using Player's X in the shared parent space.
## After Player dies, an attack in progress finishes but no new retry starts.
func advance_tick(delta: float, player_x: float, player_dead: bool) -> void:
	if is_dead:
		return
	var strike_x: float = player_x + entry_side * stop_distance()
	# Faster assassins start their wind-up farther out, so it always lasts windup_duration.
	var windup_distance: float = movement_speed * windup_duration
	# Leftover tick time carries into the next phase instead of being lost at each transition.
	var remaining: float = delta
	if phase == Phase.APPROACH:
		# Signed separation makes one calculation work on both sides of the Player.
		var travel_time: float = maxf(0.0, (position.x - strike_x) * entry_side - windup_distance) / movement_speed
		var step: float = minf(remaining, travel_time)
		position.x = move_toward(position.x, strike_x, movement_speed * step)
		remaining -= step
		if step < travel_time:
			return # Still approaching: the authored standing pose is untouched.
		phase = Phase.WINDUP
		phase_elapsed = 0.0
	# Only the wind-up moves the root; strike, recovery and retry stay at the strike position.
	while remaining > 0.0:
		if phase == Phase.WAIT and player_dead:
			break
		var duration: float = phase_duration()
		var step: float = minf(remaining, duration - phase_elapsed)
		phase_elapsed += step
		remaining -= step
		advance_phase_step(step)
		if phase == Phase.WINDUP:
			position.x = move_toward(position.x, strike_x, movement_speed * step)
		if phase_elapsed < duration and not is_equal_approx(phase_elapsed, duration):
			break
		phase_elapsed = 0.0
		match phase:
			Phase.WINDUP:
				position.x = strike_x
				phase = Phase.STRIKE
				attack_started.emit()
			Phase.STRIKE: phase = Phase.RECOVERY
			Phase.RECOVERY: phase = Phase.WAIT
			Phase.WAIT: phase = Phase.WINDUP
	update_pose()


func phase_duration() -> float:
	match phase:
		Phase.STRIKE: return STRIKE_DURATION
		Phase.RECOVERY: return RECOVERY_DURATION
		Phase.WAIT: return RETRY_DELAY
	return windup_duration


## Only STRIKE is lethal, and only where the weapon overlaps Player's current hurtbox.
## Direct shape queries use this tick's transforms, including Duck and Jump changes.
func resolve_attack(player: Node2D) -> void:
	if is_dead or player.is_dead or phase != Phase.STRIKE:
		return
	var weapon: CollisionShape2D = weapon_shape()
	if weapon.shape.collide(weapon.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()


## Any spatially valid Player hit kills; no attack type is checked.
## Mark dead immediately because queue_free() removes the node later, after combat resolution.
func receive_hit() -> void:
	if is_dead:
		return
	is_dead = true
	$Art.leave_corpse()
	queue_free()


# --- Supplied by each assassin -----------------------------------------------------------------

## Distance from the Player's centre at which this assassin stops and strikes.
func stop_distance() -> float:
	return 0.0


## The CollisionShape2D that is lethal during STRIKE.
func weapon_shape() -> CollisionShape2D:
	return null


## Called for every slice of time spent in a non-approach phase (Blue uses it to crouch).
func advance_phase_step(_step: float) -> void:
	pass


## Moves weapon and body nodes to match the current phase; runs once per tick.
func update_pose() -> void:
	pass
