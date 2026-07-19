/*
 * wy/leaderboard.ets - 网易云排行榜
 * 对齐 lx-music-mobile wy/leaderboard.js
 */
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import { weapiRequest } from './utils/request'
import type { SearchResult, BoardListResult, BoardItem } from '../types'

const TAG = 'WyMusicApi'

// 热门榜单（对齐 lx topList 精选）
const topList: Array<BoardItem> = [
  { id: 'wybsb', name: '飙升榜', bangid: '19723756' },
  { id: 'wyrgb', name: '热歌榜', bangid: '3778678' },
  { id: 'wyxgb', name: '新歌榜', bangid: '3779629' },
  { id: 'wyycb', name: '原创榜', bangid: '2884035' },
  { id: 'wygdb', name: '古典榜', bangid: '71384707' },
  { id: 'wydouyb', name: '抖音榜', bangid: '2250011882' },
  { id: 'wyhyb', name: '韩语榜', bangid: '745956260' },
  { id: 'wydianyb', name: '电音榜', bangid: '1978921795' },
  { id: 'wydjb', name: '电竞榜', bangid: '2006508653' },
  { id: 'wyktvbb', name: 'KTV唛榜', bangid: '21845217' },
]

export function getBoards(): BoardListResult {
  return { list: topList, source: 'wy' }
}

export async function getList(bangid: string, page: number = 1, limit: number = 1000): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'wy' }
  try {
    const body = await weapiRequest('v3/playlist/detail', { id: bangid, n: limit, s: 8 })
    if (!body || body['code'] !== 200 || !body['playlist']) { return empty }
    const playlist = body['playlist'] as Record<string, Object>
    const tracks = (playlist['tracks'] as Record<string, Object>[]) || []
    const list: Array<SearchResultItem> = tracks.map((item: Record<string, Object>) => {
      const r = new SearchResultItem()
      r.title = (item['name'] as string) || ''
      const ar = item['ar'] as Record<string, Object>[]
      r.singer = ar ? ar.map(a => a['name'] as string).join('、') : ''
      const al = item['al'] as Record<string, Object>
      r.album = al ? (al['name'] as string) || '' : ''
      r.songId = String((item['id'] as number) || 0)
      r.source = 'wy'
      r.duration = formatDuration(Math.floor(((item['dt'] as number) || 0) / 1000))
      const picUrl = al ? (al['picUrl'] as string) || '' : ''
      r.coverUrl = picUrl.replace('http://', 'https://')
      r.cover = r.coverUrl
      r.rawFields = item
      return r
    })
    const total = (playlist['trackCount'] as number) || list.length
    Logger.info(TAG, `wy leaderboard getList: bangid=${bangid}, count=${list.length}`)
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'wy' }
  } catch (e) {
    Logger.error(TAG, `wy leaderboard getList err: ${JSON.stringify(e)}`)
    return empty
  }
}

export function getDetailPageUrl(id: string): string {
  if (id.startsWith('wy__')) id = id.replace('wy__', '')
  return `https://music.163.com/#/discover/toplist?id=${id}`
}
