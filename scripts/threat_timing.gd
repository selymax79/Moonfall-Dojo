## Timing maths behind the fair scheduler. For a threat spawned at time 0 moving at a given speed:
## - lethal_lead(): when it can first touch a standing Player;
## - press_window(): the earliest and latest moment its intended response can be pressed and win.
## Pure functions with no scene access, so Main and the regression suites share one formula.
##
## Player timings come straight from player.gd. The geometry below mirrors the actor scenes;
## tools/regression/press_window_verify.gd checks these values against the real scenes and
## simulates presses across every window, so retuning a scene must update this file too.
extends RefCounted

const PlayerScript = preload("res://scripts/player.gd")
const RedScript = preload("res://scripts/red_assassin.gd")
const BlueScript = preload("res://scripts/blue_assassin.gd")
const ShurikenScript = preload("res://scripts/shuriken.gd")

# Same order as Main.ThreatType.
enum { RED, BLUE, BARREL, SHURIKEN }

# Threats spawn at x=560 (Main.THREAT_START_POSITION) or its mirror; Player stands at x=320.
const SPAWN_DISTANCE: float = 240.0
# player.tscn Hurtbox/Body is 16 x 40 with its feet on the floor at y=300.
const PLAYER_HALF_WIDTH: float = 8.0
const PLAYER_HEIGHT: float = 40.0
const FLOOR_Y: float = 300.0
# Red and Blue Hurtboxes are 16 px wide.
const ASSASSIN_HALF_WIDTH: float = 8.0
# Far edges of player.tscn AttackShapes/Kick (14..36 px) and AttackShapes/Punch (6..25.5 px).
const KICK_REACH: float = 36.0
const PUNCH_REACH: float = 25.5
# From STRIKE start, Red's moving blade first touches a standing Player after 0.09 s, Blue's fist after 0.08 s.
const BLADE_CONTACT_DELAY: float = 0.09
const FIST_CONTACT_DELAY: float = 0.08
# barrel.tscn BodyShape radius (it rolls on the floor) and shuriken.tscn BodyShape radius.
const BARREL_RADIUS: float = 9.0
const SHURIKEN_RADIUS: float = 4.0


## Full committed length of each intended response, in ThreatType order.
static func response_duration(threat_type: int) -> float:
	match threat_type:
		RED: return player_action_duration(PlayerScript.Action.KICK)
		BLUE: return player_action_duration(PlayerScript.Action.PUNCH)
		BARREL: return player_action_duration(PlayerScript.Action.JUMP)
		SHURIKEN: return player_action_duration(PlayerScript.Action.DUCK)
	return 0.0


## Committed length of any Player action (Player.Action order). NONE is zero.
static func player_action_duration(action: int) -> float:
	if action == PlayerScript.Action.PUNCH:
		return PlayerScript.PUNCH_EXTENSION_DURATION + PlayerScript.PUNCH_HOLD_DURATION + PlayerScript.PUNCH_RECOVERY_DURATION
	if action == PlayerScript.Action.KICK:
		return PlayerScript.KICK_EXTENSION_DURATION + PlayerScript.KICK_HOLD_DURATION + PlayerScript.KICK_RECOVERY_DURATION
	if action == PlayerScript.Action.DUCK:
		return PlayerScript.DUCK_CROUCH_DURATION + PlayerScript.DUCK_HOLD_DURATION + PlayerScript.DUCK_RECOVERY_DURATION
	if action == PlayerScript.Action.JUMP:
		return PlayerScript.JUMP_DURATION
	return 0.0


## Seconds from spawn until first possible contact with a standing Player.
## Assassins move at full speed through their wind-up, so its length never changes this.
static func lethal_lead(threat_type: int, speed: float) -> float:
	match threat_type:
		RED: return (SPAWN_DISTANCE - RedScript.ATTACK_DISTANCE) / speed + BLADE_CONTACT_DELAY
		BLUE: return (SPAWN_DISTANCE - BlueScript.ATTACK_DISTANCE) / speed + FIST_CONTACT_DELAY
		BARREL: return (SPAWN_DISTANCE - PLAYER_HALF_WIDTH - BARREL_RADIUS) / speed
		SHURIKEN: return (SPAWN_DISTANCE - PLAYER_HALF_WIDTH - SHURIKEN_RADIUS) / speed
	return 0.0


