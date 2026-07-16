/*
 * Lucid Music - 音源持久化层
 * Preferences 单例，JSON 序列化存储 + 内存缓存
 */
import { preferences } from '@kit.ArkData'
import { AudioSourceModel, AudioSourceOrigin } from '../model/AudioSourceModel'

const STORE_NAME = 'audiosource_store'
const KEY_SOURCES = 'sources_json'

export class AudioSourceDb {
  private static instance: AudioSourceDb | null = null
  private prefs: preferences.Preferences | null = null
  private cache: AudioSourceModel[] | null = null

  static getInstance(): AudioSourceDb {
    if (AudioSourceDb.instance === null) {
      AudioSourceDb.instance = new AudioSourceDb()
    }
    return AudioSourceDb.instance
  }

  /** 初始化，需要 UIAbilityContext */
  async init(context: Context): Promise<void> {
    this.prefs = await preferences.getPreferences(context, STORE_NAME)
  }

  /** 获取全部音源列表，优先返回内存缓存 */
  async getAll(): Promise<AudioSourceModel[]> {
    if (this.cache !== null) {
      return this.cache
    }
    if (this.prefs === null) {
      return []
    }
    const jsonStr: string = await this.prefs.get(KEY_SOURCES, '[]') as string
    const rawArr: object[] = JSON.parse(jsonStr) as object[]
    const list: AudioSourceModel[] = []
    for (let i = 0; i < rawArr.length; i++) {
      list.push(this.deserialize(rawArr[i] as Record<string, Object>))
    }
    this.cache = list
    return list
  }

  /** 保存全部音源列表，更新内存缓存并刷盘 */
  async saveAll(sources: AudioSourceModel[]): Promise<void> {
    this.cache = sources
    if (this.prefs === null) {
      return
    }
    const rawArr: Record<string, Object>[] = []
    for (let i = 0; i < sources.length; i++) {
      rawArr.push(this.serialize(sources[i]))
    }
    const jsonStr: string = JSON.stringify(rawArr)
    await this.prefs.put(KEY_SOURCES, jsonStr)
    await this.prefs.flush()
  }

  /** 清空缓存（供外部强制刷新） */
  clearCache(): void {
    this.cache = null
  }

  private serialize(m: AudioSourceModel): Record<string, Object> {
    const r: Record<string, Object> = {}
    r['id'] = m.id
    r['name'] = m.name
    r['version'] = m.version
    r['source'] = m.source
    r['url'] = m.url
    r['filePath'] = m.filePath
    r['enabled'] = m.enabled
    r['importedAt'] = m.importedAt
    r['description'] = m.description
    return r
  }

  private deserialize(raw: Record<string, Object>): AudioSourceModel {
    const m = new AudioSourceModel()
    m.id = (raw['id'] as string) || ''
    m.name = (raw['name'] as string) || ''
    m.version = (raw['version'] as string) || ''
    m.source = ((raw['source'] as string) === 'online' ? 'online' : 'local') as AudioSourceOrigin
    m.url = (raw['url'] as string) || ''
    m.filePath = (raw['filePath'] as string) || ''
    m.enabled = (raw['enabled'] as boolean) || false
    m.importedAt = (raw['importedAt'] as number) || 0
    m.description = (raw['description'] as string) || ''
    return m
  }
}
