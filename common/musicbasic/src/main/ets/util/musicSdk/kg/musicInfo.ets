/*
 * kg/musicInfo.ets - 酷狗音乐歌曲信息：播放URL / 封面 / 详情页
 */
import { http } from '@kit.NetworkKit'
import { Logger, PlayUrlResult } from 'musicbasic'
import { getLyrics } from './lyric'

const TAG = 'KgMusicApi'

// ===== 播放URL =====
export async function getPlayUrl(hash: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
  const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
  try {
    const albumId: string = (rawFields['AlbumID'] as string) || ''
    const songName: string = (rawFields['SongName'] as string) || ''
    let playUrl: string | null = await tryWwwApiV1(hash, albumId)
    if (!playUrl) { playUrl = await tryBackup(hash) }
    if (!playUrl) { playUrl = await tryCdn(hash) }
    const lyrics = await getLyrics(hash, songName).catch(() => '')
    const cover = await fetchPic((rawFields['Audioid'] as number) || 0, albumId, hash, `${songName}.mp3`).catch(() => '')
    return { url: playUrl || '', lyrics: lyrics, cover: cover }
  } catch (e) {
    Logger.error(TAG, `kugou getPlayUrl error: ${JSON.stringify(e)}`)
    return empty
  }
}

async function tryWwwApiV1(hash: string, albumId: string): Promise<string | null> {
  try {
    const apiUrl = `https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=${hash}&album_id=${albumId}&mid=1&platid=4`
    const resp = await http.createHttp().request(apiUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile)', 'Referer': 'https://www.kugou.com/', 'Cookie': 'kg_mid=1' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { return null }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if ((body['err_code'] as number) === 0 && body['data']) {
      const data = body['data'] as Record<string, Object>
      const url = (data['play_url'] as string) || (data['play_backup_url'] as string) || ''
      if (url && url.startsWith('http')) { return url }
    }
  } catch (_) {}
  return null
}

async function tryBackup(hash: string): Promise<string | null> {
  try {
    const backupUrl = `http://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=${hash}`
    const resp = await http.createHttp().request(backupUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile)', 'Referer': 'http://m.kugou.com/' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200) { return null }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if ((body['status'] as number) === 1 && body['url']) { return body['url'] as string }
  } catch (_) {}
  return null
}

async function tryCdn(hash: string): Promise<string | null> {
  try {
    if (!hash || hash.length < 4) { return null }
    const prefix = `${hash.substring(0, 2)}/${hash.substring(2, 4)}`
    const cdnHosts = [
      `https://fs.ali.kugou.com/${prefix}/${hash}.mp3`,
      `https://fs.ws.kugou.com/${prefix}/${hash}.mp3`,
      `https://fs.android.kugou.com/${prefix}/${hash}.mp3`
    ]
    for (const cdnUrl of cdnHosts) {
      try {
        const resp = await http.createHttp().request(cdnUrl, {
          method: http.RequestMethod.HEAD,
          header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/' },
          connectTimeout: 5000, readTimeout: 5000
        })
        if (resp.responseCode === 200 || resp.responseCode === 302) { return cdnUrl }
      } catch (_) {}
    }
  } catch (_) {}
  return null
}

/** KG cover pic API */
export async function fetchPic(songmid: number, albumId: string, hash: string, fileName: string): Promise<string> {
  try {
    const resItem: Record<string, Object> = { 'album_audio_id': songmid, 'album_id': albumId, 'hash': hash, 'id': 0, 'name': fileName, 'type': 'audio' }
    const body: Record<string, Object> = {
      'appid': 1001, 'area_code': '1', 'behavior': 'play', 'clientver': '9020', 'need_hash_offset': 1, 'relate': 1,
      'resource': new Array<Record<string, Object>>(resItem), 'token': '', 'userid': 2626431536, 'vip': 1
    }
    const resp = await http.createHttp().request('http://media.store.kugou.com/v1/get_res_privilege', {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json', 'KG-RC': '1', 'KG-THash': 'expand_search_manager.cpp:852736169:451', 'User-Agent': 'KuGou2012-9020-ExpandSearchManager' },
      extraData: JSON.stringify(body),
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode === 200 && resp.result) {
      const data: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if ((data['error_code'] as number) === 0) {
        const list = data['data'] as Record<string, Object>[]
        if (list && list.length > 0) {
          const info = list[0]['info'] as Record<string, Object>
          const image = info['image'] as string
          if (image) {
            const sizes = info['imgsize'] as number[]
            if (sizes && sizes.length > 0) { return image.replace('{size}', String(sizes[0])) }
            return image
          }
        }
      }
    }
  } catch (_) {}
  return ''
}

// ===== 封面 =====
export function getPic(songInfo: Record<string, Object>): Promise<string> {
  // 酷狗以 hash 作为 songmid，封面通过 fetchPic 获取（此处无 album 信息，返回空）
  return Promise.resolve('')
}

// ===== 详情页URL =====
export function getMusicDetailPageUrl(songInfo: Record<string, Object>): string {
  return `https://www.kugou.com/song/#hash=${songInfo['songmid'] as string}`
}
