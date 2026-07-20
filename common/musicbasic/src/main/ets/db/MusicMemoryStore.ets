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


import { PlaylistRow } from '../data/PlaylistRow';
import { RecommendFeedKind, RecommendFeedRow } from '../data/RecommendFeedRow';
import { SongRow } from '../data/SongRow';
import { SongItem } from '../model/SongData';

/**
 * In-memory singleton backing demo catalog: songs, one playlist, and home recommend feed rows.
 */
export class MusicMemoryStore {
  /** Process-wide singleton instance. */
  private static instance: MusicMemoryStore | undefined = undefined;

  /** All seeded song rows. */
  public songs: SongRow[] = [];
  /** Playlist headers and member id lists. */
  public playlists: PlaylistRow[] = [];
  /** Home feed rows (hero, cards, tabs), unsorted until read via API. */
  public recommendFeed: RecommendFeedRow[] = [];
  /** Recently played songs (full SongItem), most recent first, no duplicates by id. */
  public recentPlayItems: SongItem[] = [];
  /** Favorited songs (full SongItem), insertion order. */
  public favoriteItems: SongItem[] = [];
  /** Collected playlist ids (歌单收藏, for playlistType === 1), insertion order. */
  public collectedPlaylistIds: number[] = [];

  /**
   * @returns Shared {@link MusicMemoryStore} instance.
   */
  public static getInstance(): MusicMemoryStore {
    if (MusicMemoryStore.instance === undefined) {
      MusicMemoryStore.instance = new MusicMemoryStore();
    }
    return MusicMemoryStore.instance;
  }

  /** Builds initial tables via {@link seedTables}. */
  private constructor() {
    this.seedTables();
  }

  /** Fills songs, playlists, and recommend feed from built-in demo data. */
  private seedTables(): void {
    this.songs = this.buildSongs();
    // 歌单不再内置示例：自建歌单由 PlaylistDb 持久化加载，收藏歌单为运行时收藏。
    this.playlists = [];
    this.recommendFeed = this.buildRecommendFeed();
  }

  /** Rotating cover art resources for demo tracks (excluding id 1 special case). */
  private static readonly coverLabelCycle: Resource[] = [
    $r('app.media.ic_avatar2'),
    $r('app.media.ic_avatar4'),
    $r('app.media.ic_avatar5'),
    $r('app.media.ic_avatar6'),
    $r('app.media.ic_avatar8'),
    $r('app.media.ic_avatar9'),
    $r('app.media.ic_avatar10'),
    $r('app.media.ic_avatar11'),
    $r('app.media.ic_avatar12'),
    $r('app.media.ic_avatar1')
  ];

  /**
   * Picks a cover resource for a song id; id 1 uses a fixed VIP-style art.
   * @param id Song primary key.
   * @returns Cover {@link Resource} for UI.
   */
  private coverLabelForSongId(id: number): Resource {
    if (id === 1) {
      return $r('app.media.ic_dream');
    }
    return MusicMemoryStore.coverLabelCycle[(id - 2) % 10];
  }

  /** Demo private-track singer labels cycle 1..12. */
  private static readonly privateSongSingerResources: Resource[] = [
    $r('app.string.private_song_singer1'),
    $r('app.string.private_song_singer2'),
    $r('app.string.private_song_singer3'),
    $r('app.string.private_song_singer4'),
    $r('app.string.private_song_singer5'),
    $r('app.string.private_song_singer6'),
    $r('app.string.private_song_singer7'),
    $r('app.string.private_song_singer8'),
    $r('app.string.private_song_singer9'),
    $r('app.string.private_song_singer10'),
    $r('app.string.private_song_singer11'),
    $r('app.string.private_song_singer12')
  ];

  /** Asset filename cycle for ids 2..N (matches former sequential seed). */
  private static readonly demoPrivateSrcCycle: string[] = [
    'world.mp3',
    'power.mp3',
    'power.mp3',
    'world.mp3',
    'boisterous.mp3'
  ];

  /** Constructs the demo song catalog: 2 songs for test switching. */
  private buildSongs(): SongRow[] {
    return [
      this.buildSongRow(1, 'Dream It Possible', 'Delacey', $r('app.media.ic_vip'), this.coverLabelForSongId(1),
        'Dream_It_Possible-Delacey.mp3', 0, 'lrcfiles/DreamItPossible.lrc'),
      this.buildSongRow(2, 'Journey of Light', 'Dane Amar', $r('app.media.ic_sq'), this.coverLabelForSongId(2),
        'world.mp3', 1, '')
    ];
  }

  /**
   * Builds a {@link SongRow} with the given fields.
   * @param id Song id.
   * @param title Title string or resource.
   * @param singer Artist string or resource.
   * @param mark Badge resource.
   * @param label Cover resource.
   * @param src Asset file name or path.
   * @param index List index.
   * @param lyric Lyric file path.
   */
  private buildSongRow(
    id: number,
    title: string | Resource,
    singer: string | Resource,
    mark: Resource,
    label: Resource,
    src: string,
    index: number,
    lyric: string
  ): SongRow {
    const row = new SongRow();
    row.id = id;
    row.title = title;
    row.singer = singer;
    row.mark = mark;
    row.label = label;
    row.src = src;
    row.index = index;
    row.lyric = lyric;
    return row;
  }

