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
 * Constants for breakpoint.
 */
export class BreakpointConstants {
  static readonly BREAKPOINT_SM: string = 'sm';
  static readonly BREAKPOINT_MD: string = 'md';
  static readonly BREAKPOINT_LG: string = 'lg';
  static readonly BREAKPOINT_VALUE: Array<string> = ['320vp', '600vp', '840vp'];
  static readonly BREAKPOINT_VALUE_NUMBER: Array<number> = [320, 600, 840];
  static readonly COLUMN_SM: number = 4;
  static readonly COLUMN_MD: number = 8;
  static readonly COLUMN_LG: number = 12;
  static readonly COLUMN_LYRIC_LG: number = 7;
  static readonly GUTTER_X: number = 12;
  static readonly GUTTER_MUSIC_X: number = 24;
  static readonly SPAN_SM: number = 4;
  static readonly SPAN_MD: number = 6;
  static readonly SPAN_LG: number = 8;
  static readonly SPAN_LYRIC_LG: number = 5;
  static readonly OFFSET_MD: number = 1;
  static readonly OFFSET_LG: number = 2;
  static readonly CURRENT_BREAKPOINT: string = 'currentBreakpoint';
  static readonly FONT_SIZE_SM: number = 14;
  static readonly FONT_SIZE_MD: number = 16;
  static readonly FONT_SIZE_LG: number = 18;
  static readonly COVER_MARGIN_SM: number = 10;
  static readonly COVER_MARGIN_MD: number = 30;
  static readonly COVER_MARGIN_LG: number = 40;
  static readonly RANGE_SM: string = '(320vp<=width<600vp)';
  static readonly RANGE_MD: string = '(600vp<=width<840vp)';
  static readonly RANGE_LG: string = '(840vp<=width)';
}
