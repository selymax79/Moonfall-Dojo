## Presentation only. Native pause freezes local clocks; this never reads or calls gameplay RNG.
extends Node2D

const PERSON = [preload("res://art/background/person_0.png"), preload("res://art/background/person_1.png")]
const DOG = [preload("res://art/background/dog_0.png"), preload("res://art/background/dog_1.png")]
const FLICKER = [0.72, 0.93, 0.80, 1.0, 0.86, 0.96, 0.78, 0.89]
const DOORS = [Rect2(116, 204, 88, 66), Rect2(436, 204, 88, 66)]
@export var cosmetic_seed: int = 270127
var cosmetic_rng := RandomNumberGenerator.new()
var ambient_time: float = 0.0
var bat_wait: float = 0.0
var bat_elapsed: float = -1.0
var bat_direction: int = 1
var bat_height: float = 44.0
var bat_count: int = 1
var door_wait: float = 0.0
var door_elapsed: float = -1.0
var door_index: int = 0
var door_direction: int = 1
var door_is_dog: bool = false

func _ready() -> void:
	cosmetic_rng.seed = cosmetic_seed
	bat_wait = cosmetic_rng.randf_range(16.0, 28.0)
	door_wait = cosmetic_rng.randf_range(10.0, 20.0)
	set_active(false)
	update_clouds()

func set_active(active: bool) -> void:
	visible = active
	set_physics_process(active)

func _physics_process(delta: float) -> void:
	ambient_time += delta
	update_clouds()
	if bat_elapsed >= 0.0:
		bat_elapsed += delta
		if bat_elapsed >= 7.5:
			bat_elapsed = -1.0
			bat_wait = cosmetic_rng.randf_range(22.0, 40.0)
	else:
		bat_wait -= delta
		if bat_wait <= 0.0:
			bat_elapsed = 0.0
			bat_direction = 1 if cosmetic_rng.randi_range(0, 1) == 0 else -1
			bat_height = cosmetic_rng.randf_range(28.0, 83.0)
			bat_count = cosmetic_rng.randi_range(1, 2)
	if door_elapsed >= 0.0:
		door_elapsed += delta
		if door_elapsed >= 9.0:
			door_elapsed = -1.0
			door_wait = cosmetic_rng.randf_range(18.0, 36.0)
	else:
		door_wait -= delta
		if door_wait <= 0.0:
			door_elapsed = 0.0
			door_index = cosmetic_rng.randi_range(0, 1)
			door_direction = 1 if cosmetic_rng.randi_range(0, 1) == 0 else -1
			door_is_dog = cosmetic_rng.randi_range(0, 2) == 0
	queue_redraw()

## Only clouds drift. Architecture stays fixed; different sky speeds provide depth without camera sway.
func update_clouds() -> void:
	for index in range(3):
		var far_cloud: Sprite2D = $FarClouds.get_child(index)
		var near_cloud: Sprite2D = $NearClouds.get_child(index)
		far_cloud.position = Vector2(floorf(fposmod(-60.0 + index * 310.0 + ambient_time * 1.6, 930.0) - 192.0), 29 + index % 2 * 8)
		near_cloud.position = Vector2(floorf(fposmod(602.0 + index * 330.0 - ambient_time * 3.1, 990.0) - 192.0), 55 + index % 2 * 12)

func _draw() -> void:
	draw_lamps()
	if bat_elapsed >= 0.0:
		for index in range(bat_count):
			var across: float = bat_elapsed * 100.0 - 40.0 - index * 18.0
			var x: float = across if bat_direction > 0 else 640.0 - across
			var y: float = bat_height + sin(bat_elapsed * 2.5 + index) * 3.0 + index * 7.0
			draw_bat(Vector2(floorf(x), floorf(y)), (floori(ambient_time * 7.0) + index) % 2 == 0)
	if door_elapsed >= 0.0:
		draw_door_activity()

func draw_bat(at: Vector2, wings_up: bool) -> void:
	var rise: int = -3 if wings_up else 2
	var ink := Color("060e1d")
	draw_rect(Rect2(at, Vector2(3, 3)), ink)
	draw_colored_polygon(PackedVector2Array([at, at + Vector2(-5, rise), at + Vector2(-3, 3), at + Vector2(1, 2)]), ink)
	draw_colored_polygon(PackedVector2Array([at + Vector2(2, 0), at + Vector2(7, rise), at + Vector2(5, 3), at + Vector2(2, 2)]), ink)

## Stepped modulation changes flame panes, short wall/frame shadows and floor glints together.
## No dynamic lights or shadow casting can change collision/readability in the centre lane.
func draw_lamps() -> void:
	for side in range(2):
		var x: float = 65.0 if side == 0 else 575.0
		var strength: float = FLICKER[(floori(ambient_time * 8.0) + side * 3) % FLICKER.size()]
		draw_rect(Rect2(x - 3, 217, 6, 11), Color(0.08, 0.025, 0.01, (1.0 - strength) * 0.75))
		draw_rect(Rect2(x - 1, 221 - floori(strength * 2), 2, 6), Color(1.0, 0.72, 0.24, strength * 0.55))
		var shadow: float = 6.0 + floorf(strength * 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 237), Vector2(x + 3, 237), Vector2(x + shadow, 254), Vector2(x - shadow, 254)]), Color(0.015, 0.025, 0.05, 0.12 + strength * 0.08))
		for row in range(3):
			draw_rect(Rect2(x - 12 + row * 3, 289 + row * 4, 25 - row * 5, 1), Color(0.95, 0.52, 0.18, strength * 0.23))
		var frame_x: float = 114.0 if side == 0 else 524.0
		draw_colored_polygon(PackedVector2Array([Vector2(frame_x, 236), Vector2(frame_x + 2, 236), Vector2(frame_x + 5 + floorf(strength * 2), 271), Vector2(frame_x + 2, 271)]), Color(0.025, 0.02, 0.025, 0.16 + strength * 0.12))

## Clip a small translucent figure into paper cells, leaving every foreground grid rail intact.
func draw_door_activity() -> void:
	var door: Rect2 = DOORS[door_index]
	var moving_time: float = door_elapsed - clampf(door_elapsed - 3.4, 0.0, 0.9)
	var progress: float = clampf(moving_time / 8.1, 0.0, 1.0)
	if door_direction < 0: progress = 1.0 - progress
	var frame: int = 0 if door_elapsed > 3.4 and door_elapsed < 4.3 else floori(ambient_time * 4.0) % 2
	var texture: Texture2D = DOG[frame] if door_is_dog else PERSON[frame]
	var actor := Rect2(Vector2(floorf(door.position.x - 24.0 + progress * 136.0), 268.0 - texture.get_height()), texture.get_size())
	# Coordinates follow the authored plate; this mask keeps the figures behind the shoji lattice.
	var columns: Array[int] = [0, 12, 24, 36, 47, 58, 69, 81, 88]
	var rows: Array[int] = [0, 11, 21, 31, 42, 53, 66]
	for column in range(columns.size() - 1):
		for row in range(rows.size() - 1):
			var pane := Rect2(door.position + Vector2(columns[column] + 1, rows[row] + 1), Vector2(columns[column + 1] - columns[column] - 2, rows[row + 1] - rows[row] - 2))
			var clipped: Rect2 = pane.intersection(actor)
			if clipped.has_area():
				draw_texture_rect_region(texture, clipped, Rect2(clipped.position - actor.position, clipped.size), Color(0.18, 0.15, 0.13, 0.46))
