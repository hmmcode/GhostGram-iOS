// @id currency
// @name Курсы валют
// @version 1.0
// @author GhostGram
// @description .rate 100 usd rub — пересчитает и отправит. .rate usd — курс к рублю. Курсы обновляются раз в сутки.

var aliases = {
  'доллар': 'USD', 'долларов': 'USD', 'доллара': 'USD', '$': 'USD', 'бакс': 'USD', 'баксов': 'USD',
  'евро': 'EUR', '€': 'EUR', 'рубль': 'RUB', 'рублей': 'RUB', 'рубля': 'RUB', 'руб': 'RUB', '₽': 'RUB',
  'гривна': 'UAH', 'гривен': 'UAH', 'грн': 'UAH', 'тенге': 'KZT', 'юань': 'CNY', 'юаней': 'CNY',
  'фунт': 'GBP', 'лира': 'TRY', 'лир': 'TRY', 'btc': 'BTC'
};

function code(word) {
  if (!word) return null;
  var lower = word.toLowerCase();
  if (aliases[lower]) return aliases[lower];
  return /^[a-z]{3}$/i.test(word) ? word.toUpperCase() : null;
}

async function rates(base) {
  var cached = GG.storage.get('rates:' + base);
  if (cached && GG.now() - cached.time < 6 * 3600) return cached.rates;
  var response = await GG.fetch('https://open.er-api.com/v6/latest/' + base, { timeout: 15 });
  var data = await response.json();
  if (data.result !== 'success') throw new Error('нет курса для ' + base);
  GG.storage.set('rates:' + base, { time: GG.now(), rates: data.rates });
  return data.rates;
}

function money(value) {
  var digits = value >= 100 ? 2 : value >= 1 ? 3 : 6;
  return Number(value.toFixed(digits)).toLocaleString('ru-RU');
}

GG.command('.rate', async function (args) {
  var parts = args.replace(/,/g, '.').split(/\s+/).filter(Boolean);
  var amount = 1;
  if (parts.length && !isNaN(parseFloat(parts[0]))) amount = parseFloat(parts.shift());
  if (parts[0] && /^(в|to|in)$/i.test(parts[1] || '')) parts.splice(1, 1);
  var from = code(parts[0]) || 'USD';
  var to = code(parts[1]) || (from === 'RUB' ? 'USD' : 'RUB');
  var table = await rates(from);
  if (!table[to]) throw new Error('не знаю валюту ' + to);
  return '💱 ' + money(amount) + ' ' + from + ' = ' + money(amount * table[to]) + ' ' + to;
}, 'пересчитать валюту');
