## Layout of the three ninja pose atlases (art/combat/player.png, red.png, blue.png). Each holds
## the same 32-pose catalogue in 8 columns; tools/build_combat_art.gd generates them in this
## order. Shared by live actors (combat_art.gd) and corpses (combat_aftermath.gd).
extends RefCounted

const CELL := Vector2(96, 56)
const COLUMNS: int = 8
# Where a cell is drawn relative to the actor's feet (feet sit 8 px above the cell's bottom).
const DRAW_RECT := Rect2(-40, -48, 96, 56)

# Pose indices in the catalogue.
const IDLE := 0 # 0 and 1 alternate as a breathing idle.
const TURN := 2
const PUNCH_WIND := 3
const PUNCH_REACH := 4
const PUNCH_HIT := 5
const PUNCH_FOLD := 6
const KICK_CHAMBER := 7
const KICK_RISE := 8
const KICK_HIT := 9
const KICK_FOLD := 10
const JUMP_TAKEOFF := 11
const JUMP_RISE := 12
const JUMP_FALL := 13
const JUMP_LANDING := 14
const CROUCH_TRANSITION := 15 # Player duck in/out; Blue's crouch.
const CROUCH_LOW := 16
const CROUCH_RISE := 17
const RUN_FIRST := 18 # 18-21: four-step run cycle (assassins).
const RED_WINDUP := 22
const RED_STRIKE := 23
const RED_RECOVERY := 24
const BLUE_GUARD := 25
const BLUE_STRIKE := 26
const COLLAPSE_FIRST := 27 # 27-31: five-pose collapse; 29 begins the low (crouched) collapse.
const COLLAPSE_LOW := 29
const COLLAPSE_LAST := 31


## Draws one pose at the canvas's current transform (set it first to mirror or lift).
static func draw_pose(canvas: CanvasItem, texture: Texture2D, pose: int) -> void:
	var cell_origin := Vector2(pose % COLUMNS, floori(pose / float(COLUMNS))) * CELL
	canvas.draw_texture_rect_region(texture, DRAW_RECT, Rect2(cell_origin, CELL))
