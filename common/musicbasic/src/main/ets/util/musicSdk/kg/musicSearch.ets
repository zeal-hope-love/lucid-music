/*
 * kg/musicSearch.ets - 酷狗音乐搜索
 * 对齐 lx-music-mobile kg/musicSearch.js，返回 SearchResult 包装。
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType } from '../types'

const TAG = 'KgMusicApi'

export async function search(keyword: string, page: number, limit: number): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'kg' }
  try {
    const url = `https://songsearch.kugou.com/song_search_v2?keyword=${encodeURIComponent(keyword)}&page=${page}&pagesize=${limit}&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0&area_code=1`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `kg search http err: ${resp.responseCode}`); return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (!body || body['error_code'] !== 0 || !body['data']) { Logger.warn(TAG, `kg search body err: code=${body?.['error_code']}`); return empty }
    const data = body['data'] as Record<string, Object>
    const list = mapList((data['lists'] as Array<Record<string, Object>>) || [])
    const total = (data['total'] as number) || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kg' }
  } catch (e) {
    Logger.error(TAG, `kg search error: ${JSON.stringify(e)}`)
    return empty
  }
}

function mapList(rawList: Array<Record<string, Object>>): SearchResultItem[] {
  const results: SearchResultItem[] = []
  const seen = new Set<string>()
  if (!Array.isArray(rawList)) { return results }
  for (const item of rawList as Record<string, Object>[]) {
    const base = buildOne(item, seen, results)
    // 展开 Grp 子项（不同音质候选）
    const grp = item['Grp'] as Record<string, Object>[] | undefined
    if (grp && Array.isArray(grp)) {
      for (const child of grp) { buildOne(child, seen, results) }
    }
    void base
  }
  return results
}

function buildOne(item: Record<string, Object>, seen: Set<string>, results: SearchResultItem[]): boolean {
  const key = `${(item['Audioid'] as string) || ''}${(item['FileHash'] as string) || ''}`
  if (seen.has(key)) { return false }
  seen.add(key)
  const result = new SearchResultItem()
  result.title = (item['SongName'] as string) || ''
  const singers = item['Singers'] as Record<string, Object>[] | undefined
  result.singer = singers ? singers.map(s => s['name'] as string || '').join('/') : ''
  result.album = (item['AlbumName'] as string) || ''
  result.songId = (item['FileHash'] as string) || ''
  result.source = 'kg'
  result.duration = formatDuration((item['Duration'] as number) || 0)
  const albumId: string = (item['AlbumID'] as string) || ''
  const kgHash: string = (item['FileHash'] as string) || ''
  result.coverUrl = albumId ? `https://imge.kugou.com/stdmusic/240/${albumId}.png` : kgHash ? `https://imge.kugou.com/stdmusic/240/${kgHash}.png` : ''
  result.cover = result.coverUrl
  const resHash: string = (item['ResFileHash'] as string) || ''
  const sqHash: string = (item['SQFileHash'] as string) || ''
  const hqHash: string = (item['HQFileHash'] as string) || ''
  result.quality = resHash ? '24bit' : sqHash ? 'SQ' : hqHash ? 'HQ' : '标准'
  // 多音质候选（对齐 lx types/_types）
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
  if ((item['FileSize'] as number) > 0) { types.push({ type: '128k', size: '' }); _types['128k'] = { size: '' } }
  if ((item['HQFileSize'] as number) > 0) { types.push({ type: '320k', size: '' }); _types['320k'] = { size: '' } }
  if ((item['SQFileSize'] as number) > 0) { types.push({ type: 'flac', size: '' }); _types['flac'] = { size: '' } }
  if ((item['ResFileSize'] as number) > 0) { types.push({ type: 'flac24bit', size: '' }); _types['flac24bit'] = { size: '' } }
  result.types = types
  result._types = _types
  result.rawFields = item
  results.push(result)
  return true
}
