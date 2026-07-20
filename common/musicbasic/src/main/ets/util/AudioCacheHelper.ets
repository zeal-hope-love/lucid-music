/*
 * AudioCacheHelper - 在线歌曲磁盘缓存管理器（功能默认直接启用，无限缓存）。
 *
 * 缓存一首歌的全部内容：音频文件 + 封面图 + 歌词 + 歌曲信息（元数据）。
 * 再次播放（同会话或重启后）直接读取本地缓存，跳过取流/换源流程，实现"播过不重取、不重下"。
 * 缓存目录位于应用沙箱 cacheDir/audio_cache，设备存储不足时系统可回收，缺失时自动回退在线取流。
 */
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from '../util/Logger'
import { SongItem } from '../model/SongData'

const TAG = 'AudioCacheHelper'

/** 缓存的歌曲信息（元数据），随索引持久化，命中时离线回填。 */
export class SongMeta {
  title: string = ''
  artist: string = ''
  album: string = ''
  duration: number = 0
  platform: string = ''
  remoteSongId: string = ''
  lyricText: string = ''
  /** 本地封面路径；若封面下载失败则回退为原始远程 coverUrl。 */
  coverUrl: string = ''
}

/** 单条缓存索引条目。 */
export class AudioCacheEntry {
  key: string = ''
  audioPath: string = ''
  imagePath: string = ''
  lyricPath: string = ''
  meta: SongMeta = new SongMeta()
  size: number = 0
  lastAccess: number = 0
}

export class AudioCacheHelper {
  private static instance: AudioCacheHelper | undefined
  /** 缓存目录名（位于 context.cacheDir 下）。 */
  private static readonly CACHE_DIR_NAME: string = 'audio_cache'
  private static readonly INDEX_FILE: string = '.index.json'
  /** 内存索引：key → 条目。 */
  private indexMap: Map<string, AudioCacheEntry> = new Map()
  private loaded: boolean = false
  /** 并发同键去重，避免重复下载。 */
  private downloading: Set<string> = new Set()

  public static getInstance(): AudioCacheHelper {
    if (!AudioCacheHelper.instance) {
      AudioCacheHelper.instance = new AudioCacheHelper()
    }
    return AudioCacheHelper.instance
  }

  private getContext(): common.UIAbilityContext | undefined {
    return AppStorage.get('context') as common.UIAbilityContext | undefined
  }

  private getCacheDir(): string {
    const ctx = this.getContext()
    if (!ctx) {
      return ''
    }
    return ctx.cacheDir + '/' + AudioCacheHelper.CACHE_DIR_NAME
  }

  private sanitize(key: string): string {
    return key.replace(/[^a-zA-Z0-9_-]/g, '_')
  }

