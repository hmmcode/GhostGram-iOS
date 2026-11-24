"""Apply GhostGram to a Telegram Desktop source tree.

Usage: python patch.py <tdesktop root>
Every patch is an exact text replacement; a missing anchor stops the build.
"""
import os
import shutil
import sys

ROOT = os.path.abspath(sys.argv[1])
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'Telegram', 'SourceFiles')


def escape_non_ascii(text):
    """MSVC may read sources in the ANSI code page: keep them pure ASCII."""
    out = []
    for ch in text:
        code = ord(ch)
        if code < 128:
            out.append(ch)
        elif code <= 0xFFFF:
            out.append('\\u%04X' % code)
        else:
            out.append('\\U%08X' % code)
    return ''.join(out)


def read(path):
    with open(path, encoding='utf-8', newline='') as f:
        return f.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(text)


def patch(rel, pairs):
    path = os.path.join(ROOT, rel)
    text = read(path)
    crlf = '\r\n' in text
    if crlf:
        text = text.replace('\r\n', '\n')
    for old, new in pairs:
        new = escape_non_ascii(new)
        if new in text:
            continue  # already applied
        if old not in text:
            sys.exit('GHOST PATCH FAILED: anchor not found in %s:\n%s' % (rel, old))
        text = text.replace(old, new, 1)
    if crlf:
        text = text.replace('\n', '\r\n')
    write(path, text)
    print('patched', rel)


# 1. New sources and resources.
overlay = os.path.join(HERE, 'overlay')
for base, _, files in os.walk(overlay):
    for name in files:
        src = os.path.join(base, name)
        dst = os.path.join(ROOT, os.path.relpath(src, overlay))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        print('copied', os.path.relpath(src, overlay))

for name in os.listdir(os.path.join(HERE, 'src')):
    src = os.path.join(HERE, 'src', name)
    dst = os.path.join(SRC, 'ghost', name)
    write(dst, escape_non_ascii(read(src)))
    print('escaped', name)

patch('Telegram/CMakeLists.txt', [(
    '    settings/settings_experimental.cpp\n',
    '    ghost/ghost_box.cpp\n'
    '    ghost/ghost_box.h\n'
    '    ghost/ghost_settings.cpp\n'
    '    ghost/ghost_settings.h\n'
    '    settings/settings_experimental.cpp\n',
)])

patch('Telegram/Resources/qrc/telegram/telegram.qrc', [(
    '    <file alias="art/logo_256.png">../../art/logo_256.png</file>\n',
    '    <file alias="art/logo_256.png">../../art/logo_256.png</file>\n'
    '    <file alias="ghost/GhostGlass.tdesktop-theme">../../ghost/GhostGlass.tdesktop-theme</file>\n',
)])

patch('Telegram/Resources/qrc/telegram/telegram.qrc', [(
    '    <file alias="ghost/GhostGlass.tdesktop-theme">../../ghost/GhostGlass.tdesktop-theme</file>\n',
    '    <file alias="ghost/GhostGlass.tdesktop-theme">../../ghost/GhostGlass.tdesktop-theme</file>\n'
    '    <file alias="ghost/GhostLiquid.tdesktop-theme">../../ghost/GhostLiquid.tdesktop-theme</file>\n',
)])

# 2. Icons for the settings rows (white glyphs on gradient squares).
path = os.path.join(SRC, 'settings', 'settings.style')
style = read(path).replace('\r\n', '\n')
style = style.split('\nghostIconStealth:')[0].rstrip('\n') + '\n'
style += '''
ghostIconStealth: icon {{ "menu/stealth", settingsIconFg }};
ghostIconRead: icon {{ "menu/read_ticks", settingsIconFg }};
ghostIconOnline: icon {{ "menu/send_when_online", settingsIconFg }};
ghostIconTyping: icon {{ "menu/keyboard", settingsIconFg }};
ghostIconStories: icon {{ "menu/stories_posted", settingsIconFg }};
ghostIconDeleted: icon {{ "menu/delete", settingsIconFg }};
ghostIconGlass: icon {{ "menu/palette", settingsIconFg }};
ghostIconOpacity: icon {{ "menu/caption_hide", settingsIconFg }};
ghostIconLiquid: icon {{ "menu/night_mode", settingsIconFg }};
'''
write(path, style)
print('patched settings.style')

