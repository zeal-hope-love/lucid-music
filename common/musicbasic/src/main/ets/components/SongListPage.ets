/*
 * Lucid Music - 共用歌曲列表页
 * 支持三种数据模式：
 *   1. source 非空 — 远程歌单模式：按平台真实歌单拉取歌曲（getPlaylistSongs），点击走远程取流播放
 *   2. listType: 'local' | 'recent' | 'favorite' — 按来源加载
 *   3. playlistId 非空 — 本地歌单模式
 * 本地/最近播放/收藏 + 歌单详情 共用此 UI
 */
import { AppStorageV2, promptAction } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, PlaybackIntentState, MusicDbApi, SongApiDto, SongItem,
  ApiSource, SearchResultItem, PlaylistMeta, SongDtoMapper
} from 'musicbasic'
import { AreaWithHdsTabBar } from './floating/AreaWithHdsTabBar'

export class SongListParam {
  title: string
  /** 'local' | 'recent' | 'favorite' — 按来源类型 */
  listType: string
  /** 歌单 ID（字符串，避免大整数精度丢失；远程歌单为平台真实 id） */
  playlistId: string
  /** 远程歌单所属平台（kg/tx/wy/kw/mg）；非空时走远程歌单模式 */
  source: string
  constructor(title: string, listType: string = '', playlistId: string = '', source: string = '') {
    this.title = title
    this.listType = listType
    this.playlistId = playlistId
    this.source = source
  }
}

@ComponentV2
export struct SongListPage {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Param param: SongListParam | undefined = undefined
  @Local songs: SongApiDto[] = []
  @Local remoteSongs: SearchResultItem[] = []
  /** 最近播放 / 收藏列表（完整 SongItem，含本地与远程） */
  @Local rfItems: SongItem[] = []
  @Local isRemote: boolean = false
  @Local pageTitle: string = ''
  /** 远程歌单元数据（名称、封面、作者等） */
  @Local playlistInfo: PlaylistMeta = new PlaylistMeta()
  /** 是否已收藏当前远程歌单 */
  @Local isSaved: boolean = false

  /** 当前是否为最近播放 / 收藏来源列表 */
  @Computed
  get isRf(): boolean {
    return this.param !== undefined &&
      (this.param.listType === 'recent' || this.param.listType === 'favorite')
  }

  private intentState: PlaybackIntentState =
    AppStorageV2.connect(PlaybackIntentState, AppStorageKeys.PLAYBACK_INTENT_STATE, () => new PlaybackIntentState())!
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!

  aboutToAppear(): void {
    this.loadData()
  }

  @Monitor('currentTabState.favoriteVersion')
  onFavoriteVersionChanged(): void {
    if (this.param !== undefined &&
      (this.param.listType === 'favorite' || this.param.listType === 'recent') && !this.isRemote) {
      this.loadData()
    }
  }

  private async loadData(): Promise<void> {
    if (this.param === undefined) {
      return
    }
    this.pageTitle = this.param.title

    // 远程歌单模式优先（真实平台歌单）
    if (this.param.source !== '') {
      this.isRemote = true
      try {
        const result = await ApiSource.getPlaylistSongs(this.param.source, this.param.playlistId, 1, 1000)
        this.remoteSongs = result.list
        this.playlistInfo = result.info
        const api = MusicDbApi.getInstance()
        this.isSaved = api.isRemotePlaylistSaved(this.param.playlistId)
        if (result.list.length === 0) {
          const extracted = this.param.playlistId.includes('http') ? this.param.playlistId.match(/https?:\/\/[^\s]+/)?.[0] || this.param.playlistId : this.param.playlistId
          promptAction.showToast({ message: `未获取到歌曲(源:${this.param.source} URL:${(extracted || '').substring(0, 40)})`, duration: 4000 })
        }
      } catch (e) {
        this.remoteSongs = []
        this.playlistInfo = new PlaylistMeta()
        const msg = e instanceof Error ? e.message : '未知错误'
        promptAction.showToast({ message: msg, duration: 4000 })
      }
      return
    }

    this.isRemote = false
    const api = MusicDbApi.getInstance()

    // 本地歌单模式
    if (this.param.playlistId !== '') {
      this.songs = api.getPlaylistSongItems(Number.parseInt(this.param.playlistId) || 0)
      return
    }

    // 来源模式
    if (this.param.listType === 'local') {
      this.songs = api.getSongList()
    } else if (this.param.listType === 'recent') {
      this.rfItems = api.getRecentPlaySongs()
    } else if (this.param.listType === 'favorite') {
      this.rfItems = api.getFavoriteSongs()
    } else {
      this.songs = []
    }
  }

  /** 将在线歌单歌曲映射为完整 SongItem（携带 platform + remoteSongId，供逐曲现取流） */
  private remoteToSongItem(r: SearchResultItem): SongItem {
    const item = new SongItem()
    item.id = -Math.abs(SongListPage.hashString(`${r.source}_${r.songId}`))
    item.title = r.title
    item.singer = r.singer
    item.coverUrl = r.coverUrl || r.cover || ''
    item.platform = r.source
    item.remoteSongId = r.songId
    item.src = ''
    return item
  }

