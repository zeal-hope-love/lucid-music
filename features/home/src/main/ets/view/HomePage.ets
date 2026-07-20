/*
 * Lucid Music - 首页
 * 布局：标题 + 搜索框 + 内容区
 * 底部 MiniPlayerBar + LucidTabBar 已提取到 Index.ets 统一管理
 */
import { curves, display } from '@kit.ArkUI'
import { RouterUrlConstants } from 'musicbasic'
import { SearchInputArea } from 'musicbasic'

@ComponentV2
export struct HomePage {
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
        isFollow: true,
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
  }
}
