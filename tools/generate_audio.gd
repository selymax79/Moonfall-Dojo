## Offline authoring: Godot --headless --path . --script res://tools/generate_audio.gd
## Original physical layers and a shared musical theme; never loaded by the game.
extends SceneTree

const RATE: int = 22050
# D, E, F, A, Bb: a dark five-note vocabulary shared by music and UI phrases.
const THEME: Array[int] = [62, 69, 70, 69, 65, 64, 62]
var noise := RandomNumberGenerator.new()

func _init() -> void:
	noise.seed = 260226
	for folder in ["sfx", "ui", "music"]:
		DirAccess.make_dir_recursive_absolute("res://audio/" + folder)
	write_player()
	write_assassins()
	write_hazards()
	write_ui()
	write_music("music/title", 92.0, false)
	write_music("music/gameplay", 132.0, true)
	print("Generated 21 original FM/string/wood/steel/formant assets; deterministic seed 260226.")
	quit()

## Punch is a dry mid-body snap. Kick has its own cloth, membrane and low-body recipe.
## They accent an accepted action; the separate defeat clips confirm actual contact.
func write_player() -> void:
	var punch := blank(0.120)
	layer(punch, make_noise_burst(0.024, 950, 4700), 0.0, 0.65)
	layer(punch, make_body_hit(0.090, 225), 0.002, 0.85)
	layer(punch, make_taiko_hit(0.065, 95), 0.0, 0.22)
	save_wave("sfx/punch", punch, 0.52)

	var kick := blank(0.210)
	layer(kick, make_air_slice(0.060, 350, 2200), 0.0, 0.22)
	layer(kick, make_taiko_hit(0.175, 64), 0.004, 1.0)
	layer(kick, make_body_hit(0.150, 128), 0.005, 0.60)
	layer(kick, make_noise_burst(0.037, 700, 3400), 0.004, 0.48)
	save_wave("sfx/kick", kick, 0.55)

	var jump := blank(0.150)
	layer(jump, make_air_slice(0.110, 500, 2600), 0.0, 0.65)
	layer(jump, make_wood_crack(0.036, 190), 0.0, 0.15)
	save_wave("sfx/jump", jump, 0.24)
	var duck := blank(0.110)
	layer(duck, make_air_slice(0.090, 260, 1500), 0.0, 0.80)
	layer(duck, make_noise_burst(0.025, 180, 650), 0.005, 0.15)
	save_wave("sfx/duck", duck, 0.13)

	var death := blank(0.390)
	layer(death, make_body_hit(0.160, 145), 0.0, 0.9)
	layer(death, make_noise_burst(0.050, 600, 3900), 0.0, 0.55)
	layer(death, make_taiko_hit(0.270, 48), 0.006, 0.85)
	# One short open-vowel cry above the body impact; duration still ends before Game Over.
	layer(death, make_grunt(0.305, 156, true), 0.020, 1.25)
	save_wave("sfx/player_death", death, 0.55)

func write_assassins() -> void:
	var red := blank(0.185)
	layer(red, make_noise_burst(0.052, 1800, 5800), 0.0, 0.36)
	layer(red, make_metal_hit(0.105, 1580), 0.0, 0.45)
	layer(red, make_air_slice(0.150, 1100, 4800), 0.006, 0.55)
	save_wave("sfx/red_attack", red, 0.48)
	var red_fall := blank(0.250)
	layer(red_fall, make_body_hit(0.135, 165), 0.0, 0.85)
	layer(red_fall, make_noise_burst(0.030, 750, 3200), 0.0, 0.32)
	layer(red_fall, make_metal_hit(0.085, 1150), 0.045, 0.36)
	layer(red_fall, make_metal_hit(0.055, 860), 0.130, 0.14)
	layer(red_fall, make_wood_crack(0.070, 175), 0.150, 0.18)
	layer(red_fall, make_grunt(0.190, 139, false), 0.012, 1.05)
	save_wave("sfx/red_defeated", red_fall, 0.52)

	var blue := blank(0.155)
	layer(blue, make_air_slice(0.120, 280, 1900), 0.0, 0.8)
	layer(blue, make_body_hit(0.090, 175), 0.0, 0.35)
	layer(blue, make_noise_burst(0.025, 550, 2100), 0.005, 0.2)
	save_wave("sfx/blue_attack", blue, 0.48)
	var blue_fall := blank(0.230)
	layer(blue_fall, make_body_hit(0.190, 118), 0.0, 1.0)
	layer(blue_fall, make_taiko_hit(0.125, 78), 0.0, 0.5)
	layer(blue_fall, make_noise_burst(0.042, 400, 2200), 0.0, 0.38)
	layer(blue_fall, make_air_slice(0.080, 180, 800), 0.110, 0.18)
	layer(blue_fall, make_grunt(0.175, 122, false), 0.010, 1.0)
	save_wave("sfx/blue_defeated", blue_fall, 0.52)

