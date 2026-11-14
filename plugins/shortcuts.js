// @id shortcuts
// @name Сокращения
// @version 1.0
// @author GhostGram
// @description Сам разворачивает сокращения в твоих сообщениях: «спс» → «спасибо». Список меняется в настройках или командой .short спс=спасибо.

GG.settings([
  { key: 'map', title: 'Сокращения', type: 'text', default: 'спс=спасибо, пж=пожалуйста, нзч=не за что, щас=сейчас', hint: 'формат: коротко=полностью, через запятую' }
]);

function table() {
  var result = {};
  String(GG.setting('map') || '').split(',').forEach(function (pair) {
    var index = pair.indexOf('=');
    if (index > 0) {
      var key = pair.slice(0, index).trim().toLowerCase();
      var value = pair.slice(index + 1).trim();
      if (key && value) result[key] = value;
    }
  });
  return result;
}

function escape(text) { return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

GG.on('outgoing', function (msg) {
  var map = table();
  var keys = Object.keys(map);
  if (!keys.length) return;
  var text = msg.text;
  keys.sort(function (a, b) { return b.length - a.length; }).forEach(function (key) {
    var pattern = new RegExp('(^|[^0-9A-Za-zА-Яа-яЁё_])(' + escape(key) + ')(?=$|[^0-9A-Za-zА-Яа-яЁё_])', 'gi');
    text = text.replace(pattern, function (all, before, word) {
      var full = map[key];
      if (word[0] !== word[0].toLowerCase()) full = full[0].toUpperCase() + full.slice(1);
      return before + full;
    });
  });
  return text === msg.text ? undefined : text;
});

GG.command('.short', function (args) {
  var index = args.indexOf('=');
  if (index <= 0) {
    var map = table();
    GG.alert('Сокращения', Object.keys(map).map(function (k) { return k + ' → ' + map[k]; }).join('\n') || 'пусто');
    return false;
  }
  var current = String(GG.setting('map') || '');
  GG.setSetting('map', (current ? current + ', ' : '') + args.trim());
  GG.toast('Добавлено: ' + args.trim());
  return false;
}, 'добавить сокращение (.short бб=бывай)');
