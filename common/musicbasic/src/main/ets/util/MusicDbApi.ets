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


import { HeroCardApiDto, RecommendCardApiDto, SongApiDto, TabApiDto } from '../api/MusicApiDtos';
import { PlaylistRow } from '../data/PlaylistRow';
import { RecommendFeedKind, RecommendFeedRow } from '../data/RecommendFeedRow';
import { SongRow } from '../data/SongRow';
import { SongItem } from '../model/SongData';
import { MusicMemoryStore } from '../db/MusicMemoryStore';
import { PlaylistDb } from '../db/PlaylistDb';

/** Cover resources for the 12-slot private-song carousel UI. */
const PRIVATE_DISPLAY_LABELS: Resource[] = [
  $r('app.media.ic_tv_list1'),
  $r('app.media.ic_tv_list2'),
  $r('app.media.ic_tv_list3'),
  $r('app.media.ic_tv_list4'),
  $r('app.media.ic_tv_list5'),
  $r('app.media.ic_tv_list6'),
  $r('app.media.ic_tv_list7'),
  $r('app.media.ic_tv_list8'),
  $r('app.media.ic_tv_list1'),
  $r('app.media.ic_tv_list2'),
  $r('app.media.ic_tv_list3'),
  $r('app.media.ic_tv_list4')
];

/**
 * Read-only API over {@link MusicMemoryStore}: songs, playlists, home feed, and DTO mapping.
 */
export class MusicDbApi {
  /** Singleton instance holder. */
  private static instance: MusicDbApi | undefined = undefined;
  /** Backing in-memory store. */
  private readonly store: MusicMemoryStore;

  /** Wires this API to the shared {@link MusicMemoryStore}. */
  private constructor() {
    this.store = MusicMemoryStore.getInstance();
  }

  /**
   * @returns Shared {@link MusicDbApi} instance.
   */
  public static getInstance(): MusicDbApi {
    if (MusicDbApi.instance === undefined) {
      MusicDbApi.instance = new MusicDbApi();
    }
    return MusicDbApi.instance;
  }

  /**
   * @returns All songs as {@link SongApiDto} rows.
   */
  public getSongList(): SongApiDto[] {
    return this.store.songs.map((songRow) => this.rowToSongApiDto(songRow));
  }

  /**
   * @param id Song primary key.
   * @returns DTO or undefined if not found.
   */
  public getSongById(id: number): SongApiDto | undefined {
    const row = this.store.songs.find((songRow) => songRow.id === id);
    return row !== undefined ? this.rowToSongApiDto(row) : undefined;
  }

  /**
   * Resolves songs for a playlist in stored id order.
   * @param playlistId Playlist id.
   * @returns Song DTOs; empty if playlist is unknown.
   */
  public getPlaylistSongItems(playlistId: number): SongApiDto[] {
    const playlist = this.store.playlists.find((playlistRow) => playlistRow.playlistId === playlistId);
    if (playlist === undefined) {
      return [];
    }
    const out: SongApiDto[] = [];
    for (let index = 0; index < playlist.songIds.length; index++) {
      const row = this.store.songs.find((songRow) => songRow.id === playlist.songIds[index]);
      if (row !== undefined) {
        out.push(this.rowToSongApiDto(row));
      }
    }
    return out;
  }

  /**
   * @returns Hero banner rows sorted by feed sort order.
   */
  public getHeroCards(): HeroCardApiDto[] {
    return this.feedSorted()
      .filter((feedRow) => feedRow.kind === RecommendFeedKind.HERO_BANNER)
      .map((feedRow) => this.rowToHeroCardApiDto(feedRow));
  }

  /**
   * @returns Recommend-card rows sorted by feed sort order.
   */
  public getRecommendPlaylists(): RecommendCardApiDto[] {
    return this.feedSorted()
      .filter((feedRow) => feedRow.kind === RecommendFeedKind.RECOMMEND_CARD)
      .map((feedRow) => this.rowToRecommendCardApiDto(feedRow));
  }

  /**
   * @returns Category tab rows sorted by feed sort order.
   */
  public getCategoryTabs(): TabApiDto[] {
    return this.feedSorted()
      .filter((feedRow) => feedRow.kind === RecommendFeedKind.CATEGORY_TAB)
      .map((feedRow) => this.rowToTabApiDto(feedRow));
  }

