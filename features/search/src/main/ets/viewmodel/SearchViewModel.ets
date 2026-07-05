/*
 * SearchViewModel - 搜索视图模型
 */
import { Logger } from 'musicbasic'
import { SearchResultItem } from '../model/SearchResultItem'
import { MusicApiService } from '../service/MusicApiService'

const TAG = 'SearchViewModel'

export class SearchViewModel {
  public keyword: string = ''
  public results: SearchResultItem[] = []

  public async search(keyword: string): Promise<void> {
    Logger.info(`${TAG}: search keyword=${keyword}`)
    this.keyword = keyword
  }

  public clear(): void {
    this.keyword = ''
    this.results = []
  }
}
