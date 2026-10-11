# Moonfall Dojo — Current Design Reference

[AGENTS.md](AGENTS.md) defines intended scope; this reference describes implemented behaviour.
[Roadmap.md](Roadmap.md) defines the development sequence, milestone status and next target.

## Core Game Loop

Single-screen endless arcade reaction/combat game. Player stays at x=320, feet at y=300;
threats enter at x=80 or x=560. One spatial hit kills Player. Actions are committed;
Score, Level and a persistent single High Score track the run. There is no victory condition.

## Startup / Title / Controls

Application startup opens Title, showing MOONFALL DOJO, the persistent High Score,
START GAME and CONTROLS. Up/Down switches the explicit selection; Enter activates it.
Controls lists Left/Right = Turn, Up = Jump, Down = Duck, Z = Punch, X = Kick,
P = Pause/Resume and Enter = Select/Restart at Game Over. Esc or Enter returns to Title
with Controls still selected. Development keys are not presented as normal controls.

Main uses three states: `TITLE`, `CONTROLS` and `RUN`. RUN retains Player's existing death
flag and Game Over overlay; SceneTree pause remains separate. Menus hide and disable Player,
hide run statistics, and gate the simulation before gameplay clocks, spawning or RNG draws.
No threats or fairness reservations exist before Start. P/F2/F4 are ignored in menus.
Gameplay keys cannot alter hidden Player state or buffer actions into the next run; held-key
echoes are ignored. Menu navigation and dwell time consume no gameplay RNG.

Start Game, Game Over Enter and in-run F2 share `start_new_run()`: a deferred replacement
of Main with a fresh instance configured to enter RUN, bypassing Title. This resets all
run state without maintaining a separate field-by-field reset list. It begins unpaused at
Level 1, x1.0, zero Score/Kills/Dodges/development boost, with an idle living Player, the
normal first threat and a newly selected pending threat. High Score reloads from the same save.
The Title-to-run handover preserves the gameplay RNG seed/state, so identical seeds and
gameplay inputs produce identical sequences regardless of menu time. Restarts retain the
previous fresh-RNG behaviour. There is no in-run return-to-title control yet.

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

After Player's existing 0.40 s death animation completes, a centred GAME OVER message and
**Enter to restart** prompt appear. The HUD retains Score, High Score, Kills, Dodges, Level
and multiplier. Death immediately cancels pending spawning and prevents further gameplay
rewards. Surviving Assassins finish recovery; active hazards freeze; already-resolved
Barrel/Shuriken cosmetics may finish and remove themselves without further rewards.

Enter (InputMap `restart_run`) accepts a fresh, non-echo press only while Game Over is
visible and the game is unpaused. Enter during play, actions, the death animation or pause
is discarded, not buffered. Holding it before death cannot trigger a later restart.
Restart replaces Main with an unpaused Level 1 run: Score/Kills/Dodges/development boost
reset to zero, multiplier to x1.0, Player and scheduler reset, and old threat nodes are removed.
The fresh scheduler starts its normal first encounter and selects a new pending threat.
The saved High Score survives both Enter restart and F2; new records still save on scoring.

P remains available while dead. Pause freezes the death animation and delays Game Over;
at Game Over, PAUSED temporarily replaces the message. P resumes and restores the restart
prompt; Enter is then available again. F2 can restart immediately, even during death or pause,
and always clears pause. F4 retains its development behaviour: it can change Level/multiplier
on the dead or paused HUD without awarding points or restarting spawning.

## Pause

During a run, P toggles SceneTree pause on a fresh, non-echo press, including during death.
Title and Controls ignore P. A centred
PAUSED overlay and P-to-resume hint appear over the HUD. Player actions/turning/death,
all threat movement/attacks/cosmetics, and scheduler gameplay time freeze without wall-clock
catch-up. Gameplay presses during pause are discarded, not queued for resume.

Main uses Always processing so P/F2/F4 remain available, with one central pause guard before
its simulation tick. Player and spawned threat roots use Pausable processing, including
Barrel/Shuriken's independent cosmetic ticks. Future gameplay/audio nodes must likewise
use Pausable processing rather than inherit Main's control exception; no audio exists yet.

## Development Controls

- **F2:** restart the current run unpaused; reset counters, development boost and scheduler;
  retain High Score. Explicitly clears SceneTree pause before replacing Main. Ignored in menus.
- **F4:** advance effective Level by exactly one per fresh press using a run-local `dev_level_boost`.
  Level and run-relative multiplier refresh immediately, without changing Score, Kills, Dodges,
  handled count or High Score. F4 itself never saves High Score; later scoring can update it normally.
  Works during actions, approaches, empty gaps, pause and death. It cannot restart spawning after death.
  While paused, Level/Multiplier update behind the overlay but gameplay remains frozen.
  Ignored on Title and Controls, so no development boost accumulates before Start.

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
0.5 for every three completed run-relative Levels, including future higher-level starts.
Score uses the old/current multiplier **before** incrementing the counter and recalculating
Level. Without development boosts, threat #12 scores ×1.0, then Level 4/×1.5;
#24 scores ×1.5, then Level 7/×2.0. Boosted Levels use the same run-relative multiplier;
three F4 presses from Level 1 make the next success worth 150, and four real successes then reach Level 5.

Main stores multiplier in integer half-units. A single High Score loads from
`user://high_score.cfg`, saves immediately when exceeded, and survives F2. Missing or
invalid saved values become zero. There is no Top 10 table or starting-level menu yet.

## Deterministic Resolution Rules

Main advances Player, then all unresolved threats. All valid Player attacks on Assassins
resolve before any enemy damage; valid attacks win same-tick clashes regardless of array
order. Next come lethal queries, then surviving hazard rewards. A lethal overlap cannot
award a Dodge. Reward/progression happen once on gameplay resolution, independently of
cosmetic cleanup. Death cancels the pending spawn; no later rewards occur. Active hazards
freeze, surviving Assassins finish recovery, and resolved effects finish independently.

## Current Threat Selection

Main owns a small `active_threats` array of unresolved records plus one selected pending
type/side. Type is uniform over Red/Blue/Barrel/Shuriken; side is independent 50/50.
RNG draw order is always **type, then side**, with no timing draw or anti-streak logic.
The first choice is drawn when a fresh RUN instance enters the tree, never on Title/Controls;
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

Full background art; polished sprites; audio/music; options/pause menus; remappable
controls; controller bindings; selectable/unlocked starting levels; Top 10 initials table;
advanced authored encounter patterns.
