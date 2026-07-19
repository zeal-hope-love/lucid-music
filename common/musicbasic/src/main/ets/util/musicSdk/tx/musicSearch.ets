/*
 * tx/musicSearch.ets - QQ音乐搜索
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration, zzcSign, QQSearchBody } from './utils/crypto'
import type { SearchResult } from '../types'

const TAG = 'TxMusicApi'

export async function search(keyword: string, page: number, limit: number): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'tx' }
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
    if (resp.responseCode !== 200) { Logger.warn(TAG, `tx search http err: ${resp.responseCode}`); return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (!body || body['code'] !== 0 || !body['req']) { Logger.warn(TAG, `tx search body err: code=${body?.['code']}`); return empty }
    const req = body['req'] as Record<string, Object>
    if (req['code'] !== 0 || !req['data']) { Logger.warn(TAG, `tx search req err: code=${req['code']}`); return empty }
    const data = req['data'] as Record<string, Object>
    const songs: Record<string, Object>[] = (data['body'] as Record<string, Object>)?.['item_song'] as Record<string, Object>[]
    const list = songs ? mapList(songs) : []
    const total = (data['meta'] as Record<string, Object>)?.[`num_${page}`] as number || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'tx' }
  } catch (e) { Logger.error(TAG, `tx search error: ${JSON.stringify(e)}`); return empty }
}

function mapList(rawList: Array<Record<string, Object>>): Array<SearchResultItem> {
  const results: Array<SearchResultItem> = []
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
    if (albumMid) {
      result.coverUrl = `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg`
    } else if (singers && singers.length > 0) {
      const singerMid = singers[0]['mid'] as string
      if (singerMid) { result.coverUrl = `https://y.gtimg.cn/music/photo_new/T001R500x500M000${singerMid}.jpg` }
    }
    result.cover = result.coverUrl
    if ((file['size_hires'] as number) > 0) { result.quality = '24bit' }
    else if ((file['size_flac'] as number) > 0) { result.quality = 'SQ' }
    else if ((file['size_320mp3'] as number) > 0) { result.quality = 'HQ' }
    else { result.quality = '标准' }
    result.rawFields = item
    result.rawFields['songmid'] = result.songId
    if (albumMid) { result.rawFields['albummid'] = albumMid }
    results.push(result)
  }
  return results
}
