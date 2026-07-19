/*
 * mg/musicSearch.ets - 咪咕音乐搜索
 * 对齐 lx-music-mobile mg/musicSearch.js，返回 SearchResult 包装。
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { mapMgSong } from './songMap'
import type { SearchResult } from '../types'

const TAG = 'MgMusicApi'

const SEARCH_SWITCH = '%7B%22song%22%3A1%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A0%2C%22mvSong%22%3A0%2C%22bestShow%22%3A0%7D'

export async function search(keyword: string, page: number, limit: number): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'mg' }
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/search_all.do?isCopyright=1&isCorrect=1&pageNo=${page}&pageSize=${limit}&searchSwitch=${SEARCH_SWITCH}&sort=0&text=${encodeURIComponent(keyword)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `mg search http err: ${resp.responseCode}`); return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    let resultList: Array<Record<string, Object>> = []
    if (body['resultList']) { resultList = body['resultList'] as Array<Record<string, Object>> }
    else if (body['songResultData']) { resultList = ((body['songResultData'] as Record<string, Object>)['resultList'] as Array<Record<string, Object>>) || [] }
    const list = mapList(resultList)
    const total = (body['totalCount'] as number) || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'mg' }
  } catch (e) {
    Logger.error(TAG, `mg search error: ${JSON.stringify(e)}`)
    return empty
  }
}

function mapList(rawList: Array<Record<string, Object>>): SearchResultItem[] {
  const results: SearchResultItem[] = []
  const seen = new Set<string>()
  if (!Array.isArray(rawList)) { return results }
  for (const item of rawList) {
    if (Array.isArray(item)) {
      for (const inner of item as Array<Record<string, Object>>) { mapOne(inner as Record<string, Object>, seen, results) }
    } else {
      mapOne(item as Record<string, Object>, seen, results)
    }
  }
  return results
}

function mapOne(data: Record<string, Object>, seen: Set<string>, results: SearchResultItem[]): void {
  const dedupKey: string = (data['copyrightId'] as string) || (data['id'] as string) || ''
  if (!dedupKey || seen.has(dedupKey)) { return }
  seen.add(dedupKey)
  results.push(mapMgSong(data))
}
