extends Node2D

const TURN_DURATION: float = 0.10
const PUNCH_EXTENSION_DURATION: float = 0.06
const PUNCH_HOLD_DURATION: float = 0.08
const PUNCH_RECOVERY_DURATION: float = 0.16
const KICK_EXTENSION_DURATION: float = 0.08
const KICK_HOLD_DURATION: float = 0.16
const KICK_RECOVERY_DURATION: float = 0.16
const DUCK_CROUCH_DURATION: float = 0.08
const DUCK_HOLD_DURATION: float = 0.20
const DUCK_RECOVERY_DURATION: float = 0.17
const DUCK_HEIGHT_SCALE: float = 0.45
const JUMP_DURATION: float = 0.60
const JUMP_HEIGHT: float = 55.0
const DEATH_DURATION: float = 0.40
const PUNCH_EXTENDED_SCALE: float = 1.5
const KICK_EXTENDED_SCALE: float = 8.0 / 3.0

enum Action { NONE, PUNCH, KICK, DUCK, JUMP }

var target_direction: float = 1.0
var turn_progress: float = 1.0
var current_action: Action = Action.NONE
var action_elapsed: float = 0.0
var is_dead: bool = false
var death_elapsed: float = 0.0
var death_start_position: Vector2
var death_start_scale: Vector2
var death_arm_rotation: float
var death_arm_scale: Vector2
var death_leg_rotation: float
var death_leg_scale: Vector2

@onready var visuals: Node2D = $Visuals
@onready var standing_visual_position: Vector2 = visuals.position
@onready var punch_arm: Node2D = $Visuals/PunchArm
@onready var kick_leg: Node2D = $Visuals/KickLeg
@onready var punch_shape: CollisionShape2D = $AttackShapes/Punch
@onready var kick_shape: CollisionShape2D = $AttackShapes/Kick
@onready var hurtbox: CollisionShape2D = $Hurtbox/Body


func _unhandled_input(event: InputEvent) -> void:
	# Discard inputs during the committed action; nothing is buffered.
	if is_dead or current_action != Action.NONE or event.is_echo():
		return
	if event.is_action_pressed("punch"):
		start_action(Action.PUNCH)
	elif event.is_action_pressed("kick"):
		start_action(Action.KICK)
	elif event.is_action_pressed("duck"):
		start_action(Action.DUCK)
	elif event.is_action_pressed("jump"):
		start_action(Action.JUMP)
	elif event.is_action_pressed("turn_left"):
		target_direction = -1.0
	elif event.is_action_pressed("turn_right"):
		target_direction = 1.0


func advance_tick(delta: float) -> void:
	if is_dead:
		update_death(delta)
		return
	update_living_pose(delta)
	# Keep the core body aligned with the visible jump/crouch, but not turn squashing.
	hurtbox.position = visuals.position + Vector2(0.0, -20.0 * visuals.scale.y)
	hurtbox.shape.size = Vector2(16.0, 40.0 * visuals.scale.y)


func update_living_pose(delta: float) -> void:
	if current_action != Action.NONE:
		update_action(delta)
		return

	# Crossing from +1 to -1 takes one full turn; reversing keeps current progress.
	turn_progress = move_toward(turn_progress, target_direction, 2.0 * delta / TURN_DURATION)
	# Avoid a zero scale (a singular transform) at the turn's midpoint.
	var visible_width: float = maxf(absf(turn_progress), 0.05)
	visuals.scale.x = visible_width * (-1.0 if turn_progress < 0.0 else 1.0)


func start_action(action: Action) -> void:
	if is_dead:
		return
	# A committed action completes a reversible turn in its requested direction.
	turn_progress = target_direction
	visuals.scale.x = target_direction
	action_elapsed = 0.0
	current_action = action


func update_action(delta: float) -> void:
	if current_action == Action.JUMP:
		update_jump(delta)
		return

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


func resolve_attack(enemy: Area2D) -> void:
	if is_dead or enemy.is_dead:
		return
	var attack_shape: CollisionShape2D
	var active_start: float
	var active_end: float
	if current_action == Action.PUNCH:
		attack_shape = punch_shape
		active_start = PUNCH_EXTENSION_DURATION
		active_end = active_start + PUNCH_HOLD_DURATION
	elif current_action == Action.KICK:
		attack_shape = kick_shape
		active_start = KICK_EXTENSION_DURATION
		active_end = active_start + KICK_HOLD_DURATION
	else:
		return
	if action_elapsed < active_start or action_elapsed >= active_end:
		return
	# Compare current transforms directly; no physics-server overlap cache lag.
	var offset := attack_shape.position
	offset.x *= target_direction
	var attack_transform := Transform2D(0.0, to_global(offset))
	var enemy_body: CollisionShape2D = enemy.get_node("Hurtbox")
	if attack_shape.shape.collide(attack_transform, enemy_body.shape, enemy_body.global_transform):
		enemy.receive_hit()


func receive_hit() -> void:
	if is_dead:
		return
	is_dead = true
	current_action = Action.NONE
	death_start_position = visuals.position
	death_start_scale = visuals.scale
	death_arm_rotation = punch_arm.rotation
	death_arm_scale = punch_arm.scale
	death_leg_rotation = kick_leg.rotation
	death_leg_scale = kick_leg.scale


func update_death(delta: float) -> void:
	death_elapsed = minf(death_elapsed + delta, DEATH_DURATION)
	var progress: float = death_elapsed / DEATH_DURATION
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	# Fall away from the right-side attacker. Keep the silhouette above the floor.
	visuals.position = death_start_position.lerp(standing_visual_position + Vector2(0, -11), eased)
	visuals.scale = death_start_scale.lerp(Vector2(1, 1), eased)
	visuals.rotation = -PI / 2.0 * eased
	punch_arm.rotation = lerpf(death_arm_rotation, 0.0, eased)
	punch_arm.scale = death_arm_scale.lerp(Vector2.ONE, eased)
	kick_leg.rotation = lerpf(death_leg_rotation, 0.0, eased)
	kick_leg.scale = death_leg_scale.lerp(Vector2.ONE, eased)


func update_jump(delta: float) -> void:
	action_elapsed = minf(action_elapsed + delta, JUMP_DURATION)
	var progress: float = action_elapsed / JUMP_DURATION
	# A parabola starts at the floor, peaks halfway through, and returns to the floor.
	var height_offset: float = 4.0 * JUMP_HEIGHT * progress * (1.0 - progress)
	visuals.position = standing_visual_position + Vector2(0.0, -height_offset)
	if action_elapsed >= JUMP_DURATION or is_equal_approx(action_elapsed, JUMP_DURATION):
		visuals.position = standing_visual_position
		current_action = Action.NONE
