/*
 * SearchResultItem - 搜索结果数据模型
 * 对齐 lx-music-mobile 和 MusicHome 的数据结构
 */
@ObservedV2
export class SearchResultItem {
  // 核心展示字段
  @Trace title: string = ''
  @Trace singer: string = ''
  @Trace album: string = ''
  @Trace quality: string = ''
  @Trace duration: string = ''
  @Trace cover: string = ''
  @Trace coverUrl: string = ''

  // 平台标识
  @Trace source: string = ''
  @Trace songId: string = ''

  // 兼容旧字段
  @Trace id: number = 0
  @Trace url: string = ''

  // 原始 API 返回数据（用于后续播放等操作）
  public rawFields: Record<string, Object> = {}
}
