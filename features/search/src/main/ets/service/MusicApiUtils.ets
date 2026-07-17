/*
 * MusicApiUtils - 共享工具、接口、常量
 */
import { util } from '@kit.ArkTS'

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

/** QQ 获取 vkey 请求模块 */
export interface QQVkeyModule {
  module: string
  method: string
  param: QQVkeyParam
}

/** QQ 获取 vkey 请求体 */
export interface QQVkeyBody {
  req_0: QQVkeyModule
}

/** 播放 URL 获取结果 */
export interface PlayUrlResult {
  url: string
  lyrics: string
  cover: string
}

/** QQ 热搜请求体 */
export interface QQHotKeyComm {
  ct: string; cv: string; guid: string; patch: string
  psrf_access_token_expiresAt: number; psrf_qqaccess_token: string
  psrf_qqopenid: string; psrf_qqunionid: string; tmeAppID: string
  tmeLoginType: number; uin: string; wid: string
}
export interface QQHotKeyParam { search_id: string; uin: number }
export interface QQHotKeyModule { method: string; module: string; param: QQHotKeyParam }
export interface QQHotKeyBody { comm: QQHotKeyComm; hotkey: QQHotKeyModule }

/** 平台标识映射 */
export function platformToId(platform: string): string {
  const map: Record<string, string> = { 'kugou': 'kg', 'qq': 'tx', 'netease': 'wy', 'kuwo': 'kw', 'migu': 'mg' }
  return map[platform] || platform
}

/** 秒数转 mm:ss */
export function formatDuration(seconds: number): string {
  if (!seconds || seconds <= 0 || !isFinite(seconds)) { return '--:--' }
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}

/** Base64 解码歌词 */
export function decodeBase64Lyric(encoded: string): string {
  if (!encoded) { return '' }
  try {
    const helper = new util.Base64Helper()
    const uint8 = helper.decodeSync(encoded)
    const decoder = new util.TextDecoder('utf-8')
    return decoder.decodeToString(uint8)
  } catch (_) {
    try { return decodeURIComponent(encoded) } catch (__) { return '' }
  }
}
