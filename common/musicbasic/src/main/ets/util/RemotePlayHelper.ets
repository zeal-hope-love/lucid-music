/*
 * RemotePlayHelper - 远程歌曲播放共享逻辑
 * 统一「取流 → 设 PlaybackIntentState → 打开播放器」流程，
 * 供搜索结果、音乐厅歌单详情等需要播放真实歌曲的模块复用。
 * 取流优先级：JSVM 音源脚本（AudioSourceExecutor）优先，直接 API（ApiSource.getPlayUrl）兜底。
 */
import { AppStorageV2 } from '@kit.ArkUI'
import {
  Logger, PlaybackIntentState, MusicAppState, AppStorageKeys, ApiSource, AudioSourceExecutor, SearchResultItem, SongItem, findMusicList
} from 'musicbasic'
import type { PlayUrlResult } from 'musicbasic'

const TAG = 'RemotePlayHelper'

/** 取流结果包：音频地址 + 歌词 + 封面（具名 class，规避 ArkTS 匿名对象字面量限制） */
class PlayUrlBundle {
  url: string = ''
  lyrics: string = ''
  cover: string = ''
}

export class RemotePlayHelper {
  private static appState: MusicAppState | undefined = undefined
  private static intentState: PlaybackIntentState | undefined = undefined

