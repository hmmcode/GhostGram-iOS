"""Preview the dark ghost wallpaper: gradient seen through the pattern on a near-black base.
Usage: python preview.py <pattern.svg> <out.png> <intensity 0..100> <c1> <c2> <c3> <c4>
"""
import sys
from PySide6.QtCore import QRectF, QPointF, Qt
from PySide6.QtGui import QGuiApplication, QImage, QPainter, QColor, QRadialGradient
from PySide6.QtSvg import QSvgRenderer

app = QGuiApplication([])
svg, out, intensity = sys.argv[1], sys.argv[2], int(sys.argv[3])
colors = [QColor(c) for c in sys.argv[4:8]]
W, H = 1100, 760

# 4-point gradient like Telegram's (blend of radial blobs).
grad = QImage(W, H, QImage.Format_ARGB32_Premultiplied)
grad.fill(colors[0])
p = QPainter(grad)
for col, (x, y) in zip(colors, [(0.2, 0.2), (0.85, 0.3), (0.25, 0.85), (0.8, 0.85)]):
    g = QRadialGradient(QPointF(W * x, H * y), max(W, H) * 0.7)
    c0 = QColor(col); c0.setAlpha(255)
    c1 = QColor(col); c1.setAlpha(0)
    g.setColorAt(0, c0); g.setColorAt(1, c1)
    p.fillRect(0, 0, W, H, g)
p.end()

mask = QImage(W, H, QImage.Format_ARGB32_Premultiplied)
mask.fill(Qt.transparent)
p = QPainter(mask)
r = QSvgRenderer(svg)
# Telegram scales the 1440x2960 pattern to cover the width.
scale = W / 1440.0
r.render(p, QRectF(0, 0, 1440 * scale, 2960 * scale))
p.end()

res = QImage(W, H, QImage.Format_ARGB32_Premultiplied)
res.fill(QColor(0, 0, 0))
p = QPainter(res)
# Dark mode: a dimmed gradient everywhere, the full gradient inside the pattern.
p.setOpacity(1 - intensity / 100.0)
p.drawImage(0, 0, grad)
p.setOpacity(1.0)
pat = QImage(grad)
pp = QPainter(pat)
pp.setCompositionMode(QPainter.CompositionMode_DestinationIn)
pp.drawImage(0, 0, mask)
pp.end()
p.drawImage(0, 0, pat)
p.end()
res.save(out)
print('ok')
