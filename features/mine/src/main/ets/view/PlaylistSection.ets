/*
 * Lucid Music - 歌单区域组件（合并版）
 * 统一展示「我的歌单」：包含自建歌单和收藏歌单，每项标注类型
 * 功能：新建自建歌单、点击进入详情、左滑删除
 */
import { promptAction } from '@kit.ArkUI'
import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, MusicDbApi, PlaylistRow, RouterUrlConstants, SongListParam
} from 'musicbasic'

// ==================== 新建歌单 Dialog ====================

@CustomDialog
struct CreatePlaylistDialog {
  controller: CustomDialogController
  confirm: (name: string) => void = () => {}

  build() {
    Column() {
      Text('新建歌单')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 16 })

      TextInput({ placeholder: '请输入歌单名称' })
        .width('100%')
        .height(44)
        .fontSize(15)
        .borderRadius(10)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 20 })
        .onChange((value: string) => { this._inputText = value })

      Row({ space: 12 }) {
        Button('取消')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .onClick(() => { this.controller.close() })

        Button('创建')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .type(ButtonType.ROUNDED_RECTANGLE)
          .layoutWeight(1)
          .onClick(() => {
            const name = this._inputText.trim()
            if (name.length === 0) {
              return
            }
            this.controller.close()
            this.confirm(name)
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  _inputText: string = ''
}

/** 平台颜色映射 */
const SOURCE_COLORS: Record<string, string> = {
  'kg': '#2E8BFC', 'tx': '#31C27C', 'wy': '#C20C0C', 'kw': '#FFCC00', 'mg': '#E81E25'
}

@ComponentV2
export struct PlaylistSection {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Local playlists: PlaylistRow[] = []
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!
  /** playlistId → 第一首歌封面 Resource */
  @Local coverMap: Map<number, string> = new Map()
  private dialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.loadPlaylists()
  }

  @Monitor('currentTabState.refreshCounter')
  onRefreshCounterChanged(): void {
    this.loadPlaylists()
  }

  private loadPlaylists(): void {
    const api = MusicDbApi.getInstance()
    // 合并自建歌单和收藏歌单
    const own = api.getOwnPlaylists()
    const collected = api.getCollectedPlaylists()
    this.playlists = [...own, ...collected]
    // 预加载封面：自建用第一首歌，收藏用 coverUrl
    this.coverMap.clear()
    for (const pl of this.playlists) {
      if (pl.playlistType === 1 && pl.coverUrl) {
        this.coverMap.set(pl.playlistId, pl.coverUrl)
      } else if (pl.songIds.length > 0) {
        // 自建歌单用第一首歌封面 Resource 路径 - 用占位图
        this.coverMap.set(pl.playlistId, '')
      }
    }
  }

  private openCreateDialog(): void {
    this.dialogController = new CustomDialogController({
      builder: CreatePlaylistDialog({
        confirm: (name: string) => { this.onCreatePlaylist(name) }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center
    })
    this.dialogController.open()
  }

  private onCreatePlaylist(name: string): void {
    const api = MusicDbApi.getInstance()
    api.createOwnPlaylist(name)
    this.loadPlaylists()
    promptAction.showToast({ message: '已创建歌单', duration: 2000 })
  }

  private onPlaylistTap(playlist: PlaylistRow): void {
    if (playlist.playlistType === 1) {
      // 收藏歌单：远程模式
      const param = new SongListParam('歌单详情', '', playlist.sourceListId, playlist.source)
      this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYLIST_DETAIL, param))
    } else {
      // 自建歌单：本地模式
      const param = new SongListParam('', '', String(playlist.playlistId))
      param.title = '歌单详情'
      this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYLIST_DETAIL, param))
    }
  }

  /** 获取封面：收藏歌单用 coverUrl，自建用本地资源 */
  private getCover(playlist: PlaylistRow): string | Resource {
    if (playlist.playlistType === 1 && playlist.coverUrl) {
      return playlist.coverUrl
    }
    const api = MusicDbApi.getInstance()
    if (playlist.songIds.length > 0) {
      const firstSong = api.getSongById(playlist.songIds[0])
      if (firstSong !== undefined) {
        return firstSong.label
      }
    }
    return $r('app.media.ic_avatar1')
  }

  private onDeletePlaylist(playlist: PlaylistRow): void {
    const api = MusicDbApi.getInstance()
    let success = false
    if (playlist.playlistType === 0) {
      success = api.deleteOwnPlaylist(playlist.playlistId)
    } else {
      success = api.removeCollectedPlaylist(playlist.playlistId)
    }
    if (success) {
      promptAction.showToast({ message: '已删除', duration: 2000 })
      this.loadPlaylists()
    }
  }

  @Builder
  swipeTrashBuilder(playlist: PlaylistRow): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.trash_fill'))
        .fontSize(20)
        .fontColor(['#FF4444'])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(44)
    .height(44)
    .margin({ right: 12 })
    .onClick(() => { this.onDeletePlaylist(playlist) })
  }

  build() {
    Column() {
      // === 标题栏：我的歌单 + 新建按钮 ===
      Row() {
        Text('我的歌单')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

        Blank()

        // 新建歌单按钮
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_emphasize')])
        }
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width(32)
        .height(32)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 1.0 })
        .onClick(() => { this.openCreateDialog() })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, top: 16, right: 16, bottom: 10 })

      Divider()
        .width('100%')
        .height(1)
        .color($r('sys.color.ohos_id_color_list_separator'))

      // === 歌单列表 / 空状态 ===
      if (this.playlists.length === 0) {
        Text('暂无歌单')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 40, bottom: 40 })
      } else {
        List() {
          ForEach(this.playlists, (playlist: PlaylistRow) => {
            ListItem() {
              Row() {
                // 封面
                Image(this.getCover(playlist))
                  .width(44)
                  .height(44)
                  .borderRadius(6)
                  .objectFit(ImageFit.Cover)

                // 歌单信息
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(playlist.title)
                      .fontSize(15)
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .constraintSize({ maxWidth: 180 })

                    // 类型标签
                    if (playlist.playlistType === 1) {
                      Text('收藏')
                        .fontSize(10)
                        .fontColor(Color.White)
                        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                        .borderRadius(4)
                        .backgroundColor(SOURCE_COLORS[playlist.source] || '#999')
                    } else {
                      Text('自建')
                        .fontSize(10)
                        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                        .borderRadius(4)
                        .backgroundColor($r('sys.color.ohos_id_color_click_effect'))
                    }
                  }

                  Text(playlist.playlistType === 1
                    ? (playlist.author || '收藏歌单')
                    : `${playlist.songIds.length}首`)
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 10 })
                .layoutWeight(1)

                // 右侧箭头
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 12, bottom: 12 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.onPlaylistTap(playlist)
              })
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.swipeTrashBuilder(playlist)
                }
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }, (playlist: PlaylistRow) => `${playlist.playlistType}_${playlist.playlistId}`)
        }
        .width('100%')
        .divider({ strokeWidth: 0.5, color: '#1A000000', startMargin: 66, endMargin: 12 })
      }
    }
    .width('90%')
    .margin({ top: 12 })
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .clip(true)
  }
}
