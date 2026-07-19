/*
 * kg/songList.ets - 酷狗音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile kg/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType } from '../types'

const TAG = 'KgMusicApi'

// ===== 歌单列表 =====
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30): Promise<MusichallPlaylistItem[]> {
  try {
    const offset = page * limit
    const url = `https://www.kugou.com/yy/special/index/special.html?is_ajax=1&categoryid=${cat || 0}&page=${page + 1}&pagesize=${limit}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/yy/special/index.html' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) {
      Logger.warn(TAG, `kg getPlaylists: HTTP ${resp.responseCode}`)
      return []
    }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const data = body.data as Record<string, Object>
    if (!data) { return [] }
    const list = data.info as Record<string, Object>[]
    if (!list || list.length === 0) { return [] }
    const results: MusichallPlaylistItem[] = []
    for (const item of list) {
      const playlistItem = new MusichallPlaylistItem()
      playlistItem.playlistId = String(item.specialid || '')
      playlistItem.title = (item.specialname as string) || ''
      const coverUrl = (item.imgurl as string) || ''
      playlistItem.coverImage = coverUrl.replace('/{size}', '/400') || $r('app.media.ic_avatar1')
      const playCount = item.playcount as number || 0
      playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      results.push(playlistItem)
    }
    Logger.info(TAG, `kg getPlaylists success: count=${results.length}`)
    return results
  } catch (e) {
    Logger.error(TAG, `kg getPlaylists error: ${JSON.stringify(e)}`)
    return []
  }
}

// ===== 歌单分类标签 =====
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const url = 'https://www.kugou.com/yy/special/index/getCategory.html?is_ajax=1'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/yy/special/index.html' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const data = body.data as Record<string, Object>
    if (!data) { return getDefaultPlaylistTags() }
    const categories = data.category as Record<string, Object>[]
    if (!categories || categories.length === 0) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    for (const category of categories) {
      const group = new TagFilterGroup()
      group.groupName = (category.categoryname as string) || ''
      const items = category.child as Record<string, Object>[]
      if (items && items.length > 0) {
        group.tags = items.map(item => {
          const tagItem = new TagFilterItem()
          tagItem.id = String(item.categoryid || '')
          tagItem.name = (item.categoryname as string) || ''
          return tagItem
        }).filter(tag => tag.id && tag.name)
      }
      if (group.tags && group.tags.length > 0) { groups.push(group) }
    }
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `kg getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== 歌单内歌曲（新增，对齐 lx songList.getListDetailBySpecialId） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'kg' }
  try {
    const url = `http://www2.kugou.kugou.com/yueku/v9/special/single/${playlistId}-5-9999.html`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return empty }
    const html = resp.result as string
    const match = html.match(/global\.data\s*=\s*(\[[\s\S]+?\]);/)
    if (!match) { Logger.warn(TAG, `kg getPlaylistSongs: no global.data`); return empty }
    const rawList = JSON.parse(match[1]) as Record<string, Object>[]
    const enriched = await getMusicInfos(rawList)
    const list = enriched.map(mapOne)
    const total = list.length
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kg' }
  } catch (e) {
    Logger.error(TAG, `kg getPlaylistSongs error: ${JSON.stringify(e)}`)
    return empty
  }
}

async function getMusicInfos(list: Record<string, Object>[]): Promise<Record<string, Object>[]> {
  const ids = new Set<string>()
  const dedup = list.filter(item => {
    const hash = (item['hash'] as string) || ''
    if (!hash || ids.has(hash)) { return false }
    ids.add(hash)
    return true
  })
  if (dedup.length === 0) { return [] }
  try {
    const body: Record<string, Object> = {
      'area_code': '1', 'show_privilege': 1, 'show_album_info': '1', 'is_publish': '',
      'appid': 1005, 'clientver': 11451, 'mid': '1', 'dfid': '-', 'clienttime': Date.now(),
      'key': 'OIlwieks28dk2k092lksi2UIkp',
      'fields': 'album_info,author_name,audio_info,ori_audio_name,base,songname',
      'data': dedup.map((item): Record<string, Object> => ({ 'hash': item['hash'] as string }))
    }
    const resp = await http.createHttp().request('http://gateway.kugou.com/v2/album_audio/audio', {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'KG-THash': '13a3164', 'KG-RC': '1', 'KG-Fake': '0', 'KG-RF': '00869891',
        'User-Agent': 'Android712-AndroidPhone-11451-376-0-FeeCacheUpdate-wifi',
        'x-router': 'kmr.service.kugou.com'
      },
      extraData: JSON.stringify(body),
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return dedup }
    const rb: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const data = rb['data'] as Record<string, Object>[]
    if (Array.isArray(data) && data.length > 0) { return data.map(d => (d[0] as Record<string, Object>) || d) }
    return dedup
  } catch (_) {
    return dedup
  }
}

function mapOne(item: Record<string, Object>): SearchResultItem {
  const ai = (item['audio_info'] as Record<string, Object>) || item
  const result = new SearchResultItem()
  result.title = (item['songname'] as string) || (ai['songname'] as string) || ''
  result.singer = (item['author_name'] as string) || ''
  const albumInfo = (item['album_info'] as Record<string, Object>) || {}
  result.album = (albumInfo['album_name'] as string) || ''
  result.songId = (ai['hash'] as string) || (item['hash'] as string) || ''
  result.source = 'kg'
  result.duration = formatDuration(Math.floor(((ai['timelength'] as number) || 0) / 1000))
  result.coverUrl = ''
  result.cover = ''
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
  if ((ai['filesize'] as number) > 0) { types.push({ type: '128k', size: '' }); _types['128k'] = { size: '' } }
  if ((ai['filesize_320'] as number) > 0) { types.push({ type: '320k', size: '' }); _types['320k'] = { size: '' } }
  if ((ai['filesize_flac'] as number) > 0) { types.push({ type: 'flac', size: '' }); _types['flac'] = { size: '' } }
  if ((ai['filesize_high'] as number) > 0) { types.push({ type: 'flac24bit', size: '' }); _types['flac24bit'] = { size: '' } }
  result.types = types
  result._types = _types
  result.rawFields = item
  return result
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
    makeTag('0', '全部'),
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
