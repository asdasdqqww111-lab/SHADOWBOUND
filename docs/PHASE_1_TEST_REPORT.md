# SHADOWBOUND — Phase 1 Verification & Test Report

- **Date:** 2026-11-18 (UTC)
- **Branch:** `arena/1e3db61b-shadowbound`
- **Base Commit:** `24a7d55e2e4320dabc8f560a1214849898b97088` (`main`)
- **Milestone:** Phase 1 — Project Setup, Main Menu, Playable Anime Stickman, Dual Movement & Camera Switching, Twilight Sanctum Level, Touch Controls, Bilingual EN/AR RTL Foundation

---

## 1. Executed Automated Test Suites & Real Results

| Test Suite | Command | Result | Details |
| --- | --- | --- | --- |
| **Project, GDScript AST, Lint, Scene, Resource, Atlas & Localization Validator** | `python3 tests/validate_project.py` | **160 / 160 PASSED** (`exit 0`) | Validated `project.godot` (`config_version=5`), all 9 required directories, zero secrets/keystores/APKs, `gdparse` (Godot 4 AST parser via `gdtoolkit 4.5.0`) across 16/16 `.gd` scripts, `gdlint` across 16/16 `.gd` scripts, 11/11 `.tscn`/`.tres` files (`format=3`, exact `load_steps`, zero missing `ExtResource`/`SubResource` references, all `@onready $NodePath` targets resolved, all 77 `AtlasTexture` rects strictly within PNG bounds, all 14 character animations present), 51/51 EN/AR localization keys with 100% key and placeholder parity and logical UTF-8 Arabic script, 20/20 RGBA PNG binary checks, Cairo TrueType font load check, SVG XML parse, and license files. |
| **Gameplay Physics, Level Reachability & Touch Ergonomics Suite** | `python3 tests/test_gameplay_logic.py` | **17 / 17 PASSED** (`exit 0`) | Verified single-jump apex (`102.4 px`), double-jump apex (`184.3 px`), horizontal jump span (`228.4 px`), single-jump reachability across all main `SideScrollZone` terraces, double-jump reachability for `UpperOverlookLedge` (`150 px` climb), safe abyss respawn threshold (`y = 380`), 8-direction top-down diagonal velocity normalization (`265.0 px/s`), `TopDownSpawn` enclosure & pillar clearance (`427.1 px`), Android touch button minimum dimensions (`92x92` to `116x116 px`), and zero circle overlap in `ActionCluster`. |
| **Signal & Callback Cross-Script Audit** | Static cross-file verification | **PASSED** (`0 errors`) | Audited 16 custom signals and 149 functions across all 16 `.gd` files for `.connect()`, `.call()`, `has_method()`, and `has_signal()` integrity. |

### Issues Found & Fixed During Phase 1 Testing

1. `gdlint` reported two lines exceeding 120 characters in `tests/gdscript/test_phase1_headless.gd` (initial run: `153 passed, 1 failed`). Wrapped both lines cleanly and refactored the Godot headless runner into a standard scene (`tests/gdscript/test_phase1_runner.tscn`) so `[autoload]` singletons (`LocalizationManager`, `GameState`) mount identically to production gameplay (`160 passed, 0 failed`).
2. Added `_nearby_rift_count = 0` reset in `PlayerCharacter.set_mode()` to guarantee proximity state never lingers across instant zone transitions.
3. Added `class_name PlayerCharacter` on `scripts/player/player_controller.gd` for compile-time typed access from `twilight_sanctum_level.gd` and headless tests.

---

## 2. Environment Notes & Honest Limitations

- **Godot 4 Binary in Cloud Sandbox:** The current Linux sandbox does not have a preinstalled `godot` binary, and outbound egress is restricted to GitHub API/PyPI/npm (blocking release binary downloads from `objects.githubusercontent.com`). Therefore, GDScript syntax/AST/linting (`gdtoolkit 4.5.0`), `.tscn`/`.tres` resource graphs, node paths, atlas bounds, signals, localization tables, and physics math were verified directly here, and the native Godot 4 headless runtime test scene is shipped ready to run locally on any machine with Godot 4.3+ installed:
  ```bash
  godot --headless --path . --import
  godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
  ```
- **Android APK Export Status:** **Not yet exported** (Phase 1 scope). `export_presets.cfg.example` is provided targeting Android 9.0+ (`min_sdk="28"`, `target_sdk="34"`, offline/zero network permissions, `include_filter="*.json"`). Actual APK generation and verification require Godot Android export templates + Android SDK + OpenJDK 17 and are scheduled for Phase 9.

---

## 3. Phase 1 Deliverable Checklist

| # | Deliverable | Status | Primary Files |
| --- | --- | --- | --- |
| 1 | Valid `project.godot` | **Complete** | `project.godot`, `icon.svg`, `export_presets.cfg.example` |
| 2 | Working main menu | **Complete** | `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`, `resources/themes/fantasy_ui_theme.tres` |
| 3 | Playable Stickman character | **Complete** | `scenes/player/player.tscn`, `scripts/player/player_controller.gd`, `resources/player/player_profile.gd` |
| 4 | Character animations (14 animations, 73 frames) | **Complete** | `assets/sprites/player/stickman_sidescroll_sheet.png`, `assets/sprites/player/stickman_topdown_sheet.png`, `resources/sprites/stickman_sprite_frames.tres` |
| 5 | Side-scrolling movement (run, gravity, jump, double jump, dodge, slash) | **Complete** | `scripts/player/side_scroll_controller.gd`, `data/config/movement_config.json` |
| 6 | Top-down movement prototype (8-dir move, dodge, directional slash) | **Complete** | `scripts/player/top_down_controller.gd`, `data/config/movement_config.json` |
| 7 | Camera switching (mode-aware zoom, lookahead, limits, shake) | **Complete** | `scripts/camera/dual_mode_camera.gd`, `scripts/autoload/game_state.gd`, `scripts/world/rift_gate.gd` |
| 8 | One playable fantasy environment (*Twilight Sanctum*) | **Complete** | `scenes/levels/twilight_sanctum.tscn`, `scripts/world/twilight_sanctum_level.gd`, `scenes/props/*` |
| 9 | Basic touch controls (multi-touch virtual joystick + ATK/JUMP/DODGE/MODE) | **Complete** | `scenes/ui/touch_controls.tscn`, `scripts/ui/touch_controls.gd`, `scripts/ui/virtual_joystick.gd`, `scenes/ui/game_hud.tscn` |
| 10 | Clear README with run instructions (+ credits & licenses) | **Complete** | `README.md`, `ASSET_CREDITS.md`, `licenses/*`, `docs/*` |
