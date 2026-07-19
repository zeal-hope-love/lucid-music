/*
 * tx/qqTypes.ets - QQ音乐接口请求体类型（对齐 lx-music-mobile tx 端点）
 * 仅声明结构，供 hotSearch / musicInfo 组装请求体时使用，避免无类型对象字面量。
 */

export interface QQVkeyParam {
  guid: string
  songmid: Array<string>
  songtype: Array<number>
  uin: string
  loginflag: number
  platform: string
}

export interface QQVkeyReq0 {
  module: string
  method: string
  param: QQVkeyParam
}

export interface QQVkeyBody {
  req_0: QQVkeyReq0
}

export interface QQHotKeyParam {
  search_id: string
  uin: number
}

export interface QQHotKeyHotkey {
  method: string
  module: string
  param: QQHotKeyParam
}

export interface QQHotKeyBody {
  comm: Record<string, Object>
  hotkey: QQHotKeyHotkey
}
