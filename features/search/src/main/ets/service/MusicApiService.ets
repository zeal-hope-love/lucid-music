/*
 * MusicApiService - 音乐平台 API 服务
 * 直接调用 5 大音乐平台公开 HTTP API 进行搜索、热门搜索、联想建议
 * 参考 lx-music-mobile 项目的 API 端点和 MusicHome 的 ArkTS 实现
 */
import { http } from '@kit.NetworkKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { buffer, util } from '@kit.ArkTS'
import { Logger } from 'musicbasic'
import { SearchResultItem } from '../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../model/SuggestionItem'

const TAG = 'MusicApiService'

/** EAPI 请求数据 */
interface EapiData {
  id: string
}

/** QQ 获取 vkey 请求参数 */
interface QQVkeyParam {
  guid: string
  songmid: string[]
  songtype: number[]
  uin: string
  loginflag: number
  platform: string
}

/** QQ 获取 vkey 请求模块 */
interface QQVkeyModule {
  module: string
  method: string
  param: QQVkeyParam
}

/** QQ 获取 vkey 请求体 */
interface QQVkeyBody {
  req_0: QQVkeyModule
}

/** 播放 URL 获取结果 */
export interface PlayUrlResult {
  url: string
  lyrics: string
}

/** EAPI AES-128-ECB 密钥（UTF-8 编码，恰好 16 字节） */
const EAPI_KEY = 'e82ckenh8dichen8'

/** PKCS7 padding：补足到 16 字节倍数 */
function pkcs7Pad(input: Uint8Array): Uint8Array {
  const blockSize = 16
  const padLen = blockSize - (input.length % blockSize)
  const padded = new Uint8Array(input.length + padLen)
  padded.set(input)
  for (let i = 0; i < padLen; i++) {
    padded[input.length + i] = padLen
  }
  return padded
}

/** MD5 hex 小写 */
async function md5Hex(input: string): Promise<string> {
  const md = cryptoFramework.createMd('MD5')
  await md.update({ data: new Uint8Array(buffer.from(input, 'utf-8').buffer) })
  const result = await md.digest()
  let hex = ''
  for (const b of result.data) {
    hex += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16)
  }
  return hex
}

/** AES-128-ECB-NoPadding，输入字节数组，输出 hex 大写 */
async function aesEcbEncrypt(plainBytes: Uint8Array): Promise<string> {
  const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128')
  const keyBlob: cryptoFramework.DataBlob = {
    data: new Uint8Array(buffer.from(EAPI_KEY, 'utf-8').buffer)
  }
  const symKey = await symKeyGenerator.convertKey(keyBlob)
  const cipher = cryptoFramework.createCipher('AES128|ECB|NoPadding')
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null!)
  const padded = pkcs7Pad(plainBytes)
  const output: cryptoFramework.DataBlob = await cipher.doFinal({ data: padded })
  let hex = ''
  for (const b of output.data) {
    hex += ((b as number) < 16 ? '0' : '') + ((b as number) & 0xff).toString(16).toUpperCase()
  }
  return hex
}

/** EAPI 加密：url + data → params 字符串 */
async function eapiEncrypt(url: string, data: EapiData): Promise<string> {
  const jsonStr = JSON.stringify(data)
  const message = `nobody${url}use${jsonStr}md5forencrypt`
  const digest = await md5Hex(message)
  const plain = `${url}-36cd479b6b5-${jsonStr}-36cd479b6b5-${digest}`
  const plainBytes = new Uint8Array(buffer.from(plain, 'utf-8').buffer)
  return aesEcbEncrypt(plainBytes)
}

/** QQ 热搜请求体 — internetAPI 模块 */
interface QQHotKeyComm {
  ct: string
  cv: string
  guid: string
  patch: string
  psrf_access_token_expiresAt: number
  psrf_qqaccess_token: string
  psrf_qqopenid: string
  psrf_qqunionid: string
  tmeAppID: string
  tmeLoginType: number
  uin: string
  wid: string
}

interface QQHotKeyParam {
  search_id: string
  uin: number
}

interface QQHotKeyModule {
  method: string
  module: string
  param: QQHotKeyParam
}

interface QQHotKeyBody {
  comm: QQHotKeyComm
  hotkey: QQHotKeyModule
}

export class MusicApiService {
  /** 平台标识映射：SearchPlatform → 内部 API ID */
  private static platformToId(platform: string): string {
    const map: Record<string, string> = {
      'kugou': 'kg',
      'qq': 'tx',
      'netease': 'wy',
      'kuwo': 'kw',
      'migu': 'mg',
    }
    return map[platform] || platform
  }

  // ============================================================
  // 公共接口
  // ============================================================

  /**
   * 搜索歌曲
   * @param keyword 关键词
   * @param platform 平台标识 (kugou/qq/netease/kuwo/migu)
   * @param page 页码 (从 1 开始)
   * @param limit 每页条数
   */
  public static async search(keyword: string, platform: string, page: number = 1,
    limit: number = 30): Promise<SearchResultItem[]> {
    const pid = MusicApiService.platformToId(platform)
    switch (pid) {
      case 'kg':
        return MusicApiService.searchKugou(keyword, page, limit)
      case 'tx':
        return MusicApiService.searchQQ(keyword, page, limit)
      case 'wy':
        return MusicApiService.searchNetease(keyword, page, limit)
      case 'kw':
        return MusicApiService.searchKuwo(keyword, page, limit)
      case 'mg':
        return MusicApiService.searchMigu(keyword, page, limit)
      default:
        return []
    }
  }

  /**
   * 获取热门搜索词
   */
  public static async hotSearch(platform: string): Promise<string[]> {
    const pid = MusicApiService.platformToId(platform)
    switch (pid) {
      case 'wy':
        return MusicApiService.hotSearchNetease()
      case 'tx':
        return MusicApiService.hotSearchQQ()
      case 'kg':
        return MusicApiService.hotSearchKugou()
      case 'kw':
        return MusicApiService.hotSearchKuwo()
      case 'mg':
        return MusicApiService.hotSearchMigu()
      default:
        return MusicApiService.hotSearchNetease()
    }
  }

