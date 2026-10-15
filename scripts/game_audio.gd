## Scene-local playback only: fixed voices, explicit game hooks, no gameplay clocks or RNG.
extends Node

const CLIPS = {
	"punch": preload("res://audio/sfx/punch.wav"),
	"kick": preload("res://audio/sfx/kick.wav"),
	"jump": preload("res://audio/sfx/jump.wav"),
	"duck": preload("res://audio/sfx/duck.wav"),
	"player_death": preload("res://audio/sfx/player_death.wav"),
	"red_attack": preload("res://audio/sfx/red_attack.wav"),
	"blue_attack": preload("res://audio/sfx/blue_attack.wav"),
	"red_defeated": preload("res://audio/sfx/red_defeated.wav"),
	"blue_defeated": preload("res://audio/sfx/blue_defeated.wav"),
	"barrel_roll": preload("res://audio/sfx/barrel_roll.wav"),
	"barrel_explosion": preload("res://audio/sfx/barrel_explosion.wav"),
	"shuriken_flight": preload("res://audio/sfx/shuriken_flight.wav"),
	"shuriken_impact": preload("res://audio/sfx/shuriken_impact.wav"),
	"menu_move": preload("res://audio/ui/menu_move.wav"),
	"menu_confirm": preload("res://audio/ui/menu_confirm.wav"),
	"pause": preload("res://audio/ui/pause.wav"),
	"game_over": preload("res://audio/ui/game_over.wav"),
	"level_up": preload("res://audio/ui/level_up.wav"),
	"high_score": preload("res://audio/ui/high_score.wav"),
	"title": preload("res://audio/music/title.wav"),
	"gameplay": preload("res://audio/music/gameplay.wav"),
}
var current_music: String = ""
# Web waits for one real input gesture; the single music voice retains the requested track.
var activated: bool = not OS.has_feature("web")
var browser_suspended := false
var death_started: bool = false
var result_played: bool = false
# A maximum of two unresolved hazards needs exactly two quiet looping voices.
var hazard_owners: Array[int] = [0, 0]
var next_impact: int = 0

@onready var music: AudioStreamPlayer = $Music
@onready var impacts: Array[AudioStreamPlayer] = [$ImpactA, $ImpactB]
@onready var hazards: Array[AudioStreamPlayer] = [$HazardA, $HazardB]

func _ready() -> void:
	for name in ["title", "gameplay", "barrel_roll", "shuriken_flight"]:
		var clip: AudioStreamWAV = CLIPS[name]
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_begin = 0
		clip.loop_end = roundi(clip.get_length() * clip.mix_rate)

func apply_volumes(music_volume: int, sfx_volume: int) -> void:
	for setting in [["Music", music_volume], ["SFX", sfx_volume]]:
		var index: int = AudioServer.get_bus_index(setting[0])
		var amount: float = clampf(float(setting[1]) / 100.0, 0.0, 1.0)
		AudioServer.set_bus_mute(index, amount == 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(amount) if amount > 0.0 else 0.0)

## Submenus keep the same stream/playhead; only entering a run or returning from death changes music.
func play_music(track: String) -> void:
	if not activated:
		current_music = track
		return
	if current_music == track and music.playing:
		return
	if track == "title":
		$System.stop() # A quick return from initials entry must not carry the Game Over sting into Title.
	music.stop()
	current_music = track
	music.stream = CLIPS[track]
	music.play()
	music.stream_paused = get_tree().paused or browser_suspended


func activate() -> void:
	if activated: return
	activated = true
	if not current_music.is_empty(): play_music(current_music)

func play_ui(cue: String) -> void:
	_play($UI, cue)

func play_action(action: int) -> void:
	if death_started:
		return
	# Player.Action order. These are movement/attack accents, not proof of a successful hit.
	var cues: Array[String] = ["", "punch", "kick", "duck", "jump"]
	if action > 0 and action < cues.size():
		_play($Player, cues[action])

func play_attack(kind: int) -> void:
	if not death_started:
		_play($Danger, "red_attack" if kind == 0 else "blue_attack")

func play_defeat(kind: int) -> void:
	play_impact("red_defeated" if kind == 0 else "blue_defeated")

## Two bounded voices let cosmetic impact and a successful strike coexist without cutting danger cues.
func play_impact(cue: String) -> void:
	if death_started:
		return
	var voice: AudioStreamPlayer = impacts[next_impact]
	for candidate in impacts:
		if not candidate.playing:
			voice = candidate
			break
	_play(voice, cue)
	next_impact = (impacts.find(voice) + 1) % impacts.size()

func play_level_up() -> void:
	if not death_started:
		# One system voice restarts the flourish instead of stacking rapid F4 presses.
		_play($System, "level_up")

func start_hazard(owner_id: int, kind: int) -> void:
	if death_started:
		return
	var index: int = hazard_owners.find(0)
	if index < 0:
		return
	hazard_owners[index] = owner_id
	_play(hazards[index], "barrel_roll" if kind == 2 else "shuriken_flight")

func stop_hazard(owner_id: int) -> void:
	var index: int = hazard_owners.find(owner_id)
	if index >= 0:
		hazards[index].stop()
		hazard_owners[index] = 0

## Death has priority over every approach/attack/cosmetic sound and stops music at lethal resolution.
func begin_death() -> void:
	if death_started:
		return
	death_started = true
	stop_all()
	_play($Player, "player_death")

func play_game_over() -> void:
	if result_played:
		return
	result_played = true
	_play($System, "game_over")

## Native pausing freezes playheads. Explicit stream pause also covers F4 starting a cue while paused.
## The always-processing UI voice alone may play the pause/unpause tone.
func set_game_paused(paused: bool) -> void:
	for voice in get_children():
		if voice != $UI:
			voice.stream_paused = paused or browser_suspended
	play_ui("pause")


## Background menus also go silent; returning to a paused run never resumes its voices.
func set_browser_suspended(suspended: bool) -> void:
	browser_suspended = suspended
	for voice in get_children():
		voice.stream_paused = suspended or (get_tree().paused and voice != $UI)

func stop_all() -> void:
	for voice in get_children():
		voice.stop()
	hazard_owners.assign([0, 0])
	current_music = ""

func _exit_tree() -> void:
	# Scene replacement owns every voice; explicitly release playback before the old scene is freed.
	stop_all()

func _play(voice: AudioStreamPlayer, cue: String) -> void:
	if not activated: return
	voice.stop()
	voice.stream = CLIPS[cue]
	voice.play()
	voice.stream_paused = browser_suspended or (get_tree().paused and voice != $UI)