  /** 稳定字符串哈希（用于为在线歌生成确定性负数 id） */
  private static hashString(s: string): number {
    let h = 0
    for (let i = 0; i < s.length; i++) {
      h = (h * 31 + s.charCodeAt(i)) | 0
    }
    return h
  }

  private onSongTap(index: number): void {
    // 歌单内点歌（本地/自建/收藏）：队列=该歌单全部歌曲，标题=歌单名
    const queue = this.songs.map((dto): SongItem => SongDtoMapper.toSongItem(dto))
    this.intentState.pendingQueue = queue
    this.intentState.pendingSelectIndex = index
    this.intentState.pendingPlaylistTitle = this.param?.title ?? ''
    this.intentState.requestVersion++
  }

  private onRemoteSongTap(index: number): void {
    // 在线歌单：整张歌单作为队列，逐曲现取流；标题=歌单名
    const queue = this.remoteSongs.map((r): SongItem => this.remoteToSongItem(r))
    this.intentState.pendingQueue = queue
    this.intentState.pendingSelectIndex = index
    this.intentState.pendingPlaylistTitle = this.playlistInfo.name || this.param?.title || ''
    this.intentState.openPlayerUi = true
    this.intentState.requestVersion++
  }

  /** 最近播放 / 收藏列表项点击：整份列表作为队列播放（本地/在线一视同仁） */
  private onRfSongTap(index: number): void {
    if (this.rfItems[index] === undefined) {
      return
    }
    this.intentState.pendingQueue = [...this.rfItems]
    this.intentState.pendingSelectIndex = index
    this.intentState.pendingPlaylistTitle = this.param?.title ?? ''
    this.intentState.requestVersion++
  }

  /** 收藏 / 取消收藏远程歌单 */
  private onToggleSave(): void {
    if (this.param === undefined || this.param.source === '') { return }
    const api = MusicDbApi.getInstance()
    if (this.isSaved) {
      // 取消收藏：按 sourceListId 查找并移除
      const playlists = api.getCollectedPlaylists()
      const target = playlists.find(p => p.sourceListId === this.param!.playlistId)
      if (target) {
        api.removeCollectedPlaylist(target.playlistId)
        this.isSaved = false
      }
    } else {
      // 收藏
      const info = this.playlistInfo
      api.saveRemotePlaylist(
        info.name || this.param.title || '未命名歌单',
        this.param.source,
        this.param.playlistId,
        info.img,
        info.author
      )
      this.isSaved = true
    }
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

  @Builder
  songRow(index: number, title: string | Resource, singer: string | Resource, extra: string): void {
    Row() {
      Text(`${index + 1}`)
        .fontSize(15)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        .width(32)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(singer)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (extra !== '') {
        Text(extra)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
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

        Text(`${this.isRemote ? this.remoteSongs.length : (this.isRf ? this.rfItems.length : this.songs.length)}首`)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('90%')
      .height(56)
      .margin({ top: 48 })

      // === 远程歌单信息头部（封面 + 名称 + 作者 + 收藏按钮） ===
      if (this.isRemote && this.playlistInfo.name) {
        Row() {
          // 封面
          if (this.playlistInfo.img) {
            Image(this.playlistInfo.img)
              .width(60)
              .height(60)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
          }

          Column({ space: 4 }) {
            Text(this.playlistInfo.name)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Row({ space: 8 }) {
              if (this.playlistInfo.author) {
                Text(this.playlistInfo.author)
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              if (this.playlistInfo.playCount) {
                Text(`播放 ${this.playlistInfo.playCount}`)
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              }
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: this.playlistInfo.img ? 12 : 0 })

          // 收藏按钮
          Column() {
            SymbolGlyph(this.isSaved ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
              .fontSize(24)
              .fontColor(this.isSaved
                ? [Color.Red]
                : [$r('sys.color.ohos_id_color_text_secondary')])
            Text(this.isSaved ? '已收藏' : '收藏')
              .fontSize(11)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .margin({ top: 2 })
          }
          .padding({ left: 8, right: 4, top: 4, bottom: 4 })
          .borderRadius(8)
          .onClick(() => { this.onToggleSave() })
        }
        .width('90%')
        .padding({ top: 4, bottom: 12 })
      }

      // === 歌曲列表 ===
      List() {
        if (this.isRemote) {
          ForEach(this.remoteSongs, (song: SearchResultItem, index: number) => {
            ListItem() {
              this.songRow(index, song.title, song.singer, song.duration)
            }
            .onClick(() => {
              this.onRemoteSongTap(index)
            })
          }, (song: SearchResultItem, index: number): string => `${song.songId}_${index}`)
        } else if (this.isRf) {
          ForEach(this.rfItems, (song: SongItem, index: number) => {
            ListItem() {
              this.songRow(index, song.title, song.singer, '')
            }
            .onClick(() => {
              this.onRfSongTap(index)
            })
          })
        } else {
          ForEach(this.songs, (song: SongApiDto, index: number) => {
            ListItem() {
              this.songRow(index, song.title, song.singer, '')
            }
            .onClick(() => {
              this.onSongTap(index)
            })
          })
        }
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
