/*
 * Lucid Music - 搜索页（覆盖层）+ 搜索结果（内嵌）
 * 顶部固定：返回键 + 搜索框
 * 下部切换：热门/联想 → 搜索结果
 */
import { curves, display } from '@kit.ArkUI'
import { CapsuleSegmentButtonV2, SegmentButtonV2Items, ColorMetrics } from '@kit.ArkUI'
import {
  RouterUrlConstants
} from 'musicbasic'
import { AreaWithHdsTabBar, SearchInputArea, MiniPlayerBar } from 'musicbasic'
import { SearchViewModel, SearchState, PlatformTab } from '../viewmodel/SearchViewModel'
import { SearchResultViewModel } from '../viewmodel/SearchResultViewModel'
import { SearchResultItem } from '../model/SearchResultItem'
import { SuggestionItem, SuggestionType } from '../model/SuggestionItem'



@ComponentV2
export struct SearchPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Consumer() searchBackVersion: number = 0
  @Consumer() isSearchResultMode: boolean = false

  @Local viewModel: SearchViewModel = new SearchViewModel()
  @Local resultVM: SearchResultViewModel = new SearchResultViewModel()
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

  @Monitor('platformSelectedIndex')
  onPlatformSelectedChange(): void {
    this.viewModel.currentPlatform = this.viewModel.platforms[this.platformSelectedIndex].platform
    if (this.isResultMode) {
      const kw = this.resultVM.keyword
      if (kw.length > 0) {
        setTimeout(() => {
          this.resultVM.doSearch(kw)
        }, 300)
      }
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
      this.resultVM.doSearch(kw)
    }
  }

  // ==================== 热门搜索标签（常驻在 Tab 下方） ====================

  @Builder
  hotSearchTags(): void {
    Column({ space: 8 }) {
      Text('热门搜索')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.viewModel.hotSearches, (hotWord: string) => {
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
    .width('90%')
    .margin({ top: 8 })
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
      ForEach(this.resultVM.results, (item: SearchResultItem) => {
        ListItem() {
          Row() {
            Column({ space: 4 }) {
              Text(item.title as string)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
              Text(item.singer as string)
                .fontSize(13)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)

            Text('⋯')
              .fontSize(20)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .fontWeight(FontWeight.Bold)
              .padding({ left: 12, right: 4, top: 12, bottom: 12 })
              .onClick(() => {
                this.menuItemId = item.id
                this.menuVisible = !this.menuVisible
              })
              .bindMenu(
                this.menuVisible && this.menuItemId === item.id,
                this.itemMenuBuilder(item)
              )
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => { this.resultVM.playSong(item) })
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
      setTimeout(() => {
        this.getUIContext().getFocusController().requestFocus('search_text_input')
      }, 200)
    }
  }

  // ==================== UI ====================

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
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

      // 热门搜索标签（仅初始状态显示，输入内容或结果模式时隐藏）
      if (!this.isResultMode && this.viewModel.currentState === SearchState.HOT) {
        this.hotSearchTags()
      }

      // 下部内容区（Swiper 支持左右划切换平台）
      Swiper(this.swiperController) {
        ForEach(this.viewModel.platforms, (_platform: PlatformTab, index: number) => {
          Column() {
            if (this.isResultMode) {
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
              if (this.viewModel.currentState === SearchState.HOT) {
                Scroll() {
                  this.searchHistoryContent()
                }
                .width('100%').layoutWeight(1).scrollBar(BarState.Off).margin({ top: 8 })
              } else if (this.viewModel.currentState === SearchState.SUGGESTING) {
                Scroll() {
                  this.suggestionContent()
                }
                .width('100%').layoutWeight(1).scrollBar(BarState.Off).margin({ top: 4 })
              }
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
      .padding({ bottom: 126 })

      // === 底部迷你播放条 ===
      MiniPlayerBar({
        barWidth: this.screenWidth - 40,
        bottomOffset: 36,
        onTap: (): void => {
          this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYBACK, undefined))
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
