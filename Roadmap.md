# Moonfall Dojo — Autonomous Development Roadmap
You are continuing development of Moonfall Dojo.

This roadmap exists so that development can continue safely even when no external architect/reviewer is available.

It does NOT override [AGENTS.md](AGENTS.md).

Before beginning any work:

1. Read `AGENTS.md`.
2. Read `DESIGN_NOTES.md`.
3. Inspect the repository and current Git status.
4. Inspect recent Git history.
5. Compare the current implementation against this roadmap.
6. Determine the earliest incomplete roadmap item.
7. Work only on that item unless explicitly instructed otherwise.
`AGENTS.md` is the project constitution.

`DESIGN_NOTES.md` describes the current implemented game state.

This roadmap describes the intended development path.

If code and documentation disagree, inspect carefully and report the discrepancy rather than silently assuming which is correct.

---

# CURRENT MILESTONE STATUS

| Milestone | Status |
| --- | --- |
| 21 — Player-facing Game Over and Restart | COMPLETE: implementation reviewed and verified. |
| 22 — Title Screen and Start Game Flow | COMPLETE: implementation reviewed and verified. |
| 23 — Local Top-10 High Score Table | COMPLETE: persistence, migration, entry flow and rendering verified. |
| 24 — Highest Level Unlock + Start Level | COMPLETE: legitimate unlocks, higher starts and restarts verified. |
| 25 — Controls / Options Shell | COMPLETE: keyboard navigation and input isolation verified. |
| 26 — Audio Foundation | COMPLETE: automated integration verified and redesigned audio accepted through user listening. |
| 27 — Environment Art Pass | COMPLETE: automated verification passed and environment/HUD presentation manually accepted by the user. |
| 28 — Character and Threat Art Pass | COMPLETE for functional development following user review; required pre-release character-art polish remains below. |
| 29 — Effects and Game Feel | COMPLETE for functional development following user review; preserve current timing and gameplay alignment. |
| 30 — Difficulty Shaping | IMPLEMENTED / MANUAL ACCEPTANCE PENDING: late speed/gap tiers verified; user playtesting remains. |
| 31 — Curated Encounter Patterns | IMPLEMENTED / MANUAL ACCEPTANCE PENDING: short mirrored patterns verified through the existing fairness scheduler. |
| 32/33 — Controller Support, Remapping and Mobile Input Foundation | IMPLEMENTED / HARDWARE ACCEPTANCE PENDING: injected-event, persistence, regression and rendered checks passed. |
| 34 — Web / Mobile Version | IMPLEMENTED / DEVICE ACCEPTANCE PENDING: shared Web export, touch menus, browser lifecycle, persistence and PWA verified; real devices remain. |
| 35 — Final Polish | NEXT: includes required character anatomy/combat-pose art debt; not started by Milestone 34. |

Milestone 21 provides GAME OVER after the death animation, the retained final HUD and
Enter restart into a clean run at its chosen starting Level with persistent records. Verification covered
deaths from all four threats on both sides, restart/input isolation, no post-death admissions
or rewards, cosmetic cleanup after death, P/F2/F4 interactions, scoring and persistence.
Regression checks passed for all 384 scheduler pair cases, 9,000 scheduled encounters,
seeded determinism, pause and development progression. Fresh 640×360 renders were inspected.
Keyboard checks used injected Godot events; physical keyboard playtesting was not performed.
Completion describes verified functionality in the checkout, not whether it has been committed.

Milestone 22 opens on Title with persistent High Score, keyboard Start Game and a Controls
view. Menus leave Player, scheduler clocks and gameplay RNG idle; Start/Enter/F2 share a
clean run-creation path. Verification compared real 2 s and 20 s menu dwell plus navigation:
the same seed produced identical 200-encounter gameplay traces. Separate-process relaunch
loaded a newly earned record on Title. Game Over, input isolation, pause, F4, 384 scheduler
pair cases and 9,000 scheduled encounters passed regression checks. Title selections,
Controls, first gameplay frame, Game Over, pause and restart were inspected at 640×360.
Input verification used injected Godot events; physical keyboard playtesting remains unperformed.

