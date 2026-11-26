// @id stats
// @name Моя статистика
// @version 1.0
// @author GhostGram
// @description Считает, сколько ты пишешь: сообщения и слова за сегодня, неделю и всё время, самые активные чаты. .stats — посмотреть (видишь только ты).

function day(offset) {
  var d = new Date(Date.now() - (offset || 0) * 86400000);
  return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
}

GG.on('outgoing', function (msg) {
  if (!msg.text || msg.text[0] === '.') return undefined;
  var words = msg.text.trim().split(/\s+/).filter(Boolean).length;
  var days = GG.storage.get('days', {});
  var today = day(0);
  var entry = days[today] || { m: 0, w: 0 };
  entry.m += 1;
  entry.w += words;
  days[today] = entry;
  var keep = {};
  for (var i = 0; i < 31; i++) {
    if (days[day(i)]) keep[day(i)] = days[day(i)];
  }
  GG.storage.set('days', keep);
  var chats = GG.storage.get('chats', {});
  var title = msg.chatTitle || msg.chatId;
  chats[title] = (chats[title] || 0) + 1;
  GG.storage.set('chats', chats);
  GG.storage.set('total', GG.storage.get('total', 0) + 1);
  GG.storage.set('totalWords', GG.storage.get('totalWords', 0) + words);
  return undefined;
});

function report() {
  var days = GG.storage.get('days', {});
  var todayEntry = days[day(0)] || { m: 0, w: 0 };
  var week = { m: 0, w: 0 };
  for (var i = 0; i < 7; i++) {
    var e = days[day(i)];
    if (e) { week.m += e.m; week.w += e.w; }
  }
  var chats = GG.storage.get('chats', {});
  var top = Object.keys(chats).sort(function (a, b) { return chats[b] - chats[a]; }).slice(0, 5);
  var lines = [
    'Сегодня: ' + todayEntry.m + ' сообщ., ' + todayEntry.w + ' слов',
    'За неделю: ' + week.m + ' сообщ., ' + week.w + ' слов',
    'Всего: ' + GG.storage.get('total', 0) + ' сообщ., ' + GG.storage.get('totalWords', 0) + ' слов'
  ];
  if (top.length) {
    lines.push('');
    lines.push('Чаще всего пишешь:');
    top.forEach(function (name, i) { lines.push((i + 1) + '. ' + name + ' — ' + chats[name]); });
  }
  return lines.join('\n');
}

GG.command('.stats', function () {
  GG.alert('📊 Моя статистика', report());
  return false;
}, 'сколько я пишу (видно только тебе)');

GG.action('Показать статистику', function () {
  GG.alert('📊 Моя статистика', report());
});

GG.action('Сбросить', function () {
  ['days', 'chats', 'total', 'totalWords'].forEach(function (k) { GG.storage.remove(k); });
  GG.toast('Статистика сброшена');
});
