/*
 * tx/leaderboard.ets - QQ音乐排行榜
 * 对齐 lx-music-mobile tx/leaderboard.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, BoardListResult, BoardItem } from '../types'

const TAG = 'TxMusicApi'

const boardList: Array<BoardItem> = [
  { id: 'txlxzsb', name: '流行榜', bangid: '4' },
  { id: 'txrgb', name: '热歌榜', bangid: '26' },
  { id: 'txwlhgb', name: '网络榜', bangid: '28' },
  { id: 'txdyb', name: '抖音榜', bangid: '60' },
  { id: 'txndb', name: '内地榜', bangid: '5' },
  { id: 'txxgb', name: '香港榜', bangid: '59' },
  { id: 'txtwb', name: '台湾榜', bangid: '61' },
  { id: 'txoumb', name: '欧美榜', bangid: '3' },
  { id: 'txhgb', name: '韩国榜', bangid: '16' },
  { id: 'txrbb', name: '日本榜', bangid: '17' },
  { id: 'txtybb', name: 'YouTube榜', bangid: '128' },
]

export function getBoards(): BoardListResult {
  return { list: boardList, source: 'tx' }
}

export async function getList(bangid: string, page: number = 1, limit: number = 300): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'tx' }
  try {
    const reqParam: Record<string, Object> = { 'topid': parseInt(bangid), 'num': limit, 'period': '' }
    const reqToplist: Record<string, Object> = { 'module': 'musicToplist.ToplistInfoServer', 'method': 'GetDetail', 'param': reqParam }
    const reqComm: Record<string, Object> = { 'uin': 0, 'format': 'json', 'ct': 20, 'cv': 1859 }
    const reqBody: Record<string, Object> = { 'toplist': reqToplist, 'comm': reqComm }
    const dataStr = JSON.stringify(reqBody)
    const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', {
      method: http.RequestMethod.POST,
      header: { 'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)' },
      extraData: dataStr, connectTimeout: 8000, readTimeout: 8000,
    })
    if (resp.responseCode !== 200) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 0) { return empty }
    const toplist = (body['toplist'] as Record<string, Object>)?.['data'] as Record<string, Object>
    const songInfoList = (toplist?.['songInfoList'] as Record<string, Object>[]) || []
    const list: Array<SearchResultItem> = songInfoList.map((item: Record<string, Object>) => {
      const r = new SearchResultItem()
      r.title = (item['title'] as string) || ''
      const singers = item['singer'] as Record<string, Object>[]
      r.singer = singers ? singers.map(s => s['name'] as string).join('/') : ''
      const album = item['album'] as Record<string, Object>
      r.album = album ? (album['name'] as string) || '' : ''
      r.songId = String((item['id'] as number) || 0)
      r.source = 'tx'
      r.duration = formatDuration((item['interval'] as number) || 0)
      const albumMid = album ? (album['mid'] as string) || '' : ''
      r.coverUrl = albumMid ? `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg` : ''
      r.cover = r.coverUrl
      r.rawFields = item
      if (albumMid) { r.rawFields['albummid'] = albumMid }
      return r
    })
    const total = list.length
    Logger.info(TAG, `tx leaderboard getList: bangid=${bangid}, count=${list.length}`)
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'tx' }
  } catch (e) {
    Logger.error(TAG, `tx leaderboard getList err: ${JSON.stringify(e)}`)
    return empty
  }
}

export function getDetailPageUrl(id: string): string {
  if (id.startsWith('tx__')) id = id.replace('tx__', '')
  return `https://y.qq.com/n/ryqq/toplist/${id}`
}
