/**
 * Hearem 智能音色分流（Quantumult X）
 *
 * 单条规则只拦截 api.hearem.cc：
 * - reference_id 属于下方 31 个“唱歌音色”时：转为请求 kk.weshine.im，并返回 KK MP3。
 * - 其他音色：请求 api.hearem.cc，并使用 cc.js 的请求头返回 Fish MP3。
 *
 * 重写类型必须使用 script-analyze-echo-response，以便读取请求正文并回显音频。
 * 只启用这一条规则，原来的 kk.js、cc.js 规则全部关闭。
 */

var SCRIPT_VERSION = "4.3.0-cc-loop-retry-fix-20260730";
var TAG = "[Hearem智能分流]";
var HEAREM_TTS_URL = "https://api.hearem.cc/fishaudio-proxy/v1/tts";
var CC_MAX_ATTEMPTS = 2;
var CC_RETRY_DELAY = 1200;
var CC_TIMEOUT = 60000;

var KK_CONFIG = {
  uid: "9c38d994-cf5c-e109-7560-0c1096f58c5d",
  h: "f15fadd486574700a71be18872843c63",
  timestamp: "1784441120919",
  token: "OTQxMDBmZTMwNDY3NTU0NTMwMzQwMGU2NWIxNjM2ZGQ0MmRhMTY2Zg==",
  idfv: "58BA91A7-AD82-4D66-A3A8-77587B86A6D7",
  sign: "b9cb3f3f6b8c1a0210ed2ead474e8995",
  cookie: "SERVERID=2c66a41e2e0272413c175c4af3082142|1784441120|1784441103"
};

// 唱歌音色 ID -> 名称
var SINGING_VOICES = {
  "7278de0e91425211a76d56fd58c32764": "魔性合唱",
  "94b8f3ec59b18723224b7ac5e3fa3a07": "苹果抽象歌",
  "6ddef70db42a48389bab18197e2db375": "mc水观音",
  "7ebf53e21862da16f8b4dad483a528e7": "偶买噶女",
  "fe8d17bb734ce00ca1447bf3ec331b3b": "加麻不加辣",
  "fcc96934f82c142e337b716ad7ee6295": "偶买噶男",
  "d9f307e23c83fbc0261817d7adb1c797": "泰国神曲",
  "54d82621dcb782e80ccd7e2d787fd692": "梦的翅膀",
  "233a7f55e1afa3f2b1663d2c59cc8c12": "丑死了",
  "cbd3072d8d32332ace3330365ac60d7b": "再等一分钟",
  "22631f177e12936f5e567ed1622c2db0": "苹果抽象歌男",
  "d3408687624c3b86f4a9e7d03443977b": "奶蛙唱歌",
  "6485e072d4e2feafb5f4b33c74c10fc9": "山歌",
  "2801e1d81a603434f9517bec083e4d1a": "大香蕉",
  "780afe03c0a7722fa4f8e318f7ac8e15": "老师约稿",
  "f0231a8f7395f2a793c278097dcb55ff": "发牌女声",
  "e6e35bc5ae62761cb3afd9babb506a72": "贝利亚",
  "c7e03b4e20c1de3b40c85ed1e3d7faa1": "伤不起",
  "d7bb588b330315448a96958f90a778b6": "纯情蟑螂",
  "a100d962c2132c5d5af9f699d2a16776": "哈基米",
  "663280b60a373a1f5b511d7e3a83586a": "大江大海",
  "65e33254a5bf3696a6d5fd0ea0ebcbb8": "rap气泡音",
  "53d6873339d44e203f91a48a0106409c": "吃鸡神曲",
  "9753639de6399ac7b3db48ea09cd6318": "网恋rb",
  "8c1f66993229d3f405e389657eec2d6a": "甜嗓朋克",
  "18694208d38b6186fdf3274faac4d091": "甜嗓摇滚",
  "d4c04e522ef47f88a182dcb88a5c484c": "土味pop",
  "88ca3b607ca65a7634e68dfa36247d5a": "土味电子",
  "df79fa0947f4daae5393e7599c4a9c0b": "电音dj",
  "62a08f5bcce41ba50f9cdcd75951e61d": "鸡毛叔",
  "d0ecaa200a094ec5b3dff3c40734e180": "鸡毛嫂"
};

