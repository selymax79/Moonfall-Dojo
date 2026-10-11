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
Options explains that audio options will be available after audio implementation; no settings yet.
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
| Jump | 0.75 | Deterministic parabola, 55 px apex; hurtbox follows the visual vertically. |
| Duck | 0.08 crouch + 0.35 low hold + 0.17 stand = 0.60 | Feet planted; body height scales to 45%; no indefinite hold. |

Standing hurtbox is 16×40; fully ducked is 16×18. Turning does not squash this hurtbox.
Committed actions discard new action/turn inputs; no general buffering. Keyboard echo
is ignored, so holding Down does not extend/restart Duck; another press is required.
Arrow keys turn/jump/duck; Z punches; X kicks; **P pauses/resumes** (InputMap `pause_game`).
Death cancels the action and plays a 0.40 s placeholder fall; the HUD stays visible.

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
use Pausable processing rather than inherit Main's control exception; no audio exists yet.

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
- **Barrel → Jump.** Radius 7 (14×14), centre y=293; base speed. Standing/Duck collide.
  Punch/Kick do not destroy it. Complete horizontal passage awards a Dodge, then
  0.50 harmless roll + 0.40 cosmetic explosion; the effect cannot damage or score.
- **Shuriken → Duck.** Approximately 8×8, stable radius 4, centre y=270, speed ×1.25.
  Standing body overlaps; fully crouched head clears its bottom by 8 px. Artwork spins
  independently of collision. Punch/Kick do not destroy it; Jump can spatially evade.
  Complete passage awards a Dodge, then 0.20 departure + 0.75 falling + 0.15 settled,
  then removal. Centre settles at y=296, lowest tip at floor y=300. All aftermath is harmless.

## Threat Speed

`base_speed = min(60 + 5 * (level - 1), 100)` px/s: Level 1=60, Level 5=80, Level 9+=100.
Assassins and Barrel use base speed; Shuriken uses `base_speed * 1.25` (75/100/125).
Final speed is assigned at spawn; existing threats never speed up retroactively.
Assassins begin their moving telegraph farther out at higher speeds, preserving its 0.35 s.

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

Writes occur on migration, confirmed leaderboard insertion or a new legitimate highest Level.
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
| Barrel | 225/v | 3.750 s | 2.813 s | 2.250 s |
| Shuriken | 228/v | 3.040 s | 2.280 s | 1.824 s |

Assassin travel already includes the 0.35 s moving telegraph; weapon reach adds 0.09/0.08 s.
Hazard distances subtract Player half-width 8 and radius 7/4. Shuriken uses ×1.25 speed.
Higher Levels retain capped lead times; neither side changes them.

For each actor, let `L = spawn_time + contact_lead` and `D = intended response duration`.
Reserve **[L − D, L + D]**, including startup and recovery. This is a conservative planning
interval containing a successful response, not an input window where every press succeeds.
Examples of successful planned presses: Red at strike start −0.08; Blue at strike start
−0.06; Barrel when centre arrival is 0.375 s away; Shuriken when centre arrival is 0.271 s away.
These place the attack hold, Jump apex or Duck clearance over the relevant encounter.

Before spawning the pending actor, require:

`new_response_start >= max(existing_response_ends, now + actual_remaining_commitment) + turn + 0.10`

`turn` is 0.10 s for either Assassin, zero for hazards. Same-side Assassin pairs may need
no actual turn; reserving the opposite-side cost avoids relying on future facing choices.
The 100 ms margin covers fixed-tick rounding and leaves recovery breathing room. The
current action uses its actual remaining duration, not another complete action duration.

At the speed cap, the shortest reserved approach lead is Shuriken's 1.224 s. Even after
the longest fresh commitment (0.75), it leaves 0.374 s beyond the 0.10 margin. Thus zero
post-resolution delay would still allow a valid response; the positive gap bands preserve
readability. For unresolved pairs, every ordered type/side pair can be delayed until its
reservations separate; no forbidden pairs or rerolls are necessary. At capped speeds,
the model permits at least approximately 0.63 s of approach overlap before the first
threat's expected resolution (before fixed-tick rounding).

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
All artwork is currently simple placeholder geometry; there is no drawn floor/background.

## Not Yet Implemented

Full background art; polished sprites; audio/music and usable audio options; full pause menu;
remappable controls; controller bindings; advanced authored encounter patterns.
