/*
 * Lucid Music - 迷你播放条
 * 显示当前播放歌曲信息 + 播放控制，点击跳转播放页
 * 订阅 MusicAppState，无播放时完全隐藏
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { AppStorageKeys } from '../../constants/Constants'
import { MusicAppState } from '../../model/MusicAppState'
import { AreaWithHdsTabBar } from '../floating/AreaWithHdsTabBar'

@ComponentV2
export struct MiniPlayerBar {
  @Param @Require barWidth: number
  @Event onPlayPause?: () => void
  @Event onNext?: () => void
  @Event onTap?: () => void
  @Param bottomOffset: number = 10

  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!

  @Computed
  get hasSong(): boolean {
    return this.appState.getQueueLength() > 0 || this.appState.remoteSongItem !== null
  }

  @Computed
  get songTitle(): string {
    return this.appState.getCurrentSongItem()?.title?.toString() ?? 'Lucid Music'
  }

  @Computed
  get songSinger(): string {
    return this.appState.getCurrentSongItem()?.singer?.toString() ?? '未在播放'
  }

  @Builder
  miniBarContent(): void {
    Row() {
      Column() {
        Image($r('app.media.startIcon'))
          .width('100%').height('100%')
          .borderRadius('50%')
      }
      .padding(1).width(40).aspectRatio(1)
      .justifyContent(FlexAlign.Center)

      Column({ space: 4 }) {
        Text(this.songTitle)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        Text(this.songSinger)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          .fontWeight(FontWeight.Regular)
          .fontColor($r('sys.color.font_secondary'))
          .fontSize($r('sys.float.Caption_M'))
      }
      .padding({ left: 12 })
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      .onClick(() => {
        this.onTap?.()
      })

      Row({ space: 16 }) {
        SymbolGlyph(this.appState.isPlay ?
          $r('sys.symbol.pause_circle_fill') : $r('sys.symbol.play_circle_fill'))
          .fontSize($r('sys.float.Title_M'))
          .onClick(() => {
            this.onPlayPause?.()
          })
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize($r('sys.float.Title_M'))
          .onClick(() => {
            this.onNext?.()
          })
      }
      .padding({ left: 12, right: 12 })
    }
    .width(this.barWidth - 20)
    .height(56)
  }

  build() {
    if (this.hasSong) {
      AreaWithHdsTabBar({
        barHeight: 56,
        barWidth: this.barWidth,
        barPlacement: BarPosition.End,
        bottomMargin: this.bottomOffset,
        content: (): void => { this.miniBarContent() }
      })
    }
  }
}