Milestones 23–25 provide a local Top 10 with direct three-character initials entry, one-time
AAA migration of a legacy record, earned-only Level unlocks, a bounded Start Level selector,
High Scores/Controls/Options destinations and restarts at the run's chosen starting Level.
ConfigFile persistence checks covered missing/invalid fields, stable ties, trimming, qualification,
legacy migration and separate-process relaunch. A forced write failure preserved the previous
file and recovered on a later save; an intentionally corrupt file fell back safely. These negative
fixtures emitted their expected diagnostics; normal runtime and render checks were clean.

Verification passed 172 feature-flow checks, 621 combat/progression regression checks,
116,980 pause checks, 318,498 F4 checks and 2,716,418 scheduler assertions, including the
384-pair matrix and 9,000 encounters. A separate 113,223-check menu determinism run compared
2 s and 20 s real menu waits with identical 200-encounter traces. F4 never unlocked a start
Level or wrote records; mixed earned Level 3 / effective Level 20 unlocked only Level 3.
Level-10 starts reached Level 13/x1.5 and Level 16/x2.0 at the unchanged scoring boundaries.
F2 and non-qualifying Enter restarts retained the chosen higher starting Level and cleared pause.
Separate-process startup loaded the confirmed leaderboard and unlock while selecting Level 1.
All title selections, selector maximum, full/partial tables, initials entry, Controls, Options,
Level-1/Level-10 runs and both Game Over outcomes were rendered and inspected at 640×360.
Tests used isolated user data and injected input; no physical keyboard playtesting was performed.

Milestone 26 adds 21 original generated WAVs, scene-local fixed playback voices, Master/Music/SFX
buses and persistent Music/SFX options. Automated audio verification passed 3,625 checks for
event counts, routing, volume, death, pause and repeated restarts; settings sanitisation/migration
passed 33 checks. All 21 source assets passed format/peak checks. The 172 feature-flow, 621
combat/progression, 116,980 pause, 318,498 F4 and 2,716,418 scheduler checks passed with audio
integrated, including 384 pair cases and 9,000 encounters. Another 113,223 menu-determinism
checks matched 200 encounters after 2 s versus 20 s menu dwell. Separate-process startup
restored volumes/records and applied their bus gains. The 640×360 Options render was inspected.
These tests used isolated save data and injected input. User listening accepted the integration
but rejected the initial sound design. The replacement 21 assets use named wood/steel/body/air
layers and a shared title/gameplay motif. The 3,625 audio, 172 feature-flow, 621 combat/progression
and 33 settings checks passed again with replacements, as did separate-process volume restoration.
Regeneration reproduced all 21 hashes; all four source loops have matching endpoint samples.
A native nine-voice stress capture at full settings remained below clipping. Runtime scripts,
scenes, project settings and buses match the accepted integration byte-for-byte.
User manual listening accepted the redesigned audio foundation: “Feels a lot better.”
Together with the automated verification above, this completes Milestone 26.
Milestone 27 adds the moonlit dojo, independently moving masked clouds, occasional bats and
shoji figures, lamp/shadow flicker and a fixed bottom HUD with an original bitmap font.
The 172 feature-flow, 621 combat/progression, 3,625 audio, 116,980 pause and 318,498 F4 checks
passed with this presentation. A further 104,713 presentation/scheduler checks compared identical
200-success gameplay traces under different cosmetic seeds and 1× versus 9× ambient time.
Ten simulated minutes produced 16 bat and 16 door events without adding cosmetic nodes.
Rendered inspection covered all four threats, a real two-threat Level-10 encounter, ambient
states, populated/large HUD values, Pause, both Game Over outcomes and existing menus.
The viewport was also rendered in 1280×720 and 1000×650 windows; captures retain the logical
640×360 viewport and do not themselves verify physical monitor scaling. Automated verification
did not include physical keyboard playtesting. The user has manually reviewed and accepted
the environment and HUD presentation. Milestone 27 is COMPLETE.