var finished = false;

function log(message) {
  console.log(TAG + "[" + SCRIPT_VERSION + "] " + message);
}

function doneOnce(payload) {
  if (finished) return;
  finished = true;
  $done(payload);
}

function statusLine(code) {
  var texts = {
    200: "OK",
    400: "Bad Request",
    401: "Unauthorized",
    403: "Forbidden",
    404: "Not Found",
    429: "Too Many Requests",
    500: "Internal Server Error",
    502: "Bad Gateway",
    503: "Service Unavailable"
  };
  return "HTTP/1.1 " + code + " " + (texts[code] || "Response");
}

function errorText(error) {
  if (error == null) return "未知错误";
  if (typeof error === "string") return error;

  var parts = [];
  var keys = ["error", "message", "code", "status", "statusCode", "domain", "localizedDescription"];
  for (var i = 0; i < keys.length; i++) {
    var value = error[keys[i]];
    if (value != null && String(value) !== "") {
      parts.push(keys[i] + "=" + String(value));
    }
  }

  if (parts.length) return parts.join(", ");
  try { return JSON.stringify(error); } catch (_) { return String(error); }
}

function finishError(code, message, detail) {
  detail = errorText(detail);
  var payload = {
    version: SCRIPT_VERSION,
    code: -1,
    message: message,
    detail: detail || ""
  };
  log(message + (detail ? "：" + detail : ""));
  doneOnce({
    status: statusLine(code),
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type,Authorization,model,X-App-Key",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Cache-Control": "no-store",
      "X-Hearem-Hybrid-Version": SCRIPT_VERSION
    },
    body: JSON.stringify(payload)
  });
}

function decodeUtf8(buffer) {
  if (!buffer) return "";
  var bytes;
  if (buffer instanceof ArrayBuffer) {
    bytes = new Uint8Array(buffer);
  } else if (typeof ArrayBuffer !== "undefined" && ArrayBuffer.isView && ArrayBuffer.isView(buffer)) {
    bytes = new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);
  } else {
    return "";
  }

  if (typeof TextDecoder !== "undefined") {
    try { return new TextDecoder("utf-8").decode(bytes); } catch (_) {}
  }

  var binary = "";
  var chunkSize = 8192;
  for (var i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, Math.min(i + chunkSize, bytes.length)));
  }
  try { return decodeURIComponent(escape(binary)); } catch (_) { return binary; }
}

function getRequestBody() {
  if (typeof $request.body === "string" && $request.body.length) {
    return $request.body;
  }
  if ($request.bodyBytes) {
    return decodeUtf8($request.bodyBytes);
  }
  return "";
}

function parseBody(rawBody) {
  if (!rawBody) return {};
  try {
    return JSON.parse(rawBody);
  } catch (_) {
    var result = {};
    var pairs = rawBody.split("&");
    for (var i = 0; i < pairs.length; i++) {
      var pos = pairs[i].indexOf("=");
      if (pos < 0) continue;
      var key = decodeURIComponent(pairs[i].slice(0, pos).replace(/\+/g, " "));
      var value = decodeURIComponent(pairs[i].slice(pos + 1).replace(/\+/g, " "));
      result[key] = value;
    }
    return result;
  }
}

function getVoiceId(body) {
  return String(body.reference_id || body.voice_id || body.voiceId || body.vid || "").trim().toLowerCase();
}

function getText(body) {
  return typeof body.text === "string" ? body.text.trim() : "";
}

function isSingingVoice(voiceId) {
  return !!SINGING_VOICES[voiceId];
}

