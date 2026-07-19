/*
 * kw/index.ets - 酷我音乐平台 API 聚合
 * 对齐 lx-music-mobile kw/index.js：各端点拆分子模块后在此组装为对象。
 */
import { search } from './musicSearch'
import { getPlaylists, getPlaylistTags, getPlaylistSongs } from './songList'
import { getLyrics } from './lyric'
import { hotSearch } from './hotSearch'
import { getPlayUrl, getPic, getMusicDetailPageUrl } from './musicInfo'
import { getComment } from './comment'
import { getBoards, getList, getDetailPageUrl } from './leaderboard'
import { suggest, getTipSearch } from './tipSearch'
import type { MusicPlatform } from '../types'

const kw: MusicPlatform = {
  search,
  suggest,
  getTipSearch,
  hotSearch,
  getLyrics,
  getPlayUrl,
  getPic,
  getMusicDetailPageUrl,
  getPlaylists,
  getPlaylistTags,
  getPlaylistSongs,
  getBoards,
  getLeaderboardList: getList,
  getLeaderboardDetailPageUrl: getDetailPageUrl,
  getComment,
}

export default kw
