/*
 * MusicApiService - 音乐平台 API 调度层
 * 将请求分发到各平台实现（platform/KgMusicApi, TxMusicApi, ...）
 */
import { SearchResultItem } from '../model/SearchResultItem'
import { SuggestionItem } from '../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { PlayUrlResult, platformToId, TAG } from './MusicApiUtils'
import { KgMusicApi } from './platform/KgMusicApi'
import { TxMusicApi } from './platform/TxMusicApi'
import { WyMusicApi } from './platform/WyMusicApi'
import { KwMusicApi } from './platform/KwMusicApi'
import { MgMusicApi } from './platform/MgMusicApi'
export { PlayUrlResult } from './MusicApiUtils'

export class MusicApiService {
  // ===== 搜索 =====
  public static async search(keyword: string, platform: string, page: number = 1, limit: number = 30): Promise<SearchResultItem[]> {
    const pid = platformToId(platform)
    switch (pid) {
      case 'kg': return KgMusicApi.search(keyword, page, limit)
      case 'tx': return TxMusicApi.search(keyword, page, limit)
      case 'wy': return WyMusicApi.search(keyword, page, limit)
      case 'kw': return KwMusicApi.search(keyword, page, limit)
      case 'mg': return MgMusicApi.search(keyword, page, limit)
      default: return []
    }
  }

  // ===== 热搜 =====
  public static async hotSearch(platform: string): Promise<string[]> {
    const pid = platformToId(platform)
    switch (pid) {
      case 'wy': return WyMusicApi.hotSearch()
      case 'tx': return TxMusicApi.hotSearch()
      case 'kg': return KgMusicApi.hotSearch()
      case 'kw': return KwMusicApi.hotSearch()
      case 'mg': return MgMusicApi.hotSearch()
      default: return WyMusicApi.hotSearch()
    }
  }

  // ===== 联想（带降级回退链） =====
  public static async suggest(keyword: string, platform: string): Promise<SuggestionItem[]> {
    const pid = platformToId(platform)
    const primary = await MusicApiService.suggestByPlatform(pid, keyword)
    if (primary.length > 0) { return primary }
    const fallbackOrder = ['tx', 'wy', 'kw', 'mg'].filter(p => p !== pid)
    for (const fbPid of fallbackOrder) {
      const result = await MusicApiService.suggestByPlatform(fbPid, keyword)
      if (result.length > 0) { Logger.info(TAG, `suggest fallback from ${pid} to ${fbPid}`); return result }
    }
    return []
  }

  private static async suggestByPlatform(pid: string, keyword: string): Promise<SuggestionItem[]> {
    switch (pid) {
      case 'kg': return KgMusicApi.suggest(keyword)
      case 'tx': return TxMusicApi.suggest(keyword)
      case 'wy': return WyMusicApi.suggest(keyword)
      case 'kw': return KwMusicApi.suggest(keyword)
      case 'mg': return MgMusicApi.suggest(keyword)
      default: return []
    }
  }

  // ===== 播放URL =====
  public static async getPlayUrl(songId: string, source: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    const pid = platformToId(source)
    switch (pid) {
      case 'kg': return KgMusicApi.getPlayUrl(songId, rawFields)
      case 'tx': return TxMusicApi.getPlayUrl(songId, rawFields)
      case 'wy': return WyMusicApi.getPlayUrl(songId)
      case 'kw': return KwMusicApi.getPlayUrl(songId)
      case 'mg': return MgMusicApi.getPlayUrl(songId, rawFields)
      default: return { url: '', lyrics: '', cover: '' }
    }
  }

  // ===== 工具 =====
  public static defaultHotSearches(): string[] {
    return ['周杰伦', '邓紫棋', '林俊杰', '陈奕迅', 'Taylor Swift', 'IU']
  }

  public static async searchSongs(keyword: string, platform?: string): Promise<SearchResultItem[]> {
    return MusicApiService.search(keyword, platform || 'kugou', 1, 30)
  }
}
