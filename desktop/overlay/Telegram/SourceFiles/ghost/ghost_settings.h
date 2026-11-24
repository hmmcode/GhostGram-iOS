/*
GhostGram for Telegram Desktop: local privacy switches.
*/
#pragma once

#include "data/data_msg_id.h"

class QWidget;

namespace Ghost {

enum class Option {
	HideRead,
	HideOnline,
	HideTyping,
	HideStoryViews,
	SaveDeleted,
	LiquidBackground,
};

// The master switch turns the whole ghost mode on or off.
[[nodiscard]] bool Master();
void SetMaster(bool value);

// The raw value of a single switch, as shown in the settings box.
[[nodiscard]] bool Get(Option option);
void Set(Option option, bool value);

// Whether an option is in effect right now (ghost options need the master).
[[nodiscard]] bool Active(Option option);

[[nodiscard]] int WindowOpacity();
void SetWindowOpacity(int percent);
void ApplyWindowOpacity(QWidget *window);
void ApplyWindowOpacityToAll();

void ApplyGlassTheme();

// The default (ghost pattern) wallpaper, editable in tdata/ghostgram.ini:
// wallpaper_colors=3d4258,2c2f3e,383b50,272a36 and wallpaper_intensity=-40.
[[nodiscard]] std::vector<QColor> WallpaperColors();
[[nodiscard]] int WallpaperIntensity();
void ReloadFromDisk();

[[nodiscard]] rpl::producer<> Changes();

// Called for every outgoing API request: true means "do not send it".
[[nodiscard]] bool ShouldBlockRequest(uint32 constructor, uint32 argument);

void MarkDeleted(uint64 sessionId, FullMsgId id);
[[nodiscard]] bool IsDeleted(uint64 sessionId, FullMsgId id);

} // namespace Ghost
