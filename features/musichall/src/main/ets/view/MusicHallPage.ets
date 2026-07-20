/*
 * Lucid Music - 音乐厅页面
 * 布局：标题（滑动渐隐）+ 吸顶平台 Tab 栏 + 3 列歌单网格 + 标签筛选 BindSheet。
 * 底部 MiniPlayerBar + LucidTabBar 已提取到 Index.ets 统一管理。
 */
import { Platform, PlatformLabels, MusichallPlaylistItem, TagFilterGroup, ApiSource, Logger, RouterUrlConstants, SongListParam } from 'musicbasic'
import { SourceTabBar } from './SourceTabBar'
import { PlaylistCard } from './PlaylistCard'
import { TagFilterSheet } from './TagFilterSheet'
import { PlaylistOpenModal } from './PlaylistOpenModal'

/** 顶部吸顶栏尺寸常量 */
const HEADER_SAFE_TOP: number = 64   // 状态栏安全间距
const HEADER_TAB_H: number = 48      // 平台切换栏高度

@ComponentV2
export struct MusicHallPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Local playlists: MusichallPlaylistItem[] = []
  @Local tagGroups: TagFilterGroup[] = []
  @Local activeSource: string = Platform.KW
  @Local activeTagId: string = ''
  @Local isTagSheetVisible: boolean = false
  /** 标题透明度（上滑渐隐） */
  @Local titleOpacity: number = 1
  /** 标题高度（56vp → 0vp 收缩，推动平台栏上移） */
  @Local titleSpace: number = 56
  /** 动态顶部高度（标题收缩时平台栏上移） */
  @Computed
  get headerHeight(): number {
    return HEADER_SAFE_TOP + this.titleSpace + HEADER_TAB_H
  }
  /** 排序选中索引，默认推荐 */
  @Local activeSortIndex: number = 0
  /** 加载状态：true=加载中，false=加载完成 */
  @Local isLoading: boolean = true
  /** 错误信息：空字符串表示无错误 */
  @Local errorMessage: string = ''
  /** 当前分页（0-indexed），用于触底加载下一页 */
  @Local currentPage: number = 0
  /** 是否还有更多页（接口返回 hasMore 驱动） */
  @Local hasMore: boolean = true
  /** 是否正在加载更多（触底加载中，防止重复触发） */
  @Local isLoadingMore: boolean = false
  readonly sortOptions: string[] = ['推荐', '热门', '最新', '收藏']

  aboutToAppear(): void {
    this.loadData()
  }

  /** 打开歌单弹窗：每次重建 controller 确保 source/平台标签取当前值 */
  private onOpenPlaylistDialog(): void {
    this._playlistDialogCtrl = new CustomDialogController({
      builder: PlaylistOpenModal({
        sourceLabel: PlatformLabels[this.activeSource as Platform] || this.activeSource,
        onSubmit: (id: string): void => {
          const param = new SongListParam('歌单详情', '', id, this.activeSource)
          this.navPathStack.pushPath(
            new NavPathInfo(RouterUrlConstants.PLAYLIST_DETAIL, param), { animated: false }
          )
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    })
    this._playlistDialogCtrl.open()
  }
  private _playlistDialogCtrl: CustomDialogController | null = null

  /** 排序索引 → 接口 order 参数（网易云 hot/new；酷我 hot/new；QQ 最热/最新） */
  private getOrderFromSort(): string {
    switch (this.activeSortIndex) {
      case 1: return 'hot'   // 热门
      case 2: return 'new'   // 最新
      default: return ''     // 推荐 / 收藏：平台默认
    }
  }

  private async loadData(): Promise<void> {
    const order = this.getOrderFromSort()
    Logger.info('MusicHallPage', `loadData enter | source=${this.activeSource} | tag=${this.activeTagId} | order=${order}`)
    this.isLoading = true
    this.errorMessage = ''
    this.currentPage = 0
    this.hasMore = true
    try {
      const loadResults = await Promise.all([
        ApiSource.getPlaylists(this.activeSource, this.activeTagId, 0, 30, order),
        ApiSource.getPlaylistTags(this.activeSource)
      ])
      const apiPlaylists = loadResults[0]
      const apiTagGroups = loadResults[1]
      const items = (apiPlaylists && apiPlaylists.items) ? apiPlaylists.items : []
      this.playlists = items
      this.hasMore = (apiPlaylists && apiPlaylists.hasMore) ? apiPlaylists.hasMore : false
      this.tagGroups = (apiTagGroups && apiTagGroups.length > 0) ? apiTagGroups : []
      Logger.info('MusicHallPage', `loadData done | playlists=${this.playlists.length} | hasMore=${this.hasMore} | tags=${this.tagGroups.length}`)
    } catch (error) {
      Logger.error('MusicHallPage', `loadData error: ${JSON.stringify(error)}`)
      if (this.playlists.length === 0 && this.tagGroups.length === 0) {
        this.errorMessage = '加载失败，请检查网络后重试'
      }
    } finally {
      this.isLoading = false
    }
  }

  private onTagSelect(tagId: string): void {
    this.activeTagId = tagId
    this.isTagSheetVisible = false
    this.loadData()
  }

  /** 触底加载下一页并追加到列表 */
  private async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore || this.isLoading) { return }
    this.isLoadingMore = true
    const nextPage = this.currentPage + 1
    const order = this.getOrderFromSort()
    Logger.info('MusicHallPage', `loadMore enter | page=${nextPage} | source=${this.activeSource} | tag=${this.activeTagId}`)
    try {
      const page = await ApiSource.getPlaylists(this.activeSource, this.activeTagId, nextPage, 30, order)
      const items = (page && page.items) ? page.items : []
      if (items.length > 0) {
        this.playlists = [...this.playlists, ...items]
        this.currentPage = nextPage
      }
      this.hasMore = (page && page.hasMore) ? page.hasMore : false
      Logger.info('MusicHallPage', `loadMore done | appended=${items.length} | total=${this.playlists.length} | hasMore=${this.hasMore}`)
    } catch (e) {
      Logger.error('MusicHallPage', `loadMore error: ${JSON.stringify(e)}`)
    } finally {
      this.isLoadingMore = false
    }
  }

  private onGridScroll(firstIndex: number): void {
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
        this.loadData()
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // === LAYER 1: 滚动内容（位于顶部浮层下方） ===
      Column() {
        if (this.isLoading) {
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
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.errorMessage) {
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
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.playlists.length === 0) {
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
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Grid() {
            ForEach(this.playlists, (item: MusichallPlaylistItem) => {
              GridItem() {
                PlaylistCard({ item: item })
              }
            }, (item: MusichallPlaylistItem): string => `${item.playlistId}`)

            if (this.isLoadingMore) {
              GridItem() {
                Column() {
                  LoadingProgress()
                    .width(28)
                    .height(28)
                  Text('加载中...')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 8 })
                }
                .width('100%')
                .height(60)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
              }
              .columnStart(0)
              .columnEnd(2)
            } else if (!this.hasMore && this.playlists.length > 0) {
              GridItem() {
                Text('已经到底啦 ~')
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                  .width('100%')
                  .height(60)
                  .textAlign(TextAlign.Center)
              }
              .columnStart(0)
              .columnEnd(2)
            }
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
          .onReachEnd((): void => {
            this.loadMore()
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.headerHeight })

      // === LAYER 2: 顶部吸顶栏 ===
      Column() {
        // 状态栏占位（确保背景色从 y=0 开始连续，消除顶边白线）
        Blank().height(64)
        // 标题区
        Row() {
          Text('音乐厅')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width('90%')
        .opacity(this.titleOpacity)
        .height(this.titleSpace)
        .animation({ duration: 200, curve: Curve.EaseOut })

        // 平台切换栏 + 打开歌单按钮
        Row() {
          SourceTabBar({
            activeSource: this.activeSource,
            onSourceChange: (source: string): void => {
              this.activeSource = source
              this.activeTagId = ''
              this.activeSortIndex = 0
              this.loadData()
            },
            onFilterClick: (): void => {
              this.isTagSheetVisible = true
            }
          })
            .layoutWeight(1)

          Button() {
            SymbolGlyph($r('sys.symbol.plus_square_on_square'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }
          .buttonStyle(ButtonStyleMode.NORMAL)
          .width(36)
          .height(36)
          .borderRadius(8)
          .onClick(() => {
            this.onOpenPlaylistDialog()
          })
        }
        .width('100%')
        .padding({ left: 18, right: 18 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(this.headerHeight)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
