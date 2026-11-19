#!/usr/bin/env python3
"""
SHADOWBOUND — Deterministic Original Anime Fantasy Stickman Art Generator.

Generates clean, supersampled (2x anti-aliased) original prototype sprites,
environment layers, props, and mobile touch UI icons under `assets/sprites/`.
All outputs are 100% original CC0 project art with exact frame dimensions
documented in `docs/ASSET_PIPELINE.md` for seamless artist drop-in replacement.
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SPRITES_DIR = ROOT / "assets" / "sprites"

# Cohesive Shadowbound palette (Twilight Obsidian + Shadow Violet + Royal Gold + Crimson Scarf + Cyan Eyes)
INK_DARK = (14, 11, 26, 255)
INK_RIM = (155, 126, 255, 255)
BODY_CORE = (20, 16, 36, 255)
EYE_CYAN = (96, 238, 255, 255)
EYE_GLOW = (96, 238, 255, 110)
SCARF_MAIN = (228, 54, 98, 255)
SCARF_DARK = (152, 26, 68, 255)
SCARF_HIGHLIGHT = (255, 122, 152, 255)
BLADE_LIGHT = (238, 232, 255, 255)
BLADE_VIOLET = (142, 96, 255, 255)
GOLD_BRIGHT = (255, 224, 138, 255)
GOLD_MID = (214, 158, 62, 255)
GOLD_DARK = (126, 82, 24, 255)
AURA_VIOLET = (138, 86, 255, 95)
AURA_CYAN = (84, 226, 255, 115)


def make_ss_canvas(w: int, h: int, bg: tuple[int, int, int, int] = (0, 0, 0, 0), scale: int = 2) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    img = Image.new("RGBA", (w * scale, h * scale), bg)
    draw = ImageDraw.Draw(img, "RGBA")
    return img, draw, scale


def finalize_ss(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def draw_limb(draw: ImageDraw.ImageDraw, p1: tuple[float, float], p2: tuple[float, float], width: int, color: tuple[int, int, int, int] = BODY_CORE, rim: tuple[int, int, int, int] | None = None) -> None:
    if rim is not None:
        rw = width + 4
        draw.line([p1, p2], fill=rim, width=rw)
        r = rw / 2.0
        for px, py in (p1, p2):
            draw.ellipse((px - r, py - r, px + r, py + r), fill=rim)
    draw.line([p1, p2], fill=color, width=width)
    r = width / 2.0
    for px, py in (p1, p2):
        draw.ellipse((px - r, py - r, px + r, py + r), fill=color)


def draw_anime_head_side(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    radius: float,
    s: int,
    lean: float = 0.0,
    alpha_scale: float = 1.0,
) -> None:
    def a(col: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        return (col[0], col[1], col[2], max(0, min(255, int(col[3] * alpha_scale))))

    # Spiky anime hair tufts sweeping slightly backward (left)
    spikes = [
        [(cx - radius * 0.4, cy - radius * 0.65), (cx - radius * 1.35, cy - radius * 1.15), (cx + radius * 0.05, cy - radius * 0.95)],
        [(cx - radius * 0.1, cy - radius * 0.8), (cx - radius * 0.55, cy - radius * 1.55), (cx + radius * 0.45, cy - radius * 0.9)],
        [(cx + radius * 0.1, cy - radius * 0.75), (cx + radius * 0.55, cy - radius * 1.35), (cx + radius * 0.8, cy - radius * 0.55)],
        [(cx - radius * 0.65, cy - radius * 0.25), (cx - radius * 1.45, cy - radius * 0.45), (cx - radius * 0.75, cy + radius * 0.2)],
    ]
    for tri in spikes:
        draw.polygon(tri, fill=a(INK_DARK), outline=a((112, 84, 210, 180)))

    # Rim circle + obsidian stickman head
    r_out = radius + 1.5 * s
    draw.ellipse((cx - r_out, cy - r_out, cx + r_out, cy + r_out), fill=a((132, 98, 235, 220)))
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=a(INK_DARK))

    # Glowing sharp anime eye (facing right)
    ex = cx + radius * 0.34 + lean * 1.5
    ey = cy + radius * 0.06
    draw.ellipse((ex - 5 * s, ey - 3.5 * s, ex + 6 * s, ey + 3.5 * s), fill=a(EYE_GLOW))
    eye_poly = [
        (ex - 3.2 * s, ey + 0.5 * s),
        (ex + 4.8 * s, ey - 2.0 * s),
        (ex + 3.8 * s, ey + 2.0 * s),
        (ex - 2.4 * s, ey + 2.2 * s),
    ]
    draw.polygon(eye_poly, fill=a(EYE_CYAN))
    # Faint secondary far-side eye glint
    ex2 = cx + radius * 0.72
    draw.polygon(
        [(ex2 - 1.0 * s, ey - 1.2 * s), (ex2 + 2.2 * s, ey - 1.8 * s), (ex2 + 1.6 * s, ey + 1.4 * s)],
        fill=a(EYE_CYAN),
    )


def draw_scarf_ribbon(
    draw: ImageDraw.ImageDraw,
    neck: tuple[float, float],
    wave_phase: float,
    length: float,
    lift: float,
    s: int,
    alpha_scale: float = 1.0,
) -> None:
    def a(col: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        return (col[0], col[1], col[2], max(0, min(255, int(col[3] * alpha_scale))))

    nx, ny = neck
    pts_top = []
    pts_bot = []
    steps = 7
    for i in range(steps):
        t = i / (steps - 1)
        px = nx - t * length
        py = ny + lift * t + math.sin(wave_phase + t * 3.8) * (4.5 * s * t)
        thickness = (4.2 * (1.0 - 0.55 * t) + 1.4) * s
        pts_top.append((px, py - thickness * 0.5))
        pts_bot.append((px, py + thickness * 0.5))
    poly = pts_top + list(reversed(pts_bot))
    draw.polygon(poly, fill=a(SCARF_MAIN), outline=a(SCARF_DARK))
    # Collar wrap around neck
    draw.rounded_rectangle(
        (nx - 7 * s, ny - 3.5 * s, nx + 7.5 * s, ny + 3.8 * s),
        radius=int(3 * s),
        fill=a(SCARF_MAIN),
        outline=a(SCARF_HIGHLIGHT),
        width=max(1, s // 2),
    )


def draw_sidescroll_pose(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    s: int,
    pose: dict,
    alpha_scale: float = 1.0,
) -> None:
    def pt(x: float, y: float) -> tuple[float, float]:
        return ((ox + x) * s, (oy + y) * s)

    def a(col: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        return (col[0], col[1], col[2], max(0, min(255, int(col[3] * alpha_scale))))

    # Ground contact shadow when grounded
    if pose.get("grounded", True) and alpha_scale > 0.8:
        draw.ellipse((pt(42, 111), pt(86, 120)), fill=(8, 5, 18, 120))

    hip = pt(*pose["hip"])
    neck = pt(*pose["neck"])
    head_c = pt(*pose["head"])

    # Flowing crimson scarf behind body
    draw_scarf_ribbon(
        draw,
        neck,
        wave_phase=pose.get("scarf_phase", 0.0),
        length=pose.get("scarf_len", 30.0) * s,
        lift=pose.get("scarf_lift", 4.0) * s,
        s=s,
        alpha_scale=alpha_scale,
    )

    # Sheathed katana on hip if not actively swinging
    if not pose.get("sword_drawn", False):
        sx1, sy1 = pt(pose["hip"][0] - 22, pose["hip"][1] + 10)
        sx2, sy2 = pt(pose["hip"][0] + 14, pose["hip"][1] - 6)
        draw.line([(sx1, sy1), (sx2, sy2)], fill=a((46, 32, 82, 255)), width=int(3.5 * s))
        draw.line([(sx2, sy2), (sx2 + 6 * s, sy2 - 3 * s)], fill=a(GOLD_BRIGHT), width=int(3 * s))

    body_col = a(BODY_CORE)
    far_col = a((42, 32, 74, 255))
    rim_col = a((126, 94, 228, 175))
    limb_w = int(5.4 * s)
    torso_w = int(6.8 * s)

    # Far leg & far arm
    draw_limb(draw, hip, pt(*pose["l_knee"]), limb_w, far_col)
    draw_limb(draw, pt(*pose["l_knee"]), pt(*pose["l_foot"]), limb_w, far_col)
    draw_limb(draw, neck, pt(*pose["l_elbow"]), int(4.6 * s), far_col)
    draw_limb(draw, pt(*pose["l_elbow"]), pt(*pose["l_hand"]), int(4.6 * s), far_col)

    # Torso (slim athletic anime stickman)
    draw_limb(draw, hip, neck, torso_w, body_col, rim=rim_col)

    # Near leg
    draw_limb(draw, hip, pt(*pose["r_knee"]), limb_w, body_col, rim=rim_col)
    draw_limb(draw, pt(*pose["r_knee"]), pt(*pose["r_foot"]), limb_w, body_col, rim=rim_col)

    # Drawn shadow katana + near arm
    r_hand = pt(*pose["r_hand"])
    if pose.get("sword_drawn", False):
        angle = pose.get("sword_angle", -0.3)
        blen = pose.get("sword_len", 42.0) * s
        tip = (r_hand[0] + math.cos(angle) * blen, r_hand[1] + math.sin(angle) * blen)
        # Violet energy aura around blade
        draw.line([r_hand, tip], fill=a((150, 92, 255, 165)), width=int(7.0 * s))
        draw.line([r_hand, tip], fill=a(BLADE_LIGHT), width=int(3.2 * s))
        # Gold tsuba guard
        gx = r_hand[0] + math.cos(angle + 1.57) * 4.5 * s
        gy = r_hand[1] + math.sin(angle + 1.57) * 4.5 * s
        gx2 = r_hand[0] - math.cos(angle + 1.57) * 4.5 * s
        gy2 = r_hand[1] - math.sin(angle + 1.57) * 4.5 * s
        draw.line([(gx, gy), (gx2, gy2)], fill=a(GOLD_BRIGHT), width=int(2.6 * s))

    draw_limb(draw, neck, pt(*pose["r_elbow"]), int(4.8 * s), body_col, rim=rim_col)
    draw_limb(draw, pt(*pose["r_elbow"]), r_hand, int(4.8 * s), body_col, rim=rim_col)

    # Head with anime hair & glowing cyan eye
    draw_anime_head_side(draw, head_c[0], head_c[1], 12.5 * s, s, lean=pose.get("lean", 0.0), alpha_scale=alpha_scale)


def generate_sidescroll_sheet() -> None:
    cell = 128
    cols, rows = 8, 11
    w, h = cell * cols, cell * rows
    img, draw, s = make_ss_canvas(w, h, scale=2)

    # Row 0: idle (6 frames)
    for f in range(6):
        ox, oy = f * cell, 0 * cell
        phase = (f / 6.0) * math.tau
        bob = math.sin(phase) * 2.0
        pose = {
            "head": (64, 42 + bob),
            "neck": (63, 56 + bob),
            "hip": (62, 82 + bob * 0.5),
            "l_knee": (55, 98),
            "l_foot": (50, 114),
            "r_knee": (70, 98),
            "r_foot": (74, 114),
            "l_elbow": (53, 69 + bob),
            "l_hand": (56, 80 + bob),
            "r_elbow": (71, 68 + bob),
            "r_hand": (74, 78 + bob),
            "scarf_phase": phase,
            "scarf_len": 28,
            "scarf_lift": 3.0,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        # Subtle rising shadow aura mote
        mx = (ox + 48 + (f * 6) % 32) * s
        my = (oy + 96 - f * 8) * s
        draw.ellipse((mx - 2.2 * s, my - 2.2 * s, mx + 2.2 * s, my + 2.2 * s), fill=AURA_VIOLET)

    # Row 1: run (8 frames)
    for f in range(8):
        ox, oy = f * cell, 1 * cell
        phase = (f / 8.0) * math.tau
        stride = math.sin(phase)
        lift_r = max(0.0, -math.cos(phase)) * 10.0
        lift_l = max(0.0, math.cos(phase)) * 10.0
        bob = abs(math.sin(phase)) * -3.5
        pose = {
            "head": (72, 44 + bob),
            "neck": (67, 58 + bob),
            "hip": (58, 82 + bob),
            "r_knee": (62 + stride * 15, 96 - lift_r * 0.5),
            "r_foot": (58 + stride * 24, 114 - lift_r),
            "l_knee": (62 - stride * 15, 96 - lift_l * 0.5),
            "l_foot": (58 - stride * 24, 114 - lift_l),
            "r_elbow": (64 - stride * 10, 70 + bob),
            "r_hand": (70 - stride * 14, 78 + bob),
            "l_elbow": (60 + stride * 10, 68 + bob),
            "l_hand": (68 + stride * 14, 74 + bob),
            "scarf_phase": phase * 2.0,
            "scarf_len": 38,
            "scarf_lift": -1.5,
            "lean": 1.0,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)

    # Row 2: jump (4 frames)
    for f in range(4):
        ox, oy = f * cell, 2 * cell
        t = f / 3.0
        if f <= 1:
            # Shadow-cyan launch ring under feet
            rw = (22 + f * 10) * s
            rh = (5 + f * 2) * s
            cx_r, cy_r = (ox + 62) * s, (oy + 114) * s
            draw.ellipse((cx_r - rw, cy_r - rh, cx_r + rw, cy_r + rh), outline=AURA_CYAN, width=int(2.5 * s))
        pose = {
            "head": (67, 36 - t * 4),
            "neck": (64, 50 - t * 4),
            "hip": (60, 76 - t * 3),
            "r_knee": (76, 84 - t * 3),
            "r_foot": (70, 98 - t * 2),
            "l_knee": (52, 92),
            "l_foot": (44, 108),
            "r_elbow": (75, 58 - t * 4),
            "r_hand": (82, 48 - t * 5),
            "l_elbow": (50, 62),
            "l_hand": (44, 72),
            "scarf_phase": t * 3.0,
            "scarf_len": 34,
            "scarf_lift": 14.0,
            "lean": 0.6,
            "grounded": False,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)

    # Row 3: fall (4 frames)
    for f in range(4):
        ox, oy = f * cell, 3 * cell
        phase = (f / 4.0) * math.tau
        sway = math.sin(phase) * 2.0
        pose = {
            "head": (65, 40),
            "neck": (63, 54),
            "hip": (61, 80),
            "r_knee": (73, 92 + sway),
            "r_foot": (77, 108),
            "l_knee": (52, 88 - sway),
            "l_foot": (48, 103),
            "r_elbow": (76, 52 + sway),
            "r_hand": (84, 44 + sway),
            "l_elbow": (48, 52 - sway),
            "l_hand": (40, 44 - sway),
            "scarf_phase": phase,
            "scarf_len": 34,
            "scarf_lift": -16.0,
            "grounded": False,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)

    # Row 4: dodge / shadow-step (5 frames)
    for f in range(5):
        ox, oy = f * cell, 4 * cell
        dash_pose = {
            "head": (78, 52),
            "neck": (70, 64),
            "hip": (56, 86),
            "r_knee": (74, 96),
            "r_foot": (84, 112),
            "l_knee": (42, 96),
            "l_foot": (28, 110),
            "r_elbow": (64, 74),
            "r_hand": (78, 76),
            "l_elbow": (52, 72),
            "l_hand": (38, 76),
            "scarf_phase": f * 1.3,
            "scarf_len": 42,
            "scarf_lift": -2.0,
            "lean": 1.4,
            "grounded": False,
        }
        # Ghost afterimage behind player
        draw_sidescroll_pose(draw, ox - 18, oy, s, dash_pose, alpha_scale=0.35)
        # Speed streak lines
        for sy, slen in ((52, 46), (72, 54), (94, 42)):
            draw.line(
                [((ox + 12) * s, (oy + sy) * s), ((ox + 12 + slen) * s, (oy + sy) * s)],
                fill=(132, 224, 255, 150),
                width=int(2.2 * s),
            )
        draw_sidescroll_pose(draw, ox, oy, s, dash_pose, alpha_scale=0.92 if f in (1, 2, 3) else 1.0)

    # Row 5: sword attack (6 frames)
    sword_angles = [-2.1, -1.3, -0.25, 0.42, 0.68, 0.5]
    for f in range(6):
        ox, oy = f * cell, 5 * cell
        ang = sword_angles[f]
        lunge = 6.0 if f in (2, 3, 4) else 0.0
        pose = {
            "head": (64 + lunge, 43),
            "neck": (61 + lunge, 57),
            "hip": (57 + lunge * 0.7, 83),
            "r_knee": (73 + lunge, 97),
            "r_foot": (82 + lunge, 114),
            "l_knee": (46, 98),
            "l_foot": (38, 114),
            "r_elbow": (72 + lunge, 64),
            "r_hand": (82 + lunge, 66 + (f - 2) * 3),
            "l_elbow": (50 + lunge * 0.5, 68),
            "l_hand": (46 + lunge * 0.5, 78),
            "scarf_phase": f * 1.1,
            "scarf_len": 34,
            "scarf_lift": 0.0,
            "sword_drawn": True,
            "sword_angle": ang,
            "sword_len": 38.0,
            "lean": 1.0,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        # Sweeping anime crescent slash VFX on impact frames 2, 3, 4
        if f in (2, 3, 4):
            alpha_arc = 235 if f == 3 else 165
            bbox_outer = ((ox + 42) * s, (oy + 18) * s, (ox + 124) * s, (oy + 112) * s)
            draw.arc(bbox_outer, start=-68, end=58, fill=(154, 96, 255, alpha_arc), width=int(10 * s))
            bbox_inner = ((ox + 46) * s, (oy + 22) * s, (ox + 121) * s, (oy + 108) * s)
            draw.arc(bbox_inner, start=-58, end=48, fill=(195, 245, 255, alpha_arc), width=int(4.5 * s))

    # Row 6: guard / block (4 frames — defensive katana stance + glowing shadow ward)
    for f in range(4):
        ox, oy = f * cell, 6 * cell
        phase = (f / 4.0) * math.tau
        pulse = math.sin(phase) * 2.0
        pose = {
            "head": (62, 46),
            "neck": (60, 60),
            "hip": (56, 85),
            "r_knee": (71, 98),
            "r_foot": (77, 114),
            "l_knee": (45, 99),
            "l_foot": (37, 114),
            "r_elbow": (74, 68),
            "r_hand": (82, 58),
            "l_elbow": (68, 72),
            "l_hand": (80, 64),
            "scarf_phase": phase,
            "scarf_len": 28,
            "scarf_lift": 2.0,
            "sword_drawn": True,
            "sword_angle": -1.38,
            "sword_len": 34.0,
            "lean": 0.4,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        # Shimmering forward shadow-cyan barrier arc
        bx1, by1 = (ox + 68 - pulse) * s, (oy + 24 - pulse) * s
        bx2, by2 = (ox + 108 + pulse) * s, (oy + 108 + pulse) * s
        draw.arc((bx1, by1, bx2, by2), start=-65, end=65, fill=(142, 96, 255, 195), width=int(6.5 * s))
        draw.arc((bx1 + 3 * s, by1 + 4 * s, bx2 - 2 * s, by2 - 4 * s), start=-55, end=55, fill=EYE_CYAN, width=int(3.0 * s))

    # Row 7: wall_slide (4 frames — braced against right-side wall with cyan sparks)
    for f in range(4):
        ox, oy = f * cell, 7 * cell
        phase = (f / 4.0) * math.tau
        pose = {
            "head": (66, 44),
            "neck": (64, 58),
            "hip": (60, 84),
            "r_knee": (76, 90),
            "r_foot": (82, 102),
            "l_knee": (54, 96),
            "l_foot": (58, 112),
            "r_elbow": (76, 54),
            "r_hand": (84, 42),
            "l_elbow": (52, 68),
            "l_hand": (46, 76),
            "scarf_phase": phase * 1.5,
            "scarf_len": 32,
            "scarf_lift": -14.0,
            "grounded": False,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        # Wall friction aura sparks
        spark_y = (oy + 44 + (f * 14) % 48) * s
        spark_x = (ox + 85) * s
        draw.ellipse((spark_x - 3 * s, spark_y - 3 * s, spark_x + 3 * s, spark_y + 3 * s), fill=EYE_CYAN)
        draw.line([(spark_x, spark_y), (spark_x - 5 * s, spark_y - 8 * s)], fill=GOLD_BRIGHT, width=int(2 * s))

    # Row 8: attack_2 — Crescent Reverse upward cyan slash (5 frames)
    up_angles = [0.78, 0.25, -0.55, -1.45, -1.85]
    for f in range(5):
        ox, oy = f * cell, 8 * cell
        lunge = 7.0 if f in (1, 2, 3) else 0.0
        pose = {
            "head": (65 + lunge, 41),
            "neck": (62 + lunge, 55),
            "hip": (58 + lunge * 0.7, 82),
            "r_knee": (74 + lunge, 96),
            "r_foot": (84 + lunge, 114),
            "l_knee": (46, 98),
            "l_foot": (36, 114),
            "r_elbow": (73 + lunge, 62),
            "r_hand": (84 + lunge, 58 - f * 2),
            "l_elbow": (50 + lunge * 0.5, 67),
            "l_hand": (44 + lunge * 0.5, 76),
            "scarf_phase": f * 1.25 + 1.0,
            "scarf_len": 36,
            "scarf_lift": -3.0,
            "sword_drawn": True,
            "sword_angle": up_angles[f],
            "sword_len": 40.0,
            "lean": 1.15,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        if f in (1, 2, 3):
            a_arc = 240 if f == 2 else 175
            draw.arc(((ox + 44) * s, (oy + 12) * s, (ox + 125) * s, (oy + 108) * s), start=-82, end=52, fill=(76, 224, 255, a_arc), width=int(10 * s))
            draw.arc(((ox + 48) * s, (oy + 16) * s, (ox + 121) * s, (oy + 104) * s), start=-72, end=42, fill=(235, 250, 255, a_arc), width=int(4.5 * s))

    # Row 9: attack_3 — Eclipse Finisher blazing crimson-gold heavy cleave (6 frames)
    fin_angles = [-2.4, -1.7, -0.35, 0.35, 0.72, 0.62]
    for f in range(6):
        ox, oy = f * cell, 9 * cell
        lunge = 10.0 if f in (2, 3, 4) else (-3.0 if f == 0 else 2.0)
        pose = {
            "head": (64 + lunge, 40 if f < 2 else 44),
            "neck": (61 + lunge, 54 if f < 2 else 58),
            "hip": (56 + lunge * 0.8, 82),
            "r_knee": (75 + lunge, 96),
            "r_foot": (86 + lunge, 114),
            "l_knee": (44, 98),
            "l_foot": (34, 114),
            "r_elbow": (74 + lunge, 62),
            "r_hand": (86 + lunge, 64),
            "l_elbow": (52 + lunge * 0.5, 66),
            "l_hand": (48 + lunge * 0.5, 74),
            "scarf_phase": f * 1.4,
            "scarf_len": 40,
            "scarf_lift": -5.0,
            "sword_drawn": True,
            "sword_angle": fin_angles[f],
            "sword_len": 44.0,
            "lean": 1.35,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        if f in (2, 3, 4):
            a_arc = 248 if f == 3 else 185
            draw.arc(((ox + 34) * s, (oy + 8) * s, (ox + 126) * s, (oy + 116) * s), start=-78, end=68, fill=(235, 58, 104, a_arc), width=int(13 * s))
            draw.arc(((ox + 40) * s, (oy + 14) * s, (ox + 122) * s, (oy + 112) * s), start=-68, end=58, fill=(255, 224, 138, a_arc), width=int(6.5 * s))

    # Row 10: hurt — stagger recoil with crimson impact spark (3 frames)
    for f in range(3):
        ox, oy = f * cell, 10 * cell
        recoil = (2 - f) * 3.0
        pose = {
            "head": (58 - recoil, 45),
            "neck": (60 - recoil, 59),
            "hip": (62 - recoil * 0.5, 85),
            "r_knee": (72, 98),
            "r_foot": (78, 114),
            "l_knee": (48, 98),
            "l_foot": (42, 114),
            "r_elbow": (72 - recoil, 68),
            "r_hand": (78 - recoil, 58),
            "l_elbow": (48 - recoil, 68),
            "l_hand": (40 - recoil, 60),
            "scarf_phase": f * 1.1,
            "scarf_len": 32,
            "scarf_lift": -6.0,
            "lean": -0.6,
            "grounded": True,
        }
        draw_sidescroll_pose(draw, ox, oy, s, pose)
        if f in (0, 1):
            draw.ellipse(((ox + 58) * s, (oy + 52) * s, (ox + 78) * s, (oy + 72) * s), outline=SCARF_HIGHLIGHT, width=int(3 * s))

    out = finalize_ss(img, w, h)
    out.save(SPRITES_DIR / "player" / "stickman_sidescroll_sheet.png")


def draw_topdown_stickman(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    s: int,
    facing: str,
    step: float,
    bob: float,
    alpha_scale: float = 1.0,
    slashing: int = -1,
) -> None:
    def pt(x: float, y: float) -> tuple[float, float]:
        return ((ox + x) * s, (oy + y) * s)

    def a(col: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        return (col[0], col[1], col[2], max(0, min(255, int(col[3] * alpha_scale))))

    # Grounded oval shadow centered around y=104
    draw.ellipse((pt(42, 97), pt(86, 113)), fill=a((8, 5, 18, 135)))

    rim_col = a((134, 102, 238, 185))
    body_col = a(BODY_CORE)
    lw = int(5.4 * s)

    # Scarf tail behind when facing down or side
    if facing == "down":
        draw.polygon(
            [pt(56, 62 + bob), pt(42, 54 + bob + step * 3), pt(46, 68 + bob)],
            fill=a(SCARF_DARK),
        )
    elif facing == "side":
        draw_scarf_ribbon(draw, pt(60, 62 + bob), step * 2.0, 26 * s, 5 * s, s, alpha_scale)

    # Diagonal katana across back (when not mid-slash)
    if slashing < 0:
        draw.line([pt(48, 82 + bob), pt(78, 50 + bob)], fill=a((66, 46, 118, 255)), width=int(3.6 * s))
        draw.line([pt(76, 52 + bob), pt(83, 45 + bob)], fill=a(GOLD_BRIGHT), width=int(3.0 * s))

    # Legs (3/4 RPG stride)
    if facing in ("down", "up"):
        ly = 104 - max(0.0, step) * 6.0
        ry = 104 - max(0.0, -step) * 6.0
        draw_limb(draw, pt(58, 84 + bob), pt(55, ly), lw, body_col, rim=rim_col)
        draw_limb(draw, pt(70, 84 + bob), pt(73, ry), lw, body_col, rim=rim_col)
        # Torso cloak/tunic core
        draw.polygon(
            [pt(55, 62 + bob), pt(73, 62 + bob), pt(76, 86 + bob), pt(52, 86 + bob)],
            fill=body_col,
            outline=rim_col,
        )
        # Arms
        draw_limb(draw, pt(55, 65 + bob), pt(47, 79 + bob - step * 5), int(4.6 * s), body_col, rim=rim_col)
        draw_limb(draw, pt(73, 65 + bob), pt(81, 79 + bob + step * 5), int(4.6 * s), body_col, rim=rim_col)
        # Crimson collar scarf
        draw.rounded_rectangle(
            (pt(52, 58 + bob), pt(76, 66 + bob)),
            radius=int(3.5 * s),
            fill=a(SCARF_MAIN),
            outline=a(SCARF_HIGHLIGHT),
            width=max(1, s // 2),
        )
        if facing == "up":
            # Flowing twin scarf tails visible on back!
            draw.polygon(
                [pt(58, 65 + bob), pt(65, 65 + bob), pt(61 + step * 4, 88 + bob), pt(53 + step * 3, 86 + bob)],
                fill=a(SCARF_MAIN),
                outline=a(SCARF_DARK),
            )
            draw.polygon(
                [pt(65, 65 + bob), pt(71, 65 + bob), pt(74 - step * 3, 84 + bob), pt(67 - step * 2, 86 + bob)],
                fill=a(SCARF_DARK),
            )
    else:
        # Side 3/4 view (facing right)
        draw_limb(draw, pt(62, 84 + bob), pt(62 - step * 12, 104), lw, a((44, 34, 78, 255)))
        draw_limb(draw, pt(64, 62 + bob), pt(63, 85 + bob), int(7.5 * s), body_col, rim=rim_col)
        draw_limb(draw, pt(64, 84 + bob), pt(64 + step * 12, 104), lw, body_col, rim=rim_col)
        draw_limb(draw, pt(65, 65 + bob), pt(71 - step * 8, 80 + bob), int(4.6 * s), body_col, rim=rim_col)

    # Oversized expressive 3/4 anime stickman head (clear readability from top-down camera)
    hcx, hcy = (ox + 64) * s, (oy + 43 + bob) * s
    hr = 15.5 * s
    spikes = [
        [(hcx - hr * 0.7, hcy - hr * 0.5), (hcx - hr * 1.25, hcy - hr * 1.05), (hcx - hr * 0.15, hcy - hr * 0.9)],
        [(hcx - hr * 0.3, hcy - hr * 0.8), (hcx, hcy - hr * 1.48), (hcx + hr * 0.35, hcy - hr * 0.8)],
        [(hcx + hr * 0.15, hcy - hr * 0.9), (hcx + hr * 1.2, hcy - hr * 1.05), (hcx + hr * 0.7, hcy - hr * 0.45)],
    ]
    for tri in spikes:
        draw.polygon(tri, fill=a(INK_DARK), outline=a((118, 90, 220, 180)))
    draw.ellipse((hcx - hr - 1.5 * s, hcy - hr - 1.5 * s, hcx + hr + 1.5 * s, hcy + hr + 1.5 * s), fill=rim_col)
    draw.ellipse((hcx - hr, hcy - hr, hcx + hr, hcy + hr), fill=a(INK_DARK))

    if facing == "down":
        # Both glowing cyan anime eyes
        for sign in (-1, 1):
            ex = hcx + sign * 5.8 * s
            ey = hcy + 2.4 * s
            draw.ellipse((ex - 4.5 * s, ey - 3.2 * s, ex + 4.5 * s, ey + 3.2 * s), fill=a(EYE_GLOW))
            draw.polygon(
                [
                    (ex - sign * 3.5 * s, ey - 1.6 * s),
                    (ex + sign * 3.8 * s, ey - 0.3 * s),
                    (ex + sign * 2.8 * s, ey + 2.4 * s),
                    (ex - sign * 2.6 * s, ey + 2.0 * s),
                ],
                fill=a(EYE_CYAN),
            )
    elif facing == "side":
        ex = hcx + 6.5 * s
        ey = hcy + 2.0 * s
        draw.ellipse((ex - 4.5 * s, ey - 3.2 * s, ex + 5.5 * s, ey + 3.2 * s), fill=a(EYE_GLOW))
        draw.polygon(
            [(ex - 3 * s, ey + 0.3 * s), (ex + 4.8 * s, ey - 1.8 * s), (ex + 3.6 * s, ey + 2.2 * s), (ex - 2.2 * s, ey + 2.2 * s)],
            fill=a(EYE_CYAN),
        )

    # Sweeping 360/220 shadow-blade slash ring for td_attack
    if slashing >= 1:
        bbox = ((ox + 12) * s, (oy + 24) * s, (ox + 116) * s, (oy + 118) * s)
        start_a = -110 + slashing * 32
        end_a = start_a + 165
        alpha_s = 230 if slashing in (2, 3) else 145
        draw.arc(bbox, start=start_a, end=end_a, fill=(150, 92, 255, alpha_s), width=int(10 * s))
        bbox2 = ((ox + 18) * s, (oy + 30) * s, (ox + 110) * s, (oy + 112) * s)
        draw.arc(bbox2, start=start_a + 12, end=end_a - 12, fill=(190, 246, 255, alpha_s), width=int(4.5 * s))


def generate_topdown_sheet() -> None:
    cell = 128
    cols, rows = 6, 12
    w, h = cell * cols, cell * rows
    img, draw, s = make_ss_canvas(w, h, scale=2)

    # Rows 0..2: td_idle_down, td_idle_up, td_idle_side (4 frames each)
    for row_idx, facing in enumerate(("down", "up", "side")):
        for f in range(4):
            phase = (f / 4.0) * math.tau
            draw_topdown_stickman(draw, f * cell, row_idx * cell, s, facing, step=math.sin(phase) * 0.15, bob=math.sin(phase) * 1.8)

    # Rows 3..5: td_walk_down, td_walk_up, td_walk_side (6 frames each)
    for row_idx, facing in enumerate(("down", "up", "side"), start=3):
        for f in range(6):
            phase = (f / 6.0) * math.tau
            step = math.sin(phase)
            bob = -abs(math.sin(phase)) * 2.8
            draw_topdown_stickman(draw, f * cell, row_idx * cell, s, facing, step=step, bob=bob)

    # Row 6: td_dodge (5 frames)
    for f in range(5):
        ox, oy = f * cell, 6 * cell
        # Shadow blink ring
        cx_r, cy_r = (ox + 64) * s, (oy + 84) * s
        rad = (18 + f * 6) * s
        draw.ellipse((cx_r - rad, cy_r - rad * 0.65, cx_r + rad, cy_r + rad * 0.65), outline=(120, 232, 255, 175), width=int(3 * s))
        draw_topdown_stickman(draw, ox - 12, oy, s, "side", step=0.8, bob=-3.0, alpha_scale=0.35)
        draw_topdown_stickman(draw, ox + 4, oy, s, "side", step=0.9, bob=-3.0, alpha_scale=0.85)

    # Row 7: td_attack (5 frames)
    for f in range(5):
        draw_topdown_stickman(draw, f * cell, 7 * cell, s, "down", step=0.3, bob=-1.5, slashing=f)

    # Row 8: td_block (4 frames — omnidirectional rune ward ring + braced stance)
    for f in range(4):
        ox, oy = f * cell, 8 * cell
        pulse = math.sin((f / 4.0) * math.tau) * 2.5
        draw_topdown_stickman(draw, ox, oy, s, "down", step=0.0, bob=1.0)
        rx1, ry1 = (ox + 26 - pulse) * s, (oy + 32 - pulse) * s
        rx2, ry2 = (ox + 102 + pulse) * s, (oy + 114 + pulse) * s
        draw.ellipse((rx1, ry1, rx2, ry2), outline=(146, 98, 255, 195), width=int(4.5 * s))
        draw.arc((rx1 + 4 * s, ry1 + 4 * s, rx2 - 4 * s, ry2 - 4 * s), start=int(25 + f * 18), end=int(155 + f * 18), fill=EYE_CYAN, width=int(3.5 * s))

    # Row 9: td_attack_2 — Reverse cyan crescent slash (5 frames)
    for f in range(5):
        ox, oy = f * cell, 9 * cell
        draw_topdown_stickman(draw, ox, oy, s, "down", step=-0.4, bob=-2.0, slashing=f)
        if f in (1, 2, 3):
            draw.arc(((ox + 16) * s, (oy + 38) * s, (ox + 112) * s, (oy + 122) * s), start=-20, end=195, fill=EYE_CYAN, width=int(7.0 * s))

    # Row 10: td_attack_3 — Eclipse Spin Finisher crimson-gold 360 ring (5 frames)
    for f in range(5):
        ox, oy = f * cell, 10 * cell
        draw_topdown_stickman(draw, ox, oy, s, "side", step=0.6, bob=-2.5, slashing=f)
        if f in (1, 2, 3):
            draw.ellipse(((ox + 12) * s, (oy + 34) * s, (ox + 116) * s, (oy + 120) * s), outline=SCARF_MAIN, width=int(8.5 * s))
            draw.ellipse(((ox + 18) * s, (oy + 40) * s, (ox + 110) * s, (oy + 114) * s), outline=GOLD_BRIGHT, width=int(4.5 * s))

    # Row 11: td_hurt — Recoil frame (3 frames)
    for f in range(3):
        ox, oy = f * cell, 11 * cell
        draw_topdown_stickman(draw, ox, oy, s, "down", step=0.0, bob=2.0)
        if f in (0, 1):
            draw.ellipse(((ox + 38) * s, (oy + 48) * s, (ox + 90) * s, (oy + 98) * s), outline=SCARF_HIGHLIGHT, width=int(3.2 * s))

    out = finalize_ss(img, w, h)
    out.save(SPRITES_DIR / "player" / "stickman_topdown_sheet.png")


def generate_portrait_and_logo() -> None:
    # Hero portrait (160x160)
    w, h = 160, 160
    img, draw, s = make_ss_canvas(w, h, scale=2)
    draw.rounded_rectangle((6 * s, 6 * s, 154 * s, 154 * s), radius=24 * s, fill=(18, 12, 38, 255), outline=GOLD_MID, width=4 * s)
    draw.ellipse((24 * s, 20 * s, 136 * s, 132 * s), fill=(44, 24, 84, 210), outline=(146, 98, 255, 170), width=2 * s)
    # Shoulders & crimson scarf
    draw.polygon([(38 * s, 148 * s), (56 * s, 108 * s), (104 * s, 108 * s), (122 * s, 148 * s)], fill=INK_DARK, outline=INK_RIM)
    draw.polygon([(26 * s, 124 * s), (58 * s, 104 * s), (104 * s, 104 * s), (126 * s, 118 * s), (106 * s, 128 * s), (44 * s, 136 * s)], fill=SCARF_MAIN, outline=SCARF_HIGHLIGHT)
    # Spiky anime hair + head
    cx, cy, r = 82 * s, 74 * s, 32 * s
    for tri in [
        [(cx - 24 * s, cy - 16 * s), (cx - 46 * s, cy - 36 * s), (cx - 6 * s, cy - 28 * s)],
        [(cx - 10 * s, cy - 24 * s), (cx - 2 * s, cy - 52 * s), (cx + 14 * s, cy - 26 * s)],
        [(cx + 6 * s, cy - 24 * s), (cx + 38 * s, cy - 40 * s), (cx + 26 * s, cy - 12 * s)],
    ]:
        draw.polygon(tri, fill=INK_DARK, outline=(136, 104, 240, 210))
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK_DARK, outline=INK_RIM, width=3 * s)
    # Intense glowing cyan anime eyes
    for ex, ey, flip in ((cx - 11 * s, cy + 4 * s, -1), (cx + 13 * s, cy + 4 * s, 1)):
        draw.ellipse((ex - 10 * s, ey - 6 * s, ex + 10 * s, ey + 6 * s), fill=EYE_GLOW)
        draw.polygon(
            [(ex - flip * 8 * s, ey - 3 * s), (ex + flip * 9 * s, ey - 0.5 * s), (ex + flip * 6 * s, ey + 5 * s), (ex - flip * 6 * s, ey + 4 * s)],
            fill=EYE_CYAN,
        )
    finalize_ss(img, w, h).save(SPRITES_DIR / "player" / "player_portrait.png")

    # Main menu logo emblem (256x256)
    lw, lh = 256, 256
    limg, ldraw, ls = make_ss_canvas(lw, lh, scale=2)
    cx, cy = 128 * ls, 128 * ls
    # Outer ornate magic ring
    ldraw.ellipse((24 * ls, 24 * ls, 232 * ls, 232 * ls), fill=(18, 11, 38, 215), outline=GOLD_MID, width=4 * ls)
    ldraw.ellipse((38 * ls, 38 * ls, 218 * ls, 218 * ls), outline=(146, 98, 255, 190), width=2 * ls)
    # Crescent eclipse moon
    ldraw.ellipse((66 * ls, 56 * ls, 190 * ls, 180 * ls), fill=(156, 112, 255, 220))
    ldraw.ellipse((86 * ls, 48 * ls, 202 * ls, 164 * ls), fill=(18, 11, 38, 255))
    # Crossed shadow blades
    for dx in (-1, 1):
        p_tip = (cx + dx * 68 * ls, cy - 72 * ls)
        p_hilt = (cx - dx * 52 * ls, cy + 62 * ls)
        ldraw.line([p_hilt, p_tip], fill=(142, 92, 255, 190), width=14 * ls)
        ldraw.line([p_hilt, p_tip], fill=BLADE_LIGHT, width=6 * ls)
        gx, gy = cx - dx * 32 * ls, cy + 40 * ls
        ldraw.ellipse((gx - 9 * ls, gy - 9 * ls, gx + 9 * ls, gy + 9 * ls), fill=GOLD_BRIGHT, outline=GOLD_DARK, width=2 * ls)
    # Central diamond star
    ldraw.polygon([(cx, cy - 26 * ls), (cx + 18 * ls, cy), (cx, cy + 26 * ls), (cx - 18 * ls, cy)], fill=EYE_CYAN, outline=BLADE_LIGHT)
    finalize_ss(limg, lw, lh).save(SPRITES_DIR / "ui" / "logo_emblem.png")


def generate_touch_ui() -> None:
    # Virtual joystick base (220x220)
    bw, bh = 220, 220
    img, draw, s = make_ss_canvas(bw, bh, scale=2)
    cx, cy = 110 * s, 110 * s
    draw.ellipse((12 * s, 12 * s, 208 * s, 208 * s), fill=(14, 10, 30, 115), outline=(218, 174, 88, 185), width=3 * s)
    draw.ellipse((28 * s, 28 * s, 192 * s, 192 * s), outline=(146, 104, 255, 125), width=2 * s)
    for i in range(8):
        ang = i * (math.tau / 8.0)
        r1 = 76 * s if i % 2 == 0 else 82 * s
        r2 = 92 * s
        col = (255, 224, 138, 195) if i % 2 == 0 else (150, 112, 255, 145)
        draw.line(
            [(cx + math.cos(ang) * r1, cy + math.sin(ang) * r1), (cx + math.cos(ang) * r2, cy + math.sin(ang) * r2)],
            fill=col,
            width=3 * s if i % 2 == 0 else 2 * s,
        )
    finalize_ss(img, bw, bh).save(SPRITES_DIR / "ui" / "joystick_base.png")

    # Virtual joystick knob (96x96)
    kw, kh = 96, 96
    kimg, kdraw, ks = make_ss_canvas(kw, kh, scale=2)
    kdraw.ellipse((8 * ks, 8 * ks, 88 * ks, 88 * ks), fill=(36, 22, 74, 220), outline=GOLD_BRIGHT, width=3 * ks)
    kdraw.ellipse((22 * ks, 22 * ks, 74 * ks, 74 * ks), fill=(124, 82, 245, 210))
    kdraw.polygon([(48 * ks, 28 * ks), (62 * ks, 48 * ks), (48 * ks, 68 * ks), (34 * ks, 48 * ks)], fill=EYE_CYAN)
    finalize_ss(kimg, kw, kh).save(SPRITES_DIR / "ui" / "joystick_knob.png")

    def make_action_button(filename: str, size: int, bg_col: tuple[int, int, int, int], ring_col: tuple[int, int, int, int], icon_fn) -> None:
        bi, bd, bs = make_ss_canvas(size, size, scale=2)
        pad = 6 * bs
        bd.ellipse((pad, pad, (size - 6) * bs, (size - 6) * bs), fill=bg_col, outline=ring_col, width=4 * bs)
        bd.ellipse((14 * bs, 14 * bs, (size - 14) * bs, (size - 14) * bs), outline=(255, 255, 255, 70), width=2 * bs)
        icon_fn(bd, size, bs)
        finalize_ss(bi, size, size).save(SPRITES_DIR / "ui" / filename)

    # Attack button (128x128) — gleaming katana & crescent arc
    def icon_attack(d: ImageDraw.ImageDraw, sz: int, s: int) -> None:
        d.arc((24 * s, 24 * s, 104 * s, 104 * s), start=-80, end=50, fill=EYE_CYAN, width=5 * s)
        d.line([(36 * s, 90 * s), (92 * s, 34 * s)], fill=BLADE_LIGHT, width=7 * s)
        d.line([(42 * s, 72 * s), (56 * s, 86 * s)], fill=GOLD_BRIGHT, width=5 * s)

    # Jump button (112x112) — winged double upward chevron
    def icon_jump(d: ImageDraw.ImageDraw, sz: int, s: int) -> None:
        c = sz / 2.0
        d.line([((c - 22) * s, (c + 2) * s), (c * s, (c - 20) * s), ((c + 22) * s, (c + 2) * s)], fill=BLADE_LIGHT, width=6 * s)
        d.line([((c - 16) * s, (c + 20) * s), (c * s, (c + 4) * s), ((c + 16) * s, (c + 20) * s)], fill=EYE_CYAN, width=5 * s)

    # Dodge button (112x112) — shadow step double arrow + streaks
    def icon_dodge(d: ImageDraw.ImageDraw, sz: int, s: int) -> None:
        c = sz / 2.0
        for off, al in ((-10, 140), (8, 255)):
            col = (220, 200, 255, al)
            d.line([((c + off - 10) * s, (c - 18) * s), ((c + off + 10) * s, c * s), ((c + off - 10) * s, (c + 18) * s)], fill=col, width=5 * s)
        d.line([((c - 30) * s, c * s), ((c - 12) * s, c * s)], fill=EYE_CYAN, width=4 * s)

    # Mode switch button (112x112) — dimensional rift diamond & orbit ring
    def icon_mode(d: ImageDraw.ImageDraw, sz: int, s: int) -> None:
        c = sz / 2.0
        d.ellipse(((c - 28) * s, (c - 14) * s, (c + 28) * s, (c + 14) * s), outline=GOLD_BRIGHT, width=4 * s)
        d.polygon([(c * s, (c - 22) * s), ((c + 13) * s, c * s), (c * s, (c + 22) * s), ((c - 13) * s, c * s)], fill=EYE_CYAN, outline=BLADE_LIGHT)

    # Block / Guard button (104x104) — crested anime rune shield
    def icon_block(d: ImageDraw.ImageDraw, sz: int, s: int) -> None:
        c = sz / 2.0
        shield = [
            (c * s, (c - 24) * s),
            ((c + 20) * s, (c - 15) * s),
            ((c + 16) * s, (c + 8) * s),
            (c * s, (c + 24) * s),
            ((c - 16) * s, (c + 8) * s),
            ((c - 20) * s, (c - 15) * s),
        ]
        d.polygon(shield, fill=(58, 42, 128, 225), outline=BLADE_LIGHT)
        d.polygon([(c * s, (c - 10) * s), ((c + 8) * s, c * s), (c * s, (c + 11) * s), ((c - 8) * s, c * s)], fill=EYE_CYAN)

    make_action_button("btn_attack.png", 128, (64, 18, 48, 205), SCARF_HIGHLIGHT, icon_attack)
    make_action_button("btn_jump.png", 112, (18, 42, 78, 200), EYE_CYAN, icon_jump)
    make_action_button("btn_dodge.png", 112, (42, 22, 82, 200), INK_RIM, icon_dodge)
    make_action_button("btn_block.png", 104, (28, 30, 86, 205), BLADE_LIGHT, icon_block)
    make_action_button("btn_mode.png", 112, (56, 38, 18, 205), GOLD_BRIGHT, icon_mode)


def generate_environment() -> None:
    rng = random.Random(4207)

    # 1. Twilight sky (1280x720)
    sw, sh = 1280, 720
    sky = Image.new("RGBA", (sw, sh))
    sdraw = ImageDraw.Draw(sky, "RGBA")
    top_c = (11, 8, 28)
    mid_c = (34, 18, 66)
    bot_c = (88, 38, 92)
    for y in range(sh):
        t = y / (sh - 1)
        if t < 0.6:
            k = t / 0.6
            r = int(top_c[0] + (mid_c[0] - top_c[0]) * k)
            g = int(top_c[1] + (mid_c[1] - top_c[1]) * k)
            b = int(top_c[2] + (mid_c[2] - top_c[2]) * k)
        else:
            k = (t - 0.6) / 0.4
            r = int(mid_c[0] + (bot_c[0] - mid_c[0]) * k)
            g = int(mid_c[1] + (bot_c[1] - mid_c[1]) * k)
            b = int(mid_c[2] + (bot_c[2] - mid_c[2]) * k)
        sdraw.line([(0, y), (sw, y)], fill=(r, g, b, 255))

    # Stars
    for _ in range(140):
        sx = rng.randint(0, sw - 1)
        sy = rng.randint(0, int(sh * 0.68))
        sr = rng.choice([1, 1, 1, 2])
        sa = rng.randint(90, 235)
        sdraw.ellipse((sx - sr, sy - sr, sx + sr, sy + sr), fill=(230, 225, 255, sa))

    # Giant anime eclipsed crescent moon + soft glow
    glow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow, "RGBA")
    mx, my, mr = 940, 178, 92
    gdraw.ellipse((mx - mr - 46, my - mr - 46, mx + mr + 46, my + mr + 46), fill=(156, 102, 255, 80))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=24))
    sky = Image.alpha_composite(sky, glow)
    sdraw = ImageDraw.Draw(sky, "RGBA")
    sdraw.ellipse((mx - mr, my - mr, mx + mr, my + mr), fill=(228, 212, 255, 235))
    sdraw.ellipse((mx - mr + 28, my - mr - 12, mx + mr + 28, my + mr - 12), fill=(24, 14, 50, 255))
    sky.save(SPRITES_DIR / "environment" / "bg_twilight_sky.png")

    # 2. Parallax distant peaks (1280x512, horizontally seamless at edges y=320)
    pw, ph = 1280, 512
    peaks = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(peaks, "RGBA")
    ridge_far = [(0, 320), (110, 220), (230, 275), (380, 150), (520, 255), (670, 185), (820, 260), (960, 140), (1120, 240), (1280, 320), (1280, ph), (0, ph)]
    pdraw.polygon(ridge_far, fill=(28, 17, 56, 230))
    ridge_near = [(0, 380), (150, 295), (290, 350), (470, 250), (630, 340), (790, 275), (970, 345), (1140, 285), (1280, 380), (1280, ph), (0, ph)]
    pdraw.polygon(ridge_near, fill=(20, 13, 42, 255))
    # Floating anime ruin spires
    for fx, fy, fw, fh_s in ((380, 95, 22, 46), (955, 82, 26, 52), (680, 128, 18, 36)):
        pdraw.polygon([(fx, fy - fh_s), (fx + fw, fy), (fx, fy + fh_s * 0.7), (fx - fw, fy)], fill=(36, 22, 72, 240), outline=(146, 108, 255, 150))
        pdraw.ellipse((fx - 3, fy - 3, fx + 3, fy + 3), fill=EYE_CYAN)
    peaks.save(SPRITES_DIR / "environment" / "bg_distant_peaks.png")

    # 3. Parallax ruined gothic arches (1280x512, seamless)
    arches = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    adraw = ImageDraw.Draw(arches, "RGBA")
    adraw.rectangle((0, 440, pw, ph), fill=(15, 10, 32, 255))
    for ax in (120, 440, 760, 1080):
        # Twin pillars & pointed arch hint
        adraw.rectangle((ax - 58, 250, ax - 34, 445), fill=(18, 12, 38, 245))
        adraw.rectangle((ax + 34, 270, ax + 58, 445), fill=(18, 12, 38, 245))
        adraw.arc((ax - 58, 200, ax + 58, 330), start=180, end=360, fill=(24, 16, 48, 245), width=16)
        # Hanging lantern pinpoint
        adraw.line([(ax, 212), (ax, 252)], fill=(90, 70, 130, 200), width=2)
        adraw.ellipse((ax - 12, 246, ax + 12, 270), fill=(255, 198, 92, 65))
        adraw.ellipse((ax - 4, 254, ax + 4, 262), fill=GOLD_BRIGHT)
    arches.save(SPRITES_DIR / "environment" / "bg_ruined_arches.png")

    # 4. Fantasy rune stone platform tile (256x64, horizontally tileable)
    tw, th = 256, 64
    plat = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    td = ImageDraw.Draw(plat, "RGBA")
    td.rectangle((0, 0, tw, th), fill=(28, 22, 52, 255))
    td.rectangle((0, 44, tw, th), fill=(18, 13, 36, 255))
    # Top glowing twilight turf / gilded bevel
    td.rectangle((0, 0, tw, 10), fill=(58, 44, 108, 255))
    td.line([(0, 1), (tw, 1)], fill=(156, 226, 255, 220), width=2)
    td.line([(0, 11), (tw, 11)], fill=(214, 164, 72, 190), width=2)
    # Stone brick joints
    for bx in (0, 64, 128, 192):
        td.line([(bx, 12), (bx, 42)], fill=(16, 12, 32, 220), width=2)
        # Glowing rune glyph in center of alternate bricks
        if bx in (0, 128):
            rx = bx + 32
            td.polygon([(rx, 20), (rx + 7, 27), (rx, 34), (rx - 7, 27)], outline=(126, 224, 255, 165))
    plat.save(SPRITES_DIR / "environment" / "platform_stone.png")

    # 5. Top-Down Sanctum stone courtyard floor (256x256, seamless tile)
    fw, fh = 256, 256
    floor = Image.new("RGBA", (fw, fh), (30, 24, 54, 255))
    fd = ImageDraw.Draw(floor, "RGBA")
    tile = 64
    for gy in range(0, fh, tile):
        offset = 32 if (gy // tile) % 2 == 1 else 0
        for gx in range(-32, fw, tile):
            shade = rng.randint(-5, 6)
            col = (32 + shade, 26 + shade, 58 + shade, 255)
            fd.rectangle((gx + offset + 2, gy + 2, gx + offset + tile - 2, gy + tile - 2), fill=col, outline=(44, 36, 78, 255))
        fd.line([(0, gy), (fw, gy)], fill=(18, 14, 34, 255), width=2)
    # Subtle rune accent on two tiles
    for rx, ry in ((96, 32), (192, 160)):
        fd.polygon([(rx, ry - 9), (rx + 9, ry), (rx, ry + 9), (rx - 9, ry)], outline=(122, 92, 218, 115))
    floor.save(SPRITES_DIR / "environment" / "topdown_sanctum_floor.png")

    # 6. Top-Down Sanctum wall block (128x128)
    ww, wh = 128, 128
    wall = Image.new("RGBA", (ww, wh), (20, 15, 40, 255))
    wd = ImageDraw.Draw(wall, "RGBA")
    wd.rectangle((3, 3, ww - 4, wh - 24), fill=(38, 28, 72, 255), outline=GOLD_MID, width=2)
    wd.rectangle((14, 14, ww - 15, wh - 36), fill=(28, 20, 56, 255), outline=(136, 98, 242, 160), width=2)
    wd.polygon([(64, 32), (78, 52), (64, 72), (50, 52)], outline=EYE_CYAN)
    # South-facing 3/4 vertical wall face for depth
    wd.rectangle((0, wh - 22, ww, wh), fill=(15, 11, 30, 255))
    wd.line([(0, wh - 22), (ww, wh - 22)], fill=GOLD_BRIGHT, width=2)
    wall.save(SPRITES_DIR / "environment" / "topdown_wall_tile.png")

    # 7. Top-Down Central Magic Rune Circle (384x384)
    rc_sz = 384
    rc, rcd, rcs = make_ss_canvas(rc_sz, rc_sz, scale=2)
    cc = (rc_sz // 2) * rcs
    rcd.ellipse((24 * rcs, 24 * rcs, 360 * rcs, 360 * rcs), fill=(62, 34, 124, 52), outline=(156, 112, 255, 175), width=3 * rcs)
    rcd.ellipse((44 * rcs, 44 * rcs, 340 * rcs, 340 * rcs), outline=(255, 220, 132, 150), width=2 * rcs)
    rcd.ellipse((108 * rcs, 108 * rcs, 276 * rcs, 276 * rcs), outline=(96, 238, 255, 155), width=2 * rcs)
    # Two interlocked squares (8-point star)
    for base_ang in (0.0, math.pi / 4.0):
        pts = [(cc + math.cos(base_ang + i * math.pi / 2.0) * 144 * rcs, cc + math.sin(base_ang + i * math.pi / 2.0) * 144 * rcs) for i in range(4)]
        rcd.polygon(pts, outline=(168, 128, 255, 150))
    finalize_ss(rc, rc_sz, rc_sz).save(SPRITES_DIR / "environment" / "topdown_rune_circle.png")

    # 8. Shadow Rift Gate sprite sheet (4 frames of 128x160 = 512x160)
    gw, gh = 128, 160
    gimg, gdraw, gs = make_ss_canvas(gw * 4, gh, scale=2)
    for f in range(4):
        ox = f * gw
        phase = (f / 4.0) * math.tau
        pulse = math.sin(phase) * 4.0
        # Glowing portal vortex
        gdraw.ellipse(((ox + 26 - pulse) * gs, (26 - pulse) * gs, (ox + 102 + pulse) * gs, (144 + pulse) * gs), fill=(116, 62, 245, 95))
        gdraw.ellipse(((ox + 36) * gs, 38 * gs, (ox + 92) * gs, 138 * gs), fill=(68, 32, 168, 220), outline=EYE_CYAN, width=3 * gs)
        gdraw.ellipse(((ox + 48) * gs, 56 * gs, (ox + 80) * gs, 122 * gs), fill=(156, 238, 255, 210))
        # Swirling energy arc
        gdraw.arc(((ox + 40) * gs, 44 * gs, (ox + 88) * gs, 132 * gs), start=int(f * 90), end=int(f * 90 + 200), fill=GOLD_BRIGHT, width=3 * gs)
        # Ornate stone archway pillars + plinth
        gdraw.rectangle(((ox + 18) * gs, 42 * gs, (ox + 34) * gs, 152 * gs), fill=(32, 24, 62, 255), outline=GOLD_MID, width=2 * gs)
        gdraw.rectangle(((ox + 94) * gs, 42 * gs, (ox + 110) * gs, 152 * gs), fill=(32, 24, 62, 255), outline=GOLD_MID, width=2 * gs)
        gdraw.polygon([((ox + 22) * gs, 42 * gs), ((ox + 64) * gs, 14 * gs), ((ox + 106) * gs, 42 * gs), ((ox + 92) * gs, 48 * gs), ((ox + 64) * gs, 28 * gs), ((ox + 36) * gs, 48 * gs)], fill=(42, 30, 82, 255), outline=GOLD_BRIGHT)
        gdraw.rectangle(((ox + 12) * gs, 146 * gs, (ox + 116) * gs, 158 * gs), fill=(26, 18, 48, 255), outline=GOLD_MID, width=2 * gs)
    finalize_ss(gimg, gw * 4, gh).save(SPRITES_DIR / "environment" / "rift_gate_sheet.png")

    # 9. Mana Lantern prop (64x128)
    ml, mld, mls = make_ss_canvas(64, 128, scale=2)
    mld.ellipse((8 * mls, 12 * mls, 56 * mls, 60 * mls), fill=(255, 212, 112, 75))
    mld.rectangle((29 * mls, 48 * mls, 35 * mls, 122 * mls), fill=(28, 22, 48, 255), outline=(92, 74, 142, 255))
    mld.rectangle((20 * mls, 118 * mls, 44 * mls, 126 * mls), fill=(38, 28, 66, 255), outline=GOLD_MID)
    mld.polygon([(32 * mls, 18 * mls), (44 * mls, 36 * mls), (32 * mls, 52 * mls), (20 * mls, 36 * mls)], fill=GOLD_BRIGHT, outline=BLADE_LIGHT)
    finalize_ss(ml, 64, 128).save(SPRITES_DIR / "environment" / "mana_lantern.png")

    # 10. Guild Training Totem (96x128)
    tt, ttd, tts = make_ss_canvas(96, 128, scale=2)
    ttd.ellipse((24 * tts, 112 * tts, 72 * tts, 124 * tts), fill=(10, 6, 22, 140))
    ttd.rectangle((42 * tts, 28 * tts, 54 * tts, 118 * tts), fill=(76, 52, 42, 255), outline=INK_DARK, width=2 * tts)
    ttd.rectangle((18 * tts, 52 * tts, 78 * tts, 62 * tts), fill=(86, 60, 48, 255), outline=INK_DARK, width=2 * tts)
    ttd.rounded_rectangle((30 * tts, 38 * tts, 66 * tts, 88 * tts), radius=8 * tts, fill=(44, 34, 72, 255), outline=GOLD_MID, width=2 * tts)
    ttd.rectangle((30 * tts, 54 * tts, 66 * tts, 64 * tts), fill=SCARF_MAIN)
    ttd.ellipse((35 * tts, 16 * tts, 61 * tts, 42 * tts), fill=(52, 40, 84, 255), outline=GOLD_MID, width=2 * tts)
    ttd.polygon([(48 * tts, 68 * tts), (56 * tts, 76 * tts), (48 * tts, 84 * tts), (40 * tts, 76 * tts)], fill=EYE_CYAN)
    finalize_ss(tt, 96, 128).save(SPRITES_DIR / "environment" / "training_totem.png")

    # 11. One-Way Rune Skybridge tile (256x32, horizontally tileable)
    ob = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
    obd = ImageDraw.Draw(ob, "RGBA")
    obd.rectangle((0, 0, 256, 14), fill=(52, 36, 96, 245))
    obd.line([(0, 1), (256, 1)], fill=EYE_CYAN, width=2)
    obd.line([(0, 13), (256, 13)], fill=GOLD_BRIGHT, width=2)
    for px in (16, 80, 144, 208):
        obd.polygon([(px, 14), (px + 32, 14), (px + 24, 26), (px + 8, 26)], fill=(34, 24, 66, 225), outline=GOLD_MID)
        obd.ellipse((px + 13, 5, px + 19, 11), fill=EYE_CYAN)
    ob.save(SPRITES_DIR / "environment" / "oneway_bridge.png")

    # 12. Ancient Lore Runestone tablet (80x120)
    lr, lrd, lrs = make_ss_canvas(80, 120, scale=2)
    lrd.ellipse((14 * lrs, 104 * lrs, 66 * lrs, 116 * lrs), fill=(8, 5, 18, 140))
    stone_poly = [
        (40 * lrs, 12 * lrs),
        (62 * lrs, 32 * lrs),
        (58 * lrs, 108 * lrs),
        (22 * lrs, 108 * lrs),
        (18 * lrs, 32 * lrs),
    ]
    lrd.polygon(stone_poly, fill=(36, 26, 68, 255), outline=GOLD_MID)
    lrd.rectangle((14 * lrs, 102 * lrs, 66 * lrs, 112 * lrs), fill=(26, 18, 48, 255), outline=GOLD_BRIGHT, width=2 * lrs)
    # Glowing carved cyan rune crest + inscription lines
    lrd.polygon([(40 * lrs, 28 * lrs), (50 * lrs, 44 * lrs), (40 * lrs, 60 * lrs), (30 * lrs, 44 * lrs)], fill=AURA_VIOLET, outline=EYE_CYAN)
    for ry in (70, 80, 90):
        lrd.line([(28 * lrs, ry * lrs), (52 * lrs, ry * lrs)], fill=EYE_CYAN, width=2 * lrs)
    finalize_ss(lr, 80, 120).save(SPRITES_DIR / "environment" / "lore_runestone.png")


def main() -> None:
    from generate_enemy_art import generate_all_enemy_art
    from generate_inventory_icons import main as generate_inventory_icons

    for sub in ("player", "environment", "ui", "enemies", "items"):
        (SPRITES_DIR / sub).mkdir(parents=True, exist_ok=True)
    generate_sidescroll_sheet()
    generate_topdown_sheet()
    generate_portrait_and_logo()
    generate_touch_ui()
    generate_environment()
    generate_all_enemy_art()
    generate_inventory_icons()
    print("Generated all SHADOWBOUND original art assets (player, UI, environment, enemies, boss).")


if __name__ == "__main__":
    main()
