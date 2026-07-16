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

import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { PlayerConstants } from '../constants/PlayerConstants';
import { BreakpointType } from '../utils/BreakpointSystem';
import { AVSessionController } from '../controller/AVSessionController';
import { StyleConstants } from '../constants/StyleConstants';
import { BreakpointConstants } from '../constants/BreakpointConstants';
import { LyricFile, LyricScrollEffect, LyricTopPosition } from '../constants/LyricConst';
import { LrcEntry } from '../viewmodel/LrcEntry';
import { SongItem } from '../viewmodel/SongData';
import { parseKrcLyric, parseLrcLyric } from '../utils/LrcUtils';
import LrcView from './LrcView';
import { MusicDbApi } from 'musicbasic';

@Component
export struct LyricsComponent {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @StorageLink('progress') time: number = 0;
  @StorageLink('isFoldFull') isFoldFull: boolean = false;
  @State progress: number = 0.01;
  @State progressText: string = '';
  @State lyricScrollEffect: LyricScrollEffect = LyricScrollEffect.Line;
  @State mLrcEntryList: Array<LrcEntry> = [];
  @StorageLink('songList') songList: SongItem[] = [];
  @StorageProp('selectIndex') @Watch('getLrcEntryList') selectIndex: number = 0;
  @StorageLink('isPlay') isPlay: boolean = false;
  @StorageLink('isFavorite') isFavorite: boolean = false;
  @Link isTablet: boolean;
  @Prop follow: boolean = false;
  private context: common.UIAbilityContext | undefined = AppStorage.get('context');

  aboutToAppear() {
    this.getLrcEntryList();
    this.syncFavoriteState();
  }

  syncFavoriteState(): void {
    if (this.songList.length > 0 && this.selectIndex < this.songList.length) {
      const songId = this.songList[this.selectIndex].id
      this.isFavorite = MusicDbApi.getInstance().isFavorite(songId)
    }
  }

  getLrcEntryList() {
    this.mLrcEntryList = [];
    if (!this.context) {
      return;
    }
    if (!this.songList || this.selectIndex < 0 || this.selectIndex >= this.songList.length) {
      return;
    }
    this.syncFavoriteState();

    const songItem = this.songList[this.selectIndex]

    // 优先使用 lyricText（远程歌曲的直接歌词文本）
    if (songItem.lyricText && songItem.lyricText.length > 0) {
      this.mLrcEntryList = parseLrcLyric(songItem.lyricText)
      return
    }

    // 回退：从文件系统读取歌词文件
    if (!songItem.lyric || songItem.lyric.length === 0) {
      return
    }
    this.context.resourceManager.getRawFileContent(songItem.lyric)
      .then((value: Uint8Array) => {
        let textDecoder = util.TextDecoder.create(PlayerConstants.ENCODING, { ignoreBOM: true });
        let stringData = textDecoder.decodeToString(value, { stream: false });
        if (songItem.lyric.endsWith(LyricFile.KRC)) {
          this.mLrcEntryList = parseKrcLyric(stringData);
        } else if (songItem.lyric.endsWith(LyricFile.LRC)) {
          this.mLrcEntryList = parseLrcLyric(stringData);
        }
      })
  }

