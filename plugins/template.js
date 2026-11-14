// @id my-plugin
// @name Мой плагин (шаблон)
// @version 1.0
// @author я
// @description Шаблон: покажет, как устроены команды, события, настройки и кнопки. .hello — проверка.

// Настройки появятся на экране плагина в GhostGram → Плагины.
GG.settings([
  { key: 'greeting', title: 'Приветствие', type: 'text', default: 'Привет из плагина 👻' },
  { key: 'loud', title: 'Капсом', type: 'bool', default: false }
]);

// Команда: напиши «.hello Вася» в любом чате — уйдёт то, что вернёт функция.
// Вернуть строку — отправить её вместо команды; false — ничего не отправлять.
GG.command('.hello', function (args, msg) {
  var text = GG.setting('greeting') + (args ? ', ' + args : '');
  return GG.setting('loud') ? text.toUpperCase() : text;
}, 'поздороваться');

// Входящие сообщения (только пока GhostGram открыт или недавно свёрнут).
GG.on('message', function (msg) {
  if (msg.text === 'пинг' && msg.chatType === 'private') {
    msg.reply('понг 🏓');
  }
});

// Кнопка на экране плагина.
GG.action('Показать, кто я', function () {
  var me = GG.me();
  GG.alert('Это ты', me ? me.name + ' (id ' + me.id + ')' : 'аккаунт ещё не загрузился');
});

GG.log('Шаблон запущен');
