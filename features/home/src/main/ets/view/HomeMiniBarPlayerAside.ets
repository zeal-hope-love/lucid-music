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

import { PlayerConstants, PlayerViewModel } from 'player';


/**
 * Mini player row: title, artist, transport controls, and playlist affordance beside the cover.
 */
@ComponentV2
export struct HomeMiniBarPlayerAside {
  /** Navigation stack consumed from ancestor {@code @Provider} for playlist routing. */
  @Consumer('pageIndexInfos') pageIndexInfos: NavPathStack = new NavPathStack();
  /** Shared player state and actions (play/pause, next, open full screen). */
  @Param playerViewModel: PlayerViewModel = new PlayerViewModel();
  /** When true, shows the previous-track control before play/pause. */
  @Param showPreviousTrack: boolean = false;

  /**
   * Lays out metadata column, optional previous track, play/pause, next, and queue buttons.
   */
  build() {
    Row() {
      Column() {
        Text(this.playerViewModel.songTitle())
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontSize(12)
          .fontWeight(600)
          .lineHeight(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.playerViewModel.songSinger())
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          .fontSize(10)
          .lineHeight(13)
          .fontWeight(FontWeight.Regular)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(PlayerConstants.LAYOUT_WEIGHT_PLAYER_CONTROL)
      .onClick(() => {
        this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
      })

      Row({ space: 16 }) {
        if (this.showPreviousTrack) {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize(24)
            .fontWeight(FontWeight.Regular)
            .height(24)
            .fontColor(['#FFFFFFFF'])
            .onClick(() => {
              this.playerViewModel.playPrevious();
            })
        }

        SymbolGlyph(this.playerViewModel.appState.isPlay ?
          $r('sys.symbol.pause_circle_fill') :
          $r('sys.symbol.play_circle_fill'))
          .fontSize(24)
          .fontWeight(FontWeight.Regular)
          .height(24)
          .fontColor(['#FFFFFFFF'])
          .onClick(() => {
            this.playerViewModel.togglePlayPause();
          })

        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(24)
          .fontWeight(FontWeight.Regular)
          .height(24)
          .fontColor(['#FFFFFFFF'])
          .onClick(() => this.playerViewModel.playNext())

        SymbolGlyph($r('sys.symbol.music_note_list'))
          .fontSize(24)
          .fontWeight(FontWeight.Regular)
          .height(24)
          .fontColor(['#FFFFFFFF'])
          .onClick(() => {
            this.playerViewModel.pushPlaylistDetail(this.pageIndexInfos);
          })
      }
    }
    .layoutWeight(1)
    .onClick(() => {
      this.playerViewModel.openFullScreenWithSharedElementTransition(this.getUIContext());
    })
  }
}
