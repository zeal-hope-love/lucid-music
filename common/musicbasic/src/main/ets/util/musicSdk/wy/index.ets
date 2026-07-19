/*
 * wy/index.ets - 网易云音乐平台 API 聚合
 * 对齐 lx-music-mobile wy/index.js：各端点拆分子模块后在此组装为对象。
 */
import { search } from './musicSearch'
import { getPlaylists, getPlaylistTags, getPlaylistSongs } from './songList'
import { getLyrics } from './lyric'
import { hotSearch } from './hotSearch'
import { getPlayUrl, getPic, getMusicDetailPageUrl } from './musicInfo'
import { getComment } from './comment'
import { getBoards, getList, getDetailPageUrl } from './leaderboard'
import { suggest, getTipSearch } from './tipSearch'
import { MusicPlatform } from '../types'

const wy: MusicPlatform = {
  // 搜索
  search,
  // 联想 / 智能提示
  suggest,
  getTipSearch,
  // 热搜
  hotSearch,
  // 歌词
  getLyrics,
  // 播放URL / 封面 / 详情页
  getPlayUrl,
  getPic,
  getMusicDetailPageUrl,
  // 歌单
  getPlaylists,
  getPlaylistTags,
  getPlaylistSongs,
  // 排行榜
  getBoards,
  getLeaderboardList: getList,
  getLeaderboardDetailPageUrl: getDetailPageUrl,
  // 评论
  getComment,
}

export default wy
