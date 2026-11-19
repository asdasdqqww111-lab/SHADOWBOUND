# SHADOWBOUND

**SHADOWBOUND** (*عهد الظلال*) is an offline single-player 2D Anime Fantasy Stickman RPG built with **Godot 4.x stable** and **GDScript**, designed for **Android (9.0 / API 28+)** and desktop testing with full **English (LTR)** and **Arabic (RTL)** support.

> **Current Milestone:** **Phase 5 — Equipment, Classes, Talent Trees & Loot (`v0.5.0`)**

---

## Delivered Features (Phases 1–5)

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
4. **23 Unified Stickman Animations & Expanded Twilight Sanctum**
   - 112 frames across `idle`, `run`, `jump`, `fall`, `dodge`, `attack`, `block`, `wall_slide`, `td_idle_down/up/side`, `td_walk_down/up/side`, `td_dodge`, `td_attack`, `td_block`, `attack_2/3`, `hurt`, `td_attack_2/3`, and `td_hurt`.
   - Upgraded `scenes/levels/twilight_sanctum.tscn` with two pass-through **One-Way Skybridges**, a **Wall-Jump Ruin Tower** leading to the upper overlook, two bilingual **Lore Runestones** in the courtyard wings, and three **Camera Vista Zones**.
5. **Android 9+ Multi-Touch & Bilingual English / Arabic (RTL) UI**
   - Non-overlapping 5-button right-thumb fan (`ATK`, `JUMP/ACT`, hold-capable `GUARD`, `DODGE`, `MODE`) + left-thumb analog `VirtualJoystick`, live HUD movement-state/compass/`[VISTA]` readout, Camera View settings in Main & Pause menus, and 217 paired EN/AR RTL localization keys bundled with the SIL OFL **Cairo** font.

6. **Shared Full Combat System**
   - Buffered **3-hit sword combo**: Shadow Cut → Crescent Reverse → Eclipse Finisher (shield-breaking); 5/9 stamina follow-ups, critical hits, knockback, hurt stun and one hit per target per swing.
   - Directional **Perfect Guard** restores stamina/MP, staggers melee attackers, reflects hostile orbs, and grants a **1.6s Riposte**. Sustained guard takes chip damage and costs stamina; exhausted guard breaks. Dodge i-frames avoid damage.
   - Localized floating damage/crit/parry/shield-break text, slain counter, Riposte badge, defeat and victory banners.
7. **Three Dual-Mode Enemy Archetypes & One Boss**
   - **Umbral Stalker** (`umbral_hound`): fast melee rush with a telegraphed lunge.
   - **Rift Arcanist** (`rift_wisp`): ranged kiting caster; orbs can be reflected or sliced with a finisher/Riposte.
   - **Obsidian Sentinel**: slow armored guardian; directional shield is vulnerable to flanking, parry and finisher.
   - **Vaelor, Warden of the Eclipse**: North Seal boss, **320 HP**, three phases (100% / 65% / 30%), greatsword cleave, dash-strike, three-orb fan and eight-orb nova. Phase changes briefly grant invulnerability.
   - Seven regular foes across cliffs and courtyard, safe courtyard spawn south of boss aggro, auto-revive after defeat, and **Pause → Revive & Reset Enemies**. Reset restores all enemies and boss; mode changes clear projectiles but preserve combat progress.
   - Combat tuning lives in `data/config/combat_config.json`; per-enemy tuning in `resources/combat/*_stats.tres`. Phase 4 now awards these XP/gold values and deterministic materials exactly once per enemy life.

