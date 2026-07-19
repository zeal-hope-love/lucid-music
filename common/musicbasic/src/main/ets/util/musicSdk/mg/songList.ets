/*
 * mg/songList.ets - 咪咕音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile mg/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem } from 'musicbasic'
import { mapMgSong } from './songMap'
import type { SearchResult } from '../types'

const TAG = 'MgMusicApi'

// ===== 歌单列表 =====
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30): Promise<MusichallPlaylistItem[]> {
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/template/playlistlistbytaglimit.do?tagId=${cat || '100000000'}&start=${page * limit}&size=${limit}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== '000000') { return [] }
    const data = body.data as Record<string, Object>
    if (!data) { return [] }
    const list = data.contentItemList as Record<string, Object>[]
    if (!list || list.length === 0) { return [] }
    const results: MusichallPlaylistItem[] = []
    for (const item of list) {
      const playlistItem = new MusichallPlaylistItem()
      const idInfo = item.idInfo as Record<string, Object>
      playlistItem.playlistId = String(idInfo?.id || '')
      playlistItem.title = (item.title as string) || ''
      const imgItem = item.imgItem as Record<string, Object>
      const coverUrl = (imgItem?.img as string) || ''
      playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
      const opNum = item.opNumItem as Record<string, Object>
      const playCount = (opNum?.playNum as number) || 0
      playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      results.push(playlistItem)
    }
    Logger.info(TAG, `mg getPlaylists success: count=${results.length}`)
    return results
  } catch (e) {
    Logger.error(TAG, `mg getPlaylists error: ${JSON.stringify(e)}`)
    return []
  }
}

// ===== 歌单分类标签 =====
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const url = 'https://app.c.nf.migu.cn/MIGUM2.0/v1.0/template/playlisttaglist.do'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== '000000') { return getDefaultPlaylistTags() }
    const data = body.data as Record<string, Object>
    if (!data) { return getDefaultPlaylistTags() }
    const tags = data.tagList as Record<string, Object>[]
    if (!tags || tags.length === 0) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    for (const tag of tags) {
      const group = new TagFilterGroup()
      group.groupName = (tag.tagName as string) || ''
      const items = tag.subTagList as Record<string, Object>[]
      if (items && items.length > 0) {
        group.tags = items.map(item => {
          const tagItem = new TagFilterItem()
          tagItem.id = String(item.tagId || '')
          tagItem.name = (item.tagName as string) || ''
          return tagItem
        }).filter(tag => tag.id && tag.name)
      }
      if (group.tags && group.tags.length > 0) { groups.push(group) }
    }
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `mg getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== 歌单内歌曲（新增，对齐 lx songList.getListDetailList） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 30): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'mg' }
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=${page}&pageSize=${limit}&playlistId=${playlistId}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== '000000') { Logger.warn(TAG, `mg getPlaylistSongs: code=${body.code}`); return empty }
    const data = body.data as Record<string, Object>
    const songList = (data['songList'] as Record<string, Object>[]) || []
    const list = songList.map(s => mapMgSong(s))
    const total = (data['totalCount'] as number) || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'mg' }
  } catch (e) {
    Logger.error(TAG, `mg getPlaylistSongs error: ${JSON.stringify(e)}`)
    return empty
  }
}

// 构造标签项（规避 Object.assign 在 ArkTS 的限制）
function makeTag(id: string, name: string): TagFilterItem {
  const t = new TagFilterItem()
  t.id = id
  t.name = name
  return t
}

// 默认标签（兜底数据）
export function getDefaultPlaylistTags(): TagFilterGroup[] {
  const groups: TagFilterGroup[] = []
  const hotGroup = new TagFilterGroup()
  hotGroup.groupName = '热门'
  hotGroup.tags = [
    makeTag('100000000', '全部'),
    makeTag('100000001', '推荐'),
    makeTag('100000002', '最新')
  ]
  groups.push(hotGroup)
  const langGroup = new TagFilterGroup()
  langGroup.groupName = '语种'
  langGroup.tags = [
    makeTag('100000003', '华语'),
    makeTag('100000004', '欧美'),
    makeTag('100000005', '日语'),
    makeTag('100000006', '韩语')
  ]
  groups.push(langGroup)
  return groups
}
