/*
 * Lucid Music - 音乐列表页（本地/最近播放/收藏）
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { AppStorageKeys, CurrentTabState, MusicAppState, MusicDbApi, SongApiDto, AreaWithHdsTabBar } from 'musicbasic'
import { AudioPlayerController } from 'player'

export class MusicListParam {
  title: string
  listType: string
  constructor(title: string, listType: string = 'local') {
    this.title = title
    this.listType = listType
  }
}

@ComponentV2
export struct MusicListPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Param param: MusicListParam | undefined = undefined
  @Local songs: SongApiDto[] = []
  @Local pageTitle: string = '本地'
  private appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
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
    if (this.param !== undefined) {
      if (this.param.title.length > 0) {
        this.pageTitle = this.param.title
      }
      const api = MusicDbApi.getInstance()
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
  }

  private onSongTap(index: number): void {
    const clickedId = this.songs[index].id
    const currentSongId = this.appState.playQueueIds[this.appState.selectIndex]
    // 同一首歌
    if (currentSongId === clickedId) {
      if (this.appState.isPlay) {
        // 正在播放：不操作
        return
      }
      // 暂停中：恢复播放
      AudioPlayerController.getInstance().play()
      return
    }
    // 不同歌曲：原有逻辑
    this.appState.playQueueIds = this.songs.map((dto): number => dto.id)
    this.appState.selectIndex = index
    this.appState.isPlay = true
    AudioPlayerController.getInstance().playCurrent()
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
