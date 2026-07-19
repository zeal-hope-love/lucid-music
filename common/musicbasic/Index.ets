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

/*
 * Barrel file for musicbasic (common HAR). All public exports are listed here.
 */

import { AppRuntimeStorage, getAppRuntime as getAppRuntimeFromModel } from './src/main/ets/model/AppRuntimeStorage';

// Constants (single Constants.ets file; class names unchanged)
export {
  AppStorageKeys,
  BreakpointConstants,
  GridConstants,
  PlaybackIntentLogEvent,
  PlaybackShellConstants,
  RouterUrlConstants,
  SdkConstants,
  SongConstants,
  StyleConstants,
  WatchNavRouteConstants
} from './src/main/ets/constants/Constants';

export { TabItem } from './src/main/ets/model/TabItem';

// Data and in-memory DB mocks
export { SongRow } from './src/main/ets/data/SongRow';
export { PlaylistRow } from './src/main/ets/data/PlaylistRow';
export { RecommendFeedKind, RecommendFeedRow } from './src/main/ets/data/RecommendFeedRow';
export { MusichallPlaylistItem, TagFilterItem, TagFilterGroup } from './src/main/ets/data/MusichallPlaylistItem';
export { MusicMemoryStore } from './src/main/ets/db/MusicMemoryStore';
export { MusicDbApi } from './src/main/ets/util/MusicDbApi';

// API DTOs for MusicDbApi (separate from row types in data/*)
export {
  SongApiDto,
  HeroCardApiDto,
  RecommendCardApiDto,
  TabApiDto
} from './src/main/ets/api/MusicApiDtos';
export { SongDtoMapper } from './src/main/ets/api/SongDtoMapper';

// Model: bind getAppRuntime via export const so runtimes that skip re-exported functions still resolve.
export { AppRuntimeStorage };
export const getAppRuntime = getAppRuntimeFromModel;
export { MenuData } from './src/main/ets/model/MenuData';
export { SongItem } from './src/main/ets/model/SongData';
export { OptionItem } from './src/main/ets/model/OptionItem';
export { MusicAppState } from './src/main/ets/model/MusicAppState';
export { PlaybackIntentState } from './src/main/ets/model/PlaybackIntentState';
export { CurrentTabState } from './src/main/ets/model/CurrentTabState';
export { BottomBarVisibility } from './src/main/ets/model/BottomBarVisibility';
export { SongDataSource } from './src/main/ets/model/SongDataSource';

// util
export { BreakpointType, isWidthBreakpointLgOrXl } from './src/main/ets/util/BreakpointSystem';
export { Logger } from './src/main/ets/util/Logger';
export { StringResourceUtil } from './src/main/ets/util/StringResourceUtil';
export { ImmersiveType } from './src/main/ets/util/ImmersiveType';
export {
  WindowUtil,
  WindowInfo,
  WINDOW_INFO_STORAGE_KEY,
  getWindowInfoState
} from './src/main/ets/util/WindowUtil';
export { getStatusBarTopVpFromWindowUtil } from './src/main/ets/util/StatusBarInsetUtil';
export { SdkApiUtil } from './src/main/ets/util/SdkApiUtil';
export { SearchPageExtraInfo } from './src/main/ets/util/SearchPageExtraInfo';
export { getResourceString } from './src/main/ets/util/ResourceStringUtil';

export { MusicEmptyComponent } from './src/main/ets/components/MusicEmptyComponent';
export { MusicTextIcon } from './src/main/ets/components/MusicTextIcon';

// New: 公共 UI 组件
export { AreaWithHdsTabBar } from './src/main/ets/components/floating/AreaWithHdsTabBar';
export { LucidTabBar } from './src/main/ets/components/tabbar/LucidTabBar';
export { MiniPlayerBar } from './src/main/ets/components/miniplayer/MiniPlayerBar';
export { SearchInputArea } from './src/main/ets/components/search/SearchInputArea';
export { SongListPage, SongListParam } from './src/main/ets/components/SongListPage';

// New: 平台常量
export { Platform, PlatformLabels, PlatformColors } from './src/main/ets/constants/Platform';

// New: 工具类
export { splitHighlightKeyword, trimAndEllipsis } from './src/main/ets/util/StringUtil';
export { formatDuration } from './src/main/ets/util/TimeUtil';

// New: 音源管理（AudioSource）
export { AudioSourceModel } from './src/main/ets/model/AudioSourceModel';
export type { AudioSourceOrigin } from './src/main/ets/model/AudioSourceModel';
export { AudioSourceDb } from './src/main/ets/service/AudioSourceDb';
export { AudioSourceManager } from './src/main/ets/service/AudioSourceManager';
export type { ActiveScriptResult, ImportResult } from './src/main/ets/service/AudioSourceManager';

// New: JSVM 音源脚本桥（下沉自 player）
export { JsVmBridge } from './src/main/ets/service/JsVmBridge';
export type { ScriptRequestResult } from './src/main/ets/service/JsVmBridge';

// New: musicSdk - 音乐平台 API
export { wy, tx, kg, kw, mg, sources, ApiSource, apis, supportQuality, searchMusic, findMusic, init } from './src/main/ets/util/musicSdk/index';
export { PlayUrlResult } from './src/main/ets/util/musicSdk/index';
export {
  SearchResultItem, SuggestionItem, CommentItem, SuggestionType
} from './src/main/ets/util/musicSdk/index';
export type {
  SearchResult, CommentResult, BoardItem, BoardListResult, MusicPlatform, SourceInfo
} from './src/main/ets/util/musicSdk/index';
