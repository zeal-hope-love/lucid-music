/*
 * Lucid Music - 搜索页面 ViewModel
 * 搜索页VM：管理历史/热门、联想建议、跳转结果页
 */
import { Logger } from 'musicbasic'
import { SuggestionItem, SuggestionType } from '../model/SuggestionItem'

const TAG = 'SearchViewModel'

export enum SearchState {
  HOT = 'hot',
  SUGGESTING = 'suggesting',
  RESULT = 'result'
}

@ObservedV2
export class SearchViewModel {
  @Trace keyword: string = ''
  @Trace currentState: SearchState = SearchState.HOT
  @Trace suggestions: SuggestionItem[] = []
  @Trace hotSearches: string[] = ['周杰伦', '邓紫棋', '林俊杰', '陈奕迅', 'Taylor Swift', 'IU']
  @Trace searchHistory: string[] = []

  private maxHistoryCount: number = 10

  /**
   * 更新关键词并触发联想建议
   */
  public updateKeyword(keyword: string): void {
    this.keyword = keyword
    if (keyword.trim().length === 0) {
      this.currentState = SearchState.HOT
      this.suggestions = []
    } else {
      this.currentState = SearchState.SUGGESTING
      this.fetchSuggestions(keyword)
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
   * 获取联想建议（mock实现）
   */
  private fetchSuggestions(keyword: string): void {
    // mock 联想建议
    const mockSuggestions: SuggestionItem[] = [
      new SuggestionItem(`${keyword} - 歌曲`, SuggestionType.SONG, keyword),
      new SuggestionItem(`${keyword}现场版`, SuggestionType.SONG, keyword),
      new SuggestionItem(`${keyword}remix`, SuggestionType.SONG, keyword),
      new SuggestionItem(`${keyword}伴奏`, SuggestionType.SONG, keyword),
      new SuggestionItem(`${keyword} - 歌手`, SuggestionType.ARTIST, keyword),
      new SuggestionItem(`${keyword}专辑`, SuggestionType.ALBUM, keyword),
    ]
    this.suggestions = mockSuggestions
  }
}
