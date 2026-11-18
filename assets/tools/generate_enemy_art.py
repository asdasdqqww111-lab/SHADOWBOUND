#!/usr/bin/env python3
"""
SHADOWBOUND — Phase 3 Original Anime Fantasy Enemy & Multi-Phase Boss Art Generator.

Produces 100% original, clean-licensed (CC0 1.0) RGBA PNG sheets sharing the
Twilight Obsidian + Shadow Violet + Royal Gold + Crimson + Soul Cyan palette:
  1. assets/sprites/enemies/umbral_hound_sheet.png       (512x512, 4x4 of 128x128)
  2. assets/sprites/enemies/rift_wisp_sheet.png          (512x512, 4x4 of 128x128)
  3. assets/sprites/enemies/obsidian_sentinel_sheet.png  (512x512, 4x4 of 128x128)
  4. assets/sprites/enemies/eclipse_warden_boss_sheet.png (640x640, 4x4 of 160x160)
  5. assets/sprites/enemies/shadow_orb.png               (64x64)
"""

from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ENEMIES_DIR = ROOT / "assets" / "sprites" / "enemies"

INK_DARK = (14, 11, 26, 255)
INK_RIM = (148, 112, 255, 235)
BODY_CORE = (22, 17, 40, 255)
ARMOR_MID = (42, 30, 74, 255)
SCARF_MAIN = (228, 54, 98, 255)
SCARF_BRIGHT = (255, 112, 148, 255)
SCARF_DARK = (144, 24, 62, 255)
EYE_CYAN = (96, 238, 255, 255)
AURA_VIOLET = (142, 96, 255, 225)
GOLD_BRIGHT = (255, 224, 138, 255)
GOLD_MID = (214, 158, 62, 255)
BLADE_LIGHT = (232, 224, 255, 255)


def make_ss(w: int, h: int, scale: int = 2) -> tuple[Image.Image, ImageDraw.ImageDraw, int]:
    img = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img, "RGBA"), scale


