/*
 * Lucid Music - 共用歌曲列表页
 * 支持两种数据模式：
 *   1. listType: 'local' | 'recent' | 'favorite' — 按来源加载
 *   2. playlistId > 0 — 按歌单加载
 * 本地/最近播放/收藏 + 歌单详情 共用此 UI
 */
import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, PlaybackIntentState, MusicDbApi, SongApiDto
} from 'musicbasic'
import { AreaWithHdsTabBar } from './floating/AreaWithHdsTabBar'

export class SongListParam {
  title: string
  /** 'local' | 'recent' | 'favorite' — 按来源类型 */
  listType: string
  /** 歌单 ID，> 0 时优先使用歌单数据 */
  playlistId: number
  constructor(title: string, listType: string = '', playlistId: number = 0) {
    this.title = title
    this.listType = listType
    this.playlistId = playlistId
  }
}

@ComponentV2
export struct SongListPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Param param: SongListParam | undefined = undefined
  @Local songs: SongApiDto[] = []
  @Local pageTitle: string = ''

  private intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!

  aboutToAppear(): void {
    this.loadData()
  }

  @Monitor('currentTabState.favoriteVersion')
  onFavoriteVersionChanged(): void {
    if (this.param !== undefined && this.param.listType === 'favorite') {
      this.loadData()
    }
  }

  private loadData(): void {
    if (this.param === undefined) {
      return
    }
    this.pageTitle = this.param.title
    const api = MusicDbApi.getInstance()

    // 歌单模式优先
    if (this.param.playlistId > 0) {
      this.songs = api.getPlaylistSongItems(this.param.playlistId)
      return
    }

    // 来源模式
    if (this.param.listType === 'local') {
      this.songs = api.getSongList()
    } else if (this.param.listType === 'recent') {
      this.songs = api.getRecentPlaySongs()
    } else if (this.param.listType === 'favorite') {
      this.songs = api.getFavoriteSongs()
    } else {
      this.songs = []
    }
  }

  private onSongTap(index: number): void {
    const songIds = this.songs.map((dto): number => dto.id)
    // 通过 PlaybackIntentState 分发播放请求，由 Index.ets → PlaybackIntentDispatcher → AudioPlayerController 处理
    this.intentState.pendingQueueIds = songIds
    this.intentState.pendingSelectIndex = index
    this.intentState.requestVersion++
  }

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

        Text(this.pageTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 12 })

        Blank()

        Text(`${this.songs.length}首`)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('90%')
      .height(56)
      .margin({ top: 48 })

      // === 歌曲列表 ===
      List() {
        ForEach(this.songs, (song: SongApiDto, index: number) => {
          ListItem() {
            Row() {
              Text(`${index + 1}`)
                .fontSize(15)
                .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                .width(32)

              Column({ space: 2 }) {
                Text(song.title)
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(song.singer)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .onClick(() => {
              this.onSongTap(index)
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#1A000000', startMargin: 56, endMargin: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
