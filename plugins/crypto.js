// @id crypto
// @name Крипта
// @version 1.0
// @author GhostGram
// @description .crypto btc — цена монеты в долларах и рублях и изменение за сутки. Понимает btc, eth, ton, usdt, sol, doge, bnb, xrp, trx, ltc, not.

var coins = {
  btc: 'bitcoin', eth: 'ethereum', ton: 'the-open-network', usdt: 'tether', sol: 'solana',
  doge: 'dogecoin', bnb: 'binancecoin', xrp: 'ripple', trx: 'tron', ltc: 'litecoin', not: 'notcoin'
};

function money(value, sign) {
  var digits = value >= 100 ? 0 : value >= 1 ? 2 : 6;
  return Number(value.toFixed(digits)).toLocaleString('ru-RU') + ' ' + sign;
}

GG.command('.crypto', async function (args) {
  var tickers = (args || 'btc').toLowerCase().split(/[\s,]+/).filter(Boolean);
  var ids = tickers.map(function (t) { return coins[t] || t; });
  var response = await GG.fetch('https://api.coingecko.com/api/v3/simple/price?ids=' + ids.join(',') + '&vs_currencies=usd,rub&include_24hr_change=true', { timeout: 15 });
  var data = await response.json();
  var lines = [];
  tickers.forEach(function (ticker, i) {
    var row = data[ids[i]];
    if (!row) return;
    var change = row.usd_24h_change;
    var arrow = change >= 0 ? '📈 +' : '📉 ';
    lines.push('🪙 ' + ticker.toUpperCase() + ': ' + money(row.usd, '$') + ' · ' + money(row.rub, '₽') + (change !== undefined ? '  ' + arrow + change.toFixed(2) + '%' : ''));
  });
  if (!lines.length) throw new Error('не знаю монету ' + tickers.join(', '));
  return lines.join('\n');
}, 'цена криптовалюты (.crypto btc eth)');