  /**
   * 获取搜索联想建议（带多平台降级回退链）
   */
  public static async suggest(keyword: string, platform: string): Promise<SuggestionItem[]> {
    const pid = MusicApiService.platformToId(platform)
    // 主平台尝试
    const primary = await MusicApiService.suggestByPlatform(pid, keyword)
    if (primary.length > 0) {
      return primary
    }
    // 降级回退链：依次尝试其他可用平台
    const fallbackOrder = ['tx', 'wy', 'kw', 'mg'].filter(p => p !== pid)
    for (const fbPid of fallbackOrder) {
      const result = await MusicApiService.suggestByPlatform(fbPid, keyword)
      if (result.length > 0) {
        Logger.info(TAG, `suggest fallback from ${pid} to ${fbPid}, items=${result.length}`)
        return result
      }
    }
    return []
  }

  /** 按平台 ID 分发搜索联想请求 */
  private static async suggestByPlatform(pid: string, keyword: string): Promise<SuggestionItem[]> {
    switch (pid) {
      case 'kg':
        return MusicApiService.suggestKugou(keyword)
      case 'tx':
        return MusicApiService.suggestQQ(keyword)
      case 'wy':
        return MusicApiService.suggestNetease(keyword)
      case 'kw':
        return MusicApiService.suggestKuwo(keyword)
      case 'mg':
        return MusicApiService.suggestMigu(keyword)
      default:
        return []
    }
  }

  // ============================================================
  // 酷狗音乐 (kg)
  // ============================================================

