## Read-only presentation for the five existing actors. No animation callback can change combat.
## Fixed atlas poses follow gameplay clocks; the independent clock is only for idle/rolling detail.
extends Node2D

const NINJAS = [preload("res://art/combat/player.png"), preload("res://art/combat/red.png"), preload("res://art/combat/blue.png")]
const BARREL = preload("res://art/combat/barrel.png")
const STAR = preload("res://art/combat/shuriken.png")
const AFTERMATH = preload("res://scripts/combat_aftermath.gd")
@export_enum("Player", "Red", "Blue", "Barrel", "Shuriken") var kind: int = 0
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
	process_physics_priority = 100 # Main's movement/combat tick runs before presentation.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.ready.connect(update_pose,CONNECT_ONE_SHOT)

func _physics_process(delta: float) -> void:
	elapsed += delta
	dust_left = maxf(0.0,dust_left-delta)
	update_pose()

func update_pose() -> void:
	if kind == 0:
		facing = actor.target_direction
		lift = actor.visuals.position.y if not actor.is_dead else lerpf(actor.death_start_position.y,0.0,minf(actor.death_elapsed/actor.DEATH_DURATION,1.0))
		frame = floori(elapsed*2.0)%2
		if actor.is_dead:
			# Start a crouched death low instead of suddenly standing to enter the collapse strip.
			var first: int = 29 if actor.death_start_scale.y < 0.75 else 27
			frame = first+mini(31-first,floori(actor.death_elapsed/actor.DEATH_DURATION*(32-first)))
		else:
			var time: float = actor.action_elapsed
			match actor.current_action:
				actor.Action.NONE:
					if absf(actor.turn_progress) < 0.8: frame = 2
				actor.Action.PUNCH:
					if time < actor.PUNCH_EXTENSION_DURATION:
						frame = 3 if time < 0.03 else 4
					elif time < actor.PUNCH_EXTENSION_DURATION + actor.PUNCH_HOLD_DURATION:
						frame = 5
					else:
						# Retract through the extension pose, fold the elbow, then settle into guard.
						var recovery: float = (time-actor.PUNCH_EXTENSION_DURATION-actor.PUNCH_HOLD_DURATION)/actor.PUNCH_RECOVERY_DURATION
						frame = 4 if recovery < 0.25 else (6 if recovery < 0.75 else 1)
				actor.Action.KICK:
					if time < actor.KICK_EXTENSION_DURATION:
						frame = 7 if time < 0.04 else 8
					elif time < actor.KICK_EXTENSION_DURATION + actor.KICK_HOLD_DURATION:
						frame = 9
					else:
						var recovery: float = (time-actor.KICK_EXTENSION_DURATION-actor.KICK_HOLD_DURATION)/actor.KICK_RECOVERY_DURATION
						frame = 8 if recovery < 0.25 else (10 if recovery < 0.75 else 1)
				actor.Action.JUMP:
					# Keep authored pose phases aligned when the deterministic arc duration is tuned.
					var progress: float = time / actor.JUMP_DURATION
					frame = 11 if progress < 0.10 else (12 if progress < 2.0/3.0 else (13 if progress < 0.68/0.75 else 14))
				actor.Action.DUCK:
					# Select genuine crouch poses, never vertically scale a standing sprite.
					var height: float = actor.hurtbox.shape.size.y
					frame = 16 if height <= 23.0 else (15 if time < 0.08 else 17)
			var jumping: bool = actor.current_action == actor.Action.JUMP
			if was_jumping and not jumping: dust_left = 0.12
			was_jumping = jumping
	elif kind < 3:
		# Assassin roots already mirror gameplay children; the atlas is authored facing right.
		facing = -1.0
		frame = 18+posmod(floori(actor.position.x/4.0),4)
		if actor.phase != actor.Phase.APPROACH:
			if kind == 1:
				frame = 22 if actor.phase == actor.Phase.WINDUP else (23 if actor.phase == actor.Phase.STRIKE else 24)
			else:
				frame = 15 if actor.crouch_elapsed < actor.CROUCH_DURATION else (26 if actor.phase == actor.Phase.STRIKE else 25)
	elif kind == 3:
		# Signed distance/radius: rightward travel rolls clockwise, leftward anticlockwise.
		# Round around each authored pose so either direction switches at the same distance.
		frame = posmod(roundi(actor.visuals.rotation/(PI/4.0)),8)
	else:
		frame = posmod(floori(actor.visuals.rotation/(PI/4.0)),4)
	queue_redraw()

## Called before the assassin is removed. The corpse has no actor reference or collision shapes.
func leave_corpse() -> void:
	var corpse := Node2D.new()
	corpse.set_script(AFTERMATH)
	corpse.texture = NINJAS[kind]
	corpse.position = actor.position
	corpse.facing = -float(actor.entry_side)
	corpse.blue = kind == 2
	actor.get_parent().add_child(corpse)

