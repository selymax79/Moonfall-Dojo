## Read-only presentation for the five actors: picks an atlas pose from the actor's own gameplay
## clocks and draws it with small pixel effects. It never writes to the actor, collision shapes,
## scheduler, scoring or RNG, so art changes cannot change combat.
## Runs after Main's simulation tick (process_physics_priority) and inherits the actor's
## processing mode, so pause and menu disabling freeze it with the actor.
extends Node2D

const NinjaAtlas = preload("res://scripts/ninja_atlas.gd")
const NINJAS = [preload("res://art/combat/player.png"), preload("res://art/combat/red.png"), preload("res://art/combat/blue.png")]
const BARREL = preload("res://art/combat/barrel.png")
const STAR = preload("res://art/combat/shuriken.png")
const AFTERMATH = preload("res://scripts/combat_aftermath.gd")

enum Kind { PLAYER, RED, BLUE, BARREL, SHURIKEN }
@export var kind: Kind = Kind.PLAYER

# Presentation timing (seconds). Free to tweak: none of these affect gameplay.
const IDLE_BREATHS_PER_SECOND: float = 2.0
const LANDING_DUST_DURATION: float = 0.12
const DEATH_SPARK_DURATION: float = 0.08
# Turn pose shows while the facing is mid-reversal.
const TURN_POSE_BELOW: float = 0.8
# Jump pose bands as a fraction of the arc: take-off, rise, fall, then landing from ~0.907
# (0.68 / 0.75, authored for the original 0.75 s jump and kept so the poses still line up).
const JUMP_TAKEOFF_UNTIL: float = 0.10
const JUMP_RISE_UNTIL: float = 2.0 / 3.0
const JUMP_LANDING_FROM: float = 0.68 / 0.75
# Duck shows its lowest pose once the hurtbox is this short (px).
const DUCK_LOW_POSE_HEIGHT: float = 23.0
# A death that starts this crouched enters the collapse strip at its low part.
const LOW_DEATH_SCALE: float = 0.75
# Run-cycle step length for assassins (px per pose).
const RUN_STEP_PIXELS: float = 4.0
const SHADOW_COLOR := Color(0.025, 0.035, 0.065)

var elapsed: float = 0.0
var frame: int = 0
var facing: float = 1.0
var lift: float = 0.0
var dust_left: float = 0.0
var was_jumping: bool = false
@onready var actor = get_parent()


func _ready() -> void:
	# Inherit the actor: Pausable during play, Disabled when Main hides actors in menus.
	process_mode = Node.PROCESS_MODE_INHERIT
	process_physics_priority = 100 # Main's movement/combat tick runs first.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.ready.connect(update_pose, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	elapsed += delta
	dust_left = maxf(0.0, dust_left - delta)
	update_pose()


func update_pose() -> void:
	match kind:
		Kind.PLAYER: frame = player_pose()
		Kind.RED, Kind.BLUE: frame = assassin_pose()
		# Barrel rounds around each of its 8 authored poses so both roll directions switch at the
		# same distance; signed rotation already turns clockwise rightward, anticlockwise leftward.
		Kind.BARREL: frame = posmod(roundi(actor.visuals.rotation / (PI / 4.0)), 8)
		Kind.SHURIKEN: frame = posmod(floori(actor.visuals.rotation / (PI / 4.0)), 4)
	queue_redraw()