  // ==================== 最近播放 ====================

  /** Stable dedup identity for recent-play, derived from the SongItem's own content (path-independent). */
  private recentKey(s: SongItem): string {
    const src: string = s.src
    if (src && src.length > 0) {
      // 去 query/fragment 中的易变参数（时间戳/签名），保留稳定主体
      const base: string = src.split('?')[0].split('#')[0]
      return `src#${base}`
    }
    const title: string = typeof s.title === 'string' ? s.title : ''
    const singer: string = typeof s.singer === 'string' ? s.singer : ''
    return `meta#${title}#${singer}`
  }

  /** Records a play: dedups by stable identity (src, then title+singer), then prepends to front. */
  public addRecentPlay(item: SongItem): void {
    const key = this.recentKey(item);
    const idx = this.recentPlayItems.findIndex((s) => this.recentKey(s) === key);
    if (idx !== -1) {
      this.recentPlayItems.splice(idx, 1);
    }
    this.recentPlayItems.unshift(item);
    // 限制最近播放规模，避免持久化文件无限膨胀
    const RECENT_CAP = 100;
    if (this.recentPlayItems.length > RECENT_CAP) {
      this.recentPlayItems.length = RECENT_CAP;
    }
  }

  // ==================== 收藏 ====================

  /** Toggles favorite status. Returns the new state (true = favorited). */
  public toggleFavorite(item: SongItem): boolean {
    const idx = this.favoriteItems.findIndex((s) => s.id === item.id);
    if (idx !== -1) {
      this.favoriteItems.splice(idx, 1);
      return false;
    }
    this.favoriteItems.push(item);
    return true;
  }

  /** Checks whether a song id is favorited. */
  public isFavorite(id: number): boolean {
    return this.favoriteItems.findIndex((s) => s.id === id) !== -1;
  }

  // ==================== 歌单收藏 ====================

  /** Toggles playlist collect status. Returns the new state (true = collected). */
  public toggleCollectPlaylist(id: number): boolean {
    const idx = this.collectedPlaylistIds.indexOf(id);
    if (idx !== -1) {
      this.collectedPlaylistIds.splice(idx, 1);
      return false;
    }
    this.collectedPlaylistIds.push(id);
    return true;
  }

  /** Checks whether a playlist id is collected. */
  public isCollectedPlaylist(id: number): boolean {
    return this.collectedPlaylistIds.indexOf(id) !== -1;
  }

  /** Deletes an own playlist by id and returns true if found and deleted. */
  public deleteOwnPlaylist(id: number): boolean {
    const idx = this.playlists.findIndex((p) => p.playlistId === id && p.playlistType === 0);
    if (idx !== -1) {
      this.playlists.splice(idx, 1);
      return true;
    }
    return false;
  }

  /** 收藏远程歌单：创建 PlaylistRow（playlistType=1, songIds 留空）并加入 collectedPlaylistIds。返回创建的 playlistId。 */
  public saveRemotePlaylist(name: string, source: string, sourceListId: string, coverUrl: string, author: string): number {
    const newId = this.playlists.length > 0
      ? Math.max(...this.playlists.map(p => p.playlistId)) + 1
      : 1
    const row = new PlaylistRow()
    row.playlistId = newId
    row.title = name
    row.songIds = []
    row.playlistType = 1
    row.source = source
    row.sourceListId = sourceListId
    row.coverUrl = coverUrl
    row.author = author
    this.playlists.push(row)
    this.collectedPlaylistIds.push(newId)
    return newId
  }

  /** 判断远程歌单是否已收藏（按 sourceListId 去重） */
  public isRemotePlaylistSaved(sourceListId: string): boolean {
    return this.playlists.some(p => p.playlistType === 1 && p.sourceListId === sourceListId)
  }

  /** Removes a collected playlist from both playlists array and collectedPlaylistIds. */
  public removeCollectedPlaylist(id: number): boolean {
    // 从 collectedPlaylistIds 中移除
    const collectedIdx = this.collectedPlaylistIds.indexOf(id);
    if (collectedIdx !== -1) {
      this.collectedPlaylistIds.splice(collectedIdx, 1);
    }
    
    // 从 playlists 数组中移除该歌单
    const playlistIdx = this.playlists.findIndex((p) => p.playlistId === id && p.playlistType === 1);
    if (playlistIdx !== -1) {
      this.playlists.splice(playlistIdx, 1);
      return true;
    }
    return false;
  }

  // ==================== 种子数据 ====================