func write_hazards() -> void:
	# Irregular stave contacts, with occasional quiet hoops; no sustained motor oscillator.
	var roll := blank(1.600)
	var knocks: Array = [[0.01, 164, 0.70], [0.19, 132, 0.48], [0.43, 188, 0.62],
		[0.72, 145, 0.54], [0.91, 205, 0.32], [1.18, 157, 0.67], [1.43, 126, 0.42]]
	for knock in knocks:
		layer(roll, make_wood_crack(0.075, knock[1]), knock[0], knock[2])
		layer(roll, make_noise_burst(0.090, 120, 750), knock[0], 0.15)
	layer(roll, make_metal_hit(0.075, 640), 0.48, 0.07)
	layer(roll, make_metal_hit(0.060, 750), 1.24, 0.05)
	save_wave("sfx/barrel_roll", roll, 0.34)

	var burst := blank(0.380)
	layer(burst, make_taiko_hit(0.250, 52), 0.0, 1.0)
	layer(burst, make_noise_burst(0.115, 180, 3400), 0.002, 0.58)
	for crack in [[0.0, 310, 0.85], [0.021, 440, 0.70], [0.057, 240, 0.63],
			[0.104, 380, 0.42], [0.162, 190, 0.25]]:
		layer(burst, make_wood_crack(0.085, crack[1]), crack[0], crack[2])
	layer(burst, make_metal_hit(0.085, 680), 0.195, 0.16)
	layer(burst, make_wood_crack(0.040, 290), 0.290, 0.10)
	save_wave("sfx/barrel_explosion", burst, 0.55)

	# Fixed-frequency, fast-decaying steel ticks between dry air cuts. No vibrato/pitch LFO.
	# A quiet tick repeats with the existing loop; no new launch event or runtime hook is needed.
	var flight := blank(1.250)
	for slice in [[0.0, 0.70], [0.19, 0.45], [0.405, 0.58], [0.61, 0.40], [0.805, 0.52], [1.025, 0.44]]:
		layer(flight, make_air_slice(0.115, 1900, 4600), slice[0], slice[1])
	layer(flight, make_metal_hit(0.030, 2350), 0.003, 0.12)
	layer(flight, make_metal_hit(0.025, 2100), 0.430, 0.07)
	layer(flight, make_metal_hit(0.022, 2450), 0.870, 0.05)
	save_wave("sfx/shuriken_flight", flight, 0.26)
	var clink := blank(0.140)
	layer(clink, make_metal_hit(0.078, 2100), 0.0, 0.75)
	layer(clink, make_metal_hit(0.035, 1430), 0.048, 0.18)
	layer(clink, make_wood_crack(0.045, 330), 0.001, 0.42)
	save_wave("sfx/shuriken_impact", clink, 0.40)

func write_ui() -> void:
	save_wave("ui/menu_move", make_wood_crack(0.055, 620), 0.30)
	var confirm := blank(0.115)
	layer(confirm, make_plucked_tone(0.110, THEME[0]), 0.0, 0.7)
	layer(confirm, make_wood_crack(0.030, 540), 0.0, 0.30)
	save_wave("ui/menu_confirm", confirm, 0.36)
	var pause_cue := blank(0.140)
	layer(pause_cue, make_wood_crack(0.050, 460), 0.0, 0.6)
	layer(pause_cue, make_plucked_tone(0.085, 57), 0.050, 0.4)
	save_wave("ui/pause", pause_cue, 0.30)
	write_phrase("ui/level_up", [62, 65, 69, 74], [0.0, 0.105, 0.210, 0.330], 0.650, false)
	write_phrase("ui/high_score", [62, 69, 70, 69, 74], [0.0, 0.10, 0.20, 0.30, 0.43], 0.760, false)
	write_phrase("ui/game_over", [70, 69, 65, 62], [0.0, 0.18, 0.36, 0.59], 1.050, true)

