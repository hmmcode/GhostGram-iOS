// @id translate
// @name Переводчик
// @version 1.0
// @author GhostGram
// @description .tr en привет — отправит перевод. .tr текст — переведёт на язык из настроек. Коды: en, ru, uk, de, es, fr, tr, zh, ja…

GG.settings([
  { key: 'lang', title: 'Язык по умолчанию', type: 'choice', default: 'en', options: ['en', 'ru', 'uk', 'de', 'es', 'fr', 'it', 'pl', 'tr', 'zh', 'ja', 'ko', 'ar'] },
  { key: 'withOriginal', title: 'Добавлять оригинал', type: 'bool', default: false }
]);

async function translate(text, target) {
  var url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&dt=t&tl=' + encodeURIComponent(target) + '&q=' + encodeURIComponent(text);
  var response = await GG.fetch(url, { timeout: 15 });
  if (!response.ok) throw new Error('переводчик ответил ' + response.status);
  var data = await response.json();
  return (data[0] || []).map(function (part) { return part[0]; }).join('');
}

GG.command('.tr', async function (args) {
  var match = /^([a-z]{2}(?:-[a-z]{2})?)\s+([\s\S]+)$/i.exec(args);
  var target = match ? match[1].toLowerCase() : GG.setting('lang') || 'en';
  var text = match ? match[2] : args;
  if (!text) throw new Error('пример: .tr en привет');
  var result = await translate(text, target);
  return GG.setting('withOriginal') ? result + '\n\n(' + text + ')' : result;
}, 'перевести и отправить');

GG.command('.trc', function (args) {
  translate(args, 'ru').then(function (result) { GG.alert('Перевод', result); }, function (e) { GG.toast('⚠️ ' + e.message); });
  return false;
}, 'перевести на русский, не отправляя');