  /** Builds hero banners, recommend cards, and category tab rows for the home feed. */
  private buildRecommendFeed(): RecommendFeedRow[] {
    const rows: RecommendFeedRow[] = [];
    let nextFeedId = 0;
    let nextSortOrder = 0;

    const appendHeroRow = (
      badge: Resource,
      title: Resource,
      subLine: Resource,
      coverImage: Resource,
      gradientStart: string,
      gradientEnd: string
    ): void => {
      const feedRow = new RecommendFeedRow();
      feedRow.feedId = nextFeedId++;
      feedRow.sortOrder = nextSortOrder++;
      feedRow.kind = RecommendFeedKind.HERO_BANNER;
      feedRow.heroBadge = badge;
      feedRow.heroTitle = title;
      feedRow.heroSubLine = subLine;
      feedRow.heroCoverImage = coverImage;
      feedRow.heroGradientStart = gradientStart;
      feedRow.heroGradientEnd = gradientEnd;
      rows.push(feedRow);
    };

    const heroSub: Resource = $r('app.string.hero_banner_subline_brand');

    appendHeroRow($r('app.string.hero_1_badge'), $r('app.string.hero_1_title'), heroSub,
      $r('app.media.ic_recommend1'), '#152238', '#2E4A78');
    appendHeroRow($r('app.string.hero_2_badge'), $r('app.string.hero_2_title'), heroSub,
      $r('app.media.ic_recommend2'), '#2B3F5C', '#5A7A9E');
    appendHeroRow($r('app.string.hero_3_badge'), $r('app.string.hero_3_title'), heroSub,
      $r('app.media.ic_recommend3'), '#3D2F55', '#6B5A8C');
    appendHeroRow($r('app.string.hero_4_badge'), $r('app.string.hero_4_title'), heroSub,
      $r('app.media.ic_recommend4'), '#5C2D2D', '#9A5C4A');
    appendHeroRow($r('app.string.hero_5_badge'), $r('app.string.hero_5_title'), heroSub,
      $r('app.media.ic_recommend5'), '#1A2F4A', '#3D5C82');

    const appendRecommendCardRow = (
      title: Resource,
      playLabel: Resource,
      palette: number,
      backgroundResource: Resource
    ): void => {
      const feedRow = new RecommendFeedRow();
      feedRow.feedId = nextFeedId++;
      feedRow.sortOrder = nextSortOrder++;
      feedRow.kind = RecommendFeedKind.RECOMMEND_CARD;
      feedRow.cardTitle = title;
      feedRow.cardPlayCountLabel = playLabel;
      feedRow.cardPaletteIndex = palette;
      feedRow.cardBackgroundImage = backgroundResource;
      rows.push(feedRow);
    };

    appendRecommendCardRow($r('app.string.rec_1_title'), $r('app.string.rec_1_play'), 0,
      $r('app.media.ic_recommend_you1'));
    appendRecommendCardRow($r('app.string.rec_2_title'), $r('app.string.rec_2_play'), 1,
      $r('app.media.ic_recommend_you2'));
    appendRecommendCardRow($r('app.string.rec_3_title'), $r('app.string.rec_3_play'), 2,
      $r('app.media.ic_recommend_you3'));
    appendRecommendCardRow($r('app.string.rec_4_title'), $r('app.string.rec_4_play'), 3,
      $r('app.media.ic_recommend_you4'));
    appendRecommendCardRow($r('app.string.rec_5_title'), $r('app.string.rec_5_play'), 4,
      $r('app.media.ic_recommend_you5'));
    appendRecommendCardRow($r('app.string.rec_6_title'), $r('app.string.rec_6_play'), 0,
      $r('app.media.ic_recommend_you6'));

    const appendCategoryTabRow = (
      title: Resource,
      iconSelected: Resource,
      iconUnselected: Resource
    ): void => {
      const feedRow = new RecommendFeedRow();
      feedRow.feedId = nextFeedId++;
      feedRow.sortOrder = nextSortOrder++;
      feedRow.kind = RecommendFeedKind.CATEGORY_TAB;
      feedRow.tabTitle = title;
      feedRow.tabIconSelected = iconSelected;
      feedRow.tabIconUnselected = iconUnselected;
      rows.push(feedRow);
    };

    appendCategoryTabRow($r('app.string.home_tab_featured'), $r('app.media.ic_home_chip_featured_sel'),
      $r('app.media.ic_home_chip_featured_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_artist'), $r('app.media.ic_home_chip_artist_sel'),
      $r('app.media.ic_home_chip_artist_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_ai_music'), $r('app.media.ic_home_chip_ai_sel'),
      $r('app.media.ic_home_chip_ai_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_charts'), $r('app.media.ic_home_chip_charts_sel'),
      $r('app.media.ic_home_chip_charts_unsel'));
    appendCategoryTabRow($r('app.string.home_tab_categories'), $r('app.media.ic_home_chip_categories_sel'),
      $r('app.media.ic_home_chip_categories_unsel'));

    return rows;
  }

  // ==================== MusicHall 种子数据已移除 ====================
  // MusicHall 现完全依赖真实 API（ApiSource.getPlaylists / getPlaylistTags），
  // 不再内置假种子数据；拉取失败时在页面提示。
}
