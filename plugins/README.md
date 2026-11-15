# Плагины GhostGram

Плагин — это обычный `.js` файл. GhostGram запускает его через JavaScriptCore. Пересобирать приложение не нужно.

**Как поставить:** GhostGram 👻 → «🧩 Плагины». Источники:
- каталог (этот репозиторий, файл `index.json`);
- «Избранное» (`.js` файл, отправленный себе);
- файл;
- буфер обмена;
- ссылка.

Чтобы увидеть все команды, напиши в любом чате `.plugins`.

## Заголовок

```js
// @id my-plugin            — уникальный id (латиница, цифры, -)
// @name Мой плагин
// @version 1.0             — для обновлений из каталога
// @author я
// @description Что делает
```

## API `GG`

| Что | Как |
|---|---|
| Команда в чате | `GG.command('.cmd', (args, msg) => 'текст', 'описание')` |
| Входящие сообщения | `GG.on('message', msg => { … })` |
| Свои исходящие сообщения | `GG.on('outgoing', msg => 'новый текст' \| false \| undefined)` |
| Запуск плагина | `GG.on('start', () => { … })` |
| Изменение настройки | `GG.on('settings', ({key}) => { … })` |
| Отправить | `GG.send(chatId, text, {replyTo})`, `msg.reply(text)`, `msg.respond(text)` |
| Голосовое с рисунком (v11+) | `GG.sendVoice(chatId, [0..31 × до 100], {duration, replyTo})`, `msg.voice(wave, {duration})` — беззвучное голосовое, волна рисуется из чисел |
| Кружок (v12+) | `GG.pickRound(chatId, {seconds, replyTo})`, `msg.round({seconds})` — открывает галерею, выбранное видео/гифка/картинка уходит кружком |
| Уведомление | `GG.notify(title, body, {delay: секунды, id})`, `GG.cancelNotify(id)` |
| Окно / тост / буфер | `GG.alert(title, text)`, `GG.toast(text)`, `GG.copy(text)` |
| Настройки (экран плагина) | `GG.settings([{key, title, type: 'bool'\|'text'\|'number'\|'choice', default, options, hint}])` |
| Значения настроек | `GG.setting(key)`, `GG.setSetting(key, value)` |
| Кнопки на экране плагина | `GG.action('Название', () => { … })` |
| Хранилище | `GG.storage.get(key, fallback)`, `.set(key, value)`, `.remove(key)`, `.keys()` |
| Интернет | `await GG.fetch(url, {method, headers, body, timeout})` → `{status, ok, text(), json(), headers}` |
| Таймеры | `setTimeout`, `setInterval`, `clearTimeout`, `await GG.sleep(ms)` |
| Я | `GG.me()` → `{id, chatId, name, username}` |
| Прочее | `GG.now()` (unix-время), `GG.log(...)` / `console.log(...)` пишут в журнал плагина |

### Что вернуть из команды
- **Строку.** Она уйдёт вместо команды.
- **`false` или ничего.** Не отправлять ничего.
- **Promise (`async`).** Команда не уйдёт, а результат отправится, когда будет готов.
- **Ошибку (`throw`).** Покажется тост ⚠️, а ошибка попадёт в журнал.

### Поля сообщения
| Поле | Что это |
|---|---|
| `id` | id сообщения |
| `chatId` | id чата, строка |
| `chatType` | `private`, `group`, `channel`, `secret` или `saved` |
| `chatTitle` | название чата |
| `fromId`, `fromUserId` | id автора |
| `fromName`, `fromUsername` | имя и юзернейм автора |
| `fromIsBot` | автор — бот |
| `text` | текст сообщения |
| `date` | время, unix |
| `out` | исходящее |
| `muted` | чат без звука |
| `replyTo` | id сообщения, на которое ответили |
| `media` | `photo`, `video`, `voice`, `round`, `sticker`, `music`, `file` или `''` |

## Ограничения
- Плагины работают, пока GhostGram открыт или недавно свёрнут: iOS усыпляет фоновые приложения. Уведомления с `delay` приходят и в закрытом приложении.
- Плагины не меняют внешний вид экранов. Это делается только сборкой.
- Каждый плагин работает в своей песочнице. Ошибка одного не ломает остальные.
