extends Node2D

const TURN_DURATION: float = 0.10
const PUNCH_EXTENSION_DURATION: float = 0.06
const PUNCH_HOLD_DURATION: float = 0.08
const PUNCH_RECOVERY_DURATION: float = 0.16
const PUNCH_DURATION: float = PUNCH_EXTENSION_DURATION + PUNCH_HOLD_DURATION + PUNCH_RECOVERY_DURATION

var target_direction: float = 1.0
var turn_progress: float = 1.0
var action_in_progress: bool = false
var punch_elapsed: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var punch_arm: Node2D = $Visuals/PunchArm


func _unhandled_input(event: InputEvent) -> void:
	# Discard inputs during the committed action; nothing is buffered.
	if action_in_progress or event.is_echo():
		return
	if event.is_action_pressed("punch"):
		start_punch()
	elif event.is_action_pressed("turn_left"):
		target_direction = -1.0
	elif event.is_action_pressed("turn_right"):
		target_direction = 1.0


func _process(delta: float) -> void:
	if action_in_progress:
		update_punch(delta)
		return

	# Crossing from +1 to -1 takes one full turn; reversing keeps current progress.
	turn_progress = move_toward(turn_progress, target_direction, 2.0 * delta / TURN_DURATION)
	# Avoid a zero scale (a singular transform) at the turn's midpoint.
	var visible_width: float = maxf(absf(turn_progress), 0.05)
	visuals.scale.x = visible_width * (-1.0 if turn_progress < 0.0 else 1.0)


func start_punch() -> void:
	# A punch completes a reversible turn immediately in its requested direction.
	turn_progress = target_direction
	visuals.scale.x = target_direction
	punch_elapsed = 0.0
	action_in_progress = true


func update_punch(delta: float) -> void:
	punch_elapsed = minf(punch_elapsed + delta, PUNCH_DURATION)
	var extension: float
	if punch_elapsed < PUNCH_EXTENSION_DURATION:
		extension = punch_elapsed / PUNCH_EXTENSION_DURATION
	elif punch_elapsed < PUNCH_EXTENSION_DURATION + PUNCH_HOLD_DURATION:
		extension = 1.0
	else:
		extension = 1.0 - (punch_elapsed - PUNCH_EXTENSION_DURATION - PUNCH_HOLD_DURATION) / PUNCH_RECOVERY_DURATION

	# Raise and extend the forward arm; the Visuals parent mirrors it when facing left.
	punch_arm.rotation = -PI / 2.0 * extension
	punch_arm.scale.y = 1.0 + 0.5 * extension
	if punch_elapsed >= PUNCH_DURATION or is_equal_approx(punch_elapsed, PUNCH_DURATION):
		punch_arm.rotation = 0.0
		punch_arm.scale = Vector2.ONE
		action_in_progress = false
