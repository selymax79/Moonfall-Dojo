## Local records, audio and controls, shared across Main replacements without an autoload.
extends RefCounted

const SAVE_PATH: String = "user://high_score.cfg"
const TABLE_SIZE: int = 10
const DEFAULT_MUSIC_VOLUME: int = 70
const DEFAULT_SFX_VOLUME: int = 80
var entries: Array[Dictionary] = []
var highest_level: int = 1
var music_volume: int = DEFAULT_MUSIC_VOLUME
var sfx_volume: int = DEFAULT_SFX_VOLUME
var save_data := ConfigFile.new()
var controls = preload("res://scripts/control_bindings.gd").new()
var last_save_error: Error = OK


func load_records() -> void:
	entries.clear()
	highest_level = 1
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	save_data = ConfigFile.new()
	controls.load_bindings(null)
	if save_data.load(SAVE_PATH) != OK:
		save_data = ConfigFile.new()
		return
	controls.load_bindings(save_data.get_value("controls", "bindings", {}))
	var saved_entries: Variant = save_data.get_value("scores", "entries", [])
	if saved_entries is Array:
		for entry in saved_entries:
			if entry is Dictionary and valid_score(entry.get("score")):
				insert_sorted({"initials": sanitise_initials(entry.get("initials")), "score": entry.score})
	var saved_level: Variant = save_data.get_value("progress", "highest_level", 1)
	if typeof(saved_level) == TYPE_INT and saved_level >= 1:
		highest_level = saved_level
	music_volume = sanitise_volume(save_data.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME), DEFAULT_MUSIC_VOLUME)
	sfx_volume = sanitise_volume(save_data.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME), DEFAULT_SFX_VOLUME)
	# An explicit entries key, even an empty table, is authoritative. Never re-import it each launch.
	if not save_data.has_section_key("scores", "entries"):
		var legacy: Variant = save_data.get_value("scores", "high_score", 0)
		if valid_score(legacy) and legacy > 0:
			insert_sorted({"initials": "AAA", "score": legacy})
			save_records()


## Numeric settings clamp before conversion; invalid types/non-finite values use sensible defaults.
func sanitise_volume(value: Variant, fallback: int) -> int:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)):
		return roundi(clampf(float(value), 0.0, 100.0))
	return fallback


func set_audio_volume(music_setting: bool, amount: int) -> void:
	amount = clampi(amount, 0, 100)
	if music_setting:
		if music_volume == amount: return
		music_volume = amount
	else:
		if sfx_volume == amount: return
		sfx_volume = amount
	save_records()


func valid_score(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0


func sanitise_initials(value: Variant) -> String:
	var cleaned := ""
	if value is String:
		for character in value.to_upper():
			if (character >= "A" and character <= "Z") or (character >= "0" and character <= "9"):
				cleaned += character
	return (cleaned + "AAA").substr(0, 3)


func get_high_score() -> int:
	return 0 if entries.is_empty() else int(entries[0].score)


func qualifies(final_score: int) -> bool:
	return final_score >= 0 and (entries.size() < TABLE_SIZE or final_score > int(entries.back().score))


## Strictly greater insertion keeps earlier equal scores first, including while repairing loaded data.
func insert_sorted(entry: Dictionary) -> void:
	var index: int = 0
	while index < entries.size() and int(entries[index].score) >= int(entry.score):
		index += 1
	entries.insert(index, entry)
	if entries.size() > TABLE_SIZE:
		entries.resize(TABLE_SIZE)


func submit_score(initials: String, final_score: int) -> void:
	if not qualifies(final_score):
		return
	insert_sorted({"initials": sanitise_initials(initials), "score": final_score})
	save_records()


## Main calls this after each success with the run's current, always-earned Level.
func unlock_level(earned_level: int) -> void:
	if earned_level > highest_level:
		highest_level = earned_level
		save_records()


## Confirmed binding edits use the same atomic save as records and audio.
func save_controls() -> void:
	save_data.set_value("controls", "bindings", controls.bindings)
	save_records()


## Preserve unrelated sections; replace only after a complete write succeeds.
## Failed writes leave the previous file intact and retain settings in memory for this session.
func save_records() -> void:
	save_data.set_value("scores", "entries", entries)
	save_data.set_value("progress", "highest_level", highest_level)
	save_data.set_value("audio", "music_volume", music_volume)
	save_data.set_value("audio", "sfx_volume", sfx_volume)
	if save_data.has_section_key("scores", "high_score"):
		save_data.erase_section_key("scores", "high_score")
	var temporary_path: String = SAVE_PATH + ".tmp"
	var error: Error = save_data.save(temporary_path)
	if error == OK:
		error = DirAccess.rename_absolute(temporary_path, SAVE_PATH)
	if error != OK:
		push_warning("Could not save run records to %s: %s" % [SAVE_PATH, error_string(error)])
	last_save_error = error
