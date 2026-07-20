/*
 * kg/songList.ets - 酷狗音乐歌单：列表 / 标签 / 歌单内歌曲
 * 对齐 lx-music-mobile kg/songList.js
 */
import { http } from '@kit.NetworkKit'
import { Logger, MusichallPlaylistItem, TagFilterGroup, TagFilterItem, SearchResultItem, MusichallPlaylistPage, PlaylistMeta } from 'musicbasic'
import { formatDuration, signatureParams } from './utils/crypto'
import type { SearchResult, QualityType, QualitySizeType, PlaylistDetailResult } from '../types'

const TAG = 'KgMusicApi'

// ===== 歌单列表 =====
// 对齐 lx-music-mobile kg/songList.js getSongListUrl/getSongList
export async function getPlaylists(cat: string = '', page: number = 0, limit: number = 30, order?: string): Promise<MusichallPlaylistPage> {
  try {
    let sortId = '5' // 推荐
    if (order === 'hot') { sortId = '6' } // 最热
    else if (order === 'new') { sortId = '7' } // 最新
    const kgHeader: Record<string, string> = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/yy/special/index.html' }
    const url = `http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_ajax=1&cdn=cdn&t=${sortId}&c=${cat || ''}&p=${page + 1}&pagesize=${limit}`
    // 信息端点（对齐 lx getListInfo）：取 params.total/pagesize 精确计算 hasMore
    const infoUrl = cat
      ? `http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&cdn=cdn&t=5&c=${cat}`
      : 'http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&'
    Logger.info(TAG, `kg getPlaylists request | url=${url}`)
    const respPromises = await Promise.all([
      http.createHttp().request(url, { method: http.RequestMethod.GET, header: kgHeader, connectTimeout: 10000, readTimeout: 10000 }),
      http.createHttp().request(infoUrl, { method: http.RequestMethod.GET, header: kgHeader, connectTimeout: 10000, readTimeout: 10000 })
    ])
    const resp = respPromises[0]
    const infoResp = respPromises[1]
    if (resp.responseCode !== 200 || !resp.result) {
      Logger.warn(TAG, `kg getPlaylists empty: HTTP ${resp.responseCode} | url=${url}`)
      return new MusichallPlaylistPage()
    }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.status !== 1) {
      Logger.warn(TAG, `kg getPlaylists empty: status=${body.status} | raw=${JSON.stringify(body).slice(0, 200)} | url=${url}`)
      return new MusichallPlaylistPage()
    }
    const list = body.special_db as Record<string, Object>[]
    if (!list || list.length === 0) {
      Logger.warn(TAG, `kg getPlaylists empty: no special_db | raw=${JSON.stringify(body).slice(0, 200)} | url=${url}`)
      return new MusichallPlaylistPage()
    }
    const results: MusichallPlaylistItem[] = []
    for (const item of list) {
      const playlistItem = new MusichallPlaylistItem()
      playlistItem.playlistId = String(item.specialid || '')
      playlistItem.title = (item.specialname as string) || ''
      const coverUrl = ((item.img as string) || (item.imgurl as string)) || ''
      playlistItem.coverImage = coverUrl.replace('/{size}', '/400') || $r('app.media.ic_avatar1')
      const playCount = (item.total_play_count as number) || (item.play_count as number) || 0
      playlistItem.playCount = playCount >= 10000 ? (playCount / 10000).toFixed(1) + '万' : playCount.toString()
      playlistItem.source = 'kg'
      results.push(playlistItem)
    }
    Logger.info(TAG, `kg getPlaylists success: count=${results.length}`)
    const pg = new MusichallPlaylistPage()
    pg.items = results
    pg.page = page
    pg.limit = limit
    // 默认按「本页数满则可能有更多」，再用信息端点 total/pagesize 精确校正
    let hasMore = results.length >= limit
    let total = 0
    try {
      if (infoResp.responseCode === 200 && infoResp.result) {
        const ib: Record<string, Object> = JSON.parse(infoResp.result as string) as Record<string, Object>
        const idata = ib.data as Record<string, Object>
        const params = idata?.params as Record<string, Object>
        if (params) {
          total = (params.total as number) || 0
          const pageSize = (params.pagesize as number) || limit
          if (total > 0) { hasMore = (page + 1) * pageSize < total }
        }
      }
    } catch (_) { /* 信息端点解析失败则保留默认启发式 */ }
    pg.total = total
    pg.hasMore = hasMore
    return pg
  } catch (e) {
    Logger.error(TAG, `kg getPlaylists error: ${JSON.stringify(e)}`)
    return new MusichallPlaylistPage()
  }
}

