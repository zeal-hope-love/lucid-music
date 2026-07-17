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
import { SongDtoMapper } from '../api/SongDtoMapper';
import { SongItem } from './SongData';
import { MusicDbApi } from '../util/MusicDbApi';

@ObservedV2
export class  MusicAppState {
  /** Current queue: song ids only; rows resolved on demand via {@link MusicDbApi}. */
  @Trace public playQueueIds: number[] = [];
  /** Index in {@link playQueueIds} for the current track. */
  @Trace public selectIndex: number = 0;
  /** Whether audio is currently playing. */
  @Trace public isPlay: boolean = false;
  /** Currently playing remote song info (set when source provides URL). */
  @Trace public remoteSongItem: SongItem | null = null;
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
  /** 播放模式: 0=单曲循环, 1=顺序, 2=随机 (aligns with MusicPlayMode enum). */
  @Trace public playMode: number = 1;
  /** 当前歌曲是否已收藏. */
  @Trace public isFavorite: boolean = false;
  /** 是否静音模式. */
  @Trace public isSilentMode: boolean = false;
  /** 当前音量 0-100. */
  @Trace public currentVolume: number = 100;

  /**
   * Resolves a {@link SongItem} for the given queue index without keeping a full table in memory.
   * @param queueIndex Index into playQueueIds.
   * @returns A song item, or undefined if the index is out of range.
   */
  public resolveSongAtQueueIndex(queueIndex: number): SongItem | undefined {
    const ids = this.playQueueIds;
    if (queueIndex < 0 || queueIndex >= ids.length) {
      return undefined;
    }
    const dto = MusicDbApi.getInstance().getSongById(ids[queueIndex]);
    return dto !== undefined ? SongDtoMapper.toSongItem(dto) : undefined;
  }

  /**
   * @returns The item at {@link selectIndex}, or undefined.
   */
  public getCurrentSongItem(): SongItem | undefined {
    if (this.remoteSongItem) {
      return this.remoteSongItem;
    }
    return this.resolveSongAtQueueIndex(this.selectIndex);
  }

  /**
   * @returns The length of playQueueIds.
   */
  public getQueueLength(): number {
    return this.playQueueIds.length;
  }
}
