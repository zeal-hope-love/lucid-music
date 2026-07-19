/*
 * kw/tipSearch.ets - 酷我音乐智能提示
 * 对齐 lx-music-mobile kw/tipSearch.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SuggestionItem, SuggestionType } from 'musicbasic'

const TAG = 'KwMusicApi'

// 原联想接口（tips.kuwo.cn）
export async function suggest(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const url = `https://tips.kuwo.cn/t.s?corp=kuwo&newver=3&p2p=1&notrace=0&c=mbox&w=${encodeURIComponent(keyword)}&encoding=utf8&rformat=json`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'Referer': 'http://www.kuwo.cn/' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const wordItems = body['WORDITEMS'] as Record<string, Object>[]
    if (!wordItems) { return [] }
    return wordItems.map(w => new SuggestionItem(w['RELWORD'] as string || '', SuggestionType.SONG, keyword)).slice(0, 10)
  } catch (e) {
    Logger.error(TAG, `kw suggest error: ${JSON.stringify(e)}`)
    return []
  }
}

// 智能提示（与 suggest 同源）
export async function getTipSearch(keyword: string): Promise<Array<SuggestionItem>> {
  return suggest(keyword)
}
