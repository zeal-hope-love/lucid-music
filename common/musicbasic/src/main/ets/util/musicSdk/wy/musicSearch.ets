/*
 * wy/musicSearch.ets - 网易云搜索
 * 对齐 lx-music-mobile wy/musicSearch.js，返回 SearchResult 包装。
 */
import { http } from '@kit.NetworkKit'
import { Logger, SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import { eapiRequest, weapiRequest, getSongDetail, extractCoverFromDetail } from './utils/request'
import type { SearchResult, QualityType, QualitySizeType, QualityBuildResult } from '../types'

const TAG = 'WyMusicApi'

// 构建 lx 风格的多音质候选
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

export async function search(keyword: string, page: number, limit: number): Promise<SearchResult> {
  const empty: SearchResult = { list: [], allPage: 1, limit, total: 0, source: 'wy' }
  // 主路径：eapi（含 privilege 音质数据，对齐 lx-music）
  const body = await eapiRequest('/api/search/song/list/page', {
    keyword: keyword, needCorrect: '1', channel: 'typing',
    offset: limit * (page - 1), scene: 'normal', total: page == 1, limit: limit
  })
  if (body && body['code'] === 200 && body['data']) {
    const data = body['data'] as Record<string, Object>
    const results = mapList(data['resources'] as Record<string, Object>[] || [])
    Logger.info(TAG, `wy search eapi: ${results.length} results for "${keyword}"`)
    if (results.length > 0) {
      return { list: results, allPage: Math.ceil((data['totalCount'] as number || results.length) / limit) || 1, limit, total: data['totalCount'] as number || results.length, source: 'wy' }
    }
  }
  // 兜底：legacy
  const results = await searchLegacy(keyword, page, limit)
  Logger.info(TAG, `wy search legacy: ${results.length} results for "${keyword}"`)
  const filled = await fillMissingCovers(results)
  const r: SearchResult = {
    list: filled,
    allPage: empty.allPage,
    limit: empty.limit,
    total: empty.total,
    source: empty.source
  }
  return r
}

async function searchLegacy(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
  try {
    const resp = await http.createHttp().request(
      `https://music.163.com/api/search/get?s=${encodeURIComponent(keyword)}&type=1&offset=${(page - 1) * limit}&limit=${limit}`,
      { method: http.RequestMethod.GET, header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://music.163.com' }, connectTimeout: 10000, readTimeout: 10000 }
    )
    if (resp.responseCode !== 200) { return [] }
    const body = JSON.parse(resp.result as string) as Record<string, Object>
    if (!body || body['code'] !== 200 || !body['result']) { return [] }
    return parseLegacySongs((body['result'] as Record<string, Object>)['songs'] as Record<string, Object>[] || [])
  } catch (e) { Logger.error(TAG, `wy searchLegacy err: ${JSON.stringify(e)}`); return [] }
}

function parseLegacySongs(songs: Record<string, Object>[]): SearchResultItem[] {
  const r: SearchResultItem[] = []
  for (const item of songs) {
    const result = new SearchResultItem()
    result.title = (item['name'] as string) || ''
    const artists = item['artists'] as Record<string, Object>[]
    result.singer = artists ? artists.map(a => a['name'] as string).join('、') : ''
    const album = item['album'] as Record<string, Object>
    const al = item['al'] as Record<string, Object>
    result.album = album ? (album['name'] as string) || '' : (al ? (al['name'] as string) || '' : '')
    result.songId = String((item['id'] as number) || 0)
    result.source = 'wy'
    result.duration = formatDuration(Math.floor(((item['duration'] as number) || 0) / 1000))
    let picUrl = (album ? (album['picUrl'] as string) || '' : '')
    if (!picUrl && al) { picUrl = (al['picUrl'] as string) || '' }
    result.coverUrl = picUrl.replace('http://', 'https://')
    result.cover = result.coverUrl
    const q = buildQualityTypes(item)
    result.types = q.types
    result._types = q._types
    result.quality = resolveQuality(item)
    result.rawFields = item
    r.push(result)
  }
  return r
}

function mapList(resources: Record<string, Object>[]): SearchResultItem[] {
  const r: SearchResultItem[] = []
  if (!Array.isArray(resources)) { return r }
  for (const resource of resources) {
    const baseInfo = resource['baseInfo'] as Record<string, Object>
    if (!baseInfo) { continue }
    const item = baseInfo['simpleSongData'] as Record<string, Object>
    if (!item) { continue }
    const result = new SearchResultItem()
    result.title = (item['name'] as string) || ''
    const artists = item['ar'] as Record<string, Object>[]
    result.singer = artists ? artists.map(a => a['name'] as string).join('、') : ''
    const al = item['al'] as Record<string, Object>
    result.album = al ? (al['name'] as string) || '' : ''
    result.songId = String((item['id'] as number) || 0)
    result.source = 'wy'
    result.duration = formatDuration(Math.floor(((item['dt'] as number) || 0) / 1000))
    const picUrl = al ? (al['picUrl'] as string) || '' : ''
    result.coverUrl = picUrl.replace('http://', 'https://')
    result.cover = result.coverUrl
    const q = buildQualityTypes(item)
    result.types = q.types
    result._types = q._types
    result.quality = resolveQuality(item)
    result.rawFields = item
    r.push(result)
  }
  return r
}

/**
 * 解析网易云歌曲音质
 * 优先使用 privilege.maxBrLevel + maxbr，不可用时 fallback 到 h/m/l 品质子对象的 bitrate
 */
function resolveQuality(item: Record<string, Object>): string {
  const privilege = item['privilege'] as Record<string, Object> | undefined
  const maxBrLevel = privilege ? (privilege['maxBrLevel'] as string) || '' : ''
  const maxbr = privilege ? (privilege['maxbr'] as number) || 0 : 0
  if (maxBrLevel === 'hires') { return '24bit' }
  if (maxbr >= 999000) { return 'SQ' }
  if (maxbr >= 320000) { return 'HQ' }
  if (maxbr === 0 && !maxBrLevel) {
    const hItem = item['h'] as Record<string, Object>
    const mItem = item['m'] as Record<string, Object>
    const lItem = item['l'] as Record<string, Object>
    const hBr = hItem ? (hItem['br'] as number) || 0 : 0
    const mBr = mItem ? (mItem['br'] as number) || 0 : 0
    const lBr = lItem ? (lItem['br'] as number) || 0 : 0
    const bestBr = Math.max(hBr, mBr, lBr)
    if (bestBr >= 999000) { return 'SQ' }
    if (bestBr >= 320000) { return 'HQ' }
    return '标准'
  }
  return '标准'
}

async function fillMissingCovers(results: SearchResultItem[]): Promise<SearchResultItem[]> {
  const need = results.filter(r => !r.coverUrl && r.songId)
  if (need.length === 0) { return results }
  Logger.info(TAG, `fillMissingCovers: ${need.length}/${results.length} songs need covers`)
  const details = await Promise.all(need.map(r => getSongDetail(r.songId).catch(() => null)))
  let filled = 0
  for (let i = 0; i < need.length; i++) {
    const coverUrl = extractCoverFromDetail(details[i])
    if (coverUrl) { need[i].coverUrl = coverUrl; need[i].cover = coverUrl; filled++ }
  }
  Logger.info(TAG, `fillMissingCovers: filled ${filled}/${need.length}`)
  return results
}
