// @id wave
// @name Рисунок в голосовом
// @version 1.0
// @author GhostGram
// @description Голосовое без звука, но с нарисованной волной: .heart, .wave пульс, .wave горы, свои цифры. Нужна версия GhostGram v11+.

var N = 100; // столько столбиков хранит Telegram

GG.settings([
  { key: 'seconds', title: 'Длина голосового (сек)', type: 'number', default: 7, hint: 'Чем длиннее, тем шире пузырь' }
]);

function clamp(v) { return Math.max(0, Math.min(31, Math.round(v))); }

function build(fn) {
  var out = [];
  for (var i = 0; i < N; i++) out.push(clamp(fn(i / (N - 1))));
  return out;
}

// t — от 0 до 1 по ширине пузыря, результат — высота 0..31
var SHAPES = {
  'сердце': function (t) {
    var x = (t - 0.5) * 2.4;                 // от -1.2 до 1.2
    var ax = Math.abs(x);
    if (ax > 1.15) return 1;
    var hump = Math.sqrt(Math.max(0, 1 - Math.pow(ax / 0.55 - 1, 2))); // две «половинки»
    var body = 1 - Math.pow(ax / 1.15, 1.6);                           // спадает к краям
    return 4 + 27 * Math.max(0, 0.55 * hump + 0.45 * body - (ax < 0.3 ? 0.55 * Math.pow(1 - ax / 0.3, 0.8) : 0));
  },
  'пульс': function (t) {
    var beat = (t * 3) % 1;                    // три удара
    if (beat > 0.30 && beat < 0.36) return 9;  // P
    if (beat > 0.44 && beat < 0.47) return 0;  // Q
    if (beat >= 0.47 && beat < 0.52) return 31; // R
    if (beat >= 0.52 && beat < 0.55) return 0; // S
    if (beat > 0.66 && beat < 0.76) return 11; // T
    return 3;
  },
  'горы': function (t) {
    return 4 + 27 * Math.max(0, Math.max(1 - Math.abs(t - 0.3) / 0.25, 0.75 - Math.abs(t - 0.68) / 0.22, 0.45 - Math.abs(t - 0.9) / 0.1));
  },
  'волна': function (t) { return 16 + 14 * Math.sin(t * Math.PI * 6); },
  'пирамида': function (t) { return 31 * (1 - Math.abs(t - 0.5) * 2); },
  'лесенка': function (t) { return Math.floor(t * 8) * 4.4; },
  'ровно': function () { return 31; },
  'пусто': function () { return 0; },
  'бит': function (t) { var i = Math.floor(t * N); return (i % 4 === 0) ? 31 : 4 + (i * 7919 % 13); },
  'зубья': function (t) { return Math.floor(t * N) % 2 ? 2 : 31; }
};
var ALIASES = { heart: 'сердце', '❤️': 'сердце', '♥': 'сердце', pulse: 'пульс', экг: 'пульс', mountains: 'горы',
  sine: 'волна', wave: 'волна', pyramid: 'пирамида', stairs: 'лесенка', full: 'ровно', empty: 'пусто', beat: 'бит', saw: 'зубья' };

function seconds(arg) {
  var s = parseInt(arg, 10);
  if (!(s > 0)) s = Number(GG.setting('seconds')) || 7;
  return Math.max(1, Math.min(600, s));
}

function sendShape(msg, name, secArg) {
  msg.voice(build(SHAPES[name]), { duration: seconds(secArg) });
  return null; // текст команды не отправляем
}

GG.command('.heart', function (args, msg) { return sendShape(msg, 'сердце', args); }, 'голосовое с сердечком (.heart 10 — на 10 сек)');

GG.command('.wave', function (args, msg) {
  var parts = args.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) {
    GG.alert('Рисунок в голосовом', 'Формы: ' + Object.keys(SHAPES).join(', ') +
      '\n\nПримеры:\n.wave пульс\n.wave горы 15\n.heart\n\nСвоя волна — цифры 0..31:\n.wave 0 10 20 31 20 10 0');
    return null;
  }
  if (/^\d+$/.test(parts[0]) && parts.length >= 3) {
    var bars = parts.map(Number).filter(function (n) { return !isNaN(n); });
    // растягиваем до 100 столбиков, чтобы рисунок был во всю ширину
    var wide = build(function (t) { return bars[Math.min(bars.length - 1, Math.floor(t * bars.length))]; });
    msg.voice(wide, { duration: seconds() });
    return null;
  }
  var name = parts[0].toLowerCase();
  name = ALIASES[name] || name;
  if (!SHAPES[name]) {
    GG.toast('Нет формы «' + parts[0] + '». Напиши .wave — покажу список');
    return null;
  }
  return sendShape(msg, name, parts[1]);
}, 'нарисовать волну в голосовом (.wave — список форм)');
