extends Area2D


func receive_hit() -> void:
	if not is_queued_for_deletion():
		queue_free()
