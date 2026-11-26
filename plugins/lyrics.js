// @id lyrics
// @name Текст песни
// @version 1.0
// @author GhostGram
// @description .lyrics исполнитель - песня — отправит текст песни из открытой базы LRCLIB. .lyricsme — покажет текст только тебе.

async function find(query) {
  var response = await GG.fetch('https://lrclib.net/api/search?q=' + encodeURIComponent(query), { timeout: 15, headers: { 'User-Agent': 'GhostGram plugin' } });
  var list = await response.json();
  for (var i = 0; i < (list || []).length; i++) {
    var item = list[i];
    var text = item.plainLyrics || (item.syncedLyrics || '').replace(/^\[[^\]]*\]\s*/gm, '');
    if (text && text.trim()) return { title: item.artistName + ' — ' + item.trackName, text: text.trim() };
  }
  return null;
}

GG.command('.lyrics', async function (args) {
  if (!args) {
    GG.toast('Пример: .lyrics Кино - Группа крови');
    return false;
  }
  var song = await find(args);
  if (!song) throw new Error('не нашёл текст «' + args + '»');
  var text = song.text.length > 3500 ? song.text.slice(0, 3500) + '\n…' : song.text;
  return '🎵 ' + song.title + '\n\n' + text;
}, 'отправить текст песни');

GG.command('.lyricsme', async function (args) {
  if (!args) {
    GG.toast('Пример: .lyricsme Кино - Группа крови');
    return false;
  }
  var song = await find(args);
  if (!song) throw new Error('не нашёл текст «' + args + '»');
  GG.alert(song.title, song.text);
  return false;
}, 'показать текст только себе');
