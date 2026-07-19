/*
 * types.ets - musicSdk 统一数据模型
 * 对齐 lx-music-mobile 的 SearchResultItem / SearchResult 结构，
 * 新增 types/_types/typeUrl 多音质候选字段。
 * 注意：本文件为纯数据模型，不依赖 musicbasic，避免循环引用。
 */

// MusicPlatform 引用的外部类型（从源文件导入，避免经 musicbasic barrel 形成循环依赖）
import type { PlayUrlResult } from './wy/utils/crypto'
import type { MusichallPlaylistItem, TagFilterGroup } from '../../data/MusichallPlaylistItem'

// ===== 共享音质类型 =====
export interface QualityType {
  type: string
  size: string
}
export interface QualitySizeType {
  size: string
  hash?: string
}

// buildQualityTypes 的返回结构（消除对象字面量当类型）
export interface QualityBuildResult {
  types: Array<QualityType>
  _types: Record<string, QualitySizeType>
}

// 评论游标缓存项
export interface CursorCacheItem {
  cursor: number
  prevCursor: number
  orderType: number
  offset: number
  page: number
}

// getCursor 返回结构
export interface CursorInfo {
  orderType: number
  cursor: number
  offset: number
}

// 签名结果（mg 平台）
export interface SignatureResult {
  sign: string
  deviceId: string
}

// findMusic 入参
export interface MusicInfo {
  name: string
  singer?: string
  source?: string
  songId?: string
}

// ===== 搜索结果项 =====
@ObservedV2
export class SearchResultItem {
  // 核心展示字段
  @Trace title: string = ''
  @Trace singer: string = ''
  @Trace album: string = ''
  @Trace quality: string = ''
  @Trace duration: string = ''
  @Trace cover: string = ''
  @Trace coverUrl: string = ''
  @Trace source: string = ''
  @Trace songId: string = ''

  // 兼容旧字段
  @Trace id: number = 0
  @Trace url: string = ''
  @Trace name: string = ''
  @Trace artist: string = ''

  // 原始 API 返回数据（用于后续播放/取歌单内歌曲等操作）
  public rawFields: Record<string, Object> = {}

  // ===== 对齐 lx-music-mobile 多音质候选 =====
  // types: 展示用音质列表，如 [{ type: '320k', size: '10.2MB' }]
  types: Array<QualityType> = []
  // _types: 按音质 key 索引的明细
  _types: Record<string, QualitySizeType> = {}
  // typeUrl: 各音质对应的播放地址（取 URL 时填充）
  typeUrl: Record<string, string> = {}
}

// ===== 搜索返回包装（对齐 lx 的 { list, allPage, limit, total, source }） =====
export interface SearchResult {
  list: SearchResultItem[]
  allPage: number
  limit: number
  total: number
  source: string
}

// ===== 搜索建议类型 =====
export enum SuggestionType {
  SONG = 'song',
  ARTIST = 'artist',
  ALBUM = 'album'
}

export class SuggestionItem {
  text: string = ''
  type: SuggestionType = SuggestionType.SONG
  highlightText: string = ''

  constructor(text: string, type: SuggestionType = SuggestionType.SONG, highlightText: string = '') {
    this.text = text
    this.type = type
    this.highlightText = highlightText
  }
}

// ===== 评论项（对齐 lx comment.js 返回结构） =====
@ObservedV2
export class CommentItem {
  @Trace id: string = ''
  @Trace text: string = ''
  @Trace userName: string = ''
  @Trace avatar: string = ''
  @Trace likedCount: number = 0
  @Trace time: number = 0
  @Trace timeStr: string = ''
  @Trace location: string = ''

  public userId: string = ''
  public images: Array<string> = []
  public reply: Array<CommentItem> = []
}

// ===== 评论返回包装 =====
export interface CommentResult {
  source: string
  comments: Array<CommentItem>
  total: number
  page: number
  limit: number
  maxPage: number
}

// ===== 排行榜榜单项 =====
export interface BoardItem {
  id: string
  name: string
  bangid: string
}

// ===== 排行榜列表包装 =====
export interface BoardListResult {
  list: Array<BoardItem>
  source: string
}

// ===== 平台对象统一接口（各平台方法形态一致，参数以最宽签名约束） =====
// 置于文件末尾：其引用的 SearchResult / SuggestionItem / CommentResult / BoardListResult
// 等均已在上方声明，满足 ArkTS 声明前置要求。
// 注意：ArkTS 严格模式下，对象字面量只能对应「数据字段」的 class/interface；
// MusicPlatform 全为方法签名，故定义为 class（方法字段用 ! 明确赋值），
// 各平台用对象字面量直接构造（ArkTS 允许对象字面量赋值给含公开方法字段的 class）。
export class MusicPlatform {
  search!: (keyword: string, page: number, limit: number) => Promise<SearchResult>
  suggest!: (keyword: string) => Promise<Array<SuggestionItem>>
  getTipSearch!: (keyword: string) => Promise<Array<SuggestionItem>>
  hotSearch!: () => Promise<string[]>
  getLyrics!: (songId: string, songName?: string) => Promise<string>
  getPlayUrl!: (songId: string, rawFields: Record<string, Object>) => Promise<PlayUrlResult>
  getPic!: (songInfo: Record<string, Object>) => Promise<string>
  getMusicDetailPageUrl!: (songInfo: Record<string, Object>) => string
  getPlaylists!: (cat: string, page: number, limit: number) => Promise<Array<MusichallPlaylistItem>>
  getPlaylistTags!: () => Promise<Array<TagFilterGroup>>
  getPlaylistSongs!: (playlistId: string, page: number, limit: number) => Promise<SearchResult>
  getBoards!: () => BoardListResult
  getLeaderboardList!: (bangid: string, page: number, limit: number) => Promise<SearchResult>
  getLeaderboardDetailPageUrl!: (id: string) => string
  getComment!: (songmid: string, page: number, limit: number) => Promise<CommentResult>
}
