#!/usr/bin/env python3
"""Original CC0 Phase 4 item icons; deterministic Pillow vector primitives."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/sprites/items'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    colors = {'health_potion': '#E43662', 'mana_potion': '#609EFF', 'stamina_draught': '#47DBB8',
              'shadow_fragment': '#9B7EFF', 'eclipse_sigil': '#FFE08A'}
    for name, color in colors.items():
        image = Image.new('RGBA', (256, 256))
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((12, 12, 244, 244), radius=42, fill='#17112D', outline='#D69E3E', width=5)
        draw.ellipse((30, 30, 226, 226), fill='#271C46', outline='#584080', width=3)
        if 'potion' in name or 'draught' in name:
            draw.rounded_rectangle((82, 98, 174, 204), radius=26, fill=color, outline='#DDEBFF', width=5)
            draw.rectangle((106, 62, 150, 108), fill='#43335E', outline='#DDEBFF', width=5)
            draw.rounded_rectangle((100, 48, 156, 72), radius=6, fill='#D69E3E', outline='#FFE08A', width=3)
            draw.line((102, 122, 102, 166), fill='#FFFFFF', width=7)
            draw.line((112, 152, 148, 152), fill='#FFFFFF', width=7)
            draw.line((130, 134, 130, 170), fill='#FFFFFF', width=7)
        elif name == 'shadow_fragment':
            draw.polygon([(130, 42), (182, 116), (142, 210), (80, 170), (74, 108)], fill=color, outline='#DDEBFF', width=4)
            draw.line([(130, 42), (118, 132), (142, 210)], fill='#47376B', width=5)
            draw.line([(74, 108), (118, 132), (182, 116)], fill='#DDEBFF', width=3)
        else:
            draw.ellipse((60, 60, 196, 196), fill='#D69E3E', outline=color, width=7)
            draw.ellipse((82, 76, 178, 172), fill='#8E60FF')
            draw.ellipse((102, 68, 190, 156), fill='#17112D')
            draw.polygon([(126, 174), (138, 194), (126, 218), (114, 194)], fill=color)
        image.resize((64, 64), Image.Resampling.LANCZOS).save(OUT / (name + '.png'))
    print('Generated 5 Phase 4 CC0 item icons.')


if __name__ == '__main__':
    main()