The user explicitly combined Milestones 28 and 29, including upgraded shoji figures and shadows.
Original pixel atlases now cover Player/Assassin poses and hazard animation. Read-only visual
selection follows existing action/collision clocks, with immediate Assassin resolution and
separate harmless 0.48 s corpse cleanup. Contact shadows, stepped cast shadows and small hit,
landing, death and hazard effects complete this presentation pass; no camera shake was added.
Verification passed 621 combat/progression, 172 feature-flow, 3,625 audio, 116,980 pause,
318,498 F4 and 2,716,418 scheduler checks (384 pairs and 9,000 encounters). Another 104,713
presentation checks matched 200-success gameplay traces across different cosmetic seeds/rates.
16,484 targeted art checks covered immutable hurtboxes/RNG, mirrored actions, low death poses, 60 real defeats,
single corpse creation, no extra reward, native pause and cleanup. A 16,320-sample baseline/current
geometry trace produced identical SHA-256 hashes for Player actions, hurtboxes and threat/weapon
transforms at representative Levels on both sides. Rendered inspection covered
the requested combat poses, both facings, collapse stages, hazards, background figures/shadows
and a real Level-10 two-threat admission. These checks used automated/injected inputs rather
than physical keyboard playtesting. Following separate manual visual review, the user accepted
Milestones 28 and 29 as COMPLETE for functional development, with the art debt below explicitly
retained. Milestone 30 tuning is implemented and awaiting manual acceptance as described below.

