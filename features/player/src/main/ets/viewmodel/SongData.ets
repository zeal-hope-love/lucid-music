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
 * Music information entity class (avplayer format, used within features/player UI).
 */
export class SongItem {
  id: number = 0;
  title: Resource | undefined;
  singer: Resource | undefined;
  mark: Resource = $r('app.string.page_show');
  label: Resource = $r('app.string.page_show');
  src: string = '';
  index: number = 0;
  lyric: string = '';
  isDarkBackground: boolean = false;
}
