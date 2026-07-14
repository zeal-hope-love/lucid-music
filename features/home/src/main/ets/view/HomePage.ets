/*
 * Lucid Music - 首页
 * 布局：标题 + 搜索框 + 内容区 + 底部 MiniPlayerBar + LucidTabBar
 */
import { AppStorageV2, curves, display } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, RouterUrlConstants
} from 'musicbasic'
import { LucidTabBar, MiniPlayerBar, SearchInputArea } from 'musicbasic'

@ComponentV2
export struct HomePage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Local currentTab: number = AppStorage.get<number>(AppStorageKeys.CURRENT_TAB) ?? 0

  @Computed
  get screenWidth(): number {
    try {
      const d = display.getDefaultDisplaySync()
      return Math.round(d.width * 160 / d.densityDPI)
    } catch (_) {
      return 360
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('首页')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width('90%')
        .margin({ top: 64 })

        SearchInputArea({
          barWidth: Math.floor(this.screenWidth * 0.75),
          placeholder: '搜歌曲、歌手、专辑',
          onTap: (): void => {
            this.getUIContext().animateTo({
              curve: curves.interpolatingSpring(0, 1, 342, 38)
            }, () => {
              this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.SEARCH, undefined), false)
            })
          }
        })
        .width(Math.floor(this.screenWidth * 0.75))
        .margin({ top: 25 })
        .alignSelf(ItemAlign.Center)

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .padding({ bottom: 150 })

      // === 底部栏 ===
      Column() {
        MiniPlayerBar({
          barWidth: this.screenWidth - 40,
          bottomOffset: 10,
          onTap: (): void => {
            this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYBACK, undefined))
          }
        })
        .margin({ bottom: 30 })

        LucidTabBar({
          currentIndex: this.currentTab,
          barWidth: this.screenWidth - 40,
          bottomOffset: 30,
          onChange: (index: number): void => {
            const tabState = AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!
            tabState.index = index
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
