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
