/*
GhostGram for Telegram Desktop: the settings box.
*/
#include "ghost/ghost_box.h"

#include "ghost/ghost_settings.h"
#include "settings/settings_common.h"
#include "ui/layers/generic_box.h"
#include "ui/vertical_list.h"
#include "ui/widgets/buttons.h"
#include "ui/wrap/slide_wrap.h"
#include "ui/wrap/vertical_layout.h"
#include "styles/style_settings.h"
#include "styles/style_layers.h"

namespace Ghost {
namespace {

[[nodiscard]] QBrush Gradient(QColor from, QColor to) {
	auto gradient = QLinearGradient(0., 0., 1., 1.);
	gradient.setCoordinateMode(QGradient::ObjectBoundingMode);
	gradient.setColorAt(0., from);
	gradient.setColorAt(1., to);
	return QBrush(gradient);
}

[[nodiscard]] Settings::IconDescriptor Icon(
		const style::icon &icon,
		QColor from,
		QColor to) {
	return Settings::IconDescriptor{
		.icon = &icon,
		.backgroundBrush = Gradient(from, to),
	};
}

not_null<Ui::SettingsButton*> AddToggle(
		not_null<Ui::VerticalLayout*> container,
		const QString &text,
		Settings::IconDescriptor &&icon,
		bool value,
		Fn<void(bool)> changed) {
	const auto button = Settings::AddButtonWithIcon(
		container,
		rpl::single(text),
		st::settingsButton,
		std::move(icon));
	button->toggleOn(rpl::single(value));
	button->toggledChanges(
	) | rpl::on_next(std::move(changed), button->lifetime());
	return button;
}

void AddOptionToggle(
		not_null<Ui::VerticalLayout*> container,
		const QString &text,
		Settings::IconDescriptor &&icon,
		Option option) {
	AddToggle(container, text, std::move(icon), Get(option), [=](bool v) {
		Set(option, v);
	});
}

[[nodiscard]] int NextOpacity(int current) {
	static const auto values = std::vector<int>{ 100, 95, 90, 85, 80, 75 };
	for (auto i = 0; i != int(values.size()); ++i) {
		if (values[i] == current) {
			return values[(i + 1) % values.size()];
		}
	}
	return 100;
}

} // namespace

void SettingsBox(not_null<Ui::GenericBox*> box) {
	box->setStyle(st::layerBox);
	box->setTitle(rpl::single(u"GhostGram 👻"_q));
	box->setWidth(st::boxWideWidth);

	const auto container = box->verticalLayout();

	Ui::AddSkip(container);
	const auto master = AddToggle(
		container,
		u"Режим призрака"_q,
		Icon(st::ghostIconStealth, QColor(0x8B, 0x5C, 0xF6), QColor(0x3B, 0x82, 0xF6)),
		Master(),
		[](bool v) { SetMaster(v); });
	Ui::AddSkip(container);
	Ui::AddDividerText(
		container,
		rpl::single(u"Главный переключатель. Когда он включён, работают "
			"пункты ниже: тебя не видно, но ты видишь всё."_q));

	const auto ghostWrap = container->add(
		object_ptr<Ui::SlideWrap<Ui::VerticalLayout>>(
			container,
			object_ptr<Ui::VerticalLayout>(container)));
	const auto ghost = ghostWrap->entity();
	Ui::AddSkip(ghost);
	Ui::AddSubsectionTitle(ghost, rpl::single(u"Что скрывать"_q));
	AddOptionToggle(
		ghost,
		u"Не отправлять «прочитано»"_q,
		Icon(st::ghostIconRead, QColor(0x22, 0xC5, 0x5E), QColor(0x10, 0xB9, 0x81)),
		Option::HideRead);
	AddOptionToggle(
		ghost,
		u"Скрывать «в сети»"_q,
		Icon(st::ghostIconOnline, QColor(0x0E, 0xA5, 0xE9), QColor(0x06, 0xB6, 0xD4)),
		Option::HideOnline);
	AddOptionToggle(
		ghost,
		u"Не показывать «печатает…»"_q,
		Icon(st::ghostIconTyping, QColor(0xF5, 0x9E, 0x0B), QColor(0xF9, 0x73, 0x16)),
		Option::HideTyping);
	AddOptionToggle(
		ghost,
		u"Смотреть истории незаметно"_q,
		Icon(st::ghostIconStories, QColor(0xEC, 0x48, 0x99), QColor(0xD9, 0x46, 0xEF)),
		Option::HideStoryViews);
	Ui::AddSkip(ghost);
	Ui::AddDividerText(
		ghost,
		rpl::single(u"Сообщения останутся непрочитанными у собеседника, "
			"пока ты не ответишь."_q));
	ghostWrap->toggleOn(master->toggledValue());

	Ui::AddSkip(container);
	Ui::AddSubsectionTitle(container, rpl::single(u"Сообщения"_q));
	AddOptionToggle(
		container,
		u"Сохранять удалённые сообщения"_q,
		Icon(st::ghostIconDeleted, QColor(0xEF, 0x44, 0x44), QColor(0xF4, 0x3F, 0x5E)),
		Option::SaveDeleted);
	Ui::AddSkip(container);
	Ui::AddDividerText(
		container,
		rpl::single(u"Если собеседник удалит сообщение, оно останется "
			"у тебя с пометкой 🗑 (до перезапуска)."_q));

	Ui::AddSkip(container);
	Ui::AddSubsectionTitle(container, rpl::single(u"Жидкое стекло"_q));
	const auto glass = Settings::AddButtonWithIcon(
		container,
		rpl::single(u"Включить тему Ghost Liquid"_q),
		st::settingsButton,
		Icon(st::ghostIconGlass, QColor(0x3A, 0x3D, 0x4C), QColor(0x7B, 0x83, 0xD6)));
	glass->setClickedCallback([=] {
		box->closeBox();
		ApplyGlassTheme();
	});
	AddOptionToggle(
		container,
		u"Живой фон"_q,
		Icon(st::ghostIconLiquid, QColor(0x2A, 0x2D, 0x3C), QColor(0x6F, 0x78, 0xB8)),
		Option::LiquidBackground);
	auto opacityLabel = rpl::single(
		rpl::empty
	) | rpl::then(
		Changes()
	) | rpl::map([] {
		return QString::number(WindowOpacity()) + '%';
	});
	const auto opacity = Settings::AddButtonWithLabel(
		container,
		rpl::single(u"Прозрачность окна"_q),
		std::move(opacityLabel),
		st::settingsButton,
		Icon(st::ghostIconOpacity, QColor(0x2A, 0x2D, 0x3C), QColor(0x5A, 0x60, 0x80)));
	opacity->setClickedCallback([] {
		SetWindowOpacity(NextOpacity(WindowOpacity()));
	});
	Ui::AddSkip(container);
	Ui::AddDividerText(
		container,
		rpl::single(u"Ghost Liquid: тёмный матовый графит, пузыри из "
			"матового стекла и фон с призраками, который медленно "
			"переливается. «Живой фон» включает этот перелив. "
			"Прозрачность окна: 100 → 95 → 90 → 85 → 80 → 75%."_q));

	box->addButton(rpl::single(u"Готово"_q), [=] { box->closeBox(); });
}

} // namespace Ghost
