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

import { SongItem } from './SongData';

/**
 * Cross-feature playback request (AppStorageV2: PlaybackIntentState).
 * View models only bump this; the shell listens and writes {@link MusicAppState} and media.
 */
@ObservedV2
export class PlaybackIntentState {
  /** Incremented on each intent so the shell reacts even when the song id is unchanged. */
  @Trace public requestVersion: number = 0;
  /** Index into the current {@link MusicAppState.playQueue} to switch to; -1 when unset. */
  @Trace public pendingPlayIndex: number = -1;
  /** When true, the shell should present full-screen player UI. */
  @Trace public openPlayerUi: boolean = false;
  /** Remote audio URL (non-empty signals remote playback via audio source). */
  @Trace public remoteUrl: string = '';
  /** Remote song display name. */
  @Trace public remoteSongName: string = '';
  /** Remote song display singer. */
  @Trace public remoteSongSinger: string = '';
  /** Remote song cover image URL (optional). */
  @Trace public remoteSongCover: string = '';
  /** Remote song lyric text (LRC format). */
  @Trace public remoteLyricText: string = '';
  /** Remote source platform identifier (e.g. 'wy', 'tx'); needed for disk cache key. */
  @Trace public remotePlatform: string = '';
  /** Remote song ID on the source platform; needed for disk cache key. */
  @Trace public remoteSongId: string = '';
  /** Pending new queue (full song objects; set when switching queues). */
  @Trace public pendingQueue: SongItem[] = [];
  /** Pending select index in the new queue. */
  @Trace public pendingSelectIndex: number = 0;
  /** Pending playlist title for the new queue (shown in the playback sheet). */
  @Trace public pendingPlaylistTitle: string = '';

  /** Reset remote-playback fields after consumption. */
  public resetRemote(): void {
    this.remoteUrl = '';
    this.remoteSongName = '';
    this.remoteSongSinger = '';
    this.remoteSongCover = '';
    this.remoteLyricText = '';
    this.remotePlatform = '';
    this.remoteSongId = '';
  }
}
