## Harmless five-pose assassin collapse, left behind when an assassin is defeated. Owned by the
## run, never registered with the scheduler, no collision. A fixed lifetime bounds node count;
## pause and scene replacement handle cleanup naturally.
extends Node2D

const NinjaAtlas = preload("res://scripts/ninja_atlas.gd")
# Presentation timing (seconds). Free to tweak: the corpse never affects gameplay.
const DURATION: float = 0.48
const SECONDS_PER_POSE: float = 0.08
const HIT_SPARK_DURATION: float = 0.12
const DUST_FROM: float = 0.24
const DUST_UNTIL: float = 0.36
# Red's dropped katana height for each of the five collapse poses.
const BLADE_HEIGHTS = [-24.0, -17.0, -8.0, -1.0, -1.0]

var texture: Texture2D
var facing: float = 1.0
var blue: bool = false
var elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var step: int = mini(4, floori(elapsed / SECONDS_PER_POSE))
	draw_rect(Rect2(-19, -1, 36, 3), Color(0.02, 0.03, 0.05, 0.5))
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	NinjaAtlas.draw_pose(self, texture, NinjaAtlas.COLLAPSE_FIRST + step)
	if not blue:
		# The dropped katana uses held positions and becomes part of the grounded aftermath.
		var blade_y: float = BLADE_HEIGHTS[step]
		draw_line(Vector2(10, blade_y), Vector2(34, blade_y + (3 if step < 3 else 0)), Color("82969e"), 1, false)
		draw_rect(Rect2(8, blade_y - 1, 2, 3), Color("b79b62"))
	if elapsed < HIT_SPARK_DURATION:
		var spread: int = 2 + floori(elapsed * 60)
		for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_rect(Rect2(Vector2(0, -21 if blue else -29) + direction * spread, Vector2(3, 2)), Color("f1d49b"))
	elif elapsed > DUST_FROM and elapsed < DUST_UNTIL:
		draw_rect(Rect2(-26, -2, 5, 2), Color("857761"))
		draw_rect(Rect2(15, -2, 5, 2), Color("857761"))
