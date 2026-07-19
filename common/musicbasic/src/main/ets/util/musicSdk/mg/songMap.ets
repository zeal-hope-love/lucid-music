/*
 * mg/songMap.ets - 咪咕音乐歌曲对象 → SearchResultItem 通用映射
 * 兼容搜索结果（name/singers/rateFormats）与歌单/榜单（songName/singerName/audioFormats）两种字段形态。
 */
import { SearchResultItem } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { QualityType, QualitySizeType } from '../types'

export function mapMgSong(data: Record<string, Object>): SearchResultItem {
  const result = new SearchResultItem()
  result.title = (data['name'] as string) || (data['songName'] as string) || ''
  const singers = (data['singers'] as Record<string, Object>[]) || (data['singerList'] as Record<string, Object>[]) || []
  result.singer = singers.map(s => s['name'] as string || '').join('/')
  result.album = (data['album'] as string) || (data['albumName'] as string) || ''
  result.songId = String(data['songId'] as string || data['copyrightId'] as string || '')
  result.source = 'mg'
  result.duration = formatDuration((data['duration'] as number) || 0)
  result.coverUrl = getImg(data)
  result.cover = result.coverUrl
  const rateFormats = (data['rateFormats'] as Record<string, Object>[]) ||
    (data['audioFormats'] as Record<string, Object>[]) ||
    (data['newRateFormats'] as Record<string, Object>[]) || []
  const types: Array<QualityType> = []
  const _types: Record<string, QualitySizeType> = {}
  for (const t of rateFormats) {
    const formatType = (t['formatType'] as string) || ''
    const size = String((t['size'] as number) || (t['asize'] as number) || (t['isize'] as number) || '')
    switch (formatType) {
      case 'PQ': types.push({ type: '128k', size }); _types['128k'] = { size }; break
      case 'HQ': types.push({ type: '320k', size }); _types['320k'] = { size }; break
      case 'SQ': types.push({ type: 'flac', size }); _types['flac'] = { size }; break
      case 'ZQ':
      case 'ZQ24': types.push({ type: 'flac24bit', size }); _types['flac24bit'] = { size }; break
    }
  }
  result.types = types
  result._types = _types
  const rf = (data['rateFormats'] as Record<string, Object>[]) || []
  result.quality = rf.length > 0 ? (parseInt((rf[rf.length - 1]['rate'] as string) || '0') >= 4 ? '24bit' : parseInt((rf[rf.length - 1]['rate'] as string) || '0') >= 3 ? 'SQ' : parseInt((rf[rf.length - 1]['rate'] as string) || '0') >= 2 ? 'HQ' : '标准') : '标准'
  result.rawFields = data
  return result
}

function getImg(data: Record<string, Object>): string {
  let img: string = ''
  const imgItems = data['imgItems'] as Record<string, Object>[] | undefined
  if (imgItems && imgItems.length > 0) { img = imgItems[0]['img'] as string || '' }
  if (!img) { img = (data['img3'] as string) || (data['img2'] as string) || (data['img1'] as string) || '' }
  if (img && !/https?:/.test(img)) { img = 'http://d.musicapp.migu.cn' + img }
  return img
}
