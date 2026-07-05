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


/**
 * Music information entity class.
 * @ObservedV2 and @Trace for V2 state management deep observation.
 */
@ObservedV2
export class SongItem {
  /**
   * Primary key ID.
   */
  @Trace public id: number = 0;

  /**
   * Music name (plain string or string resource for i18n).
   */
  public title: string | Resource = '';

  /**
   * Music author name (plain string or string resource for i18n).
   */
  public singer: string | Resource = '';

  /**
   * Music logo information.
   * Resource type may not support @Trace - kept as plain field.
   */
  public mark: Resource = $r('app.string.page_show');

  /**
   * Music avatar information.
   * Resource type may not support @Trace - kept as plain field.
   */
  public label: Resource = $r('app.string.page_show');

  /**
   * Remote cover image URL (used for songs from audio sources).
   */
  public coverUrl: string = '';

  /**
   * Music file path information.
   */
  @Trace public src: string = '';

  /**
   * Index of the current music list.
   */
  @Trace public index: number = 0;

  /**
   * Lyric file path information.
   */
  @Trace public lyric: string = '';

  /**
   * Raw lyric text (used for remote songs where no local file exists).
   * When non-empty, LyricsComponent parses this directly instead of reading a file.
   */
  @Trace public lyricText: string = '';
}
