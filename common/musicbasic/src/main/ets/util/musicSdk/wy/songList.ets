/*
 * wy/songList.ets - 网易云歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile wy/songList.js
 */
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import { weapiRequest } from './utils/request'
import type { SearchResult, QualityType, QualitySizeType, QualityBuildResult } from '../types'

const TAG = 'WyMusicApi'

function buildQualityTypes(item: Record<string, Object>): QualityBuildResult {
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
  const privilege = item['privilege'] as Record<string, Object> | undefined
  const maxBrLevel = privilege ? (privilege['maxBrLevel'] as string) || '' : ''
  const maxbr = privilege ? (privilege['maxbr'] as number) || 0 : 0
  if (maxBrLevel === 'hires') { types.push({ type: 'flac24bit', size: '' }); _types['flac24bit'] = { size: '' } }
  if (maxbr >= 999000) { types.push({ type: 'flac', size: '' }); _types['flac'] = { size: '' } }
  if (maxbr >= 320000) { types.push({ type: '320k', size: '' }); _types['320k'] = { size: '' } }
  if (maxbr >= 128000) { types.push({ type: '128k', size: '' }); _types['128k'] = { size: '' } }
  return { types, _types }
}

// ===== 歌单列表 =====
export async function getPlaylists(cat: string = '全部', page: number = 0, limit: number = 30): Promise<MusichallPlaylistItem[]> {
  try {
    const body = await weapiRequest('top/playlist', {
      cat: cat, order: 'hot', offset: page * limit, limit: limit, total: true
    })
    if (!body) { Logger.warn(TAG, `getPlaylists failed: body is null`); return [] }
    const code = body.code as number
    const playlists = body.playlists as Record<string, Object>[]
    if (code !== 200 || !playlists) { Logger.warn(TAG, `getPlaylists failed: cat=${cat}, page=${page}, code=${code}`); return [] }

    const results: MusichallPlaylistItem[] = []
    for (const playlist of playlists) {
      const item = new MusichallPlaylistItem()
      item.playlistId = String(playlist.id || '')
      item.title = (playlist.name as string) || ''
      const coverUrl = (playlist.coverImgUrl as string) || ''
      item.coverImage = coverUrl ? coverUrl.replace('http://', 'https://') : $r('app.media.ic_avatar1')
      const playCount = playlist.playCount as number || 0
      item.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      item.tags = (playlist.tags as string[]) || []
      results.push(item)
    }
    Logger.info(TAG, `getPlaylists success: cat=${cat}, page=${page}, count=${results.length}`)
    return results
  } catch (e) {
    Logger.error(TAG, `getPlaylists error: ${JSON.stringify(e)}`)
    return []
  }
}

// ===== 歌单分类标签 =====
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const hotBody = await weapiRequest('playlist/hot', {})
    const catBody = await weapiRequest('playlist/catlist', {})
    const groups: TagFilterGroup[] = []
    if (hotBody) {
      const hotTags = hotBody.tags as Record<string, Object>[]
      if (hotBody.code === 200 && hotTags) {
        const hotGroup = new TagFilterGroup()
        hotGroup.groupName = '热门标签'
        hotGroup.tags = hotTags.map(tag => {
          const item = new TagFilterItem()
          const playlistTag = tag.playlistTag as Record<string, Object> | undefined
          item.id = (playlistTag?.id as string) || (tag.id as string) || ''
          item.name = (playlistTag?.name as string) || (tag.name as string) || ''
          return item
        }).filter(item => item.id && item.name)
        groups.push(hotGroup)
      }
    }
    if (catBody) {
      const subCats = catBody.sub as Record<string, Object>[]
      if (catBody.code === 200 && subCats) {
        const allGroup = new TagFilterGroup()
        allGroup.groupName = '全部分类'
        allGroup.tags = subCats.map(cat => {
          const item = new TagFilterItem()
          item.id = (cat.name as string) || ''
          item.name = (cat.name as string) || ''
          return item
        }).filter(item => item.id && item.name)
        groups.push(allGroup)
      }
    }
    Logger.info(TAG, `getPlaylistTags success: groups=${groups.length}`)
    return groups
  } catch (e) {
    Logger.error(TAG, `getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== 歌单内歌曲（新增，对齐 lx songList.getListDetail） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'wy' }
  try {
    const body = await weapiRequest('v3/playlist/detail', { id: playlistId, n: limit, s: 8 })
    if (!body || body['code'] !== 200 || !body['playlist']) { return empty }
    const playlist = body['playlist'] as Record<string, Object>
    const tracks = (playlist['tracks'] as Record<string, Object>[]) || []
    const list: SearchResultItem[] = tracks.map((item: Record<string, Object>) => {
      const r = new SearchResultItem()
      r.title = (item['name'] as string) || ''
      const ar = item['ar'] as Record<string, Object>[]
      r.singer = ar ? ar.map(a => a['name'] as string).join('、') : ''
      const al = item['al'] as Record<string, Object>
      r.album = al ? (al['name'] as string) || '' : ''
      r.songId = String((item['id'] as number) || 0)
      r.source = 'wy'
      r.duration = formatDuration(Math.floor(((item['dt'] as number) || 0) / 1000))
      const picUrl = al ? (al['picUrl'] as string) || '' : ''
      r.coverUrl = picUrl.replace('http://', 'https://')
      r.cover = r.coverUrl
      const q = buildQualityTypes(item)
      r.types = q.types
      r._types = q._types
      r.rawFields = item
      return r
    })
    const total = (playlist['trackCount'] as number) || list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'wy' }
  } catch (e) {
    Logger.error(TAG, `getPlaylistSongs error: ${JSON.stringify(e)}`)
    return empty
  }
}

// 默认标签（兜底数据）
export function getDefaultPlaylistTags(): TagFilterGroup[] {
  const groups: TagFilterGroup[] = []
  const hotGroup = new TagFilterGroup()
  hotGroup.groupName = '热门标签'
  hotGroup.tags = [
    { id: 'hot', name: '热门' },
    { id: 'style_pop', name: '流行' },
    { id: 'style_rock', name: '摇滚' },
    { id: 'style_electronic', name: '电子' }
  ]
  groups.push(hotGroup)
  const styleGroup = new TagFilterGroup()
  styleGroup.groupName = '风格'
  styleGroup.tags = [
    { id: 'style_chinese', name: '华语' },
    { id: 'style_western', name: '欧美' },
    { id: 'style_jpop', name: '日语' },
    { id: 'style_kpop', name: '韩语' },
    { id: 'style_light', name: '轻音乐' },
    { id: 'style_soundtrack', name: '影视原声' }
  ]
  groups.push(styleGroup)
  const moodGroup = new TagFilterGroup()
  moodGroup.groupName = '心情'
  moodGroup.tags = [
    { id: 'mood_relax', name: '放松' },
    { id: 'mood_hot', name: '激情' },
    { id: 'mood_sad', name: '伤感' },
    { id: 'mood_happy', name: '快乐' }
  ]
  groups.push(moodGroup)
  return groups
}