// ===== 歌单分类标签 =====
// 对齐 lx-music-mobile kg/songList.js getTags：is_smarty getSpecial → data.hotTag + data.tagids
export async function getPlaylistTags(): Promise<TagFilterGroup[]> {
  try {
    const url = 'http://www2.kugou.kugou.com/yueku/v9/special/getSpecial?is_smarty=1&'
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Referer': 'https://www.kugou.com/yy/special/index.html' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return getDefaultPlaylistTags() }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    if (body.status !== 1) { return getDefaultPlaylistTags() }
    const data = body.data as Record<string, Object>
    if (!data) { return getDefaultPlaylistTags() }
    const groups: TagFilterGroup[] = []
    // 热门标签：data.hotTag = { status, data: { key: { special_id, special_name } } }
    const hotTag = data.hotTag as Record<string, Object>
    if (hotTag && (hotTag.status as number) === 1) {
      const hotData = hotTag.data as Record<string, Object>
      if (hotData) {
        const hotGroup = new TagFilterGroup()
        hotGroup.groupName = '热门'
        const hotTags: TagFilterItem[] = []
        for (const key of Object.keys(hotData)) {
          const t = hotData[key] as Record<string, Object>
          const item = new TagFilterItem()
          item.id = String(t.special_id || '')
          item.name = (t.special_name as string) || ''
          if (item.id && item.name) { hotTags.push(item) }
        }
        hotGroup.tags = hotTags
        if (hotTags.length > 0) { groups.push(hotGroup) }
      }
    }
    // 分类标签：data.tagids = { 分组名: { data: [{ id, name }] } }
    const tagids = data.tagids as Record<string, Object>
    if (tagids) {
      for (const name of Object.keys(tagids)) {
        const grp = tagids[name] as Record<string, Object>
        const arr = grp?.data as Record<string, Object>[]
        if (arr && arr.length > 0) {
          const group = new TagFilterGroup()
          group.groupName = name
          group.tags = arr.map(tag => {
            const item = new TagFilterItem()
            item.id = String(tag.id || '')
            item.name = (tag.name as string) || ''
            return item
          }).filter(item => item.id && item.name)
          if (group.tags.length > 0) { groups.push(group) }
        }
      }
    }
    Logger.info(TAG, `kg getPlaylistTags success: groups=${groups.length}`)
    return groups.length > 0 ? groups : getDefaultPlaylistTags()
  } catch (e) {
    Logger.error(TAG, `kg getPlaylistTags error: ${JSON.stringify(e)}`)
    return getDefaultPlaylistTags()
  }
}

// ===== URL/ID 解析（对齐 lx songList.getListDetail） =====
const KG_RE_INTERNAL = /\/(\d+)-5-9999\.html/
const KG_RE_SPECIAL_SINGLE = /\/special\/single\/(\d+)\.html/
const KG_RE_CHAIN = /\/share\/\?chain=(\w+)/
const KG_RE_GCID = /gcid_(\w+)/

/** 从粘贴的分享文本中提取纯 URL（截取 https?:// 开头的连续非空白字符） */
function extractUrl(rawText: string): string {
  const trimmed = rawText.trim()
  const m = trimmed.match(/https?:\/\/[^\s]+/)
  if (!m) { return trimmed }
  return m[0].replace(/[）\)。，,，！!？?…/』】]+$/, '')
}

