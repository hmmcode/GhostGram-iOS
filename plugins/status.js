// @id status
// @name Свой статус
// @version 1.0
// @author GhostGram
// @description .status крутой 😎 — твой текст в строке статуса этого чата (в личках и группах). .statusdraft текст — живой черновик (только лички). .statusrotate a | b | c — меняет статусы по кругу. .status off — выключить. Нужна GhostGram v20+.

GG.settings([
  { key: 'interval', title: 'Смена статуса по кругу, секунд', type: 'number', default: 8 }
]);

var rotations = {};

function stop(chatId) {
  if (rotations[chatId]) {
    clearInterval(rotations[chatId]);
    delete rotations[chatId];
  }
}

GG.command('.status', function (args, msg) {
  stop(msg.chatId);
  if (!args || /^(off|выкл|стоп)$/i.test(args.trim())) {
    GG.status(msg.chatId, '');
    GG.toast('Статус выключен');
    return false;
  }
  GG.status(msg.chatId, args.trim());
  GG.toast('Статус: ' + args.trim());
  return false;
}, 'свой текст в статусе чата (.status off — выключить)');

GG.command('.statusdraft', function (args, msg) {
  stop(msg.chatId);
  if (!args) {
    GG.toast('Пример: .statusdraft пишу тебе поэму…');
    return false;
  }
  if (msg.chatType !== 'private') {
    GG.toast('Живой черновик виден только в личках');
    return false;
  }
  GG.status(msg.chatId, args.trim(), { draft: true });
  GG.toast('Черновик включён');
  return false;
}, 'живой черновик в личке');

GG.command('.statusrotate', function (args, msg) {
  var list = (args || '').split('|').map(function (s) { return s.trim(); }).filter(Boolean);
  stop(msg.chatId);
  if (list.length < 2) {
    GG.toast('Пример: .statusrotate крутой 😎 | занят | пишу код');
    return false;
  }
  var index = 0;
  var chatId = msg.chatId;
  GG.status(chatId, list[0]);
  rotations[chatId] = setInterval(function () {
    index = (index + 1) % list.length;
    GG.status(chatId, list[index]);
  }, Math.max(4, Number(GG.setting('interval')) || 8) * 1000);
  GG.toast('Статусы по кругу: ' + list.length);
  return false;
}, 'менять статусы по кругу');