  /**
   * First 12 catalog songs with carousel-specific labels and display indices.
   * @returns Song DTOs tailored for the private-song strip UI.
   */
  public getPrivateSongDisplayList(): SongApiDto[] {
    const out: SongApiDto[] = [];
    for (let displayIndex = 0; displayIndex < 12; displayIndex++) {
      const songId = displayIndex + 1;
      const row = this.store.songs.find((songRow) => songRow.id === songId);
      if (row === undefined) {
        continue;
      }
      const dto = this.rowToSongApiDto(row);
      dto.label = PRIVATE_DISPLAY_LABELS[displayIndex];
      dto.index = displayIndex;
      out.push(dto);
    }
    return out;
  }

  /** Copies and sorts recommend feed rows by {@link RecommendFeedRow.sortOrder}. */
  private feedSorted(): RecommendFeedRow[] {
    const rows = [...this.store.recommendFeed];
    rows.sort((left, right) => left.sortOrder - right.sortOrder);
    return rows;
  }

  /** Resolves an id list to SongApiDto list in the given order, skipping missing ids. */
  private idsToSongDtos(ids: number[]): SongApiDto[] {
    const out: SongApiDto[] = [];
    for (let i = 0; i < ids.length; i++) {
      const dto = this.getSongById(ids[i]);
      if (dto !== undefined) {
        out.push(dto);
      }
    }
    return out;
  }

  // ==================== 歌单 ====================

  /**
   * Loads persisted data from {@link PlaylistDb} into the in-memory store:
   * own playlists (type 0), collected playlists (type 1), recent play, and favorites.
   * Call once after {@link PlaylistDb.init}.
   */
  public async initPlaylists(): Promise<void> {
    const db = PlaylistDb.getInstance();
    const results = await Promise.all([
      db.getAllOwn(),
      db.getAllCollected(),
      db.getRecent(),
      db.getFavorites()
    ]);
    const persistedOwn = results[0];
    const persistedCollected = results[1];
    const recent = results[2];
    const favorites = results[3];
    this.store.playlists = persistedCollected.concat(persistedOwn);
    this.store.collectedPlaylistIds = persistedCollected.map((p) => p.playlistId);
    this.store.recentPlayItems = recent;
    this.store.favoriteItems = favorites;
  }

  /** @returns Own playlists (playlistType === 0). */
  public getOwnPlaylists(): PlaylistRow[] {
    return this.store.playlists.filter((p) => p.playlistType === 0);
  }

  /** @returns Collected playlists (playlistType === 1). */
  public getCollectedPlaylists(): PlaylistRow[] {
    return this.store.playlists.filter((p) => p.playlistType === 1);
  }

  /**
   * Creates a new own playlist with the given title, persists it, and returns the new row.
   * @param title User-entered playlist name.
   */
  public createOwnPlaylist(title: string): PlaylistRow {
    let maxId = 0;
    for (let i = 0; i < this.store.playlists.length; i++) {
      if (this.store.playlists[i].playlistId > maxId) {
        maxId = this.store.playlists[i].playlistId;
      }
    }
    const row = new PlaylistRow();
    row.playlistId = maxId + 1;
    row.title = title;
    row.songIds = [];
    row.playlistType = 0;
    this.store.playlists.push(row);
    this.persistOwn();
    return row;
  }

  /** Persists current own playlists (type === 0) to {@link PlaylistDb}. */
  private persistOwn(): void {
    const own = this.store.playlists.filter((p) => p.playlistType === 0);
    PlaylistDb.getInstance().saveAllOwn(own);
  }

  /** Persists current collected playlists (type === 1) to {@link PlaylistDb}. */
  private persistCollected(): void {
    const collected = this.store.playlists.filter((p) => p.playlistType === 1);
    PlaylistDb.getInstance().saveAllCollected(collected);
  }

  /** Persists current recent-play list to {@link PlaylistDb}. */
  private persistRecent(): void {
    PlaylistDb.getInstance().saveRecent(this.store.recentPlayItems);
  }

  /** Persists current favorite-song list to {@link PlaylistDb}. */
  private persistFavorites(): void {
    PlaylistDb.getInstance().saveFavorites(this.store.favoriteItems);
  }

  /** Deletes an own playlist by id and returns true if found and deleted. */
  public deleteOwnPlaylist(id: number): boolean {
    const ok = this.store.deleteOwnPlaylist(id);
    if (ok) {
      this.persistOwn();
    }
    return ok;
  }

  /** Removes a playlist from collected list and returns true if found. */
  public removeCollectedPlaylist(id: number): boolean {
    const ok = this.store.removeCollectedPlaylist(id);
    if (ok) {
      this.persistCollected();
    }
    return ok;
  }