function buildKkUrl(text, voiceId) {
  var params = {
    content: text,
    v: "2.8.2",
    x: "0",
    netstatus: "1",
    lan: "zh",
    uid: KK_CONFIG.uid,
    vc: "1059",
    h: KK_CONFIG.h,
    voice_id: voiceId,
    sv: "17.3.1",
    c: "AppStore",
    m: "iPhone_15_Pro",
    s: "iOS",
    timestamp: KK_CONFIG.timestamp,
    token: KK_CONFIG.token,
    idfv: KK_CONFIG.idfv,
    sign: KK_CONFIG.sign,
    ad: "0"
  };

  var parts = [];
  var keys = Object.keys(params);
  for (var i = 0; i < keys.length; i++) {
    parts.push(encodeURIComponent(keys[i]) + "=" + encodeURIComponent(String(params[keys[i]])));
  }
  return "https://kk.weshine.im/v1.0/text2voice/createTtsAudio?" + parts.join("&");
}

function kkHeaders() {
  return {
    "author": "yan wang",
    "Cookie": KK_CONFIG.cookie,
    "Accept": "application/json,*/*",
    "User-Agent": "Keyboard/1059 CFNetwork/1492.0.1 Darwin/23.3.0",
    "Accept-Language": "zh-CN,zh-Hans;q=0.9"
  };
}

function copyHeaders(source) {
  var target = {};
  source = source || {};
  var keys = Object.keys(source);
  for (var i = 0; i < keys.length; i++) target[keys[i]] = source[keys[i]];
  return target;
}

function deleteHeader(headers, name) {
  var keys = Object.keys(headers || {});
  var lowerName = name.toLowerCase();
  for (var i = 0; i < keys.length; i++) {
    if (keys[i].toLowerCase() === lowerName) delete headers[keys[i]];
  }
}

// cc.js 的请求头逻辑。Authorization 等原请求头会保留。
function buildCcHeaders(attempt) {
  var headers = copyHeaders($request.headers);
  headers["model"] = "S2 Pro";
  headers["Connection"] = "keep-alive";
  headers["Accept-Encoding"] = "identity";
  headers["Content-Type"] = "application/json";
  headers["sentry-trace"] = "ce7833fa3b36445a855bcc9dc46e84c6-c623c79d592b4d67-0";
  headers["User-Agent"] = "Hearem/184 CFNetwork/1492.0.1 Darwin/23.3.0";
  headers["Host"] = "api.hearem.cc";
  headers["Accept-Language"] = "zh-CN,zh-Hans;q=0.9";
  headers["Accept"] = "*/*";
  headers["x-app-key"] = "8d7ab222c3f3e948a830cb799c7b668e78b904dc959182826569884165a511a7";
  headers["X-Hearem-Retry-Attempt"] = String(attempt || 1);
  deleteHeader(headers, "Content-Length");
  deleteHeader(headers, "Transfer-Encoding");
  deleteHeader(headers, "Content-Encoding");
  return headers;
}

function cleanResponseHeaders(source, route) {
  var headers = copyHeaders(source);
  deleteHeader(headers, "Content-Length");
  deleteHeader(headers, "Transfer-Encoding");
  deleteHeader(headers, "Content-Encoding");
  headers["Access-Control-Allow-Origin"] = "*";
  headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,model,X-App-Key";
  headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS";
  headers["X-Hearem-Hybrid-Version"] = SCRIPT_VERSION;
  headers["X-Hearem-Route"] = route;
  return headers;
}

function returnFetchResponse(response, route) {
  var code = Number(response.statusCode || 200);
  var headers = cleanResponseHeaders(response.headers, route);
  var payload = {
    status: statusLine(code),
    headers: headers
  };

  if (response.bodyBytes && response.bodyBytes.byteLength) {
    payload.bodyBytes = response.bodyBytes;
  } else {
    payload.body = response.body || "";
  }
  doneOnce(payload);
}

