// @id layout
// @name Раскладка
// @version 1.0
// @author GhostGram
// @description .fix ghbdtn → «привет»: исправит текст, набранный не в той раскладке. .fixen — наоборот. Можно включить автоисправление своих сообщений.

GG.settings([
  { key: 'auto', title: 'Исправлять мои сообщения сами', type: 'bool', default: false, hint: 'Если всё сообщение набрано латиницей и похоже на русский в английской раскладке' }
]);

var en = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>~";
var ru = 'йцукенгшщзхъфывапролджэячсмитьбюёЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ';

function convert(text, from, to) {
  var out = '';
  for (var i = 0; i < text.length; i++) {
    var index = from.indexOf(text[i]);
    out += index >= 0 ? to[index] : text[i];
  }
  return out;
}

// Latin text with no vowels in a row and few real English letter pairs is most likely Russian.
function looksWrong(text) {
  if (!/^[a-z\[\];',.`\s!?0-9-]+$/i.test(text) || text.length < 4) return false;
  if (/\b(the|and|you|is|are|ok|lol|hi|hello|thanks|yes|no|what|why)\b/i.test(text)) return false;
  var converted = convert(text, en, ru);
  var russianVowels = (converted.match(/[аеёиоуыэюя]/gi) || []).length;
  var letters = (converted.match(/[а-яё]/gi) || []).length;
  return letters > 0 && russianVowels / letters > 0.28 && russianVowels / letters < 0.6;
}

GG.command('.fix', function (args) {
  if (!args) {
    GG.toast('Пример: .fix ghbdtn rfr ltkf');
    return false;
  }
  return convert(args, en, ru);
}, 'из латиницы в русскую раскладку');

GG.command('.fixen', function (args) {
  if (!args) {
    GG.toast('Пример: .fixen руддщ');
    return false;
  }
  return convert(args, ru, en);
}, 'из русской раскладки в латиницу');

GG.on('outgoing', function (msg) {
  if (!GG.setting('auto') || !msg.text || msg.text[0] === '.') return undefined;
  return looksWrong(msg.text) ? convert(msg.text, en, ru) : undefined;
});
