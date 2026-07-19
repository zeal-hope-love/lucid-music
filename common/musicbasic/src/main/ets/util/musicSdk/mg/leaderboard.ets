/*
 * mg/leaderboard.ets - 咪咕音乐排行榜
 * 对齐 lx-music-mobile mg/leaderboard.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { mapMgSong } from './songMap'
import type { SearchResult, BoardListResult, BoardItem } from '../types'

const TAG = 'MgMusicApi'

const boardList: Array<BoardItem> = [
  { id: 'mgyyb', name: '音乐榜', bangid: '27553319' },
  { id: 'mgysb', name: '影视榜', bangid: '23603721' },
  { id: 'mghybnd', name: '华语内地榜', bangid: '23603926' },
  { id: 'mghyjqbgt', name: '华语港台榜', bangid: '23603954' },
  { id: 'mgomb', name: '欧美榜', bangid: '23603974' },
  { id: 'mgrhb', name: '日韩榜', bangid: '23603982' },
  { id: 'mgwlb', name: '网络榜', bangid: '23604058' },
  { id: 'mgclb', name: '彩铃榜', bangid: '23604023' },
  { id: 'mgktvb', name: 'KTV榜', bangid: '23604040' },
  { id: 'mgrcb', name: '原创榜', bangid: '23604032' }
]

export function getBoards(): BoardListResult {
  return { list: boardList, source: 'mg' }
}

export async function getList(bangid: string, page: number = 1, limit: number = 200): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'mg' }
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/querycontentbyId.do?columnId=${bangid}&needAll=0`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36', 'Referer': 'https://app.c.nf.migu.cn/', 'channel': '0146921' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== '000000') { Logger.warn(TAG, `mg leaderboard err: code=${body['code']}`); return empty }
    const columnInfo = body['columnInfo'] as Record<string, Object>
    const contents = (columnInfo['contents'] as Record<string, Object>[]) || []
    const songObjs: Record<string, Object>[] = []
    for (const c of contents) {
      const obj = c['objectInfo'] as Record<string, Object>
      if (obj) { songObjs.push(obj) }
    }
    const list = songObjs.map(s => mapMgSong(s))
    const total = list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'mg' }
  } catch (e) {
    Logger.error(TAG, `mg leaderboard getList err: ${JSON.stringify(e)}`)
    return empty
  }
}

export function getDetailPageUrl(id: string): string {
  if (typeof id == 'string') { id = id.replace('mg__', '') }
  return `https://music.migu.cn/v3/music/top/${id}`
}
