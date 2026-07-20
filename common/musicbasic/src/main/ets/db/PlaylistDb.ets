/*
 * Lucid Music - 歌单 / 最近播放 / 收藏 持久化层
 * Preferences 单例，JSON 序列化存储 + 内存缓存
 * - 自建歌单（playlistType === 0）
 * - 收藏歌单（playlistType === 1，远程歌单）
 * - 最近播放（SongItem[]）
 * - 收藏歌曲（SongItem[]）
 */
import { preferences } from '@kit.ArkData'
import { PlaylistRow } from '../data/PlaylistRow'
import { SongItem } from '../model/SongData'

const STORE_NAME = 'playlist_store'
const KEY_OWN = 'own_playlists_json'
const KEY_COLLECTED = 'collected_playlists_json'
const KEY_RECENT = 'recent_play_json'
const KEY_FAVORITE = 'favorite_json'

export class PlaylistDb {
  private static instance: PlaylistDb | null = null
  private prefs: preferences.Preferences | null = null
  private ownCache: PlaylistRow[] | null = null
  private collectedCache: PlaylistRow[] | null = null
  private recentCache: SongItem[] | null = null
  private favoriteCache: SongItem[] | null = null

  static getInstance(): PlaylistDb {
    if (PlaylistDb.instance === null) {
      PlaylistDb.instance = new PlaylistDb()
    }
    return PlaylistDb.instance
  }

  /** 初始化，需要 UIAbilityContext */
  async init(context: Context): Promise<void> {
    this.prefs = await preferences.getPreferences(context, STORE_NAME)
  }

  // ==================== 自建歌单 (type 0) ====================

  /** 获取全部自建歌单，优先返回内存缓存 */
  async getAllOwn(): Promise<PlaylistRow[]> {
    if (this.ownCache !== null) {
      return this.ownCache
    }
    const rawArr = await this.readRows(KEY_OWN)
    this.ownCache = rawArr.map((r) => this.deserializePlaylist(r))
    return this.ownCache
  }

  /** 保存全部自建歌单，更新内存缓存并刷盘 */
  async saveAllOwn(rows: PlaylistRow[]): Promise<void> {
    this.ownCache = rows
    await this.writeRows(KEY_OWN, rows.map((r) => this.serializePlaylist(r)))
  }

  // ==================== 收藏歌单 (type 1) ====================

  /** 获取全部收藏歌单（远程歌单），优先返回内存缓存 */
  async getAllCollected(): Promise<PlaylistRow[]> {
    if (this.collectedCache !== null) {
      return this.collectedCache
    }
    const rawArr = await this.readRows(KEY_COLLECTED)
    this.collectedCache = rawArr.map((r) => this.deserializePlaylist(r))
    return this.collectedCache
  }

  /** 保存全部收藏歌单，更新内存缓存并刷盘 */
  async saveAllCollected(rows: PlaylistRow[]): Promise<void> {
    this.collectedCache = rows
    await this.writeRows(KEY_COLLECTED, rows.map((r) => this.serializePlaylist(r)))
  }

  // ==================== 最近播放 ====================

  /** 获取最近播放列表，优先返回内存缓存 */
  async getRecent(): Promise<SongItem[]> {
    if (this.recentCache !== null) {
      return this.recentCache
    }
    const rawArr = await this.readRows(KEY_RECENT)
    this.recentCache = rawArr.map((r) => this.deserializeSong(r))
    return this.recentCache
  }

  /** 保存最近播放列表，更新内存缓存并刷盘 */
  async saveRecent(items: SongItem[]): Promise<void> {
    this.recentCache = items
    await this.writeRows(KEY_RECENT, items.map((s) => this.serializeSong(s)))
  }

  // ==================== 收藏歌曲 ====================

  /** 获取收藏歌曲列表，优先返回内存缓存 */
  async getFavorites(): Promise<SongItem[]> {
    if (this.favoriteCache !== null) {
      return this.favoriteCache
    }
    const rawArr = await this.readRows(KEY_FAVORITE)
    this.favoriteCache = rawArr.map((r) => this.deserializeSong(r))
    return this.favoriteCache
  }

