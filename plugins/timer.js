// @id timer
// @name Напоминалки
// @version 1.0
// @author GhostGram
// @description .timer 10m купить хлеб — пришлёт уведомление через 10 минут, даже если GhostGram закрыт. Единицы: s, m, h, d (или с, м, ч, д).

var units = { s: 1, 'с': 1, sec: 1, 'сек': 1, m: 60, 'м': 60, min: 60, 'мин': 60, h: 3600, 'ч': 3600, 'час': 3600, d: 86400, 'д': 86400, 'дн': 86400 };

function parseDelay(token) {
  var match = /^(\d+(?:[.,]\d+)?)([a-zа-я]*)$/i.exec(token || '');
  if (!match) return 0;
  var value = parseFloat(match[1].replace(',', '.'));
  var unit = (match[2] || 'm').toLowerCase();
  return units[unit] ? Math.round(value * units[unit]) : 0;
}

function human(seconds) {
  if (seconds < 60) return seconds + ' сек';
  if (seconds < 3600) return Math.round(seconds / 60) + ' мин';
  if (seconds < 86400) return (Math.round(seconds / 360) / 10) + ' ч';
  return (Math.round(seconds / 8640) / 10) + ' дн';
}

GG.command('.timer', function (args, msg) {
  var parts = args.split(/\s+/);
  var seconds = parseDelay(parts[0]);
  if (!seconds) {
    GG.toast('Пример: .timer 25m перерыв');
    return false;
  }
  var text = parts.slice(1).join(' ') || 'Время вышло';
  var id = String(Date.now());
  GG.notify('⏰ Напоминание', text + (msg.chatTitle ? ' · ' + msg.chatTitle : ''), { delay: seconds, id: id });
  var list = GG.storage.get('list', []);
  list.push({ id: id, at: GG.now() + seconds, text: text });
  GG.storage.set('list', list.filter(function (item) { return item.at > GG.now(); }));
  GG.toast('⏰ Напомню через ' + human(seconds));
  return false;
}, 'напомнить через время');

GG.command('.timers', function () {
  var list = GG.storage.get('list', []).filter(function (item) { return item.at > GG.now(); });
  GG.alert('⏰ Напоминания', list.length ? list.map(function (item) {
    return '• через ' + human(item.at - GG.now()) + ': ' + item.text;
  }).join('\n') : 'Нет активных напоминаний');
  return false;
}, 'список напоминаний');

GG.action('Отменить все напоминания', function () {
  GG.storage.get('list', []).forEach(function (item) { GG.cancelNotify(item.id); });
  GG.storage.set('list', []);
  GG.toast('Напоминания отменены');
});
