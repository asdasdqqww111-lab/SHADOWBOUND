# SHADOWBOUND

**SHADOWBOUND** (*عهد الظلال*) is an offline single-player 2D Anime Fantasy Stickman RPG built with **Godot 4.x stable** and **GDScript**, designed for **Android (9.0 / API 28+)** and desktop testing with full **English (LTR)** and **Arabic (RTL)** support.

> **Current Milestone:** **Phase 2 — Dual Camera System & Separate Full Movement Controllers (`v0.2.0`)**

---

## Delivered Features (Phases 1 & 2)

1. **Dedicated Dual-Mode Camera System (`resources/camera/`, `scripts/camera/`)**
   - Data-driven **`CameraModeProfile`** resources for both modes (`side_scroll_camera_profile.tres` and `top_down_camera_profile.tres`).
   - **Side-Scrolling Camera:** Elevated platformer horizon, responsive facing/velocity lookahead, vertical jump deadzone, fast-fall downward landing peek, guard focus zoom, and world boundary clamping.
   - **Top-Down Camera:** Balanced 3/4 RPG exploration framing, symmetric 2D deadzone, 8-direction lookahead, sprint zoom-out, and guard focus zoom.
   - **Contextual Camera Vista & POI Zones (`CameraZoneTrigger`):** Priority-stacked panoramic zoom and focal-point framing at the Cliffside Overlook, East Shadow Rift, and North Sanctum Altar, plus player-selectable **Standard / Wide** camera zoom presets persisted to `user://settings.cfg`.
   - **Smooth Mode Transitions:** Preserves each zone's exact player position, facing vector, and shared `PlayerProfile` state (`Kael / كايل`, HP, MP, Stamina, combo count, mode-switch count).
2. **Full Side-Scrolling Movement Controller (`scripts/player/side_scroll_controller.gd`)**
   - Snappy acceleration + 1.65x turn-reversal boost, asymmetric jump/fall gravity, apex hang smoothing, coyote time, jump buffering, variable jump height, and **Double Jump**.
   - **Wall Slide & Wall Jump** with clamped descent, forgiving wall-coyote grace, and air-dodge refresh.
   - **One-Way Skybridge Drop-Through** (`Down + Jump` on Layer 8 `world_oneway`).
   - **Shadow Dodge** (ground & limited 1x air dodge) with invulnerability frames (i-frames) and cyan shimmer feedback.
   - **Shadow Guard (Block)** with a `0.18s` **Perfect Guard** parry window, stamina drain, and slow guarded footing, plus lunge-assisted **Sword Slash**.
3. **Full 8-Direction Top-Down Movement Controller (`scripts/player/top_down_controller.gd`)**
   - True 8-compass locomotion (`E`, `SE`, `S`, `SW`, `W`, `NW`, `N`, `NE`) with strict unit-circle diagonal normalization, turn-snap boost, analog joystick **Walk**, full **Run**, and stamina-powered **Sprint**.
   - **8-Way Shadow Dodge** with i-frames, pivotable **Directional Shadow Guard** with `0.18s` Perfect Guard window, **8-Way Sword Slash**, and contextual exploration interaction with **Ancient Lore Runestones** and **Shadow Rift Gates**.
4. **17 Unified Stickman Animations & Expanded Twilight Sanctum**
   - 85 frames across `idle`, `run`, `jump`, `fall`, `dodge`, `attack`, `block`, `wall_slide`, `td_idle_down/up/side`, `td_walk_down/up/side`, `td_dodge`, `td_attack`, and `td_block`.
   - Upgraded `scenes/levels/twilight_sanctum.tscn` with two pass-through **One-Way Skybridges**, a **Wall-Jump Ruin Tower** leading to the upper overlook, two bilingual **Lore Runestones** in the courtyard wings, and three **Camera Vista Zones**.
5. **Android 9+ Multi-Touch & Bilingual English / Arabic (RTL) UI**
   - Non-overlapping 5-button right-thumb fan (`ATK`, `JUMP/ACT`, hold-capable `GUARD`, `DODGE`, `MODE`) + left-thumb analog `VirtualJoystick`, live HUD movement-state/compass/`[VISTA]` readout, Camera View settings in Main & Pause menus, and 74 paired EN/AR RTL localization keys bundled with the SIL OFL **Cairo** font.

