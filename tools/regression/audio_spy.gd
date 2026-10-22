extends "res://scripts/game_audio.gd"
var events: Array = []
var music_starts: Array[String] = []
func _play(voice: AudioStreamPlayer, cue: String) -> void:
	events.append([cue, String(voice.name)])
	super._play(voice, cue)
func play_music(track: String) -> void:
	if current_music != track or not music.playing: music_starts.append(track)
	super.play_music(track)
func count(cue: String) -> int:
	var total := 0
	for event in events:
		if event[0] == cue: total += 1
	return total
