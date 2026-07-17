/*
 * WyMusicApi - 网易云音乐平台 API（仅未加密端点）
 */
import { http } from '@kit.NetworkKit'
import { SearchResultItem } from '../../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../../model/SuggestionItem'
import { Logger } from 'musicbasic'
import { TAG, PlayUrlResult, formatDuration } from '../MusicApiUtils'

export class WyMusicApi {
  // ===== 搜索 =====
  static async search(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const url = `https://music.163.com/api/search/get?s=${encodeURIComponent(keyword)}&type=1&offset=${(page - 1) * limit}&limit=${limit}`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' },
        connectTimeout: 10000, readTimeout: 10000
      })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== 200 || !body['result']) { return [] }
      const songs = (body['result'] as Record<string, Object>)['songs'] as Record<string, Object>[]
      return WyMusicApi.parseSongs(songs || [])
    } catch (e) { Logger.error(TAG, `wy search error: ${JSON.stringify(e)}`); return [] }
  }

  private static parseSongs(songs: Record<string, Object>[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
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
      result.quality = maxBrLevel === 'hires' ? '24bit' : maxbr >= 999000 ? 'SQ' : maxbr >= 320000 ? 'HQ' : '标准'
      result.rawFields = item
      results.push(result)
    }
    Logger.info(TAG, `wy search: ${results.length} results`)
    return results
  }

  // ===== 热搜 =====
  static async hotSearch(): Promise<string[]> {
    return []  // 加密 API 不可用，由 SearchViewModel 默认兜底链处理
  }

  // ===== 联想 =====
  static async suggest(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://music.163.com/api/search/suggest/web?csrf_token=&s=${encodeURIComponent(keyword)}&type=1`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://music.163.com' },
        connectTimeout: 5000, readTimeout: 5000
      })
      if (resp.responseCode !== 200) { return [] }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 200 || !body['result']) { return [] }
      const result = body['result'] as Record<string, Object>
      const songs = result['songs'] as Record<string, Object>[]
      const items: SuggestionItem[] = []
      if (songs) { for (const s of songs.slice(0, 5)) { if (s['name']) { items.push(new SuggestionItem(s['name'] as string, SuggestionType.SONG, keyword)) } } }
      return items.slice(0, 10)
    } catch (e) { Logger.error(TAG, `wy suggest error: ${JSON.stringify(e)}`); return [] }
  }

  // ===== 播放URL =====
  static async getPlayUrl(songId: string): Promise<PlayUrlResult> {
    const empty: PlayUrlResult = { url: '', lyrics: '', cover: '' }
    try {
      const url = `https://music.163.com/api/song/enhance/player/url?id=${songId}&ids=[${songId}]&br=320000`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' },
        connectTimeout: 8000, readTimeout: 8000
      })
      let playUrl = ''
      if (resp.responseCode === 200) {
        const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
        if (body['code'] === 200 && body['data']) {
          const data = body['data'] as Record<string, Object>[]
          if (data.length > 0) { playUrl = (data[0]['url'] as string) || '' }
        }
      }
      const lyrics = await WyMusicApi.getLyrics(songId).catch(() => '')
      Logger.info(TAG, `wy getPlayUrl: songId=${songId}, playUrlLen=${playUrl.length}, lyricsLen=${lyrics.length}`)
      return { url: playUrl, lyrics: lyrics, cover: '' }
    } catch (e) { Logger.error(TAG, `wy getPlayUrl error: ${JSON.stringify(e)}`); return empty }
  }

  // ===== 歌词 =====
  static async getLyrics(songId: string): Promise<string> {
    try {
      const url = `https://music.163.com/api/song/lyric?id=${songId}&lv=1&kv=1&tv=-1`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' },
        connectTimeout: 6000, readTimeout: 6000
      })
      if (resp.responseCode !== 200) { return '' }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 200) { return '' }
      const lrc = body['lrc'] as Record<string, Object>
      return lrc ? (lrc['lyric'] as string) || '' : ''
    } catch (_) { return '' }
  }
}
