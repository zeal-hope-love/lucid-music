/*
 * tx/songList.ets - QQ音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile tx/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem, formatDuration } from 'musicbasic'
import type { SearchResult } from '../types'

const TAG = 'TxMusicApi'

// ===== 歌单列表 =====
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30): Promise<MusichallPlaylistItem[]> {
  try {
    const offset = page * limit
    let url: string
    if (cat) {
      const categoryId = parseInt(cat) || 0
      const dataStr = `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_category_content","param":{"titleid":${categoryId},"caller":"0","category_id":${categoryId},"sin":${offset},"num":${limit}}}}`
      url = `https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${encodeURIComponent(dataStr)}`
    } else {
      const dataStr = `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_playlist_by_tag","param":{"id":5,"sin":${offset},"num":${limit},"order":5,"caller":"0"}}}`
      url = `https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${encodeURIComponent(dataStr)}`
    }
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'Referer': 'https://y.qq.com/', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { Logger.warn(TAG, `tx getPlaylists: HTTP ${resp.responseCode}`); return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const playlist = body.playlist as Record<string, Object>
    if (!playlist) { Logger.warn(TAG, `tx getPlaylists: no playlist data`); return [] }
    const data = playlist.data as Record<string, Object>
    if (!data) { Logger.warn(TAG, `tx getPlaylists: no data`); return [] }
    const vItem = data.v_item as Record<string, Object>[]
    if (!vItem || vItem.length === 0) {
      const list = data.list as Record<string, Object>[]
      if (list && list.length > 0) { return parsePlaylistList(list) }
      Logger.warn(TAG, `tx getPlaylists: no v_item or list`); return []
    }
    const results: MusichallPlaylistItem[] = []
    for (const item of vItem) {
      const basic = item.basic as Record<string, Object>
      if (!basic) continue
      const playlistItem = new MusichallPlaylistItem()
      playlistItem.playlistId = String(basic.tid || '')
      playlistItem.title = (basic.title as string) || ''
      const cover = basic.cover as Record<string, Object>
      const coverUrl = (cover?.medium_url as string) || (cover?.default_url as string) || ''
      playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
      const playCount = basic.play_cnt as number || 0
      playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      results.push(playlistItem)
    }
    Logger.info(TAG, `tx getPlaylists success: count=${results.length}`)
    return results
  } catch (e) {
    Logger.error(TAG, `tx getPlaylists error: ${JSON.stringify(e)}`); return []
  }
}

function parsePlaylistList(list: Record<string, Object>[]): MusichallPlaylistItem[] {
  const results: MusichallPlaylistItem[] = []
  for (const item of list) {
    const playlistItem = new MusichallPlaylistItem()
    playlistItem.playlistId = String(item.dissid || '')
    playlistItem.title = (item.dissname as string) || ''
    const coverUrl = (item.imgurl as string) || ''
    playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
    const playCount = item.listennum as number || 0
    playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
    results.push(playlistItem)
  }
  return results
}

// ===== 歌单分类标签 =====
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const dataStr = `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_all_categories","param":{"caller":"0"}}}`
    const url = `https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${encodeURIComponent(dataStr)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'Referer': 'https://y.qq.com/', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const playlist = body.playlist as Record<string, Object>
    if (!playlist) { return getDefaultPlaylistTags() }
    const data = playlist.data as Record<string, Object>
    if (!data) { return getDefaultPlaylistTags() }
    const categories = data.categories as Record<string, Object>[]
    if (!categories || categories.length === 0) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    for (const category of categories) {
      const group = new TagFilterGroup()
      group.groupName = (category.category_name as string) || ''
      const items = category.items as Record<string, Object>[]
      if (items && items.length > 0) {
        group.tags = items.map(item => {
          const tagItem = new TagFilterItem()
          tagItem.id = String(item.category_id || '')
          tagItem.name = (item.category_name as string) || ''
          return tagItem
        }).filter(tag => tag.id && tag.name)
      }
      if (group.tags && group.tags.length > 0) { groups.push(group) }
    }
    Logger.info(TAG, `tx getPlaylistTags success: groups=${groups.length}`)
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `tx getPlaylistTags error: ${JSON.stringify(e)}`); return getDefaultPlaylistTags()
  }
}

// ===== 歌单内歌曲（新增，对齐 lx songList.getListDetail） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'tx' }
  try {
    const url = `https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0&new_format=1&disstid=${playlistId}&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { Origin: 'https://y.qq.com', Referer: `https://y.qq.com/n/yqq/playsquare/${playlistId}.html` },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['code'] !== 0) { return empty }
    const cdlist = (body['cdlist'] as Record<string, Object>[])?.[0]
    if (!cdlist) { return empty }
    const songlist = cdlist['songlist'] as Record<string, Object>[]
    const list: Array<SearchResultItem> = (songlist || []).map((item: Record<string, Object>) => {
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
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'tx' }
  } catch (e) {
    Logger.error(TAG, `tx getPlaylistSongs error: ${JSON.stringify(e)}`); return empty
  }
}

// 默认标签（兜底数据）
export function getDefaultPlaylistTags(): TagFilterGroup[] {
  const groups: TagFilterGroup[] = []
  const hotGroup = new TagFilterGroup()
  hotGroup.groupName = '热门'
  const hotTags: TagFilterItem[] = []
  let tagItem = new TagFilterItem(); tagItem.id = '5'; tagItem.name = '热门'; hotTags.push(tagItem)
  tagItem = new TagFilterItem(); tagItem.id = '2'; tagItem.name = '最新'; hotTags.push(tagItem)
  hotGroup.tags = hotTags
  groups.push(hotGroup)
  const langGroup = new TagFilterGroup()
  langGroup.groupName = '语种'
  const langTags: TagFilterItem[] = []
  tagItem = new TagFilterItem(); tagItem.id = '3'; tagItem.name = '华语'; langTags.push(tagItem)
  tagItem = new TagFilterItem(); tagItem.id = '4'; tagItem.name = '欧美'; langTags.push(tagItem)
  tagItem = new TagFilterItem(); tagItem.id = '5'; tagItem.name = '日语'; langTags.push(tagItem)
  tagItem = new TagFilterItem(); tagItem.id = '6'; tagItem.name = '韩语'; langTags.push(tagItem)
  langGroup.tags = langTags
  groups.push(langGroup)
  return groups
}
