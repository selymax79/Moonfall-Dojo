# Moonfall Dojo — Current Design Reference

[AGENTS.md](AGENTS.md) defines intended scope; this reference describes implemented behaviour.
[Roadmap.md](Roadmap.md) defines the development sequence, milestone status and next target.

## Core Game Loop

Single-screen endless arcade reaction/combat game. Player stays at x=320, feet at y=300;
threats enter at x=80 or x=560. One spatial hit kills Player. Actions are committed;
Score, Level and a persistent local Top 10 track the run. There is no victory condition.

## Startup / Title / Menus

Application startup opens Title with MOONFALL DOJO, High Score (leaderboard entry #1),
and five rows: START GAME, START LEVEL, HIGH SCORES, CONTROLS, OPTIONS.
Up/Down wraps through rows; Enter activates. On START LEVEL, Left/Right clamps the selection
between 1 and the highest legitimate unlock; Enter also starts at that selected level.
Selection defaults to 1 on each application launch and is retained when returning to Title.

Controls lists Left/Right = Turn, Up = Jump, Down = Duck, Z = Punch, X = Kick,
P = Pause/Resume, Enter = Select/Confirm/Restart and Esc = Back where available.
Options provides Music Volume and SFX Volume (0–100, defaults 70/80). Up/Down selects;
Left/Right adjusts by 5, applies immediately and saves actual changes. Zero mutes that bus;
100 uses its reference gain. Enter/Esc returns to Title.
High Scores shows ten ranked rows, with placeholders for empty slots rather than fake saved scores.
Esc or Enter returns from these screens to Title with the selected row retained.
Development keys are not shown as normal controls; remapping is not implemented.

Main has explicit TITLE, CONTROLS, OPTIONS, HIGH_SCORES, INITIALS_ENTRY and RUN states.
Non-qualifying Game Over remains a RUN substate; SceneTree pause is separate.
Menus hide/disable gameplay actors and gate simulation before clocks, spawning or RNG draws.
Initials Entry retains final statistics; other menus hide them. P/F2/F4 cannot pause,
restart or boost menus/initials entry (typing P enters an initial). Gameplay presses and
held-key echoes cannot buffer into the next run. Menu dwell/navigation consumes no gameplay RNG.

Start Game, non-qualifying Game Over Enter and in-run F2 share `start_new_run()`: a deferred
replacement of Main with a fresh RUN instance. Starts use the selected level; F2/Enter restarts
retain the current `run_start_level`. All begin unpaused at x1.0 with zero Score/Kills/Dodges/dev
boost, an idle living Player and a fresh scheduler including its first threat and pending choice.
The shared records object survives replacement; old gameplay nodes are removed together.
The Title-to-run handover preserves gameplay RNG seed/state, making seeded sequences independent
of menu time. In-run restarts retain fresh RNG behaviour. There is no live-run return-to-title
control; qualifying Game Over reaches Title through the leaderboard.

## Player

Implemented in [player.gd](scripts/player.gd) and [player.tscn](scenes/player.tscn).
Distances are logical pixels; times are seconds and do not scale with Level.

| Action | Timing | Behaviour |
| --- | --- | --- |
| Turn | 0.10 across a full reversal | Reversible, not committed; repeated direction does not restart it. An action during a turn snaps to target facing. |
| Punch | 0.06 extension + 0.08 active + 0.16 recovery = 0.30 | Active rectangle extends 6..25.5 px toward facing, y=-25..-21 relative to feet. |
| Kick | 0.08 extension + 0.16 active + 0.16 recovery = 0.40 | Raised active rectangle extends 14..36 px toward facing, y=-33..-27. |
| Jump | 0.82 | Deterministic parabola, 55 px apex; hurtbox follows the visual vertically. |
| Duck | 0.08 crouch + 0.35 low hold + 0.17 stand = 0.60 | Feet planted; body height scales to 45%; no indefinite hold. |

Standing hurtbox is 16×40; fully ducked is 16×18. Turning does not squash this hurtbox.
Committed actions discard new action/turn inputs; no general buffering. Keyboard echo
is ignored, so holding Down does not extend/restart Duck; another press is required.
Arrow keys turn/jump/duck; Z punches; X kicks; **P pauses/resumes** (InputMap `pause_game`).
Death cancels the action and plays five collapse poses within the existing 0.40 s clock;
the body settles on the floor and the HUD stays visible.

## Game Over / Restart

After Player's existing 0.40 s death animation completes, qualification is checked once.
The final HUD retains Score, High Score, Kills, Dodges, Level and multiplier.
Death immediately cancels pending spawning and prevents further gameplay rewards.
Before menu entry, surviving Assassins finish recovery; active hazards freeze; resolved
Barrel/Shuriken cosmetics may finish without rewards. Initials Entry hides/freezes all actors.

A qualifying score shows GAME OVER / NEW HIGH SCORE / ENTER INITIALS. Type three A–Z/0–9
characters (letters become uppercase); Backspace removes the last character; Enter confirms
only when all three slots are filled. Confirmation inserts/saves once and shows High Scores.
Enter/Esc then returns to Title, not directly to a new run. F2/F4 and Pause are disabled during
entry; typing P remains a valid initial. Echoes and invalid characters are ignored.

A non-qualifying score shows centred GAME OVER and **Enter to restart**.
Enter (InputMap `restart_run`) accepts a fresh non-echo press only while this overlay is visible
and unpaused. Enter during play, actions, death animation or pause is discarded, not buffered.
Restart replaces Main with an unpaused run at its original starting level: counters/dev boost
reset to zero, multiplier to x1.0, Player and scheduler reset, and old threats are removed.
The saved leaderboard and unlocks survive both Enter and F2. High Score always means the
confirmed table's top entry; a qualifying run joins it only on initials confirmation.

P remains available during death and non-qualifying Game Over. Pause freezes the death animation
and delays qualification/Game Over. PAUSED temporarily replaces the restart overlay; P restores it.
F2 can restart immediately during death/pause and clears pause. F4 may change Level/multiplier
on the dead/paused HUD without points, unlocks or renewed spawning. Both are ignored after entering initials.

## Pause

During a run, P toggles SceneTree pause on a fresh, non-echo press, including during death.
Menus ignore the Pause action. A centred
PAUSED overlay and P-to-resume hint appear over the HUD. Player actions/turning/death,
all threat movement/attacks/cosmetics, and scheduler gameplay time freeze without wall-clock
catch-up. Gameplay presses during pause are discarded, not queued for resume.

Main uses Always processing so P/F2/F4 remain available, with one central pause guard before
its simulation tick. Player and spawned threat roots use Pausable processing, including
Barrel/Shuriken's independent cosmetic ticks. Future gameplay/audio nodes must likewise
use Pausable processing rather than inherit Main's control exception. Gameplay audio is
Pausable; the separate UI voice remains Always processing for pause/resume feedback.

## Development Controls

- **F2:** restart the current run unpaused; reset counters, development boost and scheduler;
  retain its chosen starting level, leaderboard and unlocks. Clears SceneTree pause before
  replacing Main. Ignored in menus and initials entry.
- **F4:** advance effective Level by exactly one per fresh press using a run-local `dev_level_boost`.
  Level and run-relative multiplier refresh immediately, without changing Score, Kills, Dodges,
  handled count, leaderboard or legitimate unlock. F4 itself never writes persistence.
  Works during actions, approaches, empty gaps, pause and death. It cannot restart spawning after death.
  While paused, Level/Multiplier update behind the overlay but gameplay remains frozen.
  Ignored in menus and initials entry, so no development boost accumulates before Start.

F4 updates future difficulty and overlap eligibility. A shorter gap band shortens the remaining
pacing wait while preserving elapsed time. Pending type/side, active speeds and response reservations
stay unchanged; every admission still passes the fairness checks. F2/scene reload resets the boost to zero.

## Threat Vocabulary

The intended response is **not a magic attack-type rule**. Current visual/hurtbox geometry
and spatial overlap determine success. Both entry sides mirror the same mechanics.

- **Red Assassin → Kick.** Standing 16×40 body; stops 38 px away. Punch's 25.5 px
  reach cannot bridge the 30 px gap to its near body edge; Kick can. Telegraph is 0.35,
  strike 0.20, recovery 0.25, retry wait 0.40. The katana travels during its strike;
  first standing contact is 0.09 after strike begins. Duck can pass below the blade
  (y=276..278) but does not defeat or resolve Red. A valid Player attack wins a same-tick clash.
- **Blue Assassin → Punch.** Stops 30 px away; crouches over 0.08 to a 16×24 body
  at y=276..300, remaining low thereafter. Raised Kick passes above it; Punch overlaps.
  Telegraph/strike/recovery/retry are 0.35/0.20/0.25/0.40. Fist first reaches standing
  Player 0.08 into strike, at y=286..290; Duck remains vulnerable. Jump may spatially evade.
- **Barrel → Jump.** Radius 9 (18×18), centre y=291; base speed ×1.15. Standing/Duck collide.
  Punch/Kick do not destroy it. Complete horizontal passage awards a Dodge, then
  0.50 harmless roll + 0.40 cosmetic explosion; the effect cannot damage or score.
  The 18 px drawn body matches the collider, with transparent padding in each 20 px atlas cell.
  Jump retains its 55 px parabola and committed input, stretched only to 0.82 s (apex at 0.41 s).
- **Shuriken → Duck.** Approximately 8×8, stable radius 4, centre y=270, speed ×1.25.
  Standing body overlaps; fully crouched head clears its bottom by 8 px. Artwork spins
  independently of collision. Punch/Kick do not destroy it; Jump can spatially evade.
  Complete passage awards a Dodge, then 0.20 departure + 0.75 falling + 0.15 settled,
  then removal. Centre settles at y=296, lowest tip at floor y=300. All aftermath is harmless.

## Threat Speed

`base_speed = min(60 + 5 * (level - 1), 100)` px/s: Level 1=60, Level 5=80, Level 9+=100.
Assassins use base speed; Barrel uses `base_speed * 1.15` (69/92/115);
Shuriken uses `base_speed * 1.25` (75/100/125).
Final speed is assigned at spawn; existing threats never speed up retroactively.
Assassins begin their moving telegraph farther out at higher speeds, preserving its 0.35 s.

### Barrel / Jump tuning verification

Godot collision stepping at 1 ms and fresh-input sampling at the normal 60 Hz tick give:

| Level | Barrel speed | Successful input window (1 ms stepping) | 60 Hz earliest-to-latest successful press span |
| --- | --- | --- | --- |
| 1 | 69 px/s | approximately 246–247 ms | 233 ms (15 successful press ticks) |
| 5 | 92 px/s | approximately 366 ms | 350 ms (22 successful press ticks) |
| 9+ | 115 px/s | approximately 437 ms | 417 ms (26 successful press ticks) |

Both sides and both facings have identical successful ticks at 60 Hz; Level 1's sub-tick
boundary differs by 1 ms under fine stepping due to accumulated floating-point positions.
Clearly early jumps land into the Barrel; late jumps collide before gaining clearance.
The previous radius-7/base-speed/0.75 s setup measured approximately 195/318/391 ms.
The larger/faster Barrel with unchanged 0.75 s Jump measured 185/305/376 ms; 0.82 s
restores a little more opportunity than the original. A tested 0.85 s Jump gave 273/393/463 ms,
so the smaller 0.82 s increase was chosen. No apex hold, gravity change or input buffering is added.

## Scoring / Progression

Assassin success adds one Kill; Barrel/Shuriken passage adds one Dodge.
`handled_threats = kills + dodges`;
`level = run_start_level + floor(handled_threats / 4) + dev_level_boost` (boost defaults to zero).
Each success earns 100 × current multiplier. Multiplier starts at ×1.0 and rises by
0.5 for every three completed run-relative Levels, including higher-level starts.
Score uses the old/current multiplier **before** incrementing the counter and recalculating
Level. Without development boosts, threat #12 scores ×1.0, then Level 4/×1.5;
#24 scores ×1.5, then Level 7/×2.0. Boosted Levels use the same run-relative multiplier;
three F4 presses from Level 1 make the next success worth 150, and four real successes then reach Level 5.

Main stores multiplier in integer half-units. Starting at Level 10 begins at x1.0;
threat #12 scores x1.0 then reaches Level 13/x1.5; #24 scores x1.5 then reaches Level 16/x2.0.
The initial threat speed/pacing uses the selected absolute Level; multiplier remains run-relative.

## Local Records / Legitimate Unlocks

[run_records.gd](scripts/run_records.gd) is a small RefCounted helper owned by Main, shared across
scene replacement. It loads once per application session and uses the existing ConfigFile path,
`user://high_score.cfg`. `[scores] entries` stores `{initials, score}` dictionaries;
`[progress] highest_level` stores the legitimate unlock. Other sections are preserved.

An old positive `[scores] high_score` without an entries key becomes one `AAA` entry and is
saved in the new format. Existing tables, including an explicit empty table, are authoritative:
migration never replaces them or re-adds the legacy value on subsequent launches.
Missing/corrupt data defaults to an empty table, High Score 0 and unlocked Level 1.
Scores must be non-negative integers (no string/float/bool coercion). Invalid entries are discarded;
initials are uppercased, filtered to A–Z/0–9, truncated/padded with A to three characters.
Loaded tables are sorted descending and trimmed to ten. Highest Level must be a positive integer;
invalid values fall back to 1. No artificial gameplay level cap is added.

Earlier equal scores retain their order. A new score qualifies when fewer than ten entries exist,
or when it strictly exceeds the tenth score. An equal cutoff cannot displace an existing entry.
High Score derives from entry #1, or zero for an empty table; no separate record is maintained.
New runs do not change it until initials are confirmed. Zero-score runs may legitimately qualify in
an incomplete table; empty UI rows themselves are never persisted.

After each real success, `earned_level = run_start_level + floor((kills + dodges) / 4)` updates
the highest unlock if greater. F4's offset is excluded even while earning real levels during a
boosted run. Real Level 3 boosted to effective Level 20 still unlocks only Level 3.
Previously unlocked higher starts may unlock further levels through normal progression.

Writes occur on migration, confirmed leaderboard insertion, a new legitimate highest Level,
or an actual audio-volume change. `[audio] music_volume` and `sfx_volume` share this file.
Finite numeric volume values clamp to 0–100 and round to integers; missing, non-numeric or
non-finite values use 70/80. Settings saves preserve the leaderboard, unlock and unrelated fields.
A temporary file is written completely before replacing the save. Failure warns without interrupting
gameplay or destroying the previous file; records stay in memory across restart and can be written
by a subsequent save. Unconfirmed run scores are not persisted. No autoload or external service exists.

## Deterministic Resolution Rules

Main advances Player, then all unresolved threats. All valid Player attacks on Assassins
resolve before any enemy damage; valid attacks win same-tick clashes regardless of array
order. Next come lethal queries, then surviving hazard rewards. A lethal overlap cannot
award a Dodge. Reward/progression happen once on gameplay resolution, independently of
cosmetic cleanup. Death cancels the pending spawn; no later rewards occur. Active hazards
freeze, surviving Assassins finish recovery, and resolved effects finish independently until menu entry.

## Current Threat Selection

Main owns a small `active_threats` array of unresolved records plus one selected pending
type/side. Type is uniform over Red/Blue/Barrel/Shuriken; side is independent 50/50.
RNG draw order is always **type, then side**, with no timing draw or anti-streak logic.
The first choice is drawn when a fresh RUN instance enters the tree, never in menus;
each spawn immediately draws the next pending choice.
Unsafe choices wait unchanged: neither capacity nor fairness checks consume RNG draws.
Seed before readiness for reproducibility (same seed and Player inputs give the same run).

| Level | Minimum gap after spawn or resolution | Maximum unresolved |
| --- | --- | --- |
| 1–3 | 0.85 s | 1 |
| 4–5 | 0.65 s | 1 |
| 6 | 0.65 s | 2 |
| 7–9 | 0.45 s | 2 |
| 10+ | 0.35 s | 2 |

With one allowed, the gap is post-resolution. With two allowed, the next approach can
start earlier, but only after the fairness check below. Cosmetic nodes never count.
Level changes affect future speeds/pacing; existing speed and timing reservations are immutable.
F2 recreates the scene and all scheduler state.

## Scheduler Fairness Model

Standing first-contact lead times from either spawn (240 px from Player):

| Threat | Formula (v is that actor's final speed) | Level 1 | Level 5 | Level 9+ |
| --- | --- | --- | --- | --- |
| Red | 202/v + 0.09 | 3.457 s | 2.615 s | 2.110 s |
| Blue | 210/v + 0.08 | 3.580 s | 2.705 s | 2.180 s |
| Barrel | 223/v | 3.232 s | 2.424 s | 1.939 s |
| Shuriken | 228/v | 3.040 s | 2.280 s | 1.824 s |

Assassin travel already includes the 0.35 s moving telegraph; weapon reach adds 0.09/0.08 s.
Hazard distances subtract Player half-width 8 and radius 9/4. Barrel uses ×1.15 speed;
Shuriken uses ×1.25 speed.
Higher Levels retain capped lead times; neither side changes them.

For each actor, let `L = spawn_time + contact_lead` and `D = intended response duration`.
Reserve **[L − D, L + D]**, including startup and recovery. This is a conservative planning
interval containing a successful response, not an input window where every press succeeds.
Examples of successful planned presses: Red at strike start −0.08; Blue at strike start
−0.06; Barrel when centre arrival is 0.410 s away; Shuriken when centre arrival is 0.271 s away.
These place the attack hold, Jump apex or Duck clearance over the relevant encounter.

Before spawning the pending actor, require:

`new_response_start >= max(existing_response_ends, now + actual_remaining_commitment) + turn + 0.10`

`turn` is 0.10 s for either Assassin, zero for hazards. Same-side Assassin pairs may need
no actual turn; reserving the opposite-side cost avoids relying on future facing choices.
The 100 ms margin covers fixed-tick rounding and leaves recovery breathing room. The
current action uses its actual remaining duration, not another complete action duration.

At the speed cap, the shortest reserved approach lead is Barrel's approximately 1.119 s.
Even after the longest fresh commitment (0.82), it leaves 0.199 s beyond the 0.10 margin. Thus zero
post-resolution delay would still allow a valid response; the positive gap bands preserve
readability. For unresolved pairs, every ordered type/side pair can be delayed until its
reservations separate; no forbidden pairs or rerolls are necessary. Pair verification covers
all 384 ordered type/side/Level cases, including overlap at eligible Levels.

Overlap is mathematically possible at Level 1 too. Level 6 is a pacing unlock, validated
at base speed 85, not a claim that lower Levels are geometrically unsafe. Every spawn
still passes the same timing/capacity gates.

If an unresolved actor reaches its predicted first contact, no further actor is admitted
until that overdue encounter resolves. In particular, repeatedly ducking an Assassin does
not advance an expired forecast. Already admitted pairs remain fair for their intended
responses; this does not guarantee recovery after arbitrary missed responses or indefinite
Assassin evasion. Player skill is still required. The model depends on the documented
fixed geometry/timings: retuning them requires recalculation and pair/regression tests.

## Display / Presentation

640×360 logical viewport, 16:9, fractional viewport scaling with aspect preservation,
nearest-neighbour filtering, Compatibility renderer, dark navy clear colour.
The fixed moonlit dojo uses a cool navy/blue-black palette, muted moonlit grey roofs and trees,
with small amber lamp pools and warm cream shoji doors. The central wall stays restrained
behind combat. The painted pixel-style architecture plate contains sky, moon, tree silhouettes,
distant and near tiled roofs, wall, doors, lamps and wooden floor. It is an original generated
image adapted to the logical viewport; foreground actors use original compact pixel atlases.

[dojo_environment.tscn](scenes/dojo_environment.tscn) sits behind every gameplay actor.
Its 640×318 plate extends beneath the HUD; the visible plank floor grounds unchanged feet
at y=300. Architecture stays fixed: independent cloud motion provides depth without camera sway.
Two repeated pixel cloud banks drift at +1.6 and −3.1 logical px/s, snapped to whole pixels.
A small authored sky mask lets clouds cross the moon without painting over trees or roofs.
There are no dynamic lights, physics bodies or gameplay callbacks in this environment.

[dojo_environment.gd](scripts/dojo_environment.gd) owns its own seeded cosmetic RNG and local
physics clock. It never consumes Main's encounter RNG. One or two small bats occasionally cross
in either direction for 7.5 s (initial wait 16–28 s, subsequent waits 22–40 s). One person or dog
crosses a single shoji panel for 9 s, including a brief pause (initial wait 10–20 s, subsequent
waits 18–36 s). Figures are clipped into individual paper cells so the wooden lattice remains
in front. Four-frame adult walks and dog trots use two-pixel travel steps; an additional adult
pose holds the pause. Direction mirrors both the figure and its travel. Understated opacity
keeps these events distinct from threats. Three authored lantern-cage/timber shadow sprites
follow an uneven stepped 8 Hz lamp cadence, with matching flame pixels and floor glints;
the broad warm illumination is part of the static plate. This is inexpensive drawn lighting.
The environment is Pausable, so all local clocks freeze with gameplay; menus hide and stop it.

The run HUD is a fixed 640×52 status strip at y=308, below the existing gameplay floor.
Dark timber/navy framing and a thin bronze highlight separate it from the fighting lane.
Left: HI and SCORE; centre: KILLS and DODGES; right: LEVEL and multiplier. Values retain
their existing meanings and update through Main. Score/HI have a minimum of eight digits,
never a maximum; multiplier remains x1.0/x1.5/etc. No statistic moves or animates.
[run_hud.gd](scripts/run_hud.gd) owns only the panel drawing and text fitting.
An original project-owned 5×7 bitmap alphabet has an 8 px native line height, normally rendered
at 16 px for statistics, 8 px for HI and 24 px for Pause/Game Over headings. Integer font scaling
keeps edges crisp. A value too wide for its column uses the native 8 px size; full signed-64-bit
positive integer values fit without truncation. Final stats remain visible at Game Over and
initials entry. Pause dims only the play area, keeping the HUD clear; entry hints sit above it.

[art/README.md](art/README.md) documents source assets and the offline presentation builder.
Milestone 27 is complete following automated verification and user manual acceptance of the environment and HUD presentation.

## Character Art / Combat Feedback

The combined Milestone 28/29 pass implements first-pass 16-bit combat art, not final character
artwork. These sprites are accepted as placeholders for continued functional development.
Player punch/kick anatomy and poses remain weak, with limbs reading too much like bent sticks;
Red/Blue anatomy and sprite quality also need review. Current animation timing and gameplay
alignment are good. The required pre-release drawing/pose polish is recorded in
[Roadmap.md](Roadmap.md#required-pre-release-character-art-polish), with gameplay timings,
hitboxes and animation-state alignment to be preserved.

The pass uses original, offline-authored pixel atlases with dark outlines,
small colour ramps, hard highlights and held key poses. Player uses navy/slate and a muted gold
headband; Red uses crimson and steel; Blue uses cool blues with restrained cyan highlights.
Native-sized textures use nearest filtering and only ±1 horizontal mirroring, with no runtime
skeleton, sprite rotation or fractional sprite scaling. The background and HUD remain as accepted.

[combat_art.gd](scripts/combat_art.gd) reads actor state after Main's simulation tick. It does not
write to the actor, collision shapes, scheduler, scoring or RNG. The hidden legacy pose nodes
remain as the established collision/jump/crouch drivers; their transforms are not applied to the
new artwork. This preserves gameplay geometry while replacing the displayed poses.

- Player: two idle poses, a narrow turn pose between facings, four low-punch poses, four high-kick
  poses with a planted supporting leg and backward torso lean, four jump poses, three crouch/rise
  poses and five collapse frames (a crouched death enters the low part of the sequence).
  Existing extension/hold/recovery/death clocks select frames.
- Red: four distance-stepped run poses, drawn-back wind-up, forward strike and recovery poses.
  A separately drawn 26×2 blade follows the exact Sword collision-parent translation, rounded
  only for raster display. It remains non-lethal outside the existing STRIKE phase; on defeat,
  a cosmetic dropped blade settles beside the body.
- Blue: four compact run poses, crouch transition, low guard/attack poses and a distinct folded
  collapse. Its visible 4×4 fist and connected sleeve follow the actual low Fist transform.
  The raised Player kick continues to pass above Blue's existing low hurtbox.
- Barrel: eight wood-stave/steel-band end-face frames cover a full rolling revolution, driven
  by signed distance/radius: clockwise travelling right, anticlockwise travelling left.
  An off-centre wooden plug rotates with the face; frame changes are symmetric between sides.
  These are followed by four stepped
  stages of low wood fragments, hoop pieces and dust during the existing 0.40 s aftermath.
- Shuriken: four bright steel spin frames, the existing departure/fall, and a three-step small
  floor spark during the existing 0.15 s settle. Collision remains an unrotated radius-4 circle.

Player's active punch fist and full high-kick shoe align with the existing attack regions.
Duck uses authored crouch poses rather than scaling a standing sprite; the final head is 18 px
above planted feet. Jump poses follow the unchanged 55 px arc; a subtle flattened contact shadow
stays on the floor and narrows at the apex. Player/Assassins/Barrel have small contact shadows.
Effects are restrained pixel clusters: successful-hit spark, landing dust, death impact accent,
Barrel debris and Shuriken floor contact. There is no screen shake, hit-stop or gameplay delay.

Assassin death still resolves immediately. Before removal, the actor creates one harmless
[combat_aftermath.gd](scripts/combat_aftermath.gd) node under the current run. It holds only its
texture/facing and a 0.48 s clock, plays five collapse poses and removes itself. It has no collision
shape, actor reference, scoring callback or scheduler registration. New threats can spawn while
it finishes. Scene replacement removes old effects; menu entry hides/disables them with actors.
Actor art inherits its actor's processing mode, so both pause and menu disabling freeze it;
detached corpses explicitly use Pausable processing. No new cosmetic effect uses RNG. Shoji
events retain the environment's separate RNG and original event timing, independent of gameplay.

[build_combat_art.gd](tools/build_combat_art.gd) regenerates the 17 new PNGs deterministically.
Each ninja atlas contains the common 32-pose authoring catalogue; runtime actors use only their
relevant poses. No copied sprites, downloaded fonts, runtime IK or new manager is involved.
Milestones 28 and 29 are complete for functional development following user manual review,
with the character-art polish debt explicitly retained.

## Audio Foundation

[game_audio.gd](scripts/game_audio.gd) owns nine fixed, scene-defined AudioStreamPlayers under
Main: Music, Player, Danger, two Impact voices, System, UI and two quiet Hazard loops.
There is no autoload, runtime synthesiser or audio-driven gameplay clock. Scene replacement
stops and removes all old voices before the new run begins. The small impact pool permits
cosmetic impacts alongside combat feedback; the two hazard voices match scheduler capacity.

[default_bus_layout.tres](default_bus_layout.tres) defines Master, Music and SFX. Music routes
to Music; every other voice, including UI, routes to SFX. Both feed Master with -6 dB headroom.
Per-voice gains keep danger/player accents above the quiet hazard loops and background music.
Volume options change bus gain; they do not alter streams, timings or gameplay RNG.

The 21 original placeholder WAVs use offline layers of damped steel, wood, cloth/air noise,
body impacts and FM bass/plucks. Title and gameplay share the D–A–Bb–A / F–E–D motif within
a D/E/F/A/Bb vocabulary. Title is an eight-bar 92 BPM loop (~20.87 s); gameplay transforms
the same theme at 132 BPM (~14.55 s) with tighter bass, taiko-like hits and wood accents.
Shuriken flight has dry air cuts and fixed-pitch steel ticks, with no pitch modulation;
Barrel break-up layers a low thump, staggered wood cracks, short noise and hoop clatter.
[audio/README.md](audio/README.md) documents assets, mix and regeneration
using [generate_audio.gd](tools/generate_audio.gd). These are original synthesis recipes,
not samples or melodies copied from another game. The current audio foundation has user manual
listening acceptance; Milestone 26 is complete.

Audio hooks observe existing transitions without changing collision or action durations:

- Accepted Punch/Kick/Jump/Duck starts play an action accent; they do not imply a successful hit.
- Red/Blue WINDUP → STRIKE plays the respective danger cue; an actual defeat plays its impact.
- Unresolved Barrel/Shuriken play quiet movement loops from spawn until resolution/removal/death.
- Barrel EXPLODING and Shuriken SETTLED transitions each play one cosmetic impact.
- Lethal Player resolution immediately stops music and other sounds, then plays death once.
- After the existing 0.40 s death animation, Game Over plays one short thematic sting (~1.05 s).
- Menu movement/confirmation, accepted initials edits/confirmation and Level increases have cues.
  Rapid F4 restarts one Level-up voice instead of stacking; dead F4 remains silent.

Title music continues uninterrupted through Controls, High Scores and Options. Start/restart
switches to one gameplay loop. Initials entry and its leaderboard retain the Game Over sting/UI
without background music; returning to Title stops any remaining sting and starts Title music.
No optional turn sound or adaptive music is implemented.

Pause freezes gameplay music/SFX playheads; UI alone plays the pause/resume cue. Resume continues
the same streams without restarting music or catching up wall-clock time. A Level-up cue created
by paused F4 stays paused until resume. Native output may drain one already-submitted audio buffer
(~12 ms measured); subsequent paused time produces no playhead drift. F2 clears pause and stops
all old audio before starting the fresh run. Gameplay audio callbacks never award points.

## Not Yet Implemented

Final character anatomy/combat-pose polish; full pause menu;
remappable controls; controller bindings; advanced authored encounter patterns.
