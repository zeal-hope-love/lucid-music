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
 * Breakpoint / grid layout numbers; used with BreakpointType, Grid, etc.
 */
export class BreakpointConstants {
  /** Column count for the SM width breakpoint. */
  public static readonly COLUMN_SM: number = 4;
  /** Column count for the MD width breakpoint. */
  public static readonly COLUMN_MD: number = 8;
  /** Column count for the LG width breakpoint. */
  public static readonly COLUMN_LG: number = 12;
  /** Column count for the lyric area on large breakpoints. */
  public static readonly COLUMN_LYRIC_LG: number = 7;

  /** Horizontal gutter for the main music area (vp or same unit as layout). */
  public static readonly GUTTER_MUSIC_X: number = 24;

  /** Default span for SM. */
  public static readonly SPAN_SM: number = 4;
  /** Default span for MD. */
  public static readonly SPAN_MD: number = 6;
  /** Span for the lyric area on large breakpoints. */
  public static readonly SPAN_LYRIC_LG: number = 5;

  /** Grid offset for the MD breakpoint. */
  public static readonly OFFSET_MD: number = 1;
}

/**
 * Common full-size width/height strings (e.g. width/height '100%' in ArkUI).
 */
export class StyleConstants {
  /** Full width of the parent. */
  public static readonly FULL_WIDTH: string = '100%';
  /** Full height of the parent. */
  public static readonly FULL_HEIGHT: string = '100%';
  /** Circular clip / capsule radius (e.g. wearable list icons). */
  public static readonly CIRCLE_BORDER_RADIUS: string = '50%';
}

/**
 * Grid item span in a 12-column system.
 */
export class GridConstants {
  /** Spans 4 columns. */
  public static readonly SPAN_FOUR: number = 4;
  /** Spans 6 columns. */
  public static readonly SPAN_SIX: number = 6;
  /** Spans 8 columns. */
  public static readonly SPAN_EIGHT: number = 8;
  /** Spans 12 columns. */
  public static readonly SPAN_TWELVE: number = 12;
}

/**
 * NavPath / navigation stack page names; must match registered route names.
 */
export class RouterUrlConstants {
  /** Home tab */
  public static readonly HOME: string = 'Home';
  /** MusicHall tab */
  public static readonly MUSIC_HALL: string = 'MusicHall';
  /** Mine tab */
  public static readonly MINE: string = 'Mine';
  /** Search page */
  public static readonly SEARCH: string = 'Search';
  /** Playback page (future) */
  public static readonly PLAYBACK: string = 'Playback';
  /** Playlist detail page. */
  public static readonly PLAYLIST_DETAIL: string = 'PlaylistDetailPage';
  /** Split-column playlist (wide) page. */
  public static readonly SPLIT_COLUMN_PLAYLIST: string = 'SplitColumnPlaylistPage';
}

/**
 * Durations (ms) for track transitions, etc. (exact unit depends on the API used).
 */
export class SongConstants {
  /** Cross-fade or transition between tracks; not the same as full-screen player open. */
  public static readonly TRANSITION_DURATION: number = 500;
}

/**
 * App shell: full-screen player open animation, paired with UIContext.animateTo in entry Index.
 */
export class PlaybackShellConstants {
  /** Duration (ms) for animating from mini player to full-screen player. */
  public static readonly OPEN_PLAYER_UI_ANIMATION_MS: number = 380;
}

/**
 * Watch product: page names on the nav stack; must match NavDestination / stack config.
 */
export class WatchNavRouteConstants {
  /** Hot playlists / playlist swiper entry. */
  public static readonly PLAY_LIST: string = 'playList';
  /** Favorites / song list. */
  public static readonly SONG_LIST: string = 'songList';
  /** Now playing screen. */
  public static readonly SONG_PAGE: string = 'songPage';
  /** Settings placeholder; ignore tap until implemented. */
  public static readonly SETTING: string = 'setting';
}

/**
 * HiLog labels for unified playback-intent handling; search or forward to analytics from one place.
 */
export class PlaybackIntentLogEvent {
  /** Shell starts handling a PlaybackIntentState change. */
  public static readonly SHELL_DISPATCH: string = 'shell_playback_intent';
  /** Request to present full-screen player UI. */
  public static readonly OPEN_PLAYER_UI: string = 'open_player_ui';
  /** Resolve index in queue and start load/playback. */
  public static readonly LOAD_QUEUE: string = 'load_queue';
  /** Requested song id is not in the local library. */
  public static readonly SONG_NOT_IN_DB: string = 'pending_song_not_in_db';
}

/**
 * Minimum system API level gates (compare with SdkApiUtil, distributionOSApiVersion, etc.).
 */
export class SdkConstants {
  /**
   * API 23 = HarmonyOS 6.1.0(23). Used for HDS tab bar floating, etc. Reuse for any feature
   * that needs the same floor; do not duplicate the magic number 23.
   */
  public static readonly HDS_TABS_BAR_FLOATING_MIN_SDK_API: number = 23;
}

/**
 * {@link AppStorageV2.connect} link keys for shared observable state (prefix {@code musichome_}).
 */
export class AppStorageKeys {
  /** {@link MusicAppState} */
  public static readonly MUSIC_APP_STATE: string = 'musichome_MusicAppState';
  /** {@link PlaybackIntentState} */
  public static readonly PLAYBACK_INTENT_STATE: string = 'musichome_PlaybackIntentState';
  /** Watch playlist navigation context ({@link WatchNavContext} in playlist feature). */
  public static readonly WATCH_NAV_CONTEXT: string = 'musichome_WatchNavContextStore';
  /** {@link WindowInfo} */
  public static readonly WINDOW_INFO: string = 'musichome_WindowInfo';
  /** {@link AppRuntimeStorage} */
  public static readonly APP_RUNTIME: string = 'musichome_AppRuntimeStorage';
  /** Active audio source ID (user-imported script that is currently enabled). */
  public static readonly ACTIVE_SOURCE_ID: string = 'musichome_ActiveSourceId';
  /** Current selected tab index (0=Home, 1=MusicHall, 2=Mine). Shared across pages via AppStorage. */
  public static readonly CURRENT_TAB: string = 'musichome_CurrentTab';
  /** {@link CurrentTabState} – V2 observable tab index. */
  public static readonly CURRENT_TAB_STATE: string = 'musichome_CurrentTabState';
}