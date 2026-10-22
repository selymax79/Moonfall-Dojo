## Red Assassin: carries a katana, so it must be Kicked. Approach, wind-up, strike and retry
## timing come from assassin.gd; this script adds the stop distance and the moving sword.
extends "res://scripts/assassin.gd"

# Logical pixels. Stopping 38 px away puts the body's near edge 30 px out: inside Kick's 36 px
# reach, beyond Punch's 25.5 px. Changing it changes which response wins, so re-run
# press_window_verify.gd (threat_timing.gd reads this value).
const ATTACK_DISTANCE: float = 38.0
# Sword animation: it draws back during the wind-up, thrusts over THRUST_DURATION of STRIKE,
# then returns during recovery. These positions decide when the blade first touches the Player
# (threat_timing.gd BLADE_CONTACT_DELAY).
const THRUST_DURATION: float = 0.168
const SWORD_DRAW_BACK: float = 24.0
const SWORD_THRUST_END: float = -4.0

@onready var sword: Node2D = $Sword
@onready var blade_shape: CollisionShape2D = $Sword/Attack/BladeShape


func stop_distance() -> float:
	return ATTACK_DISTANCE


func weapon_shape() -> CollisionShape2D:
	return blade_shape


## Move the shared sword parent so the visible blade and its collision shape stay aligned.
## Drawing back before thrusting gives visible travel before contact, not a hidden grace period.
func update_pose() -> void:
	match phase:
		Phase.WINDUP:
			sword.position.x = lerpf(0.0, SWORD_DRAW_BACK, phase_elapsed / windup_duration)
		Phase.STRIKE:
			sword.position.x = lerpf(SWORD_DRAW_BACK, SWORD_THRUST_END, minf(phase_elapsed / THRUST_DURATION, 1.0))
		Phase.RECOVERY:
			sword.position.x = lerpf(SWORD_THRUST_END, 0.0, phase_elapsed / RECOVERY_DURATION)
		_:
			sword.position.x = 0.0
