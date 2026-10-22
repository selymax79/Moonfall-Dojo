## Blue Assassin: unarmed, attacks with a low punch, so it must be Punched. It crouches during
## its first wind-up and stays low, so a raised Kick passes over it while a Punch connects.
## Shared approach/strike/retry timing comes from assassin.gd.
extends "res://scripts/assassin.gd"

# Logical pixels and seconds. Stopping 30 px away keeps the body within Punch reach.
# Changing these affects which response wins: re-run press_window_verify.gd afterwards.
const ATTACK_DISTANCE: float = 30.0
const THRUST_DURATION: float = 0.16
# Crouch must finish before Blue enters Kick range even with the shortest late wind-up
# (press_window_verify.gd checks this at every Level).
const CROUCH_DURATION: float = 0.08
const CROUCH_HEIGHT_SCALE: float = 0.60
const FIST_TRAVEL: float = 20.0

# Never resets: Blue stays low through strikes, recovery and retries.
var crouch_elapsed: float = 0.0

@onready var body: Node2D = $BodyVisuals
@onready var hurtbox: CollisionShape2D = $Hurtbox
@onready var fist: Node2D = $Fist
@onready var fist_shape: CollisionShape2D = $Fist/Attack/Shape
@onready var forearm: Polygon2D = $Forearm


func stop_distance() -> float:
	return ATTACK_DISTANCE


func weapon_shape() -> CollisionShape2D:
	return fist_shape


func advance_phase_step(step: float) -> void:
	crouch_elapsed = minf(crouch_elapsed + step, CROUCH_DURATION)


## Compress the body about its feet and resize its scene-local hurtbox to match.
## At floor Y=300 the low body spans Y=276..300: Punch overlaps; the raised Kick is above it.
func update_pose() -> void:
	var crouch: float = crouch_elapsed / CROUCH_DURATION
	var height_scale: float = lerpf(1.0, CROUCH_HEIGHT_SCALE, crouch)
	body.scale.y = height_scale
	hurtbox.position.y = -BODY_SIZE.y / 2.0 * height_scale
	hurtbox.shape.size = Vector2(BODY_SIZE.x, BODY_SIZE.y * height_scale)
	# Fist and its child hitbox travel together; recovery visibly retracts them but cannot hurt.
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
