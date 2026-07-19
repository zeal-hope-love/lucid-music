/*
 * Lucid Music - 搜索页面 ViewModel
 * 搜索页VM：管理历史/热门、联想建议、跳转结果页
 * 所有数据源接入 MusicApiService 真实 API
 */
import { Logger } from 'musicbasic'
import { SuggestionItem, SuggestionType, ApiSource } from 'musicbasic'

const TAG = 'SearchViewModel'

export enum SearchState {
  HOT = 'hot',
  SUGGESTING = 'suggesting',
  RESULT = 'result'
}

/** 音乐搜索平台 */
export enum SearchPlatform {
  KUGOU = 'kugou',
  QQ = 'qq',
  NETEASE = 'netease',
  KUWO = 'kuwo',
  MIGU = 'migu'
}

/** 平台 Tab 数据（名称 + 枚举值） */
export interface PlatformTab {
  name: string
  platform: SearchPlatform
}

/** 默认平台 Tab 列表（排序：酷狗 → QQ → 网易云 → 酷我 → 咪咕） */
export const DEFAULT_PLATFORM_TABS: PlatformTab[] = [
  { name: '酷狗', platform: SearchPlatform.KUGOU },
  { name: 'QQ', platform: SearchPlatform.QQ },
  { name: '网易云', platform: SearchPlatform.NETEASE },
  { name: '酷我', platform: SearchPlatform.KUWO },
  { name: '咪咕', platform: SearchPlatform.MIGU }
]

@ObservedV2
export class SearchViewModel {
  @Trace keyword: string = ''
  @Trace currentState: SearchState = SearchState.HOT
  @Trace suggestions: SuggestionItem[] = []
  @Trace hotSearches: string[] = []
  @Trace searchHistory: string[] = []
  @Trace currentPlatform: SearchPlatform = SearchPlatform.KUGOU
  @Trace platforms: PlatformTab[] = DEFAULT_PLATFORM_TABS
  @Trace hotSearchExpanded: boolean = false

  private maxHistoryCount: number = 10
  private suggestTimer: number = -1
  private readonly SUGGEST_DEBOUNCE_MS: number = 300

  /**
   * 初始化热门搜索（页面首次加载时调用）
   */
  public async initHotSearches(): Promise<void> {
    Logger.info(`${TAG}: initHotSearches platform=${this.currentPlatform}`)
    try {
      const hots = await ApiSource.hotSearch(this.currentPlatform)
      if (hots && hots.length > 0) {
        this.hotSearches = hots
        Logger.info(`${TAG}: hotSearches loaded count=${hots.length}`)
      } else {
        // 如果当前平台热搜为空，回退到网易云热搜
        if (this.currentPlatform !== SearchPlatform.NETEASE) {
          const wyHots = await ApiSource.hotSearch(SearchPlatform.NETEASE)
          if (wyHots && wyHots.length > 0) {
            this.hotSearches = wyHots
          } else {
            this.hotSearches = ApiSource.defaultHotSearches()
          }
        } else {
          this.hotSearches = ApiSource.defaultHotSearches()
        }
      }
    } catch (e) {
      Logger.error(`${TAG}: initHotSearches error: ${JSON.stringify(e)}`)
      this.hotSearches = ApiSource.defaultHotSearches()
    }
  }

  /**
   * 平台切换时刷新热门搜索
   */
  public async refreshHotSearches(): Promise<void> {
    Logger.info(`${TAG}: refreshHotSearches platform=${this.currentPlatform}`)
    this.hotSearchExpanded = false
    try {
      const hots = await ApiSource.hotSearch(this.currentPlatform)
      if (hots && hots.length > 0) {
        this.hotSearches = hots
        Logger.info(`${TAG}: refreshHotSearches loaded count=${hots.length}`)
      } else {
        // 切换到的平台热搜为空，尝试网易云降级
        if (this.currentPlatform !== SearchPlatform.NETEASE) {
          const wyHots = await ApiSource.hotSearch(SearchPlatform.NETEASE)
          if (wyHots && wyHots.length > 0) {
            this.hotSearches = wyHots
            Logger.info(`${TAG}: refreshHotSearches fallback to netease count=${wyHots.length}`)
          }
        }
      }
    } catch (e) {
      Logger.error(`${TAG}: refreshHotSearches error: ${JSON.stringify(e)}`)
      // 异常时保持在旧热搜，不做清空
    }
  }

