/*
 * kw/songList.ets - 酷我音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile kw/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem, MusichallPlaylistPage, PlaylistMeta } from 'musicbasic'
import { formatDuration } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType, PlaylistDetailResult } from '../types'

const TAG = 'KwMusicApi'

const MINFO_RE = /level:(\w+),bitrate:(\d+),format:(\w+),size:([\w.]+)/

// 规范化封面 URL：处理协议相对 //、http、空值兜底
function normalizeCover(raw: string): Resource | string {
  let url: string = (raw || '').trim()
  if (!url) { return $r('app.media.ic_avatar1') }
  if (url.startsWith('//')) { url = 'http:' + url }
  // 保持 http 明文下载：酷我图床 img1.kwcdn.kuwo.cn 的 https 证书不被系统信任库认可，强转 https 会触发 SSL 2300060
  return url
}

// 酷我标签 id 采用 `${id}-${digest}`（对齐 lx-music），无 digest 时回退纯 id
function buildKwTagId(d: Record<string, Object>): string {
  const id = String(d.id || '')
  const digest = (d.digest as string) || ''
  return digest ? `${id}-${digest}` : id
}

// ===== 歌单列表 =====
// 对齐 lx-music-mobile kw/songList.js getListUrl/getList
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30, order?: string): Promise<MusichallPlaylistPage> {
  try {
    const sortId = order || 'hot'
    let url: string
    if (cat) {
      const parts = cat.split('-')
      const kwId = parts[0]
      const kwType = parts[1] || ''
      url = `http://wapi.kuwo.cn/api/pc/classify/playlist/getTagPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=${page + 1}&id=${kwId}&type=${kwType}&rn=${limit}`
    } else {
      url = `http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList?loginUid=0&loginSid=0&appUid=76039576&pn=${page + 1}&rn=${limit}&order=${sortId}`
    }
    Logger.info(TAG, `kw getPlaylists request | url=${url}`)
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'http://www.kuwo.cn/playlist' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) {
      Logger.warn(TAG, `kw getPlaylists empty: HTTP ${resp.responseCode} | url=${url}`)
      return new MusichallPlaylistPage()
    }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.code !== 200) {
      Logger.warn(TAG, `kw getPlaylists empty: body.code=${body.code} | raw=${JSON.stringify(body).slice(0, 200)} | url=${url}`)
      return new MusichallPlaylistPage()
    }
    // 无分类：list 在 body.data.data；有分类：body 为数组，list 在 body[].list
    let list: Record<string, Object>[] = []
    if (cat) {
      const arr = body as Object as Record<string, Object>[]
      for (const grp of arr) {
        const gl = grp.list as Record<string, Object>[]
        if (gl && gl.length > 0) { list.push(...gl) }
      }
    } else {
      const data = body.data as Record<string, Object>
      list = (data?.data as Record<string, Object>[]) || []
    }
    if (!list || list.length === 0) {
      Logger.warn(TAG, `kw getPlaylists empty: no list | raw=${JSON.stringify(body).slice(0, 200)} | url=${url}`)
      return new MusichallPlaylistPage()
    }
    const results: MusichallPlaylistItem[] = []
    for (const item of list) {
      const playlistItem = new MusichallPlaylistItem()
      playlistItem.playlistId = String(item.id || '')
      playlistItem.title = (item.name as string) || ''
      const coverUrl = (item.img as string) || ''
      playlistItem.coverImage = normalizeCover(coverUrl)
      const playCount = item.listencnt as number || 0
      playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      playlistItem.source = 'kw'
      results.push(playlistItem)
    }
    if (results.length > 0) {
      Logger.info(TAG, `kw getPlaylists coverSample | id=${results[0].playlistId} | rawImg=${JSON.stringify(list[0]?.img)} | finalCover=${JSON.stringify(results[0].coverImage)}`)
    }
    Logger.info(TAG, `kw getPlaylists success: count=${results.length}`)
    const pg = new MusichallPlaylistPage()
    pg.items = results
    pg.page = page
    pg.limit = limit
    pg.hasMore = results.length >= limit
    return pg
  } catch (e) {
    Logger.error(TAG, `kw getPlaylists error: ${JSON.stringify(e)}`)
    return new MusichallPlaylistPage()
  }
}

// ===== 歌单分类标签 =====
// 对齐 lx-music-mobile kw/songList.js tagsUrl/getTag + hotTagUrl/getHotTag
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const header: Record<string, string> = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'http://www.kuwo.cn/playlist' }
    const tagUrl = 'http://wapi.kuwo.cn/api/pc/classify/playlist/getTagList?cmd=rcm_keyword_playlist&user=0&prod=kwplayer_pc_9.0.5.0&vipver=9.0.5.0&source=kwplayer_pc_9.0.5.0&loginUid=0&loginSid=0&appUid=76039576'
    const hotUrl = 'http://wapi.kuwo.cn/api/pc/classify/playlist/getRcmTagList?loginUid=0&loginSid=0&appUid=76039576'
    const tagHotPromises = await Promise.all([
      http.createHttp().request(tagUrl, { method: http.RequestMethod.GET, header, connectTimeout: 10000, readTimeout: 10000 }),
      http.createHttp().request(hotUrl, { method: http.RequestMethod.GET, header, connectTimeout: 10000, readTimeout: 10000 })
    ])
    const tagResp = tagHotPromises[0]
    const hotResp = tagHotPromises[1]
    const groups: TagFilterGroup[] = []
    // 热门标签
    if (hotResp.responseCode === 200 && hotResp.result) {
      try {
        const hb: Record<string, Object> = JSON.parse(hotResp.result as string) as Record<string, Object>
        if (hb.code === 200) {
          const hdata = hb.data as Record<string, Object>[]
          const hotArr = (hdata && hdata[0]?.data as Record<string, Object>[]) || []
          if (hotArr.length > 0) {
            const hotGroup = new TagFilterGroup()
            hotGroup.groupName = '热门标签'
            hotGroup.tags = hotArr.map(d => {
              const t = new TagFilterItem()
              t.id = buildKwTagId(d)
              t.name = (d.name as string) || ''
              return t
            }).filter(t => t.id && t.name)
            if (hotGroup.tags.length > 0) { groups.push(hotGroup) }
          }
        }
      } catch (_) { /* ignore */ }
    }
    // 分类标签
    if (tagResp.responseCode === 200 && tagResp.result) {
      try {
        const tb: Record<string, Object> = JSON.parse(tagResp.result as string) as Record<string, Object>
        if (tb.code === 200) {
          const tdata = tb.data as Record<string, Object>[]
          if (tdata && tdata.length > 0) {
            for (const type of tdata) {
              const items = type.data as Record<string, Object>[]
              if (items && items.length > 0) {
                const group = new TagFilterGroup()
                group.groupName = (type.name as string) || ''
                group.tags = items.map(d => {
                  const t = new TagFilterItem()
                  t.id = buildKwTagId(d)
                  t.name = (d.name as string) || ''
                  return t
                }).filter(t => t.id && t.name)
                if (group.tags.length > 0) { groups.push(group) }
              }
            }
          }
        }
      } catch (_) { /* ignore */ }
    }
    Logger.info(TAG, `kw getPlaylistTags success: groups=${groups.length}`)
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `kw getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== URL/ID 解析 =====
function parsePlaylistId(rawInput: string): string {
  const id = rawInput.trim()
  if (/^\d+$/.test(id)) { return id }
  return id
}

// ===== 歌单内歌曲（新增，对齐 lx songList.getListDetailDigest8） =====
export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<PlaylistDetailResult> {
  const id = parsePlaylistId(playlistId)
  const emptyMeta = new PlaylistMeta()
  const empty: PlaylistDetailResult = { list: [], allPage: 1, limit, total: 0, source: 'kw', info: emptyMeta }
  try {
    const url = `http://nplserver.kuwo.cn/pl.svc?op=getlistinfo&pid=${id}&pn=${page - 1}&rn=${limit}&encode=utf8&keyset=pl2012&identity=kuwo&pcmp4=1&vipver=MUSIC_9.0.5.0_W1&newver=1`
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
    const meta = new PlaylistMeta()
    meta.name = (body['title'] as string) || ''
    meta.img = (body['pic'] as string) || ''
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kw', info: meta }
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