---

## Controls

| Action | Android / Touch | Keyboard | Gamepad |
| --- | --- | --- | --- |
| **Move (Side-Scroll / 8-Dir Top-Down)** | Left Virtual Joystick (analog walk/run) | `W A S D` / Arrow Keys | Left Stick / D-Pad |
| **Jump, Double Jump & Wall Jump** *(Side-Scroll)* | `JUMP` | `Space` | A / Cross |
| **Drop Through One-Way Bridge** *(Side-Scroll)* | Joystick Down + `JUMP` | `S`/`Down` + `Space` | Down + A |
| **Sprint** *(Top-Down)* | — *(Full stick runs; keyboard/pad sprint)* | `Ctrl` | L2 / LT |
| **Sword Slash** | `ATK` | `J` or `Z` | X / Square |
| **Shadow Guard / Perfect Guard** *(Hold)* | Hold `GUARD` | Hold `C` or `X` | L1 / LB |
| **Shadow Dodge (w/ i-frames)** | `DODGE` | `Shift` or `K` | B / Circle |
| **Interact (Rift Gate / Lore Runestone)** | `ACT` *(when in range)* | `E` or `F` | Y / Triangle |
| **Switch Camera & Gameplay Mode** | `MODE` or HUD Button | `Tab` or `M` | R1 / RB |
| **Pause / Resume** | HUD `Pause` / Android Back | `Esc` or `P` | Start |

---

## How to Run (Godot 4.x Stable)

1. Clone the repository:
   ```bash
   git clone https://github.com/asdasdqqww111-lab/SHADOWBOUND.git
   cd SHADOWBOUND
   ```
2. Open **Godot 4.3+ stable** (standard GDScript edition), click **Import**, select `project.godot`, and press **F5** (or run `godot --path .`).

---

## Running Tests & Validation

### 1. Godot Headless Runtime Test Suites (Phases 1 & 2)
```bash
godot --headless --path . --import
godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase2_runner.tscn
```

### 2. Automated AST, Linter, Scene/Resource, Signal & Physics Suites
```bash
pip install gdtoolkit pillow
python3 tests/validate_project.py
python3 tests/test_gameplay_logic.py
```

---

## Android APK Export Setup (Android 9.0 / API 28+)

1. Install matching Godot 4 **Export Templates** and configure **Android SDK (API 34)** + **OpenJDK 17** + local debug keystore (never commit `.keystore` files).
2. Copy `export_presets.cfg.example` to `export_presets.cfg` (`min_sdk="28"`, `target_sdk="34"`, `include_filter="*.json"`, zero network permissions for 100% offline play).
3. Export via `Project -> Export -> Android APK -> Export Project`. *(Full Android APK export verification is scheduled in Phase 9.)*

---

## Repository Structure

```text
SHADOWBOUND/
├── project.godot                 # Godot 4.x project config (v0.2.0, 12 actions, 8 physics layers)
├── export_presets.cfg.example    # Android 9+ (API 28) offline APK preset template
├── icon.svg                      # Original SHADOWBOUND application icon
├── ASSET_CREDITS.md              # Asset evaluation & complete licensing provenance ledger
├── scenes/                       # Main menu, player, HUD, touch UI, props, Twilight Sanctum level
├── scripts/                      # Autoloads, separate movement controllers, dual camera/zones, world, UI
├── assets/                       # Cairo Arabic/Latin font, 23 CC0 PNGs, deterministic art generator
├── resources/                    # CameraModeProfiles, PlayerProfile, SpriteFrames (17 anims), Fantasy Theme
├── data/                         # Movement/camera JSON config + English & Arabic RTL localization (74 keys)
├── addons/                       # Reserved for Godot 4 editor plugins
├── tests/                        # Godot Phase 1 & 2 headless suites + Python AST/resource/physics validators
├── licenses/                     # Full license texts (SIL OFL 1.1, CC0 1.0)
└── docs/                         # Architecture, asset replacement pipeline, Phase 1 & Phase 2 test reports
```
