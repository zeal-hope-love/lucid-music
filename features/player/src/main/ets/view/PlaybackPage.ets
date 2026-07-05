/**
 * 播放页面 — UI 占位，你需要重写
 */
import { PlaybackPageCoverContent } from './PlaybackPageCoverContent'

@ComponentV2
export struct PlaybackPage {
  build() {
    NavDestination() {
      Text('播放页 - 待重写')
        .fontSize(20)
        .width('100%')
        .height('100%')
        .textAlign(TextAlign.Center)
    }
    .hideTitleBar(true)
  }
}