func player_pose() -> int:
	facing = actor.target_direction
	if actor.is_dead:
		# The body sinks from where death caught it (mid-jump included) back to the floor.
		lift = lerpf(actor.death_start_position.y, 0.0, minf(actor.death_elapsed / actor.DEATH_DURATION, 1.0))
		# A crouched death enters the low part of the collapse instead of standing up first.
		var first: int = NinjaAtlas.COLLAPSE_LOW if actor.death_start_scale.y < LOW_DEATH_SCALE else NinjaAtlas.COLLAPSE_FIRST
		var strip: int = NinjaAtlas.COLLAPSE_LAST + 1 - first
		return first + mini(strip - 1, floori(actor.death_elapsed / actor.DEATH_DURATION * strip))
	lift = actor.visuals.position.y
	var jumping: bool = actor.current_action == actor.Action.JUMP
	if was_jumping and not jumping: dust_left = LANDING_DUST_DURATION
	was_jumping = jumping
	var time: float = actor.action_elapsed
	match actor.current_action:
		actor.Action.PUNCH:
			if time < actor.PUNCH_EXTENSION_DURATION:
				return NinjaAtlas.PUNCH_WIND if time < actor.PUNCH_EXTENSION_DURATION / 2.0 else NinjaAtlas.PUNCH_REACH
			if time < actor.PUNCH_EXTENSION_DURATION + actor.PUNCH_HOLD_DURATION:
				return NinjaAtlas.PUNCH_HIT
			# Retract through the reach pose, fold the elbow, then settle into guard.
			var recovery: float = (time - actor.PUNCH_EXTENSION_DURATION - actor.PUNCH_HOLD_DURATION) / actor.PUNCH_RECOVERY_DURATION
			return recovery_pose(recovery, NinjaAtlas.PUNCH_REACH, NinjaAtlas.PUNCH_FOLD)
		actor.Action.KICK:
			if time < actor.KICK_EXTENSION_DURATION:
				return NinjaAtlas.KICK_CHAMBER if time < actor.KICK_EXTENSION_DURATION / 2.0 else NinjaAtlas.KICK_RISE
			if time < actor.KICK_EXTENSION_DURATION + actor.KICK_HOLD_DURATION:
				return NinjaAtlas.KICK_HIT
			var recovery: float = (time - actor.KICK_EXTENSION_DURATION - actor.KICK_HOLD_DURATION) / actor.KICK_RECOVERY_DURATION
			return recovery_pose(recovery, NinjaAtlas.KICK_RISE, NinjaAtlas.KICK_FOLD)
		actor.Action.JUMP:
			var progress: float = time / actor.JUMP_DURATION
			if progress < JUMP_TAKEOFF_UNTIL: return NinjaAtlas.JUMP_TAKEOFF
			if progress < JUMP_RISE_UNTIL: return NinjaAtlas.JUMP_RISE
			return NinjaAtlas.JUMP_FALL if progress < JUMP_LANDING_FROM else NinjaAtlas.JUMP_LANDING
		actor.Action.DUCK:
			# Genuine crouch poses, never a vertically squashed standing sprite.
			if actor.hurtbox.shape.size.y <= DUCK_LOW_POSE_HEIGHT: return NinjaAtlas.CROUCH_LOW
			return NinjaAtlas.CROUCH_TRANSITION if time < actor.DUCK_CROUCH_DURATION else NinjaAtlas.CROUCH_RISE
	if absf(actor.turn_progress) < TURN_POSE_BELOW:
		return NinjaAtlas.TURN
	return NinjaAtlas.IDLE + floori(elapsed * IDLE_BREATHS_PER_SECOND) % 2


## Attack recovery: first quarter back through the extension pose, middle half folded, then guard.
func recovery_pose(recovery: float, extension_pose: int, fold_pose: int) -> int:
	if recovery < 0.25: return extension_pose
	return fold_pose if recovery < 0.75 else NinjaAtlas.IDLE + 1


func assassin_pose() -> int:
	# Assassin roots already mirror their children; the atlas is authored facing right.
	facing = -1.0
	if actor.phase == actor.Phase.APPROACH:
		return NinjaAtlas.RUN_FIRST + posmod(floori(actor.position.x / RUN_STEP_PIXELS), 4)
	if kind == Kind.RED:
		match actor.phase:
			actor.Phase.WINDUP: return NinjaAtlas.RED_WINDUP
			actor.Phase.STRIKE: return NinjaAtlas.RED_STRIKE
		return NinjaAtlas.RED_RECOVERY
	if actor.crouch_elapsed < actor.CROUCH_DURATION:
		return NinjaAtlas.CROUCH_TRANSITION
	return NinjaAtlas.BLUE_STRIKE if actor.phase == actor.Phase.STRIKE else NinjaAtlas.BLUE_GUARD


## Called by an assassin just before it is removed. The corpse keeps no actor reference or collision.
func leave_corpse() -> void:
	var corpse := Node2D.new()
	corpse.set_script(AFTERMATH)
	corpse.texture = NINJAS[kind]
	corpse.position = actor.position
	corpse.facing = -float(actor.entry_side)
	corpse.blue = kind == Kind.BLUE
	actor.get_parent().add_child(corpse)


