/*
 * MgMusicApi - 咪咕音乐平台 API
 */
import { http } from '@kit.NetworkKit'
import { SearchResultItem } from '../../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { TAG, PlayUrlResult, formatDuration } from '../MusicApiUtils'

export class MgMusicApi {
  // ===== 搜索 =====
  static async search(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const ss = '%7B%22song%22%3A1%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A0%2C%22mvSong%22%3A0%2C%22songlist%22%3A0%2C%22bestShow%22%3A0%7D'
      const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/search_all.do?isCopyright=1&isCorrect=1&pageNo=${page}&pageSize=${limit}&searchSwitch=${ss}&sort=0&text=${encodeURIComponent(keyword)}`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://m.music.migu.cn/' }, connectTimeout: 10000, readTimeout: 10000 })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      let resultList: object[] = []
      if (body['resultList']) { resultList = body['resultList'] as object[] }
      else if (body['songResultData']) { resultList = (body['songResultData'] as Record<string, Object>)['resultList'] as object[] || [] }
      return MgMusicApi.mapList(resultList)
    } catch (e) { Logger.error(TAG, `mg search error: ${JSON.stringify(e)}`); return [] }
  }

  static mapList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []; const seen = new Set<string>()
    if (!Array.isArray(rawList)) { return results }
    for (const item of rawList) {
      if (Array.isArray(item)) { for (const inner of item as object[]) { MgMusicApi.mapOne(inner as Record<string, Object>, seen, results) } }
      else { MgMusicApi.mapOne(item as Record<string, Object>, seen, results) }
    }
    return results
  }

  private static mapOne(data: Record<string, Object>, seen: Set<string>, results: SearchResultItem[]): void {
    const dedupKey: string = (data['copyrightId'] as string) || (data['id'] as string) || ''
    if (!dedupKey || seen.has(dedupKey)) { return }
    seen.add(dedupKey)
    const result = new SearchResultItem()
    result.title = (data['name'] as string) || ''
    const singers = (data['singers'] as Record<string, Object>[]) || (data['singerList'] as Record<string, Object>[]) || []
    result.singer = singers.map(s => s['name'] as string || '').join('/')
    result.album = (data['album'] as string) || (((data['albums'] as Record<string, Object>[])?.length ?? 0) > 0 ? (data['albums'] as Record<string, Object>[])[0]['name'] as string || '' : '')
    result.songId = String(data['songId'] as string || data['copyrightId'] as string || '')
    result.source = 'mg'; result.duration = formatDuration((data['duration'] as number) || 0)
    let img: string = ''
    const imgItems = data['imgItems'] as Record<string, Object>[]
    if (imgItems && imgItems.length > 0) { img = imgItems[0]['img'] as string || '' }
    if (!img) { img = (data['img3'] as string) || (data['img2'] as string) || (data['img1'] as string) || '' }
    if (img && !/https?:/.test(img)) { img = 'http://d.musicapp.migu.cn' + img }
    result.coverUrl = img; result.cover = result.coverUrl
    const rateFormats: string = (data['rateFormats'] as string) || ''
    const formatList: string[] = rateFormats ? rateFormats.split(',').filter(Boolean) : []
    result.quality = formatList.length > 0 ? (parseInt(formatList[formatList.length - 1] as string) >= 4 ? '24bit' : parseInt(formatList[formatList.length - 1] as string) >= 3 ? 'SQ' : parseInt(formatList[formatList.length - 1] as string) >= 2 ? 'HQ' : '标准') : '标准'
    result.rawFields = data; results.push(result)
  }

  // ===== 热搜 =====
  static async hotSearch(): Promise<string[]> {
    try {
      const url = 'http://jadeite.migu.cn:7090/music_search/v3/search/hotword'
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== '000000' || !body['data']) { return [] }
      const hotwords = (body['data'] as Record<string, Object>)['hotwords'] as Record<string, Object>[]
      if (!hotwords || hotwords.length === 0) { return [] }
      const hotwordList = hotwords[0]['hotwordList'] as Record<string, Object>[]
      return hotwordList ? hotwordList.filter(h => h['resourceType'] === 'song').map(h => h['word'] as string).filter(Boolean) : []
    } catch (e) { Logger.error(TAG, `mg hotSearch error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 联想 =====
  static async suggest(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://music.migu.cn/v3/api/search/suggest?keyword=${encodeURIComponent(keyword)}`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'referer': 'https://music.migu.cn/v3' }, connectTimeout: 5000, readTimeout: 5000 })
      if (resp.responseCode !== 200) { return [] }
      const songs = (JSON.parse(resp.result as string) as Record<string, Object>)['songs'] as Record<string, Object>[]
      return songs ? songs.map(s => new SuggestionItem(s['name'] as string || '', SuggestionType.SONG, keyword)).slice(0, 10) : []
    } catch (e) { Logger.error(TAG, `mg suggest error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 播放URL =====
  static async getPlayUrl(copyrightId: string, rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    try {
      const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/resourceinfo.do?copyrightId=${copyrightId}&resourceType=2`
      const resp = await http.createHttp().request(url, { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://m.music.migu.cn/' }, connectTimeout: 8000, readTimeout: 8000 })
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
    } catch (e) { Logger.error(TAG, `mg getPlayUrl error: ${JSON.stringify(e)}`); return { url: '', lyrics: '', cover: '' } }
  }
}
