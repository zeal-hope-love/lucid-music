/*
 * Lucid Music - 设置页面
 */
import { AreaWithHdsTabBar } from 'musicbasic'
import { AudioSourceSection } from './AudioSourceSection'

@ComponentV2
export struct SettingsPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()

  @Builder
  backButtonContent(): void {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .margin({ top: -4 })
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.navPathStack.pop()
    })
  }

  build() {
    Column() {
      // === 标题栏 ===
      Row() {
        AreaWithHdsTabBar({
          barHeight: 40,
          barWidth: 40,
          barPlacement: BarPosition.End,
          bottomMargin: 8,
          content: (): void => { this.backButtonContent() }
        })
          .margin({ top: 8 })

        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 12 })

        Blank()
      }
      .width('90%')
      .height(56)
      .margin({ top: 40 })

      // === 内容区 ===
      Scroll() {
        Column() {
          // --- 自定义音源 ---
          Text('自定义音源')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .padding({ left: 4, bottom: 12 })

          // 音源选择列表（内部含管理按钮 + bindSheet）
          AudioSourceSection()
        }
        .width('90%')
        .padding({ top: 0 })
      }
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
