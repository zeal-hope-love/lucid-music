/*
 * Lucid Music - 搜索结果页
 * 布局：返回 + 搜索框（只读） + 结果列表
 */
import { display } from '@kit.ArkUI'
import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStorageKeys, MusicAppState, PlaybackIntentState
} from 'musicbasic'
import { SearchInputArea } from 'musicbasic'
import { SearchResultViewModel } from '../viewmodel/SearchResultViewModel'
import { SearchResultItem } from '../model/SearchResultItem'
import { dispatchShellPlaybackIntent } from 'player'

@ComponentV2
export struct SearchResultPage {
  @Param @Require keyword: string
  @Event onClose: () => void = () => {}

  @Local viewModel: SearchResultViewModel = new SearchResultViewModel()
  @Local menuItemId: number = -1
  @Local menuVisible: boolean = false
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

  aboutToAppear(): void {
    this.viewModel.doSearch(this.keyword)
  }

  @Builder
  itemMenuBuilder(item: SearchResultItem): void {
    Menu() {
      MenuItem({ content: '下一首播放' })
        .onClick(() => {
          this.viewModel.playNext(item)
          this.menuVisible = false
        })
      MenuItem({ content: '稍后播放' })
        .onClick(() => {
          this.viewModel.playLater(item)
          this.menuVisible = false
        })
      MenuItem({ content: '添加到歌单' })
        .onClick(() => {
          this.menuVisible = false
        })
    }
  }

  @Builder
  resultList(): void {
    List() {
      ForEach(this.viewModel.results, (item: SearchResultItem) => {
        ListItem() {
          Row() {
            Column({ space: 4 }) {
              Text(item.title as string)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
              Text(item.singer as string)
                .fontSize(13)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // 四点更多菜单按钮
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
          .onClick(() => {
            this.viewModel.playSong(item)
          })
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .listDirection(Axis.Vertical)
    .divider({
      strokeWidth: 0.5,
      color: '#1A000000',
      startMargin: 16,
      endMargin: 16
    })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          .onClick(() => {
            this.onClose()
          })

        SearchInputArea({
          barWidth: this.screenWidth * 0.78,
          isFollow: false,
          keyword: this.keyword,
          placeholder: this.keyword
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 12 })

      if (this.viewModel.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ top: 100 })
      }

      if (!this.viewModel.isLoading) {
        if (this.viewModel.results.length > 0) {
          this.resultList()
        } else {
          Column() {
            Text('暂无搜索结果')
              .fontSize(15)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .margin({ top: 100 })
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ bottom: 70 })
  }
}