function parsePlaylistId(rawInput: string): string {
  let id = extractUrl(rawInput)
  if (/^\d+$/.test(id)) { return id }
  if (id.startsWith('id_')) { return id.substring(3) }
  if (KG_RE_INTERNAL.test(id)) { return id.match(KG_RE_INTERNAL)![1] }
  if (KG_RE_SPECIAL_SINGLE.test(id)) { return id.match(KG_RE_SPECIAL_SINGLE)![1] }
  if (KG_RE_CHAIN.test(id)) { return id.match(KG_RE_CHAIN)![1] }
  if (/\.html/.test(id)) { return id.replace(/.+\/(\w+)\.html(?:\?.*|&.*$|#.*$|$)/, '$1') }
  if (KG_RE_GCID.test(id)) { return id }
  return id
}

/** 对含 gcid_ / 无法识别的分享链接做 HTTP 重定向解析，提取 global_collection_id */
async function resolveKgLink(rawUrl: string): Promise<string | null> {
  try {
    Logger.info(TAG, `resolveKgLink request: ${rawUrl.substring(0, 100)}`)
    const resp = await http.createHttp().request(rawUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Mobile Safari/537.36' },
      connectTimeout: 8000, readTimeout: 8000
    })
    Logger.info(TAG, `resolveKgLink response: code=${resp.responseCode} bodyLen=${typeof resp.result === 'string' ? resp.result.length : 0}`)
    if (resp.responseCode !== 200 || !resp.result) {
      throw new KgPlaylistSongsError(`HTTP ${resp.responseCode}`)
    }
    const html = resp.result as string
    let match = html.match(/(?:global_collection_id[=:]\s*["' ]?|"global_collection_id":")(\w+)/)
    if (match) { Logger.info(TAG, `resolveKgLink matched global_collection_id=${match[1]}`); return match[1] }
    match = html.match(/\/special\/single\/(\d+)\.html/)
    if (match) { Logger.info(TAG, `resolveKgLink matched special/single=${match[1]}`); return match[1] }
    match = html.match(/(?:specialid[=:]\s*["' ]?|"specialid":")(\w+)/)
    if (match) { Logger.info(TAG, `resolveKgLink matched specialid=${match[1]}`); return match[1] }
    match = html.match(/global_collection_id[=:]([a-zA-Z0-9]+)/)
    if (match) { Logger.info(TAG, `resolveKgLink matched gc_id=${match[1]}`); return match[1] }
    Logger.warn(TAG, `resolveKgLink no match! HTML full:\n${html}`)
    throw new KgPlaylistSongsError(`HTML解析失败 length=${html.length}`)
  } catch (e) {
    if (e instanceof KgPlaylistSongsError) { throw e }
    Logger.error(TAG, `resolveKgLink error: ${JSON.stringify(e)}`)
    throw new KgPlaylistSongsError(`HTTP请求失败`)
  }
}

// ===== 歌单内歌曲 =====
export class KgPlaylistSongsError extends Error {
  detail: string = ''
  constructor(msg: string) { super(msg); this.detail = msg }
}

class KgBatchDecodeItem {
  id: string = ''
  id_type: number = 0
}

class KgBatchDecodeBody {
  ret_info: number = 0
  data: KgBatchDecodeItem[] = []
}

/** decodeGcid → 获取 global_collection_id */
async function decodeGcid(gcid: string): Promise<string | null> {
  try {
    const params = 'dfid=-&appid=1005&mid=0&clientver=20109&clienttime=640612895&uuid=-'
    const item = new KgBatchDecodeItem()
    item.id = gcid
    item.id_type = 2
    const body = new KgBatchDecodeBody()
    body.ret_info = 1
    body.data = [item]
    const bodyStr = JSON.stringify(body)
    const sig = await signatureParams(params, 'android', bodyStr)
    const url = `https://t.kugou.com/v1/songlist/batch_decode?${params}&signature=${sig}`
    Logger.info(TAG, `decodeGcid request: ${url.substring(0, 100)}`)
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36', 'Referer': 'https://m.kugou.com/' },
      extraData: bodyStr,
      connectTimeout: 8000, readTimeout: 8000
    })
    Logger.info(TAG, `decodeGcid resp code=${resp.responseCode} resultLen=${typeof resp.result === 'string' ? resp.result.length : 0}`)
    if (resp.responseCode !== 200 || !resp.result) {
      Logger.warn(TAG, `decodeGcid HTTP fail: code=${resp.responseCode}`)
      return null
    }
    const respBody: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    Logger.info(TAG, `decodeGcid resp keys: ${Object.keys(respBody).join(',')}`)
    const respData = respBody['data'] as Record<string, Object>
    if (!respData) { Logger.warn(TAG, `decodeGcid no data field`); return null }
    const rlist = respData['list'] as Record<string, Object>[]
    if (rlist && rlist.length > 0) {
      const gcId = rlist[0]['global_collection_id'] as string || ''
      Logger.info(TAG, `decodeGcid got global_collection_id=${gcId}`)
      if (gcId) { return gcId }
    } else {
      Logger.warn(TAG, `decodeGcid no list in data, err_code=${respBody['err_code']}`)
    }
    return null
  } catch (e) {
    Logger.warn(TAG, `decodeGcid error: ${JSON.stringify(e)}`)
    return null
  }
}

/** 按 global_collection_id 分页拉取全量歌曲（v5 API, 需签名） */
async function fetchByCollectionId(globalCollectionId: string, limit: number): Promise<PlaylistDetailResult | null> {
  try {
    const infoParams = `appid=1058&specialid=0&global_specialid=${globalCollectionId}&format=jsonp&srcappid=2919&clientver=20000&clienttime=1586163242519&mid=1586163242519&uuid=1586163242519&dfid=-`
    const infoSig = await signatureParams(infoParams, 'web', '')
    const infoUrl = `https://mobiles.kugou.com/api/v5/special/info_v2?${infoParams}&signature=${infoSig}`
    Logger.info(TAG, `fetchByCollectionId info: ${infoUrl.substring(0, 120)}`)
    const infoResp = await http.createHttp().request(infoUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38', 'Referer': 'https://m3ws.kugou.com/share/index.php', 'dfid': '-', 'clienttime': '1586163242519', 'mid': '1586163242519' },
      connectTimeout: 8000, readTimeout: 8000
    })
    Logger.info(TAG, `fetchByCollectionId infoResp: code=${infoResp.responseCode} len=${typeof infoResp.result === 'string' ? infoResp.result.length : 0}`)
    if (infoResp.responseCode !== 200 || !infoResp.result) {
      Logger.warn(TAG, `fetchByCollectionId info http fail`)
      return null
    }
    const infoBody: Record<string, Object> = JSON.parse(infoResp.result as string) as Record<string, Object>
    Logger.info(TAG, `fetchByCollectionId info keys: ${Object.keys(infoBody).join(',')}`)
    const infoData = infoBody['data'] as Record<string, Object>
    if (!infoData) { Logger.warn(TAG, `fetchByCollectionId no data field`); return null }
    const songCount = (infoData['songcount'] as number) || 0
    const specialName = (infoData['specialname'] as string) || ''
    const imgUrl = (infoData['imgurl'] as string) || ''
    const nickname = (infoData['nickname'] as string) || ''
    Logger.info(TAG, `fetchByCollectionId songCount=${songCount}`)
    if (songCount === 0) { Logger.warn(TAG, `fetchByCollectionId songCount is 0`); return null }
    // 分页拉歌曲
    const allSongs: Record<string, Object>[] = []
    let page = 1; const pageSize = 300
    while (allSongs.length < songCount) {
      const songParams = `appid=1058&global_specialid=${globalCollectionId}&specialid=0&plat=0&version=8000&page=${page}&pagesize=${pageSize}&srcappid=2919&clientver=20000&clienttime=1586163263991&mid=1586163263991&uuid=1586163263991&dfid=-`
      const songSig = await signatureParams(songParams, 'web', '')
      const songUrl = `https://mobiles.kugou.com/api/v5/special/song_v2?${songParams}&signature=${songSig}`
      const songResp = await http.createHttp().request(songUrl, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38', 'Referer': 'https://m3ws.kugou.com/share/index.php', 'dfid': '-', 'clienttime': '1586163263991', 'mid': '1586163263991' },
        connectTimeout: 8000, readTimeout: 8000
      })
      Logger.info(TAG, `fetchByCollectionId songResp page=${page} code=${songResp.responseCode} len=${typeof songResp.result === 'string' ? songResp.result.length : 0}`)
      if (songResp.responseCode !== 200 || !songResp.result) { break }
      const songBody: Record<string, Object> = JSON.parse(songResp.result as string) as Record<string, Object>
      const songData = songBody['data'] as Record<string, Object>
      const info = (songData ? songData['info'] as Record<string, Object>[] : songBody['info'] as Record<string, Object>[]) || []
      if (info && info.length > 0) {
        allSongs.push(...info)
        page++
      } else { break }
    }
    Logger.info(TAG, `fetchByCollectionId loaded ${allSongs.length} songs`)
    if (allSongs.length === 0) { return null }
    const enriched = await getMusicInfos(allSongs)
    const list = enriched.map(mapOne)
    const meta = new PlaylistMeta()
    meta.name = specialName
    meta.img = imgUrl.replace('{size}', '240')
    meta.author = nickname
    return { list, allPage: 1, limit: list.length, total: list.length, source: 'kg', info: meta }
  } catch (e) {
    Logger.error(TAG, `fetchByCollectionId error: ${JSON.stringify(e)}`)
    return null
  }
}

