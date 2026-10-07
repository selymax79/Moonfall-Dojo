extends Node2D

@onready var player = $Player
@onready var assassin = $RedAssassin


func _physics_process(delta: float) -> void:
	player.advance_tick(delta)
	if not is_instance_valid(assassin):
		return
	assassin.advance_tick(delta, player.position.x, player.is_dead)
	# Player hits always resolve first, including simultaneous valid strikes.
	player.resolve_attack(assassin)
	if not assassin.is_dead:
		assassin.resolve_attack(player)
