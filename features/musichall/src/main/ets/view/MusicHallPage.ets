/*
 * Lucid Music - 音乐厅页面
 * 布局：内容区 + 底部 MiniPlayerBar + LucidTabBar
 */
import { AppStorageV2, display } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, RouterUrlConstants
} from 'musicbasic'
import { LucidTabBar, MiniPlayerBar } from 'musicbasic'

@ComponentV2
export struct MusicHallPage {
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
        Text('音乐厅')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .width('90%')
          .margin({ top: 16 })

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