/** 从 kg gcid 分享链接加载歌单（通过 decodeGcid → v5 API 获取全量） */
async function resolveKgLinkAndFetch(rawUrl: string, limit: number): Promise<PlaylistDetailResult | null> {
  const gcidMatch = rawUrl.match(/gcid_(\w+)/)
  if (gcidMatch) {
    const gcid = gcidMatch[0]
    Logger.info(TAG, `resolveKgLinkAndFetch gcid=${gcid}`)
    const gcId = await decodeGcid(gcid)
    Logger.info(TAG, `resolveKgLinkAndFetch after decodeGcid: gcId=${gcId ? gcId : '(null)'}`)
    if (gcId) {
      const result = await fetchByCollectionId(gcId, limit)
      Logger.info(TAG, `resolveKgLinkAndFetch after fetchByCollectionId: result=${result ? `songs=${result.list.length}` : '(null)'}`)
      if (result) { return result }
    }
  }
  // 回落：解析内嵌 JSON（10首）
  try {
    const resp = await http.createHttp().request(rawUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36' },
      connectTimeout: 10000, readTimeout: 10000
    })
    if (resp.responseCode !== 200 || !resp.result) { return null }
    const html = resp.result as string
    const startIdx = html.indexOf('window.$output = ')
    if (startIdx < 0) { return null }
    const braceStart = html.indexOf('{', startIdx)
    if (braceStart < 0) { return null }
    let depth = 0; let inStr = false; let esc = false; let endIdx = braceStart
    for (let i = braceStart; i < html.length; i++) {
      const ch = html.charAt(i)
      if (esc) { esc = false; continue }
      if (ch === '\\') { esc = true; continue }
      if (ch === '"') { inStr = !inStr; continue }
      if (inStr) { continue }
      if (ch === '{') { depth++ }
      else if (ch === '}') { depth--; if (depth === 0) { endIdx = i + 1; break } }
    }
    const data: Record<string, Object> = JSON.parse(html.substring(braceStart, endIdx)) as Record<string, Object>
    return parseOutputJson(data, limit)
  } catch (e) {
    Logger.error(TAG, `resolveKgLinkAndFetch error: ${JSON.stringify(e)}`)
    return null
  }
}