func write_phrase(path: String, notes: Array, times: Array, duration: float, dark: bool) -> void:
	var phrase := blank(duration)
	for index in range(notes.size()):
		var tail: float = minf(0.35, duration - times[index])
		layer(phrase, make_plucked_tone(tail, notes[index] - (12 if dark else 0)), times[index], 0.65)
	if dark:
		layer(phrase, make_fm_bass(0.440, 38), 0.590, 0.55)
	else:
		layer(phrase, make_wood_crack(0.050, 420), 0.0, 0.12)
	save_wave(path, phrase, 0.46)

## Two arrangements of the same explicit call/answer. Beat positions leave room for combat SFX.
## Title is spacious; gameplay shortens notes and adds bass/taiko syncopation, not a busy lead.
func write_music(path: String, bpm: float, urgent: bool) -> void:
	var beat: float = 60.0 / bpm
	var song := blank(32.0 * beat)
	var phrases: Array = [
		[[0.0, THEME[0]], [1.5, THEME[1]], [2.5, THEME[2]], [3.25, THEME[3]]],
		[[0.5, THEME[4]], [2.0, THEME[5]], [3.0, THEME[6]]],
		[[0.0, 57], [1.5, 62], [2.5, 65]],
		[[0.0, 64], [1.5, 62]],
		[[0.0, THEME[0]], [1.5, THEME[1]], [2.5, THEME[2]], [3.25, THEME[3]]],
		[[0.5, THEME[4]], [2.0, THEME[5]], [3.0, THEME[6]]],
		[[0.0, 65], [1.5, 64], [2.5, 57]],
		[[0.0, 62], [2.5, 57]]]
	var roots: Array[int] = [38, 38, 34, 33, 38, 41, 34, 38]
	for bar in range(8):
		var start: float = bar * 4.0 * beat
		for note in phrases[bar]:
			var pluck := make_dojo_string(beat * (1.05 if urgent else 1.65), note[1])
			layer(song, pluck, start + note[0] * beat, 0.22 if urgent else 0.28, true)
			# A quiet, filtered answer gives the pluck room without a wash over combat cues.
			layer(song, soften(pluck), start + (note[0]+0.375) * beat, 0.045, true)
		var bass_beats: Array = [0.0, 0.75, 1.5, 2.0, 2.75, 3.5] if urgent else [0.0, 2.5]
		for index in range(bass_beats.size()):
			var accent: float = 0.48 if index == 0 else 0.32
			layer(song, make_fm_bass(beat * (0.45 if urgent else 1.1), roots[bar]),
				start + bass_beats[index] * beat, accent, true)
		layer(song, make_taiko_hit(0.260, 58), start, 0.68 if urgent else 0.40, true)
		if urgent:
			layer(song, make_taiko_hit(0.170, 93), start + 1.5 * beat, 0.40, true)
			layer(song, make_taiko_hit(0.220, 68), start + 2.75 * beat, 0.52, true)
		elif bar % 2 == 1:
			layer(song, make_taiko_hit(0.170, 88), start + 3.0 * beat, 0.22, true)
		for tap in ([1.0, 2.5, 3.25] if urgent else [1.5, 3.5]):
			layer(song, make_wood_crack(0.045, 720 if urgent else 570), start + tap * beat,
				0.13 if urgent else 0.07, true)
		# Bell occupies only two phrase openings; no constant high-frequency hat/lead bed.
		if bar in [0, 4]:
			layer(song, make_metal_hit(0.65, 1174.66), start, 0.065, true)
		if urgent and bar in [3, 7]:
			layer(song, make_fm_bass(0.160, 50), start + 3.5 * beat, 0.16, true)
		# Slow two-bar beds connect the sparse phrases. Their tails wrap through the loop seam.
		if bar % 2 == 0:
			layer(song, make_drone(beat*9.0, roots[bar]+12), start, 0.09 if urgent else 0.12, true)
		# A single high string response in the second half, leaving the main motif recognisable.
		if bar in [5,7]:
			layer(song, make_dojo_string(beat*1.8, 81 if bar == 5 else 74), start+3.0*beat, 0.055, true)
	# The title's sustained layers raise average energy; lower its ceiling to retain the old level.
	save_wave(path, song, 0.50 if urgent else 0.44)

