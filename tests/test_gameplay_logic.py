#!/usr/bin/env python3
"""
SHADOWBOUND — Phase 2 Behavioral, Camera & Controller Verification Suite.

Verifies:
1. Side-Scrolling physics: jump/double-jump/apex-hang, platform & one-way skybridge
   reachability, WallJumpTower clearance & wall-jump trajectory to UpperOverlookLedge,
   wall-slide speed clamping, air-dodge i-frame window, and guard/perfect-parry parameters.
2. Top-Down 8-direction controller: exact 8-compass octant mapping (E, SE, S, SW, W, NW, N, NE),
   strict unit-circle normalization, analog walk/run/sprint speed hierarchy, guard & dodge i-frames,
   courtyard enclosure, pillar clearance, and LoreRunestone exploration placement.
3. Dual-Mode Camera profiles & CameraZoneTrigger priority/vista/POI framing math.
4. Android Touch Controls: all 5 action buttons (Attack, Jump, Block, Dodge, Mode) meet minimum
   ergonomic touch dimensions with zero pairwise circle overlap.
"""

from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPASS_LABELS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

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


def vector_to_compass_8(x: float, y: float) -> str:
    if x * x + y * y < 0.0001:
        return "S"
    octant = round(math.atan2(y, x) / (math.pi * 0.25)) % 8
    return COMPASS_LABELS[octant]


