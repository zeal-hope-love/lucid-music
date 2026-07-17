/*
 * Lucid Music - 迷你播放条
 * 显示当前播放歌曲信息 + 播放控制 + 播放列表按钮
 * 订阅 MusicAppState，无播放时完全隐藏
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { AppStorageKeys } from '../../constants/Constants'
import { MusicAppState } from '../../model/MusicAppState'
import { SongItem } from '../../model/SongData'
import { PlaybackIntentState } from '../../model/PlaybackIntentState'
import { MusicDbApi } from '../../util/MusicDbApi'
import { AreaWithHdsTabBar } from '../floating/AreaWithHdsTabBar'

interface LrcEntry {
  time: number
  text: string
}

@ComponentV2
export struct MiniPlayerBar {
  @Param @Require barWidth: number
  @Event onPlayPause?: () => void
  @Event onNext?: () => void
  @Event onTap?: () => void
  @Param bottomOffset: number = 10

  @Local appState: MusicAppState =
    AppStorageV2.connect(MusicAppState, AppStorageKeys.MUSIC_APP_STATE, () => new MusicAppState())!
  @Local intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  @Local isShowPlayList: boolean = false

  /** 歌词缓存：上次解析的原始文本 */
  private cachedLyricText: string = ''
  /** 歌词缓存：已解析的（时间ms, 文本）列表 */
  private cachedLrcEntries: Array<LrcEntry> = []

  /** 轻量 LRC 解析，只提取时间和纯文本行 */
  private parseLrcLyricForMiniBar(text: string): Array<LrcEntry> {
    const result: Array<LrcEntry> = []
    const lines = text.split('\n')
    const lrcLineRegex = /\[(\d+):(\d+(?:\.\d+)?)\](.*)/
    for (const line of lines) {
      const match = line.match(lrcLineRegex)
      if (match) {
        const min = parseInt(match[1])
        const sec = parseFloat(match[2])
        const timeMs = (min * 60 + sec) * 1000
        const lineText = match[3].trim()
        if (lineText) {
          result.push({ time: timeMs, text: lineText })
        }
      }
    }
    result.sort((a, b) => a.time - b.time)
    return result
  }

  @Computed
  get coverSource(): Resource | string {
    const song = this.appState.getCurrentSongItem()
    if (song?.coverUrl) {
      return song.coverUrl
    }
    if (song?.label) {
      return song.label
    }
    return $r('app.media.ic_music_symbol')
  }

  @Computed
  get hasSong(): boolean {
    return this.appState.getQueueLength() > 0 || this.appState.remoteSongItem !== null
  }

  @Computed
  get titleArtistLine(): string {
    const title = this.appState.getCurrentSongItem()?.title?.toString()
    if (!title) {
      return 'Lucid Music'
    }
    const singer = this.appState.getCurrentSongItem()?.singer?.toString()
    return singer ? `${title} - ${singer}` : title
  }

  @Computed
  get subLine(): string {
    // 非就绪状态：显示播放状态信息
    const status = this.appState.playbackStatus
    if (status === 'requesting_url' || status === 'preparing' || status === 'error') {
      return this.appState.playbackStatusMessage || status
    }
    const lyric = this.appState.getCurrentSongItem()?.lyricText
    if (!lyric) {
      return ''
    }
    // 读取 progress 使 @Computed 随播放进度实时更新
    const progressMs = this.appState.progress

    // 歌词文本变化时重新解析并缓存
    if (lyric !== this.cachedLyricText) {
      this.cachedLyricText = lyric
      this.cachedLrcEntries = this.parseLrcLyricForMiniBar(lyric)
    }

    // 无解析条目：回退到首行纯文本
    const entries = this.cachedLrcEntries
    if (entries.length === 0) {
      const firstLine = lyric.split('\n')[0] || lyric
      return firstLine.replace(/\[.*?\]/g, '').trim()
    }

    // 查找当前播放进度对应的歌词行
    let currentText = entries[0].text
    for (const entry of entries) {
      if (entry.time <= progressMs) {
        currentText = entry.text
      } else {
        break
      }
    }
    return currentText
  }

  @Computed
  get subLineIsStatus(): boolean {
    const status = this.appState.playbackStatus
    return status === 'requesting_url' || status === 'preparing' || status === 'error'
  }

  // 解析播放列表为 SongItem 数组
  private resolvePlaylist(): SongItem[] {
    const result: SongItem[] = []
    for (let i = 0; i < this.appState.playQueueIds.length; i++) {
      const song = this.appState.resolveSongAtQueueIndex(i)
      if (song) {
        result.push(song)
      }
    }
    return result
  }

  // ==================== 播放列表 Sheet Builder ====================

  @Builder
  playlistSheetBuilder(): void {
    Column() {
      // 标题栏
      Row() {
        Text('播放列表')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(`${this.appState.getQueueLength()} 首`)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      Divider().strokeWidth(0.5).color('#1A000000')

      // 歌曲列表
      if (this.appState.getQueueLength() > 0) {
        List() {
          ForEach(this.resolvePlaylist(), (item: SongItem, index: number) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(item.title as string)
                    .fontSize(15)
                    .fontWeight(this.appState.selectIndex === index ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(this.appState.selectIndex === index
                      ? $r('sys.color.ohos_id_color_text_primary')
                      : $r('sys.color.ohos_id_color_text_primary'))
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                  Text(item.singer as string)
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1)

                if (this.appState.selectIndex === index && this.appState.isPlay) {
                  SymbolGlyph($r('sys.symbol.play_fill'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_primary')])
                }
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 14, bottom: 14 })
              .onClick(() => {
                this.intentState.pendingPlaySongId = item.id
                this.intentState.requestVersion++
                this.isShowPlayList = false
              })
            }
          })
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Off)
        .listDirection(Axis.Vertical)
        .divider({ strokeWidth: 0.5, color: '#1A000000', startMargin: 20, endMargin: 20 })
      } else {
        Column() {
          Text('播放列表为空')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 40 })
        }
        .width('100%').layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  // ==================== Mini Bar 内容 ====================

  @Builder
  miniBarContent(): void {
    Row() {
      Column() {
        Image(this.coverSource)
          .width('100%').height('100%')
          .borderRadius('50%')
          .objectFit(ImageFit.Cover)
          .geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: false })
      }
      .padding(1).width(40).aspectRatio(1)
      .justifyContent(FlexAlign.Center)

      Column({ space: 5 }) {
        Text(this.titleArtistLine)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .fontSize($r('sys.float.Body_S'))
        if (this.subLine) {
          Text(this.subLine)
            .textOverflow({ overflow: TextOverflow.MARQUEE }).maxLines(1)
            .fontWeight(FontWeight.Regular)
            .fontColor(this.subLineIsStatus ?
              $r('sys.color.ohos_id_color_text_primary') :
              $r('sys.color.font_secondary'))
            .fontSize($r('sys.float.Caption_M'))
        }
      }
      .padding({ left: 12 })
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      // 播放控制按钮 — hitTestBehavior 防止触发外层 Row 的 onClick
      SymbolGlyph(this.appState.isPlay ?
        $r('sys.symbol.pause_round_triangle_fill') : $r('sys.symbol.play_round_triangle_fill'))
        .fontSize($r('sys.float.Title_M'))
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .hitTestBehavior(HitTestMode.Block)
        .margin({ left: 6, right: 6 })
        .onClick(() => {
          this.onPlayPause?.()
        })
      SymbolGlyph($r('sys.symbol.forward_end_fill'))
        .fontSize($r('sys.float.Title_M'))
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .hitTestBehavior(HitTestMode.Block)
        .margin({ left: 6, right: 6 })
        .onClick(() => {
          this.onNext?.()
        })
      SymbolGlyph($r('sys.symbol.music_note_list'))
        .fontSize($r('sys.float.Title_M'))
        .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        .hitTestBehavior(HitTestMode.Block)
        .margin({ left: 6, right: 12 })
        .onClick(() => {
          this.isShowPlayList = true
        })
        .bindSheet($$this.isShowPlayList, this.playlistSheetBuilder(), {
          detents: [SheetSize.MEDIUM],
          dragBar: false,
          showClose: false,
          preferType: SheetType.CENTER
        })
    }
    .width(this.barWidth - 20)
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onTap?.()
    })
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
