/*
 * Lucid Music - 首页
 * 布局：左上标题 + 光感搜索框（一镜到底锚点）
 */
import { AppStorageV2, display } from '@kit.ArkUI'
import {
  AppStorageKeys, MusicAppState, PlaybackIntentState, PlaybackShellConstants
} from 'musicbasic'
import { SearchInputArea } from 'musicbasic'
import { dispatchShellPlaybackIntent } from 'player'

@ComponentV2
export struct HomePage {
  @Param @Require currentTab: number
  @Param @Require isSearchOverlayShowing: boolean
  @Event onSearchClick: () => void = () => {}

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
      this.getUIContext().animateTo({
        duration: PlaybackShellConstants.OPEN_PLAYER_UI_ANIMATION_MS,
        curve: Curve.EaseInOut
      }, () => { this.appState.isShowPlay = true })
    })
  }

  build() {
    Column({ space: 24 }) {
      Row() {
        Text('首页')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('90%')
      .margin({ top: 16 })

      // 光感搜索框（覆盖层显示时隐藏，触发一镜到底转场）
      if (!this.isSearchOverlayShowing) {
        SearchInputArea({
          barWidth: this.screenWidth * 0.9,
          isFollow: true,
          placeholder: '搜歌曲、歌手、专辑',
          onTap: (): void => {
            this.onSearchClick()
          }
        })
        .width('90%')
      }

      Blank()
    }
    .width('100%')
    .height('100%')
  }
}
