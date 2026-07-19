/*
 * Lucid Music - 搜索页（覆盖层）+ 搜索结果（内嵌）
 * 顶部固定：返回键 + 搜索框
 * 下部切换：热门/联想 → 搜索结果
 * 所有数据源接入真实 API
 */
import { curves, display } from '@kit.ArkUI'
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, ColorMetrics } from '@kit.ArkUI'
import { AreaWithHdsTabBar, SearchInputArea } from 'musicbasic'
import { SearchViewModel, SearchState, PlatformTab } from '../viewmodel/SearchViewModel'
import { SearchResultViewModel } from '../viewmodel/SearchResultViewModel'
import { SearchResultItem, SuggestionItem, SuggestionType } from 'musicbasic'



@ComponentV2
export struct SearchPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Consumer() searchBackVersion: number = 0
  @Consumer() isSearchResultMode: boolean = false

  @Local viewModel: SearchViewModel = new SearchViewModel()
  @Local resultVM: SearchResultViewModel = new SearchResultViewModel()
  @Local activeResultIndex: number = -1
  @Local isResultMode: boolean = false
  @Local menuItemId: number = -1
  @Local menuVisible: boolean = false
  @Local platformSelectedIndex: number = 0
  @Local platformItems: SegmentButtonV2Items = new SegmentButtonV2Items([])
  private swiperController: SwiperController = new SwiperController()

  @Computed
  get screenWidth(): number {
    try {
      const d = display.getDefaultDisplaySync()
      return Math.round(d.width * 160 / d.densityDPI)
    } catch (_) {
      return 360
    }
  }

  @Computed
  get visibleHotSearches(): string[] {
    if (this.viewModel.hotSearchExpanded || this.viewModel.hotSearches.length <= 24) {
      return this.viewModel.hotSearches
    }
    return this.viewModel.hotSearches.slice(0, 24)
  }

  @Monitor('platformSelectedIndex')
  onPlatformSelectedChange(): void {
    const prevPlatform = this.viewModel.currentPlatform
    this.viewModel.currentPlatform = this.viewModel.platforms[this.platformSelectedIndex].platform
    this.resultVM.currentPlatform = this.viewModel.platforms[this.platformSelectedIndex].platform
    if (this.isResultMode) {
      const kw = this.resultVM.keyword
      if (kw.length > 0) {
        // 立即清空旧结果，避免切换时闪现前一平台内容
        this.resultVM.clearResults()
        setTimeout(() => {
          this.resultVM.doSearch(kw)
        }, 100)
      }
    } else if (prevPlatform !== this.viewModel.currentPlatform) {
      // 非结果模式下切换平台，刷新热门搜索
      this.viewModel.refreshHotSearches()
    }
  }

  aboutToAppear(): void {
    const items: Record<string, string>[] = []
    for (const p of this.viewModel.platforms) {
      const entry: Record<string, string> = {}
      entry['text'] = p.name
      items.push(entry)
    }
    this.platformItems = new SegmentButtonV2Items(items)
    // 初始化热门搜索
    this.viewModel.initHotSearches()
  }

  @Monitor('isResultMode')
  onResultModeChange(): void {
    this.isSearchResultMode = this.isResultMode
  }

  @Monitor('searchBackVersion')
  onSearchBack(): void {
    this.isResultMode = false
  }

  // ==================== 返回键逻辑 ====================

  private onBack(): void {
    if (this.isResultMode) {
      this.isResultMode = false
      this.viewModel.resumeSuggesting()
    } else {
      this.getUIContext().animateTo({
        curve: curves.interpolatingSpring(0, 1, 342, 38)
      }, () => {
        this.navPathStack.pop(false)
      })
    }
  }

  @Builder
  backButtonContent(): void {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(28)
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .margin({ top: -5 })
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onBack()
    })
  }

  // ==================== 搜索确认 ====================

  private doSearch(): void {
    const kw = this.viewModel.doSearch()
    if (kw) {
      this.isResultMode = true
      this.resultVM.currentPlatform = this.viewModel.currentPlatform
      this.resultVM.doSearch(kw)
    }
  }

  // ==================== 热门搜索标签（折叠展开） ====================

  @Builder
  hotSearchTags(): void {
    Column({ space: 8 }) {
      Text('热门搜索')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.visibleHotSearches, (hotWord: string) => {
          Text(hotWord)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#0D000000')
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.viewModel.updateKeyword(hotWord)
              this.doSearch()
            })
        })
      }
      .width('100%')

      // 超过6行时显示展开/收起箭头
      if (this.viewModel.hotSearches.length > 24) {
        Row() {
          SymbolGlyph(this.viewModel.hotSearchExpanded
            ? $r('sys.symbol.chevron_up')
            : $r('sys.symbol.chevron_down'))
            .fontSize(18)
            .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
          Text(this.viewModel.hotSearchExpanded ? '收起' : '展开更多')
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 4 })
        .onClick(() => {
          this.viewModel.hotSearchExpanded = !this.viewModel.hotSearchExpanded
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  searchHistoryContent(): void {
    Column({ space: 12 }) {
      if (this.viewModel.searchHistory.length > 0) {
        Row() {
          Text('搜索历史')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
          Blank()
          SymbolGlyph($r('sys.symbol.trash_fill'))
            .fontSize(16)
            .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
            .onClick(() => { this.viewModel.clearHistory() })
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.viewModel.searchHistory, (historyWord: string) => {
            Text(historyWord)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#0D000000')
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.viewModel.updateKeyword(historyWord)
                this.doSearch()
              })
          })
        }
      }
    }
    .width('90%')
  }

  // ==================== 联想建议 ====================

  @Builder
  suggestionContent(): void {
    Column() {
      ForEach(this.viewModel.suggestions, (item: SuggestionItem) => {
        Column() {
          Row({ space: 12 }) {
            SymbolGlyph(item.type === SuggestionType.ARTIST
              ? $r('sys.symbol.person_crop_circle_fill_1')
              : $r('sys.symbol.music_note_list'))
              .fontSize(18)
              .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])

            Text(item.text)
              .fontSize(15)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(48)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.viewModel.updateKeyword(item.text)
            this.doSearch()
          })

          Divider().strokeWidth(0.5).color('#1A000000').width('100%')
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  // ==================== 搜索结果列表 ====================

  @Builder
  itemMenuBuilder(item: SearchResultItem): void {
    Menu() {
      MenuItem({ content: '下一首播放' })
        .onClick(() => {
          this.resultVM.playNext(item)
          this.menuVisible = false
        })
      MenuItem({ content: '稍后播放' })
        .onClick(() => {
          this.resultVM.playLater(item)
          this.menuVisible = false
        })
      MenuItem({ content: '添加到歌单' })
        .onClick(() => { this.menuVisible = false })
    }
  }

  @Builder
  resultList(): void {
    List() {
      ForEach(this.resultVM.results, (item: SearchResultItem, index: number) => {
        ListItem() {
          Row() {
            // 序号
            Text(`${index + 1}`)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .width(28)
              .textAlign(TextAlign.Center)

            // 歌曲信息
            Column({ space: 3 }) {
              Text(item.title as string)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)

              Row({ space: 6 }) {
                if (item.quality.length > 0) {
                  Text(item.quality)
                    .fontSize(9)
                    .fontColor(item.quality === '24bit' ? '#C8A145' :
                      item.quality === 'SQ' ? '#D4A017' :
                      item.quality === 'HQ' ? '#FF6B35' : '#999999')
                    .fontWeight(FontWeight.Bold)
                    .padding({ left: 3, right: 3, top: 1, bottom: 1 })
                    .backgroundColor(item.quality === '24bit' ? '#1AC8A145' :
                      item.quality === 'SQ' ? '#1AD4A017' :
                      item.quality === 'HQ' ? '#1AFF6B35' : '#1A999999')
                    .borderRadius(3)
                }
                Text(item.singer as string)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                  .constraintSize({ maxWidth: this.screenWidth * 0.35 })

                if (item.album.length > 0) {
                  Text('·')
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                  Text(item.album)
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                    .constraintSize({ maxWidth: this.screenWidth * 0.25 })
                }
              }
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)

            // 时长
            if (item.duration !== '--:--') {
              Text(item.duration)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                .margin({ right: 8 })
            }

            // 更多菜单
            Text('⋯')
              .fontSize(20)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .fontWeight(FontWeight.Bold)
              .padding({ left: 4, right: 4, top: 12, bottom: 12 })
              .onClick(() => {
                this.menuItemId = item.songId.length > 0 ?
                  parseInt(item.songId) || index : index
                this.menuVisible = !this.menuVisible
              })
              .bindMenu(
                this.menuVisible && this.menuItemId === (
                  item.songId.length > 0 ? parseInt(item.songId) || index : index),
                this.itemMenuBuilder(item)
              )
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .borderRadius(8)
          .backgroundColor(this.activeResultIndex === index ? 'rgba(0,0,0,0.06)' : Color.Transparent)
          .onClick(() => {
            this.activeResultIndex = index
            this.resultVM.playSong(item)
            setTimeout(() => { this.activeResultIndex = -1 }, 200)
          })
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .listDirection(Axis.Vertical)
    .divider({ strokeWidth: 0.5, color: '#1A000000', startMargin: 16, endMargin: 16 })
  }

  // ==================== 搜索框点击（结果模式下返回搜索） ====================

  private onSearchInputTap(): void {
    if (this.isResultMode) {
      this.isResultMode = false
      this.viewModel.resumeSuggesting()
      setTimeout(() => {
        this.getUIContext().getFocusController().requestFocus('search_text_input')
      }, 200)
    }
  }

  // ==================== UI ====================

  build() {
    Column() {
      // 顶部固定栏：返回键 + 搜索框
      Row({ space: 8 }) {
        AreaWithHdsTabBar({
          barHeight: 40,
          barWidth: 40,
          barPlacement: BarPosition.End,
          bottomMargin: 8,
          content: (): void => { this.backButtonContent() }
        })

        SearchInputArea({
          isFollow: false,
          autoFocus: !this.isResultMode,
          keyword: this.viewModel.keyword,
          placeholder: this.isResultMode ? this.resultVM.keyword : '搜歌曲、歌手、专辑',
          onKeywordChange: (text: string): void => {
            this.viewModel.updateKeyword(text)
          },
          onSearch: (): void => {
            this.doSearch()
          },
          onClear: (): void => {
            this.viewModel.clear()
          },
          onTap: (): void => {
            this.onSearchInputTap()
          }
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .margin({ top: 56 })
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 12 })

      // 音乐平台切换（分段按钮）
      CapsuleSegmentButtonV2({
        items: this.platformItems,
        selectedIndex: this.platformSelectedIndex!!,
        itemSelectedFontColor: ColorMetrics.resourceColor($r('sys.color.font_primary')),
        itemSelectedBackgroundColor:
        ColorMetrics.resourceColor($r('sys.color.segment_button_v2_tab_selected_item_background'))
      })
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })

      // 下部内容区（Swiper 支持左右划切换平台）
      Swiper(this.swiperController) {
        ForEach(this.viewModel.platforms, (_platform: PlatformTab, index: number) => {
          Column() {
            if (this.isResultMode) {
              // 按平台匹配渲染：只有当前平台才显示结果数据
              if (this.resultVM.currentPlatform === _platform.platform) {
                if (this.resultVM.isLoading) {
                  LoadingProgress().width(40).height(40).margin({ top: 100 })
                }
                if (!this.resultVM.isLoading) {
                  if (this.resultVM.results.length > 0) {
                    this.resultList()
                  } else {
                    Column() {
                      Text('暂无搜索结果')
                        .fontSize(15)
                        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                        .margin({ top: 100 })
                    }
                    .width('100%').layoutWeight(1)
                  }
                }
              } else {
                // 非当前平台：显示加载态，避免闪烁旧数据
                LoadingProgress().width(40).height(40).margin({ top: 100 })
              }
            } else {
              Column() {
                if (this.viewModel.currentState === SearchState.HOT) {
                  Scroll() {
                    Column() {
                      this.hotSearchTags()
                      this.searchHistoryContent()
                    }
                  }
                  .width('100%').scrollBar(BarState.Off)
                } else if (this.viewModel.currentState === SearchState.SUGGESTING) {
                  Scroll() {
                    this.suggestionContent()
                  }
                  .width('100%').scrollBar(BarState.Off)
                }
              }
              .width('100%').layoutWeight(1).justifyContent(FlexAlign.Start)
            }
          }
          .width('100%')
        }, (_platform: PlatformTab, index: number) => index.toString())
      }
      .index(this.platformSelectedIndex)
      .indicator(false)
      .loop(false)
      .disableSwipe(false)
      .cachedCount(0)
      .width('100%')
      .layoutWeight(1)
      .onChange((index: number) => {
        this.platformSelectedIndex = index
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ bottom: 72 })
  }
}
