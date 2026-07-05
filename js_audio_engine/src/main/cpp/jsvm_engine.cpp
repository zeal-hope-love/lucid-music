#include "jsvm_engine.h"
#include <hilog/log.h>
#include <cstring>
#include <algorithm>
#include <random>
#include <sstream>
#include <iomanip>
#include <vector>
#include <thread>
#include <chrono>
#include <cstdint>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x3200
#define LOG_TAG "JSVM_ENGINE"

namespace JsAudioEngine {

// ============ Embedded preload script from LX Music Mobile ============
const char* JsvmEngine::PRELOAD_SCRIPT = R"PRELOAD(
'use strict'

globalThis.lx_setup = (key, id, name, description, version, author, homepage, rawScript) => {
  delete globalThis.lx_setup
  const _nativeCall = globalThis.__lx_native_call__
  delete globalThis.__lx_native_call__
  const checkLength = (str, length = 1048576) => {
    if (typeof str == 'string' && str.length > length) throw new Error('Input too long')
    return str
  }
  const nativeFuncNames = [
    '__lx_native_call__set_timeout',
    '__lx_native_call__utils_str2b64',
    '__lx_native_call__utils_b642buf',
    '__lx_native_call__utils_str2md5',
    '__lx_native_call__utils_aes_encrypt',
    '__lx_native_call__utils_rsa_encrypt',
  ]
  const nativeFuncs = {}
  for (const name of nativeFuncNames) {
    const nativeFunc = globalThis[name]
    delete globalThis[name]
    nativeFuncs[name.replace('__lx_native_call__', '')] = (...args) => {
      for (const arg of args) checkLength(arg)
      return nativeFunc(...args)
    }
  }
  const KEY_PREFIX = {
    publicKeyStart: '-----BEGIN PUBLIC KEY-----',
    publicKeyEnd: '-----END PUBLIC KEY-----',
    privateKeyStart: '-----BEGIN PRIVATE KEY-----',
    privateKeyEnd: '-----END PRIVATE KEY-----',
  }
  const RSA_PADDING = {
    OAEPWithSHA1AndMGF1Padding: 'RSA/ECB/OAEPWithSHA1AndMGF1Padding',
    NoPadding: 'RSA/ECB/NoPadding',
  }
  const AES_MODE = {
    CBC_128_PKCS7Padding: 'AES/CBC/PKCS7Padding',
    ECB_128_NoPadding: 'AES',
  }
  const nativeCall = (action, data) => {
    data = JSON.stringify(data)
    checkLength(data, 2097152)
    _nativeCall(key, action, data)
  }

  const callbacks = new Map()
  let timeoutId = 0
  const _setTimeout = (callback, timeout = 0, ...params) => {
    if (typeof callback !== 'function') throw new Error('callback required a function')
    if (typeof timeout !== 'number' || timeout < 0) throw new Error('timeout required a number')
    if (timeoutId > 90000000000) throw new Error('max timeout')
    const id = timeoutId++
    callbacks.set(id, {
      callback(...args) {
        callback(...args)
      },
      params,
    })
    nativeFuncs.set_timeout(id, parseInt(timeout))
    return id
  }
  const _clearTimeout = (id) => {
    const tagret = callbacks.get(id)
    if (!tagret) return
    callbacks.delete(id)
  }
  const handleSetTimeout = (id) => {
    const tagret = callbacks.get(id)
    if (!tagret) return
    callbacks.delete(id)
    tagret.callback(...tagret.params)
  }

  function bytesToString(bytes) {
    let result = ''
    let i = 0
    while (i < bytes.length) {
      const byte = bytes[i]
      if (byte < 128) {
        result += String.fromCharCode(byte)
        i++
      } else if (byte >= 192 && byte < 224) {
        result += String.fromCharCode(((byte & 31) << 6) | (bytes[i + 1] & 63))
        i += 2
      } else {
        result += String.fromCharCode(((byte & 15) << 12) | ((bytes[i + 1] & 63) << 6) | (bytes[i + 2] & 63))
        i += 3
      }
    }
    return result
  }
  function stringToBytes(inputString) {
    const bytes = []
    for (let i = 0; i < inputString.length; i++) {
      const charCode = inputString.charCodeAt(i)
      if (charCode < 128) {
        bytes.push(charCode)
      } else if (charCode < 2048) {
        bytes.push((charCode >> 6) | 192)
        bytes.push((charCode & 63) | 128)
      } else {
        bytes.push((charCode >> 12) | 224)
        bytes.push(((charCode >> 6) & 63) | 128)
        bytes.push((charCode & 63) | 128)
      }
    }
    return bytes
  }

  const NATIVE_EVENTS_NAMES = {
    init: 'init',
    showUpdateAlert: 'showUpdateAlert',
    request: 'request',
    cancelRequest: 'cancelRequest',
    response: 'response',
  }
  const EVENT_NAMES = {
    request: 'request',
    inited: 'inited',
    sources: 'sources',
    updateAlert: 'updateAlert',
  }
  const eventNames = Object.values(EVENT_NAMES)
  const events = {
    request: null,
  }
  const allSources = ['kw', 'kg', 'tx', 'wy', 'mg', 'local']
  const supportQualitys = {
    kw: ['128k', '320k', 'flac', 'flac24bit'],
    kg: ['128k', '320k', 'flac', 'flac24bit'],
    tx: ['128k', '320k', 'flac', 'flac24bit'],
    wy: ['128k', '320k', 'flac', 'flac24bit'],
    mg: ['128k', '320k', 'flac', 'flac24bit'],
    local: [],
  }
  const supportActions = {
    kw: ['musicUrl'],
    kg: ['musicUrl'],
    tx: ['musicUrl'],
    wy: ['musicUrl'],
    mg: ['musicUrl'],
    xm: ['musicUrl'],
    local: ['musicUrl', 'lyric', 'pic'],
  }

  const verifyLyricInfo = (info) => {
    if (typeof info != 'object' || typeof info.lyric != 'string') throw new Error('failed')
    if (info.lyric.length > 51200) throw new Error('failed')
    return {
      lyric: info.lyric,
      tlyric: (typeof info.tlyric == 'string' && info.tlyric.length < 5120) ? info.tlyric : null,
      rlyric: (typeof info.rlyric == 'string' && info.rlyric.length < 5120) ? info.rlyric : null,
      lxlyric: (typeof info.lxlyric == 'string' && info.lxlyric.length < 8192) ? info.lxlyric : null,
    }
  }

  const requestQueue = new Map()
  let isInitedApi = false
  let isShowedUpdateAlert = false

  const sendNativeRequest = (url, options, callback) => {
    const requestKey = Math.random().toString()
    const requestInfo = {
      aborted: false,
      abort: () => {
        nativeCall(NATIVE_EVENTS_NAMES.cancelRequest, requestKey)
      },
    }
    requestQueue.set(requestKey, {
      callback,
      requestInfo,
    })
    nativeCall(NATIVE_EVENTS_NAMES.request, { requestKey, url, options })
    return requestInfo
  }
  const handleNativeResponse = ({ requestKey, error, response }) => {
    const targetRequest = requestQueue.get(requestKey)
    if (!targetRequest) return
    requestQueue.delete(requestKey)
    targetRequest.requestInfo.aborted = true
    if (error == null) targetRequest.callback(null, response)
    else targetRequest.callback(new Error(error), null)
  }

  const handleRequest = ({ requestKey, data }) => {
    if (!events.request) return nativeCall(NATIVE_EVENTS_NAMES.response, { requestKey, status: false, errorMessage: 'Request event is not defined' })
    try {
      events.request.call(globalThis.lx, { source: data.source, action: data.action, info: data.info }).then(response => {
        let result
        switch (data.action) {
          case 'musicUrl':
            if (typeof response != 'string' || response.length > 2048 || !/^https?:/.test(response)) throw new Error('failed')
            result = {
              source: data.source,
              action: data.action,
              data: {
                type: data.info.type,
                url: response,
              },
            }
            break
          case 'lyric':
            result = {
              source: data.source,
              action: data.action,
              data: verifyLyricInfo(response),
            }
            break
          case 'pic':
            if (typeof response != 'string' || response.length > 2048 || !/^https?:/.test(response)) throw new Error('failed')
            result = {
              source: data.source,
              action: data.action,
              data: response,
            }
            break
          default:
            // Pass through raw response for search/leaderboard/any other action
            result = response
            break
        }
        nativeCall(NATIVE_EVENTS_NAMES.response, { requestKey, status: true, result })
      }).catch(err => {
        nativeCall(NATIVE_EVENTS_NAMES.response, { requestKey, status: false, errorMessage: err.message })
      })
    } catch (err) {
      nativeCall(NATIVE_EVENTS_NAMES.response, { requestKey, status: false, errorMessage: err.message })
    }
  }

  const jsCall = (action, data) => {
    switch (action) {
      case '__run_error__':
        if (!isInitedApi) {
          isInitedApi = true
          // Report script execution error so user knows what happened
          nativeCall(NATIVE_EVENTS_NAMES.init, { info: null, status: false, errorMessage: 'Script execution error: ' + (typeof data === 'string' ? data : JSON.stringify(data || 'unknown error')) })
        }
        return
      case '__set_timeout__':
        handleSetTimeout(data)
        return
      case 'request':
        handleRequest(data)
        return
      case 'response':
        handleNativeResponse(data)
        return
    }
    return 'Unknown action: ' + action
  }

  Object.defineProperty(globalThis, '__lx_native__', {
    enumerable: false,
    configurable: false,
    writable: false,
    value: (_key, action, data) => {
      if (key != _key) return 'Invalid key'
      return data == null ? jsCall(action) : jsCall(action, JSON.parse(data))
    },
  })

  const handleInit = (info) => {
    if (!info) {
      nativeCall(NATIVE_EVENTS_NAMES.init, { info: null, status: false, errorMessage: 'Missing required parameter init info' })
      return
    }
    // Respect script's own status flag (some scripts report failure explicitly)
    if (info.status === false) {
      nativeCall(NATIVE_EVENTS_NAMES.init, { info: null, status: false, errorMessage: info.errorMessage || info.message || 'Script reported init failure' })
      return
    }
    const sourceInfo = {
      sources: {},
    }
    try {
      // Iterate all sources declared by the script, not a hardcoded list
      const srcKeys = Object.keys(info.sources || {})
      for (const source of srcKeys) {
        const userSource = info.sources[source]
        if (!userSource || userSource.type !== 'music') continue
        // Use script-declared qualitys/actions, fallback to known defaults
        const qualitys = Array.isArray(userSource.qualitys) ? userSource.qualitys
          : (typeof userSource.qualitys === 'string' ? [userSource.qualitys]
          : (supportQualitys[source] || ['128k', '320k', 'flac', 'flac24bit']))
        const actions = Array.isArray(userSource.actions) ? userSource.actions
          : (typeof userSource.actions === 'string' ? [userSource.actions]
          : (supportActions[source] || ['musicUrl']))
        sourceInfo.sources[source] = {
          type: 'music',
          actions: actions,
          qualitys: qualitys,
        }
      }
    } catch (error) {
      nativeCall(NATIVE_EVENTS_NAMES.init, { info: null, status: false, errorMessage: error.message })
      return
    }
    nativeCall(NATIVE_EVENTS_NAMES.init, { info: sourceInfo, status: true })
  }
  const handleShowUpdateAlert = (data, resolve, reject) => {
    if (!data || typeof data != 'object') return reject(new Error('parameter format error.'))
    if (!data.log || typeof data.log != 'string') return reject(new Error('log is required.'))
    if (data.updateUrl && !/^https?:\/\/[^\s$.?#].[^\s]*$/.test(data.updateUrl) && data.updateUrl.length > 1024) delete data.updateUrl
    if (data.log.length > 1024) data.log = data.log.substring(0, 1024) + '...'
    nativeCall(NATIVE_EVENTS_NAMES.showUpdateAlert, { log: data.log, updateUrl: data.updateUrl, name })
    resolve()
  }

  const dataToB64 = (data) => {
    if (typeof data === 'string') return nativeFuncs.utils_str2b64(data)
    else if (Array.isArray(data) || ArrayBuffer.isView(data)) return utils.buffer.bufToString(data, 'base64')
    throw new Error('data type error: ' + typeof data + ' raw data: ' + data)
  }
  const utils = {
    crypto: {
      aesEncrypt(buffer, mode, key, iv) {
        switch (mode) {
          case 'aes-128-cbc':
            return utils.buffer.from(nativeFuncs.utils_aes_encrypt(dataToB64(buffer), dataToB64(key), dataToB64(iv), AES_MODE.CBC_128_PKCS7Padding), 'base64')
          case 'aes-128-ecb':
            return utils.buffer.from(nativeFuncs.utils_aes_encrypt(dataToB64(buffer), dataToB64(key), '', AES_MODE.ECB_128_NoPadding), 'base64')
          default:
            throw new Error('Binary encoding is not supported for input strings')
        }
      },
      rsaEncrypt(buffer, key) {
        if (typeof key !== 'string') throw new Error('Invalid RSA key')
        key = key.replace(KEY_PREFIX.publicKeyStart, '')
          .replace(KEY_PREFIX.publicKeyEnd, '')
        return utils.buffer.from(nativeFuncs.utils_rsa_encrypt(dataToB64(buffer), key, RSA_PADDING.NoPadding), 'base64')
      },
      randomBytes(size) {
        const byteArray = new Uint8Array(size)
        for (let i = 0; i < size; i++) {
          byteArray[i] = Math.floor(Math.random() * 256)
        }
        return byteArray
      },
      md5(str) {
        if (typeof str !== 'string') throw new Error('param required a string')
        const md5 = nativeFuncs.utils_str2md5(encodeURIComponent(str))
        return md5
      },
    },
    buffer: {
      from(input, encoding) {
        if (typeof input === 'string') {
          switch (encoding) {
            case 'binary':
              throw new Error('Binary encoding is not supported for input strings')
            case 'base64':
              return new Uint8Array(JSON.parse(nativeFuncs.utils_b642buf(input)))
            case 'hex':
              return new Uint8Array(input.match(/.{1,2}/g).map(byte => parseInt(byte, 16)))
            default:
              return new Uint8Array(stringToBytes(input))
          }
        } else if (Array.isArray(input)) {
          return new Uint8Array(input)
        } else {
          throw new Error('Unsupported input type: ' + input + ' encoding: ' + encoding)
        }
      },
      bufToString(buf, format) {
        if (Array.isArray(buf) || ArrayBuffer.isView(buf)) {
          switch (format) {
            case 'binary':
              return buf
            case 'hex':
              return new Uint8Array(buf).reduce((str, byte) => str + byte.toString(16).padStart(2, '0'), '')
            case 'base64':
              return nativeFuncs.utils_str2b64(bytesToString(Array.from(buf)))
            case 'utf8':
            case 'utf-8':
            default:
              return bytesToString(Array.from(buf))
          }
        } else {
          throw new Error('Input is not a valid buffer: ' + buf + ' format: ' + format)
        }
      },
    },
  }

  globalThis.lx = {
    EVENT_NAMES,
    request(url, { method = 'get', timeout, headers, body, form, formData, binary }, callback) {
      let options = { headers, binary: binary === true }
      if (timeout && typeof timeout == 'number' && timeout > 0) options.timeout = Math.min(timeout, 60000)

      let request = sendNativeRequest(url, { method, body, form, formData, ...options, _debug_url: url, _debug_headers: headers }, (err, resp) => {
        if (err) {
          callback(err, null, null)
        } else {
          // Parse body like LX Music request.js does before passing to preload
          if (typeof resp.body === 'string') {
            try { resp.body = JSON.parse(resp.body) } catch (_) {}
          }
          callback(err, {
            statusCode: resp.statusCode,
            statusMessage: resp.statusMessage,
            headers: resp.headers,
            body: resp.body,
          }, resp.body)
        }
      })

      return () => {
        if (!request.aborted) request.abort()
        request = null
      }
    },
    send(eventName, data) {
      console.log('lx.send called:', eventName, typeof data === 'object' ? JSON.stringify(Object.keys(data || {})) : data)
      return new Promise((resolve, reject) => {
        if (!eventNames.includes(eventName)) return reject(new Error('The event is not supported: ' + eventName))
        switch (eventName) {
          case EVENT_NAMES.inited:
          case EVENT_NAMES.sources:
            console.log('handleInit called with sources keys:', data && data.sources ? Object.keys(data.sources) : 'none')
            if (isInitedApi) return reject(new Error('Script is inited'))
            isInitedApi = true
            handleInit(data)
            resolve()
            break
          case EVENT_NAMES.updateAlert:
            if (isShowedUpdateAlert) return reject(new Error('The update alert can only be called once.'))
            isShowedUpdateAlert = true
            handleShowUpdateAlert(data, resolve, reject)
            break
          default:
            reject(new Error('Unknown event name: ' + eventName))
        }
      })
    },
    on(eventName, handler) {
      if (!eventNames.includes(eventName)) return Promise.reject(new Error('The event is not supported: ' + eventName))
      switch (eventName) {
        case EVENT_NAMES.request:
          events.request = handler
          break
        default: return Promise.reject(new Error('The event is not supported: ' + eventName))
      }
      return Promise.resolve()
    },
    utils,
    currentScriptInfo: {
      name,
      description,
      version,
      author,
      homepage,
      rawScript,
    },
    version: '2.0.0',
    env: 'mobile',
  }

  globalThis.setTimeout = _setTimeout
  globalThis.clearTimeout = _clearTimeout

  const freezeObject = (obj) => {
    if (typeof obj != 'object') return
    Object.freeze(obj)
    for (const subObj of Object.values(obj)) freezeObject(subObj)
  }
  freezeObject(globalThis.lx)

  const _toString = Function.prototype.toString
  Function.prototype.toString = function() {
    return Object.getOwnPropertyDescriptors(this).name.configurable
      ? _toString.apply(this)
      : 'function ' + this.name + '() { [native code] }'
  }
  globalThis.eval = function() {
    throw new Error('eval is not available')
  }
  const proxyFunctionConstructor = new Proxy(Function.prototype.constructor, {
    apply() {
      throw new Error('Dynamic code execution is not allowed.')
    },
    construct() {
      throw new Error('Dynamic code execution is not allowed.')
    },
  })
  Object.defineProperty(Function.prototype, 'constructor', {
    value: proxyFunctionConstructor,
    writable: false,
    configurable: false,
    enumerable: false,
  })
  globalThis.Function = proxyFunctionConstructor

  const excludes = [
    Function.prototype.toString,
    Function.prototype.toLocaleString,
    Object.prototype.toString,
  ]
  const freezeObjectProperty = (obj, freezedObj = new Set()) => {
    if (obj == null) return
    switch (typeof obj) {
      case 'object':
      case 'function':
        if (freezedObj.has(obj)) return
        freezedObj.add(obj)
        for (const [name, { ...config }] of Object.entries(Object.getOwnPropertyDescriptors(obj))) {
          if (!excludes.includes(config.value)) {
            if (config.writable) config.writable = false
            if (config.configurable) config.configurable = false
            Object.defineProperty(obj, name, config)
          }
          freezeObjectProperty(config.value, freezedObj)
        }
    }
  }
  freezeObjectProperty(globalThis)

  // Catch unhandled rejections and errors for debugging
  globalThis.addEventListener && globalThis.addEventListener('unhandledrejection', function(e) {
    var reason = e && e.reason;
    var msg = reason ? (reason.message || String(reason)) : 'unknown';
    if (reason && reason.stack) msg += ' | ' + String(reason.stack).substring(0, 500);
    try { globalThis.__lx_native_call__ && __lx_native_call__(key, 'debug', 'rejection:' + msg); } catch(er) {}
  });

  globalThis.onerror = function(msg, src, line, col, err) {
    var detail = msg + ' line=' + line;
    if (err && err.stack) detail += ' | ' + String(err.stack).substring(0, 500);
    try { globalThis.__lx_native_call__ && __lx_native_call__(key, 'debug', 'onerror:' + detail); } catch(er) {}
  };

  console.log('Preload finished.')
}
)PRELOAD";

// ============ Pure C++ Crypto Helpers ============

// --- MD5 (RFC 1321) ---
static std::string PureMD5(const std::string& input) {
    uint32_t state[4] = { 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476 };
    std::vector<unsigned char> msg(input.begin(), input.end());
    uint64_t bitLen = msg.size() * 8;
    msg.push_back(0x80);
    while ((msg.size() + 8) % 64 != 0) msg.push_back(0);
    for (int i = 0; i < 8; i++) msg.push_back((bitLen >> (i * 8)) & 0xFF);

    uint32_t K[64];
    for (int i = 0; i < 64; i++) K[i] = (uint32_t)(fabs(sin(i + 1.0)) * 4294967296.0);
    uint32_t S[64] = {7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
                       5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,
                       4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
                       6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21};

    #define LR(x,c) (((x)<<(c))|((x)>>(32-(c))))
    for (size_t b = 0; b < msg.size(); b += 64) {
        uint32_t M[16];
        for (int i = 0; i < 16; i++)
            M[i] = msg[b+i*4] | (msg[b+i*4+1]<<8) | (msg[b+i*4+2]<<16) | (msg[b+i*4+3]<<24);
        uint32_t a = state[0], bb = state[1], c = state[2], d = state[3];
        for (int i = 0; i < 64; i++) {
            uint32_t f, g;
            if (i < 16) { f = (bb & c) | (~bb & d); g = i; }
            else if (i < 32) { f = (d & bb) | (~d & c); g = (5*i+1)%16; }
            else if (i < 48) { f = bb ^ c ^ d; g = (3*i+5)%16; }
            else { f = c ^ (bb | ~d); g = (7*i)%16; }
            uint32_t t = d; d = c; c = bb;
            bb = bb + LR(a + f + K[i] + M[g], S[i]);
            a = t;
        }
        state[0] += a; state[1] += bb; state[2] += c; state[3] += d;
    }
    #undef LR

    std::ostringstream oss;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            oss << std::hex << std::setfill('0') << std::setw(2) << ((state[i] >> (j*8)) & 0xFF);
    return oss.str();
}

// --- URL decode ---
static std::string UrlDecode(const std::string& input) {
    std::string result;
    for (size_t i = 0; i < input.size(); i++) {
        if (input[i] == '%' && i + 2 < input.size()) {
            int hex = 0;
            auto hexVal = [](char c) {
                if (c >= '0' && c <= '9') return c - '0';
                if (c >= 'a' && c <= 'f') return c - 'a' + 10;
                if (c >= 'A' && c <= 'F') return c - 'A' + 10;
                return -1;
            };
            int h1 = hexVal(input[i+1]), h2 = hexVal(input[i+2]);
            if (h1 >= 0 && h2 >= 0) { result += (char)(h1 * 16 + h2); i += 2; continue; }
        }
        result += input[i];
    }
    return result;
}

// --- Base64 ---
static const char B64_CHARS[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static int B64_DECODE[256];
static bool b64TableInit = false;
static void initB64Table() {
    if (b64TableInit) return;
    for (int i = 0; i < 256; i++) B64_DECODE[i] = -1;
    for (int i = 0; i < 64; i++) B64_DECODE[(unsigned char)B64_CHARS[i]] = i;
    b64TableInit = true;
}

static std::vector<unsigned char> B64Decode(const std::string& input) {
    initB64Table();
    std::vector<unsigned char> bytes;
    int val = 0, valb = -8;
    for (unsigned char c : input) {
        if (c == '=') break;
        int d = B64_DECODE[c];
        if (d == -1) continue;
        val = (val << 6) + d;
        valb += 6;
        if (valb >= 0) { bytes.push_back((val >> valb) & 0xFF); valb -= 8; }
    }
    return bytes;
}

static std::string B64Encode(const std::vector<unsigned char>& input) {
    std::string result;
    int val = 0, valb = -6;
    for (unsigned char c : input) {
        val = (val << 8) + c;
        valb += 8;
        while (valb >= 0) { result.push_back(B64_CHARS[(val >> valb) & 0x3F]); valb -= 6; }
    }
    if (valb > -6) result.push_back(B64_CHARS[((val << 8) >> (valb + 8)) & 0x3F]);
    while (result.size() % 4) result.push_back('=');
    return result;
}

// --- AES-128 (FIPS 197) ---
static const uint8_t AES_SBOX[256] = {
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

static const uint8_t AES_RCON[11] = {0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36};

static void AesKeyExpand(const uint8_t* key, uint8_t* w) {
    for (int i = 0; i < 16; i++) w[i] = key[i];
    for (int i = 4; i < 44; i++) {
        uint8_t t[4];
        for (int j = 0; j < 4; j++) t[j] = w[(i-1)*4+j];
        if (i % 4 == 0) {
            uint8_t tmp = t[0];
            t[0] = AES_SBOX[t[1]] ^ AES_RCON[i/4];
            t[1] = AES_SBOX[t[2]];
            t[2] = AES_SBOX[t[3]];
            t[3] = AES_SBOX[tmp];
        }
        for (int j = 0; j < 4; j++) w[i*4+j] = w[(i-4)*4+j] ^ t[j];
    }
}

static void AesAddRoundKey(uint8_t* state, const uint8_t* wk, int round) {
    for (int i = 0; i < 16; i++) state[i] ^= wk[round*16+i];
}
static void AesSubBytes(uint8_t* state) {
    for (int i = 0; i < 16; i++) state[i] = AES_SBOX[state[i]];
}
static void AesShiftRows(uint8_t* state) {
    uint8_t t = state[1]; state[1]=state[5]; state[5]=state[9]; state[9]=state[13]; state[13]=t;
    t=state[2];state[2]=state[10];state[10]=t; t=state[6];state[6]=state[14];state[14]=t;
    t=state[3];state[3]=state[15];state[15]=state[11];state[11]=state[7];state[7]=t;
}
static uint8_t AesGfmul(uint8_t a, uint8_t b) {
    uint8_t p = 0;
    for (int i = 0; i < 8; i++) { if (b & 1) p ^= a; bool hi = a & 0x80; a <<= 1; if (hi) a ^= 0x1b; b >>= 1; }
    return p;
}
static void AesMixColumns(uint8_t* state) {
    for (int c = 0; c < 4; c++) {
        uint8_t s0 = state[c], s1=state[c+4], s2=state[c+8], s3=state[c+12];
        state[c]=AesGfmul(2,s0)^AesGfmul(3,s1)^s2^s3;
        state[c+4]=s0^AesGfmul(2,s1)^AesGfmul(3,s2)^s3;
        state[c+8]=s0^s1^AesGfmul(2,s2)^AesGfmul(3,s3);
        state[c+12]=AesGfmul(3,s0)^s1^s2^AesGfmul(2,s3);
    }
}

static void AesEncryptBlock(const uint8_t* in, const uint8_t* wk, uint8_t* out) {
    uint8_t state[16];
    for (int i = 0; i < 16; i++) state[i] = in[i];
    AesAddRoundKey(state, wk, 0);
    for (int r = 1; r < 10; r++) { AesSubBytes(state); AesShiftRows(state); AesMixColumns(state); AesAddRoundKey(state, wk, r); }
    AesSubBytes(state); AesShiftRows(state); AesAddRoundKey(state, wk, 10);
    for (int i = 0; i < 16; i++) out[i] = state[i];
}

static std::vector<unsigned char> AesCbcEncrypt(const std::vector<unsigned char>& data,
    const std::vector<unsigned char>& key, const std::vector<unsigned char>& iv) {
    uint8_t wk[176], key16[16] = {0}, iv16[16] = {0};
    for (size_t i = 0; i < std::min(key.size(), (size_t)16); i++) key16[i] = key[i];
    for (size_t i = 0; i < std::min(iv.size(), (size_t)16); i++) iv16[i] = iv[i];
    AesKeyExpand(key16, wk);

    // PKCS7 padding
    size_t pad = 16 - (data.size() % 16);
    std::vector<unsigned char> padded = data;
    for (size_t i = 0; i < pad; i++) padded.push_back((unsigned char)pad);

    std::vector<unsigned char> result(padded.size());
    uint8_t prev[16];
    for (int i = 0; i < 16; i++) prev[i] = iv16[i];
    for (size_t i = 0; i < padded.size(); i += 16) {
        uint8_t block[16];
        for (int j = 0; j < 16; j++) block[j] = padded[i+j] ^ prev[j];
        AesEncryptBlock(block, wk, &result[i]);
        for (int j = 0; j < 16; j++) prev[j] = result[i+j];
    }
    return result;
}

static std::vector<unsigned char> AesEcbEncrypt(const std::vector<unsigned char>& data,
    const std::vector<unsigned char>& key) {
    uint8_t wk[176], key16[16] = {0};
    for (size_t i = 0; i < std::min(key.size(), (size_t)16); i++) key16[i] = key[i];
    AesKeyExpand(key16, wk);

    size_t pad = 16 - (data.size() % 16);
    std::vector<unsigned char> padded = data;
    for (size_t i = 0; i < pad; i++) padded.push_back((unsigned char)pad);

    std::vector<unsigned char> result(padded.size());
    for (size_t i = 0; i < padded.size(); i += 16)
        AesEncryptBlock(&padded[i], wk, &result[i]);
    return result;
}

// --- RSA Big Integer (simple implementation for modular exponentiation) ---
using BigNum = std::vector<uint8_t>;

static BigNum BigNumAdd(const BigNum& a, const BigNum& b) {
    BigNum r; r.reserve(std::max(a.size(), b.size()) + 1);
    int carry = 0;
    for (size_t i = 0; i < std::max(a.size(), b.size()) || carry; i++) {
        int sum = carry + (i < a.size() ? a[i] : 0) + (i < b.size() ? b[i] : 0);
        r.push_back(sum & 0xFF);
        carry = sum >> 8;
    }
    return r;
}

static BigNum BigNumMul(const BigNum& a, const BigNum& b) {
    BigNum r(a.size() + b.size(), 0);
    for (size_t i = 0; i < a.size(); i++) {
        int carry = 0;
        for (size_t j = 0; j < b.size() || carry; j++) {
            int prod = r[i+j] + a[i] * (j < b.size() ? b[j] : 0) + carry;
            r[i+j] = prod & 0xFF;
            carry = prod >> 8;
        }
    }
    while (r.size() > 1 && r.back() == 0) r.pop_back();
    return r;
}

static int BigNumCmp(const BigNum& a, const BigNum& b) {
    if (a.size() != b.size()) return a.size() > b.size() ? 1 : -1;
    for (int i = (int)a.size() - 1; i >= 0; i--) {
        if (a[i] != b[i]) return a[i] > b[i] ? 1 : -1;
    }
    return 0;
}

static BigNum BigNumSub(const BigNum& a, const BigNum& b) {
    BigNum r(a.size());
    int carry = 0;
    for (size_t i = 0; i < a.size(); i++) {
        int sub = a[i] - carry - (i < b.size() ? b[i] : 0);
        carry = sub < 0 ? 1 : 0;
        r[i] = sub < 0 ? sub + 256 : sub;
    }
    while (r.size() > 1 && r.back() == 0) r.pop_back();
    return r;
}

static void BigNumDivMod(const BigNum& a, const BigNum& b, BigNum& q, BigNum& r) {
    r = a;
    q.assign(a.size(), 0);
    if (BigNumCmp(r, b) < 0) { q.assign(1, 0); return; }

    for (int i = (int)(r.size() * 8 - 1); i >= 0; i--) {
        BigNum t = BigNumMul(b, q); // this is wasteful but simple
        int index = i / 8;
        int bit = i % 8;
        q[index] |= (1 << bit);
        t = BigNumMul(b, q);
        if (BigNumCmp(t, r) > 0) q[index] ^= (1 << bit);
    }
    r = BigNumSub(a, BigNumMul(b, q));
}

static BigNum BigNumMod(const BigNum& a, const BigNum& m) {
    BigNum q, r;
    BigNumDivMod(a, m, q, r);
    return r;
}

static BigNum BigNumModPow(BigNum base, const BigNum& exp, const BigNum& mod) {
    BigNum result(1, 0);
    result[0] = 1;
    BigNum e = exp;
    BigNum m = mod;

    BigNum one(1, 0);
    one[0] = 1;
    BigNum zero(1, 0);

    while (BigNumCmp(e, zero) > 0) {
        if (e[0] & 1) {
            result = BigNumMod(BigNumMul(result, base), m);
        }
        base = BigNumMod(BigNumMul(base, base), m);
        // e >>= 1
        int carry = 0;
        for (int i = (int)e.size() - 1; i >= 0; i--) {
            int v = (carry << 8) | e[i];
            e[i] = (v >> 1) & 0xFF;
            carry = v & 1;
        }
        while (e.size() > 1 && e.back() == 0) e.pop_back();
    }
    return result;
}

// Parse DER SubjectPublicKeyInfo to extract RSA modulus and exponent
static bool ParseRsaPublicKey(const std::vector<unsigned char>& der, BigNum& n, BigNum& e) {
    // X.509 SubjectPublicKeyInfo structure:
    // 30 [len] SEQUENCE
    //   30 [len] AlgorithmIdentifier
    //     06 [len] OID
    //     05 00   NULL (may be absent)
    //   03 [len] BIT STRING
    //     00      (unused bits)
    //     30 [len] SEQUENCE
    //       02 [len] INTEGER (modulus n) - big-endian
    //       02 [len] INTEGER (exponent e) - big-endian
    if (der.size() < 20) return false;

    const uint8_t* p = der.data();
    const uint8_t* end = p + der.size();

    if (*p++ != 0x30) return false; // outer SEQUENCE
    size_t outerLen = *p++;
    if (outerLen > 0x80) { int lenBytes = outerLen & 0x7F; outerLen = 0; for (int i = 0; i < lenBytes; i++) outerLen = (outerLen << 8) | *p++; }

    if (*p++ != 0x30) return false; // AlgorithmIdentifier SEQUENCE
    size_t aiLen = *p++;
    if (aiLen > 0x80) { int lenBytes = aiLen & 0x7F; aiLen = 0; for (int i = 0; i < lenBytes; i++) aiLen = (aiLen << 8) | *p++; }
    p += aiLen; // skip AlgorithmIdentifier

    if (*p++ != 0x03) return false; // BIT STRING
    size_t bitLen = *p++;
    if (bitLen > 0x80) { int lenBytes = bitLen & 0x7F; bitLen = 0; for (int i = 0; i < lenBytes; i++) bitLen = (bitLen << 8) | *p++; }

    p++; // skip unused bits byte (should be 0x00)
    bitLen--;

    if (*p++ != 0x30) return false; // inner SEQUENCE
    size_t innerLen = *p++;
    if (innerLen > 0x80) { int lenBytes = innerLen & 0x7F; innerLen = 0; for (int i = 0; i < lenBytes; i++) innerLen = (innerLen << 8) | *p++; }

    // Read modulus (INTEGER)
    if (*p++ != 0x02) return false;
    size_t nLen = *p++;
    if (nLen > 0x80) { int lenBytes = nLen & 0x7F; nLen = 0; for (int i = 0; i < lenBytes; i++) nLen = (nLen << 8) | *p++; }
    n.clear();
    for (size_t i = 0; i < nLen; i++) n.insert(n.begin(), *p++); // reverse to little-endian

    // Read exponent (INTEGER)
    if (*p++ != 0x02) return false;
    size_t eLen = *p++;
    if (eLen > 0x80) { int lenBytes = eLen & 0x7F; eLen = 0; for (int i = 0; i < lenBytes; i++) eLen = (eLen << 8) | *p++; }
    e.clear();
    for (size_t i = 0; i < eLen; i++) e.insert(e.begin(), *p++);

    return true;
}

// ============ Singleton ============

JsvmEngine& JsvmEngine::GetInstance() {
    static JsvmEngine instance;
    return instance;
}

JsvmEngine::~JsvmEngine() {
    ReleaseEngine();
}

// ============ Engine Lifecycle ============

void JsvmEngine::CreateEngine() {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (ready_) {
        OH_LOG_INFO(LOG_APP, "JsvmEngine already created");
        return;
    }
    InitJSVM();
}

void JsvmEngine::InitJSVM() {
    // Step 1: Initialize JSVM subsystem (REQUIRED before CreateVM)
    // NOTE: OH_JSVM_Init is a global init that should only be called once per process.
    // Calling it again after ReleaseEngine can cause subsequent VM creation to fail.
    JSVM_Status status = JSVM_OK;
    if (!jsvmGlobalInited_) {
        JSVM_InitOptions initOptions = { nullptr, nullptr, nullptr, false };
        status = OH_JSVM_Init(&initOptions);
        if (status != JSVM_OK) {
            OH_LOG_ERROR(LOG_APP, "Failed to init JSVM, status=%{public}d", (int)status);
            return;
        }
        jsvmGlobalInited_ = true;
    }

    // Step 2: Create VM
    JSVM_VM vm = nullptr;
    JSVM_CreateVMOptions vmOptions = { 0, 0, 0, 0, nullptr, 0, false };
    // Set reasonable memory limits to avoid V8 assertions
    vmOptions.maxOldGenerationSize = 16 * 1024 * 1024;   // 16MB old space
    vmOptions.maxYoungGenerationSize = 4 * 1024 * 1024;   // 4MB young space
    status = OH_JSVM_CreateVM(&vmOptions, &vm);
    if (status != JSVM_OK || vm == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Failed to create JSVM, status=%{public}d", (int)status);
        return;
    }

    jsVM_ = vm;
    status = OH_JSVM_CreateEnv(vm, 0, nullptr, &jsEnv_);
    if (status != JSVM_OK || jsEnv_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Failed to create JSVM environment");
        OH_JSVM_DestroyVM(vm);
        return;
    }

    // Open EnvScope (equivalent to V8 Context::Scope) — REQUIRED for script compilation
    OH_JSVM_OpenEnvScope(jsEnv_, &envScope_);

    // Quick smoke test: run a trivial script to verify JSVM works
    {
        JSVM_HandleScope scope = nullptr;
        OH_JSVM_OpenHandleScope(jsEnv_, &scope);
        const char* testScript = "1+1";
        JSVM_Value testStr = nullptr;
        OH_JSVM_CreateStringUtf8(jsEnv_, testScript, strlen(testScript), &testStr);
        JSVM_Script testScr = nullptr;
        JSVM_Value testResult = nullptr;
        status = OH_JSVM_CompileScript(jsEnv_, testStr, nullptr, 0, false, nullptr, &testScr);
        if (status == JSVM_OK && testScr) {
            OH_JSVM_RunScript(jsEnv_, testScr, &testResult);
            OH_LOG_INFO(LOG_APP, "JSVM smoke test OK");
        } else {
            OH_LOG_ERROR(LOG_APP, "JSVM smoke test failed: compile=%{public}d", (int)status);
        }
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
    }

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 15);
    const char hexChars[] = "0123456789abcdef";
    randomKey_.clear();
    for (int i = 0; i < 36; i++) {
        if (i == 8 || i == 13 || i == 18 || i == 23) randomKey_ += '-';
        else randomKey_ += hexChars[dis(gen)];
    }

    ready_ = true;
    OH_LOG_INFO(LOG_APP, "JSVM engine created, key=%{public}s", randomKey_.c_str());
}

bool JsvmEngine::ExecuteScript(const std::string& scriptContent, const std::string& scriptId) {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (!ready_) {
        OH_LOG_ERROR(LOG_APP, "Engine not ready");
        return false;
    }

    currentScriptId_ = scriptId;
    OH_LOG_INFO(LOG_APP, "ExecuteScript: id=%{public}s, size=%{public}zu", scriptId.c_str(), scriptContent.size());

    InjectNativeFunctions();

    if (!EvaluatePreloadScript(scriptId)) {
        OH_LOG_ERROR(LOG_APP, "Preload script evaluation failed");
        return false;
    }

    std::string setupJs = "lx_setup('" + randomKey_ + "', '" + scriptId
        + "', 'Unknown', '', '1.0.0', '', '', '" + scriptId + "')";
    {
        JSVM_HandleScope scope = nullptr;
        OH_JSVM_OpenHandleScope(jsEnv_, &scope);
        JSVM_Value setupStr = nullptr;
        OH_JSVM_CreateStringUtf8(jsEnv_, setupJs.c_str(), setupJs.size(), &setupStr);
        JSVM_Script setupScr = nullptr;
        if (OH_JSVM_CompileScript(jsEnv_, setupStr, nullptr, 0, false, nullptr, &setupScr) == JSVM_OK) {
            JSVM_Value result = nullptr;
            OH_JSVM_RunScript(jsEnv_, setupScr, &result);
        }
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
    }

    if (!EvaluateUserScript(scriptContent, scriptId)) {
        OH_LOG_WARN(LOG_APP, "User script issues for: %{public}s", scriptId.c_str());
        JsCall("__run_error__", "");
    }

    OH_LOG_INFO(LOG_APP, "ExecuteScript complete: %{public}s", scriptId.c_str());
    return true;
}

void JsvmEngine::InjectNativeFunctions() {
    if (!jsEnv_) return;

    JSVM_HandleScope scope = nullptr;
    OH_JSVM_OpenHandleScope(jsEnv_, &scope);

    JSVM_Value globalObj = nullptr;
    OH_JSVM_GetGlobal(jsEnv_, &globalObj);

    // Helper: allocate a JSVM_CallbackStruct and register a native function
    auto reg = [&](const char* name, JSVM_Value (*fnPtr)(JSVM_Env, JSVM_CallbackInfo)) {
        auto* cbStruct = new JSVM_CallbackStruct{fnPtr, nullptr};
        JSVM_Value fn = nullptr;
        OH_JSVM_CreateFunction(jsEnv_, name, JSVM_AUTO_LENGTH, cbStruct, &fn);
        OH_JSVM_SetNamedProperty(jsEnv_, globalObj, name, fn);
    };

    reg("__lx_native_call__", NativeCallCb);
    reg("__lx_native_call__utils_str2b64", UtilsStr2B64Cb);
    reg("__lx_native_call__utils_b642buf", UtilsB642BufCb);
    reg("__lx_native_call__utils_str2md5", UtilsStr2Md5Cb);
    reg("__lx_native_call__utils_aes_encrypt", UtilsAesEncryptCb);
    reg("__lx_native_call__utils_rsa_encrypt", UtilsRsaEncryptCb);
    reg("__lx_native_call__set_timeout", SetTimeoutCb);

    OH_JSVM_CloseHandleScope(jsEnv_, scope);
    OH_LOG_INFO(LOG_APP, "7 native functions injected");
}

bool JsvmEngine::EvaluatePreloadScript(const std::string& scriptId) {
    if (!jsEnv_) return false;
    OH_LOG_INFO(LOG_APP, "Evaluating preload, size=%{public}zu", strlen(PRELOAD_SCRIPT));

    JSVM_HandleScope scope = nullptr;
    OH_JSVM_OpenHandleScope(jsEnv_, &scope);

    JSVM_Value scriptStr = nullptr;
    OH_JSVM_CreateStringUtf8(jsEnv_, PRELOAD_SCRIPT, strlen(PRELOAD_SCRIPT), &scriptStr);
    JSVM_Script script = nullptr;
    JSVM_Status st = OH_JSVM_CompileScript(jsEnv_, scriptStr, nullptr, 0, false, nullptr, &script);
    if (st != JSVM_OK) {
        JSVM_Value exc = nullptr;
        OH_JSVM_GetAndClearLastException(jsEnv_, &exc);
        if (exc) OH_LOG_ERROR(LOG_APP, "Preload compile: %{public}s", JsvmValueToString(jsEnv_, exc).c_str());
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
        return false;
    }
    JSVM_Value result = nullptr;
    st = OH_JSVM_RunScript(jsEnv_, script, &result);
    if (st != JSVM_OK) {
        JSVM_Value exc = nullptr;
        OH_JSVM_GetAndClearLastException(jsEnv_, &exc);
        if (exc) OH_LOG_ERROR(LOG_APP, "Preload run: %{public}s", JsvmValueToString(jsEnv_, exc).c_str());
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
        return false;
    }
    OH_JSVM_CloseHandleScope(jsEnv_, scope);
    OH_LOG_INFO(LOG_APP, "Preload OK");
    return true;
}

bool JsvmEngine::EvaluateUserScript(const std::string& scriptContent, const std::string& scriptId) {
    if (!jsEnv_) return false;

    JSVM_HandleScope scope = nullptr;
    OH_JSVM_OpenHandleScope(jsEnv_, &scope);

    JSVM_Value scriptStr = nullptr;
    OH_JSVM_CreateStringUtf8(jsEnv_, scriptContent.c_str(), scriptContent.size(), &scriptStr);
    JSVM_Script script = nullptr;
    JSVM_Status st = OH_JSVM_CompileScript(jsEnv_, scriptStr, nullptr, 0, false, nullptr, &script);
    if (st != JSVM_OK) {
        JSVM_Value exc = nullptr;
        OH_JSVM_GetAndClearLastException(jsEnv_, &exc);
        if (exc) OH_LOG_ERROR(LOG_APP, "Script compile(%{public}s): %{public}s", scriptId.c_str(), JsvmValueToString(jsEnv_, exc).c_str());
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
        return false;
    }
    JSVM_Value result = nullptr;
    st = OH_JSVM_RunScript(jsEnv_, script, &result);
    if (st != JSVM_OK) {
        JSVM_Value exc = nullptr;
        OH_JSVM_GetAndClearLastException(jsEnv_, &exc);
        if (exc) OH_LOG_ERROR(LOG_APP, "Script run(%{public}s): %{public}s", scriptId.c_str(), JsvmValueToString(jsEnv_, exc).c_str());
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
        return false;
    }
    OH_JSVM_CloseHandleScope(jsEnv_, scope);
    OH_LOG_INFO(LOG_APP, "User script OK: %{public}s", scriptId.c_str());
    return true;
}

std::string JsvmEngine::JsCall(const std::string& action, const std::string& data) {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (!ready_ || !jsEnv_) {
        OH_LOG_WARN(LOG_APP, "JsCall(%{public}s): engine not ready", action.c_str());
        return "engine not ready";
    }

    OH_LOG_INFO(LOG_APP, "JsCall: %{public}s dataLen=%{public}zu", action.c_str(), data.size());

    JSVM_HandleScope scope = nullptr;
    OH_JSVM_OpenHandleScope(jsEnv_, &scope);

    JSVM_Value globalObj = nullptr;
    OH_JSVM_GetGlobal(jsEnv_, &globalObj);
    JSVM_Value nativeFn = nullptr;
    if (OH_JSVM_GetNamedProperty(jsEnv_, globalObj, "__lx_native__", &nativeFn) != JSVM_OK) {
        OH_JSVM_CloseHandleScope(jsEnv_, scope);
        return "__lx_native__ not found";
    }

    JSVM_Value args[3];
    OH_JSVM_CreateStringUtf8(jsEnv_, randomKey_.c_str(), randomKey_.size(), &args[0]);
    OH_JSVM_CreateStringUtf8(jsEnv_, action.c_str(), action.size(), &args[1]);
    if (data.empty()) OH_JSVM_GetNull(jsEnv_, &args[2]);
    else OH_JSVM_CreateStringUtf8(jsEnv_, data.c_str(), data.size(), &args[2]);

    JSVM_Value result = nullptr;
    std::string resultStr;
    JSVM_Status callStatus = OH_JSVM_CallFunction(jsEnv_, globalObj, nativeFn, 3, args, &result);
    if (callStatus != JSVM_OK) {
        JSVM_Value exc = nullptr;
        OH_JSVM_GetAndClearLastException(jsEnv_, &exc);
        resultStr = exc ? JsvmValueToString(jsEnv_, exc) : "call failed";
        OH_LOG_ERROR(LOG_APP, "JsCall(%{public}s) exception: %{public}s", action.c_str(), resultStr.c_str());
    } else {
        resultStr = JsvmValueToString(jsEnv_, result);
    }
    if (action == "response" || action == "init") {
        OH_LOG_INFO(LOG_APP, "JsCall(%{public}s) ret=%{public}s", action.c_str(), resultStr.c_str());
    }

    OH_JSVM_CloseHandleScope(jsEnv_, scope);
    return resultStr;
}

// ============ Native Function Callbacks ============

JSVM_Value JsvmEngine::NativeCallCb(JSVM_Env env, JSVM_CallbackInfo info) {
    std::string key = GetArgString(env, info, 0);
    std::string action = GetArgString(env, info, 1);
    std::string data = GetArgString(env, info, 2);
    JsvmEngine& engine = GetInstance();

    if (key != engine.randomKey_) { JSVM_Value r = nullptr; OH_JSVM_GetNull(env, &r); return r; }
    if (engine.actionCallback_) engine.actionCallback_(action, data);

    JSVM_Value r = nullptr; OH_JSVM_GetNull(env, &r); return r;
}

JSVM_Value JsvmEngine::UtilsStr2B64Cb(JSVM_Env env, JSVM_CallbackInfo info) {
    std::string in = GetArgString(env, info, 0);
    std::string r = B64Encode(std::vector<unsigned char>(in.begin(), in.end()));
    JSVM_Value jsR = nullptr;
    OH_JSVM_CreateStringUtf8(env, r.c_str(), r.size(), &jsR);
    return jsR;
}

JSVM_Value JsvmEngine::UtilsB642BufCb(JSVM_Env env, JSVM_CallbackInfo info) {
    std::string in = GetArgString(env, info, 0);
    auto bytes = B64Decode(in);
    std::ostringstream oss; oss << "[";
    for (size_t i = 0; i < bytes.size(); i++) { if (i) oss << ","; oss << (int)bytes[i]; }
    oss << "]";
    std::string r = oss.str();
    JSVM_Value jsR = nullptr;
    OH_JSVM_CreateStringUtf8(env, r.c_str(), r.size(), &jsR);
    return jsR;
}

JSVM_Value JsvmEngine::UtilsStr2Md5Cb(JSVM_Env env, JSVM_CallbackInfo info) {
    std::string in = GetArgString(env, info, 0);
    std::string decoded = UrlDecode(in);
    std::string r = PureMD5(decoded);
    JSVM_Value jsR = nullptr;
    OH_JSVM_CreateStringUtf8(env, r.c_str(), r.size(), &jsR);
    return jsR;
}

JSVM_Value JsvmEngine::UtilsAesEncryptCb(JSVM_Env env, JSVM_CallbackInfo info) {
    std::string dataB64 = GetArgString(env, info, 0);
    std::string keyB64 = GetArgString(env, info, 1);
    std::string ivB64 = GetArgString(env, info, 2);
    std::string mode = GetArgString(env, info, 3);

    auto data = B64Decode(dataB64);
    auto key = B64Decode(keyB64);
    bool isECB = (mode.find("ECB") != std::string::npos);

    std::vector<unsigned char> result;
    if (isECB) {
        result = AesEcbEncrypt(data, key);
    } else {
        auto iv = B64Decode(ivB64);
        result = AesCbcEncrypt(data, key, iv);
    }

    std::string r = B64Encode(result);
    JSVM_Value jsR = nullptr;
    OH_JSVM_CreateStringUtf8(env, r.c_str(), r.size(), &jsR);
    return jsR;
}

JSVM_Value JsvmEngine::UtilsRsaEncryptCb(JSVM_Env env, JSVM_CallbackInfo info) {
    std::string dataB64 = GetArgString(env, info, 0);
    std::string key = GetArgString(env, info, 1);

    auto data = B64Decode(dataB64);
    auto keyBytes = B64Decode(key);

    BigNum n, e;
    if (!ParseRsaPublicKey(keyBytes, n, e)) {
        OH_LOG_ERROR(LOG_APP, "RSA: failed to parse public key");
        JSVM_Value jsR = nullptr; OH_JSVM_CreateStringUtf8(env, "", 0, &jsR); return jsR;
    }

    size_t keySize = n.size();
    // Pad data to keySize bytes with zeros on the LEFT (big-endian perspective)
    BigNum m(keySize, 0);
    for (size_t i = 0; i < std::min(data.size(), keySize); i++)
        m[keySize - 1 - i] = data[data.size() - 1 - i];

    BigNum enc = BigNumModPow(m, e, n);

    // Result should be exactly keySize bytes
    std::vector<unsigned char> result(keySize, 0);
    for (size_t i = 0; i < std::min(enc.size(), keySize); i++)
        result[keySize - 1 - i] = enc[i];

    std::string r = B64Encode(result);
    JSVM_Value jsR = nullptr;
    OH_JSVM_CreateStringUtf8(env, r.c_str(), r.size(), &jsR);
    return jsR;
}

JSVM_Value JsvmEngine::SetTimeoutCb(JSVM_Env env, JSVM_CallbackInfo info) {
    int id = GetArgInt(env, info, 0, 0);
    int ms = GetArgInt(env, info, 1, 0);
    std::thread([id, ms]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(ms));
        JsvmEngine::GetInstance().JsCall("__set_timeout__", std::to_string(id));
    }).detach();
    JSVM_Value r = nullptr; OH_JSVM_GetNull(env, &r); return r;
}

void JsvmEngine::ReleaseEngine() {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (!ready_) return;
    if (envScope_) {
        OH_JSVM_CloseEnvScope(jsEnv_, envScope_);
        envScope_ = nullptr;
    }
    if (jsEnv_) {
        OH_JSVM_DestroyEnv(jsEnv_);
        jsEnv_ = nullptr;
    }
    if (jsVM_) {
        OH_JSVM_DestroyVM(jsVM_);
        jsVM_ = nullptr;
    }
    ready_ = false;
    currentScriptId_.clear();
    randomKey_.clear();
    OH_LOG_INFO(LOG_APP, "JsvmEngine released");
}

void JsvmEngine::SetActionCallback(NativeActionCallback cb) {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    actionCallback_ = std::move(cb);
}

std::string JsvmEngine::JsvmValueToString(JSVM_Env env, JSVM_Value value) {
    if (!value) return "null";
    size_t len = 0;
    OH_JSVM_GetValueStringUtf8(env, value, nullptr, 0, &len);
    std::string result(len, '\0');
    OH_JSVM_GetValueStringUtf8(env, value, &result[0], len + 1, &len);
    return result;
}

std::string JsvmEngine::GetArgString(JSVM_Env env, JSVM_CallbackInfo info, int index) {
    size_t argc = index + 1;
    JSVM_Value* args = new JSVM_Value[argc];
    OH_JSVM_GetCbInfo(env, info, &argc, args, nullptr, nullptr);
    if (index >= (int)argc) { delete[] args; return ""; }
    std::string r = JsvmValueToString(env, args[index]);
    delete[] args;
    return r;
}

int JsvmEngine::GetArgInt(JSVM_Env env, JSVM_CallbackInfo info, int index, int defaultVal) {
    size_t argc = index + 1;
    JSVM_Value* args = new JSVM_Value[argc];
    OH_JSVM_GetCbInfo(env, info, &argc, args, nullptr, nullptr);
    if (index >= (int)argc) { delete[] args; return defaultVal; }
    int32_t val = defaultVal;
    OH_JSVM_GetValueInt32(env, args[index], &val);
    delete[] args;
    return val;
}

} // namespace JsAudioEngine
