/*
 * WyMusicApi - 网易云音乐平台 API
 */
import { http } from '@kit.NetworkKit'
import { buffer } from '@kit.ArkTS'
import { SearchResultItem } from '../../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { TAG, PlayUrlResult, WeapiResult, eapiEncrypt, weapiEncrypt, formatDuration } from '../MusicApiUtils'

export class WyMusicApi {
  // ===== 搜索 =====
  static async search(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    // 主路径：eapi（含 privilege 音质数据，对齐 lx-music）
    const body = await WyMusicApi.eapiRequest('/api/search/song/list/page', {
      keyword: keyword, needCorrect: '1', channel: 'typing',
      offset: limit * (page - 1), scene: 'normal', total: page == 1, limit: limit
    })
    if (body && body['code'] === 200 && body['data']) {
      const data = body['data'] as Record<string, Object>
      const results = WyMusicApi.mapList(data['resources'] as Record<string, Object>[] || [])
      Logger.info(TAG, `wy search eapi: ${results.length} results for "${keyword}"`)
      if (results.length > 0) { return results }
    }
    // 兜底：legacy
    const results = await WyMusicApi.searchLegacy(keyword, page, limit)
    Logger.info(TAG, `wy search legacy: ${results.length} results for "${keyword}"`)
    return await WyMusicApi.fillMissingCovers(results)
  }

