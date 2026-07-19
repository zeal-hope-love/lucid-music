/*
 * mg/hotSearch.ets - 咪咕音乐热搜
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'

const TAG = 'MgMusicApi'

export async function hotSearch(): Promise<string[]> {
  try {
    const url = 'http://jadeite.migu.cn:7090/music_search/v3/search/hotword'
    const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, connectTimeout: 5000, readTimeout: 5000 })
    if (resp.responseCode !== 200) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (!body || body['code'] !== '000000' || !body['data']) { return [] }
    const hotwords = (body['data'] as Record<string, Object>)['hotwords'] as Record<string, Object>[]
    if (!hotwords || hotwords.length === 0) { return [] }
    const hotwordList = hotwords[0]['hotwordList'] as Record<string, Object>[]
    return hotwordList ? hotwordList.filter(h => h['resourceType'] === 'song').map(h => h['word'] as string).filter(Boolean) : []
  } catch (e) {
    Logger.error(TAG, `mg hotSearch error: ${JSON.stringify(e)}`)
    return []
  }
}
