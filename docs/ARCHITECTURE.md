# SHADOWBOUND — Unified Architecture Overview

## 1. Core Architectural Principle: One Player, Two Dedicated Mode Systems

**SHADOWBOUND** unifies Side-Scrolling action platforming and Top-Down 2D RPG exploration inside a single player entity (`PlayerCharacter` in `scenes/player/player.tscn`). All RPG data, stamina/health/mana pools, animation frames, combat hitbox, and visual feedback live on `Player`, while per-frame locomotion physics and camera behavior are cleanly separated into dedicated, data-driven controllers and `CameraModeProfile` resources:

```text
Player (CharacterBody2D — scripts/player/player_controller.gd)
├── shared PlayerProfile (Resource — resources/player/player_profile.gd)
├── AnimatedSprite2D (23 unified animations / 112 frames in stickman_sprite_frames.tres)
├── CollisionShape2D (switches upright capsule [mask 129] vs. 3/4 foot collider [mask 2])
├── SideScrollController (MovementControllerBase — platform physics, jump/double-jump,
│                         apex hang, wall slide & wall jump, one-way drop-through,
│                         ground/air dodge w/ i-frames, Shadow Guard w/ perfect-parry, slash)
├── TopDownController    (MovementControllerBase — true 8-direction [E..NE] unit-normalized
│                         analog walk / run / stamina sprint, 8-way dodge w/ i-frames,
│                         pivotable directional Shadow Guard w/ perfect-parry, 8-way slash)
├── DualModeCamera       (Camera2D — loads side_scroll_camera_profile.tres &
│                         top_down_camera_profile.tres, fall-peek, 8-way lookahead,
│                         dynamic sprint/guard zoom, Standard/Wide presets, trauma shake,
│                         and priority-stacked CameraZoneTrigger vista / POI framing)
└── SlashHitbox          (Area2D — directional strike detection shared across both modes)
```

---

## 2. Phase 2 Dual-Mode Camera Architecture

| Component | Path | Responsibility |
| --- | --- | --- |
| `CameraModeProfile` | `resources/camera/camera_mode_profile.gd` | Typed Godot `Resource` defining base zoom, framing offset, directional lookahead, follow smoothing, horizontal/vertical drag deadzones, fast-fall peek, and sprint/guard dynamic zoom. |
| Side-Scroll Profile | `resources/camera/side_scroll_camera_profile.tres` | Elevated horizon (`offset.y = -44`), strong horizontal lookahead (`84 px`), locked X-follow with vertical platform drag deadzone, and downward fall-peek (`+62 px`) for safe landings. |
| Top-Down Profile | `resources/camera/top_down_camera_profile.tres` | Balanced 3/4 overhead zoom (`1.12x`), symmetric 2D deadzone, omni-directional 8-way velocity/facing lookahead (`44, 34 px`), sprint zoom-out (`0.96x`), and guard focus zoom (`1.04x`). |
| `CameraZoneTrigger` | `scripts/camera/camera_zone_trigger.gd` | Priority-stacked `Area2D` world trigger applying panoramic vista zoom, offset shifts, and smooth POI focal pull (e.g., Cliff Overlook, East Rift, North Sanctum Altar). Automatically cleared on mode switch. |

---

## 3. Physics Layer Allocation (`project.godot`)

| Bit / Value | Layer Name | Purpose |
| --- | --- | --- |
| 1 (`1`) | `world_sidescroll` | Solid side-scrolling platforms, wall-jump towers, and bounds |
| 2 (`2`) | `world_topdown` | Top-down sanctum walls, pillars, and courtyard bounds |
| 3 (`4`) | `player` | Unified Stickman `Player` body |
| 4 (`8`) | `enemies` | Side-view and top-down enemy bodies |
| 5 (`16`) | `interactables` | Shadow Rift gates, Lore Runestones, Training Totems, enemy hurtboxes |
| 6 (`32`) | `player_hitbox` | Active sword-slash and skill hitboxes |
| 7 (`64`) | `enemy_hitbox` | Hostile shadow-orb projectiles |
| 8 (`128`) | `world_oneway` | Pass-through side-scroll skybridges (player temporarily drops bit 8 on `Down+Jump`) |

---

## 4. Autoload Services

