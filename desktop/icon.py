import math, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 1024
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def gradient(size, c1, c2, c3):
    img = Image.new('RGBA', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x * 0.45 + y * 0.55) / size
            if t < 0.5:
                c = lerp(c1, c2, t / 0.5)
            else:
                c = lerp(c2, c3, (t - 0.5) / 0.5)
            px[x, y] = c + (255,)
    return img


def ghost_mask(size):
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    cx = size * 0.5
    w = size * 0.50
    top = size * 0.20
    head_r = w / 2
    bottom = size * 0.78
    left = cx - w / 2
    right = cx + w / 2
    # head
    d.ellipse([left, top, right, top + w], fill=255)
    # body
    d.rectangle([left, top + head_r, right, bottom - 1], fill=255)
    # wavy bottom: 3 scallops cut out / added
    n = 3
    sw = w / n
    for i in range(n):
        x0 = left + i * sw
        # bumps hanging down
        d.ellipse([x0, bottom - sw / 2, x0 + sw, bottom + sw / 2], fill=255)
    return m


def build():
    base = gradient(S, (124, 58, 237), (59, 130, 246), (6, 214, 220))
    circle = Image.new('L', (S, S), 0)
    ImageDraw.Draw(circle).ellipse([0, 0, S - 1, S - 1], fill=255)

    # soft inner glow blobs for depth
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([S * 0.55, S * 0.55, S * 1.15, S * 1.15], fill=(255, 70, 200, 120))
    gd.ellipse([-S * 0.2, -S * 0.25, S * 0.5, S * 0.45], fill=(170, 120, 255, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    base = Image.alpha_composite(base, glow)

    # glass highlight
    hl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([S * 0.08, S * 0.02, S * 0.92, S * 0.55], fill=(255, 255, 255, 55))
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.02))
    hm = Image.new('L', (S, S), 0)
    ImageDraw.Draw(hm).ellipse([S * 0.04, -S * 0.02, S * 0.96, S * 0.52], fill=255)
    hl.putalpha(ImageChops.multiply(hl.getchannel('A'), hm))
    base = Image.alpha_composite(base, hl)

    # ghost shadow
    gm = ghost_mask(S)
    shadow = Image.new('RGBA', (S, S), (20, 0, 60, 0))
    sh_mask = gm.filter(ImageFilter.GaussianBlur(S * 0.03))
    sh_mask = ImageChops.offset(sh_mask, 0, int(S * 0.025))
    shadow.putalpha(sh_mask.point(lambda v: int(v * 0.45)))
    base = Image.alpha_composite(base, shadow)

    # ghost body (white with slight vertical frost)
    body = Image.new('RGBA', (S, S))
    bp = body.load()
    for y in range(S):
        t = y / S
        c = lerp((255, 255, 255), (226, 232, 255), max(0, (t - 0.3) / 0.6))
        for x in range(S):
            bp[x, y] = c + (255,)
    body.putalpha(gm)
    base = Image.alpha_composite(base, body)

    # eyes
    ed = ImageDraw.Draw(base)
    ex = S * 0.5
    ey = S * 0.40
    ew = S * 0.065
    eh = S * 0.095
    for dx in (-S * 0.10, S * 0.10):
        ed.ellipse([ex + dx - ew / 2, ey - eh / 2, ex + dx + ew / 2, ey + eh / 2], fill=(38, 20, 90, 255))
        # eye shine
        r = ew * 0.22
        ed.ellipse([ex + dx - ew * 0.18 - r, ey - eh * 0.22 - r, ex + dx - ew * 0.18 + r, ey - eh * 0.22 + r], fill=(255, 255, 255, 255))
    # blush
    bl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bl)
    for dx in (-S * 0.165, S * 0.165):
        bd.ellipse([ex + dx - S * 0.035, ey + S * 0.06 - S * 0.018, ex + dx + S * 0.035, ey + S * 0.06 + S * 0.018], fill=(255, 120, 190, 150))
    bl = bl.filter(ImageFilter.GaussianBlur(S * 0.008))
    base = Image.alpha_composite(base, bl)

    # paper plane badge bottom-right
    pl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pl)
    pcx, pcy, pr = S * 0.77, S * 0.765, S * 0.12
    pd.ellipse([pcx - pr, pcy - pr, pcx + pr, pcy + pr], fill=(255, 255, 255, 255))
    pr2 = pr * 0.86
    grad2 = gradient(S, (59, 130, 246), (14, 165, 233), (6, 214, 220))
    m2 = Image.new('L', (S, S), 0)
    ImageDraw.Draw(m2).ellipse([pcx - pr2, pcy - pr2, pcx + pr2, pcy + pr2], fill=255)
    grad2.putalpha(m2)
    pl = Image.alpha_composite(pl, grad2)
    pd = ImageDraw.Draw(pl)
    k = pr2 * 0.62
    tip = (pcx + k, pcy - k * 0.75)
    left = (pcx - k, pcy - k * 0.05)
    tail = (pcx - k * 0.15, pcy + k * 0.2)
    bottomp = (pcx + k * 0.05, pcy + k * 0.85)
    pd.polygon([left, tip, tail], fill=(255, 255, 255, 255))
    pd.polygon([tail, tip, bottomp], fill=(225, 235, 255, 255))
    pd.polygon([tail, (pcx - k * 0.02, pcy + k * 0.55), bottomp], fill=(200, 215, 245, 255))
    base = Image.alpha_composite(base, pl)

    # rim
    rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(rim).ellipse([S * 0.006, S * 0.006, S * 0.994, S * 0.994], outline=(255, 255, 255, 90), width=int(S * 0.012))
    base = Image.alpha_composite(base, rim)

    base.putalpha(ImageChops.multiply(base.getchannel('A'), circle))
    return base


full = build()  # no margin version
full.save(os.path.join(OUT, 'master.png'))

def with_margin(img, size, margin_ratio=10 / 256):
    inner = int(round(size * (1 - 2 * margin_ratio)))
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    canvas.paste(img.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2, (size - inner) // 2))
    return canvas

full.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, 'logo_256_no_margin.png'))
with_margin(full, 256).save(os.path.join(OUT, 'logo_256.png'))
for s in (16, 32, 48, 64, 128, 256, 512):
    with_margin(full, s).save(os.path.join(OUT, f'icon{s}.png'))
    with_margin(full, s * 2).save(os.path.join(OUT, f'icon{s}@2x.png'))
with_margin(full, 256).save(os.path.join(OUT, 'icon256.ico'), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (256, 256)])
print('ok')
