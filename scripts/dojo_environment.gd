## The moonlit dojo backdrop: drifting clouds, flickering lamps, and occasional bats and shoji
## silhouettes. Presentation only: it has its own seeded RNG and clock, never touches gameplay,
## and pauses with the game.
extends Node2D

const PERSON = [preload("res://art/combat/adult_0.png"), preload("res://art/combat/adult_1.png"), preload("res://art/combat/adult_2.png"), preload("res://art/combat/adult_3.png"), preload("res://art/combat/adult_4.png")]
const DOG = [preload("res://art/combat/dog_0.png"), preload("res://art/combat/dog_1.png"), preload("res://art/combat/dog_2.png"), preload("res://art/combat/dog_3.png")]
const SHADOWS = [preload("res://art/combat/lamp_shadow_0.png"), preload("res://art/combat/lamp_shadow_1.png"), preload("res://art/combat/lamp_shadow_2.png")]
# Three held light/shadow states, with a deliberately uneven eight-beat cadence.
const FLICKER = [0, 2, 1, 2, 1, 2, 0, 1]
const FLICKER_STEPS_PER_SECOND: float = 8.0

# TUNING (all cosmetic). Seconds unless noted.
# Cloud drift in logical px/s; the far bank moves right, the near bank left.
const FAR_CLOUD_SPEED: float = 1.6
const NEAR_CLOUD_SPEED: float = 3.1
# Bats: one or two cross the sky; waits are random ranges between crossings.
const BAT_FIRST_WAIT := Vector2(16.0, 28.0)
const BAT_REPEAT_WAIT := Vector2(22.0, 40.0)
const BAT_CROSSING_DURATION: float = 7.5
const BAT_SPEED: float = 100.0 # px/s
const BAT_HEIGHT_RANGE := Vector2(28.0, 83.0)
# Shoji silhouettes: a person (or, one time in three, a dog) crosses one door with a pause.
const DOOR_FIRST_WAIT := Vector2(10.0, 20.0)
const DOOR_REPEAT_WAIT := Vector2(18.0, 36.0)
const DOOR_EVENT_DURATION: float = 9.0
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
	bat_wait = cosmetic_rng.randf_range(BAT_FIRST_WAIT.x, BAT_FIRST_WAIT.y)
	door_wait = cosmetic_rng.randf_range(DOOR_FIRST_WAIT.x, DOOR_FIRST_WAIT.y)
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
		if bat_elapsed >= BAT_CROSSING_DURATION:
			bat_elapsed = -1.0
			bat_wait = cosmetic_rng.randf_range(BAT_REPEAT_WAIT.x, BAT_REPEAT_WAIT.y)
	else:
		bat_wait -= delta
		if bat_wait <= 0.0:
			bat_elapsed = 0.0
			bat_direction = 1 if cosmetic_rng.randi_range(0, 1) == 0 else -1
			bat_height = cosmetic_rng.randf_range(BAT_HEIGHT_RANGE.x, BAT_HEIGHT_RANGE.y)
			bat_count = cosmetic_rng.randi_range(1, 2)
	if door_elapsed >= 0.0:
		door_elapsed += delta
		if door_elapsed >= DOOR_EVENT_DURATION:
			door_elapsed = -1.0
			door_wait = cosmetic_rng.randf_range(DOOR_REPEAT_WAIT.x, DOOR_REPEAT_WAIT.y)
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
		far_cloud.position = Vector2(floorf(fposmod(-60.0 + index * 310.0 + ambient_time * FAR_CLOUD_SPEED, 930.0) - 192.0), 29 + index % 2 * 8)
		near_cloud.position = Vector2(floorf(fposmod(602.0 + index * 330.0 - ambient_time * NEAR_CLOUD_SPEED, 990.0) - 192.0), 55 + index % 2 * 12)

func _draw() -> void:
	draw_lamps()
	if bat_elapsed >= 0.0:
		for index in range(bat_count):
			var across: float = bat_elapsed * BAT_SPEED - 40.0 - index * 18.0
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

## Three authored cage/timber shadow sprites follow the same stepped lamp cadence.
## This is a local cast-shadow accent, not a dynamic light or gameplay mask.
func draw_lamps() -> void:
	for side in range(2):
		draw_set_transform(Vector2(640, 0) if side == 1 else Vector2.ZERO, 0, Vector2(-1, 1) if side == 1 else Vector2.ONE)
		var x: float = 65.0
		var state: int = FLICKER[(floori(ambient_time * FLICKER_STEPS_PER_SECOND) + side * 3) % FLICKER.size()]
		var strength: float = [0.70, 0.85, 1.0][state]
		draw_texture(SHADOWS[state], Vector2(x - 26, 217), Color(1, 1, 1, 0.26))
		draw_rect(Rect2(x - 3, 217, 6, 11), Color(0.08, 0.025, 0.01, (1.0 - strength) * 0.75))
		draw_rect(Rect2(x - 1, 221 - floori(strength * 2), 2, 6), Color(1.0, 0.72, 0.24, strength * 0.55))
		for row in range(3):
			draw_rect(Rect2(x - 12 + row * 3, 289 + row * 4, 25 - row * 5, 1), Color(0.95, 0.52, 0.18, strength * 0.23))
	draw_set_transform(Vector2.ZERO)

## Clip a small translucent figure into paper cells, leaving every foreground grid rail intact.
func draw_door_activity() -> void:
	var door: Rect2 = DOORS[door_index]
	var moving_time: float = door_elapsed - clampf(door_elapsed - 3.4, 0.0, 0.9)
	var progress: float = clampf(moving_time / 8.1, 0.0, 1.0)
	var resting: bool = door_elapsed > 3.4 and door_elapsed < 4.3
	var frame: int = floori(moving_time * 6.0) % 4
	if resting: frame = 0 if door_is_dog else 4
	var texture: Texture2D = DOG[frame] if door_is_dog else PERSON[frame]
	# Two-pixel travel steps accompany the small walk/trot cycle; a separate pose holds the pause.
	var actor := Rect2(Vector2(door.position.x - 24.0 + floorf(progress * 68.0) * 2.0, 268.0 - texture.get_height()), texture.get_size())
	if door_direction < 0: draw_set_transform(Vector2(door.get_center().x * 2, 0), 0, Vector2(-1, 1))
	# Coordinates follow the authored plate; this mask keeps the figures behind the shoji lattice.
	var columns: Array[int] = [0, 12, 24, 36, 47, 58, 69, 81, 88]
	var rows: Array[int] = [0, 11, 21, 31, 42, 53, 66]
	for column in range(columns.size() - 1):
		for row in range(rows.size() - 1):
			var pane := Rect2(door.position + Vector2(columns[column] + 1, rows[row] + 1), Vector2(columns[column + 1] - columns[column] - 2, rows[row + 1] - rows[row] - 2))
			var clipped: Rect2 = pane.intersection(actor)
			if clipped.has_area():
				draw_texture_rect_region(texture, clipped, Rect2(clipped.position - actor.position, clipped.size), Color(0.18, 0.15, 0.13, 0.46))
	draw_set_transform(Vector2.ZERO)
