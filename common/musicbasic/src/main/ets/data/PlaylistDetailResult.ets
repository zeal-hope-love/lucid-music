/*
 * PlaylistDetailResult - 远程歌单详情结果（歌曲 + 元数据）
 * 对齐 lx-music-mobile getListDetail 返回结构
 */
import { SearchResultItem } from '../util/musicSdk/index'

/** 歌单元数据（名称、封面、作者等） */
export class PlaylistMeta {
  name: string = ''
  img: string = ''
  desc: string = ''
  author: string = ''
  playCount: string = ''
}

/** 歌单详情结果 */
export interface PlaylistDetailResult {
  /** 歌曲列表 */
  list: SearchResultItem[]
  /** 总页数 */
  allPage: number
  /** 每页条数 */
  limit: number
  /** 歌曲总数 */
  total: number
  /** 平台标识（kg/tx/wy/kw/mg） */
  source: string
  /** 歌单元数据 */
  info: PlaylistMeta
}