1. **`LocalizationManager`** (`scripts/autoload/localization_manager.gd`)
   - Loads offline JSON string tables (`data/localization/en.json`, `data/localization/ar.json` — 74 paired keys).
   - Calls `TranslationServer.set_locale()` and applies `Control.LAYOUT_DIRECTION_RTL` / `LTR` cleanly while keeping mobile thumb controls ergonomically anchored (joystick left, 5-button action fan right).
2. **`GameState`** (`scripts/autoload/game_state.gd`)
   - Holds active `GameplayMode` (`SIDE_SCROLL` / `TOP_DOWN`), shared `PlayerProfile`, data-driven `movement_config.json`, `CameraZoomPreset` (`STANDARD` / `WIDE`), touch visibility & camera smoothing settings, Android lifecycle handlers (`NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_GO_BACK_REQUEST`), and offline settings persistence (`user://settings.cfg`).

---

## 5. Phased Development Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| **Phase 1** | Godot 4 project, main menu, playable anime Stickman, basic dual movement, camera switching, playable Twilight Sanctum, touch controls, bilingual EN/AR RTL, README & credits | **Completed** |
| **Phase 2** | Dedicated data-driven Side-Scroll & Top-Down cameras (profiles, fall-peek, 8-way lookahead, vista/POI zones, Standard/Wide zoom) + separate full movement controllers (wall slide/jump, one-way drop-through, apex hang, 8-compass walk/run/sprint, dodge i-frames, Shadow Guard + perfect-parry window, Lore Runestones, 5-button touch fan) | **Completed** |
| **Phase 3** | Multi-hit sword combos, damage/parry/i-frame combat resolution, 3 enemy archetypes, 1 multi-phase boss | **Completed** |
| **Phase 4** | XP, levels, Ranks (F–SSS), currencies (Gold, Diamonds, Magic Crystals), inventory | **Completed** |
| **Phase 5** | Equipment/rarity/blacksmith upgrades, 5 classes (Warrior, Mage, Assassin, Knight, Summoner), skill trees, loot | Planned |
| **Phase 6** | Towns, shops, NPC dialogue, dungeons, world/zone maps, main & side quests, monster encyclopedia | Planned |
| **Phase 7** | Complete offline Guild simulation (HQ, NPC roster, ranks, missions, contribution, storage, shop, reputation, progression; extensible for future online) + full local save/load | Planned |
| **Phase 8** | Visual VFX polish, audio/SFX/music, full Arabic RTL polish, Android touch customization | Planned |
| **Phase 9** | End-to-end validation, mobile performance profiling, and verified Android 9+ APK export | Planned |


## Phase 3 — Combat Architecture

- `CombatResolver` is a stateless `RefCounted` utility: combo specs, critical/Riposte multipliers, armor/shield mitigation and directional incoming-hit outcomes. A supplied critical roll makes tests deterministic.
- `MovementControllerBase` owns shared combo timers, late-input buffer, chain expiry, finisher recovery, swing IDs and hurt stun. Each mode maps those states to movement/animation without duplicating combat arithmetic.
- `PlayerCharacter` owns the directional `SlashHitbox` (mask **88**), clears a per-target registry for each new swing and on controller changes, receives melee/projectile attack dictionaries, applies profile updates and publishes combat/Riposte/defeat signals.
- `EnemyBase` owns stats, common patrol/chase/telegraph/attack/stagger states, front shield, gravity vs floating motion, non-destructive defeat and `reset_enemy()`. Derived Stalker/Arcanist/Sentinel classes supply lunge/kiting/armored behavior. Hurtboxes are monitorable layer **16**, mask **0**, group `enemy_hurtbox`.
- `ShadowOrbProjectile`: hostile layer **64**, world/player mask; parried orbs become layer **32**, world/hurtbox mask with speed/damage bonuses. Lifetimes are finite. Combo finishers and ready Ripostes can slice hostile orbs.
- `EclipseWardenBoss` extends the same enemy contract. Phase transitions at **65% / 30%** HP enter `PHASE_SHIFT` with temporary invulnerability. Phases add dash strikes, fan volleys and radial nova. Boss signals drive a localized top-center health/phase panel.
- `TwilightSanctumLevel` connects combat signals, disables the inactive zone's processing, clears projectiles on mode change/reset/victory, automatically revives after **1.5s**, and resets all eight enemies through the Pause action. Enemy HP and boss phase persist across mode switches; reset restores them. Session kill/parry counters are cumulative until a new session, not reset by a retry.
- `EnemyStats.xp_reward`/`gold_reward` are reserved data for later progression. No XP, loot, persistent encyclopedia UI, audio or APK export is claimed by Phase 3.

