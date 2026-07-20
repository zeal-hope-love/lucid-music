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

import { BusinessError } from '@kit.BasicServicesKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { curves } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { LyricsComponent } from './LyricsComponent';
import { MusicInfoComponent } from './MusicInfoComponent';
import { ControlAreaComponent } from './ControlAreaComponent';
import { BreakpointConstants } from '../constants/BreakpointConstants';
import { StyleConstants } from '../constants/StyleConstants';
import { PlayerConstants } from '../constants/PlayerConstants';
import { SongItem } from 'musicbasic';
import Logger from '../utils/LoggerAdapter';
import { ColorConversion } from '../utils/ColorConversion';

const TAG = 'PlayerInfoComponent'

@Component
export struct PlayerInfoComponent {
  @StorageProp('currentBreakpoint') currentBreakpoint: string = BreakpointConstants.BREAKPOINT_SM;
  @StorageLink('songList') songList: SongItem[] = [];
  @StorageProp('selectIndex') @Watch('getImageColor') selectIndex: number = 0;
  @StorageLink('imageColor') imageColor: string = 'rgba(0, 0, 2, 1.00)';
  @StorageLink('topHeight') topHeight: number = 0;
  @StorageLink('bottomHeight') bottomHeight: number = 0;
  @State imageLabel: PixelMap | Resource = this.songList[this.selectIndex].label;
  @State isShowControl: boolean = true;
  @State isShowControlLg: boolean = false;
  @State isTablet: boolean = true;
  @State isTabletFalse: boolean = false;
  @State showLyrics: boolean = false;
  @StorageLink('pageShowTime') pageShowTime: number = 0;
  @State intervalID: number = 0;
  @Link isShowPlay: boolean;
  /** 入场/退场播放过渡：true 时 MusicInfoComponent 封面跟随 MiniPlayerBar 做一镜到底 */
  @StorageLink('playbackEntering') playbackEntering: boolean = false;
  @StorageLink('isFoldFull') isFoldFull: boolean = false;
  private context: common.UIAbilityContext | undefined = AppStorage.get('context');
  private callback: Callback<display.FoldDisplayMode> = (data: display.FoldDisplayMode) => {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      if (data === display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL) {
        this.isFoldFull = true;
      } else {
        this.isFoldFull = false;
      }
    }
  };

  aboutToAppear(): void {
    Logger.info(TAG, `currentBreakpoint is ${BreakpointConstants.BREAKPOINT_SM}`)
    this.getImageColor();
    try {
      if (canIUse('SystemCapability.Window.SessionManager')) {
        let mode = display.getFoldDisplayMode();
        if (mode === display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL) {
          this.isFoldFull = true;
        }
        display.on('foldDisplayModeChange', this.callback);
      }
    } catch (exception) {
      Logger.error(TAG, `Failed to register callback. Code: ' + ${JSON.stringify(exception)}`);
    }
  }

  aboutToDisappear(): void {
    clearInterval(this.intervalID);
    if (canIUse('SystemCapability.Window.SessionManager')) {
      display.off('foldDisplayModeChange', this.callback);
    }
  }

  private startControlTimer(): void {
    this.isShowControl = true;
  }

  private resetControlTimer(): void {
    this.isShowControl = true;
  }

  build() {
    Stack() {
      Image(this.imageLabel)
        .size(this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
          { width: PlayerConstants.BACK_IMAGE } :
          { height: PlayerConstants.BACK_IMAGE })
        .aspectRatio(1)
        .objectFit(ImageFit.Cover)
        .opacity(0.5)
      Row() {
        if (this.isFoldFull) {
          Column() {
            GridRow({
              columns: { md: BreakpointConstants.COLUMN_MD },
              gutter: BreakpointConstants.GUTTER_MUSIC_X
            }) {
              GridCol({ span: { md: BreakpointConstants.SPAN_SM } }) {
                MusicInfoComponent()
              }
              .margin({ left: $r('app.float.margin_small'), right: $r('app.float.margin_small') })

              GridCol({ span: { md: BreakpointConstants.SPAN_SM } }) {
                LyricsComponent({ isTablet: this.isTabletFalse })
              }
              .padding({ left: $r('app.float.twenty_four') })
            }
            .layoutWeight(1)
            .margin({ bottom: $r('app.float.fold_margin_bottom') })
          }
          .layoutWeight(1)
          .padding({ left: $r('app.float.common_padding'), right: $r('app.float.common_padding') })
        } else if (this.currentBreakpoint === BreakpointConstants.BREAKPOINT_LG) {
          Column() {
            GridRow({
              columns: { md: BreakpointConstants.COLUMN_MD, lg: BreakpointConstants.COLUMN_LG },
              gutter: BreakpointConstants.GUTTER_MUSIC_X
            }) {
              GridCol({
                span: { md: BreakpointConstants.SPAN_SM, lg: BreakpointConstants.SPAN_SM },
                offset: { lg: BreakpointConstants.OFFSET_MD }
              }) {
                Column() {
                  if (this.songList[this.selectIndex].coverUrl) {
                    Image(this.songList[this.selectIndex].coverUrl)
                      .width(StyleConstants.FULL_WIDTH)
                      .aspectRatio(1)
                      .borderRadius($r('app.float.cover_radius'))
                  } else {
                    Image(this.songList[this.selectIndex].label)
                      .width(StyleConstants.FULL_WIDTH)
                      .aspectRatio(1)
                      .borderRadius($r('app.float.cover_radius'))
                  }
                  ControlAreaComponent()
                }
                .height(StyleConstants.FULL_HEIGHT)
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ bottom: $r('app.float.common_margin') })
              }

              GridCol({
                span: { md: BreakpointConstants.SPAN_SM, lg: BreakpointConstants.SPAN_MD },
                offset: { lg: BreakpointConstants.OFFSET_MD }
              }) {
                LyricsComponent({ isTablet: this.isTablet })
              }
            }
            .layoutWeight(1)
            .padding({
              left: $r('app.float.common_padding'), right: $r('app.float.common_padding'),
              top: $r('app.float.lg_music_top'), bottom: $r('app.float.lg_music_margin_bottom')
            })
          }
        } else {
          Column() {
            // === 顶部页面指示器 ===
            Row() {
              Row()
                .width(this.showLyrics ? 6 : 12)
                .height(6)
                .borderRadius(3)
                .backgroundColor(this.showLyrics ? '#66FFFFFF' : '#FFFFFFFF')
                .animation({ duration: 350, curve: curves.springMotion() })
              Row()
                .width(this.showLyrics ? 12 : 6)
                .height(6)
                .borderRadius(3)
                .backgroundColor(this.showLyrics ? '#FFFFFFFF' : '#66FFFFFF')
                .animation({ duration: 350, curve: curves.springMotion() })
                .margin({ left: 8 })
            }
            .width(StyleConstants.FULL_WIDTH)
            .justifyContent(FlexAlign.Center)
            .margin({ top: 16 })

            // === 内容区（if/else + geometryTransition 独立驱动） ===
            Stack() {
              if (!this.showLyrics) {
                MusicInfoComponent({ follow: !this.showLyrics || this.playbackEntering })
                  .margin({ bottom: $r('app.float.music_component_bottom') })
              } else {
                LyricsComponent({ isTablet: this.isTabletFalse, follow: this.showLyrics && !this.playbackEntering })
                  .margin({ top: $r('app.float.margin_lyric') })
              }
            }
            .layoutWeight(1)
            .gesture(
              PanGesture({ direction: PanDirection.Horizontal, distance: 20 })
                .onActionEnd((event: GestureEvent) => {
                  if (event.offsetX < -20 && !this.showLyrics) {
                    this.getUIContext()?.animateTo({ curve: curves.springMotion(0.55, 0.78) }, () => {
                      this.showLyrics = true;
                    })
                    this.startControlTimer();
                  } else if (event.offsetX > 20 && this.showLyrics) {
                    this.getUIContext()?.animateTo({ curve: curves.springMotion(0.55, 0.78) }, () => {
                      this.showLyrics = false;
                    })
                    this.resetControlTimer();
                  }
                })
            )

            // === 底部控制区（固定不动） ===
            ControlAreaComponent()
              .opacity(this.isShowControl ? 1 : 0)
              .animation({ duration: 300, curve: Curve.EaseInOut })
              .margin({
                top: 8,
                bottom: $r('app.float.music_component_bottom')
              })
          }
          .height(StyleConstants.FULL_HEIGHT)
          .width(StyleConstants.FULL_WIDTH)
          .padding({
            left: $r('app.float.common_padding'),
            right: $r('app.float.common_padding')
          })
        }
      }
      .padding({ bottom: this.bottomHeight, top: this.topHeight })
    }
    .height(StyleConstants.FULL_HEIGHT)
    .width(StyleConstants.FULL_WIDTH)
    .backgroundColor(this.imageColor)
  }

  /**
   * Get largest proportion color of an image.
   * 优先使用 coverUrl（远程封面），label（本地资源）作为兜底。
   */
  getImageColor() {
    if (!this.context) {
      return;
    }
    if (!this.songList || this.selectIndex < 0 || this.selectIndex >= this.songList.length) {
      return;
    }
    const songItem = this.songList[this.selectIndex]
    if (!songItem) {
      return;
    }
    ColorConversion.setSysBarLightBackground(songItem.isDarkBackground);
    // 优先使用远程封面 URL
    if (songItem.coverUrl) {
      this.processRemoteCover(songItem.coverUrl, songItem);
      return;
    }
    // 回退到本地 label Resource
    if (songItem.label) {
      this.processLabelCover(songItem);
    }
  }

  /**
   * 通过 http 下载远程封面图，提取主色调并生成模糊背景。
   */
  private processRemoteCover(coverUrl: string, songItem: SongItem): void {
    try {
      http.createHttp().request(coverUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 10000
      }).then((resp) => {
        if (resp.responseCode !== 200 || !resp.result) {
          Logger.warn(TAG, `cover download failed, code: ${resp.responseCode}`);
          // 回退到 label
          if (songItem.label) {
            this.processLabelCover(songItem);
          }
          return;
        }
        const buffer = resp.result as ArrayBuffer;
        this.extractImageColorAndBlur(buffer);
      }).catch((error: BusinessError) => {
        Logger.error(TAG, `cover download error: ${error.message}`);
        // 回退到 label
        if (songItem.label) {
          this.processLabelCover(songItem);
        }
      })
    } catch (e) {
      Logger.error(TAG, `cover download exception`);
    }
  }

  /**
   * 从本地 label Resource 加载封面，提取主色调并生成模糊背景。
   */
  private processLabelCover(songItem: SongItem): void {
    this.context!.resourceManager.getMediaContent(songItem.label.id)
      .then((value: Uint8Array) => {
        const buffer = value.buffer as ArrayBuffer;
        this.extractImageColorAndBlur(buffer);
      })
      .catch((error: BusinessError) => {
        Logger.error(TAG, `getMediaContent failed ${error.code} + ${error.message}`);
      })
  }

  /**
   * 从 ArrayBuffer 创建 PixelMap，提取主色调并生成模糊背景。
   */
  private extractImageColorAndBlur(buffer: ArrayBuffer): void {
    image.createImageSource(buffer).createPixelMap({
      desiredSize: { width: PlayerConstants.BLUR_SOURCE_SIZE, height: PlayerConstants.BLUR_SOURCE_SIZE }
    }).then((pixelMap) => {
      effectKit.createColorPicker(pixelMap, (error, colorPicker) => {
        if (error) {
          Logger.error(TAG, 'Failed to create color picker.');
        } else {
          let color = colorPicker.getLargestProportionColor();
          let colorArr = ColorConversion.dealColor(color.red, color.green, color.blue);
          this.imageColor = `rgba(${colorArr[0]}, ${colorArr[1]}, ${colorArr[2]}, 1)`;
        }
      })
      let headFilter = effectKit.createEffect(pixelMap);
      if (headFilter !== null) {
        headFilter.blur(PlayerConstants.IMAGE_BLUR);
        headFilter.getEffectPixelMap().then((value) => {
          this.imageLabel = value;
        })
      }
    })
      .catch((error: BusinessError) => {
        Logger.error(TAG, `createPixelMap failed ${error.code} + ${error.message}`);
      })
  }
}