function runKk(text, voiceId) {
  var voiceName = SINGING_VOICES[voiceId] || voiceId;
  log("命中唱歌音色：" + voiceName + "，使用 KK 方法");

  $task.fetch({
    url: buildKkUrl(text, voiceId),
    method: "GET",
    headers: kkHeaders(),
    opts: {
      "skip-cert-verify": true,
      "redirection": true,
      "auto-cookie": false
    }
  }).then(function (createResponse) {
    var result;
    try {
      result = JSON.parse(createResponse.body || "{}");
    } catch (error) {
      throw new Error("KK 返回内容不是 JSON：" + String(error));
    }

    if (!result.meta || Number(result.meta.status) !== 200) {
      throw new Error("KK 生成失败：" + (result.meta && result.meta.msg ? result.meta.msg : createResponse.body));
    }
    if (!result.data || !result.data.url) {
      throw new Error("KK 响应中没有音频地址");
    }

    return $task.fetch({
      url: result.data.url,
      method: "GET",
      headers: {
        "Accept": "audio/mpeg,*/*",
        "User-Agent": "Hearem/184 CFNetwork/1492.0.1 Darwin/23.3.0"
      },
      opts: {
        "skip-cert-verify": true,
        "redirection": true,
        "auto-cookie": false
      }
    });
  }).then(function (audioResponse) {
    if (Number(audioResponse.statusCode) !== 200) {
      throw new Error("KK 音频下载失败，HTTP " + audioResponse.statusCode);
    }
    if (!audioResponse.bodyBytes || !audioResponse.bodyBytes.byteLength) {
      throw new Error("KK 音频下载成功但没有取得 bodyBytes");
    }

    doneOnce({
      status: statusLine(200),
      headers: {
        "Content-Type": "audio/mpeg",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization,model,X-App-Key",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Max-Age": "86400",
        "Accept-Ranges": "bytes",
        "Cache-Control": "no-store",
        "X-Hearem-Hybrid-Version": SCRIPT_VERSION,
        "X-Hearem-Route": "KK"
      },
      bodyBytes: audioResponse.bodyBytes
    });
  }).catch(function (error) {
    finishError(502, "KK 唱歌音色处理失败", String(error));
  });
}

function fetchCc(rawBody, attempt) {
  var request = {
    url: HEAREM_TTS_URL,
    method: "POST",
    headers: buildCcHeaders(attempt),
    body: rawBody,
    timeout: CC_TIMEOUT,
    opts: {
      // 防止脚本内部请求再次命中当前重写规则。
      "hints": false,
      "redirection": true,
      "skip-cert-verify": true,
      "auto-cookie": false
    }
  };

  return $task.fetch(request).then(function (response) {
    var code = Number(response.statusCode || 0);
    if (code < 200 || code >= 300) {
      var bodyPreview = String(response.body || "").slice(0, 200);
      throw new Error("Hearem HTTP " + code + (bodyPreview ? ", body=" + bodyPreview : ""));
    }
    if (!response.bodyBytes || !response.bodyBytes.byteLength) {
      throw new Error("Hearem HTTP " + code + " 但没有音频 bodyBytes");
    }
    return response;
  });
}

function runCc(rawBody) {
  log("未命中唱歌音色，请求 api.hearem.cc");

  function attemptRequest(attempt) {
    log("CC/Fish 第 " + attempt + "/" + CC_MAX_ATTEMPTS + " 次请求");
    fetchCc(rawBody, attempt).then(function (response) {
      log("CC/Fish 成功，HTTP=" + response.statusCode + "，bytes=" + response.bodyBytes.byteLength);
      returnFetchResponse(response, "CC");
    }).catch(function (error) {
      var detail = errorText(error);
      log("CC/Fish 第 " + attempt + " 次失败：" + detail);
      if (attempt < CC_MAX_ATTEMPTS) {
        setTimeout(function () {
          attemptRequest(attempt + 1);
        }, CC_RETRY_DELAY * attempt);
      } else {
        finishError(502, "CC/Fish 请求失败（已重试）", detail);
      }
    });
  }

  if (!rawBody) {
    finishError(400, "CC/Fish 请求体为空");
    return;
  }
  attemptRequest(1);
}

var rawBody = getRequestBody();
var body = parseBody(rawBody);
var voiceId = getVoiceId(body);
var text = getText(body);

log("reference_id=" + (voiceId || "空") + "，文本长度=" + text.length);

if (isSingingVoice(voiceId)) {
  if (!text) {
    finishError(400, "唱歌音色请求中没有可转换的 text 文本");
  } else {
    runKk(text, voiceId);
  }
} else {
  runCc(rawBody);
}
