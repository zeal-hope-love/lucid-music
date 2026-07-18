/*
 * MusicApiUtils - 共享工具、接口、常量
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { buffer, util } from '@kit.ArkTS'

export const TAG = 'MusicApiService'

/** QQ 获取 vkey 请求参数 */
export interface QQVkeyParam {
  guid: string
  songmid: string[]
  songtype: number[]
  uin: string
  loginflag: number
  platform: string
}
export interface QQVkeyModule {
  module: string
  method: string
  param: QQVkeyParam
}
export interface QQVkeyBody {
  req_0: QQVkeyModule
}
export interface PlayUrlResult {
  url: string
  lyrics: string
  cover: string
}
export interface QQHotKeyComm {
  ct: string; cv: string; guid: string; patch: string
  psrf_access_token_expiresAt: number; psrf_qqaccess_token: string
  psrf_qqopenid: string; psrf_qqunionid: string; tmeAppID: string
  tmeLoginType: number; uin: string; wid: string
}
export interface QQHotKeyParam { search_id: string; uin: number }
export interface QQHotKeyModule { method: string; module: string; param: QQHotKeyParam }
export interface QQHotKeyBody { comm: QQHotKeyComm; hotkey: QQHotKeyModule }

// ===== eapi 加密 =====
const EAPI_KEY = 'e82ckenh8dichen8'

async function md5Hex(input: string): Promise<string> {
  const md = cryptoFramework.createMd('MD5')
  await md.update({ data: new Uint8Array(buffer.from(input, 'utf-8').buffer) })
  const r = await md.digest()
  let h = ''
  for (const b of r.data) { h += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16) }
  return h
}

async function aesEcbEncryptBase64(b64Input: string): Promise<string> {
  const h = new util.Base64Helper()
  const plain = h.decodeSync(b64Input)
  const keyGen = cryptoFramework.createSymKeyGenerator('AES128')
  const keyBlob: cryptoFramework.DataBlob = { data: new Uint8Array(buffer.from(EAPI_KEY, 'utf-8').buffer) }
  const symKey = await keyGen.convertKey(keyBlob)
  // 对齐 lx-music-mobile: Cipher.getInstance("AES") 默认 PKCS5Padding (=PKCS7)
  const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7')
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null!)
  const out = await cipher.doFinal({ data: plain })
  return h.encodeToString(out.data)
}

export async function eapiEncrypt(url: string, data: ESObject): Promise<string> {
  const jsonStr = JSON.stringify(data)
  const digest = await md5Hex(`nobody${url}use${jsonStr}md5forencrypt`)
  const plain = `${url}-36cd479b6b5-${jsonStr}-36cd479b6b5-${digest}`
  const h = new util.Base64Helper()
  const plainB64 = h.encodeToStringSync(new Uint8Array(buffer.from(plain, 'utf-8').buffer))
  const cipherB64 = await aesEcbEncryptBase64(plainB64)
  const cipherBytes = h.decodeSync(cipherB64)
  let hex = ''
  for (const b of cipherBytes) { hex += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16).toUpperCase() }
  return hex
}

// ===== weapi 加密 =====
const WEAPI_PRESET_KEY = '0CoJUm6Qyw8W8jud'
const WEAPI_IV = '0102030405060708'
const WEAPI_RSA_PEM = `-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ37BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB
-----END PUBLIC KEY-----`

function randomStr(len: number): string {
  const c = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  let r = ''
  for (let i = 0; i < len; i++) { r += c.charAt(Math.floor(Math.random() * c.length)) }
  return r
}

function pemToDer(pem: string): Uint8Array {
  return new util.Base64Helper().decodeSync(pem.replace(/-----.*-----/g, '').replace(/\s/g, ''))
}

async function aesCbcEncryptBase64(b64Input: string, keyStr: string, ivStr: string): Promise<string> {
  const h = new util.Base64Helper()
  const plainBytes = h.decodeSync(b64Input)
  const keyBytes = new Uint8Array(buffer.from(keyStr, 'utf-8').buffer)
  const ivBytes = new Uint8Array(buffer.from(ivStr, 'utf-8').buffer)
  const keyGen = cryptoFramework.createSymKeyGenerator('AES128')
  const symKey = await keyGen.convertKey({ data: keyBytes })
  const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7')
  const ivParams: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: { data: ivBytes } }
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivParams)
  const out = await cipher.doFinal({ data: plainBytes })
  return h.encodeToString(out.data)
}

async function rsaEncryptNoPadding(data: Uint8Array): Promise<Uint8Array> {
  const der = pemToDer(WEAPI_RSA_PEM)
  const keyGen = cryptoFramework.createAsyKeyGenerator('RSA1024')
  const keyPair = await keyGen.convertKey({ data: der }, null!)
  const cipher = cryptoFramework.createCipher('RSA1024|NoPadding')
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, keyPair.pubKey!, null!)
  const out = await cipher.doFinal({ data: data })
  return out.data
}

function bytesToLowerHex(bytes: Uint8Array): string {
  let h = ''
  for (const b of bytes) { h += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16) }
  return h
}

export interface WeapiResult { params: string; encSecKey: string }

export async function weapiEncrypt(data: ESObject): Promise<WeapiResult> {
  const h = new util.Base64Helper()
  const jsonStr = JSON.stringify(data)
  const plainB64 = h.encodeToStringSync(new Uint8Array(buffer.from(jsonStr, 'utf-8').buffer))
  const first = await aesCbcEncryptBase64(plainB64, WEAPI_PRESET_KEY, WEAPI_IV)
  const rk = randomStr(16)
  // 第二层 AES 需要对第一层结果做 base64 编码（对齐 lx-music-mobile 的 btoa(first) 行为）
  // 使 aesCbcEncryptBase64 内部 decodeSync 后得到字符串字节而非二进制密文
  const firstB64 = h.encodeToStringSync(new Uint8Array(buffer.from(first, 'utf-8').buffer))
  const second = await aesCbcEncryptBase64(firstB64, rk, WEAPI_IV)
  const keyBytes = new Uint8Array(buffer.from(rk, 'utf-8').buffer)
  const rev = new Uint8Array(keyBytes.length)
  for (let i = 0; i < keyBytes.length; i++) { rev[i] = keyBytes[keyBytes.length - 1 - i] }
  const rsaInput = new Uint8Array(128)
  rsaInput.set(rev, 128 - rev.length)
  const rsaOut = await rsaEncryptNoPadding(rsaInput)
  return { params: second, encSecKey: bytesToLowerHex(rsaOut) }
}

// ===== 通用工具 =====
export function platformToId(platform: string): string {
  const m: Record<string, string> = { 'kugou': 'kg', 'qq': 'tx', 'netease': 'wy', 'kuwo': 'kw', 'migu': 'mg' }
  return m[platform] || platform
}

export function formatDuration(seconds: number): string {
  if (!seconds || seconds <= 0 || !isFinite(seconds)) { return '--:--' }
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

export function decodeBase64Lyric(encoded: string): string {
  if (!encoded) { return '' }
  try {
    const u = new util.Base64Helper().decodeSync(encoded)
    return new util.TextDecoder('utf-8').decodeToString(u)
  } catch (_) {
    try { return decodeURIComponent(encoded) } catch (__) { return '' }
  }
}
