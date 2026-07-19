/*
 * api-source.ets - 音源抽象层（对齐 lx-music-mobile api-source.js）
 * apis(source) 返回对应平台对象；当前无镜像切换，直接返回平台对象，
 * 预留后续按 source 切换镜像的实现位置。
 */
import wy from './wy/index'
import tx from './tx/index'
import kg from './kg/index'
import kw from './kw/index'
import mg from './mg/index'
import { supportQualitys } from './api-source-info'
import type { MusicPlatform, SearchResult, SuggestionItem, CommentResult, BoardListResult } from './types'

export const supportQuality: Record<string, Record<string, string>> = supportQualitys

export function apis(source: string): MusicPlatform {
  switch (source) {
    case 'wy': return wy
    case 'tx': return tx
    case 'kg': return kg
    case 'kw': return kw
    case 'mg': return mg
    default:
      throw new Error(`musicSdk: unknown source "${source}"`)
  }
}
