extends Node2D

const TURN_DURATION: float = 0.10

var target_direction: float = 1.0
var turn_progress: float = 1.0

@onready var visuals: Node2D = $Visuals


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("turn_left"):
		target_direction = -1.0
	elif event.is_action_pressed("turn_right"):
		target_direction = 1.0


func _process(delta: float) -> void:
	# Crossing from +1 to -1 takes one full turn; reversing keeps current progress.
	turn_progress = move_toward(turn_progress, target_direction, 2.0 * delta / TURN_DURATION)
	# Avoid a zero scale (a singular transform) at the turn's midpoint.
	var visible_width: float = maxf(absf(turn_progress), 0.05)
	visuals.scale.x = visible_width * (-1.0 if turn_progress < 0.0 else 1.0)
