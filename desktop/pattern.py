"""Generate the GhostGram chat pattern (replaces Telegram's doodle background.tgv).

Usage: python pattern.py <out.tgv> [preview.png]
The pattern is a black-on-transparent SVG (1440x2960, like the original),
gzipped. Telegram colours it with the animated gradient.
"""
import gzip
import math
import random
import sys

W, H = 1440, 2960
random.seed(1313)
SW = 4.2  # stroke width


def ghost(s):
    # Head arc, body sides, wavy bottom with three bumps, eyes.
    w = 1.0
    path = (f"M{-0.5*w},0.15 L{-0.5*w},-0.1 A{0.5*w},{0.5*w} 0 0 1 {0.5*w},-0.1 L{0.5*w},0.55 "
            f"Q{0.5*w},0.72 {0.333*w},0.62 Q{0.25*w},0.52 {0.166*w},0.62 Q0,0.78 {-0.166*w},0.62 "
            f"Q{-0.25*w},0.52 {-0.333*w},0.62 Q{-0.5*w},0.72 {-0.5*w},0.55 Z")
    eyes = ('<ellipse cx="-0.16" cy="0.02" rx="0.06" ry="0.09" fill="black" stroke="none"/>'
            '<ellipse cx="0.16" cy="0.02" rx="0.06" ry="0.09" fill="black" stroke="none"/>')
    return f'<path d="{path}"/>{eyes}', 1.0


def plane(s):
    d = "M-0.5,0.05 L0.5,-0.4 L0.12,0.45 L0.02,0.12 Z M0.02,0.12 L0.5,-0.4"
    return f'<path d="{d}" stroke-linejoin="round"/>', 1.0


def sparkle(s):
    d = ("M0,-0.5 Q0.06,-0.06 0.5,0 Q0.06,0.06 0,0.5 Q-0.06,0.06 -0.5,0 "
         "Q-0.06,-0.06 0,-0.5 Z")
    return f'<path d="{d}"/>', 0.55


def star(s):
    pts = []
    for i in range(10):
        r = 0.5 if i % 2 == 0 else 0.22
        a = -math.pi / 2 + i * math.pi / 5
        pts.append(f"{r*math.cos(a):.3f},{r*math.sin(a):.3f}")
    return f'<polygon points="{" ".join(pts)}" stroke-linejoin="round"/>', 0.6


def moon(s):
    d = "M0.18,-0.46 A0.48,0.48 0 1 0 0.42,0.28 A0.38,0.38 0 1 1 0.18,-0.46 Z"
    return f'<path d="{d}" stroke-linejoin="round"/>', 0.8


def bubble(s):
    d = ("M-0.5,-0.25 Q-0.5,-0.45 -0.3,-0.45 L0.3,-0.45 Q0.5,-0.45 0.5,-0.25 L0.5,0.12 "
         "Q0.5,0.32 0.3,0.32 L-0.1,0.32 L-0.32,0.5 L-0.28,0.32 Q-0.5,0.32 -0.5,0.12 Z")
    dots = ''.join(f'<circle cx="{x}" cy="-0.06" r="0.055" fill="black" stroke="none"/>' for x in (-0.22, 0, 0.22))
    return f'<path d="{d}" stroke-linejoin="round"/>{dots}', 0.85


def eye(s):
    d = "M-0.5,0 Q0,-0.42 0.5,0 Q0,0.42 -0.5,0 Z"
    return f'<path d="{d}"/><circle cx="0" cy="0" r="0.13" fill="black" stroke="none"/>', 0.8


def lock(s):
    return ('<rect x="-0.32" y="-0.05" width="0.64" height="0.5" rx="0.1"/>'
            '<path d="M-0.2,-0.05 L-0.2,-0.22 A0.2,0.2 0 0 1 0.2,-0.22 L0.2,-0.05"/>'), 0.75


def dot(s):
    return '<circle cx="0" cy="0" r="0.5" fill="black" stroke="none"/>', 0.16


def ring(s):
    return '<circle cx="0" cy="0" r="0.45"/>', 0.3


def heart(s):
    d = "M0,0.42 C-0.6,0.02 -0.42,-0.5 0,-0.2 C0.42,-0.5 0.6,0.02 0,0.42 Z"
    return f'<path d="{d}" stroke-linejoin="round"/>', 0.6


SHAPES = [
    (ghost, 10, (70, 115)),
    (ghost, 6, (44, 62)),
    (plane, 5, (54, 78)),
    (sparkle, 7, (40, 62)),
    (star, 3, (40, 56)),
    (moon, 3, (48, 66)),
    (bubble, 3, (56, 74)),
    (eye, 2, (52, 66)),
    (lock, 2, (44, 56)),
    (heart, 2, (36, 48)),
    (ring, 4, (18, 30)),
    (dot, 7, (8, 14)),
]


def build():
    bag = []
    for fn, weight, size in SHAPES:
        bag += [(fn, size)] * weight
    placed = []  # (x, y, r)
    items = []
    attempts = 0
    while attempts < 60000:
        attempts += 1
        fn, (lo, hi) = random.choice(bag)
        size = random.uniform(lo, hi)
        _, scale = fn(size)
        r = size * max(scale, 0.35) * 0.62 + 26
        x = random.uniform(0, W)
        y = random.uniform(0, H)
        ok = True
        for (px, py, pr) in placed:
            # Wrap vertically and horizontally so the tile has no seams.
            dx = min(abs(px - x), W - abs(px - x))
            dy = min(abs(py - y), H - abs(py - y))
            if dx * dx + dy * dy < (pr + r) ** 2:
                ok = False
                break
        if not ok:
            continue
        placed.append((x, y, r))
        rot = random.uniform(-32, 32)
        body, scale = fn(size)
        k = size * scale
        sw = SW / k
        group = (f'<g transform="translate({x:.1f},{y:.1f}) rotate({rot:.1f}) scale({k:.2f})" '
                 f'fill="none" stroke="black" stroke-width="{sw:.4f}" stroke-linecap="round">{body}</g>')
        items.append(group)
        # Duplicate near edges so the wrap is seamless.
        for ox in (-W, 0, W):
            for oy in (-H, 0, H):
                if ox == 0 and oy == 0:
                    continue
                nx, ny = x + ox, y + oy
                if -r <= nx <= W + r and -r <= ny <= H + r:
                    items.append(group.replace(f'translate({x:.1f},{y:.1f})', f'translate({nx:.1f},{ny:.1f})'))
    svg = (f'<?xml version="1.0" encoding="utf-8"?>\n<svg version="1.1" xmlns="http://www.w3.org/2000/svg" '
           f'x="0px" y="0px" viewBox="0 0 {W} {H}" width="{W}" height="{H}">\n' + '\n'.join(items) + '\n</svg>\n')
    return svg, len(placed)


svg, count = build()
with gzip.open(sys.argv[1], 'wb', compresslevel=9) as f:
    f.write(svg.encode('utf-8'))
print('shapes', count)
if len(sys.argv) > 2:
    open(sys.argv[2], 'w', encoding='utf-8').write(svg)