  /** 确保缓存目录存在；已存在则跳过 mkdir（避免 EEXIST=13900015 误报并中止缓存）。返回是否就绪。 */
  private ensureCacheDir(dir: string): boolean {
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true)
      }
      return true
    } catch (e) {
      Logger.error(`${TAG}: ensureCacheDir failed ${JSON.stringify(e)}`)
      return false
    }
  }

  private fileSize(path: string): number {
    try {
      return fs.statSync(path).size
    } catch (e) {
      return 0
    }
  }

  /** 写文本文件（fileIo 无 writeTextSync，用 openSync + writeSync + closeSync）。 */
  private writeTextFile(path: string, text: string): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path)
      }
    } catch (e) {
      // 文件不存在，忽略
    }
    const fd = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    try {
      fs.writeSync(fd.fd, text, { encoding: 'utf-8' })
    } finally {
      fs.closeSync(fd)
    }
  }

  // ==================== 索引加载/持久化 ====================

  private loadIndex(): void {
    if (this.loaded) {
      return
    }
    this.loaded = true
    const ctx = this.getContext()
    if (!ctx) {
      return
    }
    const indexPath = this.getCacheDir() + '/' + AudioCacheHelper.INDEX_FILE
    try {
      if (fs.accessSync(indexPath)) {
        const text = fs.readTextSync(indexPath)
        const arr = JSON.parse(text) as AudioCacheEntry[]
        if (arr && Array.isArray(arr)) {
          for (const e of arr) {
            this.indexMap.set(e.key, e)
          }
        }
      }
    } catch (e) {
      Logger.warn(`${TAG}: loadIndex failed ${JSON.stringify(e)}`)
    }
  }

  private persistIndex(): void {
    const ctx = this.getContext()
    if (!ctx) {
      return
    }
    const dir = this.getCacheDir()
    try {
      if (!this.ensureCacheDir(dir)) {
        return
      }
      const arr: AudioCacheEntry[] = []
      this.indexMap.forEach((v) => arr.push(v))
      this.writeTextFile(dir + '/' + AudioCacheHelper.INDEX_FILE, JSON.stringify(arr))
    } catch (e) {
      Logger.error(`${TAG}: persistIndex failed ${JSON.stringify(e)}`)
    }
  }

  private upsertEntry(entry: AudioCacheEntry): void {
    this.indexMap.set(entry.key, entry)
    this.persistIndex()
  }

  // ==================== 命中查询 ====================

  /**
   * 命中且音频文件仍存在则返回条目（顺带刷新 lastAccess，不落盘），否则 undefined（回退在线取流）。
   */
  public getCachedAudio(key: string): AudioCacheEntry | undefined {
    this.loadIndex()
    const entry = this.indexMap.get(key)
    if (!entry) {
      return undefined
    }
    try {
      if (!fs.accessSync(entry.audioPath)) {
        return undefined
      }
    } catch (e) {
      return undefined
    }
    entry.lastAccess = Date.now()
    return entry
  }

  // ==================== 后台落盘 ====================

  /**
   * 后台下载音频+封面、写歌词文件、写索引（含歌曲信息）。无淘汰（无限缓存）。
   * 仅在线歌（platform + remoteSongId 齐全）参与；下载失败静默忽略，不影响播放。
   */
  public cacheRemoteSong(key: string, songItem: SongItem, url: string): void {
    if (!key || !url) {
      return
    }
    if (!songItem.platform || !songItem.remoteSongId) {
      return
    }
    if (this.downloading.has(key)) {
      return
    }
    this.downloading.add(key)
    this.doCache(key, songItem, url)
      .catch((e: BusinessError) => {
        Logger.error(`${TAG}: cacheRemoteSong failed key=${key} ${JSON.stringify(e)}`)
      })
      .finally(() => {
        this.downloading.delete(key)
      })
  }

  private async doCache(key: string, songItem: SongItem, url: string): Promise<void> {
    const dir = this.getCacheDir()
    if (!dir) {
      return
    }
    if (!this.ensureCacheDir(dir)) {
      return
    }
    const safe = this.sanitize(key)
    const audioPath = `${dir}/${safe}.mp3`
    const imagePath = `${dir}/${safe}.jpg`
    const lyricPath = `${dir}/${safe}.lrc`

    const referer = this.refererFor(songItem.platform)
    const dlHeaders: Record<string, string> = referer ? { 'Referer': referer } : {}

    // 1. 下载音频（失败则整体放弃缓存）
    try {
      if (fs.accessSync(audioPath)) {
        fs.unlinkSync(audioPath)
      }
    } catch (e) {
      // 文件不存在，忽略
    }
    await this.downloadFile(url, audioPath, dlHeaders)

    // 2. 写歌词
    if (songItem.lyricText) {
      try {
        this.writeTextFile(lyricPath, songItem.lyricText)
      } catch (e) {
        Logger.warn(`${TAG}: write lyric failed ${JSON.stringify(e)}`)
      }
    }

    // 3. 下载封面（失败不阻断缓存）
    let localCover = ''
    const cover = songItem.coverUrl
    if (cover && (cover.startsWith('http://') || cover.startsWith('https://'))) {
      try {
        if (fs.accessSync(imagePath)) {
          fs.unlinkSync(imagePath)
        }
        await this.downloadFile(cover, imagePath, dlHeaders)
        localCover = imagePath
      } catch (e) {
        localCover = ''
      }
    }

    // 4. 歌曲信息（元数据）
    const meta = new SongMeta()
    meta.title = typeof songItem.title === 'string' ? songItem.title : String(songItem.title)
    meta.artist = typeof songItem.singer === 'string' ? songItem.singer : String(songItem.singer)
    meta.album = ''
    meta.duration = 0
    meta.platform = songItem.platform
    meta.remoteSongId = songItem.remoteSongId
    meta.lyricText = songItem.lyricText
    meta.coverUrl = localCover || cover || ''

    const entry = new AudioCacheEntry()
    entry.key = key
    entry.audioPath = audioPath
    entry.imagePath = localCover
    entry.lyricPath = lyricPath
    entry.meta = meta
    entry.size = this.fileSize(audioPath)
    entry.lastAccess = Date.now()

    this.upsertEntry(entry)
    Logger.info(`${TAG}: cached key=${key} size=${entry.size}`)
  }

  /** 写二进制文件（fileIo 无 writeBufferSync，用 openSync + writeSync + closeSync）。 */
  private writeBinaryFile(path: string, buf: ArrayBuffer): void {
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path)
      }
    } catch (e) {
      // 文件不存在，忽略
    }
    const fd = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    try {
      fs.writeSync(fd.fd, buf)
    } finally {
      fs.closeSync(fd)
    }
  }

  /**
   * 用 http 模块下载 URL 到本地文件（可靠写盘 + 真实错误码）。
   * 仅下载音频/封面等二进制；音频失败则整体放弃缓存。
   */
  /** 各平台 CDN 需要的 Referer，缺失常被 403 拒绝。 */
  private refererFor(platform: string): string {
    switch (platform) {
      case 'wy': return 'https://music.163.com/'
      case 'tx': return 'https://y.qq.com/'
      case 'mg': return 'https://music.migu.cn/'
      case 'kw': return 'https://www.kuwo.cn/'
      case 'kg': return 'https://www.kugou.com/'
      default: return ''
    }
  }

  private async downloadFile(url: string, filePath: string, headers?: Record<string, string>): Promise<void> {
    const httpRequest = http.createHttp()
    const reqHeaders: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36'
    }
    if (headers) {
      for (const k of Object.keys(headers)) {
        reqHeaders[k] = headers[k]
      }
    }
    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 15000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: reqHeaders
      })
      if (resp.responseCode !== 200) {
        throw new Error(`http ${resp.responseCode}`)
      }
      const buf = resp.result as ArrayBuffer
      if (!buf || buf.byteLength === 0) {
        throw new Error('empty body')
      }
      this.writeBinaryFile(filePath, buf)
    } finally {
      httpRequest.destroy()
    }
  }

  // ==================== 统计/清理 ====================

  /** 当前缓存总大小（字节，含歌曲/图片/歌词）。 */
  public async getTotalSize(): Promise<number> {
    const dir = this.getCacheDir()
    let total = 0
    try {
      if (!fs.accessSync(dir)) {
        return 0
      }
      const files: string[] = await fs.listFile(dir)
      for (const f of files) {
        if (f === AudioCacheHelper.INDEX_FILE) {
          continue
        }
        try {
          total += fs.statSync(`${dir}/${f}`).size
        } catch (e) {
          // 单个文件统计失败，跳过
        }
      }
    } catch (e) {
      // 目录不存在或读取失败
    }
    return total
  }

  /** 当前缓存歌曲数量。 */
  public getCachedSongCount(): number {
    this.loadIndex()
    return this.indexMap.size
  }

  /** 清除全部缓存文件与索引。 */
  public async clearAll(): Promise<void> {
    this.indexMap.clear()
    this.loaded = true
    const dir = this.getCacheDir()
    try {
      if (fs.accessSync(dir)) {
        const files: string[] = await fs.listFile(dir)
        for (const f of files) {
          try {
            fs.unlinkSync(`${dir}/${f}`)
          } catch (e) {
            // 忽略单个删除失败
          }
        }
      }
    } catch (e) {
      Logger.warn(`${TAG}: clearAll failed ${JSON.stringify(e)}`)
    }
    Logger.info(`${TAG}: clearAll done`)
  }
}
