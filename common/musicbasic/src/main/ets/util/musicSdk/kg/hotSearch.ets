/*
 * kg/hotSearch.ets - 酷狗音乐热搜
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'

const TAG = 'KgMusicApi'

export async function hotSearch(): Promise<string[]> {
  try {
    const url = 'http://gateway.kugou.com/api/v3/search/hot_tab?signature=ee44edb9d7155821412d220bcaf509dd&appid=1005&clientver=10026&plat=0'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: {
        'dfid': '1ssiv93oVqMp27cirf2CvoF1',
        'mid': '156798703528610303473757548878786007104',
        'clienttime': '1584257267',
        'x-router': 'msearch.kugou.com',
        'user-agent': 'Android9-AndroidPhone-10020-130-0-searchrecommendprotocol-wifi',
        'kg-rc': '1'
      },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (!body || body['errcode'] !== 0 || !body['data']) { return [] }
    const list = (body['data'] as Record<string, Object>)['list'] as Record<string, Object>[]
    if (!list || !Array.isArray(list)) { return [] }
    const kwds: string[] = []
    for (const item of list) {
      const keywords = item['keywords'] as Record<string, Object>[]
      if (keywords) { for (const k of keywords) { const kw = k['keyword'] as string; if (kw) { kwds.push(kw) } } }
    }
    return kwds
  } catch (e) {
    Logger.error(TAG, `kg hotSearch error: ${JSON.stringify(e)}`)
    return []
  }
}
