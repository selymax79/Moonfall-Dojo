## Owns input, fixed-duration actions, spatial attacks and the placeholder death animation.
## The root stays at the floor; Visuals moves/scales around its feet (negative Y is upward).
extends Node2D

# Durations are seconds and distances are logical pixels; player timings stay fixed across levels.
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
const KICK_OUTLINE_EXTENDED = [Vector2(-3, 0), Vector2(10, -21), Vector2(32, -21), Vector2(32, -15), Vector2(10, -15), Vector2(3, 0)]
const KICK_FILL_EXTENDED = [Vector2(-2, 0), Vector2(11, -20), Vector2(31, -20), Vector2(31, -16), Vector2(10, -16), Vector2(2, 0)]

# NONE allows reversible turning; every other action locks input until its animation finishes.
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
var kick_extension: float = 0.0
var death_kick_extension: float = 0.0

# @onready resolves scene children after they exist, and captures the original pose for restoration.
@onready var visuals: Node2D = $Visuals
@onready var standing_visual_position: Vector2 = visuals.position
@onready var punch_arm: Node2D = $Visuals/PunchArm
@onready var kick_leg: Node2D = $Visuals/KickLeg
@onready var punch_shape: CollisionShape2D = $AttackShapes/Punch
@onready var kick_shape: CollisionShape2D = $AttackShapes/Kick
@onready var hurtbox: CollisionShape2D = $Hurtbox/Body
@onready var kick_outline: Polygon2D = $Visuals/KickLeg/RightLegOutline
@onready var kick_fill: Polygon2D = $Visuals/KickLeg/RightLeg
@onready var kick_outline_rest: PackedVector2Array = kick_outline.polygon
@onready var kick_fill_rest: PackedVector2Array = kick_fill.polygon


## React to fresh presses rather than held keys. Echo filtering prevents keyboard auto-repeat.
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


## Main advances the pose before combat resolution, keeping collision and visuals on the same tick.
## The mutable hurtbox shape is scene-local, so resizing it cannot affect another instance.
func advance_tick(delta: float) -> void:
	if is_dead:
		update_death(delta)
		return
	update_living_pose(delta)
	# Keep the core body aligned with the visible jump/crouch, but not turn squashing.
	hurtbox.position = visuals.position + Vector2(0.0, -20.0 * visuals.scale.y)
	hurtbox.shape.size = Vector2(16.0, 40.0 * visuals.scale.y)


## Committed actions own the pose; otherwise horizontal squashing gives turns a brief animation.
func update_living_pose(delta: float) -> void:
	if current_action != Action.NONE:
		update_action(delta)
		return

	# Crossing from +1 to -1 takes one full turn; reversing keeps current progress.
	turn_progress = move_toward(turn_progress, target_direction, 2.0 * delta / TURN_DURATION)
	# Avoid a zero scale (a singular transform) at the turn's midpoint.
	var visible_width: float = maxf(absf(turn_progress), 0.05)
	visuals.scale.x = visible_width * (-1.0 if turn_progress < 0.0 else 1.0)


## Begin immediately in the requested facing direction, even midway through a turn.
## The input handler checks the action lock before calling this; no pending action is stored.
func start_action(action: Action) -> void:
	if is_dead:
		return
	# A committed action completes a reversible turn in its requested direction.
	turn_progress = target_direction
	visuals.scale.x = target_direction
	action_elapsed = 0.0
	current_action = action


