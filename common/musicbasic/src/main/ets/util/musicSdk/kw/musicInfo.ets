/*
 * kw/musicInfo.ets - 酷我音乐歌曲信息：播放URL / 封面 / 详情页
 */
import { http } from '@kit.NetworkKit'
import { Logger, PlayUrlResult } from 'musicbasic'
import { getLyrics } from './lyric'

const TAG = 'KwMusicApi'

// ===== 播放URL =====
export async function getPlayUrl(rid: string): Promise<PlayUrlResult> {
  const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
  try {
    const id = rid.replace('MUSIC_', '').trim()
    const url = `https://www.kuwo.cn/url?format=mp3&rid=${id}&response=url&type=convert_url3&br=128kmp3`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.kuwo.cn/' },
      connectTimeout: 8000, readTimeout: 8000
    })
    let playUrl = ''
    if (resp.responseCode === 200) {
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] === 200 && body['url']) { playUrl = (body['url'] as string) || '' }
    }
    const lyrics = await getLyrics(id).catch(() => '')
    return { url: playUrl, lyrics: lyrics, cover: '' }
  } catch (e) {
    Logger.error(TAG, `kw getPlayUrl error: ${JSON.stringify(e)}`)
    return empty
  }
}

// ===== 封面 =====
export function getPic(songInfo: Record<string, Object>): Promise<string> {
  return Promise.resolve('')
}

// ===== 详情页URL =====
export function getMusicDetailPageUrl(songInfo: Record<string, Object>): string {
  return `https://www.kuwo.cn/play_detail/${songInfo['songmid'] as string}`
}
