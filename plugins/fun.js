// @id fun
// @name Рандом
// @version 1.0
// @author GhostGram
// @description .roll, .coin, .choose a | b | c, .8ball вопрос, .rnd 1 100.

function pick(list) { return list[Math.floor(Math.random() * list.length)]; }

GG.command('.roll', function (args) {
  var sides = Math.max(2, parseInt(args, 10) || 6);
  return '🎲 ' + (1 + Math.floor(Math.random() * sides)) + ' из ' + sides;
}, 'бросить кубик (.roll 20)');

GG.command('.coin', function () {
  return '🪙 ' + pick(['Орёл', 'Решка']);
}, 'орёл или решка');

GG.command('.rnd', function (args) {
  var nums = args.split(/[\s-]+/).map(function (n) { return parseInt(n, 10); }).filter(function (n) { return !isNaN(n); });
  var min = nums.length > 1 ? Math.min(nums[0], nums[1]) : 1;
  var max = nums.length > 1 ? Math.max(nums[0], nums[1]) : (nums[0] || 100);
  return '🔢 ' + (min + Math.floor(Math.random() * (max - min + 1))) + ' (' + min + '–' + max + ')';
}, 'случайное число (.rnd 1 100)');

GG.command('.choose', function (args) {
  var options = args.split(/\s*(?:\||,|\bили\b|\bor\b)\s*/i).filter(Boolean);
  if (options.length < 2) {
    GG.toast('Пример: .choose пицца | суши | бургер');
    return false;
  }
  return '🤔 ' + options.join(' / ') + '\n👉 ' + pick(options);
}, 'выбрать вариант');

GG.command('.8ball', function (args) {
  var answers = ['Бесспорно', 'Однозначно да', 'Без сомнений', 'Скорее да', 'Знаки говорят — да', 'Пока неясно, спроси позже',
    'Лучше не рассказывать', 'Сосредоточься и спроси снова', 'Даже не думай', 'Мой ответ — нет', 'Весьма сомнительно', 'Перспективы не очень'];
  return (args ? '❓ ' + args + '\n' : '') + '🎱 ' + pick(answers);
}, 'магический шар');
