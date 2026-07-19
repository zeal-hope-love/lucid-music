/*
 * kg/lyric.ets - 酷狗音乐歌词
 */
import { http } from '@kit.NetworkKit'
import { buffer, util } from '@kit.ArkTS'
import { Logger } from 'musicbasic'

const TAG = 'KgMusicApi'

export async function getLyrics(hash: string, songName?: string): Promise<string> {
  try {
    const searchUrl = `http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=${encodeURIComponent(songName ?? '')}&hash=${hash}&lrctxt=1`
    const sResp = await http.createHttp().request(searchUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.kugou.com/' },
      connectTimeout: 6000, readTimeout: 6000
    })
    if (sResp.responseCode !== 200) { return '' }
    const sBody: Record<string, Object> = JSON.parse(sResp.result as string) as Record<string, Object>
    const candidates = sBody['candidates'] as Record<string, Object>[]
    if (!candidates || candidates.length === 0) { return '' }
    const c = candidates[0]
    const id = c['id'] as string || ''
    const accesskey = c['accesskey'] as string || ''
    if (!id || !accesskey) { return '' }
    const dlUrl = `http://lyrics.kugou.com/download?ver=1&client=pc&id=${id}&accesskey=${accesskey}&fmt=lrc&charset=utf8`
    const dResp = await http.createHttp().request(dlUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.kugou.com/' },
      connectTimeout: 6000, readTimeout: 6000
    })
    if (dResp.responseCode !== 200) { return '' }
    const dBody: Record<string, Object> = JSON.parse(dResp.result as string) as Record<string, Object>
    const content = dBody['content'] as string || ''
    if (!content) { return '' }
    const lyricBytes = buffer.from(content, 'base64')
    const decoder = new util.TextDecoder('utf-8')
    return decoder.decodeToString(new Uint8Array(lyricBytes.buffer), { stream: false })
  } catch (e) {
    Logger.warn(TAG, `kugou lyrics error: ${JSON.stringify(e)}`)
    return ''
  }
}