/** schain/transfer 全量加载 */
async function fetchByChain(chain: string, limit: number): Promise<PlaylistDetailResult | null> {
  try {
    const url = `http://m.kugou.com/schain/transfer?pagesize=${limit}&chain=${chain}&su=1&page=1&n=0.1`
    Logger.info(TAG, `fetchByChain: ${url}`)
    const resp = await http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode !== 200 || !resp.result) { return null }
    const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
    const infoData = body['info'] as Record<string, Object>
    const listData = body['list'] as Record<string, Object>[]
    const songs = (listData || (infoData ? (infoData['list'] as Record<string, Object>[]) : null) || [])
    if (songs.length === 0) { return null }
    const enriched = await getMusicInfos(songs)
    const list = enriched.map(mapOne)
    const meta = new PlaylistMeta()
    if (infoData) {
      meta.name = (infoData['name'] as string) || ''
      meta.img = ((infoData['pic'] as string) || (infoData['img'] as string) || '').replace('{size}', '240')
      meta.author = (infoData['username'] as string) || (infoData['list_create_username'] as string) || ''
    }
    Logger.info(TAG, `fetchByChain done: name=${meta.name} songs=${list.length}`)
    return { list, allPage: 1, limit, total: list.length, source: 'kg', info: meta }
  } catch (e) {
    Logger.warn(TAG, `fetchByChain error: ${JSON.stringify(e)}`)
    return null
  }
}