  private static async searchLegacy(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const resp = await http.createHttp().request(
        `https://music.163.com/api/search/get?s=${encodeURIComponent(keyword)}&type=1&offset=${(page - 1) * limit}&limit=${limit}`,
        { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' }, connectTimeout: 10000, readTimeout: 10000 }
      )
      if (resp.responseCode !== 200) { return [] }
      const body = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== 200 || !body['result']) { return [] }
      return WyMusicApi.parseLegacySongs((body['result'] as Record<string, Object>)['songs'] as Record<string, Object>[] || [])
    } catch (e) { Logger.error(TAG, `wy searchLegacy err: ${JSON.stringify(e)}`); return [] }
  }

  private static parseLegacySongs(songs: Record<string, Object>[]): SearchResultItem[] {
    const r: SearchResultItem[] = []
    for (const item of songs) {
      const result = new SearchResultItem()
      result.title = (item['name'] as string) || ''
      const artists = item['artists'] as Record<string, Object>[]
      result.singer = artists ? artists.map(a => a['name'] as string).join('、') : ''
      const album = item['album'] as Record<string, Object>
      const al = item['al'] as Record<string, Object>
      result.album = album ? (album['name'] as string) || '' : (al ? (al['name'] as string) || '' : '')
      result.songId = String((item['id'] as number) || 0)
      result.source = 'wy'
      result.duration = formatDuration(Math.floor(((item['duration'] as number) || 0) / 1000))
      let picUrl = (album ? (album['picUrl'] as string) || '' : '')
      if (!picUrl && al) { picUrl = (al['picUrl'] as string) || '' }
      result.coverUrl = picUrl.replace('http://', 'https://')
      result.cover = result.coverUrl
      const privilege = item['privilege'] as Record<string, Object>
      const maxbr = privilege ? (privilege['maxbr'] as number) || 0 : 0
      const maxBrLevel = privilege ? (privilege['maxBrLevel'] as string) || '' : ''
      result.quality = WyMusicApi.resolveQuality(maxBrLevel, maxbr, item)
      result.rawFields = item
      r.push(result)
    }
    return r
  }

  private static mapList(resources: Record<string, Object>[]): SearchResultItem[] {
    const r: SearchResultItem[] = []
    if (!Array.isArray(resources)) { return r }
    for (const resource of resources) {
      const baseInfo = resource['baseInfo'] as Record<string, Object>
      if (!baseInfo) { continue }
      const item = baseInfo['simpleSongData'] as Record<string, Object>
      if (!item) { continue }
      const result = new SearchResultItem()
      result.title = (item['name'] as string) || ''
      const artists = item['ar'] as Record<string, Object>[]
      result.singer = artists ? artists.map(a => a['name'] as string).join('、') : ''
      const al = item['al'] as Record<string, Object>
      result.album = al ? (al['name'] as string) || '' : ''
      result.songId = String((item['id'] as number) || 0)
      result.source = 'wy'
      result.duration = formatDuration(Math.floor(((item['dt'] as number) || 0) / 1000))
      const picUrl = al ? (al['picUrl'] as string) || '' : ''
      result.coverUrl = picUrl.replace('http://', 'https://')
      result.cover = result.coverUrl
      const privilege = item['privilege'] as Record<string, Object>
      const maxbr = privilege ? (privilege['maxbr'] as number) || 0 : 0
      const maxBrLevel = privilege ? (privilege['maxBrLevel'] as string) || '' : ''
      result.quality = WyMusicApi.resolveQuality(maxBrLevel, maxbr, item)
      result.rawFields = item
      r.push(result)
    }
    return r
  }

  /**
   * 解析网易云歌曲音质
   * 优先使用 privilege.maxBrLevel + maxbr，不可用时 fallback 到 h/m/l 品质子对象的 bitrate
   */
  private static resolveQuality(maxBrLevel: string, maxbr: number, item: Record<string, Object>): string {
    if (maxBrLevel === 'hires') { return '24bit' }
    if (maxbr >= 999000) { return 'SQ' }
    if (maxbr >= 320000) { return 'HQ' }
    // privilege 无法判定时，从 h/m/l 品质子对象获取 bitrate 作为 fallback
    if (maxbr === 0 && !maxBrLevel) {
      const hItem = item['h'] as Record<string, Object>
      const mItem = item['m'] as Record<string, Object>
      const lItem = item['l'] as Record<string, Object>
      const hBr = hItem ? (hItem['br'] as number) || 0 : 0
      const mBr = mItem ? (mItem['br'] as number) || 0 : 0
      const lBr = lItem ? (lItem['br'] as number) || 0 : 0
      const bestBr = Math.max(hBr, mBr, lBr)
      Logger.info(TAG, `wy quality fallback: title=${item['name']}, hasPrivilege=${!!item['privilege']}, maxbr=${maxbr}, maxBrLevel=${maxBrLevel}, hBr=${hBr}, mBr=${mBr}, lBr=${lBr}, bestBr=${bestBr}`)
      if (bestBr >= 999000) { return 'SQ' }
      if (bestBr >= 320000) { return 'HQ' }
      return '标准'
    }
    return '标准'
  }

  private static async fillMissingCovers(results: SearchResultItem[]): Promise<SearchResultItem[]> {
    const need = results.filter(r => !r.coverUrl && r.songId)
    if (need.length === 0) { return results }
    Logger.info(TAG, `fillMissingCovers: ${need.length}/${results.length} songs need covers`)
    const details = await Promise.all(need.map(r => WyMusicApi.getSongDetail(r.songId).catch(() => null)))
    let filled = 0
    for (let i = 0; i < need.length; i++) {
      const coverUrl = WyMusicApi.extractCoverFromDetail(details[i])
      if (coverUrl) { need[i].coverUrl = coverUrl; need[i].cover = coverUrl; filled++ }
    }
    Logger.info(TAG, `fillMissingCovers: filled ${filled}/${need.length}`)
    return results
  }

  // ===== 热搜 =====
  static async hotSearch(): Promise<string[]> {
    try {
      const body = await WyMusicApi.eapiRequest('/api/search/chart/detail', { id: 'HOT_SEARCH_SONG#@#' })
      if (body && body['code'] === 200 && body['data']) {
        const items = ((body['data'] as Record<string, Object>)['itemList'] as Record<string, Object>[])
          .map(h => h['searchWord'] as string).filter(Boolean)
        Logger.info(TAG, `wy hotSearch: ${items.length} items`)
        return items
      }
      Logger.warn(TAG, `wy hotSearch failed, code=${body?.['code']}`)
    } catch (e) { Logger.error(TAG, `wy hotSearch err: ${JSON.stringify(e)}`) }
    return []
  }

  // ===== 联想 =====
  static async suggest(keyword: string): Promise<SuggestionItem[]> {
    try {
      const resp = await http.createHttp().request(
        `https://music.163.com/api/search/suggest/web?csrf_token=&s=${encodeURIComponent(keyword)}&type=1`,
        { method: http.RequestMethod.GET, header: { 'Referer': 'https://music.163.com' }, connectTimeout: 5000, readTimeout: 5000 }
      )
      if (resp.responseCode !== 200) { return [] }
      const body = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 200 || !body['result']) { return [] }
      const songs = (body['result'] as Record<string, Object>)['songs'] as Record<string, Object>[]
      const items: SuggestionItem[] = []
      if (songs) { for (const s of songs.slice(0, 5)) { if (s['name']) { items.push(new SuggestionItem(s['name'] as string, SuggestionType.SONG, keyword)) } } }
      return items.slice(0, 10)
    } catch (e) { Logger.error(TAG, `wy suggest err: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 播放URL =====
  static async getPlayUrl(songId: string): Promise<PlayUrlResult> {
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
      const lyricsResult: string = await WyMusicApi.getLyrics(songId).catch(() => '')
      const detailResult: Record<string, Object> | null = await WyMusicApi.getSongDetail(songId).catch(() => null)
      const cover = WyMusicApi.extractCoverFromDetail(detailResult)
      Logger.info(TAG, `wy getPlayUrl: songId=${songId}, urlLen=${playUrl.length}, lrcLen=${lyricsResult.length}, coverLen=${cover.length}`)
      return { url: playUrl, lyrics: lyricsResult, cover: cover }
    } catch (e) { Logger.error(TAG, `wy getPlayUrl err: ${JSON.stringify(e)}`); return empty }
  }

  // ===== 歌词 =====
  static async getLyrics(songId: string): Promise<string> {
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

  // ===== EAPI 请求 =====
  private static async eapiRequest(path: string, data: ESObject): Promise<Record<string, Object> | null> {
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
      Logger.info(TAG, `eapiRequest: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
      if (resp.responseCode !== 200 || !resp.result) {
        Logger.warn(TAG, `eapiRequest FAILED: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
        return null
      }
      return JSON.parse(resp.result as string) as Record<string, Object>
    } catch (e) {
      Logger.error(TAG, `eapiRequest EXCEPTION: path=${path}, err=${(e as Error)?.message || JSON.stringify(e)}`)
      return null
    }
  }

  // ===== WEAPI 请求 =====
  private static async weapiRequest(path: string, data: ESObject): Promise<Record<string, Object> | null> {
    try {
      const weapiResult: WeapiResult = await weapiEncrypt(data)
      const formBody = `params=${encodeURIComponent(weapiResult.params)}&encSecKey=${encodeURIComponent(weapiResult.encSecKey)}`
      const bodyBytes = new Uint8Array(buffer.from(formBody, 'utf-8').buffer)
      // 诊断日志：打印 body 的完整字符串和字节级 hex 预览
      let hexPrev = ''
      for (let i = 0; i < Math.min(bodyBytes.length, 60); i++) {
        hexPrev += ((bodyBytes[i] as number) < 16 ? '0' : '') + ((bodyBytes[i] as number) & 0xff).toString(16).toUpperCase()
      }
      Logger.info(TAG, `WEAPI_BODY: path=${path}, formLen=${formBody.length}, byteLen=${bodyBytes.length}, hexPreview=${hexPrev}`)
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
      Logger.info(TAG, `WEAPI_RESP: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
      if (resp.responseCode !== 200 || !resp.result) {
        Logger.warn(TAG, `weapiRequest FAILED: path=${path}, httpCode=${resp.responseCode}, resultLen=${rlen}`)
        return null
      }
      return JSON.parse(resp.result as string) as Record<string, Object>
    } catch (e) {
      Logger.error(TAG, `weapiRequest EXCEPTION: path=${path}, err=${(e as Error)?.message || JSON.stringify(e)}`)
      return null
    }
  }

  static async getSongDetail(songId: string): Promise<Record<string, Object> | null> {
    const body = await WyMusicApi.weapiRequest('v3/song/detail', { c: `[{"id":${songId}}]`, ids: `[${songId}]` })
    if (!body || body['code'] !== 200 || !body['songs']) { Logger.warn(TAG, `getSongDetail FAILED: songId=${songId}, code=${body?.['code']}`); return null }
    const songs = body['songs'] as Record<string, Object>[]
    return songs.length > 0 ? songs[0] : null
  }

  static extractCoverFromDetail(detail: Record<string, Object> | null): string {
    if (!detail) { return '' }
    const al = detail['al'] as Record<string, Object>
    const picUrl = al ? (al['picUrl'] as string) || '' : ''
    return picUrl.replace('http://', 'https://')
  }
}
