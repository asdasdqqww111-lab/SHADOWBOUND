# SHADOWBOUND — Asset Research & Credits

This document records the asset source evaluation and the complete licensing/provenance ledger for every asset included in **SHADOWBOUND**. No copyrighted anime characters, trademarks, or unverified assets are used anywhere in the repository.

---

## 1. Open-Source Asset Repository Evaluation

| Source Repository | Reference URL | Candidate Packs Evaluated | License | Evaluation for SHADOWBOUND |
| --- | --- | --- | --- | --- |
| **Kenney.nl** | https://kenney.nl/assets | *Fantasy UI Borders*, *Onscreen Controls*, *Tiny Dungeon*, *Pixel Platformer*, *RPG Audio*, *UI Pack (RPG Expansion)* | CC0 1.0 Public Domain | Excellent license safety and clean readability; great reference and future Phase 8 SFX candidate (*RPG Audio*). Character art is chibi/blocky rather than anime stickman, so original character/UI art was created for visual cohesion. |
| **OpenGameArt.org** | https://opengameart.org | *Animated Stick Figure Character 2D Free CC0* (`opengameart.org/content/animated-stick-figure-character-2d-free-cc0` by `rgsdev`, 512x512 side-scroll base) | CC0 1.0 (pack-specific; repository varies) | Strong side-scroller stickman animations (idle, run, jump, dash, attack combo), but lacks matching top-down 8-direction sheets and is large (27.4 MB). Documented as an optional side-scroll reference; custom unified dual-mode sheets created instead. |
| **itch.io Free Assets** | https://itch.io/game-assets/free | *Animated Stick Figure Character 2D Free CC0* (`rgsdev.itch.io/animated-stick-figure-character-2d-free-cc0` by `RGS_Dev`) and free fantasy tilesets | CC0 1.0 (varies per creator; must verify each pack) | Useful side-scroll vector stickman reference; does not pair side-scrolling and top-down perspectives in one cohesive anime silhouette. |
| **Godot Demo Projects** | https://github.com/godotengine/godot-demo-projects | `2d/platformer`, `2d/role_playing_game`, `gui/bidi_and_font_features`, `gui/ui_mirroring`, `mobile/multitouch_view` | MIT (code) + SIL OFL 1.1 (bundled fonts) | Official Godot 4.x reference patterns adopted for `project.godot`, `locale/include_text_server_data=true` (Arabic BiDi shaping), `gl_compatibility` mobile rendering, and multitouch event handling. |
| **Google Fonts (Cairo)** | https://github.com/google/fonts/tree/main/ofl/cairo | *Cairo Variable Font* (`Cairo[slnt,wght].ttf`) | SIL Open Font License 1.1 | **Selected and bundled.** Crisp contemporary geometric Arabic + Latin typeface supporting full Arabic contextual shaping, RTL UI readability on mobile screens, and clean English HUD typography in a single 586 KB file. |

---

## 2. Bundled & Generated Asset Ledger

### 2.1 Typography

| Field | Record |
| --- | --- |
| **Asset Name** | Cairo Variable Font (`assets/fonts/Cairo-VariableFont.ttf`) |
| **Download URL** | https://github.com/google/fonts/tree/main/ofl/cairo (`Cairo[slnt,wght].ttf`) |
| **Upstream Project** | https://github.com/Gue3bara/Cairo |
| **Author** | Mohamed Gaber and The Cairo Project Authors |
| **License** | SIL Open Font License, Version 1.1 (`licenses/OFL-1.1-Cairo.txt`) |
| **Modifications** | Filename normalized from `Cairo[slnt,wght].ttf` to `Cairo-VariableFont.ttf` for clean Godot/Android resource paths; binary font file unmodified (599,548 bytes). |
| **Attribution Requirements** | Retain copyright notice and `licenses/OFL-1.1-Cairo.txt` in source repository and shipped distributions; do not sell the font file by itself or rename derivative fonts "Cairo". |

### 2.2 Original Anime Fantasy Stickman Sprites (Phase 1–3 Prototype Art)

