// @id weather
// @name Погода
// @version 1.0
// @author GhostGram
// @description .weather Москва — отправит погоду сейчас. Без города берёт город из настроек.

GG.settings([
  { key: 'city', title: 'Город по умолчанию', type: 'text', default: 'Москва' }
]);

GG.command('.weather', async function (args, msg) {
  var city = args || GG.setting('city') || 'Москва';
  var url = 'https://wttr.in/' + encodeURIComponent(city) + '?format=' + encodeURIComponent('%l: %c %t (ощущается %f), ветер %w, влажность %h') + '&lang=ru&m';
  var response = await GG.fetch(url, { timeout: 15 });
  var text = (await response.text()).trim();
  if (!response.ok || !text || text.indexOf('<') === 0 || /unknown location/i.test(text)) {
    throw new Error('не нашёл город «' + city + '»');
  }
  return '🌤 ' + text;
}, 'погода в городе');

GG.command('.погода', function (args, msg) {
  return GG.fetch('https://wttr.in/' + encodeURIComponent(args || GG.setting('city') || 'Москва') + '?format=' + encodeURIComponent('%l: %c %t (ощущается %f), ветер %w') + '&lang=ru&m', { timeout: 15 })
    .then(function (r) { return r.text(); })
    .then(function (t) {
      t = t.trim();
      if (!t || t.indexOf('<') === 0 || /unknown location/i.test(t)) throw new Error('город не найден');
      return '🌤 ' + t;
    });
}, 'то же самое по-русски');
