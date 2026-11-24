/*
GhostGram for Telegram Desktop: local privacy switches.
*/
#include "ghost/ghost_settings.h"

#include "settings.h"
#include "window/main_window.h"
#include "window/themes/window_theme.h"

#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtWidgets/QApplication>
#include <QtWidgets/QWidget>

#include <atomic>

namespace Ghost {
namespace {

constexpr auto kOptionsCount = 6;

struct State {
	std::atomic<bool> loaded = false;
	std::atomic<bool> master = false;
	std::atomic<bool> options[kOptionsCount] = {
		true,  // HideRead
		true,  // HideOnline
		true,  // HideTyping
		true,  // HideStoryViews
		false, // SaveDeleted
		true,  // LiquidBackground
	};
	int opacity = 100;
	std::vector<QColor> wallpaperColors;
	int wallpaperIntensity = -40;
	rpl::event_stream<> changes;
	base::flat_set<std::pair<uint64, FullMsgId>> deleted;
};

State &Instance() {
	static auto result = State();
	return result;
}

[[nodiscard]] QString Key(Option option) {
	switch (option) {
	case Option::HideRead: return u"hide_read"_q;
	case Option::HideOnline: return u"hide_online"_q;
	case Option::HideTyping: return u"hide_typing"_q;
	case Option::HideStoryViews: return u"hide_story_views"_q;
	case Option::SaveDeleted: return u"save_deleted"_q;
	case Option::LiquidBackground: return u"liquid_background"_q;
	}
	return QString();
}

[[nodiscard]] QString Path() {
	return cWorkingDir() + u"tdata/ghostgram.ini"_q;
}

void Load() {
	auto &state = Instance();
	if (state.loaded.exchange(true)) {
		return;
	}
	if (cWorkingDir().isEmpty()) {
		state.loaded = false;
		return;
	}
	auto settings = QSettings(Path(), QSettings::IniFormat);
	state.master = settings.value(u"master"_q, false).toBool();
	for (auto i = 0; i != kOptionsCount; ++i) {
		const auto option = Option(i);
		state.options[i] = settings.value(
			Key(option),
			state.options[i].load()).toBool();
	}
	state.opacity = std::clamp(
		settings.value(u"window_opacity"_q, 100).toInt(),
		60,
		100);

	auto colors = std::vector<QColor>();
	const auto list = settings.value(
		u"wallpaper_colors"_q,
		u"3d4258,2c2f3e,383b50,272a36"_q).toString().split(',');
	for (const auto &entry : list) {
		const auto color = QColor::fromString(u"#"_q + entry.trimmed());
		if (color.isValid()) {
			colors.push_back(color);
		}
	}
	if (colors.size() < 2 || colors.size() > 4) {
		colors = {
			QColor(0x3D, 0x42, 0x58),
			QColor(0x2C, 0x2F, 0x3E),
			QColor(0x38, 0x3B, 0x50),
			QColor(0x27, 0x2A, 0x36),
		};
	}
	state.wallpaperColors = std::move(colors);
	state.wallpaperIntensity = std::clamp(
		settings.value(u"wallpaper_intensity"_q, -40).toInt(),
		-100,
		100);
}

void Save() {
	auto &state = Instance();
	auto settings = QSettings(Path(), QSettings::IniFormat);
	settings.setValue(u"master"_q, state.master.load());
	for (auto i = 0; i != kOptionsCount; ++i) {
		settings.setValue(Key(Option(i)), state.options[i].load());
	}
	settings.setValue(u"window_opacity"_q, state.opacity);
	if (!settings.contains(u"wallpaper_colors"_q)) {
		auto list = QStringList();
		for (const auto &color : state.wallpaperColors) {
			list.push_back(color.name().mid(1));
		}
		settings.setValue(u"wallpaper_colors"_q, list.join(','));
		settings.setValue(
			u"wallpaper_intensity"_q,
			state.wallpaperIntensity);
	}
	settings.sync();
}

} // namespace

bool Master() {
	Load();
	return Instance().master;
}

void SetMaster(bool value) {
	Load();
	Instance().master = value;
	Save();
	Instance().changes.fire({});
}

bool Get(Option option) {
	Load();
	return Instance().options[int(option)];
}

void Set(Option option, bool value) {
	Load();
	Instance().options[int(option)] = value;
	Save();
	Instance().changes.fire({});
}

bool Active(Option option) {
	if (option == Option::SaveDeleted
		|| option == Option::LiquidBackground) {
		return Get(option);
	}
	return Master() && Get(option);
}

int WindowOpacity() {
	Load();
	return Instance().opacity;
}

void SetWindowOpacity(int percent) {
	Load();
	Instance().opacity = std::clamp(percent, 60, 100);
	Save();
	ApplyWindowOpacityToAll();
	Instance().changes.fire({});
}

void ApplyWindowOpacity(QWidget *window) {
	if (window) {
		window->setWindowOpacity(WindowOpacity() / 100.);
	}
}

void ApplyWindowOpacityToAll() {
	for (const auto widget : QApplication::topLevelWidgets()) {
		if (dynamic_cast<Window::MainWindow*>(widget)) {
			ApplyWindowOpacity(widget);
		}
	}
}

std::vector<QColor> WallpaperColors() {
	Load();
	return Instance().wallpaperColors;
}

int WallpaperIntensity() {
	Load();
	return Instance().wallpaperIntensity;
}

void ReloadFromDisk() {
	Instance().loaded = false;
	Load();
	Save();
}

void ApplyGlassTheme() {
	ReloadFromDisk();
	const auto path = cWorkingDir() + u"tdata/GhostLiquid.tdesktop-theme"_q;
	if (QFile::exists(path)) {
		QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner);
		QFile::remove(path);
	}
	// A theme file next to GhostGram.exe wins over the built-in one, so the
	// palette can be tuned without rebuilding.
	const auto local = cExeDir() + u"GhostLiquid.tdesktop-theme"_q;
	const auto source = QFile::exists(local)
		? local
		: u":/gui/ghost/GhostLiquid.tdesktop-theme"_q;
	if (!QFile::copy(source, path)) {
		return;
	}
	QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner);
	Window::Theme::Apply(path);
}

rpl::producer<> Changes() {
	return Instance().changes.events();
}

bool ShouldBlockRequest(uint32 constructor, uint32 argument) {
	switch (constructor) {
	case 0x0e306d3aU: // messages.readHistory
	case 0xcc104937U: // channels.readHistory
	case 0x36a73f77U: // messages.readMessageContents
	case 0xeab5dc38U: // channels.readMessageContents
	case 0xf731a9f4U: // messages.readDiscussion
	case 0x7f4b690aU: // messages.readEncryptedHistory
		return Active(Option::HideRead);
	case 0x58943ee2U: // messages.setTyping
	case 0x791451edU: // messages.setEncryptedTyping
		return Active(Option::HideTyping);
	case 0x6628562cU: // account.updateStatus
		// Only "offline = false" (going online) is held back.
		return Active(Option::HideOnline) && (argument == 0xbc799737U);
	case 0xa556dac8U: // stories.readStories
	case 0xb2028afbU: // stories.incrementStoryViews
		return Active(Option::HideStoryViews);
	}
	return false;
}

void MarkDeleted(uint64 sessionId, FullMsgId id) {
	Instance().deleted.emplace(std::make_pair(sessionId, id));
}

bool IsDeleted(uint64 sessionId, FullMsgId id) {
	const auto &deleted = Instance().deleted;
	return !deleted.empty()
		&& (deleted.find(std::make_pair(sessionId, id)) != deleted.end());
}

} // namespace Ghost