8. **RPG Progression & Inventory (Phase 4)**
   - **Levels 1–60**, overflow/multi-level XP awards, deterministic HP/MP/Stamina/Attack/Defense growth and ranks **F → E → D → C → B → A → S → SS → SSS**. Level-up restores vitals for living players.
   - **Gold, Diamonds and Magic Crystals**, bounded balances and atomic spending API. Regular foes award XP/gold/materials; Vaelor also awards **3 Diamonds, 5 Magic Crystals and an Eclipse Sigil**.
   - **24-slot stackable inventory**, three usable restorative consumables, two materials, five new original icons, selected-item details, and confirmed single-item discard. Full vitals never waste a potion; full bags reject materials without losing XP/currency rewards.
   - Open **Satchel** from HUD/Pause or press **I**. Combat pauses; closing restores the previous pause state. Arabic RTL, item labels/descriptions, wallet and XP displays update live.
   - Versioned **local progression checkpoints** (`user://progression.json`) preserve XP, currencies and item counts across restarts. Atomic temporary-file replacement, one previous backup, file-size/type/range validation and future-schema overwrite protection. This is **not** a full world/quest save; full save remains Phase 7.
   - Starter supplies: 3 Health Potions, 2 Mana Potions, 2 Stamina Draughts. Used items stay used after retries/relaunch; retrying a trial permits earning rewards from revived foes again. Fresh Phase 5 profiles also receive a Rust Blade. No paid currency purchases or town shops yet.


9. **Equipment, Classes & Skills (Phase 5)**
   - **Nine unique equipment pieces** across Weapon / Armor / Charm slots and **Common / Uncommon / Rare / Epic / Legendary** rarities; equipped bonuses modify actual combat stats without compounding. Unequip before discarding.
   - **Satchel forge**: deterministic enhancements **+1 to +5**. Step `N` costs `25N Gold + 2N Shadow Fragments`, plus one Magic Crystal at +4/+5. Every step adds 20% of the item's original stats. Unaffordable transactions spend nothing. This is a menu forge; town/blacksmith NPCs remain Phase 6.
   - **Five freely selectable classes**, each with an active ability: Warrior's shield-breaking cleave, Mage's three-bolt volley, Assassin's collision-aware blink strike, Knight's healing/immunity ward and Summoner's timed attacking spirit. Press **Q** or tap the HUD skill button. MP costs and shared cooldown prevent free class-switch recasts.
   - **Three-node linear talent tree per class** (15 nodes): Focus (+2 ATK), Mastery (+10 MP, ×1.2 skill power), Awakening (+15 HP, ×1.35 skill power). One point per level, globally shared; previous-node/level requirements apply. Learned talents persist on switching, but only the active class contributes bonuses. No respec yet.
   - **Weighted equipment loot**: regular enemies have a 35% gear chance; bosses always roll gear. Full bags explicitly reject new gear while preserving XP/currencies. Owned unique duplicates convert to up to 15 Gold. All nine pieces are obtainable through the two pools.
   - **Satchel → Character & Skills** for classes/talents/equipment summary. **Schema 2 checkpoints** now include class, equipment, enhancements and learned talents; Phase 4 schema 1 checkpoints migrate without duplicating starter supplies. This requires app data to remain installed; uninstalling Android previews deletes it.

---

## Controls

| Action | Android / Touch | Keyboard | Gamepad |
| --- | --- | --- | --- |
| **Move (Side-Scroll / 8-Dir Top-Down)** | Left Virtual Joystick (analog walk/run) | `W A S D` / Arrow Keys | Left Stick / D-Pad |
| **Jump, Double Jump & Wall Jump** *(Side-Scroll)* | `JUMP` | `Space` | A / Cross |
| **Drop Through One-Way Bridge** *(Side-Scroll)* | Joystick Down + `JUMP` | `S`/`Down` + `Space` | Down + A |
| **Sprint** *(Top-Down)* | — *(Full stick runs; keyboard/pad sprint)* | `Ctrl` | L2 / LT |
| **3-Hit Sword Combo** | Chain `ATK` | `J` or `Z` | X / Square |
| **Shadow Guard / Perfect Guard** *(Hold)* | Hold `GUARD` | Hold `C` or `X` | L1 / LB |
| **Shadow Dodge (w/ i-frames)** | `DODGE` | `Shift` or `K` | B / Circle |
| **Interact (Rift Gate / Lore Runestone)** | `ACT` *(when in range)* | `E` or `F` | Y / Triangle |
| **Switch Camera & Gameplay Mode** | `MODE` or HUD Button | `Tab` or `M` | R1 / RB |
| **Class Skill** | HUD skill button | `Q` | HUD button |
| **Satchel / Inventory** | HUD `Satchel` / Pause menu | `I` (Esc closes) | HUD / Pause menu |
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