  private static async searchKugou(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const url = `https://songsearch.kugou.com/song_search_v2?keyword=${
        encodeURIComponent(keyword)}&page=${page}&pagesize=${limit}&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `kugou search failed, code=${resp.responseCode}`)
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['error_code'] !== 0 || !body['data']) {
        return []
      }
      return MusicApiService.mapKugouList((body['data'] as Record<string, Object>)['lists'] as object[])
    } catch (e) {
      Logger.error(TAG, `kugou search error: ${JSON.stringify(e)}`)
      return []
    }
  }

  private static mapKugouList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    const seen = new Set<string>()
    if (!Array.isArray(rawList)) {
      return results
    }
    for (const item of rawList as Record<string, Object>[]) {
      const key = (item['Audioid'] as string) + (item['FileHash'] as string)
      if (seen.has(key)) {
        continue
      }
      seen.add(key)
      const result = new SearchResultItem()
      result.title = (item['SongName'] as string) || ''
      result.singer = (item['SingerName'] as string) || ''
      result.album = (item['AlbumName'] as string) || ''
      result.songId = (item['FileHash'] as string) || ''
      result.source = 'kg'
      result.duration = MusicApiService.formatDuration((item['Duration'] as number) || 0)
      const albumId: string = (item['AlbumID'] as string) || ''
      const kgHash: string = (item['FileHash'] as string) || ''
      result.coverUrl = albumId ? `https://imge.kugou.com/stdmusic/240/${albumId}.png` :
        kgHash ? `https://imge.kugou.com/stdmusic/240/${kgHash}.png` : ''
      result.cover = result.coverUrl
      // 音质提取
      const resHash: string = (item['ResFileHash'] as string) || ''
      const sqHash: string = (item['SQFileHash'] as string) || ''
      const hqHash: string = (item['HQFileHash'] as string) || ''
      result.quality = resHash ? '24bit' : sqHash ? 'SQ' : hqHash ? 'HQ' : '标准'
      result.rawFields = item
      results.push(result)
    }
    return results
  }

  // ============================================================
  // QQ音乐 (tx)
  // ============================================================

  private static async searchQQ(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const url = `https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&n=${
        limit}&p=${page}&w=${encodeURIComponent(keyword)}&cr=1&g_tk=5381`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://y.qq.com'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `qq search failed, code=${resp.responseCode}`)
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== 0 || !body['data']) {
        return []
      }
      const data = body['data'] as Record<string, Object>
      const song = data['song'] as Record<string, Object>
      return MusicApiService.mapQQList((song ? song['list'] : undefined) as object[] || [])
    } catch (e) {
      Logger.error(TAG, `qq search error: ${JSON.stringify(e)}`)
      return []
    }
  }

  private static mapQQList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (!Array.isArray(rawList)) {
      return results
    }
    for (const item of rawList as Record<string, Object>[]) {
      const result = new SearchResultItem()
      result.title = (item['songname'] as string) || (item['name'] as string) || ''
      const singers = item['singer'] as Record<string, Object>[]
      result.singer = singers ? singers.map((s: Record<string, Object>) => s['name'] as string).join('/') : ''
      result.album = (item['albumname'] as string) || ''
      result.songId = (item['songmid'] as string) || (item['songid'] as string) || ''
      result.source = 'tx'
      result.duration = MusicApiService.formatDuration((item['interval'] as number) || 0)
      const albumMid: string = (item['albummid'] as string) || (item['album_mid'] as string) || ''
      if (albumMid && albumMid !== '空') {
        result.coverUrl = `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumMid}.jpg`
      } else if (singers && singers.length > 0) {
        // 无专辑封面时使用歌手图
        const singerMid: string = (singers[0]['mid'] as string) || ''
        result.coverUrl = singerMid ? `https://y.gtimg.cn/music/photo_new/T001R500x500M000${singerMid}.jpg` : ''
      }
      result.cover = result.coverUrl
      // 音质提取
      const qqSizeHr: number = (item['sizehr'] as number) || 0
      const qqSizeSq: number = (item['sizesq'] as number) || 0
      const qqSize320: number = (item['size320'] as number) || 0
      result.quality = qqSizeHr > 0 ? '24bit' : qqSizeSq > 0 ? 'SQ' : qqSize320 > 0 ? 'HQ' : '标准'
      result.rawFields = item
      results.push(result)
    }
    return results
  }

  // ============================================================
  // 网易云音乐 (wy)
  // ============================================================

  private static async searchNetease(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const offset = (page - 1) * limit
      const url = `https://music.163.com/api/search/get?s=${
        encodeURIComponent(keyword)}&type=1&offset=${offset}&limit=${limit}`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://music.163.com'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `netease search failed, code=${resp.responseCode}`)
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== 200 || !body['result']) {
        return []
      }
      return MusicApiService.mapNeteaseList((body['result'] as Record<string, Object>)['songs'] as object[] || [])
    } catch (e) {
      Logger.error(TAG, `netease search error: ${JSON.stringify(e)}`)
      return []
    }
  }

  private static mapNeteaseList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (!Array.isArray(rawList)) {
      return results
    }
    for (const item of rawList as Record<string, Object>[]) {
      const result = new SearchResultItem()
      result.title = (item['name'] as string) || ''
      const artists = item['artists'] as Record<string, Object>[]
      result.singer = artists ? artists.map((a: Record<string, Object>) => a['name'] as string).join('/') : ''
      const album = item['album'] as Record<string, Object>
      result.album = album ? (album['name'] as string) || '' : ''
      result.songId = String((item['id'] as number) || 0)
      result.source = 'wy'
      result.duration = MusicApiService.formatDuration(Math.floor(((item['duration'] as number) || 0) / 1000))
      const albumCover: string = album ? ((album['picUrl'] as string) || (album['coverImgUrl'] as string) || '') : ''
      result.coverUrl = albumCover || (item['picUrl'] as string) || ''
      result.cover = result.coverUrl
      // 音质提取（网易云 privilege.maxbr / maxBrLevel）
      const privilege = item['privilege'] as Record<string, Object>
      const maxbr: number = privilege ? (privilege['maxbr'] as number) || 0 : 0
      const maxBrLevel: string = privilege ? (privilege['maxBrLevel'] as string) || '' : ''
      result.quality = maxBrLevel === 'hires' ? '24bit' : maxbr >= 999000 ? 'SQ' : maxbr >= 320000 ? 'HQ' : '标准'
      result.rawFields = item
      results.push(result)
    }
    return results
  }

  // ============================================================
  // 酷我音乐 (kw)
  // ============================================================

  private static async searchKuwo(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const url = `https://search.kuwo.cn/r.s?all=${
        encodeURIComponent(keyword)}&pn=${page - 1}&rn=${limit}&ft=music&rformat=json&encoding=utf8&client=kt&vipver=1&show_copyright_off=1&newver=1&mobi=1`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://kuwo.cn/',
          'User-Agent': 'Mozilla/5.0'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `kuwo search failed, code=${resp.responseCode}`)
        return []
      }
      const rawStr: string = resp.result as string
      // 酷我返回的是 Python-dict 格式（单引号），需要转换为标准 JSON
      const jsonStr: string = rawStr.replace(/'/g, '"')
      const body: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>
      if (!body || !body['abslist']) {
        Logger.warn(TAG, `kuwo no abslist`)
        return []
      }
      return MusicApiService.mapKuwoList(body['abslist'] as object[])
    } catch (e) {
      Logger.error(TAG, `kuwo search error: ${JSON.stringify(e)}`)
      return []
    }
  }

  private static mapKuwoList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    if (!Array.isArray(rawList)) {
      return results
    }
    for (const item of rawList as Record<string, Object>[]) {
      const result = new SearchResultItem()
      result.title = (item['NAME'] as string) || (item['name'] as string) || ''
      result.singer = (item['ARTIST'] as string) || (item['artist'] as string) || ''
      result.album = (item['ALBUM'] as string) || (item['album'] as string) || ''
      result.songId = (item['MUSICRID'] as string) || (item['musicrid'] as string) || ''
      result.source = 'kw'
      result.duration = MusicApiService.formatDuration((item['DURATION'] as number) || 0)
      result.coverUrl = (item['ALBUMCOVER'] as string) || (item['WEBPICURL'] as string) || ''
      if (result.coverUrl && !result.coverUrl.startsWith('http')) {
        result.coverUrl = `https:${result.coverUrl}`
      }
      result.cover = result.coverUrl
      // 音质提取（酷我 FORMATS 字段）
      const kwFormats: string = (item['FORMATS'] as string) || ''
      result.quality = kwFormats.includes('FLAC') || kwFormats.includes('无损') ? 'SQ'
        : kwFormats.includes('MP3H') || kwFormats.includes('320') ? 'HQ' : '标准'
      result.rawFields = item
      results.push(result)
    }
    return results
  }

  // ============================================================
  // 咪咕音乐 (mg) — 使用简化版公开 API
  // ============================================================

  private static async searchMigu(keyword: string, page: number, limit: number): Promise<SearchResultItem[]> {
    try {
      const searchSwitch = '%7B%22song%22%3A1%2C%22album%22%3A0%2C%22singer%22%3A0%2C%22tagSong%22%3A0%2C%22mvSong%22%3A0%2C%22songlist%22%3A0%2C%22bestShow%22%3A0%7D'
      const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/search_all.do?isCopyright=1&isCorrect=1&pageNo=${
        page}&pageSize=${limit}&searchSwitch=${searchSwitch}&sort=0&text=${encodeURIComponent(keyword)}`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://m.music.migu.cn/'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `migu search failed, code=${resp.responseCode}`)
        return []
      }
      const rawStr: string = resp.result as string
      const body: Record<string, Object> = JSON.parse(rawStr) as Record<string, Object>
      // 咪咕可能返回 resultList 或 songResultData.resultList
      let resultList: object[] = []
      if (body['resultList']) {
        resultList = body['resultList'] as object[]
      } else if (body['songResultData']) {
        resultList = (body['songResultData'] as Record<string, Object>)['resultList'] as object[] || []
      }
      return MusicApiService.mapMiguList(resultList)
    } catch (e) {
      Logger.error(TAG, `migu search error: ${JSON.stringify(e)}`)
      return []
    }
  }

  private static mapMiguList(rawList: object[]): SearchResultItem[] {
    const results: SearchResultItem[] = []
    const seen = new Set<string>()
    if (!Array.isArray(rawList)) {
      return results
    }
    for (const item of rawList) {
      // 咪咕新 API 返回 array-of-arrays: 展平内层数组
      if (Array.isArray(item)) {
        for (const inner of item as object[]) {
          MusicApiService.mapOneMiguSong(inner as Record<string, Object>, seen, results)
        }
      } else {
        MusicApiService.mapOneMiguSong(item as Record<string, Object>, seen, results)
      }
    }
    return results
  }

  private static mapOneMiguSong(data: Record<string, Object>, seen: Set<string>,
    results: SearchResultItem[]): void {
    const dedupKey: string = (data['copyrightId'] as string) || (data['id'] as string) || ''
    if (!dedupKey || seen.has(dedupKey)) {
      return
    }
    seen.add(dedupKey)
    const result = new SearchResultItem()
    result.title = (data['name'] as string) || ''
    const singers = (data['singers'] as Record<string, Object>[]) ||
      (data['singerList'] as Record<string, Object>[]) || []
    result.singer = singers.map((s: Record<string, Object>) => s['name'] as string || '').join('/')
    result.album = (data['album'] as string) ||
      ((data['albums'] as Record<string, Object>[])?.length ?? 0) > 0 ?
      ((data['albums'] as Record<string, Object>[])[0]['name'] as string || '') : ''
    result.songId = String(data['songId'] as string || data['copyrightId'] as string || '')
    result.source = 'mg'
    result.duration = MusicApiService.formatDuration((data['duration'] as number) || 0)
    let img: string = ''
    const imgItems = data['imgItems'] as Record<string, Object>[]
    if (imgItems && imgItems.length > 0) {
      img = imgItems[0]['img'] as string || ''
    }
    if (!img) {
      img = (data['img3'] as string) || (data['img2'] as string) || (data['img1'] as string) || ''
    }
    if (img && !/https?:/.test(img)) {
      img = 'http://d.musicapp.migu.cn' + img
    }
    result.coverUrl = img
    result.cover = result.coverUrl
    // 音质提取（咪咕 rateFormats）
    const rateFormats: string = (data['rateFormats'] as string) || ''
    const formatList: string[] = rateFormats ? rateFormats.split(',').filter(Boolean) : []
    if (formatList.length > 0) {
      const maxFormat = parseInt(formatList[formatList.length - 1] as string)
      result.quality = maxFormat >= 4 ? '24bit' : maxFormat >= 3 ? 'SQ' : maxFormat >= 2 ? 'HQ' : '标准'
    } else {
      result.quality = '标准'
    }
    result.rawFields = data
    results.push(result)
  }

  // ============================================================
  // 热门搜索 API（对齐 lx-music-mobile）
  // ============================================================

  /** 网易云热搜 — 对齐 wy/hotSearch.js: eapiRequest('/api/search/chart/detail') */
  private static async hotSearchNetease(): Promise<string[]> {
    try {
      const eapiUrl = '/api/search/chart/detail'
      const eapiData: EapiData = { id: 'HOT_SEARCH_SONG#@#' }
      const params = await eapiEncrypt(eapiUrl, eapiData)
      const resp = await http.createHttp().request('http://interface.music.163.com/eapi/batch', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
          'Origin': 'https://music.163.com',
        },
        extraData: `params=${params}`,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `wy hotSearch EAPI failed, code=${resp.responseCode}`)
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 200 || !body['data']) {
        Logger.warn(TAG, `wy hotSearch EAPI bad response`)
        return []
      }
      const data = body['data'] as Record<string, Object>
      const itemList = data['itemList'] as Record<string, Object>[]
      if (!itemList || !Array.isArray(itemList)) {
        return []
      }
      return itemList.map(h => h['searchWord'] as string).filter(Boolean)
    } catch (e) {
      Logger.error(TAG, `wy hotSearch EAPI error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** QQ 热搜 — 对齐 tx/hotSearch.js: POST u.y.qq.com/cgi-bin/musicu.fcg + HotkeyService */
  private static async hotSearchQQ(): Promise<string[]> {
    try {
      const body: QQHotKeyBody = {
        comm: {
          ct: '19',
          cv: '1803',
          guid: '0',
          patch: '118',
          psrf_access_token_expiresAt: 0,
          psrf_qqaccess_token: '',
          psrf_qqopenid: '',
          psrf_qqunionid: '',
          tmeAppID: 'qqmusic',
          tmeLoginType: 0,
          uin: '0',
          wid: '0',
        },
        hotkey: {
          method: 'GetHotkeyForQQMusicPC',
          module: 'tencent_musicsoso_hotkey.HotkeyService',
          param: {
            search_id: '',
            uin: 0,
          },
        },
      }
      const bodyStr = JSON.stringify(body)
      const resp = await http.createHttp().request('https://u.y.qq.com/cgi-bin/musicu.fcg', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Referer': 'https://y.qq.com/portal/player.html',
        },
        extraData: bodyStr,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const data: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (data['code'] !== 0 || !data['hotkey']) {
        return []
      }
      const hotkey = data['hotkey'] as Record<string, Object>
      const hotData = hotkey['data'] as Record<string, Object>
      const vecHotkey = hotData ? hotData['vec_hotkey'] as Record<string, Object>[] : []
      if (!vecHotkey || !Array.isArray(vecHotkey)) {
        return []
      }
      return vecHotkey.map(h => h['query'] as string).filter(Boolean)
    } catch (e) {
      Logger.error(TAG, `tx hotSearch error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** 酷狗热搜 — 对齐 kg/hotSearch.js: gateway.kugou.com/api/v3/search/hot_tab + 签名/headers */
  private static async hotSearchKugou(): Promise<string[]> {
    try {
      const url = 'http://gateway.kugou.com/api/v3/search/hot_tab?signature=ee44edb9d7155821412d220bcaf509dd&appid=1005&clientver=10026&plat=0'
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'dfid': '1ssiv93oVqMp27cirf2CvoF1',
          'mid': '156798703528610303473757548878786007104',
          'clienttime': '1584257267',
          'x-router': 'msearch.kugou.com',
          'user-agent': 'Android9-AndroidPhone-10020-130-0-searchrecommendprotocol-wifi',
          'kg-rc': '1',
        },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['errcode'] !== 0 || !body['data']) {
        return []
      }
      const data = body['data'] as Record<string, Object>
      const list = data['list'] as Record<string, Object>[]
      if (!list || !Array.isArray(list)) {
        return []
      }
      // 展平 keywords: list[].keywords[].keyword
      const result: string[] = []
      for (const item of list) {
        const keywords = item['keywords'] as Record<string, Object>[]
        if (keywords && Array.isArray(keywords)) {
          for (const k of keywords) {
            const keyword = k['keyword'] as string
            if (keyword) {
              result.push(keyword)
            }
          }
        }
      }
      return result
    } catch (e) {
      Logger.error(TAG, `kg hotSearch error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** 酷我热搜 — 对齐 kw/hotSearch.js: hotword.kuwo.cn/hotword.s */
  private static async hotSearchKuwo(): Promise<string[]> {
    try {
      const url = 'http://hotword.kuwo.cn/hotword.s?prod=kwplayer_ar_9.3.0.1&corp=kuwo&newver=2&vipver=9.3.0.1&source=kwplayer_ar_9.3.0.1_40.apk&p2p=1&notrace=0&uid=0&plat=kwplayer_ar&rformat=json&encoding=utf8&tabid=1'
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 9;)',
        },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['status'] !== 'ok' || !body['tagvalue']) {
        return []
      }
      const tagvalue = body['tagvalue'] as Record<string, Object>[]
      if (!tagvalue || !Array.isArray(tagvalue)) {
        return []
      }
      return tagvalue.map(item => item['key'] as string).filter(Boolean)
    } catch (e) {
      Logger.error(TAG, `kw hotSearch error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** 咪咕热搜 — 对齐 mg/hotSearch.js: jadeite.migu.cn/music_search/v3/search/hotword，过滤 resourceType==song */
  private static async hotSearchMigu(): Promise<string[]> {
    try {
      const url = 'http://jadeite.migu.cn:7090/music_search/v3/search/hotword'
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body || body['code'] !== '000000' || !body['data']) {
        return []
      }
      const data = body['data'] as Record<string, Object>
      const hotwords = data['hotwords'] as Record<string, Object>[]
      if (!hotwords || !Array.isArray(hotwords) || hotwords.length === 0) {
        return []
      }
      const hotwordList = hotwords[0]['hotwordList'] as Record<string, Object>[]
      if (!hotwordList || !Array.isArray(hotwordList)) {
        return []
      }
      return hotwordList
        .filter(h => h['resourceType'] === 'song')
        .map(h => h['word'] as string)
        .filter(Boolean)
    } catch (e) {
      Logger.error(TAG, `mg hotSearch error: ${JSON.stringify(e)}`)
      return []
    }
  }

  // ============================================================
  // 搜索联想建议 API（对齐 lx-music-mobile）
  // ============================================================

  /** 酷狗搜索提示 — 对齐 kg/tipSearch.js: body[0].RecordDatas[].HintInfo */
  private static async suggestKugou(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://searchtip.kugou.com/getSearchTip?MusicTipCount=10&keyword=${encodeURIComponent(keyword)}`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'referer': 'https://www.kugou.com/' },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const rawStr: string = resp.result as string
      const outerArr: object[] = JSON.parse(rawStr) as object[]
      if (!outerArr || !Array.isArray(outerArr) || outerArr.length === 0) {
        return []
      }
      const first = outerArr[0] as Record<string, Object>
      const recordDatas = first['RecordDatas'] as Record<string, Object>[]
      if (!recordDatas || !Array.isArray(recordDatas)) {
        return []
      }
      const items: SuggestionItem[] = []
      const seen = new Set<string>()
      for (const rd of recordDatas) {
        const hint = rd['HintInfo'] as string
        if (!hint || seen.has(hint)) {
          continue
        }
        seen.add(hint)
        items.push(new SuggestionItem(hint, SuggestionType.SONG, keyword))
      }
      return items.slice(0, 10)
    } catch (e) {
      Logger.error(TAG, `kg suggest error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** QQ 搜索提示 — 对齐 tx/tipSearch.js: smartbox_new.fcg（补全 is_xml/loginUin/hostUin/notice/platform/needNewCode） */
  private static async suggestQQ(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?is_xml=0&format=json&key=${encodeURIComponent(keyword)}&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://y.qq.com/portal/player.html',
        },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 0 || !body['data']) {
        return []
      }
      const data = body['data'] as Record<string, Object>
      const song = data['song'] as Record<string, Object>
      const itemlist = song ? song['itemlist'] as Record<string, Object>[] : []
      if (!itemlist || !Array.isArray(itemlist)) {
        return []
      }
      const items: SuggestionItem[] = []
      const seen = new Set<string>()
      for (const item of itemlist) {
        const name = item['name'] as string || ''
        if (!name || seen.has(name)) {
          continue
        }
        seen.add(name)
        items.push(new SuggestionItem(name, SuggestionType.SONG, keyword))
      }
      return items.slice(0, 10)
    } catch (e) {
      Logger.error(TAG, `tx suggest error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** 网易云搜索提示 — 对齐 wy/tipSearch.js: weapi 加密请求，降级用公开 API */
  private static async suggestNetease(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://music.163.com/api/search/suggest/web?csrf_token=&s=${encodeURIComponent(keyword)}&type=1`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://music.163.com' },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 200 || !body['result']) {
        return []
      }
      const result = body['result'] as Record<string, Object>
      const songs = result['songs'] as Record<string, Object>[]
      const artists = result['artists'] as Record<string, Object>[]
      const albums = result['albums'] as Record<string, Object>[]
      const items: SuggestionItem[] = []

      if (songs && Array.isArray(songs)) {
        for (const song of songs.slice(0, 5)) {
          const name = song['name'] as string
          if (name) {
            items.push(new SuggestionItem(name, SuggestionType.SONG, keyword))
          }
        }
      }
      if (artists && Array.isArray(artists)) {
        for (const artist of artists.slice(0, 3)) {
          const name = artist['name'] as string
          if (name) {
            items.push(new SuggestionItem(name, SuggestionType.ARTIST, keyword))
          }
        }
      }
      if (albums && Array.isArray(albums)) {
        for (const album of albums.slice(0, 2)) {
          const name = album['name'] as string
          if (name) {
            items.push(new SuggestionItem(name, SuggestionType.ALBUM, keyword))
          }
        }
      }
      return items.slice(0, 10)
    } catch (e) {
      Logger.error(TAG, `wy suggest error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** 酷我搜索提示 — 对齐 kw/tipSearch.js: tips.kuwo.cn/t.s → WORDITEMS[].RELWORD */
  private static async suggestKuwo(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://tips.kuwo.cn/t.s?corp=kuwo&newver=3&p2p=1&notrace=0&c=mbox&w=${encodeURIComponent(keyword)}&encoding=utf8&rformat=json`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'http://www.kuwo.cn/' },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (!body['WORDITEMS']) {
        return []
      }
      const wordItems = body['WORDITEMS'] as Record<string, Object>[]
      if (!wordItems || !Array.isArray(wordItems)) {
        return []
      }
      const items: SuggestionItem[] = []
      for (const wi of wordItems) {
        const relWord = wi['RELWORD'] as string
        if (relWord) {
          items.push(new SuggestionItem(relWord, SuggestionType.SONG, keyword))
        }
      }
      return items.slice(0, 10)
    } catch (e) {
      Logger.error(TAG, `kw suggest error: ${JSON.stringify(e)}`)
      return []
    }
  }

  /** 咪咕搜索提示 — 对齐 mg/tipSearch.js: music.migu.cn/v3/api/search/suggest → songs[].name - singerName */
  private static async suggestMigu(keyword: string): Promise<SuggestionItem[]> {
    try {
      const url = `https://music.migu.cn/v3/api/search/suggest?keyword=${encodeURIComponent(keyword)}`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: { 'referer': 'https://music.migu.cn/v3' },
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (resp.responseCode !== 200) {
        return []
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      const songs = body['songs'] as Record<string, Object>[]
      if (!songs || !Array.isArray(songs)) {
        return []
      }
      const items: SuggestionItem[] = []
      for (const song of songs) {
        const name = song['name'] as string || ''
        if (name) {
          items.push(new SuggestionItem(name, SuggestionType.SONG, keyword))
        }
      }
      return items.slice(0, 10)
    } catch (e) {
      Logger.error(TAG, `mg suggest error: ${JSON.stringify(e)}`)
      return []
    }
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /** 默认热门搜索（API 不可用时的后备数据） */
  public static defaultHotSearches(): string[] {
    return ['周杰伦', '邓紫棋', '林俊杰', '陈奕迅', 'Taylor Swift', 'IU']
  }

  /** 秒数转为 mm:ss 格式 */
  private static formatDuration(seconds: number): string {
    if (!seconds || seconds <= 0 || !isFinite(seconds)) {
      return '--:--'
    }
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  /**
   * 搜索歌曲（兼容旧接口）
   * @deprecated 请使用 search() 方法
   */
  public static async searchSongs(keyword: string, platform?: string): Promise<SearchResultItem[]> {
    const p = platform || 'kugou'
    return MusicApiService.search(keyword, p, 1, 30)
  }

  // ============================================================
  // 播放 URL 获取（各平台）
  // ============================================================

  /**
   * 获取歌曲播放 URL
   * @param songId 平台歌曲标识（hash/songmid/id）
   * @param source 平台来源 (kg/tx/wy/kw/mg)
   * @param rawFields 平台原始 API 返回数据
   * @returns 可播放的音频 URL，失败返回空字符串
   */
  public static async getPlayUrl(songId: string, source: string,
    rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    const pid = MusicApiService.platformToId(source)
    switch (pid) {
      case 'kg':
        return MusicApiService.getKugouPlayUrl(songId, rawFields)
      case 'tx':
        return MusicApiService.getQQPlayUrl(songId, rawFields)
      case 'wy':
        return MusicApiService.getNeteasePlayUrl(songId)
      case 'kw':
        return MusicApiService.getKuwoPlayUrl(songId)
      case 'mg':
        return MusicApiService.getMiguPlayUrl(songId, rawFields)
      default:
        return { url: '', lyrics: '' }
    }
  }

  // ---------- 酷狗 ----------

  private static async getKugouPlayUrl(hash: string,
    rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    const empty: PlayUrlResult = { url: '', lyrics: '' }
    try {
      const albumId: string = (rawFields['AlbumID'] as string) || ''
      // 主端点
      const mainUrl = `https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=${hash}&album_id=${albumId}&mid=1&platid=4`
      Logger.info(TAG, `kugou getPlayUrl: hash=${hash}, albumId=${albumId}`)
      const resp = await http.createHttp().request(mainUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile)',
          'Referer': 'https://www.kugou.com/',
          'Cookie': 'kg_mid=1'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `kugou getPlayUrl failed, code=${resp.responseCode}`)
        return MusicApiService.getKugouPlayUrlBackup(hash, rawFields)
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      Logger.info(TAG, `kugou getPlayUrl: err_code=${body['err_code']}, status=${body['status']}`)
      if (body['err_code'] !== 0 || !body['data']) {
        return MusicApiService.getKugouPlayUrlBackup(hash, rawFields)
      }
      const data = body['data'] as Record<string, Object>
      const playUrl = (data['play_url'] as string) || (data['play_backup_url'] as string) || ''
      // 歌词：使用两步 API（lyrics.kugou.com）
      const songName = (rawFields['SongName'] as string) || ''
      const lyrics = await MusicApiService.getKugouLyrics(hash, songName)
      Logger.info(TAG, `kugou getPlayUrl success: url_len=${playUrl.length}, lyrics_len=${lyrics.length}`)
      return { url: playUrl, lyrics: lyrics }
    } catch (e) {
      Logger.error(TAG, `kugou getPlayUrl error: ${JSON.stringify(e)}`)
      return empty
    }
  }

  /** 酷狗备用端点（m.kugou.com） */
  private static async getKugouPlayUrlBackup(hash: string,
    rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    try {
      const backupUrl = `http://m.kugou.com/app/i/getSongInfo.php?cmd=playInfo&hash=${hash}`
      Logger.info(TAG, `kugou backup: ${backupUrl}`)
      const resp = await http.createHttp().request(backupUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile)',
          'Referer': 'http://m.kugou.com/'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `kugou backup failed, code=${resp.responseCode}`)
        return { url: '', lyrics: '' }
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      const status = body['status'] as number
      Logger.info(TAG, `kugou backup: status=${status}`)
      if (status !== 1 || !body['url']) {
        return { url: '', lyrics: '' }
      }
      const songName = (rawFields['SongName'] as string) || ''
      const lyrics = await MusicApiService.getKugouLyrics(hash, songName)
      return { url: (body['url'] as string), lyrics: lyrics }
    } catch (e) {
      Logger.error(TAG, `kugou backup error: ${JSON.stringify(e)}`)
      return { url: '', lyrics: '' }
    }
  }

  // ---------- 酷狗歌词（两步 API） ----------

  private static async getKugouLyrics(hash: string, songName: string): Promise<string> {
    try {
      const searchUrl = `http://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=${
        encodeURIComponent(songName)}&hash=${hash}&lrctxt=1`
      Logger.info(TAG, `kugou lyrics search: hash=${hash}, name=${songName}`)
      const sResp = await http.createHttp().request(searchUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://www.kugou.com/'
        },
        connectTimeout: 6000,
        readTimeout: 6000
      })
      if (sResp.responseCode !== 200) {
        return ''
      }
      const sBody: Record<string, Object> = JSON.parse(sResp.result as string) as Record<string, Object>
      const candidates = sBody['candidates'] as Record<string, Object>[]
      if (!candidates || candidates.length === 0) {
        return ''
      }
      const c = candidates[0]
      const id = c['id'] as string || ''
      const accesskey = c['accesskey'] as string || ''
      if (!id || !accesskey) {
        return ''
      }
      const dlUrl = `http://lyrics.kugou.com/download?ver=1&client=pc&id=${id}&accesskey=${accesskey}&fmt=lrc&charset=utf8`
      const dResp = await http.createHttp().request(dlUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://www.kugou.com/'
        },
        connectTimeout: 6000,
        readTimeout: 6000
      })
      if (dResp.responseCode !== 200) {
        return ''
      }
      const dBody: Record<string, Object> = JSON.parse(dResp.result as string) as Record<string, Object>
      const content = dBody['content'] as string || ''
      if (!content) {
        return ''
      }
      const lyricBytes = buffer.from(content, 'base64')
      const decoder = new util.TextDecoder('utf-8')
      return decoder.decodeToString(new Uint8Array(lyricBytes.buffer), { stream: false })
    } catch (e) {
      Logger.warn(TAG, `kugou lyrics error: ${JSON.stringify(e)}`)
      return ''
    }
  }

  // ---------- QQ ----------

  private static async getQQPlayUrl(songmid: string,
    rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    const empty: PlayUrlResult = { url: '', lyrics: '' }
    try {
      const guid = String(Math.floor(Math.random() * 10000000000000))
      Logger.info(TAG, `qq getPlayUrl: songmid=${songmid}, guid=${guid}`)
      const vkeyBody: QQVkeyBody = {
        req_0: {
          module: 'vkey.GetVkeyServer',
          method: 'CgiGetVkey',
          param: {
            guid: guid,
            songmid: [songmid],
            songtype: [0],
            uin: '0',
            loginflag: 1,
            platform: '20'
          }
        }
      }
      const vkeyUrl = `https://u.y.qq.com/cgi-bin/musicu.fcg?data=${encodeURIComponent(
        JSON.stringify(vkeyBody)
      )}`
      Logger.info(TAG, `qq vkey url: songmid=${songmid}, guid=${guid}`)
      const resp = await http.createHttp().request(vkeyUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
          'Referer': 'https://y.qq.com'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      })
      if (resp.responseCode !== 200) {
        Logger.warn(TAG, `qq getPlayUrl failed, code=${resp.responseCode}`)
        return empty
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      const req0 = body['req_0'] as Record<string, Object>
      if (!req0 || req0['code'] !== 0 || !req0['data']) {
        Logger.warn(TAG, `qq getPlayUrl req_0 missing or code!=0, code=${req0 ? req0['code'] : 'null'}`)
        return empty
      }
      const data = req0['data'] as Record<string, Object>
      const midurlinfo = data['midurlinfo'] as Record<string, Object>[]
      const sip = data['sip'] as string[]
      const vkey = data['vkey'] as string
      Logger.info(TAG, `qq vkey: has_key=${!!vkey}, midurlinfo_count=${midurlinfo ? midurlinfo.length : 0}`)
      if (!midurlinfo || midurlinfo.length === 0 || !sip || sip.length === 0 || !vkey) {
        Logger.warn(TAG, `qq playUrl: no vkey or sip`)
        return empty
      }
      const purl = midurlinfo[0]['purl'] as string || ''
      if (!purl) {
        Logger.warn(TAG, `qq playUrl: purl empty — copyright restricted`)

        // 尝试获取歌词（即使不能播放，也返回歌词让 UI 显示）
        const lyrics = await MusicApiService.getQQLyrics(songmid)
        return { url: '', lyrics: lyrics }
      }
      const playUrl = `${sip[0]}${purl}`
      Logger.info(TAG, `qq getPlayUrl success: ${playUrl.substring(0, 50)}...`)

      // 获取歌词
      const lyrics = await MusicApiService.getQQLyrics(songmid)
      return { url: playUrl, lyrics: lyrics }
    } catch (e) {
      Logger.error(TAG, `qq getPlayUrl error: ${JSON.stringify(e)}`)
      return empty
    }
  }

  /** QQ 歌词查询 */
  private static async getQQLyrics(songmid: string): Promise<string> {
    try {
      const lyricUrl = `https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=${songmid}&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq`
      Logger.info(TAG, `qq lyrics: songmid=${songmid}`)
      const resp = await http.createHttp().request(lyricUrl, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)',
          'Referer': 'https://y.qq.com/portal/player.html'
        },
        connectTimeout: 6000,
        readTimeout: 6000
      })
      if (resp.responseCode !== 200) {
        return ''
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 0 || !body['lyric']) {
        return ''
      }
      // QQ 返回 base64 编码的歌词
      const encodedLyric = body['lyric'] as string
      if (!encodedLyric) {
        return ''
      }
      // 尝试 base64 解码
      try {
        const lyricBytes = buffer.from(encodedLyric, 'base64')
        const decoder = new util.TextDecoder('utf-8')
        return decoder.decodeToString(new Uint8Array(lyricBytes.buffer), { stream: false })
      } catch (_) {
        return encodedLyric
      }
    } catch (e) {
      Logger.warn(TAG, `qq lyrics fetch failed: ${JSON.stringify(e)}`)
      return ''
    }
  }

  // ---------- 网易云 ----------

  private static async getNeteasePlayUrl(songId: string): Promise<PlayUrlResult> {
    const empty: PlayUrlResult = { url: '', lyrics: '' }
    try {
      const url = `https://music.163.com/api/song/enhance/player/url?id=${songId}&ids=[${songId}]&br=320000`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://music.163.com'
        },
        connectTimeout: 8000,
        readTimeout: 8000
      })
      let playUrl = ''
      let lyrics = ''
      if (resp.responseCode === 200) {
        const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
        if (body['code'] === 200 && body['data']) {
          const data = body['data'] as Record<string, Object>[]
          if (data.length > 0) {
            playUrl = (data[0]['url'] as string) || ''
          }
        }
      }
      // 获取歌词
      lyrics = await MusicApiService.getNeteaseLyrics(songId)
      return { url: playUrl, lyrics: lyrics }
    } catch (e) {
      Logger.error(TAG, `netease getPlayUrl error: ${JSON.stringify(e)}`)
      return empty
    }
  }

  private static async getNeteaseLyrics(songId: string): Promise<string> {
    try {
      const url = `https://music.163.com/api/song/lyric?id=${songId}&lv=1&kv=1&tv=-1`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://music.163.com'
        },
        connectTimeout: 6000,
        readTimeout: 6000
      })
      if (resp.responseCode !== 200) {
        return ''
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['code'] !== 200) {
        return ''
      }
      const lrc = body['lrc'] as Record<string, Object>
      return lrc ? (lrc['lyric'] as string) || '' : ''
    } catch (_) {
      return ''
    }
  }

  // ---------- 酷我 ----------

  private static async getKuwoPlayUrl(rid: string): Promise<PlayUrlResult> {
    try {
      const id = rid.replace('MUSIC_', '').trim()
      const url = `https://www.kuwo.cn/url?format=mp3&rid=${id}&response=url&type=convert_url3&br=128kmp3`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://www.kuwo.cn/'
        },
        connectTimeout: 8000,
        readTimeout: 8000
      })
      let playUrl = ''
      if (resp.responseCode === 200) {
        const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
        if (body['code'] === 200 && body['url']) {
          playUrl = (body['url'] as string) || ''
        }
      }
      const lyrics = await MusicApiService.getKuwoLyrics(id)
      return { url: playUrl, lyrics: lyrics }
    } catch (e) {
      Logger.error(TAG, `kuwo getPlayUrl error: ${JSON.stringify(e)}`)
      return { url: '', lyrics: '' }
    }
  }

  private static async getKuwoLyrics(musicId: string): Promise<string> {
    try {
      const url = `https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=${musicId}`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 6000,
        readTimeout: 6000
      })
      if (resp.responseCode !== 200) {
        return ''
      }
      const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
      if (body['status'] !== 200 || !body['data']) {
        return ''
      }
      const data = body['data'] as Record<string, Object>
      const lrclist = data['lrclist'] as Record<string, Object>[]
      if (!lrclist || lrclist.length === 0) {
        return ''
      }
      return lrclist.map(l => `[${(l['time'] as string) || ''}]${(l['lineLyric'] as string) || ''}`).join('\n')
    } catch (_) {
      return ''
    }
  }

  // ---------- 咪咕 ----------

  private static async getMiguPlayUrl(copyrightId: string,
    rawFields: Record<string, Object>): Promise<PlayUrlResult> {
    try {
      const url = `https://app.c.nf.migu.cn/MIGUM2.0/v1.0/content/resourceinfo.do?copyrightId=${copyrightId}&resourceType=2`
      const resp = await http.createHttp().request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://m.music.migu.cn/'
        },
        connectTimeout: 8000,
        readTimeout: 8000
      })
      let bestUrl = ''
      if (resp.responseCode === 200) {
        const body: Record<string, Object> = JSON.parse(resp.result as string) as Record<string, Object>
        if (body['resource']) {
          const resources = body['resource'] as Record<string, Object>[]
          for (const r of resources) {
            const playUrl = (r['newRateFormats'] as string) ||
              (r['androidUrl'] as string) || (r['iosUrl'] as string) || ''
            if (playUrl) {
              bestUrl = playUrl
            }
          }
        }
      }
      const lyrics = (rawFields['lyricUrl'] as string) ? '' : '' // 咪咕歌词需额外 API，暂返回空
      return { url: bestUrl, lyrics: lyrics }
    } catch (e) {
      Logger.error(TAG, `migu getPlayUrl error: ${JSON.stringify(e)}`)
      return { url: '', lyrics: '' }
    }
  }
}
