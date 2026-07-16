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
 * Global observable tab index state (AppStorageV2 key: CURRENT_TAB_STATE).
 * Index.ets connects via AppStorageV2.connect; Tab pages write via AppStorageV2.connect.
 */
@ObservedV2
export class CurrentTabState {
  /** Current selected tab index: 0=Home, 1=MusicHall, 2=Mine */
  @Trace public index: number = 0
  /** Incremented on navigation pop to trigger MinePage/MusicListPage refresh */
  @Trace public refreshCounter: number = 0
  /** Incremented on favorite toggle to trigger MusicListPage real-time refresh */
  @Trace public favoriteVersion: number = 0
}