### 1. Godot Headless Runtime Test Suites (Phases 1–5)
```bash
godot --headless --editor --path . --import --quit
godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase2_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase3_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase4_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase5_runner.tscn
```

### 2. Static AST, Linter, Scene/Resource, Signal & Geometry Suites
```bash
pip install gdtoolkit pillow
python3 tests/validate_project.py
python3 tests/test_gameplay_logic.py
```

---

The Python suites validate static contracts and geometry; they do **not** replace native Godot execution or device playtesting. `.github/workflows/validate.yml` imports assets and runs all five native suites on Godot 4.3. See [Phase 5 verification report](docs/PHASE_5_TEST_REPORT.md) for actual results and remaining checks.

## Download Android Preview — Phase 5

[**Download SHADOWBOUND v0.5.0 APK**](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.5.0-android-preview-9/SHADOWBOUND-v0.5.0-preview.apk) · [Release and checksum](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/tag/v0.5.0-android-preview-9)

Experimental debug-signed build, approximately **160 MB**, for **Android 9+ ARM64/ARMv7** with OpenGL ES 3 support. Includes equipment, smith upgrades, five class skills/talent trees and loot. Allow installation from your browser/file manager if Android asks. No Android permissions are requested; the game runs offline.

**Verified build:** preview **9**, source `473b72f28950cb443401bd2c6423c46d0acc106b`; [APK build and validation](https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44440116517). **880 automated checks pass**, including **320 native Godot checks**. See [Phase 5 report](docs/PHASE_5_TEST_REPORT.md) for checksum, coverage and remaining device tests. Do not use obsolete early preview 5, which predates the save fix.

Phase 4 checkpoints migrate when app data is retained. Disposable test signing keys may require uninstall/reinstall, which **deletes app data**; back up important checkpoints first. This is not a production/store release, and no phone/emulator visual or performance pass is claimed.

## Android APK Export Setup (Android 9.0 / API 28+)

1. Install matching Godot 4 **Export Templates** and configure **Android SDK (API 34)** + **OpenJDK 17** + local debug keystore (never commit `.keystore` files).
2. Copy `export_presets.cfg.example` to `export_presets.cfg` (`min_sdk="28"`, `target_sdk="34"`, `include_filter="*.json"`, zero network permissions for 100% offline play).
3. Choose `Project -> Install Android Build Template`. Keep **Use Gradle Build** enabled: Godot 4.3 requires Gradle to override minimum/target SDK versions.
4. Set your local debug keystore in the preset, then export via `Project -> Export -> Android APK -> Export Project` using debug export. The Phase 5 preview APK is available above; production signing, optimization and device certification remain later work.

---

## Repository Structure

```text
SHADOWBOUND/
├── project.godot                 # Godot 4.x project config (v0.5.0, 14 actions, 8 physics layers)
├── export_presets.cfg.example    # Android 9+ (API 28) offline APK preset template
├── icon.svg                      # Original SHADOWBOUND application icon
├── ASSET_CREDITS.md              # Asset evaluation & complete licensing provenance ledger
├── scenes/                       # Main menu, player, HUD, touch UI, props, Twilight Sanctum level
├── scripts/                      # Autoloads, separate movement controllers, dual camera/zones, world, UI
├── assets/                       # Cairo Arabic/Latin font, 42 CC0 PNGs, deterministic art generator
├── resources/                    # CameraModeProfiles, PlayerProfile, player/enemy SpriteFrames (23 player anims), Fantasy Theme
├── data/                         # Movement/camera/combat/progression/build JSON config + item catalog + English & Arabic RTL localization (217 keys)
├── addons/                       # Reserved for Godot 4 editor plugins
├── tests/                        # Godot Phase 1–5 headless suites + Python AST/resource/physics validators
├── licenses/                     # Full license texts (SIL OFL 1.1, CC0 1.0)
└── docs/                         # Architecture, asset replacement pipeline, Phase 1–5 test reports
```
