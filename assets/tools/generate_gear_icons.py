#!/usr/bin/env python3
"""Original deterministic CC0 Phase 5 gear icons, using Pillow primitives."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]


def main():
    items = json.loads((ROOT / 'data/items/item_catalog.json').read_text())
    out = ROOT / 'assets/sprites/items'
    out.mkdir(parents=True, exist_ok=True)
    for item_id, spec in items.items():
        if spec['kind'] != 'equipment':
            continue
        img = Image.new('RGBA', (256, 256))
        d = ImageDraw.Draw(img)
        color = spec['color']
        d.rounded_rectangle((12, 12, 244, 244), radius=42, fill='#17112D', outline=color, width=6)
        d.ellipse((30, 30, 226, 226), fill='#271C46', outline='#584080', width=3)
        if spec['slot'] == 'weapon':
            d.polygon([(80, 170), (166, 46), (192, 36), (188, 68), (100, 180)], fill=color, outline='#DDEBFF', width=4)
            d.line([(80, 150), (118, 184)], fill='#FFE08A', width=12)
            d.line([(90, 170), (60, 208)], fill='#AA526B', width=12)
            d.line([(104, 147), (174, 56)], fill='#FFFFFF', width=3)
        elif spec['slot'] == 'armor':
            d.polygon([(80, 56), (104, 76), (152, 76), (176, 56), (214, 92), (186, 124), (170, 112), (170, 204), (86, 204), (86, 112), (68, 124), (42, 92)], fill=color, outline='#DDEBFF', width=5)
            d.line([(128, 90), (128, 190)], fill='#47376B', width=6)
        else:
            d.arc((64, 40, 192, 188), 180, 360, fill='#FFE08A', width=8)
            d.polygon([(128, 96), (180, 152), (128, 218), (76, 152)], fill=color, outline='#DDEBFF', width=4)
            d.ellipse((112, 136, 144, 168), fill='#60EEFF')
        img.resize((64, 64), Image.Resampling.LANCZOS).save(out / f'{item_id}.png')
    print('Generated 9 CC0 gear icons.')


if __name__ == '__main__':
    main()
