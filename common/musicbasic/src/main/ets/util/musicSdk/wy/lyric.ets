/*
 * wy/lyric.ets - 网易云歌词
 */
import { http } from '@kit.NetworkKit'
import { Logger } from 'musicbasic'

const TAG = 'WyMusicApi'

export async function getLyrics(songId: string): Promise<string> {
  try {
    const resp = await http.createHttp().request(
      `https://music.163.com/api/song/lyric?id=${songId}&lv=1&kv=1&tv=-1`,
      { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' }, connectTimeout: 6000, readTimeout: 6000 }
    )
    if (resp.responseCode !== 200) { return '' }
    const body = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 200) { return '' }
    const lrc = body['lrc'] as Record<string, Object>
    return lrc ? (lrc['lyric'] as string) || '' : ''
  } catch (_) { return '' }
}
