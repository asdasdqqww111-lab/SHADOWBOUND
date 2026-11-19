# SHADOWBOUND — Phase 4 Verification Report (`v0.4.0`)

## ملخص التنفيذ

اكتملت أنظمة الخبرة والمستويات حتى 60، والرتب التسع من F إلى SSS، والذهب والألماس والبلورات السحرية، وحقيبة من 24 خانة. تمنح هزيمة الأعداء مكافآت فعلية، ويمكن استخدام الجرعات والتخلص من عنصر بعد التأكيد. الحقيبة تدعم العربية وتوقف القتال مؤقتًا. يُحفظ تقدم الخبرة والعملات والعناصر محليًا مع نسخة احتياطية؛ لا يشمل ذلك حفظ العالم الكامل المخطط للمرحلة السابعة.

نجح **678 فحصًا**: 454 فحصًا ساكنًا/بايثون و224 اختبارًا فعليًا على Godot 4.3، منها 77 اختبارًا جديدًا للمرحلة الرابعة. بُنيت نسخة APK موقعة ومتحقق منها للمرحلة الرابعة، ولم يُدّعَ اختبارها بصريًا على هاتف فعلي.

## Delivered Scope

- Canonical cumulative XP, **levels 1–60**, XP overflow and multiple level-ups per award, safe level cap and derived stat growth without reload compounding.
- Ranks **F/E/D/C/B/A/S/SS/SSS** at levels **1/5/10/15/20/30/40/50/60**.
- Gold, Diamonds, Magic Crystals; bounded credits and atomic validated multi-currency spending API. No purchases or shops yet.
- Seven regular foes award resource-defined XP/gold and one Shadow Fragment. Vaelor also awards **3 Diamonds, 5 Magic Crystals, 1 Eclipse Sigil**. Exactly once per enemy life; trial retries intentionally permit earning rewards again.
- 24-slot stackable inventory; three consumables (50 HP, 35 MP, 40 Stamina), two materials, five new deterministic CC0 icons. Full-vital and fallen-state use rejects safely; full bag rejects material without losing XP/currency. Confirmed single-item discard frees space.
- HUD XP/wallet/reward/level-up readouts, selected-item detail panel, HUD/Pause/I-key access, touch-sized controls, Arabic RTL and **140 paired EN/AR keys**.
- Progression-only schema-1 checkpoint in `user://progression.json`, temporary-file replacement and previous-save backup, 64 KiB size bound, type/range/catalog validation, future-schema overwrite protection and surfaced I/O failures. XP/wallet/items persist; world positions, enemies, vitals, quests and guilds do not.

## Executed Checks

| Check | Result |
| --- | --- |
| `python3 tests/validate_project.py` | **384 passed, 0 failed** |
| `python3 tests/test_gameplay_logic.py` | **70 passed, 0 failed** |
| gdtoolkit `gdparse` / `gdlint` | **36 scripts**, no problems |
| Godot 4.3 asset import / native compilation | Clean, no engine errors/warnings |
| Native Phase 1 regression | **46 passed, 0 failed** |
| Native Phase 2 regression | **45 passed, 0 failed** |
| Native Phase 3 regression | **56 passed, 0 failed** |
| Native Phase 4 progression integration | **77 passed, 0 failed** |
| Art regeneration / SHA-256 comparison | All **33 PNGs** byte-identical |
| `git diff --check` | Clean |

**454 static checks + 224 native assertions = 678 passing checks.** Static checks are not substituted for native execution. Godot ran on GitHub Actions (not locally; sandbox release-binary downloads are host-restricted).

Native/static verified commit: `20535001eaa9c78e06eb78b5ec20104ee1a8c062`.
Successful CI: https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44426513999

### Native Phase 4 Coverage

XP exact/off-by-one thresholds; every rank boundary; multi-level awards; stat growth/refill/cap/idempotence; wallet invalid amounts, unknown IDs, atomic failure/success and overflow; stack boundaries, capacity and atomic rejection; invalid saved counts; potion clamping/no-waste/fallen/material rejection; ordinary/boss rewards; full-bag behavior; XP cap; atomic checkpoint round-trip, backup recovery, bad JSON/schema/containers/XP, oversize input, future-save non-overwrite, failed writes, retained autosave-failure feedback on opening the UI, and starter-item non-duplication; actual enemy-death reward idempotence; retry/mode persistence; modal pause restoration; Arabic selected-item localization; registered input action; discard confirmation/cancellation/commit.

## Android APK — Actual Build PASS

[**Download SHADOWBOUND v0.4.0 APK**](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/download/v0.4.0-android-preview-4/SHADOWBOUND-v0.4.0-preview.apk)

[Release / checksum](https://github.com/asdasdqqww111-lab/SHADOWBOUND/releases/tag/v0.4.0-android-preview-4)

- File size: **159,690,401 bytes** (~160 MB / 152 MiB).
- SHA-256: `601e84c5895b9e342a65a5d9bf29896b3b84c0eb0d88ec840a230d54d4524630`.
- APK source: `20535001eaa9c78e06eb78b5ec20104ee1a8c062`, the same source verified by the final native regression suite.
- Successful build/signature/manifest/package verification: https://github.com/asdasdqqww111-lab/SHADOWBOUND/actions/runs/44426513909
- Package `com.shadowbound.rpg`, version **0.4.0-preview**, code **4**.
- Android minimum SDK **28** / target **34**, launchable landscape Godot activity, OpenGL ES 3.
- Native **ARM64 + ARMv7** libraries, valid **APK v2 signature**, **zero requested Android permissions**, ZIP integrity and packaged progression/catalog/localization resources verified.
- Experimental disposable-debug-key preview. Installing over the Phase 3 APK may require uninstalling that preview. Uninstalling clears that installation's local data; future production signing/upgrade continuity is not claimed.

## Reproduce

```sh
pip install gdtoolkit==4.5.0 pillow==13.0.0
python3 tests/validate_project.py
python3 tests/test_gameplay_logic.py
godot --headless --editor --path . --import --quit
# Run each native suite independently:
godot --headless --path . res://tests/gdscript/test_phase1_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase2_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase3_runner.tscn
godot --headless --path . res://tests/gdscript/test_phase4_runner.tscn
```

Native Phase 4 save tests use `user://phase4_test_progress.json` and clean up their temporary/backup documents. Normal progression checkpoints are not deleted by the tests. Earlier suites can award normal gameplay rewards in their isolated CI user directory.

## Remaining Manual Acceptance / Scope Limits

- Test EN/AR text fit, item selection/scrolling, confirmed discard, multitouch, Back behavior and gameplay feel on real Android hardware; no screenshot or physical-device certification is claimed by headless results.
- Confirm persistence across force-close/relaunch on the target phone; the file I/O and service round-trip are tested natively, but Android lifecycle behavior has not been device-tested here.
- Only progression is checkpointed; the complete world/guild/quest save remains Phase 7. No encryption or anti-tamper promise.
- Equipment, rarity, blacksmith, five playable classes, skill trees and randomized loot remain Phase 5. Shops/towns/quests remain Phase 6. Audio, performance profiling, stable production signing and release optimization remain later work.
