/*
 * ApiSource - 音乐平台 API 统一调度层
 * 参考 lx-music-mobile 的 api-source.js 架构
 * 所有端点委托 apis(source) 返回的平台对象方法执行。
 */
import { Logger } from 'musicbasic'
import { platformToId } from './utils'
import { apis } from './api-source'
import type { SearchResult, SuggestionItem, CommentResult, BoardListResult } from './types'
import type { PlayUrlResult, MusichallPlaylistItem, TagFilterGroup, PlaylistDetailResult } from 'musicbasic'
import { MusichallPlaylistPage, PlaylistMeta } from 'musicbasic'

const TAG = 'ApiSource'

function emptyResult(source: string, limit: number): SearchResult {
  return { list: [], allPage: 1, limit, total: 0, source }
}

function emptyDetailResult(source: string, limit: number): PlaylistDetailResult {
  return { list: [], allPage: 1, limit, total: 0, source, info: new PlaylistMeta() }
}

export class ApiSource {
  // ===== 搜索 =====
  public static async search(keyword: string, platform: string, page: number = 1, limit: number = 30): Promise<SearchResult> {
    try {
      return await apis(platformToId(platform)).search(keyword, page, limit)
    } catch (e) {
      Logger.error(TAG, `search err: ${JSON.stringify(e)}`)
      return emptyResult(platformToId(platform), limit)
    }
  }

  // ===== 热搜 =====
  public static async hotSearch(platform: string): Promise<string[]> {
    try {
      return await apis(platformToId(platform)).hotSearch()
    } catch (e) {
      Logger.error(TAG, `hotSearch err: ${JSON.stringify(e)}`)
      return []
    }
  }

  // ===== 默认热搜（平台热搜为空时的兜底） =====
  public static defaultHotSearches(): string[] {
    return ['周杰伦', '邓紫棋', '林俊杰', '陈奕迅', 'Taylor Swift', 'IU']
  }

  // ===== 便捷搜索（默认酷狗，第 1 页 30 条） =====
  public static async searchSongs(keyword: string, platform?: string): Promise<SearchResult> {
    return ApiSource.search(keyword, platform || 'kugou', 1, 30)
  }

  // ===== 搜索建议 =====
  public static async suggest(keyword: string, platform: string): Promise<SuggestionItem[]> {
    try {
      return await apis(platformToId(platform)).suggest(keyword)
    } catch (e) {
      Logger.error(TAG, `suggest err: ${JSON.stringify(e)}`)
      return []
    }
  }

  // ===== 智能提示 =====
  public static async tipSearch(keyword: string, platform: string): Promise<SuggestionItem[]> {
    try {
      return await apis(platformToId(platform)).getTipSearch(keyword)
    } catch (e) {
      Logger.error(TAG, `tipSearch err: ${JSON.stringify(e)}`)
      return []
    }
  }

  // ===== 播放URL =====
  public static async getPlayUrl(songId: string, platform: string, rawFields?: Record<string, Object>): Promise<PlayUrlResult> {
    const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
    try {
      return await apis(platformToId(platform)).getPlayUrl(songId, rawFields || {})
    } catch (e) {
      Logger.error(TAG, `getPlayUrl err: ${JSON.stringify(e)}`)
      return empty
    }
  }

  // ===== 歌词 =====
  public static async getLyrics(songId: string, platform: string, songName?: string): Promise<string> {
    try {
      return await apis(platformToId(platform)).getLyrics(songId, songName)
    } catch (e) {
      Logger.error(TAG, `getLyrics err: ${JSON.stringify(e)}`)
      return ''
    }
  }

  // ===== 封面 =====
  public static async getPic(songInfo: Record<string, Object>, platform: string): Promise<string> {
    try {
      return await apis(platformToId(platform)).getPic(songInfo)
    } catch (e) {
      Logger.error(TAG, `getPic err: ${JSON.stringify(e)}`)
      return ''
    }
  }

