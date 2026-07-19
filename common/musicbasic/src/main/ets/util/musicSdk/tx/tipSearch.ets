/*
 * tx/tipSearch.ets - QQ音乐智能提示 / 联想
 * 对齐 lx-music-mobile tx/tipSearch.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SuggestionItem, SuggestionType } from 'musicbasic'

const TAG = 'TxMusicApi'

// 原联想接口（smartbox_new.fcg）
export async function suggest(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const url = `https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?is_xml=0&format=json&key=${encodeURIComponent(keyword)}&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0`
    const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'https://y.qq.com/portal/player.html' }, connectTimeout: 5000, readTimeout: 5000 })
    if (resp.responseCode !== 200) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 0 || !body['data']) { return [] }
    const itemlist = ((body['data'] as Record<string, Object>)['song'] as Record<string, Object>)?.[`itemlist`] as Record<string, Object>[]
    if (!itemlist) { return [] }
    const items: Array<SuggestionItem> = []; const seen = new Set<string>()
    for (const item of itemlist) {
      const name = item['name'] as string || ''
      if (!name || seen.has(name)) { continue }
      seen.add(name)
      items.push(new SuggestionItem(name, SuggestionType.SONG, keyword))
    }
    return items.slice(0, 10)
  } catch (e) { Logger.error(TAG, `tx suggest error: ${JSON.stringify(e)}`); return [] }
}

// 智能提示（返回 "歌名 - 歌手"）
export async function getTipSearch(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const url = `https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?is_xml=0&format=json&key=${encodeURIComponent(keyword)}&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0`
    const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'https://y.qq.com/portal/player.html' }, connectTimeout: 5000, readTimeout: 5000 })
    if (resp.responseCode !== 200) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 0 || !body['data']) { return [] }
    const itemlist = ((body['data'] as Record<string, Object>)['song'] as Record<string, Object>)?.[`itemlist`] as Record<string, Object>[]
    if (!itemlist) { return [] }
    return itemlist.slice(0, 10).map((info: Record<string, Object>) => {
      const singer = (info['singer'] as string) || ''
      const name = (info['name'] as string) || ''
      return new SuggestionItem(`${name} - ${singer}`, SuggestionType.SONG, keyword)
    })
  } catch (e) { Logger.error(TAG, `tx getTipSearch error: ${JSON.stringify(e)}`); return [] }
}
