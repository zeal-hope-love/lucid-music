/*
 * wy/utils/request.ets - 网易云共享请求封装
 * 抽取自原 wy/index.ets 的 eapi/weapi 请求与歌曲详情，供各端点模块复用。
 */
import { http } from '@kit.NetworkKit'
import { buffer } from '@kit.ArkTS'
import { Logger } from 'musicbasic'
import { eapiEncrypt, weapiEncrypt, TAG } from './crypto'

const REQ_TAG = 'WyMusicApi'

// ===== EAPI 请求 =====
export async function eapiRequest(path: string, data: ESObject): Promise<Record<string, Object> | null> {
  try {
    const params = await eapiEncrypt(path, data)
    const formBody = `params=${params}`
    const bodyBytes = new Uint8Array(buffer.from(formBody, 'utf-8').buffer)
    const resp = await http.createHttp().request('https://interface.music.163.com/eapi/batch', {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'Accept': 'application/json',
        'origin': 'https://music.163.com'
      },
      extraData: bodyBytes.buffer,
      connectTimeout: 10000, readTimeout: 10000
    })
    const resultStr = resp.result as string | undefined
    const rlen = resultStr ? resultStr.length : 0
    Logger.info(REQ_TAG, `eapiRequest: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
    if (resp.responseCode !== 200 || !resp.result) {
      Logger.warn(REQ_TAG, `eapiRequest FAILED: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
      return null
    }
    return JSON.parse(resp.result as string) as Record<string, Object>
  } catch (e) {
    Logger.error(REQ_TAG, `eapiRequest EXCEPTION: path=${path}, err=${(e as Error)?.message || JSON.stringify(e)}`)
    return null
  }
}

// ===== WEAPI 请求 =====
export async function weapiRequest(path: string, data: ESObject): Promise<Record<string, Object> | null> {
  try {
    const weapiResult = await weapiEncrypt(data)
    const formBody = `params=${encodeURIComponent(weapiResult.params)}&encSecKey=${encodeURIComponent(weapiResult.encSecKey)}`
    const bodyBytes = new Uint8Array(buffer.from(formBody, 'utf-8').buffer)
    let hexPrev = ''
    for (let i = 0; i < Math.min(bodyBytes.length, 60); i++) {
      hexPrev += ((bodyBytes[i] as number) < 16 ? '0' : '') + ((bodyBytes[i] as number) & 0xff).toString(16).toUpperCase()
    }
    Logger.info(REQ_TAG, `WEAPI_BODY: path=${path}, formLen=${formBody.length}, byteLen=${bodyBytes.length}, hexPreview=${hexPrev}`)
    const resp = await http.createHttp().request(`https://music.163.com/weapi/${path}`, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
        'Referer': 'https://music.163.com',
        'origin': 'https://music.163.com'
      },
      extraData: bodyBytes.buffer,
      connectTimeout: 8000, readTimeout: 8000
    })
    const resultStr = resp.result as string | undefined
    const rlen = resultStr ? resultStr.length : 0
    Logger.info(REQ_TAG, `WEAPI_RESP: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
    if (resp.responseCode !== 200 || !resp.result) {
      Logger.warn(REQ_TAG, `weapiRequest FAILED: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
      return null
    }
    return JSON.parse(resp.result as string) as Record<string, Object>
  } catch (e) {
    Logger.error(REQ_TAG, `weapiRequest EXCEPTION: path=${path}, err=${(e as Error)?.message || JSON.stringify(e)}`)
    return null
  }
}

export async function getSongDetail(songId: string): Promise<Record<string, Object> | null> {
  const body = await weapiRequest('v3/song/detail', { c: `[{"id":${songId}}]`, ids: `[${songId}]` })
  if (!body || body['code'] !== 200 || !body['songs']) {
    Logger.warn(REQ_TAG, `getSongDetail FAILED: songId=${songId}, code=${body?.['code']}`)
    return null
  }
  const songs = body['songs'] as Record<string, Object>[]
  return songs.length > 0 ? songs[0] : null
}

export function extractCoverFromDetail(detail: Record<string, Object> | null): string {
  if (!detail) { return '' }
  const al = detail['al'] as Record<string, Object>
  const picUrl = al ? (al['picUrl'] as string) || '' : ''
  return picUrl.replace('http://', 'https://')
}
