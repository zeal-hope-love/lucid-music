/*
 * SearchPageExtraInfo - 搜索页面间参数传递
 */
export class SearchPageExtraInfo {
  public geometryId: string = ''
  public onBackClicked: (() => void) | null = null
}
