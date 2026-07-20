/*
 * tx/songList.ets - QQ音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile tx/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem, formatDuration, MusichallPlaylistPage, PlaylistMeta, PlaylistDetailResult } from 'musicbasic'
import type { SearchResult } from '../types'

const TAG = 'TxMusicApi'

// ===== 歌单列表 =====
// 对齐 lx-music-mobile tx/songList.js getListUrl/getList（含 module 与正确 param）
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30, order?: string): Promise<MusichallPlaylistPage> {
  try {
    const offset = page * limit
    const sortId = order === 'new' ? 2 : 5
    let dataStr: string
    if (cat) {
      const categoryId = parseInt(cat) || 0
      dataStr = `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_category_content","param":{"titleid":${categoryId},"caller":"0","category_id":${categoryId},"size":${limit},"page":${page},"use_page":1},"module":"playlist.PlayListCategoryServer"}}`
    } else {
      // 无分类：广场推荐，id=10000000
      dataStr = `{"comm":{"cv":1602,"ct":20},"playlist":{"method":"get_playlist_by_tag","param":{"id":10000000,"sin":${offset},"size":${limit},"order":${sortId},"cur_page":${page + 1}},"module":"playlist.PlayListPlazaServer"}}`
    }
    const url = `https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${encodeURIComponent(dataStr)}`
    Logger.info(TAG, `tx getPlaylists request | url=${url}`)
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'Referer': 'https://y.qq.com/', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { Logger.warn(TAG, `tx getPlaylists empty: HTTP ${resp.responseCode} | url=${url}`); return new MusichallPlaylistPage() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const playlist = body.playlist as Record<string, Object>
    if (!playlist) { Logger.warn(TAG, `tx getPlaylists empty: no playlist data | url=${url}`); return new MusichallPlaylistPage() }
    const data = playlist.data as Record<string, Object>
    if (!data) { Logger.warn(TAG, `tx getPlaylists empty: no data | url=${url}`); return new MusichallPlaylistPage() }
    let results: MusichallPlaylistItem[] = []
    if (cat) {
      const content = data.content as Record<string, Object>
      const vItem = (content?.v_item as Record<string, Object>[]) || []
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
        playlistItem.source = 'tx'
        results.push(playlistItem)
      }
    } else {
      const vPlaylist = data.v_playlist as Record<string, Object>[]
      if (vPlaylist && vPlaylist.length > 0) {
        for (const item of vPlaylist) {
          const playlistItem = new MusichallPlaylistItem()
          playlistItem.playlistId = String(item.tid || '')
          playlistItem.title = (item.title as string) || ''
          const coverUrl = (item.cover_url_medium as string) || ''
          playlistItem.coverImage = coverUrl.replace('http://', 'https://') || $r('app.media.ic_avatar1')
          const playCount = item.access_num as number || 0
          playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
          playlistItem.source = 'tx'
          results.push(playlistItem)
        }
      }
    }
    Logger.info(TAG, `tx getPlaylists success: count=${results.length}`)
    const pg = new MusichallPlaylistPage()
    pg.items = results
    pg.page = page
    pg.limit = limit
    pg.hasMore = results.length >= limit
    return pg
  } catch (e) {
    Logger.error(TAG, `tx getPlaylists error: ${JSON.stringify(e)}`); return new MusichallPlaylistPage()
  }
}

// ===== 歌单分类标签 =====
// 对齐 lx-music-mobile tx/songList.js tagsUrl/getTag（module=playlist.PlaylistAllCategoriesServer）
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const dataStr = `{"comm":{"cv":1602,"ct":20},"tags":{"method":"get_all_categories","param":{"qq":""},"module":"playlist.PlaylistAllCategoriesServer"}}`
    const url = `https://u.y.qq.com/cgi-bin/musicu.fcg?loginUin=0&hostUin=0&format=json&inCharset=utf-8&outCharset=utf-8&notice=0&platform=wk_v15.json&needNewCode=0&data=${encodeURIComponent(dataStr)}`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'Referer': 'https://y.qq.com/', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const tags = body.tags as Record<string, Object>
    if (!tags) { return getDefaultPlaylistTags() }
    const data = tags.data as Record<string, Object>
    if (!data) { return getDefaultPlaylistTags() }
    const categories = data.v_group as Record<string, Object>[]
    if (!categories || categories.length === 0) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    for (const category of categories) {
      const group = new TagFilterGroup()
      group.groupName = (category.group_name as string) || ''
      const items = category.v_item as Record<string, Object>[]
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
    Logger.info(TAG, `tx getPlaylistTags success: groups=${groups.length}`)
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `tx getPlaylistTags error: ${JSON.stringify(e)}`); return getDefaultPlaylistTags()
  }
}

// ===== URL/ID 解析（对齐 lx songList.getListId） =====
const TX_RE_PLAYLIST = /\/playlist\/(\d+)/
const TX_RE_ID = /id=(\d+)/

/** 从粘贴的分享文本中提取纯 URL */
function extractUrl(rawText: string): string {
  const trimmed = rawText.trim()
  const m = trimmed.match(/https?:\/\/[^\s]+/)
  if (!m) { return trimmed }
  return m[0].replace(/[）\)。，,，！!？?…/』】]+$/, '')
}

