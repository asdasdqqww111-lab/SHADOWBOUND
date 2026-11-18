# SHADOWBOUND — Phase 2 Verification & Test Report

- **Date:** 2026-11-18
- **Branch:** `arena/1e3db61b-shadowbound`
- **Version:** `0.2.0` (Phase 2 — Dual Camera Modes & Separate Full Movement Controllers)

---

## 1. Executed Automated Checks & Real Results

| Test Suite / Tool | Command Executed | Result | Scope Verified |
| --- | --- | --- | --- |
| **Godot 4 GDScript AST Parser (`gdparse` 4.5.0)** | via `python3 tests/validate_project.py` | **20 / 20 PASS** | Every `.gd` script parses into a valid Godot 4 AST with zero syntax errors. |
| **Godot 4 GDScript Linter (`gdlint` 4.5.0)** | via `python3 tests/validate_project.py` | **20 / 20 PASS** | Zero lint errors or style violations across all 20 scripts. |
| **Project, Scene, Resource, Signal & Localization Validator** | `python3 tests/validate_project.py` | **199 / 199 PASS (0 failed)** | `project.godot` (12 input actions, RTL, GL Compatibility), zero autoload/`class_name` collisions, zero unsafe Variant `:=` inferences, 25 signals & 209 functions cross-checked, all 16 `.tscn`/`.tres` exact `load_steps` & `@onready $NodePath` resolution, all 17 `SpriteFrames` animations & 85 `AtlasTexture` bounds, 74 EN/AR localization keys + 13 dynamic `state.*` keys + 2 `lore.*` keys, and 23 RGBA PNG + font + license checks. |
| **Phase 2 Gameplay, Camera & Touch Ergonomics Suite** | `python3 tests/test_gameplay_logic.py` | **34 / 34 PASS (0 failed)** | Side-scroll jump (`102.4 px`), double-jump (`184.3 px`), apex hang (`0.76x`), turn-snap (`1.65x`), platform & one-way skybridge reachability (`84 px`, `74 px`), `WallJumpTower` clearance (`154 px`) & wall-jump span (`128 px > 100 px`), dodge i-frames & perfect-guard window; Top-down 8-compass (`E..NE`) exact mapping, unit-circle normalization (`265.0 px/s`), `walk (138) < run (265) < sprint (360) < dodge (585)` speed hierarchy, courtyard Lore Runestone clearance; both `CameraModeProfile` `.tres` resources & 3 `CameraZoneTrigger` vista zones; and 5 Android touch buttons (`>= 92x92 px`) with zero pairwise overlaps. |
| **Credential & Binary Hygiene Scan** | `git status` + validator section 1 | **PASS** | Zero secrets, tokens, `.keystore`, `.jks`, `export_presets.cfg`, or unverified `.apk` files. |

---

## 2. Issue Caught & Fixed During Phase 2 Verification

1. **`WallJumpTower` Main-Path Vertical Clearance (`scenes/levels/twilight_sanctum.tscn`):**
   - Initial placement at `(1148, -210)` left only `40 px` clearance above `HighShrinePlatform` (`y = -60`), narrower than the `66 px` player capsule height.
   - **Fix:** Relocated `WallJumpTower` to `(660, -210)` above `StartTerrace` (`154 px` vertical head clearance on the main eastbound path) while positioning its right face exactly `100 px` west of `UpperOverlookLedge` (`792, -210`) — cleanly within the `128 px` wall-jump horizontal arc. Added a regression assertion in `tests/test_gameplay_logic.py`.

---

## 3. Environment Limitations & Honest Disclosure

- **Godot 4 Native Binary (`godot --headless`):** Not pre-installed in this sandbox environment (and GitHub Release binary redirects to `objects.githubusercontent.com` are blocked by sandbox egress rules). Both `tests/gdscript/test_phase1_runner.tscn` and `tests/gdscript/test_phase2_runner.tscn` were AST-verified, linted, and method-signature-checked against all project scripts, and are ready to execute on any workstation or CI runner with Godot 4.3+ installed.
- **Android APK Export:** **Not generated in Phase 2** (scheduled for Phase 9). No APK build is claimed as completed until an actual APK is built and verified.
