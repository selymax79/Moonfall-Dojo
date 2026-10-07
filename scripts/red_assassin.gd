extends Area2D

const APPROACH_SPEED: float = 60.0
const ATTACK_DISTANCE: float = 38.0
const WINDUP_DURATION: float = 0.35
const STRIKE_DURATION: float = 0.20
const THRUST_DURATION: float = 0.168
const SWORD_DRAW_BACK: float = 24.0
const SWORD_THRUST_END: float = -4.0
const RECOVERY_DURATION: float = 0.25
const RETRY_DELAY: float = 0.40
const WINDUP_DISTANCE: float = APPROACH_SPEED * WINDUP_DURATION

enum Phase { APPROACH, WINDUP, STRIKE, RECOVERY, WAIT }
var phase: Phase = Phase.APPROACH
var phase_elapsed: float = 0.0
var is_dead: bool = false

@onready var sword: Node2D = $Sword
@onready var blade_shape: CollisionShape2D = $Sword/Attack/BladeShape


func advance_tick(delta: float, player_x: float, player_dead: bool) -> void:
	if is_dead:
		return
	var strike_x: float = player_x + ATTACK_DISTANCE
	var remaining: float = delta
	# Carry unused time across phase boundaries so movement/timing do not depend on rounding.
	if phase == Phase.APPROACH:
		var travel_time: float = maxf(0.0, position.x - strike_x - WINDUP_DISTANCE) / APPROACH_SPEED
		var step: float = minf(remaining, travel_time)
		position.x -= APPROACH_SPEED * step
		remaining -= step
		if step < travel_time:
			return
		phase = Phase.WINDUP
		phase_elapsed = 0.0
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
			position.x = move_toward(position.x, strike_x, APPROACH_SPEED * step)
		if phase_elapsed < duration and not is_equal_approx(phase_elapsed, duration):
			break
		phase_elapsed = 0.0
		match phase:
			Phase.WINDUP:
				position.x = strike_x
				phase = Phase.STRIKE
			Phase.STRIKE: phase = Phase.RECOVERY
			Phase.RECOVERY: phase = Phase.WAIT
			Phase.WAIT: phase = Phase.WINDUP
	update_sword_pose()


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


func resolve_attack(player: Node2D) -> void:
	if is_dead or player.is_dead or phase != Phase.STRIKE:
		return
	if blade_shape.shape.collide(blade_shape.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()

func receive_hit() -> void:
	if is_dead:
		return
	is_dead = true
	queue_free()
