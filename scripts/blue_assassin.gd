extends Area2D

const APPROACH_SPEED: float = 60.0
const ATTACK_DISTANCE: float = 30.0
const WINDUP_DURATION: float = 0.35
const STRIKE_DURATION: float = 0.20
const THRUST_DURATION: float = 0.16
const CROUCH_DURATION: float = 0.08
const CROUCH_HEIGHT_SCALE: float = 0.60
const FIST_TRAVEL: float = 20.0
const RECOVERY_DURATION: float = 0.25
const RETRY_DELAY: float = 0.40
const WINDUP_DISTANCE: float = APPROACH_SPEED * WINDUP_DURATION

enum Phase { APPROACH, WINDUP, STRIKE, RECOVERY, WAIT }
var phase: Phase = Phase.APPROACH
var phase_elapsed: float = 0.0
var is_dead: bool = false

var crouch_elapsed: float = 0.0

@onready var body: Node2D = $BodyVisuals
@onready var hurtbox: CollisionShape2D = $Hurtbox
@onready var fist: Node2D = $Fist
@onready var fist_shape: CollisionShape2D = $Fist/Attack/Shape
@onready var forearm: Polygon2D = $Forearm


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
		crouch_elapsed = minf(crouch_elapsed + step, CROUCH_DURATION)
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
	update_pose()


func update_pose() -> void:
	var crouch: float = crouch_elapsed / CROUCH_DURATION
	var height_scale: float = lerpf(1.0, CROUCH_HEIGHT_SCALE, crouch)
	body.scale.y = height_scale
	hurtbox.position.y = -20.0 * height_scale
	hurtbox.shape.size = Vector2(16.0, 40.0 * height_scale)
	var extension: float = 0.0
	if phase == Phase.STRIKE:
		extension = minf(phase_elapsed / THRUST_DURATION, 1.0)
	elif phase == Phase.RECOVERY:
		extension = 1.0 - phase_elapsed / RECOVERY_DURATION
	fist.position = Vector2(-10.0 - FIST_TRAVEL * extension, lerpf(-23.0, -12.0, crouch))
	# The forearm stays attached to the body while the fist travels forward.
	var y: float = fist.position.y
	forearm.polygon = PackedVector2Array([
		Vector2(-8, y - 2), Vector2(fist.position.x, y - 2),
		Vector2(fist.position.x, y + 2), Vector2(-8, y + 2)
	])


func resolve_attack(player: Node2D) -> void:
	if is_dead or player.is_dead or phase != Phase.STRIKE:
		return
	if fist_shape.shape.collide(fist_shape.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()

func receive_hit() -> void:
	if is_dead:
		return
	is_dead = true
	queue_free()
