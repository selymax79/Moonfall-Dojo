## Verification-only autoload for an isolated Web export/origin. Excluded by the shipping preset.
## Reads real runtime state; fixture awards exercise shared persistence without claiming human play.
extends Node

var callback: JavaScriptObject
var elapsed := 0.0
var frames := 0
var physics_ticks := 0
var peak_nodes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		callback = JavaScriptBridge.create_callback(command)
		JavaScriptBridge.get_interface("window").moonfallProbe = callback


func _process(delta: float) -> void:
	elapsed += delta
	frames += 1
	peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


func _physics_process(_delta: float) -> void:
	physics_ticks += 1


func command(arguments: Array) -> void:
	var main = get_tree().current_scene
	if main == null: return
	match str(arguments[0]):
		"award_four":
			for index in 4: main.award_successful_threat(main.ThreatType.BARREL)
		"qualifying_death":
			main.score = 999999
			main.player.receive_hit()
		"reset_metrics":
			elapsed = 0.0
			frames = 0
			physics_ticks = 0
			peak_nodes = 0
	var snapshot := {
		"state": main.game_state, "paused": get_tree().paused, "portrait": main.web_platform.portrait,
		"touch": main.touch_controls_enabled, "held": main.touch_overlay.fingers.size(),
		"action": main.player.current_action, "direction": main.player.target_direction,
		"dead": main.player.is_dead, "score": main.score, "level": main.level,
		"highest": main.records.highest_level, "entries": main.records.entries,
		"music_volume": main.records.music_volume, "sfx_volume": main.records.sfx_volume,
		"bindings": main.records.controls.bindings, "save_error": main.records.last_save_error,
		"audio_active": main.game_audio.activated, "music": main.game_audio.current_music,
		"music_playing": main.game_audio.music.playing, "music_paused": main.game_audio.music.stream_paused,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "peak_nodes": peak_nodes,
		"audio_voices": main.game_audio.get_child_count(), "time": elapsed, "frames": frames,
		"physics_ticks": physics_ticks, "clock": main.encounter_time,
		"persistent": OS.is_userfs_persistent(), "fps": Engine.get_frames_per_second(),
	}
	JavaScriptBridge.get_interface("window").moonfallSnapshot = JSON.stringify(snapshot)