  /** 收藏远程歌单。返回创建的 playlistId。 */
  public saveRemotePlaylist(name: string, source: string, sourceListId: string, coverUrl: string, author: string): number {
    const id = this.store.saveRemotePlaylist(name, source, sourceListId, coverUrl, author);
    this.persistCollected();
    return id;
  }

  /** 判断指定 sourceListId 的远程歌单是否已收藏。 */
  public isRemotePlaylistSaved(sourceListId: string): boolean {
    return this.store.isRemotePlaylistSaved(sourceListId);
  }

  // ==================== MusicHall 歌单展示 ====================
  // 已移除：MusicHall 现完全依赖真实 API（ApiSource.getPlaylists / getPlaylistTags），
  // 不再提供本地假种子数据 getter。



  // ==================== 最近播放 ====================

  /** Records a song as recently played (dedup + prepend) and persists. */
  public addRecentPlay(songItem: SongItem): void {
    this.store.addRecentPlay(songItem);
    this.persistRecent();
  }

  /** @returns Recently played songs (full SongItem) in order (most recent first). */
  public getRecentPlaySongs(): SongItem[] {
    return this.store.recentPlayItems;
  }

  /** @returns Count of recently played songs. */
  public getRecentPlayCount(): number {
    return this.store.recentPlayItems.length;
  }

  // ==================== 收藏 ====================

  /** Toggles favorite and persists. Returns true if now favorited, false if removed. */
  public toggleFavorite(songItem: SongItem): boolean {
    const nowFav = this.store.toggleFavorite(songItem);
    this.persistFavorites();
    return nowFav;
  }

  /** @returns Whether the song id is currently favorited. */
  public isFavorite(songId: number): boolean {
    return this.store.isFavorite(songId);
  }

  /** @returns Favorited songs (full SongItem) in insertion order. */
  public getFavoriteSongs(): SongItem[] {
    return this.store.favoriteItems;
  }

  /** @returns Count of favorited songs. */
  public getFavoriteCount(): number {
    return this.store.favoriteItems.length;
  }

  /** Maps a {@link SongRow} to {@link SongApiDto}. */
  private rowToSongApiDto(row: SongRow): SongApiDto {
    const dto = new SongApiDto();
    dto.id = row.id;
    dto.title = row.title;
    dto.singer = row.singer;
    dto.mark = row.mark;
    dto.label = row.label;
    dto.src = row.src;
    dto.index = row.index;
    dto.lyric = row.lyric;
    return dto;
  }

  /** Maps a hero {@link RecommendFeedRow} to {@link HeroCardApiDto}. */
  private rowToHeroCardApiDto(feedRow: RecommendFeedRow): HeroCardApiDto {
    const dto = new HeroCardApiDto();
    if (feedRow.heroBadge !== undefined) {
      dto.badge = feedRow.heroBadge;
    }
    if (feedRow.heroTitle !== undefined) {
      dto.title = feedRow.heroTitle;
    }
    if (feedRow.heroSubLine !== undefined) {
      dto.subLine = feedRow.heroSubLine;
    }
    if (feedRow.heroCoverImage !== undefined) {
      dto.coverImage = feedRow.heroCoverImage;
    }
    dto.gradientStart = feedRow.heroGradientStart;
    dto.gradientEnd = feedRow.heroGradientEnd;
    return dto;
  }

  /** Maps a recommend-card feed row to {@link RecommendCardApiDto}. */
  private rowToRecommendCardApiDto(feedRow: RecommendFeedRow): RecommendCardApiDto {
    const dto = new RecommendCardApiDto();
    if (feedRow.cardTitle !== undefined) {
      dto.title = feedRow.cardTitle;
    }
    if (feedRow.cardPlayCountLabel !== undefined) {
      dto.playCountLabel = feedRow.cardPlayCountLabel;
    }
    dto.paletteIndex = feedRow.cardPaletteIndex;
    if (feedRow.cardBackgroundImage !== undefined) {
      dto.backgroundImage = feedRow.cardBackgroundImage;
    }
    return dto;
  }

  /** Maps a category-tab feed row to {@link TabApiDto} with defaults for missing fields. */
  private rowToTabApiDto(feedRow: RecommendFeedRow): TabApiDto {
    const dto = new TabApiDto();
    dto.title = feedRow.tabTitle ?? $r('app.string.page_show');
    dto.iconSelected = feedRow.tabIconSelected ?? $r('app.media.ic_home_chip_featured_sel');
    dto.iconUnselected = feedRow.tabIconUnselected ?? $r('app.media.ic_home_chip_featured_unsel');
    return dto;
  }
}
