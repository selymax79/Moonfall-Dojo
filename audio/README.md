# Original dojo audio — listening acceptance pending

The 21 assets share one authored palette: low FM/membrane weight, midrange wood/body/string
and brief high steel/noise. All sounds are original offline synthesis, without external samples
or copied melodies. The sonic targets below describe design intent, not a claim of listening approval.

## Regeneration and generator structure

[generate_audio.gd](../tools/generate_audio.gd) has explicit Player, Assassin, hazard, UI and
music recipes. They combine named physical layers: `make_fm_bass`, `make_taiko_hit`,
`make_body_hit`, `make_metal_hit`, `make_wood_crack`, `make_air_slice`,
`make_noise_burst` and `make_plucked_tone`.

From the project root:

```powershell
& 'C:/Users/myles/OneDrive/Desktop/GODOT/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/generate_audio.gd
```

Open/import the project in Godot afterwards to refresh the imported samples. Generation uses
a private RNG seeded to 260226, never gameplay RNG. Layer placement is sample-based. Noise
bands use the difference of two low-pass filters; metal uses fixed, inharmonic decaying modes;
wood adds splinter noise to short hollow resonances. The string has a bright FM pick transient
that decays into a dry harmonic body. Taiko-like weight uses a settling membrane, while FM
bass keeps stable pitch and a quickly decaying modulation index. No runtime synthesis is used.

Output is mono 22,050 Hz / 16-bit PCM, with mild saturation and 1/8192 amplitude steps.
All source WAVs total 1,912,890 bytes (~1.82 MiB). DC is removed before encoding.
Peak ceilings are asset-specific (0.13–0.55), keeping cloth and flight deliberately quieter
instead of normalising everything to equal loudness. Godot import metadata uses QOA compression.

## Musical theme

The five-note vocabulary is D, E, F, A, Bb, used for a dark Japanese-inspired plucked motif.
This is a synthetic evocation, not a traditional-instrument or console-hardware emulation.

The shared call is **D4–A4–Bb4–A4**, answered by **F4–E4–D4**. The call enters on beats
0, 1.5, 2.5 and 3.25; the answer on 0.5, 2 and 3 of the next bar. A lower response completes
four bars; the second four bars restate the call and vary the ending. Deliberate rests leave
room for combat. Harmonic support centres on D with Bb, A and F bass changes.

- **Title:** eight bars at 92 BPM, ~20.87 s. Sparse bass pulses, longer dry plucks, restrained
  low percussion and only two bell accents evoke anticipation before battle.
- **Gameplay:** the same eight-bar melody at 132 BPM, ~14.55 s. Shorter plucks leave room for
  denser syncopated bass, stronger low drums, woodblock accents and two brief low FM stabs.
  It is a different arrangement of the theme, not a pitch/speed-shifted recording.
- **Level-up:** D–F–A–D, a rising expansion of the theme.
- **Initials confirmation:** D–A–Bb–A–D, retaining the call's characteristic neighbour note.
- **Game Over:** Bb–A–F–D one octave lower, with a low D at the ending.

No constant hi-hat bed, busy high lead, wide vibrato or adaptive arrangement is used.
Music note tails wrap at the file boundary; runtime playback loops the full file.

## Asset roles

Every name below is a WAV in the stated folder, with matching Godot import metadata.

