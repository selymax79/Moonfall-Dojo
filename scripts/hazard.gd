## Shared behaviour for both hazards (Barrel, Shuriken). While active, Main moves the hazard and
## checks it against the Player each tick. Once it has fully passed, it hands itself over to its
## own harmless cosmetic tick (begin_aftermath) and Main awards the Dodge.
extends Area2D

# Main supplies the final speed once at spawn; later Level changes never alter it.
var movement_speed: float = 60.0
# +1 enters from the right; -1 from the left.
var entry_side: int = 1
# True once passage completes: no further collision, scoring or Main ownership.
var is_complete: bool = false

@onready var body_shape: CollisionShape2D = $BodyShape
@onready var visuals: Node2D = $Visuals


func _ready() -> void:
	# Main exclusively owns active movement; the cosmetic tick starts only after handover.
	set_physics_process(false)


func configure_entry(side: int) -> void:
	assert(side == 1 or side == -1)
	entry_side = side


## The Player's current hurtbox decides survival, whatever its action or facing.
## Damage is checked before passage, so a lethal collision can never also count as a Dodge.
func resolve_contact(player: Node2D) -> void:
	if is_complete or player.is_dead:
		return
	if body_shape.shape.collide(body_shape.global_transform, player.hurtbox.shape, player.hurtbox.global_transform):
		player.receive_hit()
		return
	# The whole shape must clear the far edge of the Player's body, even mid-jump.
	var separation: float = entry_side * (body_shape.global_position.x - player.hurtbox.global_position.x)
	var passage_distance: float = body_shape.shape.radius + player.hurtbox.shape.size.x / 2.0
	if separation < -passage_distance:
		is_complete = true
		begin_aftermath()
		# Defer the handover so the resolving tick cannot move the hazard twice.
		set_physics_process.call_deferred(true)


## Called once when passage completes; each hazard starts its cosmetic phase here.
func begin_aftermath() -> void:
	pass
