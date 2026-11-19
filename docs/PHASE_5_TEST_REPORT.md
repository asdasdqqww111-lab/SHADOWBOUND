# SHADOWBOUND — Phase 5 Verification Report (`v0.5.0`)

## ملخص التنفيذ

تم تنفيذ المعدات والندرات الخمس، وتعزيز الحدّاد حتى +5، والفئات الخمس بمهارات قتالية فعلية، وشجرة متسلسلة من ثلاث مواهب لكل فئة، وغنائم المعدات الموزونة. واجهة الحقيبة تتضمن تبويب الشخصية والمواهب، وتدعم العربية واتجاه RTL. يمتد الحفظ إلى الفئة والمعدات والتعزيزات والمواهب، مع ترحيل ملفات المرحلة الرابعة دون فقد الخبرة والعملات والعناصر.

نجح **880 فحصًا**: 490 فحصًا ساكنًا، و70 فحص بايثون لحسابات اللعب، و320 اختبارًا فعليًا على Godot 4.3، منها 96 للمرحلة الخامسة. هذه ليست شهادة اختبار بصري أو أداء على هاتف فعلي. المدن والمتاجر والشخصيات والمهام وحفظ العالم الكامل ليست ضمن هذه المرحلة.

## Delivered Scope

- **Nine unique gear pieces**, kept in the 24-slot inventory: five weapons, two armors and two charms. One active piece per slot; Common, Uncommon, Rare, Epic and Legendary rarity colors/names. Bonuses feed actual combat stats. Replacing/toggling gear removes the old bonus; recalculation cannot compound stats or resurrect a fallen profile.
- **Satchel forge**, not a town NPC: deterministic +1…+5 enhancement. Step N costs **25N Gold + 2N Shadow Fragments**, with **one Magic Crystal at +4 and +5**. A complete chain costs 375 Gold / 30 Fragments / 2 Crystals. Each step adds 20% of the item's original stats. Missing any resource leaves all resources unchanged.
- **Five selectable classes**, one skill per class, shared across both movement modes. Class changes preserve learned talents and do not refill vitals or reset the active cooldown.
- **Fifteen talent nodes**: each class has sequential Focus → Mastery → Awakening. One globally shared point per level, including level 1. Level gates 1 / 3 / 8; costs 1 / 1 / 2. Focus grants +2 ATK; Mastery +10 MP and ×1.2 skill power; Awakening +15 HP and ×1.35 skill power. Only the active class's learned nodes contribute. No branching/respec system is claimed.
- **Weighted gear loot**: 35% regular-enemy drop chance and guaranteed boss gear roll, in addition to Phase 4 XP/currency/material rewards. All nine pieces are obtainable. Unique duplicates award up to 15 Gold, bounded by wallet headroom. A full bag explicitly rejects new gear without losing XP/currency.
- **Inventory + Character tabs**, live final stats/remaining points, class descriptions and selectors, talent buttons, equipped-slot unequip buttons, rarity-colored item list, gear stats and exact forge cost. Equip/Unequip and Forge mutate the real profile. Equipped discard is blocked; confirmed discard of an unequipped enhanced piece also removes its enhancement.
- **Schema 2 progression checkpoint** adds `class_id` and `build`. Schema 1 loads with Warrior and an empty build, retaining XP/wallet/items. The next checkpoint writes schema 2. Fresh profiles get a Rust Blade alongside the original potions; loading old saves does not re-grant starters.
- Nine new deterministic original CC0 gear icons; **42 PNGs total**, **217 paired EN/AR localization keys**, **44 GDScript files** including native tests. No third-party equipment art or new external asset dependency.

## Class Skills

Use **Q** or the localized HUD skill button. The same cooldown follows class/mode changes. Pause, death, hurt stun, insufficient MP and active cooldown reject casts without payment. MP is paid once per accepted cast.

| Class | Base modifiers | Skill | MP / cooldown |
| --- | --- | --- | --- |
| Warrior | None | Eclipse Cleave: wide forward shield-breaking strike | 15 / 6s |
| Mage | +30 MP, −2 ATK | Arcane Volley: three friendly bolts, world ray sweeps and enemy-hurtbox collision | 22 / 7s |
| Assassin | +8% crit, −10 HP | Shadow Blink: collision-aware 80px dash, heavy strike and brief immunity | 18 / 6s |
| Knight | +3 DEF, +20 HP, −2 ATK | Aegis Ward: heal, stamina restoration, short immunity and shield bash | 20 / 9s |
| Summoner | +20 MP, −1 ATK | One following Spirit Companion, attacks same-mode targets in line of sight for 6s | 25 / 10s |

Mastery/Awakening multiply damage; they also scale Knight healing/ward duration and spirit lifetime. Projectiles/spirits clear on mode transition, trial reset and victory. They are temporary session state, not checkpointed. Skill visuals use lightweight draw primitives and existing combat feedback, not finished Phase 8 effects/audio.

## Executed Checks

| Check | Result |
| --- | --- |
| `python3 tests/validate_project.py` | **490 passed, 0 failed** |
| `python3 tests/test_gameplay_logic.py` | **70 passed, 0 failed** |
| gdtoolkit parsing/lint | **44 scripts**, no problems |
| Godot Phase 1 native | **46 passed, 0 failed** |
| Godot Phase 2 native | **45 passed, 0 failed** |
| Godot Phase 3 native | **56 passed, 0 failed** |
| Godot Phase 4 native | **77 passed, 0 failed** |
| Godot Phase 5 native | **96 passed, 0 failed** |
| Godot import/runtime log scan | No script errors, engine errors or warnings in the successful native run |
| Full deterministic art regeneration | All 42 PNGs regenerated without Git differences |
| `git diff --check` | Clean |

