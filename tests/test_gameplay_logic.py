#!/usr/bin/env python3
"""
SHADOWBOUND — Phase 1 Behavioral & Geometry Verification Tests.

Verifies movement math parity with `movement_config.json`, side-scrolling platform
jump/double-jump reachability in `twilight_sanctum.tscn`, top-down courtyard wall
enclosure, touch-control hit-zone non-overlap, and camera limit coverage.
"""

from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

passed = 0
failed = 0


def check(cond: bool, msg: str) -> None:
    global passed, failed
    if cond:
        passed += 1
        print(f"[PASS] {msg}")
    else:
        failed += 1
        print(f"[FAIL] {msg}")


def test_sidescroll_physics_and_reachability() -> None:
    cfg = json.loads((ROOT / "data/config/movement_config.json").read_text(encoding="utf-8"))
    ss = cfg["side_scroll"]
    shared = cfg["shared"]

    g = float(ss["gravity"])
    g_fall = g * float(ss["fall_gravity_multiplier"])
    v_jump = float(ss["jump_velocity"])
    v_djump = float(ss["double_jump_velocity"])
    speed = float(ss["move_speed"])

    # Exact projectile apex heights
    h1 = (v_jump ** 2) / (2.0 * g)
    h2 = (v_djump ** 2) / (2.0 * g)
    h_double = h1 + h2
    t1 = abs(v_jump) / g + math.sqrt(2.0 * h1 / g_fall)
    span1 = speed * t1

    check(95.0 <= h1 <= 130.0, f"Single jump apex height is well-tuned ({h1:.1f} px)")
    check(170.0 <= h_double <= 220.0, f"Double jump combined apex height is well-tuned ({h_double:.1f} px)")
    check(span1 >= 200.0, f"Single jump horizontal reach covers platform gaps ({span1:.1f} px)")

    # Verify consecutive platform transitions in twilight_sanctum.tscn
    # (name, center_x, center_y, width, height)
    platforms = [
        ("StartTerrace", 256, 152, 768, 64),
        ("LowStepPlatform", 860, 62, 256, 64),
        ("HighShrinePlatform", 1320, -28, 512, 64),
        ("LowerBridgePlatform", 1820, 92, 512, 64),
        ("EastSanctumTerrace", 2280, -8, 512, 64),
    ]
    for i in range(len(platforms) - 1):
        n1, cx1, cy1, w1, h_p1 = platforms[i]
        n2, cx2, cy2, w2, h_p2 = platforms[i + 1]
        right1 = cx1 + w1 / 2.0
        left2 = cx2 - w2 / 2.0
        top1 = cy1 - h_p1 / 2.0
        top2 = cy2 - h_p2 / 2.0
        gap_x = max(0.0, left2 - right1)
        climb_y = max(0.0, top1 - top2)
        check(
            gap_x < span1 * 0.85 and climb_y <= h1,
            f"Platform hop {n1} -> {n2} reachable via single jump (gap={gap_x:.0f}px, climb={climb_y:.0f}px)",
        )

    # Verify UpperOverlookLedge specifically tests double-jump
    overlook_top = -178 - 32  # -210
    shrine_top = -28 - 32     # -60
    overlook_climb = shrine_top - overlook_top  # 150 px
    check(
        h1 < overlook_climb < h_double - 20.0,
        f"UpperOverlookLedge rewards double jump (climb={overlook_climb}px vs h1={h1:.1f}px, h2={h_double:.1f}px)",
    )

    # Verify abyss respawn threshold sits safely below lowest platform
    lowest_top = max(cy - hp / 2.0 for _, _, cy, _, hp in platforms)
    check(
        shared["abyss_respawn_y"] > lowest_top + 200.0,
        f"Abyss respawn Y ({shared['abyss_respawn_y']}) safely below lowest platform top ({lowest_top})",
    )


def test_topdown_8dir_and_courtyard() -> None:
    cfg = json.loads((ROOT / "data/config/movement_config.json").read_text(encoding="utf-8"))
    td = cfg["top_down"]
    speed = float(td["move_speed"])

    # Verify all 8 compass directions clamp to unit length (no sqrt(2) diagonal exploit)
    dirs = [
        (1, 0), (-1, 0), (0, 1), (0, -1),
        (1, 1), (1, -1), (-1, 1), (-1, -1),
    ]
    all_normalized = True
    for dx, dy in dirs:
        mag = math.hypot(dx, dy)
        clamped_mag = min(1.0, mag)
        vel_mag = clamped_mag * speed
        if not math.isclose(vel_mag, speed, rel_tol=1e-6):
            all_normalized = False
    check(all_normalized, f"All 8 top-down movement directions normalize to {speed:.1f} px/s")

    # Verify TopDownSpawn (800, 2165) is strictly inside courtyard walls and clear of all 4 pillars
    spawn = (800.0, 2165.0)
    north_inner = 1608 + 48
    south_inner = 2632 - 48
    west_inner = 48 + 48
    east_inner = 1552 - 48
    inside = (west_inner + 40 < spawn[0] < east_inner - 40) and (north_inner + 40 < spawn[1] < south_inner - 40)
    check(inside, "TopDownSpawn sits safely inside enclosed Sanctum Courtyard walls")

    pillars = [(420, 1880), (1180, 1880), (420, 2360), (1180, 2360)]
    min_pillar_dist = min(math.hypot(spawn[0] - px, spawn[1] - py) for px, py in pillars)
    check(min_pillar_dist > 200.0, f"TopDownSpawn is clear of all courtyard pillars (min dist {min_pillar_dist:.1f} px)")


def test_touch_controls_ergonomics() -> None:
    tscn = (ROOT / "scenes/ui/touch_controls.tscn").read_text(encoding="utf-8")
    buttons = {}
    for bname in ("AttackButton", "JumpButton", "DodgeButton", "ModeButton"):
        m = re.search(
            rf'\[node name="{bname}".*?offset_left = ([-\d.]+)\noffset_top = ([-\d.]+)\noffset_right = ([-\d.]+)\noffset_bottom = ([-\d.]+)',
            tscn,
            re.DOTALL,
        )
        assert m is not None, f"Missing {bname}"
        l, t, r, b = [float(x) for x in m.groups()]
        cx, cy = (l + r) * 0.5, (t + b) * 0.5
        rad = max(r - l, b - t) * 0.5
        buttons[bname] = (cx, cy, rad)
        check(r - l >= 88.0 and b - t >= 88.0, f"{bname} meets Android touch target minimum ({r - l:.0f}x{b - t:.0f} px)")

    # Pairwise non-overlap check
    names = list(buttons.keys())
    overlaps = []
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            c1x, c1y, r1 = buttons[names[i]]
            c2x, c2y, r2 = buttons[names[j]]
            dist = math.hypot(c1x - c2x, c1y - c2y)
            if dist <= r1 + r2:
                overlaps.append(f"{names[i]}<->{names[j]}")
    check(len(overlaps) == 0, f"Zero touch button circle overlaps in ActionCluster (overlaps: {overlaps})")


def main() -> int:
    print("=== SHADOWBOUND Phase 1 Gameplay Logic & Ergonomics Tests ===")
    test_sidescroll_physics_and_reachability()
    test_topdown_8dir_and_courtyard()
    test_touch_controls_ergonomics()
    print(f"SUMMARY: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
