/*
 * Lucid Music - 音乐厅页面
 * 布局：标题（滑动渐隐）+ 吸顶平台 Tab 栏 + 3 列歌单网格 + 标签筛选 BindSheet。
 * 底部 MiniPlayerBar + LucidTabBar 已提取到 Index.ets 统一管理。
 */
import { Platform, PlatformLabels, MusichallPlaylistItem, TagFilterGroup, MusicDbApi, ApiSource } from 'musicbasic'
import { SourceTabBar } from './SourceTabBar'
import { PlaylistCard } from './PlaylistCard'
import { TagFilterSheet } from './TagFilterSheet'

@ComponentV2
export struct MusicHallPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Local playlists: MusichallPlaylistItem[] = []
  @Local tagGroups: TagFilterGroup[] = []
  @Local activeSource: string = Platform.KW
  @Local activeTagId: string = ''
  @Local isTagSheetVisible: boolean = false
  /** 标题透明度：0=完全隐藏，1=完全显示 */
  @Local titleOpacity: number = 1
  /** 标题高度：56vp 显示，0vp 隐藏 */
  @Local titleSpace: number = 56
  /** 排序选中索引，默认推荐 */
  @Local activeSortIndex: number = 0
  /** 加载状态：true=加载中，false=加载完成 */
  @Local isLoading: boolean = true
  /** 错误信息：空字符串表示无错误 */
  @Local errorMessage: string = ''
  readonly sortOptions: string[] = ['推荐', '热门', '最新', '收藏']
  private allPlaylists: MusichallPlaylistItem[] = []

  aboutToAppear(): void {
    this.loadData()
  }

  private async loadData(): Promise<void> {
    this.isLoading = true
    this.errorMessage = ''
    
    try {
      // 优先调用真实 API
      const apiPlaylists = await ApiSource.getPlaylists(this.activeSource, this.activeTagId, 0, 30)
      const apiTagGroups = await ApiSource.getPlaylistTags(this.activeSource)
      
      if (apiPlaylists && apiPlaylists.length > 0) {
        this.allPlaylists = apiPlaylists
        console.info('MusicHallPage: loaded real API playlists:', apiPlaylists.length)
      } else {
        // API 返回空，回退到本地数据
        console.warn('MusicHallPage: API returned empty, fallback to local data')
        const api = MusicDbApi.getInstance()
        this.allPlaylists = api.getMusichallPlaylists()
      }
      
      if (apiTagGroups && apiTagGroups.length > 0) {
        this.tagGroups = apiTagGroups
        console.info('MusicHallPage: loaded real API tagGroups:', apiTagGroups.length)
      } else {
        // API 返回空，回退到本地数据
        console.warn('MusicHallPage: API tagGroups returned empty, fallback to local data')
        const api = MusicDbApi.getInstance()
        this.tagGroups = api.getMusichallTagGroups()
      }
      
      this.applyFilter()
    } catch (error) {
      console.error('MusicHallPage: loadData error:', error)
      this.errorMessage = '网络加载失败，使用本地数据'
      // 即使出错，也尝试使用本地数据
      const api = MusicDbApi.getInstance()
      this.allPlaylists = api.getMusichallPlaylists()
      this.tagGroups = api.getMusichallTagGroups()
      this.applyFilter()
    } finally {
      this.isLoading = false
    }
  }

  private applyFilter(): void {
    if (this.activeTagId === '') {
      this.playlists = [...this.allPlaylists]
    } else {
      this.playlists = this.allPlaylists.filter((item: MusichallPlaylistItem): boolean =>
      item.tags.indexOf(this.activeTagId) !== -1
      )
    }
  }

  private onTagSelect(tagId: string): void {
    this.activeTagId = tagId
    this.applyFilter()
    this.isTagSheetVisible = false
  }

  private onGridScroll(firstIndex: number): void {
    // 滚动超过 1 行（3 个卡片后）渐隐标题
    const shouldHide: boolean = firstIndex >= 3
    this.titleOpacity = shouldHide ? 0 : 1
    this.titleSpace = shouldHide ? 0 : 56
  }

  /** BindSheet 的 Builder 包装（CustomBuilder 类型要求） */
  @Builder
  tagSheetBuilder() {
    TagFilterSheet({
      tagGroups: this.tagGroups,
      activeTagId: this.activeTagId,
      sortOptions: this.sortOptions,
      activeSortIndex: this.activeSortIndex,
      onTagSelect: (tagId: string): void => {
        this.onTagSelect(tagId)
      },
      onSortChange: (index: number): void => {
        this.activeSortIndex = index
      }
    })
  }

  build() {
    Column() {
      // === 标题区（滑动渐隐） ===
      Column() {
        Row() {
          Text('音乐厅')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width('90%')
      }
      .width('100%')
      .margin({ top: 64 })
      .opacity(this.titleOpacity)
      .height(this.titleSpace)
      .animation({ duration: 200, curve: Curve.EaseOut })

      // === 吸顶 Tab 栏 ===
      SourceTabBar({
        activeSource: this.activeSource,
        onSourceChange: (source: string): void => {
          this.activeSource = source
          this.activeTagId = ''
          // 预留：后续切换平台时重新拉取数据
        },
        onFilterClick: (): void => {
          this.isTagSheetVisible = true
        }
      })
        .padding({ left: 18 })

      // === 3 列歌单网格 ===
      if (this.isLoading) {
        // 加载中状态
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
      } else if (this.errorMessage) {
        // 错误状态
        Column() {
          Image($r('app.media.ic_avatar1'))
            .width(48)
            .height(48)
          Text(this.errorMessage)
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 12 })
          Button('重试')
            .margin({ top: 16 })
            .onClick(() => {
              this.loadData()
            })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
      } else if (this.playlists.length === 0) {
        // 空状态
        Column() {
          Image($r('app.media.ic_avatar1'))
            .width(64)
            .height(64)
          Text('暂无歌单')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
      } else {
        // 正常显示歌单网格
        Grid() {
          ForEach(this.playlists, (item: MusichallPlaylistItem) => {
            GridItem() {
              PlaylistCard({ item: item })
            }
          }, (item: MusichallPlaylistItem): string => `${item.playlistId}`)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(16)
        .width('100%')
        .padding({ left: 18, right: 18 })
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onScrollIndex((first: number): void => {
          this.onGridScroll(first)
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ bottom: 160 })
    // === 标签筛选 BindSheet ===
    .bindSheet($$this.isTagSheetVisible, this.tagSheetBuilder,
      {
        height: SheetSize.MEDIUM,
        showClose: true,
        backgroundColor: $r('sys.color.ohos_id_color_sub_background')
      }
    )
  }
}
