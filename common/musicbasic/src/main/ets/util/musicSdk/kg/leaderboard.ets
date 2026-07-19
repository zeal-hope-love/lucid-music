/*
 * kg/leaderboard.ets - 酷狗音乐排行榜
 * 对齐 lx-music-mobile kg/leaderboard.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, BoardListResult, QualityType, QualitySizeType, BoardItem } from '../types'

const TAG = 'KgMusicApi'

// 精选榜单（对齐 lx boardList）
const boardList: Array<BoardItem> = [
  { id: 'kgtop500', name: 'TOP500', bangid: '8888' },
  { id: 'kgbsb', name: '飙升榜', bangid: '6666' },
  { id: 'kgwlhgb', name: '网络榜', bangid: '23784' },
  { id: 'kgfxb', name: '分享榜', bangid: '21101' },
  { id: 'kggfjqb', name: '古风榜', bangid: '33161' },
  { id: 'kgyyjqb', name: '粤语榜', bangid: '33165' },
  { id: 'kgomjqb', name: '欧美榜', bangid: '33166' },
  { id: 'kgdyrgb', name: '电音榜', bangid: '33160' },
  { id: 'kgjdrgb', name: 'DJ热歌榜', bangid: '24971' },
  { id: 'kghyxgb', name: '华语新歌榜', bangid: '31308' }
]

export function getBoards(): BoardListResult {
  return { list: boardList, source: 'kg' }
}

export async function getList(bangid: string, page: number = 1, limit: number = 100): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'kg' }
  try {
    const url = `http://mobilecdnbj.kugou.com/api/v3/rank/song?version=9108&ranktype=1&plat=0&pagesize=${limit}&area_code=1&page=${page}&rankid=${bangid}&with_res_tag=0&show_portrait_mv=1`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['errcode'] != 0) { Logger.warn(TAG, `kg leaderboard err: ${body['errcode']}`); return empty }
    const data = body['data'] as Record<string, Object>
    const total = (data['total'] as number) || 0
    const list = filterData((data['info'] as Record<string, Object>[]) || [])
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kg' }
  } catch (e) {
    Logger.error(TAG, `kg leaderboard getList err: ${JSON.stringify(e)}`)
    return empty
  }
}

function filterData(rawList: Record<string, Object>[]): Array<SearchResultItem> {
  return rawList.map((item: Record<string, Object>) => {
    const result = new SearchResultItem()
    result.title = (item['songname'] as string) || ''
    const authors = item['authors'] as Record<string, Object>[] | undefined
    result.singer = authors ? authors.map(s => s['author_name'] as string).join('、') : ''
    result.album = (item['remark'] as string) || ''
    result.songId = (item['hash'] as string) || ''
    result.source = 'kg'
    result.duration = formatDuration((item['duration'] as number) || 0)
    result.coverUrl = ''
    result.cover = ''
    const types: Array<QualityType> = []
    const _types: Record<string, QualitySizeType> = {}
    if ((item['filesize'] as number) > 0) { types.push({ type: '128k', size: '' }); _types['128k'] = { size: '', hash: item['hash'] as string } }
    if ((item['320filesize'] as number) > 0) { types.push({ type: '320k', size: '' }); _types['320k'] = { size: '', hash: item['320hash'] as string } }
    if ((item['sqfilesize'] as number) > 0) { types.push({ type: 'flac', size: '' }); _types['flac'] = { size: '', hash: item['sqhash'] as string } }
    if ((item['filesize_high'] as number) > 0) { types.push({ type: 'flac24bit', size: '' }); _types['flac24bit'] = { size: '', hash: item['hash_high'] as string } }
    result.types = types
    result._types = _types
    result.rawFields = item
    return result
  })
}

export function getDetailPageUrl(id: string): string {
  if (typeof id == 'string') { id = id.replace('kg__', '') }
  return `https://www.kugou.com/yy/rank/home/1-${id}.html`
}