  /** 保存收藏歌曲列表，更新内存缓存并刷盘 */
  async saveFavorites(items: SongItem[]): Promise<void> {
    this.favoriteCache = items
    await this.writeRows(KEY_FAVORITE, items.map((s) => this.serializeSong(s)))
  }

  /** 清空缓存（供外部强制刷新） */
  clearCache(): void {
    this.ownCache = null
    this.collectedCache = null
    this.recentCache = null
    this.favoriteCache = null
  }

  // ==================== 底层读写 ====================

  private async readRows(key: string): Promise<Record<string, Object>[]> {
    if (this.prefs === null) {
      return []
    }
    const jsonStr: string = await this.prefs.get(key, '[]') as string
    const parsed: object[] = JSON.parse(jsonStr) as object[]
    return parsed as Record<string, Object>[]
  }

  private async writeRows(key: string, rows: Record<string, Object>[]): Promise<void> {
    if (this.prefs === null) {
      return
    }
    const jsonStr: string = JSON.stringify(rows)
    await this.prefs.put(key, jsonStr)
    await this.prefs.flush()
  }

  // ==================== 序列化 ====================

  private serializePlaylist(row: PlaylistRow): Record<string, Object> {
    const r: Record<string, Object> = {}
    r['playlistId'] = row.playlistId
    r['title'] = (typeof row.title === 'string') ? row.title : ''
    r['songIds'] = row.songIds
    r['playlistType'] = row.playlistType
    // 远程歌单扩展字段（type === 1）
    r['source'] = row.source
    r['sourceListId'] = row.sourceListId
    r['coverUrl'] = row.coverUrl
    r['author'] = row.author
    return r
  }

  private deserializePlaylist(raw: Record<string, Object>): PlaylistRow {
    const row = new PlaylistRow()
    row.playlistId = (raw['playlistId'] as number) || 0
    row.title = (raw['title'] as string) || ''
    const rawIds = raw['songIds'] as number[]
    row.songIds = Array.isArray(rawIds) ? rawIds : []
    row.playlistType = (raw['playlistType'] as number) || 0
    row.source = (raw['source'] as string) || ''
    row.sourceListId = (raw['sourceListId'] as string) || ''
    row.coverUrl = (raw['coverUrl'] as string) || ''
    row.author = (raw['author'] as string) || ''
    return row
  }

  /**
   * 序列化 SongItem。仅保留可 JSON 序列化的基础字段；
   * mark/label 为 Resource 类型，无法序列化，载入时回退为默认 Resource。
   */
  private serializeSong(s: SongItem): Record<string, Object> {
    const r: Record<string, Object> = {}
    r['id'] = s.id
    r['title'] = (typeof s.title === 'string') ? s.title : ''
    r['singer'] = (typeof s.singer === 'string') ? s.singer : ''
    r['coverUrl'] = s.coverUrl
    r['src'] = s.src
    r['index'] = s.index
    r['lyric'] = s.lyric
    r['lyricText'] = s.lyricText
    r['platform'] = s.platform
    r['remoteSongId'] = s.remoteSongId
    return r
  }

  private deserializeSong(raw: Record<string, Object>): SongItem {
    const s = new SongItem()
    s.id = (raw['id'] as number) || 0
    s.title = (raw['title'] as string) || ''
    s.singer = (raw['singer'] as string) || ''
    s.coverUrl = (raw['coverUrl'] as string) || ''
    s.src = (raw['src'] as string) || ''
    s.index = (raw['index'] as number) || 0
    s.lyric = (raw['lyric'] as string) || ''
    s.lyricText = (raw['lyricText'] as string) || ''
    s.platform = (raw['platform'] as string) || ''
    s.remoteSongId = (raw['remoteSongId'] as string) || ''
    s.mark = $r('app.string.page_show')
    s.label = $r('app.string.page_show')
    return s
  }
}
