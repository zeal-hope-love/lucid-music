/*
 * Lucid Music - 歌单卡片组件（对齐 MusicHome-master 样式）
 * 正方形封面 + 左下角播放量叠加 + 下方歌单名称，网格展示，不左右滑动。
 */
import { MusichallPlaylistItem, RouterUrlConstants, MusicCoverImage } from 'musicbasic'
import { SongListParam } from 'musicbasic'

@ComponentV2
export struct PlaylistCard {
  @Consumer() navPathStack: NavPathStack = new NavPathStack()
  @Param item: MusichallPlaylistItem = new MusichallPlaylistItem()

  build() {
    Column() {
      // 封面区域（正方形，对齐 MusicHome-master ForYouSection 样式）
      Stack({ alignContent: Alignment.BottomStart }) {
        // 封面图（支持本地资源和网络URL）
        if (typeof this.item.coverImage === 'string') {
          // 网络图片：kw 走带 Referer 下载渲染，其它平台原生 Image
          MusicCoverImage({ url: this.item.coverImage, source: this.item.source })
        } else {
          // 本地资源
          Image(this.item.coverImage)
            .width('100%')
            .aspectRatio(1)
            .objectFit(ImageFit.Fill)
            .borderRadius(8)
            .draggable(false)
        }

        // 左下角播放量叠加（MusicHome 风格）
        if (this.item.playCount !== '') {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
              .fontSize(20)
              .fontColor([Color.White])

            Text(this.item.playCount)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .lineHeight(13)
          }
          .padding(4)
        }
      }
      .width('100%')
      .clip(true)

      // 歌单名称（最多两行）
      Text(this.item.title)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .lineHeight(19)
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      const param = new SongListParam(
        typeof this.item.title === 'string' ? this.item.title : '',
        '',
        this.item.playlistId,
        this.item.source
      )
      this.navPathStack.pushPath(
        new NavPathInfo(RouterUrlConstants.PLAYLIST_DETAIL, param),
        { animated: false }
      )
    })
  }
}
