/*
 * wy/tipSearch.ets - 网易云智能提示
 * 对齐 lx-music-mobile wy/tipSearch.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SuggestionItem, SuggestionType } from 'musicbasic'
import { weapiRequest } from './utils/request'

const TAG = 'WyMusicApi'

// 原联想接口（api/search/suggest/web）
export async function suggest(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const resp = await http.createHttp().request(
      `https://music.163.com/api/search/suggest/web?csrf_token=&s=${encodeURIComponent(keyword)}&type=1`,
      { method: http.RequestMethod.GET, header: { 'Referer': 'https://music.163.com' }, connectTimeout: 5000, readTimeout: 5000 }
    )
    if (resp.responseCode !== 200) { return [] }
    const body = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 200 || !body['result']) { return [] }
    const songs = (body['result'] as Record<string, Object>)['songs'] as Record<string, Object>[]
    const items: Array<SuggestionItem> = []
    if (songs) {
      for (const s of songs.slice(0, 5)) {
        if (s['name']) { items.push(new SuggestionItem(s['name'] as string, SuggestionType.SONG, keyword)) }
      }
    }
    return items.slice(0, 10)
  } catch (e) { Logger.error(TAG, `wy suggest err: ${JSON.stringify(e)}`); return [] }
}

export async function getTipSearch(keyword: string): Promise<Array<SuggestionItem>> {
  try {
    const body = await weapiRequest('search/suggest/web', { s: keyword })
    if (!body || body['code'] !== 200 || !body['result']) { return [] }
    const songs = (body['result'] as Record<string, Object>)['songs'] as Record<string, Object>[]
    if (!songs) { return [] }
    return songs.slice(0, 10).map((info: Record<string, Object>) => {
      const artists = info['artists'] as Record<string, Object>[]
      const singer = artists ? artists.map(a => a['name'] as string).join('、') : ''
      const name = (info['name'] as string) || ''
      return new SuggestionItem(`${name} - ${singer}`, SuggestionType.SONG, keyword)
    })
  } catch (e) {
    Logger.error(TAG, `wy getTipSearch err: ${JSON.stringify(e)}`)
    return []
  }
}