def finish_ss(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def limb(
    draw: ImageDraw.ImageDraw,
    p1: tuple[float, float],
    p2: tuple[float, float],
    width: int,
    color: tuple[int, int, int, int],
    rim: tuple[int, int, int, int] = INK_RIM,
) -> None:
    draw.line([p1, p2], fill=rim, width=width + 3)
    draw.line([p1, p2], fill=color, width=width)
    r = width * 0.48
    for px, py in (p1, p2):
        draw.ellipse((px - r, py - r, px + r, py + r), fill=color)


def _draw_hound_frame(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    s: int,
    stride: float,
    bob: float,
    lunging: int = -1,
    hurt: bool = False,
) -> None:
    def pt(x: float, y: float) -> tuple[float, float]:
        return ((ox + x) * s, (oy + y) * s)

    body = (92, 28, 56, 255) if hurt else BODY_CORE
    rim = SCARF_BRIGHT if hurt else INK_RIM
    shift_x = 10.0 if lunging in (1, 2) else (-4.0 if hurt else 0.0)
    lift_y = -8.0 if lunging in (1, 2) else bob

    # Ground shadow (foot anchor at y=112)
    draw.ellipse((pt(28, 106), pt(98, 118)), fill=(8, 5, 18, 135))

    # Jagged shadow tail flame
    draw.polygon(
        [
            pt(34 + shift_x, 78 + lift_y),
            pt(12 + shift_x, 62 + lift_y + stride * 5),
            pt(20 + shift_x, 76 + lift_y),
            pt(10 + shift_x, 78 + lift_y - stride * 4),
            pt(32 + shift_x, 86 + lift_y),
        ],
        fill=AURA_VIOLET,
        outline=SCARF_MAIN,
    )

    # Four beast legs (default facing RIGHT +X)
    bl_x = 38 + shift_x - stride * 11
    br_x = 46 + shift_x + stride * 9
    fl_x = 76 + shift_x + stride * 12
    fr_x = 84 + shift_x - stride * 10
    foot_y = 104 if lunging in (1, 2) else 112
    limb(draw, pt(40 + shift_x, 84 + lift_y), pt(bl_x, foot_y), int(4.5 * s), body, rim)
    limb(draw, pt(76 + shift_x, 82 + lift_y), pt(fl_x, foot_y), int(4.5 * s), body, rim)

    # Lithe lupine torso
    draw.polygon(
        [
            pt(34 + shift_x, 78 + lift_y),
            pt(58 + shift_x, 68 + lift_y),
            pt(84 + shift_x, 70 + lift_y),
            pt(80 + shift_x, 88 + lift_y),
            pt(38 + shift_x, 90 + lift_y),
        ],
        fill=body,
        outline=rim,
    )
    # Spiky crimson shadow mane
    for mx, mh in ((52, 16), (62, 20), (72, 15)):
        draw.polygon(
            [
                pt(mx - 6 + shift_x, 72 + lift_y),
                pt(mx - 2 + shift_x, 70 - mh + lift_y),
                pt(mx + 7 + shift_x, 72 + lift_y),
            ],
            fill=SCARF_MAIN,
            outline=SCARF_BRIGHT,
        )

    limb(draw, pt(44 + shift_x, 85 + lift_y), pt(br_x, foot_y), int(5.0 * s), body, rim)
    limb(draw, pt(80 + shift_x, 83 + lift_y), pt(fr_x, foot_y), int(5.0 * s), body, rim)

    # Wolf head, ears & glowing eye
    draw.polygon(
        [
            pt(76 + shift_x, 60 + lift_y),
            pt(98 + shift_x, 62 + lift_y),
            pt(108 + shift_x, 72 + lift_y),
            pt(92 + shift_x, 80 + lift_y),
            pt(76 + shift_x, 76 + lift_y),
        ],
        fill=body,
        outline=rim,
    )
    draw.polygon(
        [pt(78 + shift_x, 62 + lift_y), pt(74 + shift_x, 44 + lift_y), pt(88 + shift_x, 60 + lift_y)],
        fill=INK_DARK,
        outline=rim,
    )
    draw.polygon(
        [pt(88 + shift_x, 66 + lift_y), pt(98 + shift_x, 67 + lift_y), pt(92 + shift_x, 72 + lift_y)],
        fill=SCARF_BRIGHT if lunging >= 0 else EYE_CYAN,
    )

    # Claw slash arcs on attack frames 1 & 2
    if lunging in (1, 2):
        for off in (-8, 0, 8):
            draw.arc(
                (pt(74, 38 + off), pt(124, 102 + off)),
                start=-55,
                end=52,
                fill=SCARF_BRIGHT if off == 0 else AURA_VIOLET,
                width=int(3.5 * s),
            )
    if hurt:
        draw.ellipse((pt(54, 56), pt(74, 76)), outline=GOLD_BRIGHT, width=int(2.5 * s))


def generate_umbral_hound() -> None:
    cell = 128
    w, h = cell * 4, cell * 4
    img, draw, s = make_ss(w, h, 2)
    for f in range(4):
        ph = (f / 4.0) * math.tau
        _draw_hound_frame(draw, f * cell, 0, s, stride=0.15 * math.sin(ph), bob=math.sin(ph) * 2.0)
        _draw_hound_frame(draw, f * cell, cell, s, stride=math.sin(ph), bob=-abs(math.sin(ph)) * 4.5)
        _draw_hound_frame(draw, f * cell, 2 * cell, s, stride=0.85, bob=-2.0, lunging=f)
    for f in range(2):
        _draw_hound_frame(draw, f * cell, 3 * cell, s, stride=-0.3, bob=2.0 * f, hurt=True)
    finish_ss(img, w, h).save(ENEMIES_DIR / "umbral_hound_sheet.png")


def _draw_wisp_frame(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    s: int,
    phase: float,
    casting: int = -1,
    hurt: bool = False,
) -> None:
    def pt(x: float, y: float) -> tuple[float, float]:
        return ((ox + x) * s, (oy + y) * s)

    hover = math.sin(phase) * 5.0
    # Ground shadow below hovering caster
    draw.ellipse((pt(42, 106), pt(86, 116)), fill=(10, 6, 22, 115))

    # Outer rotating golden arcane ring
    ring_r = 34.0 + (5.0 if casting in (1, 2) else 0.0)
    draw.ellipse(
        (pt(64 - ring_r, 60 + hover - ring_r), pt(64 + ring_r, 60 + hover + ring_r)),
        outline=SCARF_BRIGHT if hurt else (EYE_CYAN if casting in (1, 2) else GOLD_MID),
        width=int(2.4 * s),
    )
    # Orbiting rune motes
    for i in range(3):
        ang = phase + i * (math.tau / 3.0)
        mx = 64 + math.cos(ang) * ring_r
        my = 60 + hover + math.sin(ang) * ring_r
        draw.ellipse((pt(mx - 4, my - 4), pt(mx + 4, my + 4)), fill=EYE_CYAN, outline=BLADE_LIGHT)

    # Tattered floating shadow cloak
    cloak = (92, 30, 64, 245) if hurt else (30, 20, 62, 245)
    sway = math.sin(phase) * 4.0
    draw.polygon(
        [
            pt(64, 24 + hover),
            pt(84, 52 + hover),
            pt(88 + sway, 94 + hover),
            pt(72, 84 + hover),
            pt(64 + sway * 0.5, 98 + hover),
            pt(54, 84 + hover),
            pt(40 - sway, 94 + hover),
            pt(44, 52 + hover),
        ],
        fill=cloak,
        outline=INK_RIM,
    )
    # Hooded void face + twin luminous cyan eyes
    draw.ellipse((pt(50, 32 + hover), pt(78, 58 + hover)), fill=INK_DARK, outline=GOLD_BRIGHT, width=int(2 * s))
    draw.ellipse((pt(56, 43 + hover), pt(63, 48 + hover)), fill=EYE_CYAN)
    draw.ellipse((pt(67, 43 + hover), pt(74, 48 + hover)), fill=EYE_CYAN)

    # Casting spell burst in front (+X)
    if casting >= 0:
        orb_r = 6 + casting * 3.5 if casting < 3 else 5
        draw.ellipse(
            (pt(92 - orb_r, 58 + hover - orb_r), pt(92 + orb_r, 58 + hover + orb_r)),
            fill=AURA_VIOLET,
            outline=EYE_CYAN,
            width=int(2.5 * s),
        )
        draw.ellipse(
            (pt(92 - orb_r * 0.45, 58 + hover - orb_r * 0.45), pt(92 + orb_r * 0.45, 58 + hover + orb_r * 0.45)),
            fill=BLADE_LIGHT,
        )


def generate_rift_wisp() -> None:
    cell = 128
    w, h = cell * 4, cell * 4
    img, draw, s = make_ss(w, h, 2)
    for f in range(4):
        ph = (f / 4.0) * math.tau
        _draw_wisp_frame(draw, f * cell, 0, s, phase=ph)
        _draw_wisp_frame(draw, f * cell, cell, s, phase=ph + 0.6)
        _draw_wisp_frame(draw, f * cell, 2 * cell, s, phase=ph, casting=f)
    for f in range(2):
        _draw_wisp_frame(draw, f * cell, 3 * cell, s, phase=f * 1.2, hurt=True)
    finish_ss(img, w, h).save(ENEMIES_DIR / "rift_wisp_sheet.png")


def _draw_sentinel_frame(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    s: int,
    stride: float,
    bob: float,
    slam: int = -1,
    hurt: bool = False,
) -> None:
    def pt(x: float, y: float) -> tuple[float, float]:
        return ((ox + x) * s, (oy + y) * s)

    armor = (96, 34, 62, 255) if hurt else ARMOR_MID
    rim = SCARF_BRIGHT if hurt else GOLD_MID

    # Ground shadow (foot anchor y=114)
    draw.ellipse((pt(32, 107), pt(94, 119)), fill=(8, 5, 18, 145))

    # Crimson knight cape
    draw.polygon(
        [pt(52, 46 + bob), pt(30 - stride * 4, 98 + bob), pt(50, 94 + bob)],
        fill=SCARF_DARK,
        outline=SCARF_MAIN,
    )

    # Heavy stickman greaves
    limb(draw, pt(54, 82 + bob), pt(48 - stride * 9, 113), int(6.5 * s), INK_DARK, rim)
    limb(draw, pt(68, 82 + bob), pt(74 + stride * 9, 113), int(6.5 * s), INK_DARK, rim)

    # Armored cuirass & pauldrons
    draw.polygon(
        [pt(46, 48 + bob), pt(76, 48 + bob), pt(72, 84 + bob), pt(50, 84 + bob)],
        fill=armor,
        outline=GOLD_BRIGHT,
    )
    draw.ellipse((pt(38, 44 + bob), pt(56, 60 + bob)), fill=INK_DARK, outline=GOLD_BRIGHT, width=int(2 * s))
    draw.ellipse((pt(66, 44 + bob), pt(84, 60 + bob)), fill=INK_DARK, outline=GOLD_BRIGHT, width=int(2 * s))

    # Horned helm + crimson plume + glowing golden visor
    draw.polygon([pt(52, 22 + bob), pt(34, 12 + bob), pt(48, 30 + bob)], fill=SCARF_MAIN, outline=SCARF_BRIGHT)
    draw.ellipse((pt(48, 22 + bob), pt(74, 48 + bob)), fill=INK_DARK, outline=GOLD_BRIGHT, width=int(2.2 * s))
    draw.line([pt(58, 35 + bob), pt(72, 35 + bob)], fill=GOLD_BRIGHT, width=int(3.2 * s))

    # Shadow-violet halberd
    if slam in (1, 2):
        limb(draw, pt(52, 58 + bob), pt(112, 68 + bob), int(4.0 * s), GOLD_MID, INK_DARK)
        draw.polygon(
            [pt(98, 44 + bob), pt(122, 68 + bob), pt(96, 88 + bob), pt(104, 68 + bob)],
            fill=AURA_VIOLET,
            outline=BLADE_LIGHT,
        )
        draw.arc(
            (pt(58, 16), pt(126, 114)),
            start=-68,
            end=62,
            fill=GOLD_BRIGHT if slam == 2 else AURA_VIOLET,
            width=int(7.0 * s),
        )
    else:
        limb(draw, pt(48, 92 + bob), pt(54, 14 + bob), int(3.8 * s), GOLD_MID, INK_DARK)
        draw.polygon(
            [pt(54, 12 + bob), pt(72, 22 + bob), pt(54, 34 + bob)],
            fill=AURA_VIOLET,
            outline=BLADE_LIGHT,
        )

    # Gilded Obsidian Tower Shield (in front on +X when not wide-open slamming)
    sx = 70 if slam in (1, 2) else 76
    draw.polygon(
        [
            pt(sx, 48 + bob),
            pt(sx + 20, 52 + bob),
            pt(sx + 18, 88 + bob),
            pt(sx + 9, 100 + bob),
            pt(sx - 2, 88 + bob),
        ],
        fill=(24, 18, 48, 255),
        outline=GOLD_BRIGHT,
    )
    draw.polygon(
        [pt(sx + 9, 60 + bob), pt(sx + 15, 72 + bob), pt(sx + 9, 84 + bob), pt(sx + 3, 72 + bob)],
        fill=EYE_CYAN,
    )


def generate_obsidian_sentinel() -> None:
    cell = 128
    w, h = cell * 4, cell * 4
    img, draw, s = make_ss(w, h, 2)
    for f in range(4):
        ph = (f / 4.0) * math.tau
        _draw_sentinel_frame(draw, f * cell, 0, s, stride=0.0, bob=math.sin(ph) * 1.5)
        _draw_sentinel_frame(draw, f * cell, cell, s, stride=math.sin(ph), bob=-abs(math.sin(ph)) * 2.5)
        _draw_sentinel_frame(draw, f * cell, 2 * cell, s, stride=0.5, bob=-1.0, slam=f)
    for f in range(2):
        _draw_sentinel_frame(draw, f * cell, 3 * cell, s, stride=-0.2, bob=1.5, hurt=True)
    finish_ss(img, w, h).save(ENEMIES_DIR / "obsidian_sentinel_sheet.png")


def _draw_boss_frame(
    draw: ImageDraw.ImageDraw,
    ox: int,
    oy: int,
    s: int,
    phase: float,
    stride: float = 0.0,
    attack_f: int = -1,
    roar_f: int = -1,
) -> None:
    def pt(x: float, y: float) -> tuple[float, float]:
        return ((ox + x) * s, (oy + y) * s)

    bob = math.sin(phase) * 2.5 - (5.0 if roar_f >= 0 else 0.0)

    # Grand ground shadow (foot anchor y=144 inside 160x160 cell)
    draw.ellipse((pt(38, 134), pt(122, 150)), fill=(8, 4, 18, 165))

    # Phase shift shockwave ring
    if roar_f >= 0:
        rr = 32 + roar_f * 13
        draw.ellipse(
            (pt(80 - rr, 82 - rr), pt(80 + rr, 82 + rr)),
            outline=GOLD_BRIGHT if roar_f % 2 == 0 else SCARF_BRIGHT,
            width=int(5.5 * s),
        )

    # Fractured Golden Eclipse Halo behind boss shoulders
    draw.ellipse((pt(44, 14 + bob), pt(116, 86 + bob)), outline=GOLD_BRIGHT, width=int(4.2 * s))
    draw.ellipse((pt(50, 20 + bob), pt(110, 80 + bob)), outline=AURA_VIOLET, width=int(2.2 * s))

    # Flowing Royal Crimson-Violet Warlord Mantle
    sway = math.sin(phase) * 6.0
    draw.polygon(
        [
            pt(54, 58 + bob),
            pt(106, 58 + bob),
            pt(118 + sway, 132 + bob),
            pt(94, 122 + bob),
            pt(80, 136 + bob),
            pt(64, 122 + bob),
            pt(40 - sway, 132 + bob),
        ],
        fill=SCARF_DARK,
        outline=SCARF_MAIN,
    )

    # Towering stickman warlord legs & torso
    limb(draw, pt(70, 102 + bob), pt(62 - stride * 12, 142), int(7.2 * s), INK_DARK, INK_RIM)
    limb(draw, pt(90, 102 + bob), pt(98 + stride * 12, 142), int(7.2 * s), INK_DARK, INK_RIM)
    draw.polygon(
        [pt(58, 58 + bob), pt(102, 58 + bob), pt(94, 104 + bob), pt(66, 104 + bob)],
        fill=INK_DARK,
        outline=GOLD_BRIGHT,
    )
    # Glowing Eclipse Core gem on chest
    draw.polygon(
        [pt(80, 68 + bob), pt(89, 80 + bob), pt(80, 92 + bob), pt(71, 80 + bob)],
        fill=SCARF_MAIN if roar_f >= 0 else EYE_CYAN,
        outline=GOLD_BRIGHT,
    )

    # Twin-horned obsidian crown head + blazing anime eyes
    draw.polygon([pt(66, 36 + bob), pt(50, 12 + bob), pt(74, 30 + bob)], fill=INK_DARK, outline=GOLD_BRIGHT)
    draw.polygon([pt(94, 36 + bob), pt(110, 12 + bob), pt(86, 30 + bob)], fill=INK_DARK, outline=GOLD_BRIGHT)
    draw.ellipse((pt(63, 28 + bob), pt(97, 62 + bob)), fill=INK_DARK, outline=INK_RIM, width=int(2.6 * s))
    draw.polygon([pt(69, 44 + bob), pt(78, 46 + bob), pt(72, 50 + bob)], fill=EYE_CYAN)
    draw.polygon([pt(91, 44 + bob), pt(82, 46 + bob), pt(88, 50 + bob)], fill=GOLD_BRIGHT)

    # Colossal Eclipse Greatsword
    if attack_f in (1, 2):
        draw.polygon(
            [pt(92, 74 + bob), pt(152, 62 + bob), pt(156, 74 + bob), pt(92, 86 + bob)],
            fill=AURA_VIOLET,
            outline=BLADE_LIGHT,
        )
        draw.arc(
            (pt(54, 12), pt(156, 146)),
            start=-75,
            end=72,
            fill=SCARF_BRIGHT if attack_f == 2 else GOLD_BRIGHT,
            width=int(9.5 * s),
        )
        draw.arc(
            (pt(62, 20), pt(150, 138)),
            start=-62,
            end=60,
            fill=BLADE_LIGHT,
            width=int(4.0 * s),
        )
    else:
        draw.polygon(
            [pt(104, 78 + bob), pt(134, 20 + bob), pt(142, 26 + bob), pt(112, 84 + bob)],
            fill=ARMOR_MID,
            outline=GOLD_BRIGHT,
        )
        draw.line([pt(108, 80 + bob), pt(137, 24 + bob)], fill=AURA_VIOLET, width=int(3.2 * s))


def generate_eclipse_warden_boss() -> None:
    cell = 160
    w, h = cell * 4, cell * 4
    img, draw, s = make_ss(w, h, 2)
    for f in range(4):
        ph = (f / 4.0) * math.tau
        _draw_boss_frame(draw, f * cell, 0, s, phase=ph)
        _draw_boss_frame(draw, f * cell, cell, s, phase=ph, stride=math.sin(ph))
        _draw_boss_frame(draw, f * cell, 2 * cell, s, phase=ph, stride=0.6, attack_f=f)
        _draw_boss_frame(draw, f * cell, 3 * cell, s, phase=ph, roar_f=f)
    finish_ss(img, w, h).save(ENEMIES_DIR / "eclipse_warden_boss_sheet.png")


def generate_shadow_orb() -> None:
    img, draw, s = make_ss(64, 64, 2)
    draw.ellipse((6 * s, 6 * s, 58 * s, 58 * s), fill=(142, 76, 255, 95))
    draw.ellipse((13 * s, 13 * s, 51 * s, 51 * s), fill=(168, 62, 224, 220), outline=SCARF_BRIGHT, width=3 * s)
    draw.ellipse((21 * s, 21 * s, 43 * s, 43 * s), fill=EYE_CYAN, outline=BLADE_LIGHT, width=2 * s)
    draw.ellipse((26 * s, 26 * s, 38 * s, 38 * s), fill=BLADE_LIGHT)
    finish_ss(img, 64, 64).save(ENEMIES_DIR / "shadow_orb.png")


def generate_all_enemy_art() -> None:
    ENEMIES_DIR.mkdir(parents=True, exist_ok=True)
    generate_umbral_hound()
    generate_rift_wisp()
    generate_obsidian_sentinel()
    generate_eclipse_warden_boss()
    generate_shadow_orb()


if __name__ == "__main__":
    generate_all_enemy_art()
    print("Generated all SHADOWBOUND Phase 3 enemy and boss art assets successfully.")
