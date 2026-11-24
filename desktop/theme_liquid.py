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
            l = l * 0.97
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
    'windowBg': '#1b1d26', 'windowBgOver': '#242631', 'windowBgRipple': '#2c2f3b',
    'windowShadowFgFallback': '#1b1d26', 'titleBg': '#171820', 'titleBgActive': '#171820',
    'titleButtonBg': '#171820', 'titleButtonBgActive': '#171820',
    'titleButtonBgOver': '#2a2c36', 'titleButtonBgActiveOver': '#2a2c36',
    'titleButtonCloseBg': '#171820', 'titleButtonCloseBgActive': '#171820',
    'titleButtonFg': '#7c8191', 'titleButtonFgActive': '#a3a7b5',
    'titleButtonFgOver': '#c9ccd6', 'titleButtonFgActiveOver': '#c9ccd6',
    'titleFg': '#7c8191', 'titleFgActive': '#a3a7b5', 'titleShadow': '#00000000',
    'dialogsBg': '#171820', 'dialogsBgOver': '#21232c', 'dialogsRippleBg': '#292c37',
    'dialogsBgActive': '#2c3044', 'dialogsRippleBgActive': '#343950',
    'dialogsNameFgActive': '#f1f2f7', 'dialogsTextFgActive': '#b7bbcb', 'dialogsDateFgActive': '#9ca1b4',
    'dialogsTextFgServiceActive': '#c2c6ff', 'dialogsChatIconFgActive': '#f1f2f7',
    'dialogsSentIconFgActive': '#a9b0ff', 'dialogsSendingIconFgActive': '#9ca1b4',
    'dialogsUnreadBg': '#7b83d6', 'dialogsUnreadBgOver': '#8890e0', 'dialogsUnreadBgActive': '#8890e0',
    'dialogsUnreadBgMuted': '#454859', 'dialogsUnreadBgMutedOver': '#424556', 'dialogsUnreadBgMutedActive': '#4a4e62',
    'dialogsUnreadFgActive': '#171820', 'dialogsSentIconFg': '#a9b0ff', 'dialogsVerifiedIconBg': '#8890e0',
    'dialogsTextFgService': '#a9b0ff', 'dialogsDraftFg': '#e58aa8',
    'topBarBg': '#1b1d26', 'historyComposeAreaBg': '#1b1d26', 'historyComposeButtonBgOver': '#242631',
    'historyComposeButtonBgRipple': '#2c2f3b', 'emojiPanBg': '#1e2029', 'emojiPanCategories': '#1a1c24',
    'boxBg': '#1f2129', 'boxDividerBg': '#171820', 'boxDividerFg': '#00000000', 'layerBg': '#00000099',
    'menuBg': '#22242d', 'menuBgOver': '#2a2c36', 'menuBgRipple': '#31343f', 'menuSeparatorFg': '#2c2e38',
    'searchedBarBg': '#1e2029', 'filterInputInactiveBg': '#242631', 'filterInputBorderFg': '#363948',
    'sideBarBg': '#14151c', 'sideBarBgActive': '#262938', 'sideBarBgRipple': '#2c2f3b',
    'sideBarTextFg': '#7c8191', 'sideBarTextFgActive': '#d7d9ff', 'sideBarIconFg': '#7c8191',
    'sideBarIconFgActive': '#b4b9ff', 'sideBarBadgeBg': '#7b83d6', 'sideBarBadgeFg': '#171820',
    'shadowFg': '#00000040',
    # Text: soft white and calm greys.
    'windowFg': '#e7e8ee', 'windowBoldFg': '#f1f2f7', 'windowSubTextFg': '#7c8191',
    'windowSubTextFgOver': '#8b90a0', 'windowActiveTextFg': '#a9b0ff',
    # Accent: ice-lilac, never neon.
    'windowBgActive': '#7b83d6', 'windowFgActive': '#171820', 'activeButtonBg': '#7b83d6',
    'activeButtonBgOver': '#8890e0', 'activeButtonBgRipple': '#959ce8', 'activeButtonFg': '#171820',
    'activeButtonFgOver': '#171820', 'activeLineFg': '#8890e0', 'lightButtonFg': '#a9b0ff',
    'lightButtonFgOver': '#bcc1ff', 'lightButtonBgOver': '#ffffff0d', 'lightButtonBgRipple': '#ffffff14',
    'checkboxFg': '#454859', 'sliderBgActive': '#8890e0', 'sliderBgInactive': '#363948',
    'scrollBg': '#ffffff14', 'scrollBgOver': '#ffffff24', 'scrollBarBg': '#ffffff38', 'scrollBarBgOver': '#ffffff52',
    # Chat: frosted glass over the living wallpaper.
    'msgInBg': '#ffffff14', 'msgInBgSelected': '#ffffff22', 'msgInShadow': '#00000000',
    'msgInShadowSelected': '#00000000', 'msgOutBg': '#a9b0ff26', 'msgOutBgSelected': '#a9b0ff38',
    'msgOutShadow': '#00000000', 'msgOutShadowSelected': '#00000000',
    'msgServiceBg': '#1b1d2699', 'msgServiceBgSelected': '#262938b3', 'msgServiceFg': '#d7d9e4',
    'msgDateImgBg': '#1b1d2699', 'msgDateImgBgOver': '#1b1d26b3', 'msgDateImgBgSelected': '#262938cc',
    'historyTextInFg': '#e7e8ee', 'historyTextOutFg': '#f1f2f7',
    'historyLinkInFg': '#b4b9ff', 'historyLinkOutFg': '#d0d3ff',
    'msgInDateFg': '#8b90a0', 'msgOutDateFg': '#a7abc7', 'msgInDateFgSelected': '#9ca1b4',
    'msgOutDateFgSelected': '#b7bbd6', 'msgInServiceFg': '#b4b9ff', 'msgOutServiceFg': '#d0d3ff',
    'msgInReplyBarColor': '#a9b0ff', 'msgOutReplyBarColor': '#d0d3ff',
    'msgFileInBg': '#7b83d6', 'msgFileOutBg': '#ffffff2e', 'historyOutIconFg': '#b4b9ff',
    'historySendingOutIconFg': '#8b90a0',
    'historyToDownBg': '#22242de6', 'historyToDownBgOver': '#2a2c36', 'historyToDownFg': '#a3a7b5',
    'historyUnreadBarBg': '#ffffff0d', 'historyUnreadBarBorder': '#00000000', 'historyUnreadBarFg': '#a9b0ff',
    'historyPinnedBg': '#1b1d26', 'historyReplyBg': '#1b1d26',
    'toastBg': '#22242df2', 'tooltipBg': '#2a2c36', 'tooltipBorderFg': '#363948',
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
