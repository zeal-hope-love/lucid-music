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


import { MusichallPlaylistItem, TagFilterGroup, TagFilterItem } from '../data/MusichallPlaylistItem';
import { PlaylistRow } from '../data/PlaylistRow';
import { RecommendFeedKind, RecommendFeedRow } from '../data/RecommendFeedRow';
import { SongRow } from '../data/SongRow';

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
  /** Recently played song ids, most recent first, no duplicates. */
  public recentPlayIds: number[] = [];
  /** Favorited song ids, insertion order. */
  public favoriteSongIds: number[] = [];
  /** Collected playlist ids (歌单收藏, for playlistType === 1), insertion order. */
  public collectedPlaylistIds: number[] = [];
  /** MusicHall 歌单展示列表（封面、播放量等 UI 数据）。 */
  public musichallPlaylists: MusichallPlaylistItem[] = [];
  /** MusicHall 分类标签树。 */
  public musichallTagGroups: TagFilterGroup[] = [];

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
    this.playlists = this.buildPlaylists();
    this.recommendFeed = this.buildRecommendFeed();
    this.musichallPlaylists = this.buildMusichallPlaylists();
    this.musichallTagGroups = this.buildMusichallTagGroups();
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

  /** Records a play: removes existing entry then prepends to front. */
  public addRecentPlay(id: number): void {
    const idx = this.recentPlayIds.indexOf(id);
    if (idx !== -1) {
      this.recentPlayIds.splice(idx, 1);
    }
    this.recentPlayIds.unshift(id);
  }

  // ==================== 收藏 ====================

  /** Toggles favorite status. Returns the new state (true = favorited). */
  public toggleFavorite(id: number): boolean {
    const idx = this.favoriteSongIds.indexOf(id);
    if (idx !== -1) {
      this.favoriteSongIds.splice(idx, 1);
      return false;
    }
    this.favoriteSongIds.push(id);
    return true;
  }

  /** Checks whether a song id is favorited. */
  public isFavorite(id: number): boolean {
    return this.favoriteSongIds.indexOf(id) !== -1;
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

  // ==================== 种子数据 ====================

  /** Seeds own + collected demo playlists. */
  private buildPlaylists(): PlaylistRow[] {
    const list: PlaylistRow[] = [];

    const makeOwn = (id: number, title: Resource, songIds: number[]): void => {
      const pl = new PlaylistRow();
      pl.playlistId = id;
      pl.title = title;
      pl.songIds = songIds;
      pl.playlistType = 0;
      list.push(pl);
    };

    const makeCollected = (id: number, title: Resource, songIds: number[]): void => {
      const pl = new PlaylistRow();
      pl.playlistId = id;
      pl.title = title;
      pl.songIds = songIds;
      pl.playlistType = 1;
      list.push(pl);
    };

    // 自建歌单
    makeOwn(1, $r('app.string.playlist_detail_title'), [1, 2]);
    makeOwn(2, $r('app.string.playlist_title_my_fav'), [1]);
    makeOwn(3, $r('app.string.playlist_title_chill'), [2]);

    // 收藏歌单
    makeCollected(4, $r('app.string.playlist_title_trending'), [1, 2]);
    makeCollected(5, $r('app.string.playlist_title_discover'), [2]);

    // 收藏歌单 ID 加入收藏列表
    this.collectedPlaylistIds = [4, 5];

    return list;
  }

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

  // ==================== MusicHall 种子数据 ====================

  /** Cover art pool for musichall playlist cards. */
  private static readonly musichallCoverPool: Resource[] = [
    $r('app.media.ic_avatar1'),
    $r('app.media.ic_avatar2'),
    $r('app.media.ic_avatar4'),
    $r('app.media.ic_avatar5'),
    $r('app.media.ic_avatar6'),
    $r('app.media.ic_avatar8'),
    $r('app.media.ic_avatar9'),
    $r('app.media.ic_avatar10'),
    $r('app.media.ic_avatar11'),
    $r('app.media.ic_avatar12')
  ];

  /** Seeds 8 demo playlist display items for MusicHallPage. */
  private buildMusichallPlaylists(): MusichallPlaylistItem[] {
    const make = (id: number, title: string, coverIdx: number, playCount: string, ...tagIds: string[]): MusichallPlaylistItem => {
      const item = new MusichallPlaylistItem();
      item.playlistId = id;
      item.title = title;
      item.coverImage = MusicMemoryStore.musichallCoverPool[coverIdx % 10];
      item.playCount = playCount;
      item.tags = tagIds;
      return item;
    };

    return [
      make(1, '华语经典怀旧精选', 0, '128.5万', 'hot', 'style_chinese'),
      make(2, '欧美热门单曲榜', 1, '96.3万', 'hot', 'style_western'),
      make(3, '轻音乐·午后咖啡馆', 2, '53.8万', 'style_light', 'mood_relax'),
      make(4, '电子音乐·夜店狂潮', 3, '87.2万', 'style_electronic', 'mood_hot'),
      make(5, '影视原声·经典回响', 4, '62.1万', 'style_soundtrack', 'style_chinese'),
      make(6, 'K-POP 韩流热单', 5, '115.7万', 'hot', 'style_kpop'),
      make(7, '爵士名曲·午夜萨克斯', 6, '28.4万', 'style_jazz', 'mood_relax'),
      make(8, '摇滚力量·经典吉他', 7, '45.9万', 'style_rock', 'mood_hot')
    ];
  }

  /** Seeds category tag tree for MusicHall tag filter sheet. */
  private buildMusichallTagGroups(): TagFilterGroup[] {
    const makeTag = (id: string, name: string): TagFilterItem => {
      const tag = new TagFilterItem();
      tag.id = id;
      tag.name = name;
      return tag;
    };

    const makeGroup = (name: string, tags: TagFilterItem[]): TagFilterGroup => {
      const group = new TagFilterGroup();
      group.groupName = name;
      group.tags = tags;
      return group;
    };

    return [
      makeGroup('热门分类', [
        makeTag('hot', '热门'),
        makeTag('new', '最新'),
        makeTag('official', '官方精选')
      ]),
      makeGroup('风格流派', [
        makeTag('style_chinese', '华语'),
        makeTag('style_western', '欧美'),
        makeTag('style_kpop', 'K-POP'),
        makeTag('style_jazz', '爵士'),
        makeTag('style_rock', '摇滚'),
        makeTag('style_electronic', '电子'),
        makeTag('style_light', '轻音乐'),
        makeTag('style_soundtrack', '影视原声')
      ]),
      makeGroup('心情场景', [
        makeTag('mood_relax', '放松'),
        makeTag('mood_hot', '嗨起来'),
        makeTag('mood_sad', '伤感'),
        makeTag('mood_sweet', '甜蜜'),
        makeTag('mood_focus', '专注')
      ])
    ];
  }
}
