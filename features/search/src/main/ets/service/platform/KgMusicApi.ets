/*
 * KgMusicApi - 酷狗音乐平台 API
 */
import { http } from '@kit.NetworkKit'
import { buffer, util } from '@kit.ArkTS'
import { SearchResultItem } from '../../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { TAG, platformToId, PlayUrlResult, formatDuration } from '../MusicApiUtils'

export class KgMusicApi {
  // ===== 搜索 =====
  static async search(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const url = `https://songsearch.kugou.com/song_search_v2?keyword=${encodeURIComponent(keyword)}&page=${page}&pagesize=${limit}&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, connectTimeout: 10000, readTimeout: 10000 })
      if (resp.responseCode !== 200) { Logger.warn(TAG, `kugou search failed, code=${resp.responseCode}`); return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['error_code'] !== 0 || !body['data']) { return [] }
      return KgMusicApi.mapList((body['data'] as Record<string, Object>)['lists'] as object[])
    } catch (e) { Logger.error(TAG, `kugou search error: ${JSON.stringify(e)}`); return [] }
  }

  static mapList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []; const seen = new Set<string>()
    if (!Array.isArray(rawList)) { return results }
    for (const item of rawList as Record<string, Object>[]) {
      const key = (item['Audioid'] as string) + (item['FileHash'] as string)
      if (seen.has(key)) { continue }
      seen.add(key)
      const result = new SearchResultItem()
      result.title = (item['SongName'] as string) || ''; result.singer = (item['SingerName'] as string) || ''
      result.album = (item['AlbumName'] as string) || ''; result.songId = (item['FileHash'] as string) || ''
      result.source = 'kg'; result.duration = formatDuration((item['Duration'] as number) || 0)
      const albumId: string = (item['AlbumID'] as string) || ''; const kgHash: string = (item['FileHash'] as string) || ''
      result.coverUrl = albumId ? `https://imge.kugou.com/stdmusic/240/${albumId}.png` : kgHash ? `https://imge.kugou.com/stdmusic/240/${kgHash}.png` : ''
      result.cover = result.coverUrl
      const resHash: string = (item['ResFileHash'] as string) || ''; const sqHash: string = (item['SQFileHash'] as string) || ''; const hqHash: string = (item['HQFileHash'] as string) || ''
      result.quality = resHash ? '24bit' : sqHash ? 'SQ' : hqHash ? 'HQ' : '标准'
      result.rawFields = item; results.push(result)
    }
    return results
  }

  // ===== 热搜 =====
  static async hotSearch(): Promise<string[]> {
    try {
      const url = 'http://gateway.kugou.com/api/v3/search/hot_tab?signature=ee44edb9d7155821412d220bcaf509dd&appid=1005&clientver=10026&plat=0'
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'dfid': '1ssiv93oVqMp27cirf2CvoF1', 'mid': '156798703528610303473757548878786007104', 'clienttime': '1584257267', 'x-router': 'msearch.kugou.com', 'user-agent': 'Android9-AndroidPhone-10020-130-0-searchrecommendprotocol-wifi', 'kg-rc': '1' }, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['errcode'] !== 0 || !body['data']) { return [] }
      const list = (body['data'] as Record<string, Object>)['list'] as Record<string, Object>[]
      if (!list || !Array.isArray(list)) { return [] }
      const kwds: string[] = []
      for (const item of list) {
        const keywords = item['keywords'] as Record<string, Object>[]
        if (keywords) { for (const k of keywords) { const kw = k['keyword'] as string; if (kw) { kwds.push(kw) } } }
      }
      return kwds
    } catch (e) { Logger.error(TAG, `kg hotSearch error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 联想 =====
  static async suggest(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://searchtip.kugou.com/getSearchTip?MusicTipCount=10&keyword=${encodeURIComponent(keyword)}`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'referer': 'https://www.kugou.com/' }, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const outerArr: object[] = JSON.parse(resp.result as string) as object[]
      if (!outerArr || !Array.isArray(outerArr) || outerArr.length === 0) { return [] }
      const recordDatas = (outerArr[0] as Record<string, Object>)['RecordDatas'] as Record<string, Object>[]
      if (!recordDatas || !Array.isArray(recordDatas)) { return [] }
      const items: SuggestionItem[] = []; const seen = new Set<string>()
      for (const rd of recordDatas) { const hint = rd['HintInfo'] as string; if (!hint || seen.has(hint)) { continue }; seen.add(hint); items.push(new SuggestionItem(hint, SuggestionType.SONG, keyword)) }
      return items.slice(0, 10)
    } catch (e) { Logger.error(TAG, `kg suggest error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 播放URL =====
  static async getPlayUrl(hash: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    try {
      const albumId: string = (rawFields['AlbumID'] as string) || ''; const songName: string = (rawFields['SongName'] as string) || ''
      let playUrl: string | null = await KgMusicApi.tryWwwApiV1(hash, albumId)
      if (!playUrl) { playUrl = await KgMusicApi.tryBackup(hash) }
      if (!playUrl) { playUrl = await KgMusicApi.tryCdn(hash) }
      const lyrics = await KgMusicApi.getLyrics(hash, songName)
      const cover = await KgMusicApi.fetchPic((rawFields['Audioid'] as number) || 0, albumId, hash, `${(rawFields['SingerName'] as string) || ''} - ${songName}.mp3`)
      return { url: playUrl || '', lyrics: lyrics, cover: cover }
    } catch (e) { Logger.error(TAG, `kugou getPlayUrl error: ${JSON.stringify(e)}`); return { url: '', lyrics: '', cover: '' } }
  }

  private static async tryWwwApiV1(hash: string, albumId: string): Promise<string | null> {
    try {
      const apiUrl = `https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=${hash}&album_id=${albumId}&mid=1&platid=4`
      const resp = await http.createHttp().request(apiUrl, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile)', 'Referer': 'https://www.kugou.com/', 'Cookie': 'kg_mid=1' }, connectTimeout: 8000, readTimeout: 8000 })
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

  private static async tryBackup(hash: string): Promise<string | null> {
    try {
      const backupUrl = `http://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=${hash}`
      const resp = await http.createHttp().request(backupUrl, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile)', 'Referer': 'http://m.kugou.com/' }, connectTimeout: 8000, readTimeout: 8000 })
      if (resp.responseCode !== 200) { return null }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if ((body['status'] as number) === 1 && body['url']) { return body['url'] as string }
    } catch (_) {}
    return null
  }

  private static async tryCdn(hash: string): Promise<string | null> {
    try {
      if (!hash || hash.length < 4) { return null }
      const prefix = `${hash.substring(0, 2)}/${hash.substring(2, 4)}`
      const cdnHosts = [`https://fs.ali.kugou.com/${prefix}/${hash}.mp3`, `https://fs.ws.kugou.com/${prefix}/${hash}.mp3`, `https://fs.android.kugou.com/${prefix}/${hash}.mp3`]
      for (const cdnUrl of cdnHosts) {
        try {
          const resp = await http.createHttp().request(cdnUrl, { method: http.RequestMethod.HEAD, header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/' }, connectTimeout: 5000, readTimeout: 5000 })
          if (resp.responseCode === 200 || resp.responseCode === 302) { return cdnUrl }
        } catch (_) {}
      }
    } catch (_) {}
    return null
  }

  /** KG cover pic API */
  static async fetchPic(songmid: number, albumId: string, hash: string, fileName: string): Promise<string> {
    try {
      const resItem: Record<string, Object> = { 'album_audio_id': songmid, 'album_id': albumId, 'hash': hash, 'id': 0, 'name': fileName, 'type': 'audio' }
      const body: Record<string, Object> = { 'appid': 1001, 'area_code': '1', 'behavior': 'play', 'clientver': '9020', 'need_hash_offset': 1, 'relate': 1, 'resource': new Array<Record<string, Object>>(resItem), 'token': '', 'userid': 2626431536, 'vip': 1 }
      const resp = await http.createHttp().request('http://media.store.kugou.com/v1/get_res_privilege', { method: http.RequestMethod.POST, header: { 'Content-Type': 'application/json', 'KG-RC': '1', 'KG-THash': 'expand_search_manager.cpp:852736169:451', 'User-Agent': 'KuGou2012-9020-ExpandSearchManager' }, extraData: JSON.stringify(body), connectTimeout: 8000, readTimeout: 8000 })
      if (resp.responseCode === 200 && resp.result) {
        const data: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
        if ((data['error_code'] as number) === 0) {
          const list = data['data'] as Record<string, Object>[]
          if (list && list.length > 0) {
            const info = list[0]['info'] as Record<string, Object>; const image = info['image'] as string
            if (image) { const sizes = info['imgsize'] as number[]; if (sizes && sizes.length > 0) { return image.replace('{size}', String(sizes[0])) }; return image }
          }
        }
      }
    } catch (_) {}
    return ''
  }

  // ===== 歌词 =====
  static async getLyrics(hash: string, songName: string): Promise<string> {
    try {
      const searchUrl = `http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=${encodeURIComponent(songName)}&hash=${hash}&lrctxt=1`
      const sResp = await http.createHttp().request(searchUrl, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.kugou.com/' }, connectTimeout: 6000, readTimeout: 6000 })
      if (sResp.responseCode !== 200) { return '' }
      const sBody: Record<string, Object> = JSON.parse(sResp.result as string) as Record<string, Object>
      const candidates = sBody['candidates'] as Record<string, Object>[]
      if (!candidates || candidates.length === 0) { return '' }
      const c = candidates[0]; const id = c['id'] as string || ''; const accesskey = c['accesskey'] as string || ''
      if (!id || !accesskey) { return '' }
      const dlUrl = `http://lyrics.kugou.com/download?ver=1&client=pc&id=${id}&accesskey=${accesskey}&fmt=lrc&charset=utf8`
      const dResp = await http.createHttp().request(dlUrl, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.kugou.com/' }, connectTimeout: 6000, readTimeout: 6000 })
      if (dResp.responseCode !== 200) { return '' }
      const dBody: Record<string, Object> = JSON.parse(dResp.result as string) as Record<string, Object>
      const content = dBody['content'] as string || ''
      if (!content) { return '' }
      const lyricBytes = buffer.from(content, 'base64'); const decoder = new util.TextDecoder('utf-8')
      return decoder.decodeToString(new Uint8Array(lyricBytes.buffer), { stream: false })
    } catch (e) { Logger.warn(TAG, `kugou lyrics error: ${JSON.stringify(e)}`); return '' }
  }
}
