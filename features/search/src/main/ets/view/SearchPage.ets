/*
 * Lucid Music - 搜索页（覆盖层）
 * 三态切换：初始态（热门+历史）→ 输入态（联想建议）→ 结果态（跳转结果页）
 */
import { display } from '@kit.ArkUI'
import {
  AppStorageKeys, MusicAppState, PlaybackIntentState, PlaybackShellConstants
} from 'musicbasic'
import { AppStorageV2 } from '@kit.ArkUI'
import { AreaWithHdsTabBar, SearchInputArea } from 'musicbasic'
import { SearchViewModel, SearchState } from '../viewmodel/SearchViewModel'
import { SuggestionItem, SuggestionType } from '../model/SuggestionItem'
import { dispatchShellPlaybackIntent } from 'player'

@ComponentV2
export struct SearchPage {
  @Event onClose: () => void = () => {}
  @Event onResult?: (keyword: string) => void

  @Local viewModel: SearchViewModel = new SearchViewModel()
  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!

  @Computed
  get screenWidth(): number {
    try {
      const d = display.getDefaultDisplaySync()
      return Math.round(d.width * 160 / d.densityDPI)
    } catch (_) {
      return 360
    }
  }

  @Monitor('intentState.requestVersion')
  onPlaybackIntentChanged(): void {
    dispatchShellPlaybackIntent(this.appState, this.intentState, () => {
      this.appState.isShowPlay = true
    })
  }

  @Builder
  hotSearchContent(): void {
    Column({ space: 20 }) {
      if (this.viewModel.hotSearches.length > 0) {
        Column({ space: 12 }) {
          Row() {
            Text('热门搜索')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
          .width('100%')

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.viewModel.hotSearches, (hotWord: string) => {
              Text(hotWord)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor('#0D000000')
                .borderRadius(16)
                .margin({ right: 10, bottom: 10 })
                .onClick(() => {
                  this.viewModel.updateKeyword(hotWord)
                  const kw = this.viewModel.doSearch(hotWord)
                  if (kw) {
                    this.onResult?.(kw)
                  }
                })
            })
          }
        }
        .width('100%')
      }

      if (this.viewModel.searchHistory.length > 0) {
        Column({ space: 12 }) {
          Row() {
            Text('搜索历史')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
            Blank()
            SymbolGlyph($r('sys.symbol.trash_fill'))
              .fontSize(18)
              .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
              .onClick(() => {
                this.viewModel.clearHistory()
              })
          }
          .width('100%')

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.viewModel.searchHistory, (historyWord: string) => {
              Text(historyWord)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor('#0D000000')
                .borderRadius(16)
                .margin({ right: 10, bottom: 10 })
                .onClick(() => {
                  this.viewModel.updateKeyword(historyWord)
                  const kw = this.viewModel.doSearch(historyWord)
                  if (kw) {
                    this.onResult?.(kw)
                  }
                })
            })
          }
        }
        .width('100%')
      }
    }
    .width('90%')
  }

  @Builder
  suggestionContent(): void {
    Column() {
      ForEach(this.viewModel.suggestions, (item: SuggestionItem) => {
        Column() {
          Row({ space: 12 }) {
            // 类型图标
            SymbolGlyph(this.getSuggestionIcon(item.type))
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
            const kw = this.viewModel.doSearch(item.text)
            if (kw) {
              this.onResult?.(kw)
            }
          })

          Divider()
            .strokeWidth(0.5)
            .color('#1A000000')
            .width('100%')
        }
      })
    }
    .width('90%')
    .margin({ top: 8 })
  }

  /** 获取建议类型对应的图标资源 */
  private getSuggestionIcon(type: SuggestionType): Resource {
    if (type === SuggestionType.ARTIST) {
      return $r('sys.symbol.person_crop_circle_fill_1')
    } else {
      return $r('sys.symbol.music_note_list')
    }
  }

  @Builder
  backButtonContent(): void {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(20)
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .offset({ y: -2 })        // ← 负数往上，正数往下
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onClose()
    })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        AreaWithHdsTabBar({
          barHeight: 40,
          barWidth: 40,
          barPlacement: BarPosition.End,
          bottomMargin: 8,
          content: (): void => {
            this.backButtonContent()
          }
        })
          .margin({ top: 0 })   // ← 正数往下，负数往上
        SearchInputArea({
          barWidth: this.screenWidth * 0.78,
          isFollow: false,
          autoFocus: true,
          keyword: this.viewModel.keyword,
          placeholder: '搜歌曲、歌手、专辑',
          onKeywordChange: (text: string): void => {
            this.viewModel.updateKeyword(text)
          },
          onSearch: (): void => {
            const kw = this.viewModel.doSearch()
            if (kw) {
              this.onResult?.(kw)
            }
          },
          onClear: (): void => {
            this.viewModel.clear()
          }
        })
          .margin({ top: 0 })  // ← 负数往上
        .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 12 })

      if (this.viewModel.currentState === SearchState.HOT) {
        Scroll() {
          this.hotSearchContent()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .margin({ top: 16 })
      } else if (this.viewModel.currentState === SearchState.SUGGESTING) {
        Scroll() {
          this.suggestionContent()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ bottom: 80 })
  }
}
