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
 * 播放模式枚举（model 层唯一可信源）。
 * 定义在 musicbasic/model 以便 musicbasic 与 player 均可引用，避免 model → player 的循环依赖。
 * 值对齐历史 AppStorage('playMode') 约定：0=单曲循环, 1=顺序, 2=随机。
 */
export enum MusicPlayMode {
  SINGLE_CYCLE = 0,
  ORDER = 1,
  RANDOM = 2
}

/**
 * 模式切换顺序：顺序 → 随机 → 单曲循环 → 顺序。
 * 作为 UI 切换（ControlAreaComponent）与 AVSession 回调的统一推进顺序。
 */
export const PLAY_MODE_CYCLE_ORDER: MusicPlayMode[] = [
  MusicPlayMode.ORDER,
  MusicPlayMode.RANDOM,
  MusicPlayMode.SINGLE_CYCLE
]