### Tests

`tests/validate_project.py` checks AST/lint/resource and inherited scene contracts; `tests/test_gameplay_logic.py` checks geometry/config contracts. Neither executes GDScript. `test_phase3_runner.tscn` exercises the actual resolver, combo buffer/recovery, hit registry, enemy defeat, projectile parry/reflection, boss phase immunity/nova/victory, revive/reset and Arabic HUD. CI installs Godot 4.3 to execute all native suites and rejects engine errors/warnings in their logs.


## Phase 4 — Progression & Inventory Architecture

| Component | Responsibility |
| --- | --- |
| `ProgressionRules` | Pure cumulative-XP → level/rank math, rank boundaries, level cap and strict safe-integer decoding. |
| `PlayerProfile.apply_progression` | Derives level/rank and growth stats from canonical XP without compounding; living level-ups refill vitals. |
| `CurrencyWallet` | Gold/Diamonds/Magic Crystals; bounded credits, copied serialization, prevalidated all-or-nothing spending. |
| `InventoryState` | 24 slots with per-item stack limits; atomic adds, checked removes, deterministic catalog-order sanitized loading. |
| `ProgressionManager` | Loads JSON config/catalog; starter supplies; enemy/boss reward transactions; consumables/discard; progression-only save/load. Emits `changed`, `rewards_granted`, `save_failed`. |
| `GameState.progression` | One service shared by both modes; binds change notifications and initializes one shared profile from its checkpoint. |
| `InventoryPanel` | Always-processing, RTL-aware paused modal, item list/details/icons, Use, confirmed Discard, feedback and previous-pause restoration. |
| `GameHUD` | XP bar, wallet, current level/rank and independent reward/level-up readout beside existing combat/boss feedback. |

### Level and Reward Rules

XP needed from level `L` to `L+1` is `100 + 40 × (L−1)`; cap **60** costs **74,340 total XP**. Rank levels: F 1, E 5, D 10, C 15, B 20, A 30, S 40, SS 50, SSS 60. Each level adds +12 HP, +6 MP, +2 Stamina, +2 Attack and +0.5 Defense; base stats are recalculated, never multiplied on each reload.

`EnemyBase._handle_defeat()`'s existing idempotence gate now calls the progression service exactly once per enemy life. Stats resources supply XP/gold; fixed material grants are not the randomized equipment loot system planned for Phase 5. Boss bonus is 3 Diamonds/5 Magic Crystals/1 Sigil. Caps saturate rewards at available headroom; full bags reject the material atomically and report it, while XP/currency still arrive. Trial resets intentionally respawn reward-eligible foes; they do not reset inventory, XP or wallets.

### Checkpoint Contract / Boundaries

`user://progression.json`, schema **1**, contains only `version`, `total_xp`, `wallet` and `inventory`. It does **not** serialize current HP/MP/Stamina, mode positions, enemy lives, session counters, quests or guilds. Re-entry restores vitals as before; a future full save remains Phase 7.

Writes flush a same-directory `.tmp` and rename it over the primary. One validated previous document is retained as `.bak`. Load checks the 64 KiB limit, containers, numeric XP range and version before applying anything. Balances and item counts are sanitized against finite limits; unknown items are ignored. Corrupt primary may recover the previous backup; when neither is usable, a fresh profile gets starter supplies. Unsupported newer primary schemas are not overwritten. I/O failures leave in-memory progression intact and are signaled to the inventory UI. No encryption/anti-cheat is claimed for this offline checkpoint.

`GameState.set_inventory_open` owns pause restoration so opening from gameplay resumes gameplay, while opening from Pause returns to Pause. Android Back delegates to the same close path. Touch movement is released through existing pause signals. Use rejects fallen players, materials, empty stacks and already-full vitals; Discard requires confirmation and removes one unit.