| Folder / asset | Duration | Authored layers and intended identity |
| --- | --- | --- |
| `sfx/punch` | 120 ms | Short noise crack, 225 Hz body smack, tiny low support: dry “PAK”. |
| `sfx/kick` | 210 ms | Cloth cut, 64 Hz membrane, 128 Hz body and sharp snap: heavier “WHUMP/KRAK”; independent recipe. |
| `sfx/jump` | 150 ms | Quiet cloth/air movement and small wooden push-off, without a cartoon chirp. |
| `sfx/duck` | 110 ms | Very quiet filtered cloth/foot scuff; peak 0.13. |
| `sfx/player_death` | 390 ms | Hard body/noise hit, settling low membrane and brief semitone FM tension. |
| `sfx/red_attack` | 185 ms | Steel transient, scrape noise and high air cut at the existing strike event. |
| `sfx/red_defeated` | 250 ms | Body impact, two short sword clatters and a subdued floor contact. |
| `sfx/blue_attack` | 155 ms | Lower cloth/body whoosh, with no metal component. |
| `sfx/blue_defeated` | 230 ms | Damped low body hit, membrane weight and soft cloth collapse. |
| `sfx/barrel_roll` | 1.60 s loop | Seven uneven stave knocks/rattles and two quiet hoop contacts; no sustained rumble. |
| `sfx/barrel_explosion` | 380 ms | Low thump, five staggered wood cracks, rapidly decaying blast, hoop and fragment contacts. |
| `sfx/shuriken_flight` | 1.25 s loop | Six dry band-limited air cuts and three tiny fixed-pitch steel ticks; no pitch LFO/siren. |
| `sfx/shuriken_impact` | 140 ms | Thin steel clink, a lower second contact and a short wooden undertone. |
| `ui/menu_move` | 55 ms | Muted wooden click. |
| `ui/menu_confirm` | 115 ms | D pluck with restrained wood attack. |
| `ui/pause` | 140 ms | Wood tap and low A pluck. |
| `ui/level_up` | 650 ms | Rising thematic plucked phrase. |
| `ui/high_score` | 760 ms | Thematic initials confirmation. |
| `ui/game_over` | 1.05 s | Descending low plucks resolving over dark FM bass. |
| `music/title` | ~20.87 s loop | Sparse eight-bar preparation theme. |
| `music/gameplay` | ~14.55 s loop | Urgent eight-bar variation with space for SFX. |

Shuriken's tiny initial steel tick also repeats as part of the quiet loop; it does not add a
separate launch event. Its air texture has no continuous pitched oscillator. Barrel cracks
occur at 0/21/57/104/162 ms after its existing explosion event, with small later debris sounds.
These are layers inside the WAV, not changes to simulation timers or gameplay hooks.

## Playback and mix

[game_audio.gd](../scripts/game_audio.gd), its hooks and the scene's gains are unchanged by
this sound-design pass. [main.tscn](../scenes/main.tscn) defines nine bounded voices. Music uses
Music; other voices use SFX. Both feed Master at -6 dB in
[default_bus_layout.tres](../default_bus_layout.tres).

Per-voice gains remain: Danger -5, Player -6, impacts -8, Music/System -10, UI -12 and hazard
loops -25 dB. Settings remain Music 70 / SFX 80 by default; zero mutes, 100 is reference level.
At these source peak ceilings, even a conservative simultaneous peak sum of all nine voices
at 100/100 stays below full scale before import rounding. No bus or playback-gain changes
are needed for numerical headroom; subjective masking still needs listening.

Spectral intent: music is mainly low/mid bass and percussion with sparse plucks; Red uses
brief upper steel, Blue lower body, Punch mid snap, Kick low-mid weight, Shuriken light
air/metal and Barrel uneven low-mid wood. No stereo positioning was added: assets remain
mono, preserving the accepted playback architecture.

Death priority, exactly-once triggers, pause/resume, scene-owned restart cleanup and settings
persistence remain as implemented. This pass changes asset timbre, arrangement and duration.

## Manual listening acceptance — required again

The previous integration was accepted by the user, but its sound design was rejected.
Milestone 26 remains **MANUAL ACCEPTANCE PENDING** for these replacements; do not advance 27.

Listen in-game with normal audio output and the default settings, then at a higher Level:

- Shuriken should read as steel cutting air, never a UFO, laser or piercing whistle.
- Barrel should roll as uneven wood and break with weight and multiple fragments, never a balloon pop.
- Punch/Kick and Red/Blue should be identifiable without watching.
- Title/gameplay should share a memorable, dark dojo/martial-arts theme and an FM-console identity.
- Repeated hazard, menu and music loops should remain comfortable.
- Music should leave danger cues clear during overlaps; test at both default and full volumes.
- Confirm clean loop seams, pause/resume, death/Game Over, initials/Title and repeated restarts.

Automated trigger, routing, persistence, peak and seam checks cannot establish physical
recognisability, musical identity, fatigue or mix readability. Those remain listening judgements.