  private static ensure(): void {
    if (!RemotePlayHelper.appState) {
      RemotePlayHelper.appState =
        AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
    }
    if (!RemotePlayHelper.intentState) {
      RemotePlayHelper.intentState =
        AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE,
          () => new PlaybackIntentState())!
    }
  }

  /**
   * 播放一首远程歌曲（真实取流）。
   * @param item 来自 musicSdk 的搜索/歌单歌曲项，需包含 songId、source、rawFields。
   */
  public static async playSong(item: SearchResultItem): Promise<void> {
    RemotePlayHelper.ensure()
    const appState = RemotePlayHelper.appState!
    const intentState = RemotePlayHelper.intentState!
    Logger.info(`${TAG}: playSong id=${item.songId} title=${item.title} source=${item.source}`)

    // 更新状态：正在请求播放地址
    appState.playbackStatus = 'requesting_url'
    appState.playbackStatusMessage = '正在请求播放地址...'
    AppStorage.setOrCreate('playbackStatus', 'requesting_url')
    AppStorage.setOrCreate('playbackStatusMessage', '正在请求播放地址...')
    intentState.remoteSongName = item.title as string
    intentState.remoteSongSinger = item.singer as string
    intentState.remoteSongCover = item.coverUrl || item.cover
    // 传递平台与歌曲 ID，供落盘缓存构造 cacheKey（platform_remoteSongId）
    intentState.remotePlatform = item.source
    intentState.remoteSongId = item.songId
    Logger.info(`${TAG}: playSong cover from item: ${(item.coverUrl || item.cover).substring(0, 50)}, source=${item.source}`)

    // 换源/取流中间态回调：同步到 playbackStatus 供 UI 显示
    const onProgress = (status: string, message: string): void => {
      appState.playbackStatus = status
      appState.playbackStatusMessage = message
      AppStorage.setOrCreate('playbackStatus', status)
      AppStorage.setOrCreate('playbackStatusMessage', message)
    }

    try {
      // === 取流（含跨平台换源回退）：JSVM 优先 + 直接 API 兜底 ===
      const result = await RemotePlayHelper.resolveUrlWithFallback(
        item.source, item.songId, item.title, item.singer, onProgress, item.rawFields)
      if (result) {
        intentState.remoteUrl = result.url
        if (result.lyrics) {
          intentState.remoteLyricText = result.lyrics
        }
        if (result.cover) {
          intentState.remoteSongCover = result.cover
        }
        // 独立歌词获取 + 换源（非阻塞，音频先响；命中后以更可靠歌词覆盖）
        void RemotePlayHelper.getLyricsWithFallback(
          item.source, item.songId, item.title, item.singer, item.rawFields)
          .then((l: string) => {
            if (l) {
              intentState.remoteLyricText = l
            }
          })
      } else {
        Logger.warn(`${TAG}: playUrl empty for ${item.songId}@${item.source}`)
      }

      // 检查是否获取到 URL
      if (!intentState.remoteUrl) {
        appState.playbackStatus = 'error'
        appState.playbackStatusMessage = '获取播放地址失败'
        AppStorage.setOrCreate('playbackStatus', 'error')
        AppStorage.setOrCreate('playbackStatusMessage', '获取播放地址失败')
        intentState.remoteUrl = ''
      }
    } catch (e) {
      Logger.error(`${TAG}: getPlayUrl error ${JSON.stringify(e)}`)
      appState.playbackStatus = 'error'
      appState.playbackStatusMessage = '请求播放地址异常'
      AppStorage.setOrCreate('playbackStatus', 'error')
      AppStorage.setOrCreate('playbackStatusMessage', '请求播放地址异常')
      intentState.remoteUrl = ''
    } finally {
      intentState.openPlayerUi = true
      intentState.requestVersion++
    }
  }

  /**
   * 独立歌词获取 + 跨平台换源回退（对齐 lx-music-mobile handleGetOnlineLyricInfo）。
   * 先调各平台专用 getLyrics（酷狗用歌名作 songName，比 rawFields['SongName'] 可靠）；
   * 结果为空或无效时跨平台搜同名歌，逐个换源取歌词，返回首个有效 LRC。
   * 永不抛异常，失败返回 ''（由上层决定是否保留原歌词）。
   */
  private static async getLyricsWithFallback(
    platform: string,
    songId: string,
    title: string,
    singer: string,
    rawFields: Record<string, Object> = {}
  ): Promise<string> {
    // 1. 原平台专用歌词 API（酷狗传 title 作 songName，规避 rawFields['SongName'] 为空的根因）
    let lyrics = await ApiSource.getLyrics(songId, platform, title)
    if (RemotePlayHelper.looksLikeLyric(lyrics)) {
      Logger.info(`${TAG}: getLyrics hit primary source=${platform}`)
      return lyrics
    }
    // 2. 跨平台换源：搜同名歌逐个试歌词
    Logger.warn(`${TAG}: lyrics empty/invalid on ${platform}, try other sources`)
    let candidates: SearchResultItem[] = []
    try {
      candidates = await findMusicList({ name: title, singer: singer, source: platform, songId: songId }, 3)
    } catch (e) {
      Logger.error(`${TAG}: findMusicList(lyric) error ${JSON.stringify(e)}`)
    }
    const retryedSource: string[] = [platform]
    for (const cand of candidates) {
      if (!cand.source || !cand.songId) {
        continue
      }
      if (retryedSource.includes(cand.source)) {
        continue
      }
      retryedSource.push(cand.source)
      const l = await ApiSource.getLyrics(cand.songId, cand.source, cand.title)
      if (RemotePlayHelper.looksLikeLyric(l)) {
        Logger.info(`${TAG}: getLyrics fallback ${platform} -> ${cand.source}`)
        return l
      }
    }
    Logger.warn(`${TAG}: all lyric sources failed for ${songId}@${platform}`)
    return ''
  }

  /** 轻量校验：是否像有效 LRC（含 [mm:ss 时间戳），对齐 lx existTimeExp 校验 */
  private static looksLikeLyric(text: string): boolean {
    if (!text || text.length < 4) {
      return false
    }
    return /\[\d{1,2}:\d{2}/.test(text)
  }

  /**
   * 为队列中的在线歌曲现取流：JSVM 音源脚本优先，直接 API 兜底；
   * 原平台失败自动跨平台换源回退。命中后回填歌词/封面（若歌曲上原本为空），返回播放 URL；失败返回 null。
   * @param song 队列内歌曲，需含 platform + remoteSongId。
   * @param onProgress 取流/换源中间态回调（如更新 playbackStatus）。
   */
  public static async resolveUrlForQueue(
    song: SongItem,
    onProgress?: (status: string, message: string) => void
  ): Promise<string | null> {
    if (!song.platform || !song.remoteSongId) {
      return null
    }
    const title: string = (typeof song.title === 'string') ? song.title : (song.title?.toString() || '')
    const singer: string = (typeof song.singer === 'string') ? song.singer : (song.singer?.toString() || '')
    const result = await RemotePlayHelper.resolveUrlWithFallback(
      song.platform, song.remoteSongId, title, singer, onProgress)
    if (result) {
      if (result.lyrics && !song.lyricText) {
        song.lyricText = result.lyrics
      }
      if (result.cover && !song.coverUrl) {
        song.coverUrl = result.cover
      }
      // 独立歌词获取 + 换源（非阻塞，音频先响；命中后以更可靠歌词覆盖）
      void RemotePlayHelper.getLyricsWithFallback(song.platform, song.remoteSongId, title, singer)
        .then((l: string) => {
          if (l) {
            song.lyricText = l
          }
        })
      return result.url
    }
    return null
  }

  /**
   * 单平台取流：JSVM 音源脚本优先，直接 API 兜底。
   * 返回 { url, lyrics, cover } 或 null（取不到/异常）。
   */
  private static async tryGetUrl(
    platform: string,
    songId: string,
    rawFields: Record<string, Object>
  ): Promise<PlayUrlBundle | null> {
    try {
      const jsvmResult = await AudioSourceExecutor.getInstance().getPlayUrl(songId, platform)
      if (jsvmResult && jsvmResult.url) {
        const bundle = new PlayUrlBundle()
        bundle.url = jsvmResult.url
        bundle.lyrics = jsvmResult.lyrics
        bundle.cover = jsvmResult.cover
        return bundle
      }
      const result: PlayUrlResult = await ApiSource.getPlayUrl(songId, platform, rawFields)
      if (result.url) {
        const bundle = new PlayUrlBundle()
        bundle.url = result.url
        bundle.lyrics = result.lyrics
        bundle.cover = result.cover
        return bundle
      }
      return null
    } catch (e) {
      Logger.error(`${TAG}: tryGetUrl error ${platform}/${songId} ${JSON.stringify(e)}`)
      return null
    }
  }

  /**
   * 取流编排：先走原平台（JSVM 优先 + API 兜底），失败则跨平台换源回退。
   * 对齐 lx-music-mobile：原源失败 → 跨平台搜同名歌 → 逐个换源重试，
   * 通过 onProgress 上报「正在更换音源...」「重新获取播放链接...」中间态。
   * 仅当所有候选源都失败才返回 null。
   */
  private static async resolveUrlWithFallback(
    platform: string,
    songId: string,
    title: string,
    singer: string,
    onProgress?: (status: string, message: string) => void,
    primaryRawFields: Record<string, Object> = {}
  ): Promise<PlayUrlBundle | null> {
    // 1. 原平台：JSVM 优先 + 直接 API 兜底
    const primary = await RemotePlayHelper.tryGetUrl(platform, songId, primaryRawFields)
    if (primary) {
      return primary
    }
    // 2. 跨平台换源回退
    Logger.warn(`${TAG}: primary source ${platform}/${songId} failed, try switching source`)
    if (onProgress) {
      onProgress('switching_source', '正在更换音源...')
    }
    let candidates: SearchResultItem[] = []
    try {
      candidates = await findMusicList({ name: title, singer: singer, source: platform, songId: songId }, 3)
    } catch (e) {
      Logger.error(`${TAG}: findMusicList error ${JSON.stringify(e)}`)
    }
    const retryedSource: string[] = [platform]
    for (const cand of candidates) {
      if (!cand.source || !cand.songId) {
        continue
      }
      if (retryedSource.includes(cand.source)) {
        continue
      }
      retryedSource.push(cand.source)
      if (onProgress) {
        onProgress('switching_source', '重新获取播放链接...')
      }
      const result = await RemotePlayHelper.tryGetUrl(cand.source, cand.songId, cand.rawFields)
      if (result) {
        Logger.info(`${TAG}: fallback success ${platform} -> ${cand.source}`)
        return result
      }
    }
    Logger.warn(`${TAG}: all sources failed for ${songId}`)
    return null
  }
}