  // ===== 详情页URL =====
  public static getMusicDetailPageUrl(songInfo: Record<string, Object>, platform: string): string {
    try {
      return apis(platformToId(platform)).getMusicDetailPageUrl(songInfo)
    } catch (e) {
      Logger.error(TAG, `getMusicDetailPageUrl err: ${JSON.stringify(e)}`)
      return ''
    }
  }

  // ===== 歌单列表 =====
  public static async getPlaylists(platform: string, cat: string = '全部', page: number = 0, limit: number = 30, order?: string): Promise<MusichallPlaylistPage> {
    const mapped = platformToId(platform)
    Logger.info(TAG, `getPlaylists enter | platform=${platform} | mapped=${mapped} | cat=${cat} | page=${page} | limit=${limit} | order=${order ?? ''}`)
    try {
      const result = await apis(mapped).getPlaylists(cat, page, limit, order)
      Logger.info(TAG, `getPlaylists result | platform=${platform} | count=${result?.items?.length ?? 0} | hasMore=${result?.hasMore ?? false}`)
      return result
    } catch (e) {
      Logger.error(TAG, `getPlaylists err: ${JSON.stringify(e)}`)
      return new MusichallPlaylistPage()
    }
  }

  // ===== 歌单分类标签 =====
  public static async getPlaylistTags(platform: string): Promise<TagFilterGroup[]> {
    const mapped = platformToId(platform)
    Logger.info(TAG, `getPlaylistTags enter | platform=${platform} | mapped=${mapped}`)
    try {
      const result = await apis(mapped).getPlaylistTags()
      Logger.info(TAG, `getPlaylistTags result | platform=${platform} | count=${result?.length ?? 0}`)
      return result
    } catch (e) {
      Logger.error(TAG, `getPlaylistTags err: ${JSON.stringify(e)}`)
      return []
    }
  }

  // ===== 歌单内歌曲 =====
  public static async getPlaylistSongs(platform: string, playlistId: string, page: number = 1, limit: number = 30): Promise<PlaylistDetailResult> {
    try {
      return await apis(platformToId(platform)).getPlaylistSongs(playlistId, page, limit)
    } catch (e) {
      Logger.error(TAG, `getPlaylistSongs err: ${JSON.stringify(e)}`)
      const msg = e instanceof Error ? e.message : JSON.stringify(e)
      throw new Error(`歌单加载失败: ${msg}`)
    }
  }

  // ===== 排行榜列表 =====
  public static getBoards(platform: string): BoardListResult {
    try {
      return apis(platformToId(platform)).getBoards()
    } catch (e) {
      Logger.error(TAG, `getBoards err: ${JSON.stringify(e)}`)
      return { list: [], source: platformToId(platform) }
    }
  }

  // ===== 排行榜歌曲 =====
  public static async getLeaderboardList(platform: string, bangid: string, page: number = 1, limit: number = 100): Promise<SearchResult> {
    try {
      return await apis(platformToId(platform)).getLeaderboardList(bangid, page, limit)
    } catch (e) {
      Logger.error(TAG, `getLeaderboardList err: ${JSON.stringify(e)}`)
      return emptyResult(platformToId(platform), limit)
    }
  }

  // ===== 排行榜详情页URL =====
  public static getLeaderboardDetailPageUrl(platform: string, id: string): string {
    try {
      return apis(platformToId(platform)).getLeaderboardDetailPageUrl(id)
    } catch (e) {
      Logger.error(TAG, `getLeaderboardDetailPageUrl err: ${JSON.stringify(e)}`)
      return ''
    }
  }

  // ===== 评论 =====
  public static async getComment(platform: string, songmid: string, page: number = 1, limit: number = 20): Promise<CommentResult> {
    const empty: CommentResult = { source: platformToId(platform), comments: [], total: 0, page, limit, maxPage: 1 }
    try {
      return await apis(platformToId(platform)).getComment(songmid, page, limit)
    } catch (e) {
      Logger.error(TAG, `getComment err: ${JSON.stringify(e)}`)
      return empty
    }
  }
}