  /**
   * 更新关键词并触发联想建议（带 300ms 防抖）
   */
  public updateKeyword(keyword: string): void {
    this.keyword = keyword
    if (keyword.trim().length === 0) {
      this.currentState = SearchState.HOT
      this.suggestions = []
      // 清除等待中的防抖定时器
      if (this.suggestTimer >= 0) {
        clearTimeout(this.suggestTimer)
        this.suggestTimer = -1
      }
    } else {
      this.currentState = SearchState.SUGGESTING
      this.debounceFetchSuggestions(keyword)
    }
  }

  /**
   * 从结果模式返回时恢复联想建议（搜索框有内容则显示联想）
   */
  public resumeSuggesting(): void {
    if (this.keyword.trim().length > 0) {
      this.currentState = SearchState.SUGGESTING
      this.debounceFetchSuggestions(this.keyword)
    } else {
      this.currentState = SearchState.HOT
    }
  }

  /**
   * 执行搜索，返回关键词用于跳转结果页
   */
  public doSearch(keyword?: string): string {
    const kw = keyword ?? this.keyword
    if (kw.trim().length === 0) {
      return ''
    }
    this.addToHistory(kw)
    this.currentState = SearchState.RESULT
    Logger.info(`${TAG}: doSearch keyword=${kw}`)
    return kw
  }

  /**
   * 清空搜索状态
   */
  public clear(): void {
    this.keyword = ''
    this.currentState = SearchState.HOT
    this.suggestions = []
    if (this.suggestTimer >= 0) {
      clearTimeout(this.suggestTimer)
      this.suggestTimer = -1
    }
  }

  /**
   * 添加到搜索历史
   */
  private addToHistory(keyword: string): void {
    // 去重
    this.searchHistory = this.searchHistory.filter(h => h !== keyword)
    this.searchHistory.unshift(keyword)
    if (this.searchHistory.length > this.maxHistoryCount) {
      this.searchHistory = this.searchHistory.slice(0, this.maxHistoryCount)
    }
  }

  /**
   * 清除搜索历史
   */
  public clearHistory(): void {
    this.searchHistory = []
  }

  /**
   * 防抖获取联想建议
   */
  private debounceFetchSuggestions(keyword: string): void {
    if (this.suggestTimer >= 0) {
      clearTimeout(this.suggestTimer)
    }
    this.suggestTimer = setTimeout(() => {
      this.fetchSuggestions(keyword)
    }, this.SUGGEST_DEBOUNCE_MS)
  }

  /**
   * 从真实 API 获取联想建议
   */
  private async fetchSuggestions(keyword: string): Promise<void> {
    const kw = keyword.trim()
    if (kw.length === 0) {
      return
    }
    // 确保仍处于 SUGGESTING 状态且关键词未被清空
    if (this.currentState !== SearchState.SUGGESTING || this.keyword.trim() !== kw) {
      return
    }
    Logger.info(`${TAG}: fetchSuggestions keyword=${kw} platform=kuwo`)
    try {
      const items = await ApiSource.suggest(kw, SearchPlatform.KUWO)
      // 双重检查：请求返回时关键词可能已经变了
      if (this.currentState === SearchState.SUGGESTING && this.keyword.trim() === kw) {
        if (items && items.length > 0) {
          this.suggestions = items
        } else {
          this.suggestions = []
        }
      }
    } catch (e) {
      Logger.error(`${TAG}: fetchSuggestions error: ${JSON.stringify(e)}`)
      if (this.currentState === SearchState.SUGGESTING && this.keyword.trim() === kw) {
        this.suggestions = []
      }
    }
  }
}