func _draw() -> void:
	if not actor.is_node_ready(): return
	match kind:
		Kind.PLAYER, Kind.RED, Kind.BLUE:
			# The Player's shadow narrows as the jump rises.
			var shadow_width: float = 16.0 - maxf(0.0, -lift) / 11.0 if kind == Kind.PLAYER else 16.0
			contact_shadow(Vector2.ZERO, shadow_width)
			draw_set_transform(Vector2(0, roundf(lift)), 0, Vector2(facing, 1))
			NinjaAtlas.draw_pose(self, NINJAS[kind], frame)
			draw_set_transform(Vector2.ZERO)
			if kind == Kind.RED: draw_blade()
			if kind == Kind.BLUE: draw_low_fist()
			if kind == Kind.PLAYER:
				if dust_left > 0: dust(1.0 - dust_left / LANDING_DUST_DURATION)
				if actor.is_dead and actor.death_elapsed < DEATH_SPARK_DURATION:
					spark(Vector2(0, lift - 22), actor.death_elapsed / DEATH_SPARK_DURATION)
		Kind.BARREL:
			if actor.phase != actor.Phase.EXPLODING:
				contact_shadow(Vector2.ZERO, 19)
				draw_texture_rect_region(BARREL, Rect2(-10, -19, 20, 20), Rect2(frame * 20, 0, 20, 20))
			else:
				barrel_debris(actor.effect_elapsed / actor.EXPLOSION_DURATION)
		Kind.SHURIKEN:
			var settled: bool = actor.phase == actor.Phase.SETTLED
			draw_texture_rect_region(STAR, Rect2(-4, -4, 8, 8), Rect2((0 if settled else frame) * 8, 0, 8, 8))
			if settled: spark(Vector2(0, 3), actor.effect_elapsed / actor.SETTLE_DURATION)


## Follows the real collision parent's continuous translation, snapped only for raster display.
func draw_blade() -> void:
	var x: float = roundf(actor.sword.position.x)
	var steel := Color("bccdd0") if actor.phase == actor.Phase.STRIKE else Color("82969e")
	draw_rect(Rect2(x - 39, -24, 26, 2), steel)
	draw_rect(Rect2(x - 38, -24, 24, 1), Color("e5e4c9"))
	draw_rect(Rect2(x - 14, -26, 2, 6), Color("b79b62"))
	draw_rect(Rect2(x - 12, -24, 6, 3), Color("292c38"))
	# Shoulder, bent elbow and wrist follow the weapon without moving its collision parent.
	var elbow := Vector2(lerpf(-10, 9, clampf((x + 4) / 28.0, 0, 1)), -20)
	var arm := PackedVector2Array([Vector2(-3, -27), elbow, Vector2(x - 9, -23)])
	draw_polyline(arm, Color("080e1c"), 6, false)
	draw_polyline(arm, Color("742a3b"), 4, false)
	draw_line(elbow, elbow.lerp(Vector2(x - 9, -23), 0.65).round(), Color("bb4050"), 1, false)
	draw_rect(Rect2(x - 10, -24, 3, 3), Color("c29b78"))


func draw_low_fist() -> void:
	if actor.phase == actor.Phase.APPROACH: return
	var at: Vector2 = actor.fist.position.round()
	var shoulder := Vector2(-2, -18 if frame == NinjaAtlas.CROUCH_TRANSITION else -15)
	var elbow := Vector2(-7, at.y + 1)
	var arm := PackedVector2Array([shoulder, elbow, at])
	draw_polyline(arm, Color("080e1c"), 6, false)
	draw_polyline(arm, Color("204977"), 4, false)
	draw_line(elbow + Vector2(0, -1), elbow.lerp(at, 0.7).round() + Vector2(0, -1), Color("367daf"), 1, false)
	draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("c29b78"))
	draw_rect(Rect2(at - Vector2(2, 2), Vector2(3, 1)), Color("efd2a0"))


func contact_shadow(at: Vector2, width: float) -> void:
	var half: int = floori(width / 2)
	draw_rect(Rect2(at + Vector2(-half, 0), Vector2(half * 2, 2)), Color(SHADOW_COLOR, 0.6))
	draw_rect(Rect2(at + Vector2(-half + 2, -1), Vector2(half * 2 - 4, 4)), Color(SHADOW_COLOR, 0.45))


func spark(at: Vector2, progress: float) -> void:
	var step: int = mini(2, floori(progress * 3))
	for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tip: Vector2 = at + offset * (2 + step * 2)
		draw_rect(Rect2(tip.round(), Vector2(2, 1)), Color("f2d493") if step < 2 else Color("ae7855"))


func dust(progress: float) -> void:
	for side in [-1, 1]:
		var x: int = side * (7 + floori(progress * 5))
		draw_rect(Rect2(x, -2, 4, 2), Color("7d7769"))
		draw_rect(Rect2(x + side * 2, -3, 2, 1), Color("a4997c"))


func barrel_debris(progress: float) -> void:
	var step: int = mini(3, floori(progress * 4))
	for index in range(6):
		var side: int = -1 if index % 2 == 0 else 1
		var x: int = side * (4 + step * (2 + floori(index / 2.0)))
		var y: int = -3 - int(sin(progress * PI) * (5 + index % 3 * 3))
		draw_rect(Rect2(x, y, 4 if index < 4 else 2, 2), Color("b7854d") if index < 4 else Color("829395"))
	if step < 3: dust(progress)
