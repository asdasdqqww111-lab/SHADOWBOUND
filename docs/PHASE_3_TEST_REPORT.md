# SHADOWBOUND — Phase 3 Verification Report

- **Date:** 2026-11-18 (UTC)
- **Version:** `0.3.0`
- **Branch:** `arena/1e3db61b-shadowbound`
- **PR:** https://github.com/asdasdqqww111-lab/SHADOWBOUND/pull/1

## Delivered Scope

- Shared three-hit buffered sword combo, criticals, directional guard/parry/Riposte, dodge immunity, hurt stun, shield-breaking finisher, reflected/sliceable projectiles, damage popups, player defeat and automatic revive.
- Three dual-mode archetypes: Umbral Stalker (melee rush), Rift Arcanist (ranged kite), Obsidian Sentinel (front shield). Seven regular enemies are placed across the cliffs/courtyard.
- Vaelor, Warden of the Eclipse: 320 HP, phases at 65% / 30%, phase-shift immunity, cleave, dash, three-orb fan and eight-orb nova, localized health/phase bar and victory feedback.
- Reset restores enemies, boss phase and player vitals; mode switches preserve enemy progress but clear projectiles. Session counters are cumulative across retries.
- 28 original CC0 RGBA PNGs, 23 player animations / 112 frames, four enemy/boss SpriteFrames, 103 paired EN/AR keys with Cairo RTL support.

## Executed Locally

| Check | Result |
| --- | --- |
| `python3 tests/validate_project.py` | **325 passed, 0 failed** |
| `python3 tests/test_gameplay_logic.py` | **56 passed, 0 failed** |
| `gdlint scripts resources tests/gdscript` | **30 scripts, 0 problems** |
| `gdparse` via project validator | **30 scripts parsed** |
| `git diff --check` | Clean |

**381 Python checks passed.** These are static/AST/resource/geometry checks, not native Godot execution. gdtoolkit is an independent GDScript parser, not the Godot compiler.

The expanded checks cover ordered combo specs, animation bindings, defense/phase configuration, inherited enemy node paths, hurtbox layers/groups, enemy localization, atlas bounds, actor placement, platform patrol safety, courtyard pillar clearance, and safe boss-spawn distance.

## Native Runtime Verification

`tests/gdscript/test_phase3_runner.tscn` adds executable integration coverage for actual resolver outcomes, critical/Riposte damage, both controllers' combo buffering and recovery, per-swing deduplication, shield break, defeat idempotence, projectile reflection, boss phase thresholds/immunity/nova/victory, projectile cleanup, auto-revive/reset and Arabic HUD direction.

The sandbox has no Godot executable. Official binary download redirects to `release-assets.githubusercontent.com`, blocked by the sandbox host allowlist. **No local Godot runtime pass or rendered gameplay/device pass is claimed.**

`.github/workflows/validate.yml` installs Godot 4.3 stable on Ubuntu, imports assets, runs all three native suites, and rejects engine errors/warnings. CI results are pending the branch push at the time of this report; they must be checked independently before merge.

Reproduce on a workstation with Godot 4.3+:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase2_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase3_runner.tscn
```

## Corrections Found During Review

- Reduced boss attack-selection returns without suppressing lint rules; retained all three phase patterns.
- Reset the player swing registry on controller changes so matching swing IDs across modes cannot suppress a valid first hit.
- Moved the top-down spawn south of the boss's aggro radius (500px initial separation vs 420px aggro).
- Preserved exact scene resource counts and resolved inherited enemy-node contracts, not just paths declared in each derived script.

## Manual Acceptance Still Required

- Play both modes through all enemies and all three boss phases; check telegraph readability, guard arcs, dodge timing, combo feel and difficulty.
- Check EN/AR text fit, boss/status panel layout, font shaping and five-button multitouch on a real Android 9+ device.
- Verify mobile performance, resume/Back behavior and frame-rate-dependent projectile collision at low FPS.
- No Android APK was built (export verification remains Phase 9). Audio, progression rewards and loot are outside this milestone.