## A few voiced harmonics shaped around vowel resonances suggest a sampled arcade grunt.
## This is original offline synthesis, not a recording or a runtime voice system; no RNG draws.
func make_grunt(duration: float, pitch: float, cry: bool) -> PackedFloat32Array:
	var sound := blank(duration)
	var phase := 0.0
	for frame in range(sound.size()):
		var t: float = float(frame)/RATE
		var progress: float = t/duration
		var fundamental: float = pitch*(1.08-0.27*progress)+2.0*sin(TAU*31*t)
		phase += TAU*fundamental/RATE
		var vowel := 0.0
		var first: float = lerpf(760.0 if cry else 610.0, 460.0, progress)
		for harmonic in range(1,25):
			var frequency: float = fundamental*harmonic
			var weight: float = 0.28*exp(-pow((frequency-first)/180.0,2))
			weight += 0.16*exp(-pow((frequency-1120.0)/230.0,2))
			weight += 0.045*exp(-pow((frequency-2450.0)/360.0,2))
			vowel += sin(phase*harmonic)*weight
		var breath: float = sin(phase*17.31)*sin(phase*9.77)*0.045
		var shape: float = pow(sin(PI*progress),0.8)*minf(t/0.010,1.0)
		sound[frame] = tanh((vowel+breath)*1.6)*shape*(1.0-0.38*progress)
	return sound

## Inharmonic pick/body over a stable string fundamental: restrained synthetic koto colour.
func make_dojo_string(duration: float, note: int) -> PackedFloat32Array:
	var sound := blank(duration)
	for frame in range(sound.size()):
		var t: float = float(frame)/RATE
		var phase: float = TAU*hz(note)*t
		var value: float = sin(phase)*exp(-t/(duration*0.4))
		value += 0.45*sin(phase*2.003)*exp(-t/0.13)
		value += 0.27*sin(phase*3.009)*exp(-t/0.055)
		value += 0.13*sin(phase*5.021)*exp(-t/0.018)
		sound[frame] = value*minf(t/0.0015,1.0)*clampf((duration-t)/0.012,0,1)
	return sound

func soften(source: PackedFloat32Array) -> PackedFloat32Array:
	var sound := source.duplicate()
	var previous := 0.0
	for frame in range(sound.size()):
		previous = lerpf(previous, sound[frame], 0.18)
		sound[frame] = previous
	return sound

## Gentle attack/release and wrapped placement keep the held fifths seamless at file boundaries.
func make_drone(duration: float, note: int) -> PackedFloat32Array:
	var sound := blank(duration)
	for frame in range(sound.size()):
		var t: float = float(frame)/RATE
		var fade: float = minf(t/0.7,1.0)*minf((duration-t)/0.8,1.0)
		var phase: float = TAU*hz(note)*t
		sound[frame] = (sin(phase)*0.65+sin(phase*1.5)*0.20+sin(phase*2)*0.10)*fade
	return sound

