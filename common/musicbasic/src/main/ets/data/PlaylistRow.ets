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
 * Playlist header and ordered member song ids for the in-memory store.
 */
export class PlaylistRow {
  /** Playlist primary key. */
  public playlistId: number = 0;
  /** Playlist title (resource for seeded, string for user-created). */
  public title: string | Resource = $r('app.string.page_show');
  /** Ordered song ids belonging to this playlist. */
  public songIds: number[] = [];
  /** 0 = 自建歌单, 1 = 收藏歌单（远程歌单） */
  public playlistType: number = 0;
  // === 远程歌单扩展字段（playlistType === 1 时有效） ===
  /** 远程平台标识：kg / tx / wy / kw / mg */
  public source: string = '';
  /** 远程歌单原始 ID（平台原始 id 字符串） */
  public sourceListId: string = '';
  /** 封面 URL（用于「我的歌单」展示） */
  public coverUrl: string = '';
  /** 歌单作者/创建者 */
  public author: string = '';
}
