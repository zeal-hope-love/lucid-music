/*
 * tx/lyric.ets - QQ音乐歌词
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'
import { decodeBase64Lyric } from './utils/crypto'

const TAG = 'TxMusicApi'

export async function getLyrics(songmid: string): Promise<string> {
  try {
    const url = `https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=${songmid}&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq`
    const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'https://y.qq.com/portal/player.html' }, connectTimeout: 6000, readTimeout: 6000 })
    if (resp.responseCode !== 200 || !resp.result) { return '' }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 0 || !body['lyric']) { return '' }
    return decodeBase64Lyric(body['lyric'] as string)
  } catch (_) { return '' }
}
