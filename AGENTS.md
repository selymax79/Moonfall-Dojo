# Moonfall Dojo — Project Instructions

## Purpose and working approach

Moonfall Dojo is a learning project for both Godot and Codex. Keep the architecture simple, readable, and beginner-friendly.

- Prefer straightforward solutions over clever abstractions.
- Keep scripts reasonably small and focused; avoid giant scripts with unrelated responsibilities.
- Use descriptive names. Comment non-obvious game logic without over-commenting trivial code.
- Explain significant architectural decisions.
- Before substantial changes, inspect existing code and explain the proposed approach.
- Make changes in small, testable increments and preserve existing working behaviour.
- Do not introduce unnecessary frameworks, plugins, or dependencies.
- Do not add features merely because they seem useful or implement future ideas without an explicit request.
- After implementation, report the files changed and what was actually tested. Never claim a test was performed unless it was.

This document defines the intended game, not permission to implement everything at once. Implement only the work explicitly requested. The initial documentation task must create only this file: no scenes, scripts, folders, assets, other files, or changes to `project.godot`.

## Project overview

**Title:** Moonfall Dojo

A single-screen 2D arcade reaction game inspired by the presentation of early-1990s 16-bit console games.

The player controls a ninja who stays horizontally stationary in the centre of the screen and cannot walk. Assassins and environmental hazards approach endlessly from either side. There is no victory condition: difficulty increases until the player dies.

## Technology and display

- Godot 4.7 and GDScript.
- 2D only; desktop-first.
- Compatibility renderer.
- Logical game resolution: 640 × 360, with a 16:9 aspect ratio.
- Scale automatically to the window or display while preserving aspect ratio.
- Use integer scaling and nearest-neighbour filtering for pixel art wherever practical.
- Use Git for version control.

## Player actions

Available actions: turn left, turn right, punch, kick, jump, and duck.

- The player remains horizontally stationary, including while jumping.
- Turning is extremely quick but has a short animation. A turn can be reversed immediately.
- Punch, kick, jump, and duck are committed actions: their animation and recovery must finish before another action can begin.
- Duck is a complete crouch-and-stand animation and cannot be held indefinitely.
- Player action timings remain constant at every level. Increase difficulty by making the world faster, never by weakening or slowing the player.

## Threats and combat

Every threat can approach from the left or right. Every threat kills the player with one successful hit or collision. Every assassin dies from one correct attack.

| Threat | Required response | Physical explanation and timing |
| --- | --- | --- |
| Red Assassin | Kick while facing the assassin. | Carries a katana. A punch lacks the reach to beat the katana, which hits the player first. One successful kick kills the assassin. |
| Blue Assassin | Punch while facing the assassin. | Unarmed; attacks with a low/crouching punch that causes a kick to miss. One successful punch kills the assassin. |
| Barrel | Jump; facing does not matter. | Rolls along the floor. Jumping too early can make the player land on it. |
| Shuriken | Duck; facing does not matter. | Travels at upper-body/head height. Ducking too early can make the player stand into it. |

An incorrect response must not magically trigger death. Wherever possible, animation, range, and physical collision must explain the outcome.

## Gameplay fairness

- Later levels may show multiple threats simultaneously.
- Required action and lethal windows must **never** overlap in a way that makes survival impossible.
- The threat generator must eventually account for player action duration and recovery when scheduling threats.
- Every generated sequence must remain theoretically survivable, even at extreme difficulty.
- Increasing movement speed and reducing spawn intervals must respect this fairness requirement.

## Progression

- Levels continue infinitely.
- Advance one level after every four successfully handled threats.
- Both kills and dodges count; progression is based on kills + dodges, not score.
- Threat movement speed increases with level, and spawn interval decreases with level.
- Player movement/action speed never changes.
- Levelling up does not interrupt gameplay.

## Scoring and HUD

Each successful kill or dodge has a base value of 100 points. Track kills and dodges separately.

The score multiplier increases by 0.5 every three levels:

| Levels when starting at Level 1 | Multiplier |
| --- | --- |
| 1–3 | ×1.0 |
| 4–6 | ×1.5 |
| 7–9 | ×2.0 |
| 10–12 | ×2.5 |

