/*
 * musicSdk - 音乐平台 API 统一导出
 * 参考 lx-music-mobile 的架构设计
 */
import wy from './wy/index'
import tx from './tx/index'
import kg from './kg/index'
import kw from './kw/index'
import mg from './mg/index'
import { ApiSource } from './ApiSource'
import { apis, supportQuality } from './api-source'
import type { MusicPlatform } from './types'
import { Logger } from 'musicbasic'
import type {
  SearchResultItem, SearchResult, SuggestionItem, SuggestionType,
  CommentItem, CommentResult, BoardItem, BoardListResult, MusicInfo
} from './types'

// 导出各平台 API 对象（对齐 lx 的平台聚合形态）
export { wy, tx, kg, kw, mg }

// 导出统一调度层
export { ApiSource }

// 导出音源抽象层
export { apis, supportQuality }
export type { MusicPlatform }

// 导出统一类型模型
// 注意：SearchResultItem / SuggestionItem / CommentItem 为 class，SuggestionType 为 enum，
// 需以值导出（可被 new / 枚举成员访问）；其余为 interface，以 type 导出。
export {
  SearchResultItem, SuggestionItem, CommentItem, SuggestionType
} from './types'
export type {
  SearchResult, CommentResult, BoardItem, BoardListResult
} from './types'

// 播放地址结果
export { PlayUrlResult } from './wy/utils/crypto'

// 平台信息接口
export interface SourceInfo {
  name: string
  id: string
}

// 导出平台列表
export const sources: SourceInfo[] = [
  { name: '网易云音乐', id: 'wy' },
  { name: 'QQ音乐', id: 'tx' },
  { name: '酷狗音乐', id: 'kg' },
  { name: '酷我音乐', id: 'kw' },
  { name: '咪咕音乐', id: 'mg' }
]

// ===== 顶层入口：跨平台搜索 =====
export interface SearchMusicOptions {
  name: string
  singer?: string
  source?: string[]
  limit?: number
}

/**
 * 并行搜索所有（或指定）平台，返回 { 平台id: SearchResult }
 * 单平台失败不影响其它平台（.catch 隔离）。
 */
export async function searchMusic(options: SearchMusicOptions): Promise<Record<string, SearchResult>> {
  const targetSources: string[] = (options.source && options.source.length > 0)
    ? options.source
    : sources.map(s => s.id)
  const limit: number = options.limit || 30
  const results = await Promise.all(targetSources.map(async (src): Promise<[string, SearchResult]> => {
    try {
      const r: SearchResult = await apis(src).search(options.name, 1, limit)
      return [src, r]
    } catch (e) {
      Logger.error('musicSdk', `searchMusic ${src} failed: ${JSON.stringify(e)}`)
      return [src, { list: [], allPage: 1, limit, total: 0, source: src }]
    }
  }))
  const map: Record<string, SearchResult> = {}
  for (let i = 0; i < results.length; i++) {
    const src: string = results[i][0]
    const r: SearchResult = results[i][1]
    map[src] = r
  }
  return map
}

/**
 * 模糊匹配挑选最佳结果（对齐 lx findMusic 的 filterStr/getIntv 思路）
 * 给定 source + songId 时直接在该平台内挑选；否则跨平台合并后挑选最高分。
 */
export async function findMusic(musicInfo: MusicInfo): Promise<SearchResultItem | null> {
  const name: string = musicInfo.name
  const singer: string = musicInfo.singer || ''
  if (musicInfo.source && musicInfo.songId) {
    try {
      const r: SearchResult = await apis(musicInfo.source).search(name, 1, 30)
      return pickBest(r.list, name, singer)
    } catch (e) {
      Logger.error('musicSdk', `findMusic ${musicInfo.source} failed: ${JSON.stringify(e)}`)
      return null
    }
  }
  const all: Record<string, SearchResult> = await searchMusic({ name, singer, limit: 30 })
  let best: SearchResultItem | null = null
  let bestScore: number = -1
  for (const src of Object.keys(all)) {
    for (const item of all[src].list) {
      const score: number = matchScore(item, name, singer)
      if (score > bestScore) { bestScore = score; best = item }
    }
  }
  return best
}

function filterStr(str: string): string {
  return (str || '').toLowerCase().replace(/[\s\-_()（）【】\[\]、，,。.!！?？]/g, '')
}

function matchScore(item: SearchResultItem, name: string, singer: string): number {
  const tName: string = filterStr(item.title)
  const qName: string = filterStr(name)
  let score: number = 0
  if (tName === qName) { score += 100 }
  else if (tName.includes(qName) || qName.includes(tName)) { score += 60 }
  else { score += 20 }
  if (singer) {
    const tSinger: string = filterStr(item.singer)
    const qSinger: string = filterStr(singer)
    if (tSinger.includes(qSinger) || qSinger.includes(tSinger)) { score += 30 }
  }
  return score
}

function pickBest(list: SearchResultItem[], name: string, singer: string): SearchResultItem | null {
  let best: SearchResultItem | null = null
  let bestScore: number = -1
  for (const item of list) {
    const score: number = matchScore(item, name, singer)
    if (score > bestScore) { bestScore = score; best = item }
  }
  return best
}

/**
 * 初始化（预留：音源镜像、缓存预热等）
 */
export function init(): void {
  Logger.info('musicSdk', `init sources=${sources.map(s => s.id).join(',')}`)
}