## Punch, Kick and Duck share extension/hold/recovery timing; Jump has its own curved motion.
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
	elif current_action == Action.DUCK:
		extension_duration = DUCK_CROUCH_DURATION
		hold_duration = DUCK_HOLD_DURATION
		recovery_duration = DUCK_RECOVERY_DURATION

	# A shared 0-to-1-to-0 amount drives each pose without duplicating the phase calculation.
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
	elif current_action == Action.KICK:
		update_kick_pose(extension)
	else:
		# Visuals mirrors the animated limb when facing left.
		limb.rotation = -PI / 2.0 * extension
		limb.scale.y = lerpf(1.0, extended_scale, extension)
	# Explicit resets avoid leaving a nearly-restored pose because of floating-point rounding.
	if action_elapsed >= duration or is_equal_approx(action_elapsed, duration):
		if current_action == Action.DUCK:
			visuals.scale.y = 1.0
		elif current_action == Action.KICK:
			update_kick_pose(0.0)
		else:
			limb.rotation = 0.0
			limb.scale = Vector2.ONE
		current_action = Action.NONE


## Interpolate matching polygon vertices from the resting leg to a raised, longer-reaching kick.
## Extended points are local to KickLeg; its parent mirrors the whole pose when facing left.
func update_kick_pose(extension: float) -> void:
	kick_extension = extension
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	# Bend at the knee while keeping the hip attached; the forward shin matches the hitbox.
	for index in range(kick_outline_rest.size()):
		outline.append(kick_outline_rest[index].lerp(KICK_OUTLINE_EXTENDED[index], extension))
		fill.append(kick_fill_rest[index].lerp(KICK_FILL_EXTENDED[index], extension))
	kick_outline.polygon = outline
	kick_fill.polygon = fill


## Only the fully extended hold can hit. Both enemies expose Hurtbox, is_dead and receive_hit().
## No attack type is passed to the enemy: range and vertical overlap decide whether it dies.
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
	# Disabled scene shapes are templates for this direct query, not automatic Area2D monitoring.
	# Mirror their local X offsets into world space; current transforms avoid overlap-cache lag.
	var offset := attack_shape.position
	offset.x *= target_direction
	var attack_transform := Transform2D(0.0, to_global(offset))
	var enemy_body: CollisionShape2D = enemy.get_node("Hurtbox")
	if attack_shape.shape.collide(attack_transform, enemy_body.shape, enemy_body.global_transform):
		enemy.receive_hit()


## Death immediately cancels gameplay actions; capture the current pose for a continuous fall.
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
	death_kick_extension = kick_extension


## Smoothstep eases into a permanent fallen pose while returning the limbs to rest.
## This placeholder assumes an attacker on the right; only Visuals moves, never the Player root.
func update_death(delta: float) -> void:
	death_elapsed = minf(death_elapsed + delta, DEATH_DURATION)
	var progress: float = death_elapsed / DEATH_DURATION
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	# Offset the rotated body toward the floor as it falls away from the right-side attacker.
	visuals.position = death_start_position.lerp(standing_visual_position + Vector2(0, -11), eased)
	visuals.scale = death_start_scale.lerp(Vector2(1, 1), eased)
	visuals.rotation = -PI / 2.0 * eased
	punch_arm.rotation = lerpf(death_arm_rotation, 0.0, eased)
	punch_arm.scale = death_arm_scale.lerp(Vector2.ONE, eased)
	kick_leg.rotation = lerpf(death_leg_rotation, 0.0, eased)
	kick_leg.scale = death_leg_scale.lerp(Vector2.ONE, eased)
	update_kick_pose(lerpf(death_kick_extension, 0.0, eased))


## A fixed visual arc gives predictable evasion without gravity or a moving character controller.
## Restore the saved position explicitly on landing so repeated jumps cannot accumulate drift.
func update_jump(delta: float) -> void:
	action_elapsed = minf(action_elapsed + delta, JUMP_DURATION)
	var progress: float = action_elapsed / JUMP_DURATION
	# A parabola starts at the floor, peaks halfway through, and returns to the floor.
	var height_offset: float = 4.0 * JUMP_HEIGHT * progress * (1.0 - progress)
	visuals.position = standing_visual_position + Vector2(0.0, -height_offset)
	if action_elapsed >= JUMP_DURATION or is_equal_approx(action_elapsed, JUMP_DURATION):
		visuals.position = standing_visual_position
		current_action = Action.NONE
