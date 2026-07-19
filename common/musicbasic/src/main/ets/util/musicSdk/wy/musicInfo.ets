/*
 * wy/musicInfo.ets - 网易云歌曲信息：播放URL / 封面 / 详情页
 */
import { http } from '@kit.NetworkKit'
import { Logger, PlayUrlResult } from 'musicbasic'
import { getSongDetail, extractCoverFromDetail } from './utils/request'
import { getLyrics } from './lyric'

const TAG = 'WyMusicApi'

// ===== 播放URL =====
export async function getPlayUrl(songId: string): Promise<PlayUrlResult> {
  const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
  try {
    const resp = await http.createHttp().request(
      `https://music.163.com/api/song/enhance/player/url?id=${songId}&ids=[${songId}]&br=320000`,
      { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' }, connectTimeout: 8000, readTimeout: 8000 }
    )
    let playUrl = ''
    if (resp.responseCode === 200) {
      const body = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] === 200 && body['data']) {
        const data = body['data'] as Record<string, Object>[]
        if (data.length > 0) { playUrl = (data[0]['url'] as string) || '' }
      }
    }
    const lyricsResult: string = await getLyrics(songId).catch(() => '')
    const detailResult: Record<string, Object> | null = await getSongDetail(songId).catch(() => null)
    const cover = extractCoverFromDetail(detailResult)
    Logger.info(TAG, `wy getPlayUrl: songId=${songId}, urlLen=${playUrl.length}, lrcLen=${lyricsResult.length}, coverLen=${cover.length}`)
    return { url: playUrl, lyrics: lyricsResult, cover: cover }
  } catch (e) { Logger.error(TAG, `wy getPlayUrl err: ${JSON.stringify(e)}`); return empty }
}

// ===== 封面 =====
export function getPic(songInfo: Record<string, Object>): Promise<string> {
  const requestObj = getSongDetail(songInfo['songmid'] as string)
  return requestObj.then(info => info ? (info['al'] as Record<string, Object>)['picUrl'] as string : '')
    .catch(() => '')
}

// ===== 详情页URL =====
export function getMusicDetailPageUrl(songInfo: Record<string, Object>): string {
  return `https://music.163.com/#/song?id=${songInfo['songmid'] as string}`
}
