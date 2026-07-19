/*
 * kw/musicSearch.ets - 酷我音乐搜索
 * 对齐 lx-music-mobile kw/musicSearch.js，返回 SearchResult 包装。
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType } from '../types'

const TAG = 'KwMusicApi'

const MINFO_RE = /level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)/

export async function search(keyword: string, page: number, limit: number): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'kw' }
  try {
    const url = `http://search.kuwo.cn/r.s?client=kt&all=${encodeURIComponent(keyword)}&pn=${page - 1}&rn=${limit}&uid=794762570&ver=kwplayer_ar_9.2.2.1&vipver=1&show_copyright_off=1&newver=1&ft=music&cluster=0&strategy=2012&encoding=utf8&rformat=json&vermerge=1&mobi=1&issubtitle=1`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)', 'Referer': 'http://www.kuwo.cn/' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `kw search http err: ${resp.responseCode}`); return empty }
    const jsonStr: string = (resp.result as string).replace(/'/g, '"')
    const body: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>
    if (!body || !body['abslist']) { Logger.warn(TAG, `kw search no abslist`); return empty }
    const list = mapList((body['abslist'] as Array<Record<string, Object>>) || [])
    const total = parseInt((body['TOTAL'] as string) || '0') || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kw' }
  } catch (e) {
    Logger.error(TAG, `kw search error: ${JSON.stringify(e)}`)
    return empty
  }
}

function mapList(rawList: Array<Record<string, Object>>): SearchResultItem[] {
  const results: SearchResultItem[] = []
  if (!Array.isArray(rawList)) { return results }
  for (const item of rawList as Record<string, Object>[]) {
    const result = new SearchResultItem()
    result.title = (item['NAME'] as string) || (item['name'] as string) || ''
    result.singer = (item['ARTIST'] as string) || (item['artist'] as string) || ''
    result.album = (item['ALBUM'] as string) || (item['album'] as string) || ''
    result.songId = (item['MUSICRID'] as string) || (item['musicrid'] as string) || ''
    result.source = 'kw'
    result.duration = formatDuration((item['DURATION'] as number) || 0)
    result.coverUrl = (item['ALBUMCOVER'] as string) || (item['WEBPICURL'] as string) || ''
    if (result.coverUrl && !result.coverUrl.startsWith('http')) { result.coverUrl = `https:${result.coverUrl}` }
    result.cover = result.coverUrl
    const kwFormats: string = (item['FORMATS'] as string) || ''
    result.quality = kwFormats.includes('FLAC') || kwFormats.includes('无损') ? 'SQ' : kwFormats.includes('MP3H') || kwFormats.includes('320') ? 'HQ' : '标准'
    // 多音质候选（对齐 lx N_MINFO 解析）
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
    const nMinfo: string = (item['N_MINFO'] as string) || ''
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
    results.push(result)
  }
  return results
}
