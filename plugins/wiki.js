// @id wiki
// @name Википедия
// @version 1.0
// @author GhostGram
// @description .wiki запрос — отправит короткую справку из Википедии со ссылкой. Язык в настройках.

GG.settings([
  { key: 'lang', title: 'Язык Википедии', type: 'choice', default: 'ru', options: ['ru', 'en', 'uk', 'de'] }
]);

async function summary(lang, title) {
  var response = await GG.fetch('https://' + lang + '.wikipedia.org/api/rest_v1/page/summary/' + encodeURIComponent(title.replace(/ /g, '_')), { timeout: 15 });
  if (!response.ok) return null;
  var data = await response.json();
  if (!data || !data.extract || data.type === 'disambiguation') return null;
  return data;
}

GG.command('.wiki', async function (args) {
  var query = (args || '').trim();
  if (!query) {
    GG.toast('Пример: .wiki Чёрная дыра');
    return false;
  }
  var lang = GG.setting('lang') || 'ru';
  var page = await summary(lang, query);
  if (!page) {
    var search = await GG.fetch('https://' + lang + '.wikipedia.org/w/api.php?action=opensearch&limit=1&format=json&search=' + encodeURIComponent(query), { timeout: 15 });
    var found = await search.json();
    if (found && found[1] && found[1][0]) page = await summary(lang, found[1][0]);
  }
  if (!page) throw new Error('ничего не нашёл про «' + query + '»');
  var extract = page.extract.length > 900 ? page.extract.slice(0, 900).replace(/\s+\S*$/, '') + '…' : page.extract;
  var link = page.content_urls && page.content_urls.mobile ? page.content_urls.mobile.page : '';
  return '📖 ' + page.title + '\n\n' + extract + (link ? '\n\n' + link : '');
}, 'справка из Википедии');