| Field | Record |
| --- | --- |
| **Asset Names** | `assets/sprites/player/stickman_sidescroll_sheet.png` (1024x1408, 11 animations / 55 frames: `idle`, `run`, `jump`, `fall`, `dodge`, `attack`, `block`, `wall_slide`, `attack_2`, `attack_3`, `hurt`), `assets/sprites/player/stickman_topdown_sheet.png` (768x1536, 12 animations / 57 frames: `td_idle_down`, `td_idle_up`, `td_idle_side`, `td_walk_down`, `td_walk_up`, `td_walk_side`, `td_dodge`, `td_attack`, `td_block`, `td_attack_2`, `td_attack_3`, `td_hurt`), `assets/sprites/player/player_portrait.png` (160x160) |
| **Download URL** | Original in-repository creation (`assets/tools/generate_placeholder_art.py`) |
| **Author** | SHADOWBOUND Development Team |
| **License** | CC0 1.0 Universal (`licenses/CC0-1.0-Shadowbound-Art.txt`) |
| **Modifications** | Original work — Twilight Obsidian stickman with violet aura rim-light, spiky shadow hair crest, cyan anime eyes, flowing crimson scarf, shadow-violet katana, cyan/violet guard ward shield (Phase 2), and wall-slide sparks (Phase 2). |
| **Attribution Requirements** | None required (CC0 1.0). Drop-in artist replacement specs documented in `docs/ASSET_PIPELINE.md`. |

### 2.3 Original Twilight Sanctum Environment & Prop Sprites

| Field | Record |
| --- | --- |
| **Asset Names** | `bg_twilight_sky.png`, `bg_distant_peaks.png`, `bg_ruined_arches.png`, `platform_stone.png`, `oneway_bridge.png` *(Phase 2)*, `topdown_sanctum_floor.png`, `topdown_wall_tile.png`, `topdown_rune_circle.png`, `rift_gate_sheet.png`, `mana_lantern.png`, `training_totem.png`, `lore_runestone.png` *(Phase 2)* (under `assets/sprites/environment/`) |
| **Download URL** | Original in-repository creation (`assets/tools/generate_placeholder_art.py`) |
| **Author** | SHADOWBOUND Development Team |
| **License** | CC0 1.0 Universal (`licenses/CC0-1.0-Shadowbound-Art.txt`) |
| **Modifications** | Original cohesive anime twilight fantasy art palette. |
| **Attribution Requirements** | None required (CC0 1.0). |

### 2.4 Original UI Branding, Icons & Android Touch Controls

| Field | Record |
| --- | --- |
| **Asset Names** | `icon.svg`, `logo_emblem.png`, `joystick_base.png`, `joystick_knob.png`, `btn_attack.png`, `btn_jump.png`, `btn_block.png` *(Phase 2)*, `btn_dodge.png`, `btn_mode.png` (under `assets/sprites/ui/`) |
| **Download URL** | Original in-repository creation (`assets/tools/generate_placeholder_art.py` and `icon.svg`) |
| **Author** | SHADOWBOUND Development Team |
| **License** | CC0 1.0 Universal (`licenses/CC0-1.0-Shadowbound-Art.txt`) |
| **Modifications** | Original fantasy gilded-obsidian + shadow-violet branding and mobile control glyphs. |
| **Attribution Requirements** | None required (CC0 1.0). |


### Phase 3 — Enemy, Boss & Combat Art

All five new PNGs under `assets/sprites/enemies/` are original procedural SHADOWBOUND Development Team work generated by `assets/tools/generate_enemy_art.py`, dedicated under **CC0 1.0 Universal** (`licenses/CC0-1.0-Shadowbound-Art.txt`). No external enemy or boss artwork is bundled.

| Asset | Dimensions | Content |
| --- | --- | --- |
| `umbral_hound_sheet.png` | 512×512 | Umbral Stalker; 128px cells; idle/move/attack/hurt |
| `rift_wisp_sheet.png` | 512×512 | Rift Arcanist; 128px cells; idle/move/attack/hurt |
| `obsidian_sentinel_sheet.png` | 512×512 | Obsidian Sentinel; 128px cells; idle/move/attack/hurt |
| `eclipse_warden_boss_sheet.png` | 640×640 | Vaelor; 160px cells; idle/move/attack/phase_shift |
| `shadow_orb.png` | 64×64 | Reflectable cyan-violet arcane projectile |

Phase 3 also extends both player sheets with reverse cut, finisher and hurt rows. All **28 PNGs** can be regenerated by `python3 assets/tools/generate_placeholder_art.py`. No attribution is required for CC0 art; retain the separate Cairo OFL license when distributing the font.
