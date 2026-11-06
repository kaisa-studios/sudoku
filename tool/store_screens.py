"""Composes the store screenshots: a short headline above a real app screen.

    python3 tool/store_screens.py <raw screens dir> <output dir>

Raw screens come from test/screenshots (workflow "Screenshots", branch ci-screens):
<lang>_<n>_<name>.png at 1179 x 2556. Output per language and store:
  app-store/<lang>/<n>.png    1290 x 2796 (6.9"/6.7" iPhone slot)
  google-play/<lang>/<n>.png  1080 x 1920 (phone, 9:16)
Needs Pillow and the Inter font (SIL Open Font License).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CREAM = (247, 243, 236)
NAVY = (31, 42, 48)
BLUE = (43, 95, 138)
FONT = '/usr/share/fonts/opentype/inter/Inter-Bold.otf'

HEADLINES = {
    'de': {
        '1': 'Klassisches Sudoku –\nklar und ruhig',
        '2': 'Große Zahlen,\nklare Felder',
        '3': 'Jeden Tag drei\nneue Rätsel',
        '4': 'Hell oder dunkel –\nwie du magst',
        '5': 'Große Darstellung\nfür kleine Handys',
        '6': 'Deine Statistik\nund Bestzeiten',
    },
    'en': {
        '1': 'Classic Sudoku –\nclean and calm',
        '2': 'Big numbers,\nclear cells',
        '3': 'Three new puzzles\nevery day',
        '4': 'Light or dark –\nyour choice',
        '5': 'Large view for\nsmall phones',
        '6': 'Your stats and\nbest times',
    },
}


def rounded(im, radius):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], radius=radius, fill=255)
    return mask


def compose(screen, headline, size):
    w, h = size
    out = Image.new('RGB', size, CREAM)
    d = ImageDraw.Draw(out)
    font = ImageFont.truetype(FONT, int(w * 0.068))
    top = int(h * 0.045)
    box = d.multiline_textbbox((0, 0), headline, font=font, spacing=int(w * 0.018), align='center')
    d.multiline_text(((w - (box[2] - box[0])) / 2, top), headline, font=font, fill=NAVY,
                     spacing=int(w * 0.018), align='center')
    text_bottom = top + (box[3] - box[1]) + int(h * 0.035)
    # the screen, as large as the rest of the height allows, with a frame and a soft shadow
    avail_h = h - text_bottom - int(h * 0.03)
    sh = avail_h
    sw = int(screen.width * sh / screen.height)
    if sw > w * 0.86:
        sw = int(w * 0.86)
        sh = int(screen.height * sw / screen.width)
    shot = screen.convert('RGB').resize((sw, sh), Image.LANCZOS)
    x = (w - sw) // 2
    y = text_bottom
    radius = int(sw * 0.07)
    frame = int(sw * 0.022)
    shadow = Image.new('L', size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x - frame, y - frame + 12, x + sw + frame, y + sh + frame + 12],
                                             radius=radius + frame, fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    out.paste((180, 172, 160), (0, 0), shadow)
    ImageDraw.Draw(out).rounded_rectangle([x - frame, y - frame, x + sw + frame, y + sh + frame],
                                          radius=radius + frame, fill=NAVY)
    out.paste(shot, (x, y), rounded(shot, radius))
    return out


def main():
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    for f in sorted(src.glob('*_*_*.png')):
        lang, n, _ = f.stem.split('_', 2)
        screen = Image.open(f)
        for store, size in [('app-store', (1290, 2796)), ('google-play', (1080, 1920))]:
            target = dst / store / lang / f'{n}.png'
            target.parent.mkdir(parents=True, exist_ok=True)
            compose(screen, HEADLINES[lang][n], size).save(target)


if __name__ == '__main__':
    main()
