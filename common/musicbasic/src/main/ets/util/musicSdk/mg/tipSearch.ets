/*
 * mg/tipSearch.ets - 咪咕音乐智能提示
 * 对齐 lx-music-mobile mg/tipSearch.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SuggestionItem, SuggestionType } from 'musicbasic'

const TAG = 'MgMusicApi'

// 原联想接口（music.migu.cn/v3/api/search/suggest）
export async function suggest(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const url = `https://music.migu.cn/v3/api/search/suggest?keyword=${encodeURIComponent(keyword)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'referer': 'https://music.migu.cn/v3' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { return [] }
    const songs = (JSON.parse(resp.result as string) as Record<string, Object>)['songs'] as Record<string, Object>[]
    return songs ? songs.map(s => new SuggestionItem(s['name'] as string || '', SuggestionType.SONG, keyword)).slice(0, 10) : []
  } catch (e) {
    Logger.error(TAG, `mg suggest error: ${JSON.stringify(e)}`)
    return []
  }
}

// 智能提示（与 suggest 同源，返回 "歌名 - 歌手" 形式）
export async function getTipSearch(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const url = `https://music.migu.cn/v3/api/search/suggest?keyword=${encodeURIComponent(keyword)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'referer': 'https://music.migu.cn/v3' },
      connectTimeout: 5000, readTimeout: 5000
    })
    if (resp.responseCode !== 200) { return [] }
    const songs = (JSON.parse(resp.result as string) as Record<string, Object>)['songs'] as Record<string, Object>[]
    if (!songs) { return [] }
    return songs.map(s => {
      const name = (s['name'] as string) || ''
      const singer = (s['singerName'] as string) || ''
      return new SuggestionItem(singer ? `${name} - ${singer}` : name, SuggestionType.SONG, keyword)
    }).slice(0, 10)
  } catch (e) {
    Logger.error(TAG, `mg getTipSearch error: ${JSON.stringify(e)}`)
    return []
  }
}
