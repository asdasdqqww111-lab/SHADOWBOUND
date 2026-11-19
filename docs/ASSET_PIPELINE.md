# SHADOWBOUND — Art Style & Asset Replacement Pipeline

## 1. Visual Identity Specification

**SHADOWBOUND** uses a 100% original dark-twilight anime fantasy stickman palette:

- **Obsidian Core:** `#141024` / `#0E0B1A` (crisp stickman silhouette)
- **Shadow Violet Rim & Magic:** `#9B7EFF` / `#8E60FF` (aura edges, blade energy, rifts)
- **Soul Cyan Accent:** `#60EEFF` (expressive anime eyes, jump rings, slash core, target runes)
- **Crimson Scarf:** `#E43662` / `#981A44` (kinetic secondary-motion cloth readable against dark skies)
- **Royal Sanctum Gold:** `#FFE08A` / `#D69E3E` (katana tsuba, UI borders, ruin inlays, lanterns)

---

## 2. Drop-In Character Sprite Sheet Specifications

Artists can replace the procedural Phase 3 sprite sheets with hand-animated PNGs (exported from Aseprite, Krita, Spine, or Blender Grease Pencil) **without modifying any GDScript or `.tscn` files**, provided the sheet grid and foot anchor match the tables below.

### 2.1 Side-Scrolling Stickman Sheet

- **Path:** `assets/sprites/player/stickman_sidescroll_sheet.png`
- **Image Size:** `1024 x 1408` px (RGBA PNG, transparent background)
- **Grid:** `8 columns x 11 rows`, cell size `128 x 128` px
- **Default Facing:** Right (`+X`); engine mirrors automatically via `flip_h` for Left (`-X`)
- **Foot Ground Anchor:** `x = 64, y = 114` inside each `128 x 128` cell

| Row | Animation Name | Frames | Cell Y | Speed (FPS) | Loop | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | `idle` | 6 (cols 0–5) | `0` | 8.0 | Yes | Breathing stance, fluttering scarf, sheathed blade |
| 1 | `run` | 8 (cols 0–7) | `128` | 13.0 | Yes | Forward-lean anime sprint cycle |
| 2 | `jump` | 4 (cols 0–3) | `256` | 10.0 | No | Launch + rising arc |
| 3 | `fall` | 4 (cols 0–3) | `384` | 9.0 | Yes | Airborne descent, upward scarf trail |
| 4 | `dodge` | 5 (cols 0–4) | `512` | 16.0 | No | Shadow-step dash with ghost afterimage |
| 5 | `attack` | 6 (cols 0–5) | `640` | 16.0 | No | Katana slash; crescent arc active on frames 2–4 |
| 6 | `block` | 4 (cols 0–3) | `768` | 9.0 | Yes | Shadow Guard diagonal katana ward + cyan/violet rune barrier |
| 7 | `wall_slide` | 4 (cols 0–3) | `896` | 10.0 | Yes | Wall brace descend with cyan/gold friction sparks |
| 8 | `attack_2` | 5 (cols 0–4) | `1024` | 18.0 | No | Crescent Reverse |
| 9 | `attack_3` | 6 (cols 0–5) | `1152` | 18.0 | No | Eclipse Finisher |
| 10 | `hurt` | 3 (cols 0–2) | `1280` | 12.0 | No | Stagger recoil |

### 2.2 Top-Down (3/4 RPG) Stickman Sheet

- **Path:** `assets/sprites/player/stickman_topdown_sheet.png`
- **Image Size:** `768 x 1536` px (RGBA PNG, transparent background)
- **Grid:** `6 columns x 12 rows`, cell size `128 x 128` px
- **Foot Shadow Anchor:** `x = 64, y = 104` inside each `128 x 128` cell
- **Side Facing:** Right (`+X`); engine mirrors via `flip_h` for Left (`-X`)

| Row | Animation Name | Frames | Cell Y | Speed (FPS) | Loop |
| --- | --- | --- | --- | --- | --- |
| 0 | `td_idle_down` | 4 (cols 0–3) | `0` | 7.0 | Yes |
| 1 | `td_idle_up` | 4 (cols 0–3) | `128` | 7.0 | Yes |
| 2 | `td_idle_side` | 4 (cols 0–3) | `256` | 7.0 | Yes |
| 3 | `td_walk_down` | 6 (cols 0–5) | `384` | 11.0 | Yes |
| 4 | `td_walk_up` | 6 (cols 0–5) | `512` | 11.0 | Yes |
| 5 | `td_walk_side` | 6 (cols 0–5) | `640` | 11.0 | Yes |
| 6 | `td_dodge` | 5 (cols 0–4) | `768` | 16.0 | No |
| 7 | `td_attack` | 5 (cols 0–4) | `896` | 16.0 | No |
| 8 | `td_block` | 4 (cols 0–3) | `1024` | 9.0 | Yes |
| 9 | `td_attack_2` | 5 (cols 0–4) | `1152` | 18.0 | No |
| 10 | `td_attack_3` | 5 (cols 0–4) | `1280` | 18.0 | No |
| 11 | `td_hurt` | 3 (cols 0–2) | `1408` | 12.0 | No |

---

## 3. Environment & UI Replacement Table