function parsePlaylistId(rawInput: string): string {
  const id = extractUrl(rawInput)
  if (/^\d+$/.test(id)) { return id }
  if (TX_RE_PLAYLIST.test(id)) { return id.match(TX_RE_PLAYLIST)![1] }
  if (TX_RE_ID.test(id)) { return id.match(TX_RE_ID)![1] }
  return id
}

/** 对 tx 短链接：利用 headersReceive 事件捕获重定向，从 Location 提取 ID */
async function resolveTxLink(rawUrl: string): Promise<string | null> {
  let m = rawUrl.match(/\/playlist\/(\d+)/)
  if (m) { return m[1] }
  m = rawUrl.match(/[?&]id=(\d+)/)
  if (m) { return m[1] }
  // HTTP GET + headersReceive 捕获重定向
  try {
    Logger.info(TAG, `resolveTxLink request: ${rawUrl.substring(0, 100)}`)
    const httpReq = http.createHttp()
    let redirectUrl = ''
    httpReq.on('headersReceive', (header: Object) => {
      const hdr = header as Record<string, string>
      Logger.info(TAG, `headersReceive keys: ${Object.keys(header).join(',')}`)
      const loc = hdr['Location'] || hdr['location'] || ''
      if (loc) {
        Logger.info(TAG, `headersReceive Location: ${loc}`)
        redirectUrl = loc
      }
    })
    const resp = await httpReq.request(rawUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36' },
      connectTimeout: 8000, readTimeout: 8000
    })
    Logger.info(TAG, `tx resp keys=${Object.keys(resp).join(',')} code=${resp.responseCode}`)
    Logger.info(TAG, `tx resp.header keys: ${Object.keys(resp.header || {}).join(',')}`)
    if (redirectUrl) {
      const pm = redirectUrl.match(/\/playlist\/(\d+)/)
      if (pm) { return pm[1] }
      const qm = redirectUrl.match(/[?&]id=(\d+)/)
      if (qm) { return qm[1] }
    }
    // 从 HTML 回落
    if (resp.responseCode === 200 && resp.result) {
      const html = resp.result as string
      let match = html.match(/\/playlist\/(\d+)\.html/)
      if (match) { return match[1] }
      match = html.match(/\/n\/\w+\/playlist\/(\d+)/)
      if (match) { return match[1] }
      match = html.match(/\/n2\/m\/share\/details\/taoge\.html\?.*?\bid=(\d+)/)
      if (match) { return match[1] }
      match = html.match(/(?:disstid|dissid)[=:]["' ]?(\d+)/)
      if (match) { return match[1] }
      match = html.match(/playlist[^\d]{0,20}(\d{7,15})/)
      if (match) { return match[1] }
      Logger.warn(TAG, `resolveTxLink no match, resp keys: ${Object.keys(resp).join(',')} header: ${JSON.stringify(resp.header)}`)
    }
    throw new TxPlaylistSongsError(`QQ短链接请先用浏览器打开，复制完整URL(含playlist/数字)后粘贴`)
  } catch (e) {
    if (e instanceof TxPlaylistSongsError) { throw e }
    Logger.error(TAG, `resolveTxLink error: ${JSON.stringify(e)}`)
    throw new TxPlaylistSongsError(`网络请求失败`)
  }
}

// ===== 歌单内歌曲 =====
export class TxPlaylistSongsError extends Error {
  detail: string = ''
  constructor(msg: string) { super(msg); this.detail = msg }
}

export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<PlaylistDetailResult> {
  const rawUrl = extractUrl(playlistId)
  let id = parsePlaylistId(playlistId)
  Logger.info(TAG, `raw=[${playlistId.substring(0, 80)}] rawUrl=[${rawUrl.substring(0, 80)}] id=[${id.substring(0, 80)}]`)
  const emptyMeta = new PlaylistMeta()
  const empty: PlaylistDetailResult = { list: [], allPage: 1, limit, total: 0, source: 'tx', info: emptyMeta }
  try {
    if (id.includes('://')) {
      const resolved = await resolveTxLink(rawUrl)
      if (!resolved) {
        throw new TxPlaylistSongsError(`链接解析失败: ${rawUrl.substring(0, 50)}...`)
      }
      Logger.info(TAG, `resolved ID=${resolved}`)
      id = resolved
    }
    const url = `https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg?type=1&json=1&utf8=1&onlysong=0&new_format=1&disstid=${id}&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq.json&needNewCode=0`
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { Origin: 'https://y.qq.com', Referer: `https://y.qq.com/n/yqq/playsquare/${id}.html` },
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
    const meta = new PlaylistMeta()
    meta.name = (cdlist['dissname'] as string) || ''
    meta.img = (cdlist['logo'] as string) || ''
    meta.author = (cdlist['nickname'] as string) || ''
    meta.desc = (cdlist['desc'] as string) || ''
    const vn = cdlist['visitnum'] as number || 0
    meta.playCount = vn >= 10000 ? (vn / 10000).toFixed(1) + '万' : vn.toString()
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'tx', info: meta }
  } catch (e) {
    if (e instanceof TxPlaylistSongsError) { throw e }
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