/** 解析 window.$output JSON */
function parseOutputJson(data: Record<string, Object>, limit: number): PlaylistDetailResult | null {
  const info = data['info'] as Record<string, Object>
  const listinfo = info?.['listinfo'] as Record<string, Object>
  const songs = (info?.['songs'] as Record<string, Object>[]) || []
  if (!listinfo || songs.length === 0) { return null }
  const meta = new PlaylistMeta()
  meta.name = (listinfo['name'] as string) || ''
  const pic = (listinfo['pic'] as string) || ''
  meta.img = pic.replace('{size}', '400')
  meta.author = (listinfo['list_create_username'] as string) || ''
  meta.desc = (listinfo['intro'] as string) || ''
  const list: SearchResultItem[] = []
  for (const song of songs.slice(0, limit)) {
    const r = new SearchResultItem()
    const si = (song['singerinfo'] as Array<Record<string, Object>>) || []
    r.singer = si.map(s => s['name'] as string).filter(Boolean).join('、')
    r.title = (song['name'] as string) || ''
    r.songId = (song['hash'] as string) || ''
    r.source = 'kg'
    r.duration = formatDuration(Math.floor(((song['timelen'] as number) || 0) / 1000))
    r.coverUrl = ''; r.cover = ''
    const types: Array<QualityType> = []
    const _types: Record<string, QualitySizeType> = {}
    const goods = (song['relate_goods'] as Array<Record<string, Object>>) || []
    for (const g of goods) {
      const bitrate = g['bitrate'] as number
      const sz = (g['size'] as number) || 0
      const hash = (g['hash'] as string) || ''
      const size = sz > 0 ? (sz >= 1048576 ? (sz / 1048576).toFixed(1) + 'MB' : (sz / 1024).toFixed(0) + 'KB') : ''
      if (bitrate >= 1000) { types.push({ type: 'flac24bit', size }); _types['flac24bit'] = { size, hash } }
      else if (bitrate >= 800) { types.push({ type: 'flac', size }); _types['flac'] = { size, hash } }
      else if (bitrate >= 300) { types.push({ type: '320k', size }); _types['320k'] = { size, hash } }
      else { types.push({ type: '128k', size }); _types['128k'] = { size, hash } }
    }
    r.types = types; r._types = _types; r.rawFields = song
    list.push(r)
  }
  const total = list.length
  Logger.info(TAG, `parseOutputJson done: name=${meta.name} songs=${total}`)
  return { list, allPage: 1, limit, total, source: 'kg', info: meta }
}

/** 通过 m3ws.kugou.com 请求，用 headersReceive 捕获 chain */
async function resolveKgViaHttp(requestUrl: string): Promise<PlaylistDetailResult | null> {
  try {
    const httpReq = http.createHttp()
    let chain = ''
    httpReq.on('headersReceive', (header: Object) => {
      const hdr = header as Record<string, string>
      const loc = hdr['Location'] || hdr['location'] || ''
      if (loc) {
        const cm = loc.match(/chain=([\w]+)/)
        if (cm) { chain = chain || cm[1] }
      }
    })
    await httpReq.request(requestUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46' },
      connectTimeout: 8000, readTimeout: 8000
    })
    Logger.info(TAG, `resolveKgViaHttp chain=${chain}`)
    if (chain) { return await fetchByChain(chain, 1000) }
    return null
  } catch (e) {
    Logger.warn(TAG, `resolveKgViaHttp error: ${JSON.stringify(e)}`)
    return null
  }
}

