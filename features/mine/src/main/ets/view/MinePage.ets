/**
 * 我的页面 — UI 占位，你需要重写
 */
import { AudioSourceSection } from './AudioSourceSection'

@ComponentV2
export struct MinePage {
  build() {
    Column() {
      Text('我的 - 待重写')
        .fontSize(20)
        .width('100%')
      AudioSourceSection()
    }
    .width('100%')
    .height('100%')
  }
}
