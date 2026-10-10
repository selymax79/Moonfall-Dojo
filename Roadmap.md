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
| 22 — Title Screen and Start Game Flow | NEXT: not implemented. |
| 23–34 | Pending: proceed in the sequence below. |

Milestone 21 provides GAME OVER after the death animation, the retained final HUD and
Enter restart into a clean Level 1 run with persistent High Score. Verification covered
deaths from all four threats on both sides, restart/input isolation, no post-death admissions
or rewards, cosmetic cleanup after death, P/F2/F4 interactions, scoring and persistence.
Regression checks passed for all 384 scheduler pair cases, 9,000 scheduled encounters,
seeded determinism, pause and development progression. Fresh 640×360 renders were inspected.
Keyboard checks used injected Godot events; physical keyboard playtesting was not performed.
Completion describes verified functionality in the checkout, not whether it has been committed.

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

- ten entries
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

## MILESTONE 32 — CONTROLLER SUPPORT
Add controller input.

Requirements:

- gameplay controls
- menus
- pause
- initials entry where appropriate
Do not break keyboard controls.

---

## MILESTONE 33 — CONTROL REMAPPING
Allow player-facing controls to be rebound.

Preserve development keys separately.

Provide conflict handling.

Persist mappings.

Keep the UI simple.

---

## MILESTONE 34 — FINAL POLISH
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
- mobile version
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
Unless repository state indicates it has already been completed, the next intended milestone is:

**Milestone 22 — Title Screen and Start Game Flow — NEXT**

Continue sequentially from there.

Before working, verify the actual repository state rather than assuming this roadmap is perfectly current.