Native validation: [GitHub Actions run 44438704707](https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44438704707), gameplay source **367dd89a96570972b0896cba9fcbca067fb45783**. Subsequent changes to the APK retry workflow do not change gameplay source.

### Phase 5 Native Coverage

- Unique item/bulk rejection; ownership/equipment-slot validation; replace/unequip behavior; multiple slots; derived stat idempotence; no equipment/class resurrection; protected equipped discard and cleanup of discarded enhancements.
- Insufficient fragments, gold and crystals; no partial charges; invalid upgrade targets; each +1…+5 cost; total chain cost; immediate actual attack changes; +5 cap and original-item-only scaling.
- Unknown/inactive class nodes; level/prerequisite checks; repeat-unlock idempotence; global point budget across five classes; retained inactive talents with no inactive bonus; skill-power multipliers; no MP refill on class switching.
- Exact 35% cutoff; weighted pool boundaries; boss guarantee; duplicate compensation and wallet cap; explicit full bag failure; real enemy reward integration without replacing Phase 4 rewards.
- Schema 2 round-trip; automatic checkpoint from armory mutation; schema 1 migration and next-write upgrade; unknown class/gear/slot/talent sanitization; enhancement range; malformed optional containers; future schema overwrite protection, including large numeric versions.
- Actual level/player/enemy instances: Warrior damage and MP/cooldown, Mage's three bolts and hurtbox hits/one-hit gate/mode isolation, Assassin collision-body movement/immunity, Knight healing/immunity/payment, Summoner creation/attack/expiry/class cleanup.
- Cooldown decay/class-switch protection; no-mana/pause/stun/death rejection; actual character/inventory tabs and five selectors; effective inherited Arabic RTL and translated tab title; actual Equip/Forge button handlers.

### Issues Found and Resolved During Verification

1. Godot JSON parses numeric versions as floats; typed Array membership rejected otherwise valid saves. Save versions now pass strict numeric normalization before range validation. Schema 1 migration and schema 2 round-trips pass natively.
2. The RTL test initially inspected the inherited enum rather than effective direction. It now checks `is_layout_rtl()` and the translated character-tab title.
3. Skill rejection originally checked only the controller's defeat flag. It now also checks canonical profile HP, preventing abilities from reviving a zero-HP profile before the controller updates.
4. Freshly changed classes synchronize the skill component before casting, so its next physics tick cannot remove a newly created summon as stale class state.
5. APK publication now requires all five native suites to pass, then successful export/signature/manifest/resource validation. Failed exports never publish a partial artifact.

## Verified Android Preview

[**Download SHADOWBOUND v0.5.0 APK**](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.5.0-android-preview-9/SHADOWBOUND-v0.5.0-preview.apk) · [Release](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/tag/v0.5.0-android-preview-9) · [Checksum file](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.5.0-android-preview-9/SHADOWBOUND-v0.5.0-preview.apk.sha256)

| Field | Verified value |
| --- | --- |
| Build | [44440116517](https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44440116517), **success**, preview **9** |
| Source | `473b72f28950cb443401bd2c6423c46d0acc106b` |
| APK size | **159,769,210 bytes** (approximately 160 MB) |
| SHA-256 | `c4a7163b2062ed0f167664440add8c71160ed1988040cd7c3e30203cd2ebf09e` |
| Package/version | `com.shadowbound.rpg` / `0.5.0-preview` / version code **5** |
| SDK | minimum **28** (Android 9), target/compile **34** |
| Architectures | **arm64-v8a + armeabi-v7a** |
| Signature | **APK Signature Scheme v2 verified**, disposable local-only debug key |
| Permissions | **Zero requested Android permissions**, offline |
| Packaged resources | Project binary, combat/progression/build JSON configs, item catalog, Arabic localization and both ARM engines verified |
| Native gate | All five suites passed **46 / 45 / 56 / 77 / 96** before export/publication |

The initial v0.5.0 preview 5 was produced before native save validation completed and is **obsolete**; its release is explicitly marked with a save issue. Use preview **9**, not preview 5, to test Phase 5 and schema-1 migration.

The first corrected export was blocked by external Gradle/Maven dependency resolution. The workflow now tries Google's public Maven Central mirror before the canonical endpoint, bounds export attempts and retries failures without publishing partial files. The final build above successfully exported and passed signature/manifest/ZIP/resource checks. Standalone validation on the same source also passed: [44440116422](https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44440116422). No Android phone/emulator visual or performance pass is implied.

## Remaining Device / Visual Checks

- Install the final APK on Android 9+ ARM hardware with OpenGL ES 3; test launch, suspend/resume, Android Back and actual installation/update behavior.
- In both modes, test joystick movement while tapping each skill, actual bolt/world collision, Assassin wall blocking, Knight ward timing and companion line-of-sight/cleanup.
- Check English/Arabic layout at different aspect ratios and text scales, especially gear-detail wrapping, character-tab scrolling, forge cost, talent feedback and skill-button placement.
- Exercise real Phase 4 → Phase 5 checkpoint migration with retained app data. Disposable debug keys may prevent an in-place update; uninstalling deletes app data. Back up important checkpoints first. File-format migration cannot preserve data removed by Android uninstall.
- Profile low-end mobile frame rate, memory, heat and draw calls. No phone/emulator performance or visual pass is claimed.

## Boundaries

This is still the dual-mode Twilight Sanctum prototype. Towns, NPC blacksmith/shops, dialogue, quests, dungeons/maps and encyclopedia belong to Phase 6. Full world/guild save is Phase 7. Finished VFX/audio and deeper Arabic polish are Phase 8; comprehensive device/performance certification is Phase 9. No store-ready, production-signing or anti-cheat claim is made.
