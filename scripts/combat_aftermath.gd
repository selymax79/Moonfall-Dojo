## Harmless five-pose assassin collapse. Owned by the run, never registered with the scheduler.
## A fixed lifetime bounds node count; pause and scene replacement handle cleanup naturally.
extends Node2D

var texture: Texture2D
var facing: float = 1.0
var blue: bool = false
var elapsed: float = 0.0
const DURATION: float = 0.48

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
	var frame: int = 27+mini(4,floori(elapsed/0.08))
	draw_rect(Rect2(-19,-1,36,3),Color(0.02,0.03,0.05,0.5))
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	draw_texture_rect_region(texture,Rect2(-40,-48,96,56),Rect2(frame%8*96,floori(frame/8.0)*56,96,56))
	if not blue:
		# The dropped katana uses held positions and becomes part of the grounded aftermath.
		var blade_y: float = [-24.0,-17.0,-8.0,-1.0,-1.0][frame-27]
		draw_line(Vector2(10,blade_y),Vector2(34,blade_y+(3 if frame < 30 else 0)),Color("82969e"),1,false)
		draw_rect(Rect2(8,blade_y-1,2,3),Color("b79b62"))
	if elapsed < 0.12:
		var spread: int = 2+floori(elapsed*60)
		for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			draw_rect(Rect2(Vector2(0,-21 if blue else -29)+direction*spread,Vector2(3,2)),Color("f1d49b"))
	elif elapsed > 0.24 and elapsed < 0.36:
		draw_rect(Rect2(-26,-2,5,2),Color("857761"))
		draw_rect(Rect2(15,-2,5,2),Color("857761"))