  build() {
    Column() {
      if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM) {
        Row() {
          Row() {
            if (!this.isTablet) {
              if (this.songList.length > 0 && this.selectIndex >= 0 &&
                  this.selectIndex < this.songList.length &&
                  this.songList[this.selectIndex] &&
                  this.songList[this.selectIndex].coverUrl) {
                Image(this.songList[this.selectIndex].coverUrl)
                  .width(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ?
                    $r('app.float.label_width_sm') : $r('app.float.label_width'))
                  .borderRadius(6)
                  .shadow({
                    radius: $r('app.float.shadow_radius'),
                    color: $r('app.color.shadow_color'),
                    offsetX: 0,
                    offsetY: 8
                  })
                  .margin({ right: $r('app.float.label_margin_right') })
                  .geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })
              } else {
                Image($r('app.media.ic_music_symbol'))
                  .width(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_SM ?
                    $r('app.float.label_width_sm') : $r('app.float.label_width'))
                  .borderRadius(6)
                  .shadow({
                    radius: $r('app.float.shadow_radius'),
                    color: $r('app.color.shadow_color'),
                    offsetX: 0,
                    offsetY: 8
                  })
                  .margin({ right: $r('app.float.label_margin_right') })
                  .geometryTransition('PLAYBACK_COVER_TRANSITION', { follow: this.follow })
              }
            }
            Column() {
              Text(this.songList[this.selectIndex].title)
                .fontSize(new BreakpointType({
                  sm: $r('app.float.title_font_sm'),
                  md: $r('app.float.title_font_md'),
                  lg: $r('app.float.title_font_lg')
                }).getValue(this.currentBreakpoint))
                .fontColor(Color.White)
                .fontWeight(PlayerConstants.FONT_WEIGHT_700)
                .fontFamily(PlayerConstants.FONT_FAMILY_BOLD)
                .constraintSize({ minWidth: 200 })
                .geometryTransition('PLAYBACK_TITLE_TRANSITION', { follow: this.follow })
              Text(this.songList[this.selectIndex].singer)
                .fontSize(new BreakpointType({
                  sm: $r('app.float.singer_font_sm'),
                  md: $r('app.float.singer_font_md'),
                  lg: $r('app.float.singer_font_lg')
                }).getValue(this.currentBreakpoint))
                .fontColor(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
                  $r('app.color.singer_text') : $r('sys.color.ohos_id_color_text_hint_contrary'))
                .fontWeight(PlayerConstants.FONT_WEIGHT_500)
                .fontFamily(PlayerConstants.FONT_FAMILY_MEDIUM)
                .margin({ top: $r('app.float.singer_margin_top') })
                .constraintSize({ minWidth: 200 })
                .geometryTransition('PLAYBACK_SINGER_TRANSITION', { follow: this.follow })
            }
            .alignItems(HorizontalAlign.Start)
          }

          SymbolGlyph(this.isFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(26)
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            .fontColor([this.isFavorite ? Color.Red : Color.White])
            .opacity(0.86)
            .geometryTransition('PLAYBACK_FAVORITE_TRANSITION', { follow: this.follow })
            .onClick(() => {
              const songId = this.songList[this.selectIndex].id
              const nowFav = MusicDbApi.getInstance().toggleFavorite(songId)
              this.isFavorite = nowFav
              AVSessionController.getInstance().updateFavoriteState(songId.toString(), nowFav)
            })
        }
        .width(StyleConstants.FULL_WIDTH)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .margin({
          top: 16,
          bottom: $r('app.float.info_margin_bottom')
        })
      }

      if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG) {
        Row() {
          GridRow({
            columns: { lg: BreakpointConstants.COLUMN_LYRIC_LG }
          }) {
            GridCol({
              span: { lg: BreakpointConstants.SPAN_LYRIC_LG },
              offset: BreakpointConstants.OFFSET_MD
            }) {
              Column() {
                Row() {
                  Column() {
                    Text(this.songList[this.selectIndex].title)
                      .fontSize(new BreakpointType({
                        sm: $r('app.float.title_font_sm'),
                        md: $r('app.float.title_font_md'),
                        lg: $r('app.float.title_font_lg')
                      }).getValue(this.currentBreakpoint))
                      .fontColor(Color.White)
                      .fontWeight(PlayerConstants.FONT_WEIGHT_700)
                      .fontFamily(PlayerConstants.FONT_FAMILY_BOLD)
                    Text(this.songList[this.selectIndex].singer)
                      .fontSize(new BreakpointType({
                        sm: $r('app.float.singer_font_sm'),
                        md: $r('app.float.singer_font_md'),
                        lg: $r('app.float.singer_font_lg')
                      }).getValue(this.currentBreakpoint))
                      .fontColor($r('sys.color.ohos_id_color_text_hint_contrary'))
                      .fontFamily(PlayerConstants.FONT_FAMILY_MEDIUM)
                      .margin({ top: $r('app.float.singer_margin_top') })
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width(StyleConstants.FULL_WIDTH)
                .justifyContent(FlexAlign.Start)
                .margin({
                  top: new BreakpointType({
                    sm: $r('app.float.info_margin_top_sm'),
                    md: $r('app.float.zero_margin'),
                    lg: $r('app.float.zero_margin')
                  }).getValue(this.currentBreakpoint),
                  bottom: $r('app.float.info_margin_bottom')
                })

                LrcView({
                  lyricMilliSecondsTime: this.time,
                  mLrcEntryList: this.mLrcEntryList,
                  lyricScrollEffect: this.lyricScrollEffect,
                  lyricTopPosition: LyricTopPosition.Middle
                })
                  .layoutWeight(1)
              }
            }
          }
        }
        .layoutWeight(1)
      } else {
        LrcView({
          lyricMilliSecondsTime: this.time,
          mLrcEntryList: this.mLrcEntryList,
          lyricScrollEffect: this.lyricScrollEffect,
          lyricTopPosition: LyricTopPosition.Middle
        })
          .layoutWeight(1)
      }

      // （歌词底部 icon 已移除，歌词区域撑满）
    }
  }
}
