# SHADOWBOUND

**SHADOWBOUND** (*عهد الظلال*) is an offline single-player 2D Anime Fantasy Stickman RPG built with **Godot 4.x stable** and **GDScript**, designed for **Android (9.0 / API 28+)** and desktop testing with full **English (LTR)** and **Arabic (RTL)** support.

> **Current Milestone:** **Phase 1 — Playable Dual-Mode Prototype (`v0.1.0`)**

---

## Phase 1 Delivered Features

1. **Valid Godot 4.x Project (`project.godot`)** — Configured with `GL Compatibility` rendering for broad Android 9+ compatibility, responsive `1280x720` (`canvas_items` + `expand`) landscape scaling, ETC2/ASTC VRAM compression, and embedded Arabic BiDi/HarfBuzz text-server data.
2. **Working Main Menu (`scenes/ui/main_menu.tscn`)** — Original twilight fantasy presentation with animated Stickman hero preview, launch into either Side-Scrolling or Top-Down mode, Controls & Guide dialog, Settings modal (Language, Touch Controls mode, Camera Smoothing), live **English / العربية (RTL)** toggle, and Quit.
3. **Unified Playable Stickman Character (`scenes/player/player.tscn`)** — Original Twilight Obsidian anime stickman with violet aura rim, glowing cyan eyes, flowing crimson scarf, shadow katana, shared `PlayerProfile` (`Kael / كايل`, Rank F, Lv.1), and modular controller architecture.
4. **14 Character Animations (`resources/sprites/stickman_sprite_frames.tres`)** — 73 frames across side-scrolling (`idle`, `run`, `jump`, `fall`, `dodge`, `attack`) and top-down (`td_idle_down`, `td_idle_up`, `td_idle_side`, `td_walk_down`, `td_walk_up`, `td_walk_side`, `td_dodge`, `td_attack`).
5. **Side-Scrolling Movement (`scripts/player/side_scroll_controller.gd`)** — Responsive acceleration/friction, asymmetric jump/fall gravity, coyote time, jump buffering, variable jump height, airborne double jump, stamina-based shadow dodge, and sword slash with forward lunge.
6. **Top-Down Movement Prototype (`scripts/player/top_down_controller.gd`)** — Smooth normalized 8-direction movement (analog joystick and digital keys), directional animation switching, 8-way shadow dash, and directional sword slash.
7. **Seamless Camera & Mode Switching (`scripts/camera/dual_mode_camera.gd`)** — Switch anytime via the `MODE` touch button, HUD button, `Tab`/`M`, Pause Menu, or in-world **Shadow Rift Gates** while preserving the same `Player` and `PlayerProfile` state (HP, MP, Stamina, slash combo count, and saved position per zone).
8. **Playable Fantasy Environment (`scenes/levels/twilight_sanctum.tscn`)** — *Twilight Sanctum* featuring both the **Twilight Cliffside Ruins** (3-layer parallax eclipse sky/peaks/arches, multi-tier rune stone platforms, double-jump overlook, mana lanterns, training totems, two Shadow Rift Gates) and the **Twilight Sanctum Courtyard** (walled stone plaza, glowing central rune circle, pillars, lanterns, training totems, return Shadow Rift Gate).
9. **Multi-Touch Android Controls (`scenes/ui/touch_controls.tscn`)** — Left-thumb analog `VirtualJoystick` + right-thumb action arc (`ATK`, `JUMP/RIFT`, `DODGE`, `MODE`) tracking independent finger touch indices, plus Fantasy HUD and Android Back/Pause handling.
10. **Documentation, Credits & Automated Tests** — `ASSET_CREDITS.md`, `licenses/`, `docs/ARCHITECTURE.md`, `docs/ASSET_PIPELINE.md`, `docs/PHASE_1_TEST_REPORT.md`, `tests/validate_project.py`, and `tests/gdscript/test_phase1_headless.gd`.

---

## Controls

