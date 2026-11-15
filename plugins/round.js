// @id round
// @name Кружок из чего угодно
// @version 1.0
// @author GhostGram
// @description .round — выбираешь в галерее любое видео, гифку, скрин или фото, и оно уходит кружком. Нужна версия GhostGram v12+.

GG.settings([
  { key: 'seconds', title: 'Длина кружка из картинки (сек)', type: 'number', default: 5, hint: 'Для фото и скринов. Видео и гифки — своей длины (до 60 сек)' }
]);

function open(args, msg) {
  var s = parseInt(args, 10);
  if (!(s > 0)) s = Number(GG.setting('seconds')) || 5;
  msg.round({ seconds: Math.max(1, Math.min(60, s)) });
  return null; // саму команду не отправляем
}

GG.command('.round', open, 'кружок из видео, гифки, скрина или фото (.round 10 — картинка на 10 сек)');
GG.command('.кружок', open, 'то же самое по-русски');