Milestone 30 preserves Levels 1–14 and introduces base speeds 105 at Level 15 and 110 at Level 20,
with minimum gaps 0.20 / 0.10 / 0.00 s at Levels 15 / 20 / 30. The two-threat cap, full response
reservations, turn allowance and 100 ms safety margin remain unchanged. Its baseline verification
used independent type/side RNG; Milestone 31 adds curated selection without changing that curve.
Verification passed 384 existing and 320 additional late-tier pairs, 9,000 progressing encounters,
4,400 fixed-tier encounters, deterministic repeats, input-window sweeps, Pause/F4, higher starts,
combat/scoring, persistence and menu/restart checks. Native 640×360 renders were inspected using
injected inputs; this is not physical-keyboard user acceptance. See the measured curve and caveats
in [DESIGN_NOTES.md](DESIGN_NOTES.md#difficulty-shaping-and-measured-pacing).

**Acceptance focus:** compare the large Level-5→6 overlap step and the modest Level-10→30 escalation.
Level 30+ is intentionally bounded endurance, not an endlessly accelerating inevitable-death timer.
Levels 40/50 match Level 30. The user must judge whether the approximately 9% response-rate increase
and shorter recognition time feel sufficient. The explicit Milestone 31 ticket authorised curated
patterns after the committed Milestone 30 baseline; this does not imply manual acceptance of 30.
Milestone 34 was subsequently explicitly authorised and implemented; it does not discharge the earlier manual/hardware acceptance items.

Milestone 31 adds eight mirrored two-step patterns using the existing pending slot. The selected
step waits unchanged until the ordinary fairness gate admits it; there is no separate queue or
pattern timing override. Starts unlock gradually from Level 4, with random threats remaining
the majority. All 64 targeted pattern/orientation/tier cases, the original 384 pair cases,
320 late-tier pairs, 9,000 progressing encounters and 16,000 fixed-tier encounters passed.
The minimum 100 ms margin and two-unresolved cap were preserved; intended responses survived
every run without starvation. Measured pattern share rose from 18.1% at Level 5 to 39.4% at
Level 20+. All started patterns completed, averaging two steps. Independent RNG comparisons,
same/different seed traces, pause/menu/cosmetic isolation, F4 boundary preservation, death/F2
reset, combat/scoring and feature-flow/persistence checks passed. Native 640×360 captures were
inspected at Levels 5/6/10/20, including delayed second steps and overlapping threats.
See [DESIGN_NOTES.md](DESIGN_NOTES.md#curated-patterns) for the library, exact draw order and metrics.

**Milestone 31 acceptance focus:** manually judge recognisable short combinations, readable
side changes and the balance of authored rhythm against randomness. Automated intended-response
inputs and captured-frame inspection are not user playtesting. Status remains IMPLEMENTED /
MANUAL ACCEPTANCE PENDING. The explicit combined 32/33 ticket proceeded separately; its input work does not imply acceptance of Milestone 31 rhythm.

## Required pre-release character-art polish

**Functional acceptance is not final character-art approval. A substantial anatomy and combat-pose
polish pass is required before release and belongs in Milestone 35 final polish.**

- Current character sprites are acceptable placeholders for continued development: implemented
  first-pass 16-bit combat art, not final character artwork.
- Player punch/kick anatomy and poses are notably weak; limbs currently read too much like bent
  sticks. Player martial-arts anatomy needs a substantial drawing and pose-quality pass.
- Punch must read as a convincing low karate punch.
- Kick must read as a convincing lean-back high martial-arts kick.
- Limbs must have proper volume and joint anatomy rather than stick-like construction.
- Red and Blue sprite anatomy and overall sprite quality must receive the same review.
- Preserve current gameplay timings, hitboxes and animation-state alignment. Animation timing
  and gameplay alignment are good; the debt concerns sprite drawing and pose quality, not timing.

This status is a checkpoint, not a substitute for inspecting the current checkout. Keep it
and CURRENT NEXT TARGET aligned after verified completion. See [DESIGN_NOTES.md](DESIGN_NOTES.md)
for the implemented game behaviour; the remaining sections retain each milestone's requirements.

---

# DEVELOPMENT PHILOSOPHY
Moonfall Dojo is both a game project and a learning project.

Prefer:

- straightforward code
- explicit ownership
- small focused scripts
- readable constants
- deterministic behaviour
- spatial gameplay
- simple architecture
- measurable fairness
- incremental implementation
- strong verification
Avoid:

- speculative abstractions
- unnecessary managers
- autoloads without a strong reason
- event buses
- dependency-injection systems
- inheritance hierarchies merely to reduce a few repeated lines
- premature data-driven frameworks
- implementing future roadmap items early
- refactoring working systems without a concrete need
Do not add features merely because they seem useful.

Implement only the current roadmap item unless instructed otherwise.

---

# CORE GAME IDENTITY
Moonfall Dojo is a single-screen endless arcade reaction/fighting game inspired by early-1990s 16-bit console and arcade games.

The Player stands horizontally fixed near the centre of the screen.

Threats approach from left or right.

The Player responds using:

- Turn
- Punch
- Kick
- Jump
- Duck
The core threat language is:

- Red Assassin -> Kick
- Blue Assassin -> Punch
- Barrel -> Jump
- Shuriken -> Duck
These are intended responses, NOT hardcoded immunity rules.

Success and failure are determined by spatial geometry and timing.

The Player dies from one lethal hit.

Player actions other than turning are committed.

The game should feel demanding but fair.

When the Player dies, the cause should normally be understandable.

---

# CURRENT FOUNDATION
The project already contains or is expected to contain:

- Player turning
- Punch
- Kick
- Jump
- Duck
- Red Assassin
- Blue Assassin
- Barrel
- Shuriken
- left/right encounters
- one-hit death
- spatial collision
- Score
- Kills
- Dodges
- Level
- score multiplier
- persistent High Score
- Level-based threat speed
- fair encounter scheduler
- limited overlapping approaches at higher Levels
- deterministic RNG
- F2 development restart
- F4 development Level advance
- P Pause/Resume
- `AGENTS.md`
- `DESIGN_NOTES.md`
Do not recreate systems that already exist.

Inspect them first.

---

# ROADMAP STATUS RULE
Before starting work, identify which roadmap milestone is already complete.

A milestone counts as complete only if:

- its core functionality exists
- it has been verified
- there are no obvious blocking defects
- its implementation is consistent with `AGENTS.md` and `DESIGN_NOTES.md`
Do not redo completed milestones for polish unless specifically instructed.

Proceed to the earliest incomplete milestone.

---

# PHASE 3 — COMPLETE THE PLAYER-FACING GAME LOOP
The immediate development goal is to transform the working arcade prototype into a game another person can launch and understand without development knowledge.

---

## MILESTONE 21 — PLAYER-FACING GAME OVER AND RESTART
Create a proper Game Over flow.

Required behaviour:

- Player death still follows existing one-hit death rules.
- Existing threat resolution ordering remains deterministic.
- Scheduler stops generating new gameplay threats after death.
- Final Score remains visible.
- Final Kills remain visible.
- Final Dodges remain visible.
- final Level remains visible.
- High Score remains visible.
- show an obvious `GAME OVER` state.
- offer a normal player-facing restart control.
- restart must not require F2.
- F2 remains available as a development shortcut.
Prefer a simple keyboard restart initially.

Do not build the title screen as part of this milestone unless absolutely necessary.

Do not add complex menus.

Verification must include:

- death from Red
- death from Blue
- death from Barrel
- death from Shuriken
- restart after death
- no spawning after death
- Score/High Score persistence behaviour
- restart returns to clean Level 1 state
- development controls continue working as intended
After completion update `DESIGN_NOTES.md`.

---

## MILESTONE 22 — TITLE SCREEN AND START GAME FLOW
Create the first proper entry flow.

Minimum title screen:

- Moonfall Dojo title
- persistent High Score
- Start Game
- Controls
- placeholder Options entry only if useful
Initial startup should no longer immediately begin gameplay.

Start Game begins a fresh run.

Game Over should allow returning/restarting cleanly.

Keep menu architecture simple.

Do not build a generic UI framework.

Keyboard navigation is sufficient initially.

Controller support comes later.

Preserve:

- pause
- F2
- F4
- persistence
- deterministic gameplay
Update `DESIGN_NOTES.md`.

---

## MILESTONE 23 — LOCAL TOP-10 HIGH SCORE TABLE
Expand persistence from one High Score value to a local Top-10 table.

Required:

- up to ten real entries, with empty UI placeholders
- score
- three-character initials
- sorted descending
- qualification detection after Game Over
- initials entry when appropriate
- persistent local storage
- safe handling of missing/corrupt save data
- existing highest-score display should use the top table entry
Keep entry controls simple.

Do not implement online leaderboards.

Do not add accounts.

Migration from the existing single High Score should preserve the old record where practical.

Test:

- qualifying score
- non-qualifying score
- ties
- empty table
- full table
- corrupt/missing save
- restart
- process restart
- initials validation
Update `DESIGN_NOTES.md`.

---

## MILESTONE 24 — HIGHEST LEVEL UNLOCK + START LEVEL
Track the highest Level legitimately reached.

The title/menu should eventually allow:

`Start Level`

with +/- adjustment.

Rules:

- minimum = 1
- maximum = highest legitimately reached Level
- development F4 boosts must NOT unlock higher starting Levels
- highest Level persists locally
- selecting a higher Start Level changes threat speed and scheduler difficulty appropriately
- multiplier remains run-relative
Important multiplier rule:

Starting a run at Level 10 does NOT mean beginning with the Level-10 absolute multiplier.

A new run always begins at x1.0.

Multiplier increases according to Levels survived during that run.

Preserve that existing principle.

Test:

- normal Level unlock
- F4 does not unlock
- persistence
- Start Level bounds
- Level speed
- scheduler pacing
- multiplier run-relative behaviour
Update `DESIGN_NOTES.md`.

---

## MILESTONE 25 — CONTROLS / OPTIONS SHELL
Create a proper Controls screen and simple options structure.

Show current defaults:

- Left / Right = Turn
- Up = Jump
- Down = Duck
- Z = Punch
- X = Kick
- P = Pause
Development controls such as F2/F4 should not be presented as normal gameplay controls.

Prepare architecture for later remapping, but do not over-engineer it.

Potential initial options:

- Sound volume placeholder only if audio work has begun
- Music volume placeholder only if audio work has begun
Do not implement large settings systems without actual settings.

---

# PHASE 4 — PRESENTATION AND GAME FEEL
Once Phase 3 is functional, begin replacing prototype presentation with the intended game identity.

Do this incrementally.

Gameplay physics and fairness should remain stable unless a presentation change exposes a genuine gameplay problem.

---

## MILESTONE 26 — AUDIO FOUNDATION
Introduce basic audio architecture.

Initial requirements:

- Punch sound
- Kick sound
- successful threat hit
- Player death
- Barrel event
- Shuriken event
- menu navigation
- simple music playback
Pause behaviour must work correctly.

Avoid building an elaborate dynamic audio engine.

Use a simple structure appropriate for one game scene/menu flow.

Add volume controls only when actual audio exists.

---

## MILESTONE 27 — ENVIRONMENT ART PASS
Create the visual identity of Moonfall Dojo.

Target:

moonlit outdoor dojo environment with early-1990s 16-bit aesthetics.

Potential layers:

- dark night sky
- moon
- clouds
- distant trees
- dojo/shoji architecture
- torch/fire elements
- fighting floor
- subtle environmental movement
Gameplay readability has priority.

Threats must remain clearly visible.

Do not allow background detail to obscure collision-critical objects.

Logical resolution remains 640×360.

Nearest-neighbour presentation remains.

---

## MILESTONE 28 — CHARACTER AND THREAT ART PASS
Replace primitive Player/threat placeholders with readable sprite artwork.

Priority order:

1. Player Ninja
2. Red Assassin
3. Blue Assassin
4. Barrel
5. Shuriken
Preserve gameplay geometry unless intentionally retuned and verified.

Visuals should communicate collision state clearly.

Player animations should communicate:

- idle
- turn
- Punch
- Kick
- Jump
- Duck
- death
Assassin animations should clearly telegraph attacks.

Do not sacrifice timing readability for animation flourish.

---

## MILESTONE 29 — EFFECTS AND GAME FEEL
Add restrained arcade feedback.

Potential features:

- hit flashes
- impact effects
- Barrel explosion refinement
- Shuriken ground impact
- tiny screen shake
- death impact
- score feedback
- Level-up feedback
Effects must not alter gameplay timing.

Avoid excessive camera motion.

The Player must always be able to read threats.

---

# PHASE 5 — DEPTH AND POLISH
Only begin this phase once the core game is genuinely enjoyable and presentation is coherent.

Do NOT implement these prematurely.

---

## MILESTONE 30 — DIFFICULTY SHAPING
Review the current scheduler using actual playtesting.

Potential improvements:

- pacing curves
- more intentional pressure/release
- Level bands
- threat-spacing refinement
- reaction difficulty tuning
- scheduler safety margin refinement
Do not reduce fairness merely to increase difficulty.

Use F4 extensively for testing.

Automated fairness verification remains mandatory after scheduler changes.

---

## MILESTONE 31 — CURATED ENCOUNTER PATTERNS
Introduce limited designed sequences while preserving scheduler fairness.

Examples could include:

- left/right alternation
- repeated pressure from one side
- Assassin followed by hazard
- hazard followed by Assassin
Patterns must remain survivable.

Do not replace random play entirely.

Do not introduce three simultaneous unresolved threats without separate design approval and mathematical analysis.

---

## MILESTONE 32/33 — CONTROLLER SUPPORT, REMAPPING AND MOBILE INPUT FOUNDATION

Implemented through the explicit combined ticket; hardware/manual acceptance remains pending.

- Shared named actions for keyboard, controller and touch gameplay.
- Controller navigation for title, options, remapping, pause, Game Over and initials entry.
- Keyboard keys and controller buttons/left-stick directions can be rebound for all thirteen
  player-facing actions. Development F2/F4 remain fixed; restart follows Menu Accept.
- Current binding display, capture/cancel, within-context conflict rejection and restore defaults.
- Validated persistent bindings in the existing atomic ConfigFile save.
- Hidden-by-default touch scene: four-way pad (Left/Right/Jump/Duck), Punch, Kick and Pause.
- Desktop test toggle; state changes release touch presses. No separate mobile gameplay path.
- Preserve gameplay timing, scoring, determinism, fairness margins and two-threat cap.

Verification: 136 viewport-dispatched input/remap/touch/persistence checks plus a fresh-process
binding reload passed. Regression runs passed 621 combat/scoring checks, 172 feature-flow checks,
3,497 audio checks, 105,078 pause checks, 280,196 F4 checks, 2,411,086 scheduler checks
(including 384 pair cases and 9,000 progressing encounters), 185,873 late-tier checks (320 pairs),
and 92,017 pattern/menu checks with identical 200-encounter timelines after different menu waits and with the touch overlay
hidden versus enabled.
The prior Controls fixture was updated only for Accept now entering remap capture rather than
returning to Title. Corrupt-save and deliberately blocked-write fixtures emit expected diagnostics; normal runs are clean.
Native 640×360 captures were inspected for controller-driven Title selection, binding conflict
capture, Controls/overlay toggle, gameplay overlay, pause, initials and Game Over. This is injected
input and rendered review, not physical keyboard/controller or real-multitouch playtesting.

Acceptance still required: physical controller mapping/feel, simultaneous real touches, and
user judgement of overlay coverage/readability. Outer approach lanes are partly under translucent
controls; central combat and HUD remain clear. Do not mark hardware acceptance complete from
synthetic input alone. That input-foundation ticket did not include export/browser work; see Milestone 34 below.

---
## MILESTONE 34 — WEB / MOBILE VERSION

**IMPLEMENTED / DEVICE ACCEPTANCE PENDING.**

Moonfall Dojo now has a Web export of the same project, with automatic touch visibility, direct
shared-menu interaction, browser audio/lifecycle handling, landscape/portrait presentation and
Godot PWA support. No gameplay or presentation codebase was forked. Native regression, served
browser and emulated-touch evidence is recorded in [WEB_VERIFICATION.md](tools/WEB_VERIFICATION.md);
[web/README.md](web/README.md) covers export/hosting. Real Android/iPhone/Safari and physical
controller testing remains outstanding. Installation UI and real phone suspension/audio latency
are device acceptance, not inferred from desktop emulation.

This explicitly authorised browser/mobile scope extends the earlier desktop-only V1 scope;
it does not authorise native Android/iOS applications.

Requirements:

- Godot Web export and desktop-browser play.
- Mobile-browser landscape play with responsive 16:9 presentation.
- Enable the 32/33 touch gameplay/Pause foundation for browser/mobile environments; add touch-friendly menus.
- Browser audio-start/autoplay handling after user interaction.
- Preserve desktop keyboard/controller behaviour, deterministic gameplay and fixed action timing.
- Touch must obey committed actions and fresh-press rules, without introducing input buffering.
- Browser/mobile regression tests, including Android browsers and iPhone/Safari where practical;
  report untested devices/browsers explicitly.
- Optional PWA / Add to Home Screen support if practical.

Verify controls, audio, scaling, pause/resume, gameplay fairness and persistence on supported
browsers. Native Android/iOS builds remain outside this milestone unless separately requested.
Milestone 35 is NEXT; it was not implemented in this task.

---

## MILESTONE 35 — FINAL POLISH
Required before release: complete the substantial
[character anatomy and combat-pose polish](#required-pre-release-character-art-polish) above.
Functional completion of Milestones 28/29 does not discharge this art debt. Review Player,
Red and Blue artwork while preserving current gameplay timings, hitboxes and animation-state
alignment; do not retune gameplay to compensate for drawing weaknesses.

Review:

- title presentation
- menus
- HUD
- Game Over
- High Scores
- transitions
- audio balance
- animation
- pacing
- difficulty
- persistence
- pause
- controller
- scaling
- error handling
Remove obsolete development artefacts only when they are no longer useful.

F2/F4 may remain available in development builds if desired.

---

# FUTURE / OPTIONAL FEATURES
These are NOT part of the core roadmap and must not be implemented without explicit instruction.

Possible future work:

- additional threat types
- additional Player abilities
- day/night visual variation
- environmental variations
- character selection
- achievements
- online leaderboards
- multiplayer
- story/campaign
- native mobile application builds (browser/mobile Web support belongs to Milestone 34)
- power-ups
- weapons
- unlockables
- replay system
- attract/demo mode
Treat these as ideas, not requirements.

---

# AUTONOMOUS TICKET WORKFLOW
When asked to continue development without a specific ticket:

1. Read `AGENTS.md`.
2. Read `DESIGN_NOTES.md`.
3. Read this roadmap.
4. Inspect Git status.
5. Inspect recent commits.
6. Determine earliest incomplete milestone.
7. Inspect relevant implementation.
8. Define a small ticket that advances only that milestone.
9. Analyse risks before editing.
10. Implement.
11. Test.
12. Render/inspect when visual behaviour matters.
13. Update `DESIGN_NOTES.md` for settled design changes.
14. Report results.
15. Do NOT commit unless explicitly authorised.
If a milestone is too large for one safe ticket, split it into logical increments.

Example:

Do NOT implement:
Title Screen + High Scores + Options + Remapping

as one enormous ticket.

Instead implement one independently verifiable piece at a time.

---

# STOP CONDITIONS
Stop before implementation and report when:

- existing code contradicts documented design
- a requested change would invalidate established fairness
- Player action timings would need modification
- threat geometry would need modification
- scheduler safety cannot be proven conservatively
- persistence migration risks losing data
- architecture would require a major redesign
- requirements are materially ambiguous
- a roadmap item depends on a previous unfinished milestone
Do NOT silently invent major design decisions merely to continue.

Small implementation details may be chosen reasonably.

---

# TESTING STANDARD
Never claim a test was performed unless it actually was.

For gameplay changes prefer:

- deterministic tests
- spatial collision checks
- boundary timing checks
- seeded long-run simulation
- regression testing
- rendered inspection where useful
Manual playtesting remains necessary for subjective feel.

Automated tests can prove survivability and consistency.

They cannot prove that gameplay feels good.

Report this distinction clearly.

---

# GIT RULES
Before implementation:

- check Git status
After implementation:

- report changed files
- run `git diff --check`
- report final Git status
Do not commit unless explicitly asked.

Do not overwrite unrelated user changes.

Keep commits conceptually focused when commit permission is eventually given.

---

# DOCUMENTATION RULE
Whenever a permanent implemented gameplay rule changes:

update `DESIGN_NOTES.md`.

Examples:

- Player action timing
- threat geometry
- scoring
- progression
- controls
- scheduler behaviour
- persistence
- menu flow
Do not use `DESIGN_NOTES.md` as a changelog.

It should describe the CURRENT game, not its history.

Update `AGENTS.md` only when the project's fundamental standing instructions or intended design constitution change.

---

# PRIORITY ORDER
When multiple possible tasks exist, prioritise:

1. broken gameplay
2. fairness defects
3. save/persistence defects
4. incomplete current milestone
5. player-facing usability
6. presentation
7. polish
8. optional features
Do not abandon core completion to chase novelty.

---

# CURRENT NEXT TARGET

**Milestone 35 — Final Polish** is the next implementation target. Do not mistake this for
completion of outstanding acceptance: Milestones 30/31 still need their user playtesting,
32/33 physical controller/touch acceptance remains, and 34 is IMPLEMENTED / DEVICE ACCEPTANCE
PENDING. The explicit Milestone 34 ticket authorised Web work without declaring those earlier
acceptance items complete.

Milestone 26 has automated verification and user listening acceptance; 27 has automated and
user environment/HUD acceptance. Combined 28/29 are complete for functional development with
the required character-art debt retained under 35. No Milestone 35 implementation or Git commit
was performed as part of 34. Future polish must affect both exports through the one codebase.

Before working, verify the actual repository state rather than assuming this roadmap is perfectly current.
