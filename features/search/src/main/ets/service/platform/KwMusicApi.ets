/*
 * KwMusicApi - 酷我音乐平台 API
 */
import { http } from '@kit.NetworkKit'
import { SearchResultItem } from '../../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { TAG, PlayUrlResult, formatDuration } from '../MusicApiUtils'

export class KwMusicApi {
  // ===== 搜索 =====
  static async search(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const url = `https://search.kuwo.cn/r.s?all=${encodeURIComponent(keyword)}&pn=${page - 1}&rn=${limit}&ft=music&rformat=json&encoding=utf8&client=kt&vipver=1&show_copyright_off=1&newver=1&mobi=1`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'https://kuwo.cn/', 'User-Agent': 'Mozilla/5.0' }, connectTimeout: 10000, readTimeout: 10000 })
      if (resp.responseCode !== 200) { return [] }
      const jsonStr: string = (resp.result as string).replace(/'/g, '"')
      const body: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>
      if (!body || !body['abslist']) { return [] }
      return KwMusicApi.mapList(body['abslist'] as object[])
    } catch (e) { Logger.error(TAG, `kw search error: ${JSON.stringify(e)}`); return [] }
  }

  static mapList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (!Array.isArray(rawList)) { return results }
    for (const item of rawList as Record<string, Object>[]) {
      const result = new SearchResultItem()
      result.title = (item['NAME'] as string) || (item['name'] as string) || ''
      result.singer = (item['ARTIST'] as string) || (item['artist'] as string) || ''
      result.album = (item['ALBUM'] as string) || (item['album'] as string) || ''
      result.songId = (item['MUSICRID'] as string) || (item['musicrid'] as string) || ''
      result.source = 'kw'; result.duration = formatDuration((item['DURATION'] as number) || 0)
      result.coverUrl = (item['ALBUMCOVER'] as string) || (item['WEBPICURL'] as string) || ''
      if (result.coverUrl && !result.coverUrl.startsWith('http')) { result.coverUrl = `https:${result.coverUrl}` }
      result.cover = result.coverUrl
      const kwFormats: string = (item['FORMATS'] as string) || ''
      result.quality = kwFormats.includes('FLAC') || kwFormats.includes('无损') ? 'SQ' : kwFormats.includes('MP3H') || kwFormats.includes('320') ? 'HQ' : '标准'
      result.rawFields = item; results.push(result)
    }
    return results
  }

  // ===== 热搜 =====
  static async hotSearch(): Promise<string[]> {
    try {
      const url = 'http://hotword.kuwo.cn/hotword.s?prod=kwplayer_ar_9.3.0.1&corp=kuwo&newver=2&vipver=9.3.0.1&source=kwplayer_ar_9.3.0.1_40.apk&p2p=1&notrace=0&uid=0&plat=kwplayer_ar&rformat=json&encoding=utf8&tabid=1'
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)' }, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['status'] !== 'ok' || !body['tagvalue']) { return [] }
      return ((body['tagvalue'] as Record<string, Object>[]) || []).map(i => i['key'] as string).filter(Boolean)
    } catch (e) { Logger.error(TAG, `kw hotSearch error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 联想 =====
  static async suggest(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://tips.kuwo.cn/t.s?corp=kuwo&newver=3&p2p=1&notrace=0&c=mbox&w=${encodeURIComponent(keyword)}&encoding=utf8&rformat=json`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'Referer': 'http://www.kuwo.cn/' }, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      const wordItems = body['WORDITEMS'] as Record<string, Object>[]
      if (!wordItems) { return [] }
      return wordItems.map(w => new SuggestionItem(w['RELWORD'] as string || '', SuggestionType.SONG, keyword)).slice(0, 10)
    } catch (e) { Logger.error(TAG, `kw suggest error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 播放URL =====
  static async getPlayUrl(rid: string): Promise<PlayUrlResult> {
    try {
      const id = rid.replace('MUSIC_', '').trim()
      const url = `https://www.kuwo.cn/url?format=mp3&rid=${id}&response=url&type=convert_url3&br=128kmp3`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.kuwo.cn/' }, connectTimeout: 8000, readTimeout: 8000 })
      let playUrl = ''
      if (resp.responseCode === 200) {
        const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
        if (body['code'] === 200 && body['url']) { playUrl = (body['url'] as string) || '' }
      }
      const lyrics = await KwMusicApi.getLyrics(id)
      return { url: playUrl, lyrics: lyrics, cover: '' }
    } catch (e) { Logger.error(TAG, `kw getPlayUrl error: ${JSON.stringify(e)}`); return { url: '', lyrics: '', cover: '' } }
  }

  // ===== 歌词 =====
  static async getLyrics(musicId: string): Promise<string> {
    try {
      const url = `https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=${musicId}`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, connectTimeout: 6000, readTimeout: 6000 })
      if (resp.responseCode !== 200) { return '' }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['status'] !== 200 || !body['data']) { return '' }
      const lrclist = (body['data'] as Record<string, Object>)['lrclist'] as Record<string, Object>[]
      if (!lrclist || lrclist.length === 0) { return '' }
      return lrclist.map(l => `[${(l['time'] as string) || ''}]${(l['lineLyric'] as string) || ''}`).join('\n')
    } catch (_) { return '' }
  }
}
