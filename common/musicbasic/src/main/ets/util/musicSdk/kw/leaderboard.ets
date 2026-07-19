/*
 * kw/leaderboard.ets - 酷我音乐排行榜
 * 对齐 lx-music-mobile kw/leaderboard.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType, BoardListResult, BoardItem } from '../types'

const TAG = 'KwMusicApi'

const boardList: Array<BoardItem> = [
  { id: 'kwbiaosb', name: '飙升榜', bangid: '93' },
  { id: 'kwregb', name: '热歌榜', bangid: '16' },
  { id: 'kwhuiyb', name: '会员榜', bangid: '145' },
  { id: 'kwdouyb', name: '抖音榜', bangid: '158' },
  { id: 'kwhuaijb', name: '怀旧榜', bangid: '26' },
  { id: 'kwhuayb', name: '华语榜', bangid: '104' },
  { id: 'kwyueyb', name: '粤语榜', bangid: '182' },
  { id: 'kwoumb', name: '欧美榜', bangid: '22' },
  { id: 'kwhanyb', name: '韩语榜', bangid: '184' },
  { id: 'kwriyb', name: '日语榜', bangid: '183' }
]

const MINFO_RE = /level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)/

export function getBoards(): BoardListResult {
  return { list: boardList, source: 'kw' }
}

export async function getList(bangid: string, page: number = 1, limit: number = 100): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'kw' }
  try {
    const url = `http://kbangserver.kuwo.cn/ksong.s?from=pc&fmt=json&pn=${page - 1}&rn=${limit}&type=bang&data=content&id=${bangid}&show_copyright_off=0&pcmp4=1&isbang=1`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'http://www.kuwo.cn/' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 200 || !body['data']) { Logger.warn(TAG, `kw leaderboard err: code=${body['code']}`); return empty }
    const data = body['data'] as Record<string, Object>
    const musiclist = (data['musiclist'] as Record<string, Object>[]) || []
    const total = (data['total'] as number) || musiclist.length
    const list = filterData(musiclist)
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kw' }
  } catch (e) {
    Logger.error(TAG, `kw leaderboard getList err: ${JSON.stringify(e)}`)
    return empty
  }
}

function filterData(rawList: Record<string, Object>[]): Array<SearchResultItem> {
  return rawList.map((item: Record<string, Object>) => {
    const result = new SearchResultItem()
    result.title = (item['name'] as string) || ''
    result.singer = (item['artist'] as string) || ''
    result.album = (item['album'] as string) || ''
    result.songId = String(item['id'] as number)
    result.source = 'kw'
    result.duration = formatDuration(parseInt((item['duration'] as string) || '0'))
    result.coverUrl = (item['pic'] as string) || ''
    if (result.coverUrl && !result.coverUrl.startsWith('http')) { result.coverUrl = `https:${result.coverUrl}` }
    result.cover = result.coverUrl
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
    const nMinfo: string = (item['n_minfo'] as string) || ''
    if (nMinfo) {
      for (const seg of nMinfo.split(';')) {
        const m = seg.match(MINFO_RE)
        if (!m) { continue }
        const bitrate = m[2]
        const size = m[4].toUpperCase()
        switch (bitrate) {
          case '4000': types.push({ type: 'flac24bit', size }); _types['flac24bit'] = { size }; break
          case '2000': types.push({ type: 'flac', size }); _types['flac'] = { size }; break
          case '320': types.push({ type: '320k', size }); _types['320k'] = { size }; break
          case '128': types.push({ type: '128k', size }); _types['128k'] = { size }; break
        }
      }
    }
    result.types = types
    result._types = _types
    result.rawFields = item
    return result
  })
}

export function getDetailPageUrl(id: string): string {
  if (typeof id == 'string') { id = id.replace('kw__', '') }
  return `http://www.kuwo.cn/rankList/${id}`
}
