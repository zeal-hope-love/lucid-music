/*
 * tx/musicInfo.ets - QQ音乐歌曲信息：播放URL / 封面 / 详情页
 */
import { http } from '@kit.NetworkKit'
import { Logger, PlayUrlResult } from 'musicbasic'
import { QQVkeyParam, QQVkeyBody } from './qqTypes'
import { getLyrics } from './lyric'

const TAG = 'TxMusicApi'

// ===== 播放URL =====
export async function getPlayUrl(songmid: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
  const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
  try {
    const qqSongmid = (rawFields['songmid'] as string) || songmid
    let playUrl = await tryJson(qqSongmid)
    if (!playUrl) { playUrl = await tryForm(qqSongmid) }
    const lyrics = await getLyrics(qqSongmid)
    const albumMid = (rawFields['albummid'] as string) || (rawFields['album_mid'] as string) || ''
    const cover = albumMid ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg` : ''
    return { url: playUrl || '', lyrics: lyrics, cover: cover }
  } catch (e) { Logger.error(TAG, `tx getPlayUrl error: ${JSON.stringify(e)}`); return empty }
}

async function tryJson(songmid: string): Promise<string | null> {
  try {
    const guid = `${Math.floor(Math.random() * 10000000000000000)}`
    const reqParam: QQVkeyParam = { 'guid': guid, 'songmid': [songmid], 'songtype': [0], 'uin': '0', 'loginflag': 1, 'platform': '20' }
    const reqData: QQVkeyBody = { 'req_0': { 'module': 'vkey.GetVkeyServer', 'method': 'CgiGetVkey', 'param': reqParam } }
    const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: http.RequestMethod.POST, header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://y.qq.com/', 'Content-Type': 'application/json', 'Accept': 'application/json' }, extraData: JSON.stringify(reqData), connectTimeout: 8000, readTimeout: 8000 })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `tx tryJson: http ${resp.responseCode}`); return null }
    const rawResp: string = resp.result as string
    Logger.info(TAG, `tx tryJson response: ${rawResp.substring(0, 300)}`)
    return extractUrl(JSON.parse(rawResp) as Record<string, Object>)
  } catch (e) { Logger.warn(TAG, `tx tryJson error: ${(e as Error)?.message || JSON.stringify(e)}`); return null }
}

async function tryForm(songmid: string): Promise<string | null> {
  try {
    const guid = `${Math.floor(Math.random() * 10000000000)}`
    const reqParam: QQVkeyParam = { 'guid': guid, 'songmid': [songmid], 'songtype': [0], 'uin': '0', 'loginflag': 1, 'platform': '20' }
    const reqData: QQVkeyBody = { 'req_0': { 'module': 'vkey.GetVkeyServer', 'method': 'CgiGetVkey', 'param': reqParam } }
    const formBody = `data=${encodeURIComponent(JSON.stringify(reqData))}`
    const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: http.RequestMethod.POST, header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://y.qq.com/', 'Content-Type': 'application/x-www-form-urlencoded' }, extraData: formBody, connectTimeout: 8000, readTimeout: 8000 })
    if (resp.responseCode !== 200) { Logger.warn(TAG, `tx tryForm: http ${resp.responseCode}`); return null }
    const rawResp: string = resp.result as string
    Logger.info(TAG, `tx tryForm response: ${rawResp.substring(0, 300)}`)
    return extractUrl(JSON.parse(rawResp) as Record<string, Object>)
  } catch (e) { Logger.warn(TAG, `tx tryForm error: ${(e as Error)?.message || JSON.stringify(e)}`); return null }
}

function extractUrl(body: Record<string, Object>): string | null {
  if ((body['code'] as number) && (body['code'] as number) !== 0) {
    Logger.warn(TAG, `tx extractUrl: top-level code=${body['code']}, ts=${body['ts']}`)
    return null
  }
  const req0 = body['req_0'] as Record<string, Object>
  if (!req0) { Logger.warn(TAG, `tx extractUrl: no req_0, keys=${JSON.stringify(Object.keys(body))}`); return null }
  const data = req0['data'] as Record<string, Object>
  if (!data) { Logger.warn(TAG, `tx extractUrl: req_0 has no data, req_0.code=${req0['code']}`); return null }
  const midurlinfo = data['midurlinfo'] as Record<string, Object>[]
  const sip = data['sip'] as string[]; const testfile2g = data['testfile2g'] as string
  if (midurlinfo && midurlinfo.length > 0 && sip && sip.length > 0) {
    const purl = midurlinfo[0]['purl'] as string
    if (purl && purl.length > 0) {
      const server = sip[0] as string
      let prefix: string = server
      if (!prefix.endsWith('/')) { prefix += '/' }
      if (!prefix.startsWith('http')) { prefix = 'https://' + prefix }
      let url: string = prefix + purl
      url = url.replace('http://', 'https://')
      Logger.info(TAG, `tx extractUrl: sip[0]=${server}, purl=${purl}, finalUrl=${url.substring(0, 150)}`)
      return url
    }
    Logger.warn(TAG, `tx extractUrl: purl empty, midurlinfo[0]=${JSON.stringify(midurlinfo[0])}`)
  } else {
    Logger.warn(TAG, `tx extractUrl: midurlinfo missing or sip missing`)
  }
  return null
}

// ===== 封面 =====
export function getPic(songInfo: Record<string, Object>): Promise<string> {
  return Promise.resolve(`https://y.gtimg.cn/music/photo_new/T002R500x500M000${songInfo['albumId'] as string}.jpg`)
}

// ===== 详情页URL =====
export function getMusicDetailPageUrl(songInfo: Record<string, Object>): string {
  return `https://y.qq.com/n/yqq/song/${songInfo['songmid'] as string}.html`
}
