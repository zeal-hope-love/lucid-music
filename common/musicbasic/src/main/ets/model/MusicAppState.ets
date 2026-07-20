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
 * Global observable playback state (AppStorageV2 key: MusicAppState).
 * Playback requests use {@link PlaybackIntentState} and are applied by the product shell, then media services.
 */
import { SongItem } from './SongData';
import { MusicPlayMode, PLAY_MODE_CYCLE_ORDER } from './PlayMode';

@ObservedV2
export class  MusicAppState {
  /** Current queue: full song objects (local & remote treated equally). Single source of truth. */
  @Trace public playQueue: SongItem[] = [];
  /** Index in {@link playQueue} for the current track. */
  @Trace public selectIndex: number = 0;
  /** Whether audio is currently playing. */
  @Trace public isPlay: boolean = false;
  /** Elapsed position for the progress bar (0..progressMax when known). */
  @Trace public progress: number = 0;
  /** Duration for the current track, or 0/1 when unknown. */
  @Trace public progressMax: number = 0;
  /** Formatted current time string for UI. */
  @Trace public currentTime: string = '00:00';
  /** Formatted total duration string for UI. */
  @Trace public totalTime: string = '00:00';
  /** Whether the full-screen player overlay is visible. */
  @Trace public isShowPlay: boolean = false;
  /** Time spent on the now-playing sub-page (e.g. to auto-hide chrome). */
  @Trace public pageShowTime: number = 0;
  /** UI volume in 0..1; mirrored to the player when applied. */
  @Trace public volume: number = 0.4;
  /** Cold-start hint for first-launch UI behavior. */
  @Trace public isFirstLaunch: boolean = true;
  /** Full-screen player background color sampled from current artwork. */
  @Trace public imageColor: string = 'rgba(0, 0, 2, 1.00)';
  /** HdsTabs mini bar expanded (true) vs compact (false). */
  @Trace public miniBarExpanded: boolean = false;
  /** 播放状态: idle | requesting_url | preparing | ready | error */
  @Trace public playbackStatus: string = 'idle';
  /** 播放状态可读文本（如 "正在请求播放地址..."） */
  @Trace public playbackStatusMessage: string = '';
  /** 播放模式: 顺序 / 随机 / 单曲循环。由本类作为唯一可信源（强类型 MusicPlayMode）。 */
  @Trace public playMode: MusicPlayMode = MusicPlayMode.ORDER;
  /** 当前播放队列所属歌单标题（用于播放列表弹层展示；默认"最近播放"）。 */
  @Trace public currentPlaylistTitle: string = '最近播放';
  /** 当前歌曲是否已收藏. */
  @Trace public isFavorite: boolean = false;
  /** 是否静音模式. */
  @Trace public isSilentMode: boolean = false;
  /** 当前音量 0-100. */
  @Trace public currentVolume: number = 100;

  /**
   * Returns the {@link SongItem} at the given queue index directly (O(1)).
   * @param queueIndex Index into {@link playQueue}.
   * @returns A song item, or undefined if the index is out of range.
   */
  public resolveSongAtQueueIndex(queueIndex: number): SongItem | undefined {
    if (queueIndex < 0 || queueIndex >= this.playQueue.length) {
      return undefined;
    }
    return this.playQueue[queueIndex];
  }

  /**
   * @returns The item at {@link selectIndex}, or undefined.
   */
  public getCurrentSongItem(): SongItem | undefined {
    if (this.selectIndex < 0 || this.selectIndex >= this.playQueue.length) {
      return undefined;
    }
    return this.playQueue[this.selectIndex];
  }

  /**
   * @returns The length of {@link playQueue}.
   */
  public getQueueLength(): number {
    return this.playQueue.length;
  }

  /**
   * 设置播放模式并同步到 AppStorage V1（供 V1 组件 @StorageLink('playMode') 消费）。
   * 本类为播放模式的唯一可信源。
   * @param mode 目标模式
   */
  public setPlayMode(mode: MusicPlayMode): void {
    this.playMode = mode;
    AppStorage.setOrCreate('playMode', mode);
  }

  /**
   * 按 {@link PLAY_MODE_CYCLE_ORDER} 推进到下一播放模式，并同步到 V1。
   * UI 切换与 AVSession 回调统一走这里，避免切换顺序分散。
   * @returns 切换后的新模式
   */
  public cyclePlayMode(): MusicPlayMode {
    const order = PLAY_MODE_CYCLE_ORDER;
    const idx = order.indexOf(this.playMode);
    const next = order[(idx + 1) % order.length];
    this.setPlayMode(next);
    return next;
  }
}