func blank(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(roundi(duration * RATE))
	return samples

func hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

## Every one-shot fades at its endpoints; wrapping layers preserve musical tails across loop seams.
func envelope(t: float, duration: float, attack: float, decay: float) -> float:
	return minf(t / attack, 1.0) * exp(-t / decay) * clampf((duration - t) / 0.008, 0.0, 1.0)

func layer(target: PackedFloat32Array, sound: PackedFloat32Array, at: float, gain: float, wrap: bool = false) -> void:
	var start: int = roundi(at * RATE)
	for frame in range(sound.size()):
		var dest: int = start + frame
		if wrap: dest %= target.size()
		if dest < target.size(): target[dest] += sound[frame] * gain

## Low two-operator FM, fast index decay: crunchy articulation over a stable pitched body.
func make_fm_bass(duration: float, note: int) -> PackedFloat32Array:
	var sound := blank(duration)
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		var phase: float = TAU * hz(note) * t
		var tone: float = 0.80 * sin(phase + 1.65 * exp(-t / 0.030) * sin(phase * 2.0))
		tone += 0.18 * sin(phase * 2.0) * exp(-t / 0.060)
		sound[frame] = tanh(tone * 1.5) * envelope(t, duration, 0.002, duration * 0.55)
	return sound

## Stretched membrane modes plus a brief settling pitch transient; no spring-like oscillation.
func make_taiko_hit(duration: float, fundamental: float) -> PackedFloat32Array:
	var sound := blank(duration)
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		var phase: float = TAU * (fundamental * t + 0.60 * (1.0 - exp(-t / 0.012)))
		var body: float = sin(phase) + 0.24 * sin(phase * 1.58) * exp(-t / 0.040)
		sound[frame] = body * envelope(t, duration, 0.001, duration * 0.30)
	return sound

## Non-metallic, heavily damped low-mid resonances for flesh/cloth contact.
func make_body_hit(duration: float, fundamental: float) -> PackedFloat32Array:
	var sound := blank(duration)
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		var phase: float = TAU * fundamental * t
		var body: float = sin(phase) + 0.35 * sin(phase * 1.47) + 0.18 * sin(phase * 2.12)
		sound[frame] = body * envelope(t, duration, 0.0007, duration * 0.20)
	return sound

## Inharmonic steel modes have fixed pitch and independent decay. No LFO, siren or pitch sweep.
func make_metal_hit(duration: float, fundamental: float) -> PackedFloat32Array:
	var sound := blank(duration)
	var ratios: Array[float] = [1.0, 1.43, 2.17, 2.91]
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		var metal: float = 0.0
		for mode in range(ratios.size()):
			metal += sin(TAU * fundamental * ratios[mode] * t) * exp(-t / (duration * (0.24 - mode * 0.04))) / (1.0 + mode)
		sound[frame] = metal * minf(t / 0.0006, 1.0) * clampf((duration - t) / 0.008, 0, 1)
	return sound

## Wood is a short hollow resonance plus splinter noise, not a pitched electronic pop.
func make_wood_crack(duration: float, fundamental: float) -> PackedFloat32Array:
	var sound := make_noise_burst(duration, 700, 4200)
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		var wood: float = sin(TAU * fundamental * t) + 0.45 * sin(TAU * fundamental * 2.67 * t)
		sound[frame] = 0.50 * sound[frame] + wood * envelope(t, duration, 0.0007, duration * 0.16)
	return sound

## Difference of two one-pole low-pass filters makes a bounded noise band; never a tonal sweep.
func make_noise_burst(duration: float, low_hz: float, high_hz: float) -> PackedFloat32Array:
	var sound := band_noise(duration, low_hz, high_hz)
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		sound[frame] *= envelope(t, duration, 0.0006, duration * 0.19)
	return sound

func make_air_slice(duration: float, low_hz: float, high_hz: float) -> PackedFloat32Array:
	var sound := band_noise(duration, low_hz, high_hz)
	for frame in range(sound.size()):
		var progress: float = float(frame) / sound.size()
		sound[frame] *= pow(sin(PI * progress), 1.7)
	return sound

func band_noise(duration: float, low_hz: float, high_hz: float) -> PackedFloat32Array:
	var sound := blank(duration)
	var slow: float = 0.0
	var fast: float = 0.0
	var slow_amount: float = 1.0 - exp(-TAU * low_hz / RATE)
	var fast_amount: float = 1.0 - exp(-TAU * high_hz / RATE)
	for frame in range(sound.size()):
		var value: float = noise.randf_range(-1.0, 1.0)
		slow = lerpf(slow, value, slow_amount)
		fast = lerpf(fast, value, fast_amount)
		sound[frame] = (fast - slow) * 2.0
	return sound

## Bright pick at onset, then a dry string body; a synthetic koto/shamisen suggestion, not emulation.
func make_plucked_tone(duration: float, note: int) -> PackedFloat32Array:
	var sound := blank(duration)
	for frame in range(sound.size()):
		var t: float = float(frame) / RATE
		var phase: float = TAU * hz(note) * t
		var pick: float = sin(phase + 2.7 * exp(-t / 0.018) * sin(phase * 3.0))
		var string_body: float = 0.28 * sin(phase * 2.0) * exp(-t / 0.090)
		string_body += 0.12 * sin(phase * 3.0) * exp(-t / 0.045)
		sound[frame] = (pick + string_body) * envelope(t, duration, 0.001, duration * 0.25)
	return sound

## Remove DC, lightly colour the mix and leave explicit peak headroom; quiet actions stay quiet.
## The existing bus/voice gains remain untouched. Loop endpoints are authored, never crossfaded in-game.
func save_wave(path: String, samples: PackedFloat32Array, target_peak: float) -> void:
	var mean: float = 0.0
	for sample in samples: mean += sample
	mean /= samples.size()
	var peak: float = 0.00001
	for frame in range(samples.size()):
		samples[frame] = snappedf(tanh((samples[frame] - mean) * 1.15), 1.0 / 8192.0)
		peak = maxf(peak, absf(samples[frame]))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for frame in range(samples.size()):
		bytes.encode_s16(frame * 2, roundi(samples[frame] / peak * target_peak * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.data = bytes
	var error: Error = wave.save_to_wav("res://audio/" + path + ".wav")
	assert(error == OK, "Could not write " + path)
