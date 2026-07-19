/*
 * kw/hotSearch.ets - 酷我音乐热搜
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'

const TAG = 'KwMusicApi'

export async function hotSearch(): Promise<string[]> {
  try {
    const url = 'http://hotword.kuwo.cn/hotword.s?prod=kwplayer_ar_9.3.0.1&corp=kuwo&newver=2&vipver=9.3.0.1&source=kwplayer_ar_9.3.0.1_40.apk&p2p=1&notrace=0&uid=0&plat=kwplayer_ar&rformat=json&encoding=utf8&tabid=1'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['status'] !== 'ok' || !body['tagvalue']) { return [] }
    return ((body['tagvalue'] as Record<string, Object>[]) || []).map(i => i['key'] as string).filter(Boolean)
  } catch (e) {
    Logger.error(TAG, `kw hotSearch error: ${JSON.stringify(e)}`)
    return []
  }
}