Continue this pattern indefinitely. Apply the starting-level rule below when a run begins above Level 1.

The HUD displays:

- Score.
- High Score.
- Kills.
- Dodges.
- Level.
- Current multiplier.

## Starting level

- Allow the player to choose a starting level from Level 1 through the highest level they have previously reached.
- Apply the threat speed and difficulty appropriate to the selected level.
- The score multiplier is based on levels survived during the current run, not the absolute game level. Always begin at ×1.0 and increase it by 0.5 after every three levels survived from the selected starting point.
- For a Level 1 start, Levels 1–3 use ×1.0, Levels 4–6 use ×1.5, Levels 7–9 use ×2.0, and so on.
- A Level 10 start also begins at ×1.0: Levels 10–12 use ×1.0; after surviving those three levels, Levels 13–15 use ×1.5, then Levels 16–18 use ×2.0, and so on.
- Starting at a higher level provides increased difficulty without granting an immediate scoring advantage.

## Menus and controls

### Main/title screen

- Moonfall Dojo title.
- Current high score.
- Start.
- Start Level with + and − controls.
- Controls.
- Sound Options.
- High Scores.

### Controls menu

Allow both keyboard and controller controls to be remapped.

| Action | Default keyboard | Default controller |
| --- | --- | --- |
| Turn left/right | Left/Right arrows | D-pad Left/Right |
| Jump | Up arrow | D-pad Up |
| Duck | Down arrow | D-pad Down |
| Punch | Z | X/Square-style face button |
| Kick | X | A/Cross-style face button |
| Pause | Escape | Not specified |

### Sound Options

- Music on/off and music volume.
- Sound effects on/off and sound effects volume.
- Master mute shortcut available during gameplay; default binding is not specified.

### Pause menu

- Resume.
- Restart.
- Quit to title.

## High scores and persistence

- Maintain a persistent local Top 10 high-score table.
- Initially populate it with deliberately beatable fictional/historical ninja-themed Easter-egg scores.
- After death, let a qualifying player enter three-character arcade-style initials.
- Persist high scores locally.
- Retain the highest level previously reached so it can limit the starting-level selector.

## Death and Game Over

- Death occurs after one successful enemy hit or hazard collision.
- A player death/fall animation is required. Where practical, the animation should vary according to what killed the player.
- Stop music abruptly on player death, before the Game Over sequence.
- After the death animation, display Game Over and the high-score table.
- Prompt for initials if the score qualifies for the Top 10.

## Visual direction

Use an early-1990s 16-bit console/arcade aesthetic. Background detail must never interfere with threat readability.

### Environment

- Open-air Japanese dojo.
- Dark night sky across the upper third, with a large moon and multiple parallax cloud layers.
- Dark silhouette of tree branches entering from one side.
- Dojo occupying the lower two-thirds, with Japanese architectural styling.
- Shoji screens with rare, subtle animated silhouettes behind them.
- Flame torches/braziers on both sides with flickering flames.
- Bamboo/wooden floor.

### Characters and hazards

- Dark/black player ninja with a strong, readable silhouette.
- Small secondary animation, such as headband/scarf movement, is desirable.
- Immediately distinguishable red assassin with a visible katana and blue unarmed assassin.
- Highly readable barrel and shuriken silhouettes.

## Audio direction

- 16-bit-inspired action music.
- Music may gain intensity or additional layers as levels increase; do not simply increase playback speed every level.
- Distinct sound effects for punch, kick, katana, enemy deaths, jump, duck, barrel, shuriken, level-up, multiplier increase, and player death.
- Threat entry sounds may reinforce visual identification.
- Music stops abruptly on player death before Game Over.

## Version 1 scope

Do not expand the game beyond this specification unless explicitly instructed.

The following are explicitly out of scope for V1:

- Day/night cycle.
- Online leaderboards.
- Multiplayer.
- Achievements.
- Character selection.
- Weapons/power-ups.
- Additional enemy types.
- Additional obstacle types.
- Story/campaign mode.
- Mobile support.

### Possible V2 idea — do not implement now

A dynamic day/night cycle tied cosmetically to progression, approximately one complete cycle every 40 levels. It must not affect gameplay or threat readability. This is a future possibility, not an approved implementation task.
