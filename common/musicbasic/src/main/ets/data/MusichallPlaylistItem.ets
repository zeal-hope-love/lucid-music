/*
 * Lucid Music - 音乐厅歌单展示数据模型
 * 用于 MusicHallPage 歌单网格卡片展示，独立于底层的 PlaylistRow
 */

/**
 * 歌单卡片展示项。
 * 后续对接在线 API 后，此模型将承载接口返回的封面 URL、播放量等字段。
 */
export class MusichallPlaylistItem {
  /** 歌单 ID，关联 PlaylistRow.playlistId */
  playlistId: number = 0
  /** 歌单名称 */
  title: string | Resource = ''
  /** 封面图资源 */
  coverImage: Resource = $r('app.media.ic_avatar1')
  /** 播放量文本（如 "12.5万"），封面左下角叠加显示 */
  playCount: string = ''
  /** 关联的分类标签 ID 列表，用于筛选 */
  tags: string[] = []
}

// ==================== 标签筛选数据模型 ====================

/** 分类标签项 */
export class TagFilterItem {
  /** 标签唯一 ID */
  id: string = ''
  /** 标签显示名称 */
  name: string = ''
}

/** 标签分组（如"热门标签""风格""语种"） */
export class TagFilterGroup {
  /** 分组名称 */
  groupName: string = ''
  /** 分组内标签列表 */
  tags: TagFilterItem[] = []
}
