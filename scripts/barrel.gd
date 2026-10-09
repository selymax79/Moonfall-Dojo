## A rolling floor obstacle. Main advances Player first, then movement and direct collision queries.
## It is not an Assassin: Main never sends Player attacks here, and passage awards no points yet.
## The scene's 4 px radius preserves roughly 176 ms of Jump input opportunity at 60 px/s.
extends Area2D

# Main supplies the same Level speed as Assassins before entering the tree.
var movement_speed: float = 60.0
# +1 enters from the right; -1 reflects the travel direction from the left.
var entry_side: int = 1
var is_complete: bool = false

@onready var body_shape: CollisionShape2D = $BodyShape
@onready var visuals: Node2D = $Visuals


func configure_entry(side: int) -> void:
	assert(side == 1 or side == -1)
	entry_side = side


## Roll only the artwork: distance/radius gives the rotation without rotating the collision shape.
func advance_tick(delta: float) -> void:
	if is_complete:
		return
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
		queue_free()