# 3. The "GhostGram" entry at the top of the main settings list.
patch('Telegram/SourceFiles/settings/sections/settings_main.cpp', [
    ('#include "settings/settings_builder.h"\n',
     '#include "settings/settings_builder.h"\n'
     '#include "ghost/ghost_box.h"\n'),
    ('''void BuildSectionButtons(SectionBuilder &builder) {
	const auto session = builder.session();
	const auto controller = builder.controller();
	const auto showOther = builder.showOther();
''', '''void BuildSectionButtons(SectionBuilder &builder) {
	const auto session = builder.session();
	const auto controller = builder.controller();
	const auto showOther = builder.showOther();

	builder.addButton({
		.id = u"main/ghostgram"_q,
		.title = rpl::single(u"GhostGram 👻"_q),
		.icon = { &st::menuIconStealth },
		.onClick = [=] { controller->show(Box(Ghost::SettingsBox)); },
		.keywords = { u"ghost"_q, u"призрак"_q, u"ghostgram"_q },
	});
'''),
])

# 4. Ghost mode: hold back read / online / typing / story view requests.
patch('Telegram/SourceFiles/mtproto/mtp_instance.cpp', [
    ('#include "mtproto/mtp_instance.h"\n',
     '#include "mtproto/mtp_instance.h"\n\n#include "ghost/ghost_settings.h"\n'),
    ('''		bool needsLayer,
		mtpRequestId afterRequestId) {
	const auto session = getSession(shiftedDcId);
''', '''		bool needsLayer,
		mtpRequestId afterRequestId) {
	{
		constexpr auto kBody = SerializedRequest::kMessageBodyPosition;
		const auto size = int(request->size());
		const auto constructor = (size > kBody)
			? uint32((*request)[kBody])
			: uint32(0);
		const auto argument = (size > kBody + 1)
			? uint32((*request)[kBody + 1])
			: uint32(0);
		if (constructor && Ghost::ShouldBlockRequest(constructor, argument)) {
			request->requestId = requestId;
			storeRequest(requestId, request, std::move(callbacks));
			InvokeQueued(_instance, [=] {
				auto response = Response();
				response.requestId = requestId;
				processCallback(response);
			});
			return;
		}
	}
	const auto session = getSession(shiftedDcId);
'''),
])

# 5. Keep messages that others delete.
patch('Telegram/SourceFiles/data/data_session.cpp', [
    ('#include "base/call_delayed.h"\n',
     '#include "base/call_delayed.h"\n#include "ghost/ghost_settings.h"\n'),
    ('''		if (list && i != list->end()) {
			const auto history = i->second->history();
			toDestroy.push_back(i->second);
''', '''		if (list && i != list->end()) {
			const auto history = i->second->history();
			if (Ghost::Active(Ghost::Option::SaveDeleted)) {
				Ghost::MarkDeleted(_session->uniqueId(), i->second->fullId());
				requestItemViewRefresh(i->second);
				continue;
			}
			toDestroy.push_back(i->second);
'''),
    ('''		if (const auto item = nonChannelMessage(messageId.v)) {
			const auto history = item->history();
			toDestroy.push_back(item);
''', '''		if (const auto item = nonChannelMessage(messageId.v)) {
			const auto history = item->history();
			if (Ghost::Active(Ghost::Option::SaveDeleted)) {
				Ghost::MarkDeleted(_session->uniqueId(), item->fullId());
				requestItemViewRefresh(item);
				continue;
			}
			toDestroy.push_back(item);
'''),
])

patch('Telegram/SourceFiles/history/view/history_view_bottom_info.cpp', [
    ('#include "styles/style_chat.h"\n',
     '#include "styles/style_chat.h"\n#include "ghost/ghost_settings.h"\n'),
    ('''	if (const auto editedDate = message->displayedEditDate()) {
		result.flags |= Flag::Edited;
''', '''	if (Ghost::IsDeleted(
			item->history()->session().uniqueId(),
			item->fullId())) {
		result.author = u"🗑 удалено"_q
			+ (result.author.isEmpty()
				? QString()
				: (u" · "_q + result.author));
	}
	if (const auto editedDate = message->displayedEditDate()) {
		result.flags |= Flag::Edited;
'''),
])

# 6. Window transparency from the GhostGram box.
patch('Telegram/SourceFiles/window/main_window.cpp', [
    ('#include "window/main_window.h"\n',
     '#include "window/main_window.h"\n\n#include "ghost/ghost_settings.h"\n'),
    ('''	updateTitle();
	updateWindowIcon();
}
''', '''	updateTitle();
	updateWindowIcon();
	Ghost::ApplyWindowOpacity(this);
}
'''),
])