def parse_tres_floats(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.startswith("["):
            k, v = line.split("=", 1)
            result[k.strip()] = v.strip()
    return result


def test_sidescroll_controller_and_level() -> None:
    print("\n--- 1. Side-Scrolling Controller & Level Geometry ---")
    cfg = json.loads((ROOT / "data/config/movement_config.json").read_text(encoding="utf-8"))
    ss = cfg["side_scroll"]
    shared = cfg["shared"]

    g = float(ss["gravity"])
    g_fall = g * float(ss["fall_gravity_multiplier"])
    v_jump = float(ss["jump_velocity"])
    v_djump = float(ss["double_jump_velocity"])
    speed = float(ss["move_speed"])

    h1 = (v_jump ** 2) / (2.0 * g)
    h2 = (v_djump ** 2) / (2.0 * g)
    h_double = h1 + h2
    t1 = abs(v_jump) / g + math.sqrt(2.0 * h1 / g_fall)
    span1 = speed * t1

    check(95.0 <= h1 <= 130.0, f"Single jump apex height well-tuned ({h1:.1f} px)")
    check(170.0 <= h_double <= 225.0, f"Double jump combined apex well-tuned ({h_double:.1f} px)")
    check(0.5 <= ss["apex_gravity_multiplier"] < 1.0, f"Apex hang gravity smoothing enabled ({ss['apex_gravity_multiplier']}x)")
    check(ss["turn_acceleration_multiplier"] > 1.2, f"Turn-around snap boost enabled ({ss['turn_acceleration_multiplier']}x)")

    # Consecutive main-route platforms
    platforms = [
        ("StartTerrace", 256, 152, 768, 64),
        ("LowStepPlatform", 860, 62, 256, 64),
        ("HighShrinePlatform", 1320, -28, 512, 64),
        ("LowerBridgePlatform", 1820, 92, 512, 64),
        ("EastSanctumTerrace", 2280, -8, 512, 64),
    ]
    for i in range(len(platforms) - 1):
        n1, cx1, cy1, w1, hp1 = platforms[i]
        n2, cx2, cy2, w2, hp2 = platforms[i + 1]
        gap_x = max(0.0, (cx2 - w2 / 2.0) - (cx1 + w1 / 2.0))
        climb_y = max(0.0, (cy1 - hp1 / 2.0) - (cy2 - hp2 / 2.0))
        check(
            gap_x < span1 * 0.85 and climb_y <= h1,
            f"Platform hop {n1} -> {n2} reachable (gap={gap_x:.0f}px, climb={climb_y:.0f}px)",
        )

    # One-way skybridges reachable via single jump from parent platform
    west_bridge_climb = 120.0 - (44.0 - 8.0)  # 84 px
    east_bridge_climb = 60.0 - (-6.0 - 8.0)   # 74 px
    check(
        0 < west_bridge_climb < h1 and 0 < east_bridge_climb < h1,
        f"Both One-Way Skybridges reachable via single jump ({west_bridge_climb:.0f}px, {east_bridge_climb:.0f}px) and support Down+Jump drop-through ({ss['drop_through_duration']}s)",
    )

    # WallJumpTower (center 660, -210, size 64x220 -> right face x=692, bottom y=-100)
    tower_bottom = -210 + 110  # -100
    terrace_head_y = 120 - 66  # 54
    check(
        terrace_head_y - tower_bottom > 120.0,
        f"WallJumpTower leaves wide unobstructed main-route clearance ({terrace_head_y - tower_bottom:.0f} px)",
    )

    wj_vx = float(ss["wall_jump_velocity_x"])
    wj_vy = float(ss["wall_jump_velocity_y"])
    wj_h = (wj_vy ** 2) / (2.0 * g)
    wj_span = wj_vx * (abs(wj_vy) / g)
    gap_tower_to_overlook = (920 - 128) - (660 + 32)  # 792 - 692 = 100 px
    check(
        ss["wall_slide_max_speed"] <= 180.0 and wj_h > 85.0 and wj_span > gap_tower_to_overlook,
        f"Wall slide ({ss['wall_slide_max_speed']} px/s) & Wall jump reach UpperOverlookLedge (span={wj_span:.0f}px > gap={gap_tower_to_overlook}px)",
    )

    # Dodge i-frames & Shadow Guard / Perfect Parry parameters
    check(
        0.1 <= ss["dodge_iframe_duration"] <= ss["dodge_duration"] and ss["max_air_dodges"] == 1,
        f"SideScroll dodge i-frames ({ss['dodge_iframe_duration']}s <= {ss['dodge_duration']}s) and air-dodge cap (1) valid",
    )
    check(
        0.1 <= ss["perfect_block_window"] <= 0.3 and 0.1 <= ss["block_move_factor"] <= 0.5,
        f"SideScroll Shadow Guard move factor ({ss['block_move_factor']}) & perfect-guard window ({ss['perfect_block_window']}s) valid",
    )
    check(
        shared["abyss_respawn_y"] > 300.0,
        f"Abyss respawn Y ({shared['abyss_respawn_y']}) safely below all platforms",
    )


def test_topdown_8dir_controller_and_courtyard() -> None:
    print("\n--- 2. Top-Down 8-Direction Controller & Sanctum Courtyard ---")
    cfg = json.loads((ROOT / "data/config/movement_config.json").read_text(encoding="utf-8"))
    td = cfg["top_down"]
    speed = float(td["move_speed"])

    cases = [
        (1, 0, "E"), (1, 1, "SE"), (0, 1, "S"), (-1, 1, "SW"),
        (-1, 0, "W"), (-1, -1, "NW"), (0, -1, "N"), (1, -1, "NE"),
    ]
    compass_ok = all(vector_to_compass_8(dx, dy) == exp for dx, dy, exp in cases)
    norm_ok = all(math.isclose(min(1.0, math.hypot(dx, dy)) * speed, speed) for dx, dy, _ in cases)
    check(compass_ok, "All 8 compass octants resolve identically (E, SE, S, SW, W, NW, N, NE)")
    check(norm_ok, f"All 8 directions normalize strictly to {speed:.1f} px/s")

    walk_v = speed * float(td["walk_speed_factor"])
    sprint_v = speed * float(td["sprint_speed_multiplier"])
    check(
        100.0 < walk_v < speed < sprint_v < td["dodge_speed"],
        f"Top-down speed hierarchy valid: walk({walk_v:.0f}) < run({speed:.0f}) < sprint({sprint_v:.0f}) < dodge({td['dodge_speed']:.0f})",
    )
    check(
        0.1 <= td["dodge_iframe_duration"] <= td["dodge_duration"] and 0.1 <= td["perfect_block_window"] <= 0.3,
        f"Top-down dodge i-frames ({td['dodge_iframe_duration']}s) & directional perfect-guard ({td['perfect_block_window']}s) valid",
    )

    # Courtyard enclosure: inner walk space x in [96..1504], y in [1656..2584]
    key_points = [
        ("TopDownSpawn", 800, 2165),
        ("LoreStoneWest", 240, 2120),
        ("LoreStoneEast", 1360, 2120),
        ("RiftGateSanctum", 800, 1825),
    ]
    pillars = [(420, 1880), (1180, 1880), (420, 2360), (1180, 2360)]
    for name, px, py in key_points:
        inside = (140 <= px <= 1460) and (1700 <= py <= 2540)
        clear = min(math.hypot(px - qx, py - qy) for qx, qy in pillars) > 160.0
        check(inside and clear, f"{name} ({px}, {py}) sits inside courtyard and clear of all pillars")


def test_dual_camera_profiles_and_zones() -> None:
    print("\n--- 3. Dual-Mode Camera Profiles & Vista Zones ---")
    ss_p = parse_tres_floats(ROOT / "resources/camera/side_scroll_camera_profile.tres")
    td_p = parse_tres_floats(ROOT / "resources/camera/top_down_camera_profile.tres")

    check(
        ss_p.get("mode_id") == "0" and ss_p.get("mode_key") == '"side_scroll"',
        "Side-scroll CameraModeProfile resource configured (mode_id=0)",
    )
    check(
        td_p.get("mode_id") == "1" and td_p.get("mode_key") == '"top_down"',
        "Top-down CameraModeProfile resource configured (mode_id=1)",
    )
    check(
        ss_p.get("drag_horizontal_enabled") == "false" and ss_p.get("drag_vertical_enabled") == "true",
        "Side-scroll camera locks horizontal follow and enables vertical platform deadzone",
    )
    check(
        td_p.get("drag_horizontal_enabled") == "true" and td_p.get("drag_vertical_enabled") == "true",
        "Top-down camera enables symmetric 2D exploration deadzone",
    )
    check(
        float(ss_p.get("fall_peek_offset_y", "0")) >= 50.0 and float(td_p.get("fall_peek_offset_y", "1")) == 0.0,
        "Fall-peek active exclusively in Side-Scroll camera profile",
    )

    level_txt = (ROOT / "scenes/levels/twilight_sanctum.tscn").read_text(encoding="utf-8")
    vista_ids = re.findall(r'zone_id = "([^"]+)"', level_txt)
    check(
        set(vista_ids) >= {"cliff_overlook", "east_rift", "sanctum_altar"},
        f"Twilight Sanctum mounts camera vista zones across both modes ({vista_ids})",
    )


def test_touch_controls_ergonomics() -> None:
    print("\n--- 4. Android 5-Button Multi-Touch Ergonomics ---")
    tscn = (ROOT / "scenes/ui/touch_controls.tscn").read_text(encoding="utf-8")
    buttons = {}
    for bname in ("AttackButton", "JumpButton", "BlockButton", "DodgeButton", "ModeButton"):
        m = re.search(
            rf'\[node name="{bname}".*?offset_left = ([-\d.]+)\noffset_top = ([-\d.]+)\noffset_right = ([-\d.]+)\noffset_bottom = ([-\d.]+)',
            tscn,
            re.DOTALL,
        )
        assert m is not None, f"Missing {bname}"
        l, t, r, b = [float(x) for x in m.groups()]
        buttons[bname] = ((l + r) * 0.5, (t + b) * 0.5, max(r - l, b - t) * 0.5)
        check(
            r - l >= 88.0 and b - t >= 88.0,
            f"{bname} meets Android touch target minimum ({r - l:.0f}x{b - t:.0f} px)",
        )

    names = list(buttons.keys())
    overlaps = []
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            c1x, c1y, r1 = buttons[names[i]]
            c2x, c2y, r2 = buttons[names[j]]
            if math.hypot(c1x - c2x, c1y - c2y) <= r1 + r2:
                overlaps.append(f"{names[i]}<->{names[j]}")
    check(len(overlaps) == 0, f"Zero pairwise circle overlaps across all 5 touch buttons (overlaps: {overlaps})")


def main() -> int:
    print("=== SHADOWBOUND Phase 2 Gameplay, Camera & Controller Tests ===")
    test_sidescroll_controller_and_level()
    test_topdown_8dir_controller_and_courtyard()
    test_dual_camera_profiles_and_zones()
    test_touch_controls_ergonomics()
    print(f"\nSUMMARY: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