| File Path | Dimensions | Format / Tiling Rule |
| --- | --- | --- |
| `assets/sprites/player/player_portrait.png` | `160 x 160` | RGBA character bust portrait |
| `assets/sprites/environment/bg_twilight_sky.png` | `1280 x 720` | RGBA sky backdrop |
| `assets/sprites/environment/bg_distant_peaks.png` | `1280 x 512` | Horizontally tileable parallax layer |
| `assets/sprites/environment/bg_ruined_arches.png` | `1280 x 512` | Horizontally tileable near parallax layer |
| `assets/sprites/environment/platform_stone.png` | `256 x 64` | Horizontally tileable side-scroll platform |
| `assets/sprites/environment/oneway_bridge.png` | `256 x 32` | Horizontally tileable one-way gilded rune skybridge |
| `assets/sprites/environment/topdown_sanctum_floor.png` | `256 x 256` | Seamlessly tileable (X & Y) courtyard stone |
| `assets/sprites/environment/topdown_wall_tile.png` | `128 x 128` | Tileable 3/4 sanctum wall/pillar block |
| `assets/sprites/environment/topdown_rune_circle.png` | `384 x 384` | Centered RGBA courtyard floor decal |
| `assets/sprites/environment/rift_gate_sheet.png` | `512 x 160` | 4 frames of `128 x 160` portal loop |
| `assets/sprites/environment/mana_lantern.png` | `64 x 128` | RGBA fantasy prop |
| `assets/sprites/environment/training_totem.png` | `96 x 128` | RGBA target dummy prop |
| `assets/sprites/environment/lore_runestone.png` | `80 x 120` | RGBA interactive sanctum lore tablet |
| `assets/sprites/ui/logo_emblem.png` | `256 x 256` | Main menu crest |
| `assets/sprites/ui/joystick_base.png` | `220 x 220` | RGBA virtual joystick ring |
| `assets/sprites/ui/joystick_knob.png` | `96 x 96` | RGBA virtual joystick thumb cap |
| `assets/sprites/ui/btn_attack.png` | `128 x 128` | Primary touch attack button |
| `assets/sprites/ui/btn_jump.png` | `112 x 112` | Touch jump / interact button |
| `assets/sprites/ui/btn_block.png` | `104 x 104` | Hold-capable touch Shadow Guard / block button |
| `assets/sprites/ui/btn_dodge.png` | `112 x 112` | Touch shadow-dodge button |
| `assets/sprites/ui/btn_mode.png` | `112 x 112` | Touch camera/mode switch button |

---

## 4. Regenerating Prototype Art & Licensing Checklist

To deterministically regenerate all placeholder PNGs:

```bash
python3 assets/tools/generate_placeholder_art.py
python3 tests/validate_project.py
```

Whenever replacing or adding any third-party asset:

1. Verify the license permits free commercial redistribution in Android APKs (CC0, MIT, CC-BY 4.0, SIL OFL 1.1).
2. Copy the full license text into `licenses/`.
3. Record Asset Name, URL, Author, License, Modifications, and Attribution in `ASSET_CREDITS.md`.
4. Re-run `python3 tests/validate_project.py` to confirm all `AtlasTexture` bounds fit the updated dimensions.


## Phase 3 — Enemy/Boss Replacement Contract

The three enemy sheets are **512×512**, four rows of four **128×128** cells: `idle`, `move`, `attack` (four frames each) and `hurt` (two frames; unused cells remain transparent). Boss sheet is **640×640**, four rows of four **160×160** cells: `idle`, `move`, `attack`, `phase_shift` (four frames each). All sheets face right and use RGBA transparency; horizontal facing is mirrored in code. Top-down currently shares these stylized silhouettes, not separate directional enemy sheets.

Resources live in `resources/sprites/{umbral_hound,rift_wisp,obsidian_sentinel,eclipse_warden}_frames.tres`. Preserve their animation names and atlas rectangles when replacing PNGs. `shadow_orb.png` is **64×64** with a central pivot. Boss phase tints are applied by code, so preserve neutral original hues.

Run `python3 assets/tools/generate_placeholder_art.py` to regenerate all 28 PNGs, or `python3 assets/tools/generate_enemy_art.py` for only the five new combat PNGs. Regeneration overwrites artist replacements: run it only on a clean worktree or back up custom art. Run both Python suites afterward and reimport in Godot; dimensions and atlas bounds must pass before export.


## Phase 4 — Inventory Asset Contract

The five IDs in `data/items/item_catalog.json` each map to `assets/sprites/items/<item_id>.png`, **64×64 RGBA**, transparent outer corners, violet/obsidian card, gold outline. Potions use red/blue/jade liquids; materials use a violet crystal and gold eclipse medallion. Inventory renders icons at 56px and uses the catalog's color/name/description/stack/effect metadata, not text painted into the images.

Regenerate only icons with `python3 assets/tools/generate_inventory_icons.py`, or all **33 PNGs** with `python3 assets/tools/generate_placeholder_art.py`. Replacing art must preserve IDs/filenames and icon dimensions. Both routes are deterministic and CC0. Text remains localized by Godot/Cairo; do not bake translated labels into icons.


## Phase 5 — Equipment Icons

The catalog now has fourteen IDs: five Phase 4 supplies/materials plus nine unique equipment pieces. All map to **64×64 RGBA** icons at `assets/sprites/items/<id>.png`. Equipment border/fill accents use the catalog's five rarity colors. Filenames and transparent-card dimensions must remain stable; labels, rarity names and stats stay in localized text, not the artwork.

Run `python3 assets/tools/generate_gear_icons.py` for the nine equipment icons, or `python3 assets/tools/generate_placeholder_art.py` for all **42 PNGs**. Both are deterministic. Bolts, spirit and beam are lightweight Godot draw primitives; more elaborate skill VFX/audio remain Phase 8.
