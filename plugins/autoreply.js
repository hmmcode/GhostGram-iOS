// @id autoreply
// @name Автоответчик
// @version 1.0
// @author GhostGram
// @description Отвечает в личке, пока ты занят. .afk [текст] — включить, .back — выключить. Работает, пока GhostGram открыт или недавно свёрнут.

GG.settings([
  { key: 'enabled', title: 'Автоответчик включён', type: 'bool', default: false },
  { key: 'text', title: 'Текст ответа', type: 'text', default: 'Привет! Сейчас не могу ответить, напишу позже 👻' },
  { key: 'cooldown', title: 'Не чаще, чем раз в (мин)', type: 'number', default: 30 },
  { key: 'contactsOnly', title: 'Только люди (не боты)', type: 'bool', default: true },
  { key: 'includeMuted', title: 'Отвечать и в чатах без звука', type: 'bool', default: false }
]);

function setEnabled(on, text) {
  GG.setSetting('enabled', on);
  if (text) GG.setSetting('text', text);
  if (on) GG.storage.set('replied', {});
  GG.toast(on ? '🌙 Автоответчик включён' : '☀️ Автоответчик выключен');
}

GG.command('.afk', function (args) {
  setEnabled(true, args);
  return false;
}, 'включить автоответчик (можно сразу с текстом)');

GG.command('.back', function () {
  setEnabled(false);
  return false;
}, 'выключить автоответчик');

GG.action('Включить / выключить', function () {
  setEnabled(!GG.setting('enabled'));
});

GG.on('message', function (msg) {
  if (!GG.setting('enabled')) return;
  if (msg.out || msg.chatType !== 'private') return;
  if (GG.setting('contactsOnly') && msg.fromIsBot) return;
  if (msg.muted && !GG.setting('includeMuted')) return;
  if (GG.now() - msg.date > 120) return; // old messages that arrived after reconnecting

  var replied = GG.storage.get('replied', {});
  var cooldown = Math.max(0, Number(GG.setting('cooldown')) || 0) * 60;
  var last = replied[msg.chatId] || 0;
  if (GG.now() - last < cooldown) return;
  replied[msg.chatId] = GG.now();
  GG.storage.set('replied', replied);

  msg.reply(String(GG.setting('text') || 'Сейчас не могу ответить'));
  GG.log('Ответил: ' + msg.chatTitle);
});
