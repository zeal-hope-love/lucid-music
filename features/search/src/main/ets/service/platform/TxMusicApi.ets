/*
 * TxMusicApi - QQ音乐平台 API
 */
import { http } from '@kit.NetworkKit'
import { SearchResultItem } from '../../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { TAG, PlayUrlResult, QQVkeyParam, QQVkeyModule, QQVkeyBody, QQHotKeyBody, QQSearchBody, formatDuration, decodeBase64Lyric, zzcSign } from '../MusicApiUtils'

export class TxMusicApi {
  // ===== 搜索 =====
  static async search(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const reqData: QQSearchBody = {
        comm: { ct: '11', cv: '14090508', v: '14090508', tmeAppID: 'qqmusic',
          phonetype: 'EBG-AN10', deviceScore: '553.47', devicelevel: '50', newdevicelevel: '20',
          rom: 'HuaWei/EMOTION/EmotionUI_14.2.0', os_ver: '12', OpenUDID: '0', OpenUDID2: '0',
          QIMEI36: '0', udid: '0', chid: '0', aid: '0', oaid: '0', taid: '0', tid: '0',
          wid: '0', uid: '0', sid: '0', modeSwitch: '6', teenMode: '0', ui_mode: '2', nettype: '1020', v4ip: '' },
        req: { module: 'music.search.SearchCgiService', method: 'DoSearchForQQMusicMobile',
          param: { search_type: 0, searchid: Math.random().toString().slice(2), query: keyword,
            page_num: page, num_per_page: limit, highlight: 0, nqc_flag: 0,
            multi_zhida: 0, cat: 2, grp: 1, sin: 0, sem: 0 } }
      }
      const jsonStr = JSON.stringify(reqData)
      const sign = await zzcSign(jsonStr)
      const resp = await http.createHttp().request(`https://u.y.qq.com/cgi-bin/musics.fcg?sign=${sign}`, {
        method: http.RequestMethod.POST,
        header: { 'User-Agent': 'QQMusic 14090508(android 12)', 'Content-Type': 'application/json' },
        extraData: jsonStr, connectTimeout: 10000, readTimeout: 10000
      })
      if (resp.responseCode !== 200) { Logger.warn(TAG, `tx search http err: ${resp.responseCode}`); return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== 0 || !body['req']) { Logger.warn(TAG, `tx search body err: code=${body?.['code']}`); return [] }
      const req = body['req'] as Record<string, Object>
      if (req['code'] !== 0 || !req['data']) { Logger.warn(TAG, `tx search req err: code=${req['code']}`); return [] }
      const data = req['data'] as Record<string, Object>
      const songs: Record<string, Object>[] = (data['body'] as Record<string, Object>)?.['item_song'] as Record<string, Object>[]
      return songs ? TxMusicApi.mapList(songs) : []
    } catch (e) { Logger.error(TAG, `qq search error: ${JSON.stringify(e)}`); return [] }
  }

  private static mapList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (!Array.isArray(rawList)) { return results }
    for (const item of rawList as Record<string, Object>[]) {
      const file = item['file'] as Record<string, Object>
      if (!file || !file['media_mid']) { continue }
      const result = new SearchResultItem()
      result.title = (item['title'] as string) || ''
      const singers = item['singer'] as Record<string, Object>[]
      result.singer = singers ? singers.map(s => s['name'] as string).join('/') : ''
      const album = item['album'] as Record<string, Object>
      result.album = album ? (album['name'] as string) || '' : ''
      result.songId = (item['mid'] as string) || String((item['id'] as number) || 0)
      result.source = 'tx'
      result.duration = formatDuration((item['interval'] as number) || 0)
      const albumMid: string = album ? (album['mid'] as string) || '' : ''
      if (albumMid && albumMid !== '空') {
        result.coverUrl = `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg`
      } else if (singers && singers.length > 0) {
        const singerMid = singers[0]['mid'] as string
        if (singerMid) { result.coverUrl = `https://y.gtimg.cn/music/photo_new/T001R500x500M000${singerMid}.jpg` }
      }
      result.cover = result.coverUrl
      // 音质：file 子对象各文件大小 != 0 判定（对齐 lx-music）
      if ((file['size_hires'] as number) > 0) { result.quality = '24bit' }
      else if ((file['size_flac'] as number) > 0) { result.quality = 'SQ' }
      else if ((file['size_320mp3'] as number) > 0) { result.quality = 'HQ' }
      else { result.quality = '标准' }
      // rawFields 兼容 getPlayUrl（需要 songmid/albummid 字段）
      result.rawFields = item
      result.rawFields['songmid'] = result.songId
      if (albumMid) { result.rawFields['albummid'] = albumMid }
      results.push(result)
    }
    return results
  }

  // ===== 热搜 =====
  static async hotSearch(): Promise<string[]> {
    try {
      const body: QQHotKeyBody = { comm: { ct: '19', cv: '1803', guid: '0', patch: '118', psrf_access_token_expiresAt: 0, psrf_qqaccess_token: '', psrf_qqopenid: '', psrf_qqunionid: '', tmeAppID: 'qqmusic', tmeLoginType: 0, uin: '0', wid: '0' }, hotkey: { method: 'GetHotkeyForQQMusicPC', module: 'tencent_musicsoso_hotkey.HotkeyService', param: { search_id: '', uin: 0 } } }
      const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: http.RequestMethod.POST, header: { 'Content-Type': 'application/json', 'Referer': 'https://y.qq.com/portal/player.html' }, extraData: JSON.stringify(body), connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const data: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (data['code'] !== 0 || !data['hotkey']) { return [] }
      const hotData = (data['hotkey'] as Record<string, Object>)['data'] as Record<string, Object>
      const vecHotkey = hotData ? hotData['vec_hotkey'] as Record<string, Object>[] : []
      return vecHotkey ? vecHotkey.map(h => h['query'] as string).filter(Boolean) : []
    } catch (e) { Logger.error(TAG, `tx hotSearch error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 联想 =====
  static async suggest(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?is_xml=0&format=json&key=${encodeURIComponent(keyword)}&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'https://y.qq.com/portal/player.html' }, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 0 || !body['data']) { return [] }
      const itemlist = ((body['data'] as Record<string, Object>)['song'] as Record<string, Object>)['itemlist'] as Record<string, Object>[]
      if (!itemlist) { return [] }
      const items: SuggestionItem[] = []; const seen = new Set<string>()
      for (const item of itemlist) { const name = item['name'] as string || ''; if (!name || seen.has(name)) { continue }; seen.add(name); items.push(new SuggestionItem(name, SuggestionType.SONG, keyword)) }
      return items.slice(0, 10)
    } catch (e) { Logger.error(TAG, `tx suggest error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 播放URL =====
  static async getPlayUrl(songmid: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
    try {
      const qqSongmid = (rawFields['songmid'] as string) || songmid
      let playUrl = await TxMusicApi.tryJson(qqSongmid)
      if (!playUrl) { playUrl = await TxMusicApi.tryForm(qqSongmid) }
      const lyrics = await TxMusicApi.getLyrics(qqSongmid)
      const albumMid = (rawFields['albummid'] as string) || (rawFields['album_mid'] as string) || ''
      const cover = albumMid ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg` : ''
      return { url: playUrl || '', lyrics: lyrics, cover: cover }
    } catch (e) { Logger.error(TAG, `qq getPlayUrl error: ${JSON.stringify(e)}`); return empty }
  }

  private static async tryJson(songmid: string): Promise<string | null> {
    try {
      const guid = `${Math.floor(Math.random() * 10000000000000000)}`
      const reqParam: QQVkeyParam = { 'guid': guid, 'songmid': [songmid], 'songtype': [0], 'uin': '0', 'loginflag': 1, 'platform': '20' }
      const reqData: QQVkeyBody = { 'req_0': { 'module': 'vkey.GetVkeyServer', 'method': 'CgiGetVkey', 'param': reqParam } }
      const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: http.RequestMethod.POST, header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://y.qq.com/', 'Content-Type': 'application/json', 'Accept': 'application/json' }, extraData: JSON.stringify(reqData), connectTimeout: 8000, readTimeout: 8000 })
      if (resp.responseCode !== 200) { Logger.warn(TAG, `tx tryJson: http ${resp.responseCode}`); return null }
      const rawResp: string = resp.result as string
      Logger.info(TAG, `tx tryJson response: ${rawResp.substring(0, 300)}`)
      return TxMusicApi.extractUrl(JSON.parse(rawResp) as Record<string, Object>)
    } catch (e) { Logger.warn(TAG, `tx tryJson error: ${(e as Error)?.message || JSON.stringify(e)}`); return null }
  }

  private static async tryForm(songmid: string): Promise<string | null> {
    try {
      const guid = `${Math.floor(Math.random() * 10000000000)}`
      const reqParam: QQVkeyParam = { 'guid': guid, 'songmid': [songmid], 'songtype': [0], 'uin': '0', 'loginflag': 1, 'platform': '20' }
      const reqData: QQVkeyBody = { 'req_0': { 'module': 'vkey.GetVkeyServer', 'method': 'CgiGetVkey', 'param': reqParam } }
      const formBody = `data=${encodeURIComponent(JSON.stringify(reqData))}`
      const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', { method: http.RequestMethod.POST, header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://y.qq.com/', 'Content-Type': 'application/x-www-form-urlencoded' }, extraData: formBody, connectTimeout: 8000, readTimeout: 8000 })
      if (resp.responseCode !== 200) { Logger.warn(TAG, `tx tryForm: http ${resp.responseCode}`); return null }
      const rawResp: string = resp.result as string
      Logger.info(TAG, `tx tryForm response: ${rawResp.substring(0, 300)}`)
      return TxMusicApi.extractUrl(JSON.parse(rawResp) as Record<string, Object>)
    } catch (e) { Logger.warn(TAG, `tx tryForm error: ${(e as Error)?.message || JSON.stringify(e)}`); return null }
  }

  private static extractUrl(body: Record<string, Object>): string | null {
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
        let prefix: string = server  // sip[0] 已是完整域名前缀如 http://aqqmusic.tc.qq.com/
        if (!prefix.endsWith('/')) {
          prefix += '/'
        }
        if (!prefix.startsWith('http')) {
          prefix = 'https://' + prefix
        }
        let url: string = prefix + purl
        url = url.replace('http://', 'https://')
        Logger.info(TAG, `tx extractUrl: sip[0]=${server}, testfile2g=${testfile2g}, purl=${purl}, finalUrl=${url.substring(0, 150)}`)
        return url
      }
      Logger.warn(TAG, `tx extractUrl: purl empty, midurlinfo[0]=${JSON.stringify(midurlinfo[0])}`)
    } else {
      Logger.warn(TAG, `tx extractUrl: midurlinfo missing or sip missing`)
    }
    return null
  }

  // ===== 歌词 =====
  static async getLyrics(songmid: string): Promise<string> {
    try {
      const url = `https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=${songmid}&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'https://y.qq.com/portal/player.html' }, connectTimeout: 6000, readTimeout: 6000 })
      if (resp.responseCode !== 200 || !resp.result) { return '' }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 0 || !body['lyric']) { return '' }
      return decodeBase64Lyric(body['lyric'] as string)
    } catch (_) { return '' }
  }
}
