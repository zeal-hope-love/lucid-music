/*
 * Lucid Music - 歌单区域组件
 * 布局：切换按钮（自建歌单 | 收藏歌单）+ 歌单列表（封面 + 歌单名 + 数量）
 * 功能：左滑删除（仅自建歌单）
 */
import { promptAction } from '@kit.ArkUI'
import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStorageKeys, CurrentTabState, MusicDbApi, PlaylistRow, RouterUrlConstants, SongListParam
} from 'musicbasic'

@ComponentV2
export struct PlaylistSection {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Local currentType: number = 0 // 0 = 自建歌单, 1 = 收藏歌单
  @Local playlists: PlaylistRow[] = []
  @Local currentTabState: CurrentTabState =
    AppStorageV2.connect(CurrentTabState, AppStorageKeys.CURRENT_TAB_STATE, () => new CurrentTabState())!
  /** playlistId → 第一首歌封面 Resource */
  @Local coverMap: Map<number, Resource> = new Map()
  /** 待删除的歌单 ID（用于左滑删除） */
  @Local pendingDeleteId: number = 0

  aboutToAppear(): void {
    this.loadPlaylists()
  }

  @Monitor('currentTabState.refreshCounter')
  onRefreshCounterChanged(): void {
    this.loadPlaylists()
  }

  private loadPlaylists(): void {
    const api = MusicDbApi.getInstance()
    if (this.currentType === 0) {
      this.playlists = api.getOwnPlaylists()
    } else {
      this.playlists = api.getCollectedPlaylists()
    }
    // 预加载每首歌单第一首歌的封面
    this.coverMap.clear()
    for (const pl of this.playlists) {
      if (pl.songIds.length > 0) {
        const firstSong = api.getSongById(pl.songIds[0])
        if (firstSong !== undefined) {
          this.coverMap.set(pl.playlistId, firstSong.label)
        }
      }
    }
  }

  private onToggle(type: number): void {
    if (this.currentType === type) {
      return
    }
    this.currentType = type
    this.loadPlaylists()
  }

  private onPlaylistTap(playlist: PlaylistRow): void {
    const param = new SongListParam('', '', playlist.playlistId)
    param.title = '歌单详情'
    this.navPathStack.pushPath(new NavPathInfo(RouterUrlConstants.PLAYLIST_DETAIL, param))
  }

  /** 获取歌单第一首歌封面，无则返回占位 */
  private getCover(playlistId: number): Resource {
    return this.coverMap.get(playlistId) ?? $r('app.media.ic_avatar1')
  }

  // ==================== 左滑删除 ====================

  private async onDeletePlaylist(playlistId: number): Promise<void> {
    const api = MusicDbApi.getInstance()
    let success = false
    
    // 根据当前歌单类型调用不同的删除方法
    if (this.currentType === 0) {
      // 自建歌单：删除歌单
      success = api.deleteOwnPlaylist(playlistId)
    } else {
      // 收藏歌单：取消收藏
      success = api.removeCollectedPlaylist(playlistId)
    }
    
    if (success) {
      promptAction.showToast({ message: '已删除', duration: 2000 })
      this.loadPlaylists()
    }
  }

  @Builder
  swipeTrashBuilder(): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.trash_fill'))
        .fontSize(20)
        .fontColor(['#FF4444'])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(44)
    .height(44)
    .margin({ right: 12 })
    .onClick(() => { this.onDeletePlaylist(this.pendingDeleteId) })
  }

  build() {
    Column() {
      // === 切换按钮：自建歌单 | 收藏歌单 ===
      Row({ space: 0 }) {
        // 自建歌单按钮
        Column() {
          Text('自建歌单')
            .fontSize(17)
            .fontWeight(this.currentType === 0 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentType === 0
              ? $r('sys.color.ohos_id_color_text_primary')
              : $r('sys.color.ohos_id_color_text_secondary'))
        }
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .borderRadius(8)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 1.0 })
        .onClick(() => { this.onToggle(0) })

        // 分隔竖线
        Text('|')
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_list_separator'))
          .margin({ left: 12, right: 12 })

        // 收藏歌单按钮
        Column() {
          Text('收藏歌单')
            .fontSize(17)
            .fontWeight(this.currentType === 1 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentType === 1
              ? $r('sys.color.ohos_id_color_text_primary')
              : $r('sys.color.ohos_id_color_text_secondary'))
        }
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .borderRadius(8)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 1.0 })
        .onClick(() => { this.onToggle(1) })
      }
      .width('100%')
      .padding({ left: 16, top: 16, right: 16, bottom: 10 })

      Divider()
        .width('100%')
        .height(1)
        .color($r('sys.color.ohos_id_color_list_separator'))

      // === 歌单列表 / 空状态 ===
      if (this.playlists.length === 0) {
        Text(this.currentType === 0 ? '暂无自建歌单' : '暂无收藏歌单')
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
                // 第一首歌封面
                Image(this.getCover(playlist.playlistId))
                  .width(44)
                  .height(44)
                  .borderRadius(6)
                  .objectFit(ImageFit.Cover)

                // 歌单名称 + 歌曲数量
                Column({ space: 4 }) {
                  Text(playlist.title)
                    .fontSize(15)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`${playlist.songIds.length}首`)
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
            // 左滑删除（自建歌单和收藏歌单都支持）
            .swipeAction({
              end: {
                builder: () => {
                  // 使用局部变量捕获当前 playlist，避免闭包捕获错误
                  const currentPlaylist = playlist
                  this.pendingDeleteId = currentPlaylist.playlistId
                  this.swipeTrashBuilder()
                }
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }, (playlist: PlaylistRow) => playlist.playlistId.toString())
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
