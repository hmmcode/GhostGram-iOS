// @id fonts
// @name Шрифты и приколы с текстом
// @version 1.0
// @author GhostGram
// @description .wide, .flip, .mock, .rev, .strike, .under, .zalgo, .small — превращают текст перед отправкой.

var flipMap = {
  a: 'ɐ', b: 'q', c: 'ɔ', d: 'p', e: 'ǝ', f: 'ɟ', g: 'ƃ', h: 'ɥ', i: 'ᴉ', j: 'ɾ', k: 'ʞ', l: 'l', m: 'ɯ', n: 'u',
  o: 'o', p: 'd', q: 'b', r: 'ɹ', s: 's', t: 'ʇ', u: 'n', v: 'ʌ', w: 'ʍ', x: 'x', y: 'ʎ', z: 'z',
  'а': 'ɐ', 'б': 'ƍ', 'в': 'ʚ', 'г': 'ɹ', 'д': 'ɓ', 'е': 'ǝ', 'ё': 'ǝ', 'ж': 'ж', 'з': 'ε', 'и': 'и', 'й': 'ņ',
  'к': 'ʞ', 'л': 'v', 'м': 'w', 'н': 'н', 'о': 'о', 'п': 'u', 'р': 'd', 'с': 'ɔ', 'т': 'ɯ', 'у': 'ʎ', 'ф': 'ф',
  'х': 'х', 'ц': 'ǹ', 'ч': 'Һ', 'ш': 'm', 'щ': 'm', 'ъ': 'q', 'ы': 'ıq', 'ь': 'q', 'э': 'є', 'ю': 'oı', 'я': 'ʁ',
  '.': '˙', ',': "'", '?': '¿', '!': '¡', '(': ')', ')': '(', '[': ']', ']': '[', '<': '>', '>': '<', '_': '‾',
  '1': 'Ɩ', '2': 'ᄅ', '3': 'Ɛ', '4': 'ㄣ', '5': 'ϛ', '6': '9', '7': 'ㄥ', '8': '8', '9': '6', '0': '0'
};
var smallMap = {
  a: 'ᴀ', b: 'ʙ', c: 'ᴄ', d: 'ᴅ', e: 'ᴇ', f: 'ꜰ', g: 'ɢ', h: 'ʜ', i: 'ɪ', j: 'ᴊ', k: 'ᴋ', l: 'ʟ', m: 'ᴍ', n: 'ɴ',
  o: 'ᴏ', p: 'ᴘ', q: 'ǫ', r: 'ʀ', s: 's', t: 'ᴛ', u: 'ᴜ', v: 'ᴠ', w: 'ᴡ', x: 'x', y: 'ʏ', z: 'ᴢ'
};
var zalgoMarks = ['̍', '̎', '̄', '̅', '̿', '̑', '̆', '̐', '͒', '͗', '͑', '̇', '̈', '̊', '͂', '̓', '̈́', '͊', '͋', '͌', '̃', '̂', '̌', '͐', '̀', '́', '̋', '̏', '̒', '̓', '̔', '̽', '̉', 'ͣ', 'ͤ', 'ͥ', 'ͦ', 'ͧ', 'ͨ', 'ͩ', '̖', '̗', '̘', '̙', '̜', '̝', '̞', '̟', '̠', '̤', '̥', '̦', '̩', '̪', '̫', '̬', '̭', '̮', '̯', '̰', '̱', '̲', '̳', '̹', '̺', '̻', '̼'];

function chars(text) { return Array.from(text); }

function need(args, example) {
  if (!args) {
    GG.toast('Пример: ' + example);
    return false;
  }
  return true;
}

GG.command('.wide', function (args) {
  if (!need(args, '.wide hello')) return false;
  return chars(args).map(function (c) {
    var code = c.charCodeAt(0);
    if (c === ' ') return '　';
    if (code >= 33 && code <= 126) return String.fromCharCode(code + 0xFEE0);
    return c;
  }).join('');
}, 'ｓｈｉｒｏｋｉｊ текст');

GG.command('.flip', function (args) {
  if (!need(args, '.flip привет')) return false;
  return chars(args).map(function (c) {
    var lower = c.toLowerCase();
    return flipMap[lower] !== undefined ? flipMap[lower] : c;
  }).reverse().join('');
}, 'перевернуть текст');

GG.command('.mock', function (args) {
  if (!need(args, '.mock ну конечно')) return false;
  var upper = false;
  return chars(args).map(function (c) {
    if (c.toLowerCase() === c.toUpperCase()) return c;
    upper = !upper;
    return upper ? c.toUpperCase() : c.toLowerCase();
  }).join('');
}, 'нУ кОнЕчНо');

GG.command('.rev', function (args) {
  if (!need(args, '.rev текст')) return false;
  return chars(args).reverse().join('');
}, 'текст задом наперёд');

GG.command('.strike', function (args) {
  if (!need(args, '.strike текст')) return false;
  return chars(args).map(function (c) { return c === ' ' ? c : c + '̶'; }).join('');
}, 'з̶а̶ч̶ё̶р̶к̶н̶у̶т̶ь̶');

GG.command('.under', function (args) {
  if (!need(args, '.under текст')) return false;
  return chars(args).map(function (c) { return c === ' ' ? c : c + '̲'; }).join('');
}, 'п̲о̲д̲ч̲е̲р̲к̲н̲у̲т̲ь̲');

GG.command('.small', function (args) {
  if (!need(args, '.small hello')) return false;
  return chars(args).map(function (c) {
    var lower = c.toLowerCase();
    return smallMap[lower] || c;
  }).join('');
}, 'ᴍᴀʟᴇɴᴋɪᴇ ʙᴜᴋᴠʏ (латиница)');

GG.command('.zalgo', function (args) {
  if (!need(args, '.zalgo ужас')) return false;
  return chars(args).map(function (c) {
    if (c === ' ') return c;
    var out = c;
    var count = 2 + Math.floor(Math.random() * 5);
    for (var i = 0; i < count; i++) out += zalgoMarks[Math.floor(Math.random() * zalgoMarks.length)];
    return out;
  }).join('');
}, 'з̴̛а̷͝л̶̈́г̸͠о̵̾');
