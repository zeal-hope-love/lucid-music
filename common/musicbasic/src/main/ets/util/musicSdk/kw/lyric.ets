/*
 * kw/lyric.ets - 酷我音乐歌词
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'

const TAG = 'KwMusicApi'

export async function getLyrics(musicId: string): Promise<string> {
  try {
    const url = `https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=${musicId}`
    const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, connectTimeout: 6000, readTimeout: 6000 })
    if (resp.responseCode !== 200) { return '' }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['status'] !== 200 || !body['data']) { return '' }
    const lrclist = (body['data'] as Record<string, Object>)['lrclist'] as Record<string, Object>[]
    if (!lrclist || lrclist.length === 0) { return '' }
    return lrclist.map(l => `[${(l['time'] as string) || ''}]${(l['lineLyric'] as string) || ''}`).join('\n')
  } catch (_) {
    return ''
  }
}
