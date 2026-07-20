/*
 * wy/songList.ets - 网易云歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile wy/songList.js
 */
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem, MusichallPlaylistPage, PlaylistDetailResult, PlaylistMeta } from 'musicbasic'
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
export async function getPlaylists(cat: string = '全部', page: number = 0, limit: number = 30, order?: string): Promise<MusichallPlaylistPage> {
  try {
    Logger.info(TAG, `wy getPlaylists request | cat=${cat} | order=${order}`)
    const body = await weapiRequest('playlist/list', {
      cat: cat || '全部', order: order || 'hot', offset: page * limit, limit: limit, total: true
    })
    if (!body) { Logger.warn(TAG, `getPlaylists failed: body is null`); return new MusichallPlaylistPage() }
    const code = body.code as number
    const playlists = body.playlists as Record<string, Object>[]
    if (code !== 200 || !playlists) { Logger.warn(TAG, `getPlaylists failed: cat=${cat}, page=${page}, code=${code}`); return new MusichallPlaylistPage() }

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
      item.source = 'wy'
      results.push(item)
    }
    Logger.info(TAG, `getPlaylists success: cat=${cat}, page=${page}, count=${results.length}`)
    const pg = new MusichallPlaylistPage()
    pg.items = results
    pg.page = page
    pg.limit = limit
    pg.hasMore = results.length >= limit
    return pg
  } catch (e) {
    Logger.error(TAG, `getPlaylists error: ${JSON.stringify(e)}`)
    return new MusichallPlaylistPage()
  }
}

// ===== 歌单分类标签 =====
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const hotBody = await weapiRequest('playlist/hottags', {})
    const catBody = await weapiRequest('playlist/catalogue', {})
    const groups: TagFilterGroup[] = []
    if (hotBody) {
      const hotTags = hotBody.tags as Record<string, Object>[]
      if (hotBody.code === 200 && hotTags) {
        const hotGroup = new TagFilterGroup()
        hotGroup.groupName = '热门标签'
        hotGroup.tags = hotTags.map(tag => {
          const item = new TagFilterItem()
          const playlistTag = tag.playlistTag as Record<string, Object> | undefined
          // 网易云分类以「分类名」作为 cat（对齐 lx：tag.id === name），故 id 取 name
          item.id = (playlistTag?.name as string) || (tag.name as string) || ''
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

// ===== URL/ID 解析（对齐 lx songList.getListId） =====
const WY_RE_ID = /^.+(?:\?|&)id=(\d+)(?:&.*$|#.*$|$)/
const WY_RE_PLAYLIST = /^.+\/playlist\/(\d+)\/\d+\/.+$/

function parsePlaylistId(rawInput: string): string {
  const id = rawInput.trim()
  if (/^\d+$/.test(id)) { return id }
  if (WY_RE_ID.test(id)) { return id.replace(WY_RE_ID, '$1') }
  if (WY_RE_PLAYLIST.test(id)) { return id.replace(WY_RE_PLAYLIST, '$1') }
  // 非 URL 或无法识别的格式，原样返回让 API 报错
  return id
}

// ===== 歌单内歌曲（对齐 lx songList.getListDetail） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<PlaylistDetailResult> {
  const id = parsePlaylistId(playlistId)
  const info = new PlaylistMeta()
  const empty: PlaylistDetailResult = { list: [], allPage: 1, limit, total: 0, source: 'wy', info }
  try {
    const body = await weapiRequest('v3/playlist/detail', { id: id, n: limit, s: 8 })
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
    const meta = new PlaylistMeta()
    meta.name = (playlist['name'] as string) || ''
    meta.img = ((playlist['coverImgUrl'] as string) || '').replace('http://', 'https://')
    meta.author = ((playlist['creator'] as Record<string, Object>)?.nickname as string) || ''
    meta.desc = (playlist['description'] as string) || ''
    const pc = playlist['playCount'] as number || 0
    meta.playCount = pc >= 10000 ? (pc / 10000).toFixed(1) + '万' : pc.toString()
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'wy', info: meta }
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
