// @id keywords
// @name Слежка за словами
// @version 1.0
// @author GhostGram
// @description Пришлёт уведомление, если в любом чате (даже без звука) написали твоё слово: ник, имя, «срочно» и т.д.

GG.settings([
  { key: 'words', title: 'Слова через запятую', type: 'text', default: 'срочно', hint: 'например: денис, ден, срочно' },
  { key: 'mutedOnly', title: 'Только чаты без звука', type: 'bool', default: false },
  { key: 'groupsOnly', title: 'Только группы и каналы', type: 'bool', default: false }
]);

function words() {
  return String(GG.setting('words') || '').split(',').map(function (w) { return w.trim().toLowerCase(); }).filter(Boolean);
}

GG.on('message', function (msg) {
  if (msg.out || !msg.text) return;
  if (GG.setting('mutedOnly') && !msg.muted) return;
  if (GG.setting('groupsOnly') && msg.chatType === 'private') return;
  var text = msg.text.toLowerCase();
  var hit = words().filter(function (w) { return text.indexOf(w) >= 0; })[0];
  if (!hit) return;
  var preview = msg.text.length > 140 ? msg.text.slice(0, 140) + '…' : msg.text;
  GG.notify('🔔 «' + hit + '» · ' + msg.chatTitle, (msg.chatType === 'private' ? '' : msg.fromName + ': ') + preview);
});

GG.command('.watch', function (args) {
  if (!args) {
    GG.alert('Слежу за словами', words().join(', ') || 'пусто');
    return false;
  }
  var list = words();
  args.split(',').forEach(function (w) {
    w = w.trim().toLowerCase();
    if (w && list.indexOf(w) < 0) list.push(w);
  });
  GG.setSetting('words', list.join(', '));
  GG.toast('Слежу: ' + list.join(', '));
  return false;
}, 'добавить слово для слежки');
