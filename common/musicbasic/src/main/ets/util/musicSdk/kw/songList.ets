/*
 * kw/songList.ets - 酷我音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile kw/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType } from '../types'

const TAG = 'KwMusicApi'

const MINFO_RE = /level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)/

// ===== 歌单列表 =====
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30): Promise<MusichallPlaylistItem[]> {
  try {
    const url = `http://www.kuwo.cn/api/pc/classify/playlist/get?pn=${page + 1}&rn=${limit}&order=hot&cid=${cat || ''}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'http://www.kuwo.cn/playlist' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return [] }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== 200) { return [] }
    const data = body.data as Record<string, Object>
    if (!data) { return [] }
    const list = data.list as Record<string, Object>[]
    if (!list || list.length === 0) { return [] }
    const results: MusichallPlaylistItem[] = []
    for (const item of list) {
      const playlistItem = new MusichallPlaylistItem()
      playlistItem.playlistId = String(item.id || '')
      playlistItem.title = (item.name as string) || ''
      const coverUrl = (item.img as string) || ''
      playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
      const playCount = item.playcnt as number || 0
      playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      results.push(playlistItem)
    }
    Logger.info(TAG, `kw getPlaylists success: count=${results.length}`)
    return results
  } catch (e) {
    Logger.error(TAG, `kw getPlaylists error: ${JSON.stringify(e)}`)
    return []
  }
}

// ===== 歌单分类标签 =====
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const url = 'http://www.kuwo.cn/api/pc/classify/classifyInfo'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'http://www.kuwo.cn/playlist' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== 200) { return getDefaultPlaylistTags() }
    const data = body.data as Record<string, Object>
    if (!data) { return getDefaultPlaylistTags() }
    const categories = data.classifyInfo as Record<string, Object>[]
    if (!categories || categories.length === 0) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    for (const category of categories) {
      const group = new TagFilterGroup()
      group.groupName = (category.name as string) || ''
      const items = category.child as Record<string, Object>[]
      if (items && items.length > 0) {
        group.tags = items.map(item => {
          const tagItem = new TagFilterItem()
          tagItem.id = String(item.id || '')
          tagItem.name = (item.name as string) || ''
          return tagItem
        }).filter(tag => tag.id && tag.name)
      }
      if (group.tags && group.tags.length > 0) { groups.push(group) }
    }
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `kw getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== 歌单内歌曲（新增，对齐 lx songList.getListDetailDigest8） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'kw' }
  try {
    const url = `http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=${playlistId}&pn=${page - 1}&rn=${limit}&encode=utf8&keyset=pl2012&identity=kuwo&pcmp4=1&vipver=MUSIC_9.0.5.0_W1&newver=1`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'http://www.kuwo.cn/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return empty }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body['result'] !== 'ok') { Logger.warn(TAG, `kw getPlaylistSongs: result=${body['result']}`); return empty }
    const musiclist = (body['musiclist'] as Record<string, Object>[]) || []
    const list = filterListDetail(musiclist)
    const total = (body['total'] as number) || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kw' }
  } catch (e) {
    Logger.error(TAG, `kw getPlaylistSongs error: ${JSON.stringify(e)}`)
    return empty
  }
}

function filterListDetail(rawList: Record<string, Object>[]): Array<SearchResultItem> {
  return rawList.map((item: Record<string, Object>) => {
    const result = new SearchResultItem()
    result.title = (item['name'] as string) || ''
    result.singer = (item['artist'] as string) || ''
    result.album = (item['album'] as string) || ''
    result.songId = (item['id'] as string) || ''
    result.source = 'kw'
    result.duration = formatDuration(parseInt((item['duration'] as string) || '0'))
    result.coverUrl = (item['pic'] as string) || ''
    if (result.coverUrl && !result.coverUrl.startsWith('http')) { result.coverUrl = `https:${result.coverUrl}` }
    result.cover = result.coverUrl
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
    const nMinfo: string = (item['N_MINFO'] as string) || ''
    if (nMinfo) {
      for (const seg of nMinfo.split(';')) {
        const m = seg.match(MINFO_RE)
        if (!m) { continue }
        const bitrate = m[2]
        const size = m[4].toUpperCase()
        switch (bitrate) {
          case '4000': types.push({ type: 'flac24bit', size }); _types['flac24bit'] = { size }; break
          case '2000': types.push({ type: 'flac', size }); _types['flac'] = { size }; break
          case '320': types.push({ type: '320k', size }); _types['320k'] = { size }; break
          case '128': types.push({ type: '128k', size }); _types['128k'] = { size }; break
        }
      }
    }
    result.types = types
    result._types = _types
    result.rawFields = item
    return result
  })
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
    makeTag('', '全部'),
    makeTag('1', '推荐'),
    makeTag('2', '最新')
  ]
  groups.push(hotGroup)
  const langGroup = new TagFilterGroup()
  langGroup.groupName = '语种'
  langGroup.tags = [
    makeTag('3', '华语'),
    makeTag('4', '欧美'),
    makeTag('5', '日语'),
    makeTag('6', '韩语')
  ]
  groups.push(langGroup)
  return groups
}
