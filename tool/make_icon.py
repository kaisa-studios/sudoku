"""Draws the app icon (direction B "Spielfeld", chosen 6 Nov 2026) and writes
every size Android and iOS need, plus the store icons.

    python3 tool/make_icon.py

Needs Pillow and the Inter font (OFL). The icon is plain geometry plus digits,
drawn at 2048 px and scaled down.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
S = 2048
CREAM = (247, 243, 236)
NAVY = (31, 42, 48)
ENTRY = (36, 85, 128)
LIGHT = (211, 227, 241)
THIN = (140, 132, 120)
FONT = '/usr/share/fonts/opentype/inter/Inter-Bold.otf'


def _center(d, box, txt, size, fill):
    f = ImageFont.truetype(FONT, size)
    x0, y0, x1, y1 = box
    b = d.textbbox((0, 0), txt, font=f)
    d.text((x0 + (x1 - x0 - (b[2] - b[0])) / 2 - b[0], y0 + (y1 - y0 - (b[3] - b[1])) / 2 - b[1]), txt, font=f, fill=fill)


def draw(background=True):
    """The full icon (background=True) or only the board on transparency."""
    im = Image.new('RGBA', (S, S), CREAM + (255,) if background else (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = S * 0.17
    side = S - 2 * m
    cell = side / 3
    x = y = m + cell
    d.rectangle([m, m, m + side, m + side], fill=CREAM)
    d.rectangle([x, y, x + cell, y + cell], fill=LIGHT)
    for i in (1, 2):
        d.line([(m + i * cell, m), (m + i * cell, m + side)], fill=THIN, width=int(S * 0.012))
        d.line([(m, m + i * cell), (m + side, m + i * cell)], fill=THIN, width=int(S * 0.012))
    d.rounded_rectangle([m, m, m + side, m + side], radius=S * 0.03, outline=NAVY, width=int(S * 0.035))
    fw = int(S * 0.022)
    d.rectangle([x + fw * 0.3, y + fw * 0.3, x + cell - fw * 0.3, y + cell - fw * 0.3], outline=ENTRY, width=fw)
    _center(d, (x, y, x + cell, y + cell), '9', int(cell * 0.66), ENTRY)
    _center(d, (m, m, m + cell, m + cell), '1', int(cell * 0.5), NAVY)
    _center(d, (m + 2 * cell, m + 2 * cell, m + 3 * cell, m + 3 * cell), '5', int(cell * 0.5), NAVY)
    return im


def main():
    full = draw()
    flat = full.convert('RGB')  # stores and iOS want no transparency

    # iOS: every size in the asset catalog, filled edge to edge (iOS rounds the corners)
    ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for f in ios.glob('Icon-App-*.png'):
        n = Image.open(f).size[0]
        flat.resize((n, n), Image.LANCZOS).save(f)

    # Android: legacy icons and the adaptive icon (board on a cream background layer)
    res = ROOT / 'android/app/src/main/res'
    board = draw(background=False)
    for name, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
        n = int(48 * scale)
        flat.resize((n, n), Image.LANCZOS).save(res / f'mipmap-{name}/ic_launcher.png')
        # adaptive foreground: 108 dp canvas, the visible 72 dp hold the same picture as the full icon
        fg_size = int(108 * scale)
        inner = int(72 * scale)
        fg = Image.new('RGBA', (fg_size, fg_size), (0, 0, 0, 0))
        fg.alpha_composite(board.resize((inner, inner), Image.LANCZOS), ((fg_size - inner) // 2,) * 2)
        fg.save(res / f'mipmap-{name}/ic_launcher_foreground.png')
    anydpi = res / 'mipmap-anydpi-v26'
    anydpi.mkdir(exist_ok=True)
    (anydpi / 'ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n')
    (res / 'values/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#F7F3EC</color>\n</resources>\n')

    # store icons
    store = ROOT / 'assets/store'
    store.mkdir(parents=True, exist_ok=True)
    flat.resize((512, 512), Image.LANCZOS).save(store / 'icon-google-play-512.png')
    flat.resize((1024, 1024), Image.LANCZOS).save(store / 'icon-app-store-1024.png')


if __name__ == '__main__':
    main()
