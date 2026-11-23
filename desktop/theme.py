import re, sys, zipfile, io, random
from PIL import Image, ImageDraw, ImageFilter

night_colors, out_path, preview_path = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(night_colors, encoding='utf-8').read()

over = {
    'windowBg': '#141428', 'windowBgOver': '#1f1f3d', 'windowBgRipple': '#2a2a52',
    'windowBgActive': '#7c5cff', 'windowActiveTextFg': '#7fdcff', 'windowSubTextFg': '#8b8fb8',
    'windowSubTextFgOver': '#9da1cc', 'windowShadowFgFallback': '#141428',
    'activeButtonBg': '#6d4aff', 'activeButtonBgOver': '#7c5cff', 'activeButtonBgRipple': '#8f73ff',
    'activeLineFg': '#8f73ff', 'lightButtonFg': '#a99bff', 'lightButtonFgOver': '#b9adff',
    'lightButtonBgOver': '#ffffff10', 'lightButtonBgRipple': '#ffffff1c', 'checkboxFg': '#4a4a78',
    'sliderBgActive': '#8f73ff', 'menuBg': '#1a1a36', 'menuBgOver': '#262650', 'menuBgRipple': '#2f2f5e',
    'titleBg': '#11112a', 'titleBgActive': '#11112a', 'titleButtonBgOver': '#ffffff14',
    'boxBg': '#191936', 'layerBg': '#05051099',
    'dialogsBg': '#12122a', 'dialogsBgOver': '#1d1d3c', 'dialogsBgActive': '#5b3fd9',
    'dialogsRippleBg': '#2a2a52', 'dialogsRippleBgActive': '#6c51e6',
    'dialogsUnreadBg': '#7c5cff', 'dialogsUnreadBgOver': '#8b6dff', 'dialogsUnreadBgMuted': '#4a4a72',
    'dialogsUnreadBgMutedOver': '#55557f', 'dialogsSentIconFg': '#7fdcff', 'dialogsVerifiedIconBg': '#7c5cff',
    'dialogsTextFgService': '#a99bff', 'dialogsDraftFg': '#ff7ab8',
    'searchedBarBg': '#16162f', 'topBarBg': '#15152d', 'emojiPanBg': '#17172f', 'emojiPanCategories': '#141428',
    'historyComposeAreaBg': '#15152d', 'historyComposeAreaBgOver': '#1d1d3c', 'historyComposeButtonBgOver': '#ffffff10',
    'historyPinnedBg': '#15152d', 'historyReplyBg': '#15152d',
    'msgInBg': '#ffffff1f', 'msgInBgSelected': '#ffffff33', 'msgInShadow': '#00000022',
    'msgInShadowSelected': '#00000033', 'msgOutBg': '#7c5cffb8', 'msgOutBgSelected': '#8f73ffd6',
    'msgOutShadow': '#00000022', 'msgOutShadowSelected': '#00000033',
    'msgServiceBg': '#ffffff24', 'msgServiceBgSelected': '#ffffff38', 'msgDateImgBg': '#00000066',
    'historyLinkInFg': '#8fdcff', 'msgInReplyBarColor': '#8fdcff', 'msgInDateFg': '#c9cbe8b0',
    'msgOutDateFg': '#ffffffb0', 'msgInServiceFg': '#9fe3ff', 'msgFileInBg': '#8f73ff',
    'msgFileOutBg': '#ffffff40', 'historyToDownBg': '#1d1d3c', 'historyToDownBgOver': '#26264a',
    'historyUnreadBarBg': '#ffffff14', 'historyUnreadBarBorder': '#00000000',
    'toastBg': '#191936ee', 'tooltipBg': '#1d1d3c', 'scrollBg': '#ffffff1a', 'scrollBgOver': '#ffffff2c',
}

lines = []
seen = set()
for line in text.splitlines():
    m = re.match(r'^([A-Za-z0-9_]+):\s*([^;]+);(.*)$', line)
    if m and m.group(1) in over:
        lines.append(f"{m.group(1)}: {over[m.group(1)]};{m.group(3)}")
        seen.add(m.group(1))
    else:
        lines.append(line)
missing = sorted(set(over) - seen)
print('missing keys (skipped):', missing)
colors = '\n'.join(lines) + '\n'

# Aurora background.
W, H = 2400, 1500
random.seed(7)
bg = Image.new('RGB', (W, H), (14, 12, 34))
blobs = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(blobs)
for (cx, cy, r, col) in [
    (0.18, 0.22, 0.42, (124, 92, 255, 150)),
    (0.82, 0.18, 0.38, (0, 180, 255, 120)),
    (0.62, 0.78, 0.46, (255, 70, 180, 95)),
    (0.12, 0.85, 0.36, (0, 220, 200, 90)),
    (0.48, 0.45, 0.30, (90, 60, 220, 110)),
]:
    d.ellipse([(cx - r) * W, (cy - r) * W * 0.6 / 0.6 * H / W * (W / H) * 0 + (cy * H - r * W * 0.6), (cx + r) * W, cy * H + r * W * 0.6], fill=col)
blobs = blobs.filter(ImageFilter.GaussianBlur(160))
bg = Image.alpha_composite(bg.convert('RGBA'), blobs)
# subtle grain for a frosted feel
noise = Image.effect_noise((W, H), 18).convert('L')
grain = Image.merge('RGBA', (noise, noise, noise, noise.point(lambda v: 10)))
bg = Image.alpha_composite(bg, grain).convert('RGB')

buf = io.BytesIO()
bg.save(buf, 'JPEG', quality=90)
with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('colors.tdesktop-theme', colors)
    z.writestr('background.jpg', buf.getvalue())
bg.resize((960, 600)).save(preview_path)
print('ok')