/** 多种方式尝试拉取 kg gcid 歌单全量数据 */
async function resolveKgAll(rawUrl: string, gcid: string, limit: number): Promise<PlaylistDetailResult | null> {
  // 方式1: schain/transfer (需真实 chain)
  const chainRes = await fetchByChain(gcid, limit)
  if (chainRes && chainRes.list.length > 10) { return chainRes }
  // 方式2: m3ws zlist API
  const zlistUrl = `https://m3ws.kugou.com/zlist/list?gcid=${encodeURIComponent(gcid)}&page=1&pagesize=${limit}`
  Logger.info(TAG, `resolveKgAll zlist: ${zlistUrl}`)
  try {
    const resp = await http.createHttp().request(zlistUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode === 200 && resp.result) {
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      const listData = (body['list'] || body['info']) as Record<string, Object>
      const songs = ((listData ? listData['list'] : body['list']) as Record<string, Object>[]) || (body['data'] as Record<string, Object>[]) || []
      if (Array.isArray(songs) && songs.length > 0) {
        const enriched = await getMusicInfos(songs)
        const list = enriched.map(mapOne)
        const meta = new PlaylistMeta()
        meta.name = (listData ? (listData['name'] as string) : '') || ''
        const pic = (listData ? (listData['pic'] as string) : '') || ''
        meta.img = pic.replace('{size}', '240')
        meta.author = (listData ? (listData['username'] as string) : '') || ''
        Logger.info(TAG, `resolveKgAll zlist done: songs=${list.length}`)
        return { list, allPage: 1, limit, total: list.length, source: 'kg', info: meta }
      }
    }
  } catch (e) { Logger.warn(TAG, `resolveKgAll zlist error: ${JSON.stringify(e)}`) }
  // 方式3: json 格式请求
  const jsonUrl = `${rawUrl}?json=true&pagesize=${limit}`
  Logger.info(TAG, `resolveKgAll jsonUrl: ${jsonUrl.substring(0, 120)}`)
  try {
    const resp = await http.createHttp().request(jsonUrl, {
      method: http.RequestMethod.GET,
      header: { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46' },
      connectTimeout: 8000, readTimeout: 8000
    })
    if (resp.responseCode === 200 && resp.result) {
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      const bodyInfo = body['info'] as Record<string, Object>
      const songs = ((body['list'] as Record<string, Object>[]) || (bodyInfo ? bodyInfo['list'] as Record<string, Object>[] : undefined) || [])
      if (Array.isArray(songs) && songs.length > 10) {
        const enriched = await getMusicInfos(songs)
        const list = enriched.map(mapOne)
        const meta = new PlaylistMeta()
        Logger.info(TAG, `resolveKgAll jsonUrl done: songs=${list.length}`)
        return { list, allPage: 1, limit, total: list.length, source: 'kg', info: meta }
      }
    }
  } catch (e) { Logger.warn(TAG, `resolveKgAll jsonUrl error: ${JSON.stringify(e)}`) }
  return null
}

export async function getPlaylistSongs(playlistId: string, page: number = 1, limit: number = 1000): Promise<PlaylistDetailResult> {
  const rawUrl = extractUrl(playlistId)
  let id = parsePlaylistId(playlistId)
  Logger.info(TAG, `raw=[${playlistId.substring(0, 80)}] rawUrl=[${rawUrl.substring(0, 80)}] id=[${id.substring(0, 80)}]`)
  const emptyMeta = new PlaylistMeta()
  const empty: PlaylistDetailResult = { list: [], allPage: 1, limit, total: 0, source: 'kg', info: emptyMeta }
  try {
    if (id.includes('://')) {
      // gcid_ / 分享链接 → 从 HTML 内嵌 JSON 直接解析歌曲
      if (/gcid_/.test(rawUrl)) {
        const directResult = await resolveKgLinkAndFetch(rawUrl, limit)
        if (directResult) { return directResult }
        throw new KgPlaylistSongsError(`gcids解析失败`)
      }
      // 其他 URL → 尝试提取 ID 后走 API
      const resolved = await resolveKgLink(rawUrl)
      if (!resolved) {
        throw new KgPlaylistSongsError(`链接解析失败: ${rawUrl.substring(0, 50)}...`)
      }
      id = resolved
      Logger.info(TAG, `resolved ID=${id}`)
    }
    const url = `http://www2.kugou.kugou.com/yueku/v9/special/single/${id}-5-9999.html`
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
    const meta = new PlaylistMeta()
    const infoMatch = html.match(/global\s*=\s*\{[\s\S]*?name:\s*"(.+?)"[\s\S]*?pic:\s*"(.+?)"/)
    if (infoMatch) {
      meta.name = infoMatch[1] || ''
      meta.img = infoMatch[2] || ''
    }
    return { list, allPage: Math.ceil(total / limit) || 1, limit, total, source: 'kg', info: meta }
  } catch (e) {
    if (e instanceof KgPlaylistSongsError) { throw e }
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