| Action | Android / Touch | Keyboard | Gamepad |
| --- | --- | --- | --- |
| **Move (Side-Scroll / 8-Dir Top-Down)** | Left Virtual Joystick | `W A S D` / Arrow Keys | Left Stick / D-Pad |
| **Jump & Double Jump** *(Side-Scroll)* | `JUMP` | `Space` | A / Cross |
| **Sword Slash** | `ATK` | `J` or `Z` | X / Square |
| **Shadow Dodge** | `DODGE` | `Shift` or `K` | B / Circle |
| **Interact / Enter Shadow Rift** | `RIFT` *(near gate)* | `E` or `F` | Y / Triangle |
| **Switch Camera & Mode** | `MODE` or HUD Button | `Tab` or `M` | R1 / RB |
| **Pause / Resume** | HUD `Pause` / Android Back | `Esc` or `P` | Start |

> **Desktop Touch Testing:** `emulate_touch_from_mouse=true` is enabled, so you can click and drag the virtual joystick and tap on-screen buttons directly with a mouse, or toggle Touch Controls between `Always On`, `Auto`, and `Hidden` in **Settings**.

---

## How to Run (Godot 4.x Stable)

### Prerequisites
- **Godot Engine 4.3 stable or newer** (standard GDScript edition — no .NET/Mono required).

### Open & Play in the Godot Editor
1. Clone this repository:
   ```bash
   git clone https://github.com/asdasdqqww111-lab/SHADOWBOUND.git
   cd SHADOWBOUND
   ```
2. Launch **Godot 4.x**, click **Import**, select `project.godot`, and click **Import & Edit** (Godot automatically generates its `.godot/` import cache on first open).
3. Press **F5** (Run Project) to launch into the **SHADOWBOUND** Main Menu.

### Run Directly from Command Line
```bash
godot --path .
```

---

## Running Tests & Validation

### 1. Godot Headless Runtime Test Suite
When the `godot` 4.x CLI binary is installed:
```bash
godot --headless --path . --import
godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
```

### 2. Static, GDScript AST, Scene, Resource & Localization Validator
```bash
pip install gdtoolkit pillow
python3 tests/validate_project.py
```

---

## Android APK Export Setup (Android 9.0 / API 28+)

1. In Godot 4, install the matching **Export Templates** (`Editor -> Manage Export Templates`).
2. Configure **Android SDK** (Platform 34, Build-Tools) and **OpenJDK 17** in `Editor -> Editor Settings -> Export -> Android`, plus a local debug keystore (never commit `.keystore` files to Git).
3. Copy the provided template:
   ```bash
   cp export_presets.cfg.example export_presets.cfg
   ```
   *(Note: `include_filter="*.json"` is pre-configured so localization and movement JSON files are packaged into the APK, and all network permissions are disabled for pure offline operation.)*
4. Export via `Project -> Export -> Android APK -> Export Project`, or test directly on a USB-connected Android 9+ device using Godot's **Remote Deploy** button.

---

## Repository Structure

```text
SHADOWBOUND/
├── project.godot                 # Godot 4.x project configuration
├── export_presets.cfg.example    # Android 9+ (API 28) offline APK preset template
├── icon.svg                      # Original SHADOWBOUND application icon
├── ASSET_CREDITS.md              # Asset research & licensing provenance ledger
├── scenes/                       # Main menu, player, HUD, touch UI, props, Twilight Sanctum level
├── scripts/                      # Autoloads, modular movement controllers, dual camera, world, UI
├── assets/                       # Cairo Arabic/Latin font, sprites, environment art, art generator
├── resources/                    # Fantasy UI Theme, Stickman SpriteFrames, PlayerProfile resource
├── data/                         # Movement physics JSON + English & Arabic RTL string tables
├── addons/                       # Reserved for Godot 4 editor plugins
├── tests/                        # Godot headless test script + Python validation suite
├── licenses/                     # Full license texts (SIL OFL 1.1, CC0 1.0)
└── docs/                         # Architecture, asset replacement pipeline, and phase test reports
```
