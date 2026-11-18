# SHADOWBOUND — Unified Architecture Overview

## 1. Core Architectural Principle: One Player, Two Gameplay Modes

**SHADOWBOUND** avoids duplicating the player system across Side-Scrolling and Top-Down gameplay. Instead, a single `Player` (`CharacterBody2D` in `scenes/player/player.tscn`) owns the shared character data, animation rig, hitbox, and camera, while delegating per-frame locomotion physics to pluggable controller nodes inheriting `MovementControllerBase`:

```text
Player (CharacterBody2D — scripts/player/player_controller.gd)
├── shared PlayerProfile (Resource — resources/player/player_profile.gd)
├── AnimatedSprite2D (14 unified animations in stickman_sprite_frames.tres)
├── CollisionShape2D (adapts upright capsule vs. 3/4 foot collider per mode)
├── SideScrollController (MovementControllerBase — grounded, gravity, jump, double-jump, dodge, slash)
├── TopDownController (MovementControllerBase — floating 8-direction normalized move, dodge, slash)
├── DualModeCamera (Camera2D — mode-specific zoom, lookahead, drag margins, world bounds, trauma shake)
└── SlashHitbox (Area2D — directional strike detection across both modes)
```

### Physics Layer Allocation (`project.godot`)

| Bit / Value | Layer Name | Purpose |
| --- | --- | --- |
| 1 (`1`) | `world_sidescroll` | Side-scrolling platforms, ledges, and level bounds |
| 2 (`2`) | `world_topdown` | Top-down sanctum walls, pillars, and courtyard bounds |
| 3 (`4`) | `player` | Unified Stickman `Player` body |
| 4 (`8`) | `enemies` | Reserved for Phase 3 side-view and top-down enemy AI |
| 5 (`16`) | `interactables` | Shadow Rift portals, training totems, future NPCs/chests |
| 6 (`32`) | `player_hitbox` | Active sword-slash and skill hitboxes |
| 7 (`64`) | `enemy_hitbox` | Reserved for Phase 3 enemy and boss attack hitboxes |

---

## 2. Autoload Services

1. **`LocalizationManager`** (`scripts/autoload/localization_manager.gd`)
   - Loads offline JSON string tables (`data/localization/en.json`, `data/localization/ar.json`).
   - Calls `TranslationServer.set_locale()` and applies `Control.LAYOUT_DIRECTION_RTL` / `LTR` cleanly while keeping mobile thumb controls ergonomically anchored (joystick left, action fan right).
2. **`GameState`** (`scripts/autoload/game_state.gd`)
   - Holds active `GameplayMode` (`SIDE_SCROLL` / `TOP_DOWN`), shared `PlayerProfile`, data-driven `movement_config.json`, pause/resume state, Android lifecycle handlers (`NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_GO_BACK_REQUEST`), and offline settings persistence (`user://settings.cfg`).

---

## 3. Phased Development Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| **Phase 1** | Godot 4 project, main menu, playable anime Stickman, animations, side-scroll movement, top-down prototype, camera switching, playable Twilight Sanctum level, basic touch controls, bilingual EN/AR RTL base, README & credits | **Completed** |
| **Phase 2** | Expanded dual-camera transitions, zone streaming, controller polish (blocking, wall/ledge feel, stamina tuning) | Planned |
| **Phase 3** | Multi-hit sword combos, blocking/dodge i-frames, 3 enemy archetypes (side & top-down AI), 1 multi-phase boss, monster encyclopedia hook | Planned |
| **Phase 4** | Character creation, 5 classes (Warrior, Mage, Assassin, Knight, Summoner), XP/levels, Ranks F–SSS, Gold/Diamonds/Magic Crystals, inventory | Planned |
| **Phase 5** | Equipment slots, rarity tiers, skill trees, loot generation, blacksmith upgrades | Planned |
| **Phase 6** | Towns, shops, NPC dialogue, dungeons, world/zone map, main & side quests | Planned |
| **Phase 7** | Complete offline Guild simulation (HQ, NPC roster, ranks, missions, contribution, storage, shop, reputation) behind a clean service interface ready for optional future online adapters + full save/load persistence | Planned |
| **Phase 8** | Visual VFX polish, audio/SFX/music, full Arabic RTL audit, Android touch customization | Planned |
| **Phase 9** | End-to-end validation, mobile performance profiling, and verified Android 9+ APK export | Planned |
