"""Build the "Ghost Liquid" palette: every colour of the night theme is re-tinted
into one graphite / ice-lilac family, then the glass parts get explicit values.

Usage: python theme_liquid.py <night colors.tdesktop-theme> <out .tdesktop-theme>
The theme has no background image on purpose: GhostGram's default wallpaper
(the animated ghost pattern) is used with it.
"""
import colorsys
import re
import sys
import zipfile

src, out = sys.argv[1], sys.argv[2]
text = open(src, encoding='utf-8').read()

BASE_HUE = 236 / 360.0


def parse(hexv):
    hexv = hexv.lstrip('#')
    r, g, b = int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16)
    a = int(hexv[6:8], 16) if len(hexv) == 8 else None
    return r, g, b, a


def fmt(r, g, b, a=None):
    s = '#%02x%02x%02x' % (max(0, min(255, int(round(r)))), max(0, min(255, int(round(g)))), max(0, min(255, int(round(b)))))
    if a is not None:
        s += '%02x' % a
    return s


def retint(hexv):
    r, g, b, a = parse(hexv)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    deg = h * 360
    if s < 0.35 or l < 0.3:
        # Neutral / dark surfaces: graphite with a faint cold tint.
        h = BASE_HUE
        s = min(s, 0.30) * 0.55
        if l < 0.3:
            l = l * 0.72
    elif 170 <= deg <= 265:
        # Telegram blues become the muted ice-lilac accent.
        h = BASE_HUE
        s = s * 0.42
        l = min(0.78, l * 1.02)
    else:
        # Reds, greens, oranges keep their meaning, just calmer.
        s = s * 0.7
    nr, ng, nb = colorsys.hls_to_rgb(h, l, s)
    return fmt(nr * 255, ng * 255, nb * 255, a)


