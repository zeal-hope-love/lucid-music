/*
 * Lucid Music - 搜索结果 ViewModel
 * 结果页VM：管理搜索结果、触发播放/队列操作
 * 搜索结果接入 MusicApiService 真实 API
 */
import { Logger, ApiSource, SearchResultItem, RemotePlayHelper } from 'musicbasic'

import { DEFAULT_PLATFORM_TABS, PlatformTab, SearchPlatform } from './SearchViewModel'

const TAG = 'SearchResultViewModel'

@ObservedV2
export class SearchResultViewModel {
  @Trace keyword: string = ''
  @Trace results: SearchResultItem[] = []
  @Trace isLoading: boolean = false
  @Trace currentPlatform: SearchPlatform = SearchPlatform.KUGOU
  @Trace platforms: PlatformTab[] = DEFAULT_PLATFORM_TABS

  /**
   * 执行搜索（调用真实 API）
   */
  public async doSearch(keyword: string): Promise<void> {
    this.keyword = keyword
    this.clearResults()
    Logger.info(`${TAG}: doSearch keyword=${keyword} platform=${this.currentPlatform}`)

    try {
      const apiResults = await ApiSource.search(keyword, this.currentPlatform, 1, 30)
      Logger.info(`${TAG}: doSearch result count=${apiResults.list.length}`)
      this.results = apiResults.list
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
   * 复用 musicbasic 的 RemotePlayHelper 统一远程播放流程。
   */
  public async playSong(item: SearchResultItem): Promise<void> {
    await RemotePlayHelper.playSong(item)
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
