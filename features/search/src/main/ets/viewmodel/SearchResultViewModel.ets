/*
 * Lucid Music - 搜索结果 ViewModel
 * 结果页VM：管理搜索结果、触发播放/队列操作
 * 搜索结果接入 MusicApiService 真实 API
 */
import { Logger, PlaybackIntentState, MusicAppState, AppStorageKeys } from 'musicbasic'
import { AppStorageV2 } from '@kit.ArkUI'
import { SearchResultItem } from '../model/SearchResultItem'
import { MusicApiService } from '../service/MusicApiService'
import type { PlayUrlResult } from '../service/MusicApiService'
import { AudioSourceExecutor } from '../service/AudioSourceExecutor'

import { DEFAULT_PLATFORM_TABS, PlatformTab, SearchPlatform } from './SearchViewModel'

const TAG = 'SearchResultViewModel'

@ObservedV2
export class SearchResultViewModel {
  @Trace keyword: string = ''
  @Trace results: SearchResultItem[] = []
  @Trace isLoading: boolean = false
  @Trace currentPlatform: SearchPlatform = SearchPlatform.KUGOU
  @Trace platforms: PlatformTab[] = DEFAULT_PLATFORM_TABS

  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  private intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE,
      () => new PlaybackIntentState())!

  /**
   * 执行搜索（调用真实 API）
   */
  public async doSearch(keyword: string): Promise<void> {
    this.keyword = keyword
    this.clearResults()
    Logger.info(`${TAG}: doSearch keyword=${keyword} platform=${this.currentPlatform}`)

    try {
      const apiResults = await MusicApiService.search(keyword, this.currentPlatform, 1, 30)
      Logger.info(`${TAG}: doSearch result count=${apiResults.length}`)
      this.results = apiResults
    } catch (e) {
      Logger.error(`${TAG}: doSearch error: ${JSON.stringify(e)}`)
      this.results = []
    } finally {
      this.isLoading = false
    }
  }

  /**
   * 立即清空结果和加载态（平台切换时使用）
   */
  public clearResults(): void {
    this.results = []
    this.isLoading = true
  }

  /**
   * 触发播放指定歌曲（JSVM 音源脚本优先，直接 API 兜底）
   */
  public async playSong(item: SearchResultItem): Promise<void> {
    Logger.info(`${TAG}: playSong id=${item.songId} title=${item.title} source=${item.source}`)

    // 更新状态：正在请求播放地址
    this.appState.playbackStatus = 'requesting_url'
    this.appState.playbackStatusMessage = '正在请求播放地址...'
    AppStorage.setOrCreate('playbackStatus', 'requesting_url')
    AppStorage.setOrCreate('playbackStatusMessage', '正在请求播放地址...')
    this.intentState.remoteSongName = item.title as string
    this.intentState.remoteSongSinger = item.singer as string
    this.intentState.remoteSongCover = item.coverUrl || item.cover
    Logger.info(`${TAG}: playSong cover from search: ${(item.coverUrl || item.cover).substring(0, 50)}, source=${item.source}`)

    try {
      // === 优先：通过 JSVM 音源脚本获取 URL ===
      const jsvmResult = await AudioSourceExecutor.getInstance().getPlayUrl(item.songId, item.source)
      Logger.info(`${TAG}: JSVM result - isNull=${jsvmResult === null}, hasUrl=${!!(jsvmResult && jsvmResult.url)}, hasLyrics=${!!(jsvmResult && jsvmResult.lyrics)}, hasCover=${!!(jsvmResult && jsvmResult.cover)}, urlLen=${jsvmResult?.url?.length ?? 0}`)
      if (jsvmResult && jsvmResult.url) {
        Logger.info(`${TAG}: JSVM playUrl obtained, length=${jsvmResult.url.length}`)
        this.intentState.remoteUrl = jsvmResult.url
        if (jsvmResult.lyrics) {
          this.intentState.remoteLyricText = jsvmResult.lyrics
        }
        if (jsvmResult.cover) {
          this.intentState.remoteSongCover = jsvmResult.cover
        }
      } else {
        // === 兜底：直接 API ===
        Logger.info(`${TAG}: JSVM unavailable, falling back to direct API`)
        const result: PlayUrlResult = await MusicApiService.getPlayUrl(item.songId, item.source, item.rawFields)
        if (result.url) {
          Logger.info(`${TAG}: API playUrl obtained, length=${result.url.length}`)
          this.intentState.remoteUrl = result.url
        } else {
          Logger.warn(`${TAG}: playUrl empty for ${item.songId}`)
        }
        Logger.info(`${TAG}: API cover result - hasCover=${!!result.cover}, coverLen=${result.cover?.length ?? 0}, coverPreview=${(result.cover || '').substring(0, 80)}`)
        if (result.lyrics) {
          this.intentState.remoteLyricText = result.lyrics
        }
        if (result.cover) {
          this.intentState.remoteSongCover = result.cover
        }
      }

      // 检查是否获取到 URL
      if (!this.intentState.remoteUrl) {
        this.appState.playbackStatus = 'error'
        this.appState.playbackStatusMessage = '获取播放地址失败'
        AppStorage.setOrCreate('playbackStatus', 'error')
        AppStorage.setOrCreate('playbackStatusMessage', '获取播放地址失败')
        this.intentState.remoteUrl = ''
      }
    } catch (e) {
      Logger.error(`${TAG}: getPlayUrl error ${JSON.stringify(e)}`)
      this.appState.playbackStatus = 'error'
      this.appState.playbackStatusMessage = '请求播放地址异常'
      AppStorage.setOrCreate('playbackStatus', 'error')
      AppStorage.setOrCreate('playbackStatusMessage', '请求播放地址异常')
      this.intentState.remoteUrl = ''
    } finally {
      this.intentState.openPlayerUi = true
      this.intentState.requestVersion++
    }
  }

  /**
   * 添加到下一首播放
   */
  public playNext(item: SearchResultItem): void {
    Logger.info(`${TAG}: playNext id=${item.songId}`)
    // 后续接入播放队列时实现
  }

  /**
   * 设置为稍后播放
   */
  public playLater(item: SearchResultItem): void {
    Logger.info(`${TAG}: playLater id=${item.songId}`)
    // 后续接入播放队列时实现
  }

  /**
   * 清空结果
   */
  public clear(): void {
    this.keyword = ''
    this.results = []
    this.isLoading = false
  }
}
