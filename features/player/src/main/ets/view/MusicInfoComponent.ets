/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { BreakpointConstants } from '../constants/BreakpointConstants';
import { PlayerConstants } from '../constants/PlayerConstants';
import { StyleConstants } from '../constants/StyleConstants';
import { BreakpointType } from '../utils/BreakpointSystem';
import { AVSessionController } from '../controller/AVSessionController';
import { SongItem } from '../viewmodel/SongData';
import { MusicDbApi } from 'musicbasic';

@Extend(Image)
function controlImageBuilder() {
  .aspectRatio(1)
  .opacity(0.86)
  .objectFit(ImageFit.Contain)
}

@Preview
@Component
export struct MusicInfoComponent {
  @State currentTabIndex: number = 0;
  @Prop follow: boolean = false;
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @StorageLink('isFoldFull') isFoldFull: boolean = false;
  @StorageLink('songList') songList: SongItem[] = [];
  @StorageProp('selectIndex') @Watch('syncFavoriteState') selectIndex: number = 0;
  @State isShowControl: boolean = false;
  @StorageLink('isFavorite') isFavorite: boolean = false;

  aboutToAppear(): void {
    this.syncFavoriteState()
  }

  syncFavoriteState(): void {
    if (this.songList.length > 0 && this.selectIndex >= 0 &&
        this.selectIndex < this.songList.length && this.songList[this.selectIndex]) {
      const songId = this.songList[this.selectIndex].id
      this.isFavorite = MusicDbApi.getInstance().isFavorite(songId)
    }
  }

  build() {
    GridRow({
      columns: {
        xs: BreakpointConstants.COLUMN_SM,
        sm: BreakpointConstants.COLUMN_SM,
        md: BreakpointConstants.COLUMN_MD
      },
      gutter: BreakpointConstants.GUTTER_MUSIC_X,
      breakpoints: { reference: BreakpointsReference.ComponentSize }
    }) {
      GridCol({
        span: {
          xs: BreakpointConstants.SPAN_SM,
          sm: BreakpointConstants.SPAN_SM,
          md: BreakpointConstants.SPAN_MD
        },
        offset: { md: BreakpointConstants.OFFSET_MD }
      }) {
        Column() {
          this.CoverInfo()
          this.MusicInfo()
        }
        .width(StyleConstants.FULL_WIDTH)
        .clip(false)
      }
    }
  }

  @Builder
  CoverInfo() {
    Row() {
      if (this.songList.length > 0 && this.selectIndex >= 0 &&
          this.selectIndex < this.songList.length &&
          this.songList[this.selectIndex] &&
          this.songList[this.selectIndex].coverUrl) {
        Image(this.songList[this.selectIndex].coverUrl)
          .width(StyleConstants.FULL_WIDTH)
          .aspectRatio(1)
          .borderRadius($r('app.float.cover_radius_label'))
          .shadow({
            radius: $r('app.float.shadow_radius'),
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 8
          })
          .margin($r('app.float.lyric_margin_right_sm'))
          .geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })
      } else if (this.songList.length > 0 && this.selectIndex >= 0 &&
                 this.selectIndex < this.songList.length &&
                 this.songList[this.selectIndex]) {
        Image(this.songList[this.selectIndex].label)
          .width(StyleConstants.FULL_WIDTH)
          .aspectRatio(1)
          .borderRadius($r('app.float.cover_radius_label'))
          .shadow({
            radius: $r('app.float.shadow_radius'),
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 8
          })
          .margin($r('app.float.lyric_margin_right_sm'))
          .geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })
      }
    }
  }

  @Builder
  MusicInfo() {
    Row() {
      Column() {
        Text(this.songList.length > 0 && this.selectIndex >= 0 &&
             this.selectIndex < this.songList.length ?
             this.songList[this.selectIndex].title : '')
          .fontSize(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_MD && !this.isFoldFull ?
            $r('app.float.title_font_play_md') : $r('app.float.title_font_play'))
          .fontColor(Color.White)
          .opacity(0.86)
          .fontWeight(FontWeight.Bold)
          .fontFamily(PlayerConstants.FONT_FAMILY_BOLD)
          .constraintSize({ minWidth: 200 })
          .geometryTransition('PLAYBACK_TITLE_TRANSITION', { follow: this.follow })
        Text(this.songList.length > 0 && this.selectIndex >= 0 &&
             this.selectIndex < this.songList.length ?
             this.songList[this.selectIndex].singer : '')
          .textAlign(TextAlign.Start)
          .fontSize(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_MD && !this.isFoldFull ?
            $r('app.float.title_font_play') : $r('app.float.font_fourteen'))
          .fontColor($r('app.color.play_text_color'))
          .fontFamily(PlayerConstants.FONT_FAMILY_BLACK)
          .margin({ top: $r('app.float.music_text_margin_top') })
          .fontWeight(FontWeight.Regular)
          .constraintSize({ minWidth: 200 })
          .geometryTransition('PLAYBACK_SINGER_TRANSITION', { follow: this.follow })
      }
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph(this.isFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
        .fontSize(26)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.isFavorite ? Color.Red : Color.White])
        .opacity(0.86)
        .geometryTransition('PLAYBACK_FAVORITE_TRANSITION', { follow: this.follow })
        .onClick(() => {
          if (!this.songList || this.selectIndex < 0 || this.selectIndex >= this.songList.length) {
            return
          }
          const songItem = this.songList[this.selectIndex]
          if (!songItem) {
            return
          }
          const songId = songItem.id
          const nowFav = MusicDbApi.getInstance().toggleFavorite(songId)
          this.isFavorite = nowFav
          AVSessionController.getInstance().updateFavoriteState(songId.toString(), nowFav)
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Top)
    .margin({ top: $r('app.float.music_info_margin_top') })
  }
}
