/*
 * mg/songList.ets - 咪咕音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile mg/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem, MusichallPlaylistPage, PlaylistMeta } from 'musicbasic'
import { mapMgSong } from './songMap'
import type { SearchResult, PlaylistDetailResult } from '../types'

const TAG = 'MgMusicApi'

// ===== 歌单列表 =====
// 对齐 lx-music-mobile mg/songList.js getSongListUrl/getList
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30, order?: string): Promise<MusichallPlaylistPage> {
  try {
    let url: string
    if (cat) {
      url = `https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-listbytag/release?pageNumber=${page + 1}&templateVersion=2&tagId=${cat}`
    } else {
      url = `https://app.c.nf.migu.cn/pc/bmw/page-data/playlist-square-recommend/v1.0?templateVersion=2&pageNo=${page + 1}`
    }
    Logger.info(TAG, `mg getPlaylists request | url=${url}`)
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { Logger.warn(TAG, `mg getPlaylists empty: HTTP ${resp.responseCode} | url=${url}`); return new MusichallPlaylistPage() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== '000000') { Logger.warn(TAG, `mg getPlaylists empty: code=${body.code} | raw=${JSON.stringify(body).slice(0, 200)} | url=${url}`); return new MusichallPlaylistPage() }
    const data = body.data as Record<string, Object>
    if (!data) { Logger.warn(TAG, `mg getPlaylists empty: no data | url=${url}`); return new MusichallPlaylistPage() }
    const results: MusichallPlaylistItem[] = []
    const contents = data.contents as Record<string, Object>[]
    if (contents && contents.length > 0) {
      const ids: Set<string> = new Set()
      flattenMgContents(contents, results, ids)
    } else {
      const contentItemList = data.contentItemList as Record<string, Object>[]
      const itemList = (contentItemList && contentItemList[1]?.itemList as Record<string, Object>[]) || []
      for (const item of itemList) {
        const playlistItem = new MusichallPlaylistItem()
        const logEvent = item.logEvent as Record<string, Object>
        playlistItem.playlistId = String((logEvent?.contentId as number) || (item.contentId as number) || '')
        playlistItem.title = (item.title as string) || ''
        const coverUrl = (item.imageUrl as string) || ''
        playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
        playlistItem.source = 'mg'
        results.push(playlistItem)
      }
    }
    Logger.info(TAG, `mg getPlaylists success: count=${results.length}`)
    const pg = new MusichallPlaylistPage()
    pg.items = results
    pg.page = page
    pg.limit = limit
    pg.hasMore = results.length >= limit
    return pg
  } catch (e) {
    Logger.error(TAG, `mg getPlaylists error: ${JSON.stringify(e)}`)
    return new MusichallPlaylistPage()
  }
}

// 递归展平 mg contents（resType==='2021' 为歌单叶子节点）
function flattenMgContents(listData: Record<string, Object>[], list: MusichallPlaylistItem[], ids: Set<string>): void {
  for (const item of listData) {
    const sub = item.contents as Record<string, Object>[]
    if (sub && sub.length > 0) {
      flattenMgContents(sub, list, ids)
    } else if ((item.resType as string) === '2021' && !ids.has(String(item.resId))) {
      ids.add(String(item.resId))
      const playlistItem = new MusichallPlaylistItem()
      playlistItem.playlistId = String(item.resId || '')
      playlistItem.title = (item.txt as string) || ''
      const coverUrl = (item.img as string) || ''
      playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
      playlistItem.source = 'mg'
      list.push(playlistItem)
    }
  }
}

// ===== 歌单分类标签 =====
// 对齐 lx-music-mobile mg/songList.js tagsUrl/filterTagInfo（musiclistplaza-taglist）
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const url = 'https://app.c.nf.migu.cn/pc/v1.0/template/musiclistplaza-taglist/release'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15', 'Referer': 'https://m.music.migu.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== '000000') { return getDefaultPlaylistTags() }
    const data = body.data as Record<string, Object>[]
    if (!data || data.length === 0) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    // 第一个为热门标签
    const hotContent = data[0]?.content as Record<string, Object>[]
    if (hotContent && hotContent.length > 0) {
      const hotGroup = new TagFilterGroup()
      hotGroup.groupName = '热门标签'
      hotGroup.tags = hotContent.map(c => {
        const texts = c.texts as string[]
        const t = new TagFilterItem()
        t.id = texts ? String(texts[1] || '') : ''
        t.name = texts ? (texts[0] as string) || '' : ''
        return t
      }).filter(t => t.id && t.name)
      if (hotGroup.tags.length > 0) { groups.push(hotGroup) }
    }
    // 其余为分类分组
    for (let i = 1; i < data.length; i++) {
      const grp = data[i]
      const header = grp.header as Record<string, Object>
      const content = grp.content as Record<string, Object>[]
      if (content && content.length > 0) {
        const group = new TagFilterGroup()
        group.groupName = (header?.title as string) || ''
        group.tags = content.map(c => {
          const texts = c.texts as string[]
          const t = new TagFilterItem()
          t.id = texts ? String(texts[1] || '') : ''
          t.name = texts ? (texts[0] as string) || '' : ''
          return t
        }).filter(t => t.id && t.name)
        if (group.tags.length > 0) { groups.push(group) }
      }
    }
    Logger.info(TAG, `mg getPlaylistTags success: groups=${groups.length}`)
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `mg getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== URL/ID 解析 =====
function parsePlaylistId(rawInput: string): string {
  const id = rawInput.trim()
  if (/^\d+$/.test(id)) { return id }
  return id
}

// ===== 歌单内歌曲（对齐 lx songList.getListDetailList） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 30): Promise<PlaylistDetailResult> {
  const id = parsePlaylistId(playlistId)
  const emptyMeta = new PlaylistMeta()
  const empty: PlaylistDetailResult = { list: [], allPage: 1, limit, total: 0, source: 'mg', info: emptyMeta }
  try {
    const url = `https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0?pageNo=${page}&pageSize=${limit}&playlistId=${id}`
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
    const meta = new PlaylistMeta()
    meta.name = (data['title'] as string) || ''
    meta.img = (data['imageUrl'] as string) || ''
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'mg', info: meta }
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