over = {
    # Surfaces: matte graphite, the side bar a touch deeper.
    'windowBg': '#101116', 'windowBgOver': '#181a21', 'windowBgRipple': '#20232c',
    'windowShadowFgFallback': '#101116', 'titleBg': '#0c0d11', 'titleBgActive': '#0c0d11',
    'titleButtonBg': '#0c0d11', 'titleButtonBgActive': '#0c0d11',
    'titleButtonBgOver': '#1b1d25', 'titleButtonBgActiveOver': '#1b1d25',
    'titleButtonCloseBg': '#0c0d11', 'titleButtonCloseBgActive': '#0c0d11',
    'titleButtonFg': '#7c8191', 'titleButtonFgActive': '#a3a7b5',
    'titleButtonFgOver': '#c9ccd6', 'titleButtonFgActiveOver': '#c9ccd6',
    'titleFg': '#7c8191', 'titleFgActive': '#a3a7b5', 'titleShadow': '#00000000',
    'dialogsBg': '#0c0d11', 'dialogsBgOver': '#15171d', 'dialogsRippleBg': '#1d2029',
    'dialogsBgActive': '#1f2230', 'dialogsRippleBgActive': '#272b3c',
    'dialogsNameFgActive': '#f1f2f7', 'dialogsTextFgActive': '#b7bbcb', 'dialogsDateFgActive': '#9ca1b4',
    'dialogsTextFgServiceActive': '#c2c6ff', 'dialogsChatIconFgActive': '#f1f2f7',
    'dialogsSentIconFgActive': '#a9b0ff', 'dialogsSendingIconFgActive': '#9ca1b4',
    'dialogsUnreadBg': '#7b83d6', 'dialogsUnreadBgOver': '#8890e0', 'dialogsUnreadBgActive': '#8890e0',
    'dialogsUnreadBgMuted': '#3a3d4c', 'dialogsUnreadBgMutedOver': '#424556', 'dialogsUnreadBgMutedActive': '#4a4e62',
    'dialogsUnreadFgActive': '#0c0d11', 'dialogsSentIconFg': '#a9b0ff', 'dialogsVerifiedIconBg': '#8890e0',
    'dialogsTextFgService': '#a9b0ff', 'dialogsDraftFg': '#e58aa8',
    'topBarBg': '#101116', 'historyComposeAreaBg': '#101116', 'historyComposeButtonBgOver': '#181a21',
    'historyComposeButtonBgRipple': '#20232c', 'emojiPanBg': '#121319', 'emojiPanCategories': '#0f1015',
    'boxBg': '#13141a', 'boxDividerBg': '#0c0d11', 'boxDividerFg': '#00000000', 'layerBg': '#00000099',
    'menuBg': '#15161c', 'menuBgOver': '#1d1f27', 'menuBgRipple': '#252832', 'menuSeparatorFg': '#22242c',
    'searchedBarBg': '#121319', 'filterInputInactiveBg': '#181a21', 'filterInputBorderFg': '#2a2d3a',
    'sideBarBg': '#0a0b0e', 'sideBarBgActive': '#181a22', 'sideBarBgRipple': '#20232c',
    'sideBarTextFg': '#7c8191', 'sideBarTextFgActive': '#d7d9ff', 'sideBarIconFg': '#7c8191',
    'sideBarIconFgActive': '#b4b9ff', 'sideBarBadgeBg': '#7b83d6', 'sideBarBadgeFg': '#0c0d11',
    'shadowFg': '#00000040',
    # Text: soft white and calm greys.
    'windowFg': '#e7e8ee', 'windowBoldFg': '#f1f2f7', 'windowSubTextFg': '#7c8191',
    'windowSubTextFgOver': '#8b90a0', 'windowActiveTextFg': '#a9b0ff',
    # Accent: ice-lilac, never neon.
    'windowBgActive': '#7b83d6', 'windowFgActive': '#0c0d11', 'activeButtonBg': '#7b83d6',
    'activeButtonBgOver': '#8890e0', 'activeButtonBgRipple': '#959ce8', 'activeButtonFg': '#0c0d11',
    'activeButtonFgOver': '#0c0d11', 'activeLineFg': '#8890e0', 'lightButtonFg': '#a9b0ff',
    'lightButtonFgOver': '#bcc1ff', 'lightButtonBgOver': '#ffffff0d', 'lightButtonBgRipple': '#ffffff14',
    'checkboxFg': '#3a3d4c', 'sliderBgActive': '#8890e0', 'sliderBgInactive': '#2a2d3a',
    'scrollBg': '#ffffff14', 'scrollBgOver': '#ffffff24', 'scrollBarBg': '#ffffff38', 'scrollBarBgOver': '#ffffff52',
    # Chat: frosted glass over the living wallpaper.
    'msgInBg': '#ffffff14', 'msgInBgSelected': '#ffffff22', 'msgInShadow': '#00000000',
    'msgInShadowSelected': '#00000000', 'msgOutBg': '#a9b0ff26', 'msgOutBgSelected': '#a9b0ff38',
    'msgOutShadow': '#00000000', 'msgOutShadowSelected': '#00000000',
    'msgServiceBg': '#0c0d1199', 'msgServiceBgSelected': '#181a22b3', 'msgServiceFg': '#d7d9e4',
    'msgDateImgBg': '#0c0d1199', 'msgDateImgBgOver': '#0c0d11b3', 'msgDateImgBgSelected': '#181a22cc',
    'historyTextInFg': '#e7e8ee', 'historyTextOutFg': '#f1f2f7',
    'historyLinkInFg': '#b4b9ff', 'historyLinkOutFg': '#d0d3ff',
    'msgInDateFg': '#8b90a0', 'msgOutDateFg': '#a7abc7', 'msgInDateFgSelected': '#9ca1b4',
    'msgOutDateFgSelected': '#b7bbd6', 'msgInServiceFg': '#b4b9ff', 'msgOutServiceFg': '#d0d3ff',
    'msgInReplyBarColor': '#a9b0ff', 'msgOutReplyBarColor': '#d0d3ff',
    'msgFileInBg': '#7b83d6', 'msgFileOutBg': '#ffffff2e', 'historyOutIconFg': '#b4b9ff',
    'historySendingOutIconFg': '#8b90a0',
    'historyToDownBg': '#15161ce6', 'historyToDownBgOver': '#1d1f27', 'historyToDownFg': '#a3a7b5',
    'historyUnreadBarBg': '#ffffff0d', 'historyUnreadBarBorder': '#00000000', 'historyUnreadBarFg': '#a9b0ff',
    'historyPinnedBg': '#101116', 'historyReplyBg': '#101116',
    'toastBg': '#15161cf2', 'tooltipBg': '#1d1f27', 'tooltipBorderFg': '#2a2d3a',
}

lines = []
seen = set()
for line in text.splitlines():
    m = re.match(r'^([A-Za-z0-9_]+):\s*([^;]+);(.*)$', line)
    if not m:
        lines.append(line)
        continue
    key, value, rest = m.group(1), m.group(2).strip(), m.group(3)
    if key in over:
        value = over[key]
        seen.add(key)
    elif value.startswith('#'):
        value = retint(value)
    lines.append(f'{key}: {value};{rest}')

print('overrides not in night theme (skipped):', sorted(set(over) - seen))
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('colors.tdesktop-theme', '\n'.join(lines) + '\n')
print('ok')
