/*
 * Lucid Music - 音源数据模型
 * 描述用户导入的 JS 脚本源元数据
 */

/** 音源来源类型 */
export type AudioSourceOrigin = 'online' | 'local'

/** 音源信息 */
export class AudioSourceModel {
  /** 唯一 ID（src_timestamp） */
  public id: string = ''
  /** JSDoc @name 解析出的显示名称 */
  public name: string = ''
  /** JSDoc @version 解析出的版本号 */
  public version: string = ''
  /** 来源类型 */
  public source: AudioSourceOrigin = 'local'
  /** 在线导入时的原始 URL */
  public url: string = ''
  /** 沙箱中脚本文件路径 */
  public filePath: string = ''
  /** 是否激活（互斥，同时只有一个为 true） */
  public enabled: boolean = false
  /** 导入时间戳（ms） */
  public importedAt: number = 0
  /** JSDoc @description 解析出的备注 */
  public description: string = ''
}
