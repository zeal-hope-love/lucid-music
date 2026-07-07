/*
 * Lucid Music - 搜索结果 ViewModel
 * 结果页VM：管理搜索结果、触发播放/队列操作
 */
import { Logger, PlaybackIntentState, MusicAppState, AppStorageKeys } from 'musicbasic'
import { AppStorageV2 } from '@kit.ArkUI'
import { SearchResultItem } from '../model/SearchResultItem'

const TAG = 'SearchResultViewModel'

@ObservedV2
export class SearchResultViewModel {
  @Trace keyword: string = ''
  @Trace results: SearchResultItem[] = []
  @Trace isLoading: boolean = false

  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  private intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!

  /**
   * 执行搜索
   */
  public async doSearch(keyword: string): Promise<void> {
    this.keyword = keyword
    this.isLoading = true
    Logger.info(`${TAG}: doSearch keyword=${keyword}`)

    // mock 搜索结果（后续接入 AudioSourceManager）
    const mockResults: SearchResultItem[] = []
    for (let i = 0; i < 15; i++) {
      const item = new SearchResultItem()
      item.id = 1000 + i
      item.title = `${keyword}${i > 0 ? ` - 版本${i}` : ''}`
      item.singer = i % 3 === 0 ? '周杰伦' : i % 3 === 1 ? '邓紫棋' : '林俊杰'
      mockResults.push(item)
    }
    this.results = mockResults
    this.isLoading = false
  }

  /**
   * 触发播放指定歌曲
   */
  public playSong(item: SearchResultItem): void {
    Logger.info(`${TAG}: playSong id=${item.id}`)
    this.intentState.pendingPlaySongId = item.id
    this.intentState.openPlayerUi = true
    this.intentState.requestVersion++
  }

  /**
   * 添加到下一首播放
   */
  public playNext(item: SearchResultItem): void {
    Logger.info(`${TAG}: playNext id=${item.id}`)
    // 后续实现队列插入逻辑
  }

  /**
   * 设置为稍后播放
   */
  public playLater(item: SearchResultItem): void {
    Logger.info(`${TAG}: playLater id=${item.id}`)
    // 后续实现添加到队列末尾
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
