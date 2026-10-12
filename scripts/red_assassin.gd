## Katana threat from either side: approach while telegraphing, then strike, recover and retry.
## Main advances this actor and resolves Player's attack first; this script has no independent tick.
extends Area2D

signal attack_started

# Logical pixels and seconds. The final spacing lets Kick reach the body while Punch falls short.
const ATTACK_DISTANCE: float = 38.0
const WINDUP_DURATION: float = 0.35
const STRIKE_DURATION: float = 0.20
const THRUST_DURATION: float = 0.168
const SWORD_DRAW_BACK: float = 24.0
const SWORD_THRUST_END: float = -4.0
const RECOVERY_DURATION: float = 0.25
const RETRY_DELAY: float = 0.40
# Main supplies this before adding the scene; independent instances retain Level 1 speed.
var movement_speed: float = 60.0
# +1 enters from the right (the authored pose); -1 reflects that encounter from the left.
var entry_side: int = 1

enum Phase { APPROACH, WINDUP, STRIKE, RECOVERY, WAIT }
var phase: Phase = Phase.APPROACH
var phase_elapsed: float = 0.0
var is_dead: bool = false

@onready var sword: Node2D = $Sword
@onready var blade_shape: CollisionShape2D = $Sword/Attack/BladeShape


## Configure before entering the tree. Reflect every visual and collision child together;
## sword animation stays in authored local coordinates, so its world-space thrust also mirrors.
func configure_entry(side: int) -> void:
	assert(side == 1 or side == -1)
	entry_side = side
	scale = Vector2(entry_side, 1.0)


## Advance movement and the attack clock using Player's X in the shared parent coordinate space.
## Finish an ongoing attack after Player dies, but stop retrying once WAIT is reached.
func advance_tick(delta: float, player_x: float, player_dead: bool) -> void:
	if is_dead:
		return
	var strike_x: float = player_x + entry_side * ATTACK_DISTANCE
	# Faster enemies telegraph farther out, preserving the full wind-up while still advancing.
	var windup_distance: float = movement_speed * WINDUP_DURATION
	var remaining: float = delta
	# Carry leftover tick time into the next phase instead of losing it at each transition.
	if phase == Phase.APPROACH:
		# Signed separation makes the same approach calculation work on both sides of Player.
		var travel_time: float = maxf(0.0, (position.x - strike_x) * entry_side - windup_distance) / movement_speed
		var step: float = minf(remaining, travel_time)
		position.x = move_toward(position.x, strike_x, movement_speed * step)
		remaining -= step
		if step < travel_time:
			return
		phase = Phase.WINDUP
		phase_elapsed = 0.0
	# Wind-up closes the remaining distance; later phases stay at the exact strike position.
	while remaining > 0.0:
		if phase == Phase.WAIT and player_dead:
			break
		var duration: float = WINDUP_DURATION
		match phase:
			Phase.STRIKE: duration = STRIKE_DURATION
			Phase.RECOVERY: duration = RECOVERY_DURATION
			Phase.WAIT: duration = RETRY_DELAY
		var step: float = minf(remaining, duration - phase_elapsed)
		phase_elapsed += step
		remaining -= step
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
	update_sword_pose()


## Move the shared sword parent so the visible blade and its collision shape remain aligned.
## Drawing back before thrusting provides visible travel before lethal contact, not a hidden grace period.
func update_sword_pose() -> void:
	match phase:
		Phase.WINDUP:
			sword.position.x = lerpf(0.0, SWORD_DRAW_BACK, phase_elapsed / WINDUP_DURATION)
		Phase.STRIKE:
			sword.position.x = lerpf(SWORD_DRAW_BACK, SWORD_THRUST_END, minf(phase_elapsed / THRUST_DURATION, 1.0))
		Phase.RECOVERY:
			sword.position.x = lerpf(SWORD_THRUST_END, 0.0, phase_elapsed / RECOVERY_DURATION)
		_:
			sword.position.x = 0.0


## Only STRIKE is lethal, and only where the blade overlaps Player's current adaptive hurtbox.
## Direct shape queries use this tick's transforms, including Duck and Jump changes.
func resolve_attack(player: Node2D) -> void:
	if is_dead or player.is_dead or phase != Phase.STRIKE:
		return
	if blade_shape.shape.collide(blade_shape.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()

## Any spatially valid player hit kills, including an artificially close Punch.
## Mark dead immediately because queue_free() removes the node later, after combat resolution.
func receive_hit() -> void:
	if is_dead:
		return
	is_dead = true
	$Art.leave_corpse()
	queue_free()
