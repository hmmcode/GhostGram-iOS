// @id tools
// @name Инструменты
// @version 1.0
// @author GhostGram
// @description .qr текст — QR-код картинкой по ссылке. .link url — короткая ссылка. .ip 1.1.1.1 — страна и провайдер IP. .def word — значение английского слова. .b64 / .unb64 — Base64.

GG.command('.qr', function (args) {
  if (!args) {
    GG.toast('Пример: .qr https://t.me/durov');
    return false;
  }
  return '🔳 QR: https://api.qrserver.com/v1/create-qr-code/?size=512x512&margin=12&data=' + encodeURIComponent(args);
}, 'QR-код из текста или ссылки');

GG.command('.link', async function (args) {
  var url = (args || '').trim();
  if (!/^https?:\/\//i.test(url)) {
    GG.toast('Пример: .link https://example.com/очень/длинная/ссылка');
    return false;
  }
  var response = await GG.fetch('https://is.gd/create.php?format=simple&url=' + encodeURIComponent(url), { timeout: 15 });
  var text = (await response.text()).trim();
  if (!/^https?:\/\//.test(text)) throw new Error(text || 'сервис не ответил');
  return '🔗 ' + text;
}, 'сократить ссылку');

GG.command('.ip', async function (args) {
  var ip = (args || '').trim();
  if (!ip) {
    GG.toast('Пример: .ip 8.8.8.8');
    return false;
  }
  var response = await GG.fetch('https://ipwho.is/' + encodeURIComponent(ip) + '?lang=ru', { timeout: 15 });
  var d = await response.json();
  if (!d.success) throw new Error(d.message || 'не получилось');
  var parts = ['🌐 ' + d.ip, (d.flag && d.flag.emoji ? d.flag.emoji + ' ' : '') + [d.country, d.region, d.city].filter(Boolean).join(', ')];
  if (d.connection) parts.push('Провайдер: ' + [d.connection.isp, d.connection.org].filter(Boolean).join(' / '));
  if (d.timezone && d.timezone.id) parts.push('Часовой пояс: ' + d.timezone.id);
  return parts.join('\n');
}, 'информация об IP-адресе');

GG.command('.def', async function (args) {
  var word = (args || '').trim().toLowerCase();
  if (!word) {
    GG.toast('Пример: .def serendipity');
    return false;
  }
  var response = await GG.fetch('https://api.dictionaryapi.dev/api/v2/entries/en/' + encodeURIComponent(word), { timeout: 15 });
  var list = await response.json();
  if (!Array.isArray(list) || !list.length) throw new Error('нет такого слова: ' + word);
  var entry = list[0];
  var lines = ['📚 ' + entry.word + (entry.phonetic ? ' ' + entry.phonetic : '')];
  (entry.meanings || []).slice(0, 3).forEach(function (m) {
    var def = m.definitions && m.definitions[0];
    if (def) lines.push('• ' + m.partOfSpeech + ': ' + def.definition + (def.example ? '\n  «' + def.example + '»' : ''));
  });
  return lines.join('\n');
}, 'значение английского слова');

// JavaScriptCore has no btoa/atob, so Base64 is done by hand over UTF-8 bytes.
var ABC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function toBase64(text) {
  var bytes = unescape(encodeURIComponent(text));
  var out = '';
  for (var i = 0; i < bytes.length; i += 3) {
    var a = bytes.charCodeAt(i), b = bytes.charCodeAt(i + 1), c = bytes.charCodeAt(i + 2);
    var n = (a << 16) | ((b || 0) << 8) | (c || 0);
    out += ABC[(n >> 18) & 63] + ABC[(n >> 12) & 63] + (i + 1 < bytes.length ? ABC[(n >> 6) & 63] : '=') + (i + 2 < bytes.length ? ABC[n & 63] : '=');
  }
  return out;
}

function fromBase64(text) {
  var clean = text.replace(/[^A-Za-z0-9+/]/g, '');
  var bytes = '';
  for (var i = 0; i < clean.length; i += 4) {
    var n = (ABC.indexOf(clean[i]) << 18) | (ABC.indexOf(clean[i + 1]) << 12) | ((ABC.indexOf(clean[i + 2]) & 63) << 6) | (ABC.indexOf(clean[i + 3]) & 63);
    bytes += String.fromCharCode((n >> 16) & 255);
    if (i + 2 < clean.length) bytes += String.fromCharCode((n >> 8) & 255);
    if (i + 3 < clean.length) bytes += String.fromCharCode(n & 255);
  }
  return decodeURIComponent(escape(bytes));
}

GG.command('.b64', function (args) {
  if (!args) return false;
  return toBase64(args);
}, 'закодировать в Base64');

GG.command('.unb64', function (args) {
  if (!args) return false;
  try {
    return fromBase64(args.trim());
  } catch (e) {
    throw new Error('это не Base64');
  }
}, 'раскодировать Base64');
