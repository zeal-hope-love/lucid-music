/*
 * Lucid Music - 音乐厅页面
 * 布局：内容区（占位）
 */
import { AppStorageV2, display } from '@kit.ArkUI'
import {
  AppStorageKeys, MusicAppState, PlaybackIntentState, PlaybackShellConstants
} from 'musicbasic'
import { dispatchShellPlaybackIntent } from 'player'

@ComponentV2
export struct MusicHallPage {
  @Param @Require currentTab: number
  @Event onTabChange: (index: number) => void = (_index: number) => {}

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
  }
}
