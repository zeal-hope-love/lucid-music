/*
 * mg/musicInfo.ets - 咪咕音乐歌曲信息：播放URL / 封面 / 详情页
 */
import { http } from '@kit.NetworkKit'
import { Logger, PlayUrlResult } from 'musicbasic'

const TAG = 'MgMusicApi'

// ===== 播放URL =====
export async function getPlayUrl(copyrightId: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
  const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/resourceinfo.do?copyrightId=${copyrightId}&resourceType=2`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 8000, readTimeout: 8000
    })
    let bestUrl = ''
    if (resp.responseCode === 200) {
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['resource']) {
        for (const r of body['resource'] as Record<string, Object>[]) {
          const pu = (r['newRateFormats'] as string) || (r['androidUrl'] as string) || (r['iosUrl'] as string) || ''
          if (pu) { bestUrl = pu }
        }
      }
    }
    return { url: bestUrl, lyrics: '', cover: '' }
  } catch (e) {
    Logger.error(TAG, `mg getPlayUrl error: ${JSON.stringify(e)}`)
    return empty
  }
}

// ===== 封面 =====
export function getPic(songInfo: Record<string, Object>): Promise<string> {
  return Promise.resolve('')
}

// ===== 详情页URL =====
export function getMusicDetailPageUrl(songInfo: Record<string, Object>): string {
  return `https://music.migu.cn/v3/music/song/${songInfo['songmid'] as string}`
}
