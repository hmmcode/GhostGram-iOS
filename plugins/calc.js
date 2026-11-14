// @id calc
// @name Калькулятор
// @version 1.0
// @author GhostGram
// @description .calc 2+2*3 — посчитает и отправит «2+2*3 = 8». Есть sqrt, sin, cos, abs, round, pi, ^ и %.

function evaluate(input) {
  var text = input.replace(/,/g, '.').replace(/×/g, '*').replace(/÷/g, '/').replace(/\s+/g, '');
  var pos = 0;
  var functions = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: function (x) { return Math.sin(x * Math.PI / 180); },
    cos: function (x) { return Math.cos(x * Math.PI / 180); },
    tan: function (x) { return Math.tan(x * Math.PI / 180); },
    ln: Math.log, log: Math.log10 || function (x) { return Math.log(x) / Math.LN10; }
  };
  var constants = { pi: Math.PI, e: Math.E };

  function peek() { return text[pos]; }
  function expect(ch) {
    if (text[pos] !== ch) throw new Error('ожидалось «' + ch + '»');
    pos++;
  }
  function number() {
    var start = pos;
    while (pos < text.length && /[0-9.]/.test(text[pos])) pos++;
    var value = parseFloat(text.slice(start, pos));
    if (isNaN(value)) throw new Error('не понял число');
    return value;
  }
  function primary() {
    var ch = peek();
    if (ch === '(') { pos++; var v = expression(); expect(')'); return v; }
    if (ch === '-') { pos++; return -power(); }
    if (ch === '+') { pos++; return power(); }
    if (/[a-z]/i.test(ch || '')) {
      var start = pos;
      while (pos < text.length && /[a-z]/i.test(text[pos])) pos++;
      var name = text.slice(start, pos).toLowerCase();
      if (constants[name] !== undefined) return constants[name];
      if (!functions[name]) throw new Error('не знаю «' + name + '»');
      expect('(');
      var arg = expression();
      expect(')');
      return functions[name](arg);
    }
    return number();
  }
  function postfix() {
    var v = primary();
    while (peek() === '%') { pos++; v = v / 100; }
    return v;
  }
  function power() {
    var base = postfix();
    if (peek() === '^') { pos++; return Math.pow(base, power()); }
    return base;
  }
  function term() {
    var v = power();
    while (peek() === '*' || peek() === '/') {
      var op = text[pos++];
      var r = power();
      v = op === '*' ? v * r : v / r;
    }
    return v;
  }
  function expression() {
    var v = term();
    while (peek() === '+' || peek() === '-') {
      var op = text[pos++];
      var r = term();
      v = op === '+' ? v + r : v - r;
    }
    return v;
  }
  if (!text) throw new Error('пустое выражение');
  var result = expression();
  if (pos < text.length) throw new Error('лишнее «' + text.slice(pos) + '»');
  return result;
}

function format(value) {
  if (!isFinite(value)) return value > 0 ? '∞' : (value < 0 ? '-∞' : 'не определено');
  var rounded = Math.round(value * 1e10) / 1e10;
  return String(rounded).replace('.', ',');
}

GG.command('.calc', function (args) {
  if (!args) {
    GG.toast('Пример: .calc 15% * 2000');
    return false;
  }
  return args + ' = ' + format(evaluate(args));
}, 'посчитать выражение');

GG.command('.=', function (args) {
  return format(evaluate(args));
}, 'отправить только ответ');
