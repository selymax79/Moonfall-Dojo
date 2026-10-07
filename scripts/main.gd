## Runs the single test encounter in an explicit order so simultaneous hits favour Player.
## Both actors share this scene's coordinate space; their scripts do not tick themselves.
extends Node2D

@onready var player = $Player
@onready var assassin = $Assassin


## Godot calls this at the fixed physics rate. Update both poses before testing their shapes.
func _physics_process(delta: float) -> void:
	player.advance_tick(delta)
	# Keep Player animating after the enemy's deferred removal has finished.
	if not is_instance_valid(assassin):
		return
	assassin.advance_tick(delta, player.position.x, player.is_dead)
	# Player hits always resolve first, including simultaneous valid strikes.
	player.resolve_attack(assassin)
	if not assassin.is_dead:
		assassin.resolve_attack(player)
