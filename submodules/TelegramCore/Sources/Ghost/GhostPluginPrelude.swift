// Generated from the GhostGram plugin prelude. Defines the `GG` API every plugin sees.

let ghostPluginPrelude: String = #"""
(function (global) {
  'use strict';
  var N = global.__native;

  var handlers = { message: [], outgoing: [], start: [], settings: [] };
  var commands = [];
  var actions = [];
  var schema = [];
  var timers = {};
  var nextTimer = 1;
  var requests = {};
  var nextRequest = 1;

  function str(value) {
    if (typeof value === 'string') return value;
    if (value === undefined) return 'undefined';
    if (value instanceof Error) return value.name + ': ' + value.message;
    try { return JSON.stringify(value); } catch (e) { return String(value); }
  }
  function joinArgs(args) {
    return Array.prototype.map.call(args, str).join(' ');
  }
  function describe(error) {
    if (error && error.stack) {
      return String(error) + (error.line ? ' (строка ' + error.line + ')' : '');
    }
    return str(error);
  }
  function report(where, error) {
    N.log('error', where + ': ' + describe(error));
  }
  function isThenable(value) {
    return value !== null && (typeof value === 'object' || typeof value === 'function') && typeof value.then === 'function';
  }

  global.console = {
    log: function () { N.log('log', joinArgs(arguments)); },
    info: function () { N.log('log', joinArgs(arguments)); },
    debug: function () { N.log('log', joinArgs(arguments)); },
    warn: function () { N.log('warn', joinArgs(arguments)); },
    error: function () { N.log('error', joinArgs(arguments)); }
  };

  function addTimer(fn, ms, args, repeat) {
    if (typeof fn !== 'function') throw new TypeError('Нужна функция');
    var id = nextTimer++;
    var delay = Math.max(repeat ? 50 : 0, Number(ms) || 0);
    timers[id] = { fn: fn, args: args, repeat: repeat, ms: delay };
    N.setTimer(id, delay);
    return id;
  }
  global.setTimeout = function (fn, ms) { return addTimer(fn, ms, Array.prototype.slice.call(arguments, 2), false); };
  global.setInterval = function (fn, ms) { return addTimer(fn, ms, Array.prototype.slice.call(arguments, 2), true); };
  global.clearTimeout = global.clearInterval = function (id) {
    if (timers[id]) {
      delete timers[id];
      N.clearTimer(Number(id));
    }
  };
  global.__ggTimer = function (id) {
    var timer = timers[id];
    if (!timer) return;
    if (timer.repeat) {
      N.setTimer(id, timer.ms);
    } else {
      delete timers[id];
    }
    try {
      var result = timer.fn.apply(null, timer.args);
      if (isThenable(result)) result.then(null, function (e) { report('таймер', e); });
    } catch (e) {
      report('таймер', e);
    }
  };

  function makeResponse(status, text, headers, url) {
    return {
      status: status,
      ok: status >= 200 && status < 300,
      url: url,
      headers: headers,
      body: text,
      text: function () { return Promise.resolve(text); },
      json: function () { return new Promise(function (resolve) { resolve(JSON.parse(text)); }); }
    };
  }
  function fetch(url, options) {
    options = options || {};
    return new Promise(function (resolve, reject) {
      var id = nextRequest++;
      requests[id] = { resolve: resolve, reject: reject, url: String(url) };
      var headers = {};
      var source = options.headers || {};
      Object.keys(source).forEach(function (key) { headers[key] = String(source[key]); });
      var body = options.body;
      if (body !== undefined && body !== null && typeof body !== 'string') {
        body = JSON.stringify(body);
        if (!headers['Content-Type'] && !headers['content-type']) headers['Content-Type'] = 'application/json';
      }
      N.fetch(id, String(url), String(options.method || (body ? 'POST' : 'GET')).toUpperCase(), JSON.stringify(headers), body === undefined || body === null ? '' : String(body), Number(options.timeout) || 30);
    });
  }
  global.fetch = fetch;
  global.__ggFetchDone = function (id, status, text, error, headersJson) {
    var request = requests[id];
    if (!request) return;
    delete requests[id];
    if (error) {
      request.reject(new Error(error));
      return;
    }
    var headers = {};
    try { headers = JSON.parse(headersJson || '{}'); } catch (e) {}
    request.resolve(makeResponse(status, text, headers, request.url));
  };

  function send(chatId, text, options) {
    options = options || {};
    if (chatId === undefined || chatId === null || chatId === '') throw new Error('GG.send: не указан чат');
    text = str(text);
    if (!text) return;
    N.send(String(chatId), text, Number(options.replyTo) || 0, options.account ? String(options.account) : '');
  }

  function sendVoice(chatId, wave, options) {
    options = options || {};
    if (chatId === undefined || chatId === null || chatId === '') throw new Error('GG.sendVoice: не указан чат');
    if (typeof N.sendVoice !== 'function') throw new Error('Голосовые с рисунком работают с GhostGram v11');
    if (!Array.isArray(wave) || !wave.length) throw new Error('GG.sendVoice: волна — это массив чисел 0..31');
    var bars = wave.slice(0, 100).map(function (v) { v = Math.round(Number(v) || 0); return v < 0 ? 0 : (v > 31 ? 31 : v); });
    var duration = Math.round(Number(options.duration) || 5);
    N.sendVoice(String(chatId), JSON.stringify(bars), duration, Number(options.replyTo) || 0, options.account ? String(options.account) : '');
  }

  function pickRound(chatId, options) {
    options = options || {};
    if (chatId === undefined || chatId === null || chatId === '') throw new Error('GG.pickRound: не указан чат');
    if (typeof N.pickRound !== 'function') throw new Error('Кружки работают с GhostGram v12');
    N.pickRound(String(chatId), Number(options.replyTo) || 0, Math.round(Number(options.seconds) || 5), options.account ? String(options.account) : '');
  }

  function wrapMessage(message) {
    message.reply = function (text) { send(message.chatId, text, { replyTo: message.id, account: message.account }); };
    message.round = function (options) { pickRound(message.chatId, Object.assign({ replyTo: message.replyTo, account: message.account }, options || {})); };
    message.voice = function (wave, options) { sendVoice(message.chatId, wave, Object.assign({ replyTo: message.replyTo, account: message.account }, options || {})); };
    message.respond = function (text) { send(message.chatId, text, { account: message.account }); };
    return message;
  }

  function settingDefault(key) {
    for (var i = 0; i < schema.length; i++) {
      if (schema[i].key === key) return schema[i]['default'];
    }
    return undefined;
  }

  var storage = {
    get: function (key, fallback) {
      var raw = N.storageGet('data:' + key);
      if (raw === null || raw === undefined) return fallback;
      try { return JSON.parse(raw); } catch (e) { return fallback; }
    },
    set: function (key, value) {
      if (value === undefined) N.storageRemove('data:' + key);
      else N.storageSet('data:' + key, JSON.stringify(value));
    },
    remove: function (key) { N.storageRemove('data:' + key); },
    keys: function () {
      return JSON.parse(N.storageKeys()).filter(function (k) { return k.indexOf('data:') === 0; }).map(function (k) { return k.slice(5); });
    }
  };

  var GG = {
    version: N.appVersion(),
    on: function (event, fn) {
      if (!handlers[event]) throw new Error('Неизвестное событие «' + event + '». Есть: ' + Object.keys(handlers).join(', '));
      if (typeof fn !== 'function') throw new TypeError('GG.on: нужна функция');
      handlers[event].push(fn);
    },
    command: function (name, fn, description) {
      name = String(name).trim().toLowerCase();
      if (!name) throw new Error('GG.command: пустое имя');
      if (typeof fn !== 'function') throw new TypeError('GG.command: нужна функция');
      commands.push({ name: name, fn: fn, description: description ? String(description) : '' });
      commands.sort(function (a, b) { return b.name.length - a.name.length; });
    },
    action: function (title, fn) {
      if (typeof fn !== 'function') throw new TypeError('GG.action: нужна функция');
      actions.push({ title: String(title), fn: fn });
    },
    settings: function (list) {
      if (!Array.isArray(list)) throw new TypeError('GG.settings: нужен массив');
      schema = list.map(function (item) {
        var type = item.type || 'text';
        if (['bool', 'text', 'number', 'choice'].indexOf(type) < 0) throw new Error('GG.settings: неизвестный тип ' + type);
        return {
          key: String(item.key),
          title: String(item.title || item.key),
          type: type,
          'default': item['default'] === undefined ? (type === 'bool' ? false : type === 'number' ? 0 : '') : item['default'],
          options: Array.isArray(item.options) ? item.options.map(String) : [],
          hint: item.hint ? String(item.hint) : ''
        };
      });
    },
    setting: function (key) {
      var raw = N.storageGet('setting:' + key);
      if (raw === null || raw === undefined) return settingDefault(key);
      try { return JSON.parse(raw); } catch (e) { return settingDefault(key); }
    },
    setSetting: function (key, value) {
      N.storageSet('setting:' + key, JSON.stringify(value));
    },
    send: send,
    sendVoice: sendVoice,
    pickRound: pickRound,
    status: function (chatId, text, options) {
      if (typeof N.setStatus !== 'function') throw new Error('Свой статус работает с GhostGram v20');
      options = options || {};
      N.setStatus(String(chatId), text === undefined || text === null ? '' : str(text), !!options.draft);
    },
    notify: function (title, body, options) {
      options = options || {};
      N.notify(str(title), body === undefined ? '' : str(body), Number(options.delay) || 0, options.id ? String(options.id) : '');
    },
    cancelNotify: function (id) { N.cancelNotify(String(id)); },
    alert: function (title, body) { N.ui('alert', str(title), body === undefined ? '' : str(body)); },
    toast: function (text) { N.ui('toast', str(text), ''); },
    copy: function (text) { N.ui('copy', str(text), ''); },
    storage: storage,
    me: function () {
      var raw = N.me();
      return raw ? JSON.parse(raw) : null;
    },
    sleep: function (ms) { return new Promise(function (resolve) { global.setTimeout(resolve, ms); }); },
    fetch: fetch,
    log: global.console.log,
    now: function () { return Math.floor(Date.now() / 1000); }
  };
  global.GG = GG;

  function settle(result, message, isCommand) {
    if (isThenable(result)) {
      result.then(function (value) {
        if (typeof value === 'string' && value) send(message.chatId, value, { replyTo: message.replyTo, account: message.account });
      }, function (e) {
        report('команда', e);
        GG.toast('⚠️ ' + (e && e.message ? e.message : str(e)));
      });
      return { action: 'cancel' };
    }
    if (typeof result === 'string') {
      return result ? { action: 'replace', text: result } : { action: 'cancel' };
    }
    if (result === false || result === null) return { action: 'cancel' };
    if (result === undefined) return isCommand ? { action: 'cancel' } : { action: 'keep' };
    if (typeof result === 'object' && typeof result.text === 'string') return { action: 'replace', text: result.text };
    return { action: 'keep' };
  }

  function matchCommand(text) {
    var trimmed = text.replace(/^\s+/, '');
    var lower = trimmed.toLowerCase();
    for (var i = 0; i < commands.length; i++) {
      var name = commands[i].name;
      if (lower.indexOf(name) === 0) {
        var rest = trimmed.slice(name.length);
        if (rest === '' || /^\s/.test(rest)) return { command: commands[i], args: rest.trim() };
      }
    }
    return null;
  }

  global.__ggOutgoing = function (json) {
    var message = wrapMessage(JSON.parse(json));
    var match = matchCommand(message.text);
    if (match) {
      message.args = match.args;
      try {
        return JSON.stringify(settle(match.command.fn(match.args, message), message, true));
      } catch (e) {
        report('команда ' + match.command.name, e);
        GG.toast('⚠️ ' + match.command.name + ': ' + (e && e.message ? e.message : str(e)));
        return JSON.stringify({ action: 'cancel' });
      }
    }
    var text = message.text;
    var changed = false;
    for (var i = 0; i < handlers.outgoing.length; i++) {
      try {
        message.text = text;
        var decision = settle(handlers.outgoing[i](message), message, false);
        if (decision.action === 'cancel') return JSON.stringify(decision);
        if (decision.action === 'replace') {
          text = decision.text;
          changed = true;
        }
      } catch (e) {
        report('outgoing', e);
      }
    }
    return JSON.stringify(changed ? { action: 'replace', text: text } : { action: 'keep' });
  };

  global.__ggDispatch = function (event, json) {
    var list = handlers[event] || [];
    if (!list.length) return;
    var payload = JSON.parse(json);
    if (event === 'message') payload = wrapMessage(payload);
    list.forEach(function (fn) {
      try {
        var result = fn(payload);
        if (isThenable(result)) result.then(null, function (e) { report(event, e); });
      } catch (e) {
        report(event, e);
      }
    });
  };

  global.__ggInfo = function () {
    return JSON.stringify({
      commands: commands.map(function (c) { return { name: c.name, description: c.description }; }),
      actions: actions.map(function (a) { return a.title; }),
      settings: schema,
      handles: { message: handlers.message.length, outgoing: handlers.outgoing.length }
    });
  };

  global.__ggRunAction = function (index) {
    var action = actions[index];
    if (!action) return;
    try {
      var result = action.fn();
      if (isThenable(result)) result.then(null, function (e) { report('кнопка «' + action.title + '»', e); GG.toast('⚠️ ' + (e && e.message ? e.message : str(e))); });
    } catch (e) {
      report('кнопка «' + action.title + '»', e);
      GG.toast('⚠️ ' + (e && e.message ? e.message : str(e)));
    }
  };
})(this);
"""#
