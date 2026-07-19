/*
 * kg/tipSearch.ets - 酷狗音乐智能提示
 * 对齐 lx-music-mobile kg/tipSearch.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SuggestionItem, SuggestionType } from 'musicbasic'

const TAG = 'KgMusicApi'

// 原联想接口（searchtip.kugou.com）
export async function suggest(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const url = `https://searchtip.kugou.com/getSearchTip?MusicTipCount=10&keyword=${encodeURIComponent(keyword)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'referer': 'https://www.kugou.com/' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { return [] }
    const outerArr: Array<Record<string, Object>> = JSON.parse(resp.result as string) as Array<Record<string, Object>>
    if (!outerArr || !Array.isArray(outerArr) || outerArr.length === 0) { return [] }
    const recordDatas = (outerArr[0] as Record<string, Object>)['RecordDatas'] as Record<string, Object>[]
    if (!recordDatas || !Array.isArray(recordDatas)) { return [] }
    const items: Array<SuggestionItem> = []
    const seen = new Set<string>()
    for (const rd of recordDatas) {
      const hint = rd['HintInfo'] as string
      if (!hint || seen.has(hint)) { continue }
      seen.add(hint)
      items.push(new SuggestionItem(hint, SuggestionType.SONG, keyword))
    }
    return items.slice(0, 10)
  } catch (e) {
    Logger.error(TAG, `kg suggest error: ${JSON.stringify(e)}`)
    return []
  }
}

// 智能提示（与 suggest 同源，返回完整提示文本）
export async function getTipSearch(keyword: string): Promise<Array<SuggestionItem>> {
  const items = await suggest(keyword)
  return items
}
