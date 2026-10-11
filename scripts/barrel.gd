## A rolling floor obstacle. Main advances Player first, then movement and direct collision queries.
## Main never sends Player attacks here; it awards a Dodge and score once when safe passage completes.
## The scene's 7 px radius and 0.75 s Jump give about 195 ms of theoretical input opportunity at 60 px/s.
extends Area2D

# Cosmetic transition only; Main has already awarded the dodge and released gameplay ownership.
signal exploded

enum Phase { ACTIVE, DEPARTING, EXPLODING }
# Cosmetic clocks begin after gameplay resolution and never delay Main's next encounter.
const DEPARTURE_DURATION: float = 0.50
const EXPLOSION_DURATION: float = 0.40
var phase: Phase = Phase.ACTIVE
var effect_elapsed: float = 0.0

# Main supplies the same Level speed as Assassins before entering the tree.
var movement_speed: float = 60.0
# +1 enters from the right; -1 reflects the travel direction from the left.
var entry_side: int = 1
var is_complete: bool = false

@onready var body_shape: CollisionShape2D = $BodyShape
@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	# Main exclusively owns active movement; enable our tick only after releasing gameplay ownership.
	set_physics_process(false)


func configure_entry(side: int) -> void:
	assert(side == 1 or side == -1)
	entry_side = side


## Roll only the artwork: distance/radius gives the rotation without rotating the collision shape.
func advance_tick(delta: float) -> void:
	if is_complete:
		return
	roll(delta)


func roll(delta: float) -> void:
	var travel: float = -entry_side * movement_speed * delta
	position.x += travel
	visuals.rotation += travel / body_shape.shape.radius


## The adaptive Player rectangle decides survival, regardless of action or facing.
## Check damage before passage so a lethal collision cannot also complete the encounter.
func resolve_contact(player: Node2D) -> void:
	if is_complete or player.is_dead:
		return
	if body_shape.shape.collide(body_shape.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()
		return
	# Both actors use unscaled world-space collision shapes. Require the whole circle to pass
	# the far edge of Player's body, even if Player is still airborne when it gets there.
	var separation: float = entry_side * (body_shape.global_position.x - player.hurtbox.global_position.x)
	var passage_distance: float = body_shape.shape.radius + player.hurtbox.shape.size.x / 2.0
	if separation < -passage_distance:
		is_complete = true
		phase = Phase.DEPARTING
		# Defer handover so the resolving tick cannot move the Barrel twice.
		set_physics_process.call_deferred(true)


## This tick is presentation-only. Completion guards permanently exclude all further collision.
func _physics_process(delta: float) -> void:
	var remaining: float = delta
	if phase == Phase.DEPARTING:
		var step: float = minf(remaining, DEPARTURE_DURATION - effect_elapsed)
		roll(step)
		effect_elapsed += step
		remaining -= step
		if effect_elapsed < DEPARTURE_DURATION and not is_equal_approx(effect_elapsed, DEPARTURE_DURATION):
			return
		phase = Phase.EXPLODING
		effect_elapsed = 0.0
		visuals.hide()
		exploded.emit()
	if phase == Phase.EXPLODING:
		effect_elapsed = minf(effect_elapsed + remaining, EXPLOSION_DURATION)
		queue_redraw()
		if effect_elapsed >= EXPLOSION_DURATION or is_equal_approx(effect_elapsed, EXPLOSION_DURATION):
			queue_free()


## A few expanding sparks replace the Barrel; these draw commands create no collision objects.
func _draw() -> void:
	if phase != Phase.EXPLODING:
		return
	var progress: float = effect_elapsed / EXPLOSION_DURATION
	var centre := Vector2(0, -7)
	var colour := Color(1.0, 0.70, 0.25, 1.0 - progress)
	for index in range(6):
		var angle: float = TAU * index / 6.0
		var offset := Vector2(cos(angle), sin(angle)) * lerpf(3.0, 15.0, progress)
		draw_rect(Rect2(centre + offset - Vector2.ONE, Vector2(2, 2)), colour)
	draw_circle(centre, lerpf(4.0, 9.0, progress), Color(1.0, 0.9, 0.5, (1.0 - progress) * 0.6))
