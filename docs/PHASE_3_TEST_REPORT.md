# SHADOWBOUND — Phase 3 Verification Report

- **Date:** 2026-11-18 (UTC)
- **Version:** `0.3.0`
- **Branch:** `arena/1e3db61b-shadowbound`
- **PR:** https://github.com/asdasdqqww111-lab/SHADOWBOUND/pull/1

## ملخص المرحلة الثالثة

تم تنفيذ نظام القتال المشترك، سلسلة ضربات من ثلاث خطوات، الصد المثالي والهجوم المضاد، ثلاثة أنواع من الأعداء في نمطَي اللعب، والزعيم «فايلور» بثلاث مراحل. نجح **529 فحصًا**: 382 فحصًا ساكنًا و147 اختبارًا فعليًا على Godot عبر CI، دون أخطاء أو تحذيرات من المحرّك. ما زال الاختبار البصري على جهاز Android وتصدير APK مطلوبَين لاحقًا؛ لا يشملهما نجاح اختبارات Headless.

## Delivered Scope

- Shared three-hit buffered sword combo, criticals, directional guard/parry/Riposte, dodge immunity, hurt stun, shield-breaking finisher, reflected/sliceable projectiles, damage popups, player defeat and automatic revive.
- Three dual-mode archetypes: Umbral Stalker (melee rush), Rift Arcanist (ranged kite), Obsidian Sentinel (front shield). Seven regular enemies are placed across the cliffs/courtyard.
- Vaelor, Warden of the Eclipse: 320 HP, phases at 65% / 30%, phase-shift immunity, cleave, dash, three-orb fan and eight-orb nova, localized health/phase bar and victory feedback.
- Reset restores enemies, boss phase and player vitals; mode switches preserve enemy progress but clear projectiles. Session counters are cumulative across retries.
- 28 original CC0 RGBA PNGs, 23 player animations / 112 frames, four enemy/boss SpriteFrames, 103 paired EN/AR keys with Cairo RTL support.

## Executed Locally

| Check | Result |
| --- | --- |
| `python3 tests/validate_project.py` | **326 passed, 0 failed** |
| `python3 tests/test_gameplay_logic.py` | **56 passed, 0 failed** |
| `gdlint scripts resources tests/gdscript` | **30 scripts, 0 problems** |
| `gdparse` via project validator | **30 scripts parsed** |
| `git diff --check` | Clean |
| Regenerate all art and compare SHA-256 | All 28 PNGs byte-identical |

**382 Python checks passed.** These are static/AST/resource/geometry checks, not native Godot execution. gdtoolkit is an independent GDScript parser, not the Godot compiler.

The expanded checks cover ordered combo specs, animation bindings, defense/phase configuration, inherited enemy node paths, hurtbox layers/groups, enemy localization, atlas bounds, actor placement, platform patrol safety, courtyard pillar clearance, and safe boss-spawn distance.

## Native Runtime Verification

`tests/gdscript/test_phase3_runner.tscn` adds executable integration coverage for actual resolver outcomes, critical/Riposte damage, both controllers' combo buffering and recovery, per-swing deduplication, shield break, defeat idempotence, projectile reflection, boss phase thresholds/immunity/nova/victory, projectile cleanup, auto-revive/reset and Arabic HUD direction.

### Executed on GitHub Actions — PASS

**Godot 4.3 stable (`77dcf97d8`)**, Ubuntu 24.04, successful CI run:
https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44420924671

Verified source commit: `9e956fa` (subsequent report-only edits do not change game behavior).

| Native check | Result |
| --- | --- |
| Asset import / native script compilation | Clean; no engine errors/warnings |
| Phase 1 regression runner | **46 passed, 0 failed** |
| Phase 2 regression runner | **45 passed, 0 failed** |
| Phase 3 combat integration runner | **56 passed, 0 failed** |
| Native total | **147 passed, 0 failed** |

**Combined executed checks: 529 passed** (382 Python/static + 147 native). Logs are available as the workflow's `godot-headless-logs` artifact and the **Native Godot diagnostics** check output. Both push and PR CI runs passed on the verified source commit.

### Local Environment Limitation

The sandbox has no Godot executable. Official binary download redirects to `release-assets.githubusercontent.com`, blocked by the sandbox host allowlist. **Native Godot was therefore run on CI, not locally. No rendered gameplay/device pass is claimed.**

`.github/workflows/validate.yml` installs Godot 4.3 stable on Ubuntu, imports assets, runs all three native suites, and rejects engine errors/warnings. The successful native results above were read from the completed CI check output; future changes must keep the validation job green.

Reproduce on a workstation with Godot 4.3+:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase2_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase3_runner.tscn
```

## Corrections Found During Review

- Native compilation exposed a pre-existing Phase 2 `Area2D.priority` redeclaration. Renamed the custom property to `camera_priority` in scripts, scene overrides and native tests; added a static regression check. The next CI run compiled cleanly and passed all suites.
- Reduced boss attack-selection returns without suppressing lint rules; retained all three phase patterns.
- Reset the player swing registry on controller changes so matching swing IDs across modes cannot suppress a valid first hit.
- Moved the top-down spawn south of the boss's aggro radius (500px initial separation vs 420px aggro).
- Preserved exact scene resource counts and resolved inherited enemy-node contracts, not just paths declared in each derived script.

## Manual Acceptance Still Required

- Play both modes through all enemies and all three boss phases; check telegraph readability, guard arcs, dodge timing, combo feel and difficulty.
- Check EN/AR text fit, boss/status panel layout, font shaping and five-button multitouch on a real Android 9+ device.
- Verify mobile performance, resume/Back behavior and frame-rate-dependent projectile collision at low FPS.
- No Android APK was built (export verification remains Phase 9). Audio, progression rewards and loot are outside this milestone.


## Follow-up — Android Preview Now Available

At the user's request, an installable Phase 3 APK was subsequently built, verified and published before Phase 4. See [Android preview build report](ANDROID_PREVIEW_TEST_REPORT.md) and [download the APK](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.3.0-android-preview-2/SHADOWBOUND-v0.3.0-preview.apk). Earlier statements above about APK export being pending describe the original Phase 3 handoff; the remaining limitation is physical-device/visual testing, not APK availability.