## (earliest, latest) press time after spawn for which the intended response wins, assuming
## the Player faces the right way and is free to act. Derived conservatively from geometry:
## pressing anywhere inside it succeeds; some presses just outside may also succeed.
static func press_window(threat_type: int, speed: float) -> Vector2:
	match threat_type:
		RED:
			return attack_window(RedScript.ATTACK_DISTANCE, BLADE_CONTACT_DELAY, KICK_REACH,
					PlayerScript.KICK_EXTENSION_DURATION, PlayerScript.KICK_HOLD_DURATION, speed)
		BLUE:
			return attack_window(BlueScript.ATTACK_DISTANCE, FIST_CONTACT_DELAY, PUNCH_REACH,
					PlayerScript.PUNCH_EXTENSION_DURATION, PlayerScript.PUNCH_HOLD_DURATION, speed)
		BARREL:
			return evade_window(BARREL_RADIUS, jump_clear_interval(), speed)
		SHURIKEN:
			return evade_window(SHURIKEN_RADIUS, duck_clear_interval(), speed)
	return Vector2.ZERO


## The attack must be active at some moment after the assassin's body enters reach and no later
## than its weapon's first contact (a same-tick clash goes to the Player).
static func attack_window(stop_distance: float, contact_delay: float, reach: float,
		extension: float, hold: float, speed: float) -> Vector2:
	var strike_start: float = (SPAWN_DISTANCE - stop_distance) / speed
	# The body's near edge enters reach this long before it stops at stop_distance.
	var in_reach_at: float = strike_start - (reach + ASSASSIN_HALF_WIDTH - stop_distance) / speed
	return Vector2(in_reach_at - (extension + hold), strike_start + contact_delay - extension)


## The hazard overlaps the Player's x-range for 2 * (half-width + radius) / speed around its
## centre arrival; that whole passage must fall inside the action's clearance interval.
static func evade_window(radius: float, clear: Vector2, speed: float) -> Vector2:
	var centre_arrival: float = SPAWN_DISTANCE / speed
	var half_passage: float = (PLAYER_HALF_WIDTH + radius) / speed
	return Vector2(centre_arrival + half_passage - clear.y, centre_arrival - half_passage - clear.x)


## Seconds after pressing Jump during which the Player's feet are above a floor-rolling Barrel.
static func jump_clear_interval() -> Vector2:
	# Height follows 4 * H * p * (1 - p); solve for the two moments it equals the Barrel diameter.
	var root: float = sqrt(1.0 - 2.0 * BARREL_RADIUS / PlayerScript.JUMP_HEIGHT)
	return Vector2((1.0 - root) / 2.0, (1.0 + root) / 2.0) * PlayerScript.JUMP_DURATION


## Seconds after pressing Duck during which the shrinking hurtbox's top is below the Shuriken.
static func duck_clear_interval() -> Vector2:
	# Height scale below which the head clears the Shuriken's lowest point.
	var clear_scale: float = (FLOOR_Y - ShurikenScript.FLIGHT_HEIGHT - SHURIKEN_RADIUS) / PLAYER_HEIGHT
	var squash: float = 1.0 - PlayerScript.DUCK_HEIGHT_SCALE
	var down: float = PlayerScript.DUCK_CROUCH_DURATION * (1.0 - clear_scale) / squash
	var up: float = PlayerScript.DUCK_CROUCH_DURATION + PlayerScript.DUCK_HOLD_DURATION \
			+ PlayerScript.DUCK_RECOVERY_DURATION * (clear_scale - PlayerScript.DUCK_HEIGHT_SCALE) / squash
	return Vector2(down, up)