# 7. Ghost Liquid: the default wallpaper is a dark graphite gradient with the
#    ghost pattern (Resources/art/background.tgv is replaced by the overlay).
patch('Telegram/SourceFiles/data/data_wall_paper.cpp', [
    ('#include "data/data_wall_paper.h"\n',
     '#include "data/data_wall_paper.h"\n\n#include "ghost/ghost_settings.h"\n'),
    ('''	).withPatternIntensity(50).withBackgroundColors({
		QColor(219, 221, 187),
		QColor(107, 165, 135),
		QColor(213, 216, 141),
		QColor(136, 184, 132),
	});''', '''	).withPatternIntensity(
		Ghost::WallpaperIntensity()
	).withBackgroundColors(Ghost::WallpaperColors());'''),
])

# 8. Living background: the gradient keeps slowly flowing.
patch('Telegram/SourceFiles/history/history_widget.cpp', [
    ('#include "history/history_widget.h"\n',
     '#include "history/history_widget.h"\n\n#include "ghost/ghost_settings.h"\n'),
    ('''	setAcceptDrops(true);
	setVisualTabOrder(true);
''', '''	setAcceptDrops(true);
	setVisualTabOrder(true);

	{
		const auto liquid = lifetime().make_state<base::Timer>([=] {
			if (_list
				&& isVisible()
				&& !anim::Disabled()
				&& Ghost::Get(Ghost::Option::LiquidBackground)) {
				_list->theme()->rotateComplexGradientBackground();
			}
		});
		liquid->callEach(2600);
	}
'''),
])

# 9. Frosted glass edge on translucent bubbles (only when the bubble colour
#    has alpha, so ordinary themes are not touched).
patch('Telegram/SourceFiles/ui/chat/message_bubble.cpp', [
    ('#include "ui/chat/message_bubble.h"\n',
     '#include "ui/chat/message_bubble.h"\n#include "ui/painter.h"\n'),
    (
    '''void PaintBubble(QPainter &p, const SimpleBubble &args) {
	if (UsePatternBubble(args)) {
		PaintPatternBubble(p, args);
	} else {
		PaintSolidBubble(p, args);
	}
}''', '''void PaintGhostGlassEdge(QPainter &p, const SimpleBubble &args) {
	const auto &st = args.st->messageStyle(args.outbg, args.selected);
	if (st.msgBg->c.alpha() >= 255) {
		return;
	}
	const auto radius = [&](BubbleCornerRounding rounding) {
		switch (rounding) {
		case BubbleCornerRounding::Large: return float64(BubbleRadiusLarge());
		case BubbleCornerRounding::Small: return float64(BubbleRadiusSmall());
		default: return 0.;
		}
	};
	const auto r = QRectF(args.geometry).adjusted(0.5, 0.5, -0.5, -0.5);
	const auto tl = radius(args.rounding.topLeft);
	const auto tr = radius(args.rounding.topRight);
	const auto bl = radius(args.rounding.bottomLeft);
	const auto br = radius(args.rounding.bottomRight);
	auto path = QPainterPath();
	path.moveTo(r.left() + tl, r.top());
	path.lineTo(r.right() - tr, r.top());
	path.arcTo(r.right() - 2 * tr, r.top(), 2 * tr, 2 * tr, 90, -90);
	path.lineTo(r.right(), r.bottom() - br);
	path.arcTo(r.right() - 2 * br, r.bottom() - 2 * br, 2 * br, 2 * br, 0, -90);
	path.lineTo(r.left() + bl, r.bottom());
	path.arcTo(r.left(), r.bottom() - 2 * bl, 2 * bl, 2 * bl, 270, -90);
	path.lineTo(r.left(), r.top() + tl);
	path.arcTo(r.left(), r.top(), 2 * tl, 2 * tl, 180, -90);
	path.closeSubpath();

	auto gradient = QLinearGradient(r.topLeft(), r.bottomLeft());
	gradient.setColorAt(0., QColor(255, 255, 255, 46));
	gradient.setColorAt(0.35, QColor(255, 255, 255, 14));
	gradient.setColorAt(1., QColor(255, 255, 255, 6));
	auto hq = PainterHighQualityEnabler(p);
	p.setBrush(Qt::NoBrush);
	p.setPen(QPen(QBrush(gradient), 1.));
	p.drawPath(path);
}

void PaintBubble(QPainter &p, const SimpleBubble &args) {
	if (UsePatternBubble(args)) {
		PaintPatternBubble(p, args);
	} else {
		PaintSolidBubble(p, args);
		PaintGhostGlassEdge(p, args);
	}
}'''),
])

# 10. The window says GhostGram.
patch('Telegram/SourceFiles/window/main_window.cpp', [(
    'setTitle((user.isEmpty() ? u"Telegram"_q : user) + added + suffix);',
    'setTitle((user.isEmpty() ? u"GhostGram"_q : user) + added + suffix);',
)])

print('GHOST PATCH OK')
