/*
 * Lucid Music - 音乐厅页面
 * 布局：内容区
 * 底部 MiniPlayerBar + LucidTabBar 已提取到 Index.ets 统一管理
 */
import { display } from '@kit.ArkUI'

@ComponentV2
export struct MusicHallPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()

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
    Column() {
      Text('音乐厅')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('90%')
        .margin({ top: 64 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .padding({ bottom: 160 })
  }
}