func _draw() -> void:
	if not actor.is_node_ready(): return
	if kind < 3:
		var shadow_width: float = 16.0
		if kind == 0: shadow_width = 16.0-maxf(0.0,-lift)/11.0
		contact_shadow(Vector2.ZERO,shadow_width)
		draw_set_transform(Vector2(0,roundf(lift)),0,Vector2(facing,1))
		draw_texture_rect_region(NINJAS[kind],Rect2(-40,-48,96,56),Rect2(frame%8*96,floori(frame/8.0)*56,96,56))
		draw_set_transform(Vector2.ZERO)
		if kind == 1: draw_blade()
		if kind == 2: draw_low_fist()
		if kind == 0:
			if dust_left > 0: dust(1.0-dust_left/0.12)
			if actor.is_dead and actor.death_elapsed < 0.08: spark(Vector2(0,lift-22),actor.death_elapsed/0.08)
	elif kind == 3:
		if actor.phase != actor.Phase.EXPLODING:
			contact_shadow(Vector2.ZERO,19)
			draw_texture_rect_region(BARREL,Rect2(-10,-19,20,20),Rect2(frame*20,0,20,20))
		else: barrel_debris(actor.effect_elapsed/actor.EXPLOSION_DURATION)
	else:
		var settled: bool = actor.phase == actor.Phase.SETTLED
		draw_texture_rect_region(STAR,Rect2(-4,-4,8,8),Rect2((0 if settled else frame)*8,0,8,8))
		if settled: spark(Vector2(0,3),actor.effect_elapsed/actor.SETTLE_DURATION)

## Follow the actual collision parent's continuous translation, snapped only for raster display.
func draw_blade() -> void:
	var x: float = roundf(actor.sword.position.x)
	var steel := Color("bccdd0") if actor.phase == actor.Phase.STRIKE else Color("82969e")
	draw_rect(Rect2(x-39,-24,26,2),steel)
	draw_rect(Rect2(x-38,-24,24,1),Color("e5e4c9"))
	draw_rect(Rect2(x-14,-26,2,6),Color("b79b62"))
	draw_rect(Rect2(x-12,-24,6,3),Color("292c38"))
	# Shoulder, bent elbow and wrist follow the weapon without moving its collision parent.
	var elbow := Vector2(lerpf(-10,9,clampf((x+4)/28.0,0,1)),-20)
	draw_polyline(PackedVector2Array([Vector2(-3,-27),elbow,Vector2(x-9,-23)]),Color("080e1c"),6,false)
	draw_polyline(PackedVector2Array([Vector2(-3,-27),elbow,Vector2(x-9,-23)]),Color("742a3b"),4,false)
	draw_line(elbow,elbow.lerp(Vector2(x-9,-23),0.65).round(),Color("bb4050"),1,false)
	draw_rect(Rect2(x-10,-24,3,3),Color("c29b78"))

func draw_low_fist() -> void:
	if actor.phase == actor.Phase.APPROACH: return
	var at: Vector2 = actor.fist.position.round()
	var shoulder := Vector2(-2,-18 if frame == 15 else -15)
	var elbow := Vector2(-7,at.y+1)
	draw_polyline(PackedVector2Array([shoulder,elbow,at]),Color("080e1c"),6,false)
	draw_polyline(PackedVector2Array([shoulder,elbow,at]),Color("204977"),4,false)
	draw_line(elbow+Vector2(0,-1),elbow.lerp(at,0.7).round()+Vector2(0,-1),Color("367daf"),1,false)
	draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("c29b78"))
	draw_rect(Rect2(at-Vector2(2,2),Vector2(3,1)),Color("efd2a0"))

func contact_shadow(at: Vector2, width: float) -> void:
	var half: int = floori(width/2)
	draw_rect(Rect2(at+Vector2(-half,0),Vector2(half*2,2)),Color(0.025,0.035,0.065,0.6))
	draw_rect(Rect2(at+Vector2(-half+2,-1),Vector2(half*2-4,4)),Color(0.025,0.035,0.065,0.45))

func spark(at: Vector2, progress: float) -> void:
	var step: int = mini(2,floori(progress*3))
	for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var tip: Vector2 = at+offset*(2+step*2)
		draw_rect(Rect2(tip.round(),Vector2(2,1)),Color("f2d493") if step < 2 else Color("ae7855"))

func dust(progress: float) -> void:
	for side in [-1,1]:
		var x: int = side*(7+floori(progress*5))
		draw_rect(Rect2(x,-2,4,2),Color("7d7769"))
		draw_rect(Rect2(x+side*2,-3,2,1),Color("a4997c"))

func barrel_debris(progress: float) -> void:
	var step: int = mini(3,floori(progress*4))
	for index in range(6):
		var side: int = -1 if index%2 == 0 else 1
		var x: int = side*(4+step*(2+floori(index/2.0)))
		var y: int = -3-int(sin(progress*PI)*(5+index%3*3))
		draw_rect(Rect2(x,y,4 if index < 4 else 2,2),Color("b7854d") if index < 4 else Color("829395"))
	if step < 3: dust(progress)
