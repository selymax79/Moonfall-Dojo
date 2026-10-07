extends Node2D

const TURN_DURATION: float = 0.10
const PUNCH_EXTENSION_DURATION: float = 0.06
const PUNCH_HOLD_DURATION: float = 0.08
const PUNCH_RECOVERY_DURATION: float = 0.16
const KICK_EXTENSION_DURATION: float = 0.08
const KICK_HOLD_DURATION: float = 0.10
const KICK_RECOVERY_DURATION: float = 0.22
const DUCK_CROUCH_DURATION: float = 0.08
const DUCK_HOLD_DURATION: float = 0.20
const DUCK_RECOVERY_DURATION: float = 0.17
const DUCK_HEIGHT_SCALE: float = 0.45
const PUNCH_EXTENDED_SCALE: float = 1.5
const KICK_EXTENDED_SCALE: float = 8.0 / 3.0

enum Action { NONE, PUNCH, KICK, DUCK }

var target_direction: float = 1.0
var turn_progress: float = 1.0
var current_action: Action = Action.NONE
var action_elapsed: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var punch_arm: Node2D = $Visuals/PunchArm
@onready var kick_leg: Node2D = $Visuals/KickLeg


func _unhandled_input(event: InputEvent) -> void:
	# Discard inputs during the committed action; nothing is buffered.
	if current_action != Action.NONE or event.is_echo():
		return
	if event.is_action_pressed("punch"):
		start_action(Action.PUNCH)
	elif event.is_action_pressed("kick"):
		start_action(Action.KICK)
	elif event.is_action_pressed("duck"):
		start_action(Action.DUCK)
	elif event.is_action_pressed("turn_left"):
		target_direction = -1.0
	elif event.is_action_pressed("turn_right"):
		target_direction = 1.0


func _process(delta: float) -> void:
	if current_action != Action.NONE:
		update_action(delta)
		return

	# Crossing from +1 to -1 takes one full turn; reversing keeps current progress.
	turn_progress = move_toward(turn_progress, target_direction, 2.0 * delta / TURN_DURATION)
	# Avoid a zero scale (a singular transform) at the turn's midpoint.
	var visible_width: float = maxf(absf(turn_progress), 0.05)
	visuals.scale.x = visible_width * (-1.0 if turn_progress < 0.0 else 1.0)


func start_action(action: Action) -> void:
	# A committed action completes a reversible turn in its requested direction.
	turn_progress = target_direction
	visuals.scale.x = target_direction
	action_elapsed = 0.0
	current_action = action


func update_action(delta: float) -> void:
	var limb: Node2D = punch_arm
	var extension_duration: float = PUNCH_EXTENSION_DURATION
	var hold_duration: float = PUNCH_HOLD_DURATION
	var recovery_duration: float = PUNCH_RECOVERY_DURATION
	var extended_scale: float = PUNCH_EXTENDED_SCALE
	if current_action == Action.KICK:
		limb = kick_leg
		extension_duration = KICK_EXTENSION_DURATION
		hold_duration = KICK_HOLD_DURATION
		recovery_duration = KICK_RECOVERY_DURATION
		extended_scale = KICK_EXTENDED_SCALE
	elif current_action == Action.DUCK:
		extension_duration = DUCK_CROUCH_DURATION
		hold_duration = DUCK_HOLD_DURATION
		recovery_duration = DUCK_RECOVERY_DURATION

	var duration: float = extension_duration + hold_duration + recovery_duration
	action_elapsed = minf(action_elapsed + delta, duration)
	var extension: float
	if action_elapsed < extension_duration:
		extension = action_elapsed / extension_duration
	elif action_elapsed < extension_duration + hold_duration:
		extension = 1.0
	else:
		extension = 1.0 - (action_elapsed - extension_duration - hold_duration) / recovery_duration

	if current_action == Action.DUCK:
		# Visuals is rooted at the feet, so vertical compression keeps them planted.
		visuals.scale.y = lerpf(1.0, DUCK_HEIGHT_SCALE, extension)
	else:
		# Visuals mirrors the animated limb when facing left.
		limb.rotation = -PI / 2.0 * extension
		limb.scale.y = lerpf(1.0, extended_scale, extension)
	if action_elapsed >= duration or is_equal_approx(action_elapsed, duration):
		if current_action == Action.DUCK:
			visuals.scale.y = 1.0
		else:
			limb.rotation = 0.0
			limb.scale = Vector2.ONE
		current_action = Action.NONE
